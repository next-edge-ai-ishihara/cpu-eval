"""Attribute Scala compile and elaboration errors to the submitted source lines."""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.submission.scala_definition import _code_mask, definition_span


def source_region(source: Path, text: str, start: int, end: int) -> dict[str, object]:
    lines = []
    offset = 0
    for number, line in enumerate(text.splitlines(keepends=True), 1):
        stop = offset + len(line)
        if (offset < end and stop > start
                and not text[offset:min(stop, start)].strip()
                and not text[max(offset, end):stop].strip()):
            lines.append(number)
        offset = stop
    return {"source": str(source.resolve()), "source_sha256": hashlib.sha256(text.encode()).hexdigest(),
            "candidate_lines": lines}


def integrated_region(source: Path, base: str, integrated: str, name: str) -> dict[str, object]:
    start, end = definition_span(base, name, allow_braceless=True)
    suffix = base[end:]
    if not integrated.startswith(base[:start]):
        raise ValueError("integrated source does not retain the fixed prefix")
    if suffix.startswith("\n"):
        suffix = suffix[1:]
    fixed_end = len(integrated)
    if suffix and not suffix.endswith("\n") and integrated.endswith(suffix + "\n"):
        fixed_end -= 1
    if suffix and not integrated[:fixed_end].endswith(suffix):
        raise ValueError("integrated source does not retain the fixed suffix")
    region = source_region(source, integrated, start, fixed_end - len(suffix))
    sinks = _reference_driven_sinks(base, start, end, integrated[start:fixed_end - len(suffix)])
    if sinks:
        region["reference_driven_sinks"] = sinks
    return region


def _reference_driven_sinks(base: str, start: int, end: int, submitted: str) -> dict[str, int]:
    """Bind inherited wire fields driven by the reference class to their fixed declaration lines."""
    reference = _code_mask(base[start:end])
    parent = re.search(r"\bextends\s+([A-Za-z_]\w*)\s*$", reference.partition("{")[0])
    if not parent or not re.search(r"\bextends\s+" + re.escape(parent[1]) + r"\s*$",
                                   _code_mask(submitted).partition("{")[0]):
        return {}
    try:
        first, last = definition_span(base[:start], parent[1])
    except ValueError:
        return {}

    def body_lines(masked: str, first_line: int):
        depth = 0
        previous = ""
        for number, line in enumerate(masked.splitlines(), first_line):
            line = line.strip()
            if not line:
                continue
            if (depth == 1 and not re.search(r"\b(?:(?:if|for|while)\s*\(.*\)|else|yield)$", previous)
                    and not previous.endswith(("=", "=>"))):
                yield number, line
            depth += line.count("{") - line.count("}")
            previous = line

    wires = {}
    for number, line in body_lines(_code_mask(base[first:last]), base.count("\n", 0, first) + 1):
        match = re.match(r"val\s+(\w+)\s*=\s*Wire\s*\(", line)
        if match:
            wires[match[1]] = number
    sinks = {}
    for _, line in body_lines(reference, 1):
        match = re.match(r"(\w+)((?:\.\w+)+)\s*:=", line)
        if match and match[1] in wires:
            sinks[(match[1] + match[2]).replace(".", "_")] = wires[match[1]]
    return sinks


def _rename_free_list_elaboration(output: str, lines: set[int]) -> bool:
    if re.search(r"error downloading|resolutionerror|no such file or directory|"
                 r"permission denied|no space left on device|\bSEED\s+\d+", output, re.I):
        return False
    failure = re.search(
        r"(?m)^\[info\] FreeListPublicContractTest:\n\[info\] Free list external relation\n"
        r"\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
        r"((?:\[info\][^\n]*\n)+?)\[info\] Run completed", output)
    if not failure or not re.search(
            r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", output):
        return False
    diagnostic = "\n".join(line.removeprefix("[info]").strip() for line in failure[1].splitlines())
    primary = diagnostic.splitlines()[0]
    if re.fullmatch(
        r"chisel3\.internal\.ChiselException: (?:Width of RenameFreeList\.\w+: Reg\[UInt\] is unknown!"
        r"|Connection between sink \(RenameFreeList\.[^\n]+have different types\.)", primary
    ):
        frames = re.findall(
            r"(?m)^at boom\.exu\.RenameFreeList\.(?:<init>|\$anonfun\$[\w$]+)\(rename-freelist\.scala:(\d+)\)$",
            diagnostic)
        return bool(frames) and all(int(number) in lines for number in frames)
    report = diagnostic.removeprefix("firrtl.passes.PassExceptions: ")
    loop_header = "firrtl.transforms.CheckCombLoops$CombLoopException: : [module RenameFreeList] Combinational loop detected:"
    loops = re.findall(re.escape(loop_header) + r"\n((?:RenameFreeList\.\w+(?:\s+@\[[^\]\n]+\])?\n)+)", report + "\n")
    if not (report.startswith(loop_header) and loops and len(loops) == report.count("CheckCombLoops$CombLoopException:")):
        return False
    for trace in loops:
        nodes = [line.split()[0] for line in trace.splitlines()]
        positions = re.findall(r"([\w.-]+\.scala) (\d+):\d+", trace)
        if nodes[0] != nodes[-1] or not positions or any(
                file != "rename-freelist.scala" or int(number) not in lines for file, number in positions):
            return False
    return True


def candidate_elaboration_error(output: str, code: int, region: dict[str, object], cwd: Path) -> bool:
    if code in {0, 124, 137, 143} or code < 0:
        return False
    if re.search(r"outofmemoryerror|stackoverflowerror|internal (?:compiler )?error|"
                 r"unresolved dependenc|failed to download|command not found", output, re.I):
        return False
    try:
        source = Path(str(region["source"]))
        source_bytes = source.read_bytes()
        if hashlib.sha256(source_bytes).hexdigest() != region["source_sha256"]:
            return False
        name = str(region["class_name"])
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            return False
        lines = set(region["candidate_lines"])
    except (OSError, KeyError, TypeError, ValueError):
        return False
    if (name == "RenameFreeList" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/rename/rename-freelist.scala").resolve()
            and _rename_free_list_elaboration(output, lines)):
        return True
    if (name == "Queue" and region.get("source_basename_unique") is True
            and source.parts[-6:] == ("src", "main", "scala", "chisel3", "util", "Decoupled.scala")):
        if re.search(r"permission denied|no space left on device|segmentation fault|error downloading", output, re.I):
            return False
        bound_type = re.findall(
            r"(?m)^\[error\] Caused by: chisel3\.package\$ExpectedChiselTypeException: "
            r"'SourceD\.io\.bs_rdat: IO\[BankedStoreInnerDecoded\]' must be a Chisel type, not hardware\n"
            r"^\[error\][ \t]+at chisel3\.internal\.requireIsChiselType\$\.apply\(Binding\.scala:\d+\)\n"
            r"^\[error\][ \t]+at chisel3\.util\.Queue\.<init>\(Decoupled\.scala:(\d+)\)\n"
            r"^\[error\][ \t]+at Chisel\.package\$QueueCompatibility\.<init>\(compatibility\.scala:\d+\)$", output)
        if len(bound_type) == 1 and output.count("[error] Caused by:") == 1:
            line = int(bound_type[0])
            submitted = _code_mask(source_bytes.decode()).splitlines()
            return line in lines and 0 < line <= len(submitted) and bool(
                re.search(r"\brequireIsChiselType\s*\(", submitted[line - 1]))
    if (name == "RVCExpander" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/RVC.scala").resolve()):
        masked = _code_mask(source_bytes.decode()).splitlines()
        if len(masked) >= 20 and 20 not in lines and "rs3: UInt = x(31,27)" in masked[19]:
            supplied = "\n".join(line for number, line in enumerate(masked, 1) if number in lines)
            narrow_input = re.search(r"\bnew\s+RVCDecoder\s*\(\s*io\.in\s*\(\s*15\s*,\s*0\s*\)\s*,", supplied)
            errors = [line for line in output.splitlines() if "firrtl." in line and "Exception:" in line
                      and not line.lstrip().startswith("at ")]
            width_error = re.compile(
                r"^(?:\[error\]\s+)?firrtl\.passes\.CheckWidths\$BitsWidthException:\s+"
                r"@\[RVC\.scala 20:(\d+)\]: \[target ~TestHarness\|RVCExpander(?:_\d+)?\] "
                r"High bit (?P<high>\d+) in bits operator is larger than input width 16 "
                r"in bits\([\w$]+, (?P=high), (\d+)\)\.$")
            causes = [line for line in errors if "CheckWidths$BitsWidthException:" in line]
            slice_diagnostics = {("57", "19", "15"), ("79", "24", "20"), ("101", "31", "27")}
            unrelated = re.search(
                r"permission denied|no space left on device|segmentation fault|error downloading|"
                r"resolutionerror|no such file or directory|(?m:^\[error\]\s*Caused by:)", output, re.I)
            if (narrow_input and causes and not unrelated
                    and all((match := width_error.fullmatch(line)) and match.groups() in slice_diagnostics
                            for line in causes)
                    and all("CheckWidths$BitsWidthException:" in line or "firrtl.passes.PassException:" in line
                            for line in errors)):
                return True
    if (name == "RegisterRead" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/register-read/register-read.scala").resolve()):
        index_error = re.findall(
            r"(?m)^\[error\] Caused by: java\.lang\.IndexOutOfBoundsException: \d+\n"
            r"^\[error\][ \t]+at scala\.collection\.immutable\.Vector\.checkRangeConvert\(Vector\.scala:\d+\)\n"
            r"^\[error\][ \t]+at scala\.collection\.immutable\.Vector\.apply\(Vector\.scala:\d+\)\n"
            r"^\[error\][ \t]+at chisel3\.Vec\.apply\(Aggregate\.scala:\d+\)\n"
            r"^\[error\][ \t]+at boom\.exu\.RegisterRead\.(?:<init>|\$anonfun\$[\w$]+)"
            r"\(register-read\.scala:(\d+)\)$", output)
        if len(index_error) == 1 and output.count("[error] Caused by:") == 1 and int(index_error[0]) in lines:
            return True

        diagnostic = r"firrtl\.transforms\.CheckCombLoops\$CombLoopException:"
        header = (rf'(?m)^\[error\] (?:Exception in thread "main" )?{diagnostic} '
                  r": \[module (RegisterRead(?:_\d+)?|FpPipeline|BoomCore)\] Combinational loop detected:\n")
        trace = r"((?:^\[error\] \w+(?:\.\w+)+(?:[ \t]+@\[[^\]\n]+\])?[ \t]*\n)+)"
        unrelated = (r"^\[error\] (?:firrtl\.(?!(?:transforms\.CheckCombLoops\$CombLoopException|"
                     r"passes\.PassExceptions?):)|Caused by:)|error downloading|resolutionerror|"
                     r"no such file or directory|permission denied|no space left on device")
        loops = re.findall(header + trace, output)
        if loops and len(loops) == len(re.findall(diagnostic, output)) and not re.search(unrelated, output, re.M | re.I):
            for module, path in loops:
                signals = [line.split()[1] for line in path.splitlines()]
                references = re.findall(r"register-read\.scala (\d+):\d+", path)
                if (signals[0] != signals[-1] or not all(signal.startswith(module + ".") for signal in signals)
                        or not references or any(int(line) not in lines for line in references)):
                    break
                if module in {"FpPipeline", "BoomCore"} and not re.search(
                        r"\.[fi]register_read\.io_exe_reqs_\d+_(?:valid|bits_pred_data)"
                        r"[ \t]+@\[[^\]\n]*register-read\.scala", path):
                    break
            else:
                return True
    if (name == "PipelinedMultiplier" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/Multiplier.scala").resolve()):
        bare_response = re.findall(
            r"(?m)^\[error\] Caused by: chisel3\.package\$ExpectedHardwareException: 'MultiplierResp' "
            r"must be hardware, not a bare Chisel type\. [^\n]+\n"
            r"(?:^\[error\][ \t]+at chisel3\.(?:internal|chiselTypeOf\$|util\.(?:Pipe\$|RegEnable\$))[.\w$]+\([^\n]+\)\n)+"
            r"^\[error\][ \t]+at freechips\.rocketchip\.rocket\.PipelinedMultiplier\.(?:<init>|\$anonfun\$[\w$]+)"
            r"\(Multiplier\.scala:(\d+)\)$", output)
        if len(bare_response) == 1 and output.count("[error] Caused by:") == 1 and int(bare_response[0]) in lines:
            return True
    if (name == "TLB" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/TLB.scala").resolve()):
        clean = re.sub(r"\x1b\[[0-9;]*m", "", output)
        bare_element = re.findall(
            r"(?m)^\[(?:info|error)\] +(?:Caused by: )?chisel3\.package\$ExpectedHardwareException: "
            r"vec element 'Bool\[1\]' must be hardware, not a bare Chisel type\. [^\n]+\n"
            r"(?:^\[(?:info|error)\][ \t]+at [^\n]+\n)*?"
            r"^\[(?:info|error)\][ \t]+at Chisel\.package\$Vec\$\.fill\(compatibility\.scala:\d+\)\n"
            r"^\[(?:info|error)\][ \t]+at freechips\.rocketchip\.rocket\.TLB\.\$anonfun\$[\w$]+"
            r"\(TLB\.scala:(\d+)\)$", clean)
        if len(bare_element) == 1:
            line = int(bare_element[0])
            submitted = _code_mask(source_bytes.decode()).splitlines()
            if line in lines and 0 < line <= len(submitted):
                return bool(re.search(r"\bVec\.fill\b.*\bBool\(\)", submitted[line - 1]))
    if (name == "NBDTLB" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/lsu/tlb.scala").resolve()):
        clean = re.sub(r"\x1b\[[0-9;]*m", "", output)
        failed = re.search(
            r"(?m)^\[info\] NBDTLBFenceTest:\n\[info\] NBDTLB outstanding translation\n"
            r"\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
            r"((?:\[info\][^\n]*\n)+?)\[info\] Run completed", clean)
        if failed and re.search(r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", clean):
            detail = "\n".join(line.removeprefix("[info]").strip() for line in failed[1].splitlines())
            wrong_flow = re.match(
                r"firrtl\.passes\.CheckFlows\$WrongFlow: @\[tlb\.scala (\d+):\d+\]: "
                r"\[module NBDTLB\]  Expression io\.ptw is used as a SourceFlow but can only be used as a SinkFlow\.(?:\n|\Z)",
                detail)
            if wrong_flow and int(wrong_flow[1]) in lines:
                return True
            constructor = re.match(
                r"(?:java\.lang\.IllegalArgumentException: requirement failed: The literal value \d+ "
                r"was elaborated with a specified width of 0 bits, but at least \d+ bits are required\."
                r"|chisel3\.internal\.ChiselException: Connection between sink .+ and source .+ failed @: "
                r".* cannot be written from module NBDTLB\.)\n"
                r"(?:at \.\.\. \(\)\n)?at boom\.lsu\.NBDTLB\.(?:<init>|\$anonfun\$[\w$]+)\(tlb\.scala:(\d+)\)(?:\n|\Z)",
                detail)
            if constructor and int(constructor[1]) in lines:
                return True
    if (name == "MulAddRecFNToRaw_postMul" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/hardfloat/src/main/scala/MulAddRecFN.scala").resolve()):
        mux = re.findall(
            r"(?m)^\[error\] Caused by: java\.lang\.AssertionError: can't create Mux with heterogeneous types "
            r"class chisel3\.(?:UInt and class chisel3\.SInt|SInt and class chisel3\.UInt)\n"
            r"^\[error\][ \t]+at chisel3\.cloneSupertype\$\.\$anonfun\$apply\$\d+\(Data\.scala:\d+\)\n"
            r"(?:^\[error\][ \t]+at scala\.[^\n]+\n)*"
            r"^\[error\][ \t]+at chisel3\.cloneSupertype\$\.apply\(Data\.scala:\d+\)\n"
            r"^\[error\][ \t]+at chisel3\.Mux\$\.do_apply\(Mux\.scala:\d+\)\n"
            r"^\[error\][ \t]+at hardfloat\.MulAddRecFNToRaw_postMul\.\$anonfun\$[\w$]+"
            r"\(MulAddRecFN\.scala:(\d+)\)$", output)
        if len(mux) == 1 and output.count("[error] Caused by:") == 1 and int(mux[0]) in lines:
            return True
    if (name == "IssueSlot" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/issue-units/issue-slot.scala").resolve()):
        diagnostic = r"firrtl\.transforms\.CheckCombLoops\$CombLoopException:"
        header = (rf'(?m)^\[error\] (?:Exception in thread "main" )?{diagnostic} '
                  r": \[module ((?:IssueSlot|IssueUnitCollapsing)(?:_\d+)?|BoomCore)\] Combinational loop detected:\n")
        trace = r"((?:^\[error\] \w+(?:\.\w+)+(?:[ \t]+@\[[^\]\n]+\])?[ \t]*\n)+)"
        loops = re.findall(header + trace, output)
        unrelated = (r"^\[error\] (?:firrtl\.(?!(?:transforms\.CheckCombLoops\$CombLoopException|"
                     r"passes\.PassExceptions?):)|Caused by:)|error downloading|resolutionerror|"
                     r"no such file or directory|permission denied|no space left on device")
        if loops and len(loops) == len(re.findall(diagnostic, output)) and not re.search(unrelated, output, re.M | re.I):
            for module, path in loops:
                names = [line.split()[1] for line in path.splitlines()]
                references = re.findall(r"issue-slot\.scala (\d+):\d+", path)
                if (names[0] != names[-1] or not all(node.startswith(module + ".") for node in names)
                        or not references or any(int(line) not in lines for line in references)):
                    break
                if not module.startswith("IssueSlot") and not re.search(
                        r"\.slots_\d+\.\w+\s+@\[[^\]\n]*issue-slot\.scala", path):
                    break
            else:
                return True
    if (name == "DivSqrtRecF64" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/hardfloat/src/main/scala/DivSqrtRecF64.scala").resolve()):
        parent = cwd / "generators/boom/src/main/scala/exu/execution-units/fdiv.scala"
        header = ('Exception in thread "main" firrtl.passes.CheckInitialization$RefNotInitializedException:'
                  '  @[fdiv.scala 141:23] : [module FDivSqrtUnit]  Reference divsqrt is not fully initialized.')
        diagnostic = [line for line in output.splitlines() if "Exception in thread" in line or "<= VOID" in line]
        if diagnostic == ["[error] " + header, "[error]    : divsqrt.io.mulAddResult_3 <= VOID"]:
            text = source_bytes.decode()
            try:
                start, end = definition_span(text, name, allow_braceless=True)
            except ValueError:
                return False
            io = re.search(r"\bval[ \t]+io[ \t]*=[ \t]*IO\(\s*new\s+Bundle\s*\{([^{}]*)\}", _code_mask(text[start:end]))
            pattern = (r"\bval\s+mulAddResult_3\s*=\s*(?:UInt\(\s*INPUT\s*,\s*105\s*\)"
                       r"|Input\(\s*UInt\(\s*105\.W\s*\)\s*\))")
            if io and re.search(pattern, io[1]) and text[:start].count("\n") + 1 in lines:
                try:
                    actual = hashlib.sha256(parent.read_bytes()).hexdigest()
                except OSError:
                    actual = ""
                if actual == "2ab05c385a1e55000235ee89dcc2636906cd39e022ca0c3b2cb33ef64766bef4":
                    return True
    if (name == "BreakpointUnit" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/Breakpoint.scala").resolve()):
        failure = re.search(
            r"(?m)^\[info\] BreakpointUnitTest:\n\[info\] BreakpointUnit\n"
            r"\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
            r"((?:^\[info\][^\n]*\n)+)", output)
        if failure and not re.search(r"EXPECT AT[^\n]*FAIL", output):
            diagnostic = "\n".join(line.removeprefix("[info]").strip()
                                   for line in failure[1].splitlines())
            first = diagnostic.split("\n", 1)[0]
            if _structured_elaboration_error(diagnostic, region, source, source_bytes.decode()):
                return True
            constructor_error = re.fullmatch(
                r"(?:chisel3\.internal\.ChiselException: (?:Connection between sink .+ and source .+ failed @: .+"
                r"|Cannot reassign to read-only .+)|java\.lang\.IndexOutOfBoundsException: -[1-9]\d*"
                r"|java\.lang\.IllegalArgumentException: requirement failed: LargeBoomConfig .+)", first)
            if constructor_error:
                frame = re.match(
                    r"[^\n]+\n(?:at \.\.\. \(\)\n)?"
                    r"at freechips\.rocketchip\.rocket\.BreakpointUnit\.(?:<init>|\$anonfun\$[\w$]+)"
                    r"\(Breakpoint\.scala:(\d+)\)", diagnostic)
                if frame and int(frame[1]) in lines:
                    return True
            loop = "firrtl.transforms.CheckCombLoops$CombLoopException: : [module BreakpointUnit] Combinational loop detected:"
            loops = re.findall(re.escape(loop) + r"\n((?:BreakpointUnit\.\w+(?:\s+@\[[^\]\n]+\])?\n)+)",
                               diagnostic + "\n")
            if first in {loop, "firrtl.passes.PassExceptions: " + loop} and loops and len(loops) == diagnostic.count(loop):
                for trace in loops:
                    nodes = [line.split()[0] for line in trace.splitlines()]
                    positions = re.findall(r"([\w.]+\.scala) (\d+):\d+", trace)
                    if (nodes[0] != nodes[-1] or not positions
                            or any(file != source.name or int(number) not in lines for file, number in positions)):
                        break
                else:
                    return True
    if (name == "BranchPredictor" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/ifu/bpd/predictor.scala").resolve()
            and "BRANCH_PREDICTOR_OBSERVATION_STARTED" not in output
            and re.search(r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", output)
            and not re.search(r"error downloading|resolutionerror|cannot find include|"
                              r"no such file or directory|permission denied|no space left on device", output, re.I)):
        failures = re.findall(
            r"(?m)^\[info\][ \t]+(?:java\.lang\.IllegalArgumentException: requirement failed"
            r"|java\.lang\.IndexOutOfBoundsException: \d+"
            r"|chisel3\.internal\.ChiselException: Connection between sink [^\n]+"
            r"(?:different length Vecs|have different types)\.)\n"
            r"(?:\[info\][ \t]+at \.\.\. \(\)\n)?"
            r"^\[info\][ \t]+at boom\.ifu\.BranchPredictor\.(?:<init>|\$anonfun\$new\$\d+)"
            r"\(predictor\.scala:(\d+)\)$", output)
        if len(failures) == 1 and int(failures[0]) in lines:
            return True
    if (name == "ComposedBranchPredictorBank" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/ifu/bpd/composer.scala").resolve()
            and "COMPOSED_PREDICTOR_OBSERVATION_STARTED" not in output
            and re.search(r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", output)):
        failure = re.search(
            r"(?m)^\[info\] ComposedPredictorPortsTest:\n\[info\] ComposedBranchPredictorBank\n"
            r"\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
            r"((?:^\[info\][^\n]*\n)+?)^\[info\] Run completed", output)
        if failure and not re.search(r"error downloading|resolutionerror|cannot find include|"
                                     r"no such file or directory|permission denied|no space left on device", output, re.I):
            diagnostic = "\n".join(line.removeprefix("[info]").strip() for line in failure[1].splitlines())
            first = diagnostic.split("\n", 1)[0]
            constructor_error = re.fullmatch(
                r"(?:java\.lang\.IllegalArgumentException: requirement failed: (?:"
                r"Composed predictor meta size \d+ exceeds bpdMaxMetaLength \d+|"
                r"The literal value \d+ was elaborated with a specified width of \d+ bits, but at least \d+ bits are required\.)"
                r"|java\.lang\.ClassCastException: class boom\.ifu\.\w+BranchPredictorBank cannot be cast "
                r"to class boom\.ifu\.\w+BranchPredictorBank \([^\n]+\)"
                r"|chisel3\.internal\.ChiselException: (?:Connection between sink .+ and source .+ failed @: .+|"
                r"Cannot reassign to read-only ComposedBranchPredictorBank\.\?: OpResult\[\w+<\d+>\]))", first)
            candidate_frame = r"at boom\.ifu\.ComposedBranchPredictorBank\.(?:<init>|\$anonfun\$[\w$]+)\(composer\.scala:(\d+)\)"
            frame = re.match(r"[^\n]+\n(?:at \.\.\. \(\)\n)?" + candidate_frame, diagnostic)
            if constructor_error and frame and int(frame[1]) in lines:
                return True
            if (diagnostic.startswith("java.lang.IndexOutOfBoundsException: 0\nat ... ()\n"
                                      "at boom.ifu.BranchPredictorBank.$anonfun$new$1(predictor.scala:158)\n")
                    and any(int(item) in lines for item in re.findall(r"(?m)^" + candidate_frame + "$", diagnostic))
                    and any(re.match(r"\s*override\s+val\s+nInputs\s*=", line)
                            for number, line in enumerate(_code_mask(source_bytes.decode()).splitlines(), 1)
                            if number in lines)):
                return True
            first_pass_prefix = "firrtl.passes.PassExceptions: "
            if diagnostic.startswith(first_pass_prefix):
                report = diagnostic.removeprefix(first_pass_prefix)
                if _structured_elaboration_error(report, region, source, source_bytes.decode()):
                    return True
                # The fixed configuration can report the same undriven submitted input
                # once at its connection and again at the submitted Wire declaration.
                missing = re.findall(
                    r"(?m)^firrtl\.passes\.CheckInitialization\$RefNotInitializedException:\s+"
                    r"@\[([\w.-]+) (\d+):\d+\] : \[module ComposedBranchPredictorBank\] +"
                    r"Reference (\w+) is not fully initialized\.\n: (dummyResp\.[^\n]+) <= VOID$", report)
                if (missing and len(missing) == report.count("firrtl.passes.CheckInitialization$RefNotInitializedException:")
                        and all((path == "composer.scala" and int(line) in lines and ref == "dummyResp")
                                or (path == "config-mixins.scala" and line == "448" and ref == "components_3")
                                for path, line, ref, _ in missing)
                        and {field for path, _, _, field in missing if path == "composer.scala"}
                        == {field for path, _, _, field in missing if path == "config-mixins.scala"}
                        and any(re.match(r"\s*val\s+dummyResp\s*=\s*Wire\(", line)
                                for number, line in enumerate(_code_mask(source_bytes.decode()).splitlines(), 1)
                                if number in lines)):
                    return True
    if (name == "DivSqrtRecF64_mulAddZ31" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/hardfloat/src/main/scala/DivSqrtRecF64_mulAddZ31.scala").resolve()
            and "DIV_SQRT_RESERVATION_OBSERVATION_STARTED" not in output
            and re.search(r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", output)):
        failure = re.search(
            r"(?m)^\[info\] DivSqrtMultiplyReservationsTest:\n\[info\] DivSqrtRecF64_mulAddZ31\n"
            r"\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
            r"((?:^\[info\][^\n]*\n)+?)^\[info\] Run completed", output)
        if failure and not re.search(r"permission denied|no space left on device", output, re.I):
            report = "\n".join(line.removeprefix("[info]").strip() for line in failure[1].splitlines())
            if _structured_elaboration_error(report.removeprefix("firrtl.passes.PassExceptions: "),
                                             region, source, source_bytes.decode()):
                return True
    if (name == "HellaCacheArbiter" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/HellaCacheArbiter.scala").resolve()):
        plain = re.sub(r"\x1b\[[0-9;]*m", "", output)
        invalid_slice = re.findall(
            r"(?m)^\[error\] HellaCacheArbiter\.scala:(\d+): Invalid bit range \(-1,0\) "
            r"in class freechips\.rocketchip\.rocket\.HellaCacheArbiter$",
            plain,
        )
        if (len(invalid_slice) == 1 and int(invalid_slice[0]) in lines
                and "[error] There were 1 error(s) during hardware elaboration." in plain
                and "chisel3.internal.Errors: Fatal errors during hardware elaboration." in plain):
            return True
        requester_requirement = re.search(
            r"(?m)^\[info\] +java\.lang\.IllegalArgumentException: requirement failed[^\n]*\n"
            r"\[info\] +at \.\.\. \(\)\n"
            r"\[info\] +at freechips\.rocketchip\.rocket\.HellaCacheArbiter\.<init>"
            r"\(HellaCacheArbiter\.scala:(\d+)\)$",
            plain,
        )
        if (requester_requirement and int(requester_requirement[1]) in lines
                and "HELLA_CACHE_ARBITER_PORTS_START" not in plain
                and "[info] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0" in plain):
            return True
    if (name == "LoopBranchPredictorColumn" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/ifu/bpd/loop.scala").resolve()):
        diagnostic = r"firrtl\.transforms\.CheckCombLoops\$CombLoopException:"
        header = (rf'(?m)^\[error\] (?:Exception in thread "main" )?{diagnostic} '
                  r": \[module (LoopBranchPredictorColumn(?:_\d+)?)\] Combinational loop detected:\n")
        trace = r"((?:^\[error\] \w+(?:\.\w+)+(?:[ \t]+@\[[^\]\n]+\])?[ \t]*\n)+)"
        loops = re.findall(header + trace, output)
        unrelated = (r"^\[error\] (?:firrtl\.(?!(?:transforms\.CheckCombLoops\$CombLoopException|"
                     r"passes\.PassExceptions?):)|Caused by:)|error downloading|resolutionerror|"
                     r"no such file or directory|permission denied|no space left on device")
        if loops and len(loops) == len(re.findall(diagnostic, output)) and not re.search(unrelated, output, re.M | re.I):
            for module, loop in loops:
                nodes = [line.split()[1] for line in loop.splitlines()]
                positions = re.findall(r"([\w.-]+\.scala) (\d+):\d+", loop)
                if (nodes[0] != nodes[-1] or not all(node.startswith(module + ".") for node in nodes)
                        or not positions or any(file != "loop.scala" or int(number) not in lines
                                                for file, number in positions)):
                    break
            else:
                return True
    if (name == "IntXbar"
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/interrupts/Xbar.scala").resolve()):
        plain = re.sub(r"\x1b\[[0-9;]*m", "", output)
        overlapping_ranges = re.search(
            r"(?m)^\[error\] Caused by: java\.lang\.IllegalArgumentException: requirement failed\n"
            r"\[error\][ \t]+at scala\.Predef\$\.require\(Predef\.scala:\d+\)\n"
            r"(?:\[error\][ \t]+at [^\n]+\n)*?"
            r"\[error\][ \t]+at freechips\.rocketchip\.interrupts\.IntSourcePortParameters\."
            r"<init>\(Parameters\.scala:42\)\n"
            r"\[error\][ \t]+at freechips\.rocketchip\.interrupts\.IntXbar\.\$anonfun\$intnode\$\d+"
            r"\(Xbar\.scala:(\d+)\)$",
            plain,
        )
        if overlapping_ranges and int(overlapping_ranges[1]) in lines:
            return True
    if (name == "FPToInt" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/tile/FPU.scala").resolve()):
        flags_on_result = re.findall(
            r'(?m)^\[error\] Exception in thread "main" firrtl\.passes\.CheckTypes\$InvalidConnect:[ \t]+'
            r"@\[FPU\.scala (\d+):\d+\]: \[module FPToInt\][ \t]+"
            r"Type mismatch in 'toint <- dcmp\.io\.exceptionFlags'\.\n"
            r"^\[error\][ \t]+toint: \{ data : UInt<65>, exc : UInt<5>\}\n"
            r"^\[error\][ \t]+dcmp\.io\.exceptionFlags: UInt<5>$", output)
        if len(flags_on_result) == 1 and int(flags_on_result[0]) in lines:
            return True
        unbound_flags = re.findall(
            r"(?m)^\[error\] Caused by: chisel3\.package\$ExpectedHardwareException: "
            r"bits operated on 'UInt<5>' must be hardware, not a bare Chisel type\. [^\n]*\n"
            r"^\[error\][ \t]+at chisel3\.internal\.requireIsHardware\$\.apply\(Binding\.scala:\d+\)\n"
            r"^\[error\][ \t]+at chisel3\.Bits\.binop\(Bits\.scala:\d+\)\n"
            r"^\[error\][ \t]+at chisel3\.UInt\.do_\$bar\(Bits\.scala:\d+\)\n"
            r"^\[error\][ \t]+at freechips\.rocketchip\.tile\.FPToInt\.\$anonfun\$new\$\d+\(FPU\.scala:(\d+)\)$", output)
        if (len(unbound_flags) == 1 and len(re.findall(r"(?m)^\[error\] Caused by:", output)) == 1
                and int(unbound_flags[0]) in lines):
            return True
    if (name == "PredRenameStage" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/rename/rename-stage.scala").resolve()
            and not re.search(r"error downloading|resolutionerror|no such file or directory|"
                              r"permission denied|no space left on device|\bSEED\s+\d+", output, re.I)):
        failure = re.search(
            r"(?m)^\[info\] PredPublicContractTest:\n\[info\] Predicate rename external relation\n"
            r"\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
            r"((?:\[info\][^\n]*\n)+?)\[info\] Run completed", output)
        if failure and re.search(r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", output):
            diagnostic = "\n".join(line.removeprefix("[info]").strip() for line in failure[1].splitlines())
            report = diagnostic.removeprefix("firrtl.passes.PassExceptions: ")
            exceptions = set(re.findall(r"(?m)^([\w.$]*(?:Exception|Error)):", report))
            exceptions.discard("firrtl.passes.PassException")
            loop_header = "firrtl.transforms.CheckCombLoops$CombLoopException: : [module PredRenameStage] Combinational loop detected:"
            loop_pattern = re.escape(loop_header) + r"\n((?:PredRenameStage\.\w+(?:\s+@\[[^\]\n]+\])?\n)+)"
            loops = re.findall(loop_pattern, report + "\n")
            if (exceptions == {"firrtl.transforms.CheckCombLoops$CombLoopException"}
                    and report.startswith(loop_header) and loops and len(loops) == report.count("CheckCombLoops$CombLoopException:")):
                for trace in loops:
                    nodes = [line.split()[0] for line in trace.splitlines()]
                    positions = re.findall(r"([\w.-]+\.scala) (\d+):\d+", trace)
                    if (nodes[0] != nodes[-1] or not positions
                            or any(file != source.name or int(number) not in lines for file, number in positions)):
                        break
                else:
                    return True
            missing_header = "firrtl.passes.CheckInitialization$RefNotInitializedException:"
            missing = re.findall(
                r"(?m)^" + re.escape(missing_header) + r"\s+@\[rename-stage\.scala 106:29\] : \[module PredRenameStage\]\s+"
                r"Reference ren2_alloc_reqs is not fully initialized\.\n: ren2_alloc_reqs\[([012])\] <= VOID$",
                report)
            count = re.findall(r"(?m)^firrtl\.passes\.PassException: (\d+) errors detected!$", report)
            declaration = source_bytes.splitlines()[105:106]
            if (exceptions == {missing_header[:-1]} and report.startswith(missing_header)
                    and missing and len(set(missing)) == len(missing)
                    and count == [str(len(missing))] and len(missing) == report.count(missing_header)
                    and 106 not in lines
                    and declaration == [b"  val ren2_alloc_reqs = Wire(Vec(plWidth, Bool()))"]):
                return True
    if (name == "IssueUnitCollapsing" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/issue-units/issue-unit-age-ordered.scala").resolve()
            and not re.search(r"error downloading|resolutionerror|no such file or directory|"
                              r"permission denied|no space left on device|\bSEED\s+\d+", output, re.I)):
        failure = re.search(
            r"(?m)^\[info\] IssuePublicContractTest:\n^\[info\] Issue queue public scheduling\n"
            r"^\[info\] - [^\n]+ \*\*\* FAILED \*\*\*\n"
            r"((?:^\[info\][^\n]*\n)+?)^\[info\] Run completed", output)
        if failure and re.search(r"(?m)^\[info\] Tests: succeeded 0, failed 1, canceled 0, ignored 0, pending 0$", output):
            diagnostic = "\n".join(line.removeprefix("[info]").strip() for line in failure[1].splitlines())
            frame = re.match(
                r"chisel3\.internal\.ChiselException: Cannot reassign to read-only Bool\((?:true|false)\)\n"
                r"(?:at \.\.\. \(\)\n)?at boom\.exu\.IssueUnitCollapsing\.(?:<init>|\$anonfun\$[\w$]+)"
                r"\(issue-unit-age-ordered\.scala:(\d+)\)(?:\n|$)", diagnostic)
            if frame and int(frame[1]) in lines:
                return True
            report = diagnostic.removeprefix("firrtl.passes.PassExceptions: ")
            loop_header = "firrtl.transforms.CheckCombLoops$CombLoopException: : [module IssueUnitCollapsing] Combinational loop detected:"
            loops = re.findall(re.escape(loop_header) + r"\n((?:IssueUnitCollapsing\.\w+(?:\s+@\[[^\]\n]+\])?\n)+)",
                               report + "\n")
            if report.startswith(loop_header) and loops and len(loops) == report.count("CheckCombLoops$CombLoopException:"):
                for trace in loops:
                    nodes = [line.split()[0] for line in trace.splitlines()]
                    positions = re.findall(r"([\w.-]+\.scala) (\d+):\d+", trace)
                    if (nodes[0] != nodes[-1] or not positions
                            or any(file != source.name or int(number) not in lines for file, number in positions)):
                        break
                else:
                    return True
            missing = re.findall(
                r"(?m)^firrtl\.passes\.CheckInitialization\$RefNotInitializedException: +"
                r"@\[issue-unit\.scala 154:28\] : \[module IssueUnitCollapsing\]  "
                r"Reference issue_slots is not fully initialized\.\n"
                r": issue_slots\[\d+\]\.(?:clear|grant|in_uop\.(?:valid|bits\.[\w.\[\]]+)) <= [^\n]*\bVOID\b[^\n]*$",
                report)
            missing_count = re.findall(r"(?m)^firrtl\.passes\.PassException: (\d+) errors detected!$", report)
            if (report.startswith("firrtl.passes.CheckInitialization$RefNotInitializedException:")
                    and missing and missing_count == [str(len(missing))]
                    and len(missing) == report.count("CheckInitialization$RefNotInitializedException:")):
                parent = source.with_name("issue-unit.scala")
                try:
                    parent_hash = hashlib.sha256(parent.read_bytes()).hexdigest()
                except OSError:
                    parent_hash = ""
                if parent_hash == "3324a8843a4a6705e89bfee01b49c2e9e97d58ef28563fdcf4003ea85c4b9dc9":
                    return True
    if (name == "FetchBuffer" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/ifu/fetch-buffer.scala").resolve()):
        vector_index = re.findall(
            r"(?m)^\[error\] Caused by: java\.lang\.IndexOutOfBoundsException: \d+\n"
            r"^\[error\][ \t]+at scala\.collection\.immutable\.Vector\.checkRangeConvert\(Vector\.scala:\d+\)\n"
            r"^\[error\][ \t]+at scala\.collection\.immutable\.Vector\.apply\(Vector\.scala:\d+\)\n"
            r"^\[error\][ \t]+at chisel3\.Vec\.apply\(Aggregate\.scala:\d+\)\n"
            r"^\[error\][ \t]+at boom\.ifu\.FetchBuffer\.(?:<init>|\$anonfun\$new\$\d+)\(fetch-buffer\.scala:(\d+)\)$",
            output)
        if (len(vector_index) == 1 and len(re.findall(r"(?m)^\[error\] Caused by:", output)) == 1
                and int(vector_index[0]) in lines):
            return True
        loop_header = "firrtl.transforms.CheckCombLoops$CombLoopException: : [module FetchBuffer] Combinational loop detected:"
        loops = re.findall(r"(?m)^\[error\] " + re.escape(loop_header) + r"\n"
                           r"((?:^\[error\] FetchBuffer\.\w+(?:[ \t]+@\[[^\]\n]+\])?[ \t]*\n)+)", output)
        if (loops and len(loops) == output.count("CheckCombLoops$CombLoopException:")
                and re.search(r"(?m)^\[error\] Exception in thread \"main\" firrtl\.passes\.PassExceptions:[ \t]*$", output)
                and not re.search(r"(?m)^\[error\] (?:firrtl\.(?!transforms\.CheckCombLoops|passes\.PassException)|Caused by:)", output)):
            for loop in loops:
                nodes = [line.split()[1] for line in loop.splitlines()]
                positions = re.findall(r"([\w.-]+\.scala) (\d+):\d+", loop)
                if (nodes[0] != nodes[-1] or not positions
                        or any(path != source.name or int(line) not in lines for path, line in positions)):
                    break
            else:
                return True
    if (name == "RenameStage" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/rename/rename-stage.scala").resolve()
            and not re.search(r"error downloading|resolutionerror|no such file or directory|"
                              r"permission denied|no space left on device", output, re.I)):
        uninitialized_map = re.search(
            r'(?m)^\[error\] Caused by: java\.lang\.NullPointerException: Cannot invoke '
            r'"boom\.exu\.RenameMapTable\.io\(\)" because the return value of '
            r'"boom\.exu\.RenameStage\.(\w+)\(\)" is null\n'
            r'^\[error\][ \t]+at boom\.exu\.RenameStage\.\$anonfun\$BypassAllocations\$\d+'
            r'\(rename-stage\.scala:(\d+)\)$', output)
        parent_call = re.search(r"(?m)^\[error\][ \t]+at boom\.exu\.AbstractRenameStage\.\$anonfun\$new\$\d+"
                                r"\(rename-stage\.scala:(\d+)\)$", output)
        if uninitialized_map and parent_call and output.count("[error] Caused by:") == 1:
            member, use = uninitialized_map[1], int(uninitialized_map[2])
            caller = int(parent_call[1])
            text = _code_mask(source_bytes.decode()).splitlines()
            if (use in lines and caller not in lines and 0 < use <= len(text) and 0 < caller <= len(text)
                    and re.search(r"\b" + re.escape(member) + r"\s*\.\s*io\b", text[use - 1])
                    and "GetNewUopAndBrMask(BypassAllocations(next_uop, " in text[caller - 1]):
                return True
    if (name == "BoomMSHR" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/lsu/mshrs.scala").resolve()):
        missing_register = re.search(
            r'(?m)^\[error\][ \t]+Caused by: java\.lang\.NullPointerException: Cannot invoke '
            r'"chisel3\.UInt\.\$colon\$eq\([^"\n]+\)" because the return value of '
            r'"boom\.lsu\.BoomMSHR\.idxReg\(\)" is null\n'
            r'^\[error\][ \t]+at boom\.lsu\.BoomMSHR\.(?:<init>|\$anonfun\$new\$\d+)'
            r'\(mshrs\.scala:(\d+)\)$', output)
        if missing_register and int(missing_register[1]) in lines:
            return True
        refill_loop = re.search(
            r'(?m)^\[error\] Exception in thread "main" firrtl\.transforms\.CheckCombLoops\$CombLoopException: '
            r': \[module BoomMSHR\] Combinational loop detected:\n'
            r'((?:^\[error\] BoomMSHR\.\w+(?:[ \t]+@\[(?:mshrs|Decoupled)\.scala \d+:\d+\])?[ \t]*\n)+)',
            output)
        if refill_loop:
            loop_nodes = [node.split()[1] for node in refill_loop[1].splitlines()]
            candidate_lines = {int(line) for line in re.findall(r'@\[mshrs\.scala (\d+):\d+\]', refill_loop[1])}
            if (loop_nodes[0] == loop_nodes[-1] == "BoomMSHR.io_lb_write_valid"
                    and "BoomMSHR.refill_done" in loop_nodes and candidate_lines and candidate_lines <= lines):
                return True
    if (name == "CSRFile"
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/CSR.scala").resolve()):
        # Other dependencies have CSR.scala. The module and an actual write to
        # the fixed input port identify this submitted definition.
        wrong_flow = re.findall(
            r"(?m)^\[error\][ \t]+firrtl\.passes\.CheckFlows\$WrongFlow:[ \t]+"
            r"@\[CSR\.scala (\d+):\d+\]: \[module CSRFile\][ \t]+"
            r"Expression io\.fcsr_flags\.bits is used as a SinkFlow but can only be used as a SourceFlow\.$",
            output)
        if len(wrong_flow) == 1:
            line = int(wrong_flow[0])
            masked = _code_mask(source_bytes.decode()).splitlines()
            if (line in lines and 0 < line <= len(masked)
                    and re.search(r"\bio\.fcsr_flags\.bits\s*:=", masked[line - 1])
                    and _structured_elaboration_error(
                        output, {**region, "source_basename_unique": True}, source, source_bytes.decode())):
                return True
    if (name == "LoopBranchPredictorBank" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/ifu/bpd/loop.scala").resolve()):
        def _loop_bank_construction_error(output: str, source: Path, text: str, lines: set[int]) -> bool:
            if re.search(r"error downloading|resolutionerror|no such file or directory|"
                         r"permission denied|no space left on device", output, re.I):
                return False
            causes = re.findall(r"(?m)^\[error\] Caused by: (.+)$", output)
            if causes:
                frame = re.search(
                    r"(?m)^\[error\]\s+at boom\.ifu\.BranchPredictorBank\.<init>\(predictor\.scala:158\)\n"
                    r"^\[error\]\s+at boom\.ifu\.LoopBranchPredictorBank\.<init>\(loop\.scala:(\d+)\)$", output)
                override = re.search(r"(?m)^[ \t]*override[ \t]+val[ \t]+nInputs[ \t]*=", _code_mask(text))
                if (causes != ["java.lang.IndexOutOfBoundsException: 0"] or frame is None
                        or int(frame[1]) not in lines or override is None
                        or text.count("\n", 0, override.start()) + 1 not in lines):
                    return False
                try:
                    parent_hash = hashlib.sha256(source.with_name("predictor.scala").read_bytes()).hexdigest()
                except OSError:
                    return False
                return parent_hash == "49b5ca9ba0c75a8089da49127b592b86bfde4b723cb7d175e8f61e531a2c7091"

            body = output.split('Exception in thread "main" firrtl.passes.PassExceptions:', 1)
            if len(body) != 2:
                return False
            diagnostics = re.findall(r"(?m)^\[error\] (firrtl\.[^:]+):", body[1])
            kinds = set(diagnostics) - {"firrtl.passes.PassException"}
            loop = "firrtl.transforms.CheckCombLoops$CombLoopException"
            width = "firrtl.passes.CheckWidths$UninferredWidth"
            if kinds == {loop}:
                reports = re.findall(
                    re.escape(loop) + r": : \[module (LoopBranchPredictorColumn(?:_\d+)?)\] Combinational loop detected:\n"
                    r"((?:\[error\] [\w.]+(?:[ \t]+@\[[^\]\n]+\])?[ \t]*\n)+)", body[1])
                if not reports or len(reports) != diagnostics.count(loop):
                    return False
                for module, trace in reports:
                    nodes = [line.split()[1] for line in trace.splitlines()]
                    locations = re.findall(r"([\w.-]+\.scala) (\d+):\d+", trace)
                    if (nodes[0] != nodes[-1] or not all(node.startswith(module + ".") for node in nodes)
                            or not locations or any(path != source.name or int(line) not in lines for path, line in locations)):
                        return False
                return True
            if kinds == {width}:
                reports = re.findall(
                    re.escape(width) + r": +(?:@\[loop\.scala (\d+):\d+\] )?: Uninferred width[^\n]*\n"
                    r"\[error\]\s+circuit \w+:\n"
                    r"\[error\]\s+\?\?\? module LoopBranchPredictor(?:Bank|Column)(?:_\d+)?:\n"
                    r"\[error\]\s+\?\?\? ([\w.]+)\n", body[1])
                return (bool(reports) and len(reports) == diagnostics.count(width)
                        and any(line for line, _ in reports)
                        and all(int(line) in lines if line else target in {"io.f2_req_idx", "io.update_idx"}
                                for line, target in reports))
            return False

        if _loop_bank_construction_error(output, source, source_bytes.decode(), lines):
            return True
    if (name == "PipelinedMulUnit" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/execution-units/functional-unit.scala").resolve()):
        diagnostic = "firrtl.transforms.CheckCombLoops$CombLoopException"
        if diagnostic in output:
            if re.search(r"error downloading|resolutionerror|no such file or directory|permission denied|"
                         r"no space left on device|segmentation fault", output, re.I):
                return False
            error_lines = [line for line in output.splitlines() if line.startswith("[error]")]
            allowed = {diagnostic, "firrtl.passes.PassExceptions", "firrtl.passes.PassException"}
            for entry in error_lines:
                entry = re.sub(r'^\[error\] (?:Exception in thread "[^"]+" )?', '', entry)
                if set(re.findall(r"\b[\w.$]*(?:Exceptions?|Error)\b", entry)) - allowed:
                    return False
            header = (rf'(?m)^\[error\] (?:Exception in thread "main" )?{re.escape(diagnostic)}: '
                      r': \[module (PipelinedMulUnit(?:_\d+)?)\] Combinational loop detected:\n')
            reports = list(re.finditer(header, output))
            if not reports or len(reports) != output.count(diagnostic):
                return False
            text = _code_mask(source_bytes.decode()).splitlines()
            statements = [text[line - 1] for line in lines if 0 < line <= len(text)]
            self_uop = re.compile(r"\s*io\.resp\.bits\.uop\s*:=\s*io\.resp\.bits\.uop\s*")
            if all(re.match(r"\[error\] io_resp_bits_uop_\w+[ \t]*\n", output[report.end():])
                   for report in reports):
                summary = re.findall(r"(?m)^\[error\] firrtl\.passes\.PassException: (\d+) errors detected!$", output)
                return summary == [str(len(reports))] and any(self_uop.fullmatch(line) for line in statements)
            if len(reports) == 1:
                report = reports[0]
                module = re.escape(report[1])
                trace = re.match(rf"\[error\] {module}\.io_resp_valid[ \t]*\n"
                                 rf"\[error\] {module}\._io_resp_valid_T(?:_\d+)?[ \t]+"
                                 r"@\[functional-unit\.scala (\d+):\d+\][ \t]*\n"
                                 rf"\[error\] {module}\.io_resp_valid[ \t]+"
                                 r"@\[functional-unit\.scala (\d+):\d+\][ \t]*\n", output[report.end():])
                return trace is not None and all(int(line) in lines for line in trace.groups())
            return False
    if (name == "MulDiv" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/Multiplier.scala").resolve()):
        if re.search(r"error downloading|resolutionerror|cannot find include|no such file or directory|"
                     r"permission denied|no space left on device|segmentation fault", output, re.I):
            return False
        diagnostic = r"firrtl\.transforms\.CheckCombLoops\$CombLoopException:"
        loop = re.search(
            rf'(?m)^\[error\] (?:Exception in thread "main" )?{diagnostic} '
            r': \[module DivUnit\] Combinational loop detected:\n'
            r'\[error\] DivUnit\.io_req_ready[ \t]*\n'
            r'\[error\] DivUnit\._T(?:_\d+)?[ \t]+@\[Decoupled\.scala 50:35\][ \t]*\n'
            r'\[error\] DivUnit\._GEN_\d+[ \t]+@\[functional-unit\.scala 650:22 '
            r'functional-unit\.scala 652:13 functional-unit\.scala 656:13\][ \t]*\n'
            r'\[error\] DivUnit\.do_kill[ \t]*\n'
            r'\[error\] DivUnit\.div\.io_kill[ \t]+@\[functional-unit\.scala 687:23\][ \t]*\n'
            r'((?:\[error\] DivUnit\.div\._io_req_ready_T(?:_\d+)?[ \t]+'
            r'@\[Multiplier\.scala \d+:\d+\][ \t]*\n)*)'
            r'\[error\] DivUnit\.div\.io_req_ready[ \t]+@\[Multiplier\.scala (\d+):\d+\][ \t]*\n'
            r'\[error\] DivUnit\.io_req_ready[ \t]+@\[functional-unit\.scala 684:23\][ \t]*$', output)
        if loop is not None:
            remaining = output[:loop.start()] + output[loop.end():]
            if re.search(r"(?m)^\[error\].*(?:Exception|Error)\b", remaining):
                return False
            return int(loop[2]) in lines and all(
                int(line) in lines for line in re.findall(r"Multiplier\.scala (\d+):", loop[1]))
        output = re.sub(
            r'(?m)^(\[error\][ \t]+)?Exception in thread "main" '
            r'(?=firrtl\.passes\.CheckWidths\$BitsWidthException:)',
            lambda match: match[1] or "", output)
    if (name == "Mul54" and region.get("source_basename_unique") is True
            and source.resolve() == (cwd / "generators/rocket-chip/hardfloat/src/main/scala/DivSqrtRecF64.scala").resolve()):
        if re.search(r"permission denied|no space left on device|segmentation fault", output, re.I):
            return False
        output = re.sub(
            r'(?m)^(\[error\][ \t]+)?Exception in thread "main" '
            r'(?=firrtl\.passes\.CheckWidths\$BitsWidthException:)',
            lambda match: match[1] or "", output)
        output = re.sub(
            r"(?m)^(\[error\][ \t]+Caused by: chisel3\.package\$ExpectedHardwareException: )"
            r"(?:bits operated on )?"
            r"(?='UInt<\d+>' must be hardware, not a bare Chisel type\.)",
            r"\g<1>data to be connected ", output)
    if _chisel_elaboration_error(output, region, source, source_bytes.decode(), cwd):
        return True
    if _structured_elaboration_error(output, region, source, source_bytes.decode()):
        return True
    module = re.escape(name) + r"(?:_Anon)?(?:_\d+)?"
    scope_error = "chisel3.internal.ChiselException: operand has escaped the scope of the when in which it was constructed"
    bare = re.search(r"(?m)^\[error\]\s+Caused by: (chisel3\.package\$ExpectedHardwareException: "
                     r"data to be connected '[\w<>]+' must be hardware, not a bare Chisel type\.[^\n]*)$", output)
    if scope_error in output or bare:
        cause = bare[1] if bare else scope_error
        packages = re.findall(r"(?m)^package\s+([\w.]+)\s*$", _code_mask(source_bytes.decode()))
        if bare and len(packages) != 1:
            return False
        if not bare and region.get("source_basename_unique") is not True:
            return False
        if re.search(r"error downloading|resolutionerror|cannot find include|no such file or directory|"
                     r"permission denied|no space left on device|segmentation fault", output, re.I):
            return False
        clean = [re.sub(r"^\[error\]\s*", "", line.strip()) for line in output.splitlines()]
        exception = cause.split(":", 1)[0]
        allowed = {"java.lang.reflect.InvocationTargetException", exception}
        for line in clean:
            if line.startswith(("[warn]", "at ", "make:")):
                continue
            if exception in line and line != "Caused by: " + cause:
                return False
            if any(token not in allowed for token in re.findall(r"\b[\w.$]*(?:Exception|Error)\b", line)):
                return False
        causes = [index for index, line in enumerate(clean) if line == "Caused by: " + cause]
        if len(causes) != 1:
            return False
        frame = re.compile(r"at ([\w.$<>]+)\(([^():]+\.scala):(\d+)\)")
        for line in clean[causes[0] + 1:]:
            match = frame.fullmatch(line)
            if match is None:
                continue
            if match[1].startswith(("chisel3.", "scala.", "java.")):
                continue
            prefix = re.escape(packages[0]) + r"\." if bare else r"(?:[\w$]+\.)*"
            return (re.fullmatch(prefix + re.escape(name) + r"\.(?:<init>|\$anonfun\$[\w$]+)", match[1]) is not None
                    and match[2] == source.name and int(match[3]) in lines)
        return False
    if "firrtl.passes.CheckWidths$BitsWidthException" in output:
        if region.get("source_basename_unique") is not True:
            return False
        if re.search(r"error downloading|resolutionerror|cannot find include|"
                     r"no such file or directory", output, re.I):
            return False
        diagnostic = re.compile(
            r"^firrtl\.passes\.CheckWidths\$BitsWidthException:\s+@\["
            + re.escape(source.name) + r" (\d+):\d+\]: \[target ~[^|\s]+\|"
            + module + r"\] .+$")
        allowed = {"firrtl.passes.CheckWidths$BitsWidthException",
                   "firrtl.passes.PassExceptions", "firrtl.passes.PassException"}
        found = False
        for line in output.splitlines():
            line = line.strip()
            if line.startswith("[error]"):
                line = line[len("[error]"):].strip()
            elif not re.match(r"(?:Exception in thread|Caused by:|[\w.$]*(?:Exception|Error):)", line):
                continue
            line = re.sub(r'^Exception in thread "[^"]+" (?=firrtl\.passes\.PassExceptions:)', "", line)
            if line.startswith("firrtl.") and line.split(":", 1)[0] not in allowed:
                return False
            exceptions = re.findall(r"\b[\w.$]*(?:Exceptions?|Error)\b", line)
            if any(exception not in allowed for exception in exceptions):
                return False
            if "firrtl.passes.CheckWidths$BitsWidthException" in line:
                match = diagnostic.fullmatch(line)
                if match is None or int(match[1]) not in lines:
                    return False
                found = True
        return found
    unknown_width = re.search(r'ChiselException: Width of ' + module + r'\.[^\n]+ is unknown!', output)
    if unknown_width:
        frame = re.compile(r"^\s*at [\w.$]+\." + re.escape(name) +
                           r"\.<init>\(" + re.escape(source.name) + r":(\d+)\)\s*$")
        if any((match := frame.match(line)) and int(match[1]) in lines for line in output.splitlines()):
            return True
    if region.get("empty_body") is True:
        diagnostic = re.compile(r'^(.+?\.scala):(\d+):\d+: error: sink "[^"]+" not fully initialized in "' + module + r'"$')
        for line in output.splitlines():
            match = diagnostic.match(line.strip())
            if match:
                path = Path(match[1])
                path = path if path.is_absolute() else cwd / path
                if path.resolve() == source.resolve():
                    return True
    return False


def _duplicate_companion(message: str, diagnostic_line: int, text: str,
                         region: dict[str, object]) -> bool:
    name = region.get("class_name")
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        return False
    if message != f"{name} is already defined as object {name}":
        return False
    masked = _code_mask(text)
    packages = re.findall(r"(?m)^[ \t]*package\b[^\n]*", masked)
    if len(packages) > 1 or any(not re.fullmatch(
            r"[ \t]*package\s+[A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)*[ \t]*;?[ \t]*",
            package) for package in packages):
        return False
    objects = []
    for match in re.finditer(r"(?m)^[ \t]*object\s+" + re.escape(name) + r"\b", masked):
        prefix = masked[:match.start()]
        if prefix.count("{") == prefix.count("}"):
            objects.append(text[:match.start()].count("\n") + 1)
    candidate_lines = set(region["candidate_lines"])
    try:
        start, _ = definition_span(text, name, allow_braceless=True)
    except ValueError:
        return False
    prefix = masked[:start]
    if (prefix.count("{") != prefix.count("}")
            or text[:start].count("\n") + 1 not in candidate_lines):
        return False
    return (len(objects) == 2 and diagnostic_line in objects
            and sum(line in candidate_lines for line in objects) == 1)


def _chisel_elaboration_error(output: str, region: dict[str, object], source: Path,
                              text: str, cwd: Path) -> bool:
    if re.search(r"error downloading|resolutionerror|cannot find include|no such file or directory|"
                 r"no space left on device|permission denied|segmentation fault", output, re.I):
        return False
    lines = output.splitlines()
    heads = [i for i, line in enumerate(lines) if line.startswith('Exception in thread ')]
    if len(heads) != 1 or any(line.strip().startswith("Caused by:") for line in lines):
        return False
    index = heads[0]
    header = lines[index]
    if any(re.search(r"\b[\w.$]+(?:Exception|Error)\b", line)
           for i, line in enumerate(lines) if i != index and not line.lstrip().startswith(("at ", "[warn]"))):
        return False
    name = re.escape(str(region["class_name"]))
    module = name + r"(?:_Anon)?(?:_\d+)?"
    errors = [line for line in lines if line.startswith("[error]") or re.search(r"(?:^|: )error:", line)]
    if header.startswith('Exception in thread "main" circt.stage.phases.Exceptions$FirtoolNonZeroExitCode:'):
        sinks = region.get("reference_driven_sinks", {})
        pattern = re.compile(r'(.+?\.scala):(\d+):\d+: error: sink "(\w+)" not fully initialized in "' + module + '"')
        for line in errors:
            match = pattern.fullmatch(line)
            if (not match or (cwd / match[1]).resolve() != source.resolve()
                    or sinks.get(match[3]) != int(match[2])):
                return False
        return bool(errors)
    if header.startswith('Exception in thread "main" chisel3.internal.Errors: Fatal errors during hardware elaboration.'):
        diagnostics = [line for line in errors if re.match(r"\[error\] \S", line)]
        if not diagnostics or any(not line.startswith("[error]") for line in errors):
            return False
        summary = re.fullmatch(r"\[error\] There (?:was|were) (\d+) error\(s\)(?: and \d+ warning\(s\))? during hardware elaboration\.", diagnostics[-1])
        if not summary or int(summary[1]) != len(diagnostics) - 1 or not int(summary[1]):
            return False
        for line in diagnostics[:-1]:
            match = re.fullmatch(r"\[error\] (.+?\.scala):(\d+):\d+: High index \d+ is out of range \[\d+, \d+\]", line)
            if (not match or (cwd / match[1]).resolve() != source.resolve()
                    or int(match[2]) not in region["candidate_lines"]):
                return False
        return True
    readonly = re.fullmatch(r'Exception in thread "main" chisel3\.package\$ChiselException: Cannot reassign to read-only '
                            + module + r'\.\?: OpResult\[(?:Bool|[US]Int<\d+>)\]', header)
    bare_type = re.fullmatch(r'Exception in thread "main" chisel3\.package\$ExpectedHardwareException: data to be connected '
                             r"'(?:Bool|[US]Int<\d+>)' must be hardware, not a bare Chisel type\..*", header)
    if errors or not (readonly or bare_type):
        return False
    masked = _code_mask(text)
    packages = re.findall(r"(?m)^[ \t]*package\s+(\w+(?:\.\w+)*)[ \t]*$", masked)
    if len(packages) != 1 or len(re.findall(r"(?m)^[ \t]*package\b", masked)) != 1:
        return False
    qualified = re.escape(packages[0]) + r"\." + name
    for line in lines[index + 1:]:
        if line.strip() == "at ... ()":
            continue
        frame = re.fullmatch(r"at " + qualified + r"\.(?:<init>|\$anonfun\$[\w$]+)\(([^():]+):(\d+)\)", line.strip())
        return bool(frame and frame[1] == source.name and int(frame[2]) in region["candidate_lines"])
    return False


def _structured_elaboration_error(output: str, region: dict[str, object], source: Path,
                                  text: str) -> bool:
    if re.search(r"error downloading|resolutionerror|cannot find include|no such file or directory", output, re.I):
        return False
    name = str(region["class_name"])
    lines = set(region["candidate_lines"])
    clean = [re.sub(r"^\[error\]\s*", "", line.strip()) for line in output.splitlines()]
    diagnostics = {"firrtl.passes.CheckFlows$WrongFlow",
                   "firrtl.passes.CheckInitialization$RefNotInitializedException"}
    allowed = diagnostics | {"firrtl.passes.PassExceptions", "firrtl.passes.PassException"}
    found = False
    for line in clean:
        if not line.startswith(("firrtl.", 'Exception in thread')):
            continue
        line = re.sub(r'^Exception in thread "[^"]+" (?=firrtl\.)', "", line)
        exceptions = re.findall(r"\b[\w.$]*(?:Exceptions?|Error|WrongFlow)\b", line)
        if any(exception not in allowed for exception in exceptions):
            return False
        if any(line.startswith(kind + ":") for kind in diagnostics):
            if region.get("source_basename_unique") is not True:
                return False
            if (name == "BoomTileModuleImp"
                    and source.as_posix().endswith("/generators/boom/src/main/scala/common/tile.scala")
                    and line.startswith("firrtl.passes.CheckInitialization$RefNotInitializedException:")):
                line = line.replace("[module BoomTile]", "[module BoomTileModuleImp]", 1)
            diagnostic = re.fullmatch(
                r"(?:" + "|".join(re.escape(kind) for kind in diagnostics) + r"):\s+@\["
                + re.escape(source.name) + r" (\d+):\d+\]\s*:\s*\[module "
                + re.escape(name) + r"(?:_Anon)?(?:_\d+)?\]\s+.+", line)
            if diagnostic is None or int(diagnostic[1]) not in lines:
                return False
            found = True
    if found:
        for line in clean:
            if line.startswith(("[warn]", "at ", "make:")):
                continue
            line = re.sub(r'^Exception in thread "[^"]+" (?=firrtl\.)', "", line)
            if any(token not in allowed for token in re.findall(r"\b[\w.$]*(?:Exceptions?|Error|WrongFlow)\b", line)):
                return False
        return True
    causes = [i for i, line in enumerate(clean) if line.startswith("Caused by:")]
    if len(causes) != 1:
        return False
    cause = clean[causes[0]]
    literal = re.fullmatch(
        r"Caused by: java\.lang\.IllegalArgumentException: requirement failed: The literal value "
        r"\d+ was elaborated with a specified width of \d+ bits, but at least \d+ bits are required\.", cause)
    connection = re.fullmatch(
        r"Caused by: chisel3\.internal\.ChiselException: Connection between sink .+ and source .+ failed @: .+", cause)
    if not (literal or connection):
        return False
    allowed = {"java.lang.reflect.InvocationTargetException", "java.lang.IllegalArgumentException",
               "chisel3.internal.ChiselException"}
    for line in clean:
        if line.startswith(("[warn]", "at ", "make:")):
            continue
        if any(token not in allowed for token in re.findall(r"\b[\w.$]*(?:Exception|Error)\b", line)):
            return False
    masked = _code_mask(text)
    packages = re.findall(r"(?m)^[ \t]*package\s+([A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)*)[ \t]*;?[ \t]*$", masked)
    if len(packages) != 1 or len(re.findall(r"(?m)^[ \t]*package\b", masked)) != 1:
        return False
    try:
        start, _ = definition_span(text, name, allow_braceless=True)
    except ValueError:
        return False
    if (masked[:start].count("{") != masked[:start].count("}")
            or text[:start].count("\n") + 1 not in lines):
        return False
    qualified = packages[0] + "." + name
    frame = re.compile(r"at ([\w.$<>]+)\(([^():]+\.scala):(\d+)\)")
    for line in clean[causes[0] + 1:]:
        match = frame.fullmatch(line)
        if match is None:
            continue
        if re.fullmatch(re.escape(qualified) + r"\.(?:<init>|\$anonfun\$[\w$]+)", match[1]):
            return match[2] == source.name and int(match[3]) in lines
        if literal and match[1].startswith(("chisel3.SIntFactory.",
                                           "Chisel.package$SIntFactory.", "Chisel.package$SInt$.")):
            continue
        if not match[1].startswith(("chisel3.internal.", "chisel3.UIntFactory.",
                                    "chisel3.package$", "chisel3.Data.", "scala.", "java.")):
            return False
    return False


def candidate_compile_error(output: str, code: int, region: dict[str, object], cwd: Path) -> bool:
    if code in {0, 124, 137, 143} or code < 0:
        return False
    output = re.sub(r"\x1b\[[0-9;]*m", "", output)
    if re.search(r"unresolved dependenc|error downloading|failed to download|resolutionerror|"
                 r"cannot find include|package/class .+ not found|command not found|"
                 r"no such file or directory|internal (?:compiler )?error|stackoverflowerror|"
                 r"outofmemoryerror|compiler crash|exception in thread", output, re.IGNORECASE):
        return False
    try:
        source = Path(str(region["source"]))
        source_bytes = source.read_bytes()
        if hashlib.sha256(source_bytes).hexdigest() != region["source_sha256"]:
            return False
        lines = set(region["candidate_lines"])
    except (OSError, KeyError, TypeError, ValueError):
        return False
    diagnostic = re.compile(r"^(?:\[error\]\s*)?(.+?\.scala):(\d+)(?::\d+)?:\s*(.*)$")
    syntax = re.compile(r"^(?:'[^']+'|identifier|type|class or object definition) expected\b|"
                        r"^illegal start of|^unclosed (?:string|character|comment)|"
                        r"^unterminated (?:string|character|comment)", re.IGNORECASE)
    for line in output.splitlines():
        match = diagnostic.match(line.strip())
        if match is None:
            continue
        if not syntax.search(match[3]) and not (
            "compilation failed" in output.lower() and line.strip().startswith("[error]")
        ):
            continue
        path = Path(match[1])
        path = path if path.is_absolute() else cwd / path
        exact_source = path.resolve() == source.resolve()
        basename_source = (len(Path(match[1]).parts) == 1 and Path(match[1]).name == source.name
                           and region.get("source_basename_unique") is True)
        if (region.get("class_name") == "BoomCore"
                and line.lstrip().startswith("[error]") and "compilation failed" in output.lower()
                and match[3] == "value coreMonitorBundle is not a member of boom.exu.BoomCore"
                and source.resolve() == (cwd / "generators/boom/src/main/scala/exu/core.scala").resolve()
                and path.resolve() == (cwd / "generators/chipyard/src/main/scala/Subsystem.scala").resolve()
                and int(match[2]) == 56):
            try:
                consumer = path.read_bytes()
            except OSError:
                continue
            if hashlib.sha256(consumer).hexdigest() == "4809349f4e4ce7d9f7e569b8a7b57f4b08ce82efb000ffcc6fc5ff2d6956dc8b":
                return True
        if (region.get("class_name") == "BoomMSHRFile"
                and line.lstrip().startswith("[error]") and "compilation failed" in output.lower()
                and match[3] == "value io is not a member of boom.lsu.BoomMSHRFile"
                and source.resolve() == (cwd / "generators/boom/src/main/scala/lsu/mshrs.scala").resolve()
                and path.resolve() == (cwd / "generators/boom/src/main/scala/lsu/dcache.scala").resolve()
                and int(match[2]) == 433):
            try:
                consumer = path.read_bytes()
            except OSError:
                continue
            if hashlib.sha256(consumer).hexdigest() == "dceed1df786cf05dd7892035988c3f1301ec4a4ba0f33a1fb4d25f9f7e668d6c":
                return True
        if (region.get("class_name") == "L1MetadataArray"
                and line.lstrip().startswith("[error]") and "compilation failed" in output.lower()
                and match[3] == ("value io is not a member of "
                                 "freechips.rocketchip.rocket.L1MetadataArray[freechips.rocketchip.rocket.L1Metadata]")
                and source.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/HellaCache.scala").resolve()
                and path.resolve() == (cwd / "generators/rocket-chip/src/main/scala/rocket/NBDcache.scala").resolve()
                and int(match[2]) == 775):
            try:
                consumer = path.read_bytes()
            except OSError:
                continue
            if hashlib.sha256(consumer).hexdigest() == "5324e1ac9899c21226e4663de5dd91bada76d7ae4d38443b66d4f70f378a3553":
                return True
        if (exact_source and region.get("class_name") == "LoopBranchPredictorColumn"
                and match[3] == "not found: type LoopBranchPredictorColumn"
                and source.resolve() == (cwd / "generators/boom/src/main/scala/ifu/bpd/loop.scala").resolve()):
            consumer_line = int(match[2])
            masked = _code_mask(source_bytes.decode())
            source_lines = masked.splitlines()
            if (consumer_line not in lines and 0 < consumer_line <= len(source_lines)
                    and source_lines[consumer_line - 1].strip() == (
                        "val columns = Seq.fill(bankWidth) { Module(new LoopBranchPredictorColumn) }")):
                wrappers = [entry for entry in re.finditer(r"(?m)^[ \t]*class[ \t]+LoopBranchPredictorBank\b", masked)
                            if masked[:entry.start()].count("\n") + 1 in lines]
                if len(wrappers) == 1:
                    submitted = masked[wrappers[0].start():]
                    try:
                        begin, end = definition_span(submitted, "LoopBranchPredictorBank", allow_braceless=True)
                    except ValueError:
                        continue
                    if re.search(r"(?m)^[ \t]*class[ \t]+LoopBranchPredictorColumn\b", submitted[begin:end]):
                        return True
        if (exact_source and region.get("class_name") == "DivSqrtRecF64"
                and match[3] == "Mul54 is already defined as class Mul54"
                and source.resolve() == (cwd / "generators/rocket-chip/hardfloat/src/main/scala/DivSqrtRecF64.scala").resolve()):
            masked = _code_mask(source_bytes.decode())
            declarations = []
            for declaration in re.finditer(r"(?m)^[ \t]*class[ \t]+Mul54\b", masked):
                prefix = masked[:declaration.start()]
                if prefix.count("{") == prefix.count("}"):
                    declarations.append(prefix.count("\n") + 1)
            if len(declarations) == 2 and int(match[2]) in declarations and len(lines.intersection(declarations)) == 1:
                return True
        if (exact_source or basename_source) and _duplicate_companion(
                match[3], int(match[2]), source_bytes.decode(), region):
            return True
        if exact_source and int(match[2]) in lines:
            return True
    return False


if __name__ == "__main__":
    import json
    args = sys.argv[1:]
    classify = candidate_compile_error
    if args and args[0] == "--elaboration":
        classify = candidate_elaboration_error
        args = args[1:]
    if len(args) != 4:
        raise SystemExit("usage: scala_compile_diagnostics.py [--elaboration] LOG STATUS REGION CWD")
    log, status, region_path, cwd = args
    matched = classify(Path(log).read_text(errors="replace"), int(status),
                       json.loads(Path(region_path).read_text()), Path(cwd))
    raise SystemExit(0 if matched else 2)
