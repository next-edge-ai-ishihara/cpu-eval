#!/usr/bin/env python3
"""Write or check the configuration that TestIndividualFeatures draws for the evaluated test ID."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


CPU_ROOT = Path(__file__).resolve().parents[1]
RECORD = CPU_ROOT / "REGRESSION_CONFIGURATION.txt"
MASK = (1 << 48) - 1


class JavaRandom:
    def __init__(self, seed: int) -> None:
        self.seed = (seed ^ 0x5DEECE66D) & MASK

    def next(self, bits: int) -> int:
        self.seed = (self.seed * 0x5DEECE66D + 0xB) & MASK
        value = self.seed >> (48 - bits)
        return value - (1 << 32) if value >= 1 << 31 else value

    def next_int(self, bound: int | None = None) -> int:
        if bound is None:
            return self.next(32)
        if bound & -bound == bound:
            return (bound * self.next(31)) >> 31
        while True:
            bits = self.next(31)
            value = bits % bound
            if -(1 << 31) <= bits - value + bound - 1 < 1 << 31:
                return value

    def next_boolean(self) -> bool:
        return self.next(1) != 0

    def next_double(self) -> float:
        return ((self.next(26) << 27) + self.next(27)) * (1.0 / (1 << 53))

    def choice(self, values: list):
        return values[self.next_int(len(values))]


def scala(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return "null" if value is None else str(value)


class Position:
    def __init__(self, dimension: str, name: str, values: dict, test_param: str = "",
                 anticipated: bool | None = None, needs_anticipation: bool = False) -> None:
        self.dimension, self.name, self.values, self.test_param = dimension, name, values, test_param
        self.anticipated, self.needs_anticipation = anticipated, needs_anticipation


def ibus(u: set[str], r: JavaRandom, rvc_rate: float) -> Position:
    catch_all, cache_all = "CATCH_ALL" in u, "CACHE_ALL" in u
    if "MMU" in u:
        raise ValueError("an MMU universe draws from the unseeded global Random")
    if r.next_double() < 0.5 and not cache_all:
        latency = r.next_int(5) + 1
        compressed = r.next_double() < rvc_rate
        injector = r.next_boolean() or latency == 1
        prediction = r.choice(["NONE", "STATIC", "DYNAMIC", "DYNAMIC_TARGET"])
        fork, persistence = r.next_boolean(), r.next_boolean()
        name = (f"Simple{latency}" + ("S2" if fork else "") + ("P" if persistence else "")
                + ("InjStage" if injector else "") + ("Rvc" if compressed else "")
                + f"vexriscv.plugin.{prediction}")
        values = {"mmuConfig": None, "latency": latency, "compressed": compressed,
                  "injectorStage": injector, "prediction": prediction, "catchAll": catch_all,
                  "cmdForkOnSecondStage": fork, "cmdForkPersistence": persistence}
        return Position("IBus", name, values, "IBUS=SIMPLE" + (" COMPRESSED=yes" if compressed else ""),
                        anticipated=injector)
    raise ValueError("the cached instruction bus is not selected by the evaluated test ID")


def dbus(u: set[str], r: JavaRandom) -> Position:
    catch_all, cache_all = "CATCH_ALL" in u, "CACHE_ALL" in u
    no_memory, no_write_back = "NO_MEMORY" in u, "NO_WRITEBACK" in u
    if (r.next_double() < 0.4 or no_memory) and not cache_all:
        raise ValueError("the simple data bus is not selected by the evaluated test ID")
    two_stage_mmu = r.next_boolean() and not no_memory and not no_write_back
    mem_width = [32, 64, 128][r.next_int(3)]
    cpu_choices = [width for width in (32, 64, 128) if width <= mem_width]
    cpu_width = cpu_choices[r.next_int(len(cpu_choices))]
    byte_per_line = max(mem_width // 8, [8, 16, 32, 64][r.next_int(4)])
    with_lr_sc = catch_all
    with_smp = with_lr_sc and r.next_boolean()
    with_amo = (catch_all and r.next_boolean()) or with_smp
    rsp_slave_pipe = r.next_boolean() or with_smp
    relaxed = r.next_boolean()
    early_ways_hits = r.next_boolean() and not no_write_back
    direct_tlb_hit = r.next_boolean() and False
    async_tag_memory = r.next_boolean()
    while True:
        cache_size = 512 << r.next_int(5)
        way_count = 1 << r.next_int(3)
        if not (cache_size // way_count < 512 or (catch_all and cache_size // way_count > 4096)):
            break
    flags = [("Cmp ", False), ("Csp ", False), ("Rsp ", rsp_slave_pipe), ("Rmtr ", relaxed),
             ("Ewh ", early_ways_hits), ("Amo ", with_amo), ("Smp ", with_smp), ("Dtlb ", direct_tlb_hit),
             ("Tsmmu ", two_stage_mmu), ("Atm", async_tag_memory)]
    name = (f"Cached{mem_width}d{cpu_width}cS{cache_size}W{way_count}BPL{byte_per_line}"
            + "".join(text for text, enabled in flags if enabled))
    values = {"catchAll": catch_all, "twoStageMmu": two_stage_mmu, "mmuConfig": None,
              "memDataWidth": mem_width, "cpuDataWidth": cpu_width, "bytePerLine": byte_per_line,
              "cacheSize": cache_size, "wayCount": way_count, "withLrSc": with_lr_sc, "withSmp": with_smp,
              "withAmo": with_amo, "dBusRspSlavePipe": rsp_slave_pipe,
              "relaxedMemoryTranslationRegister": relaxed, "earlyWaysHits": early_ways_hits,
              "directTlbHit": direct_tlb_hit, "dBusCmdMasterPipe": False, "dBusCmdSlavePipe": False,
              "asyncTagMemory": async_tag_memory}
    param = (f"DBUS=CACHED DBUS_LOAD_DATA_WIDTH={mem_width} DBUS_STORE_DATA_WIDTH={cpu_width} "
             + ("LRSC=yes " if with_lr_sc else "") + ("AMO=yes " if with_amo else "")
             + ("DBUS_EXCLUSIVE=yes DBUS_INVALIDATE=yes " if with_smp else ""))
    return Position("DBus", name, values, param)


def mul_div(u: set[str], r: JavaRandom) -> Position:
    no_memory, no_write_back = "NO_MEMORY" in u, "NO_WRITEBACK" in u
    names = ["MulDivFpgaSimple"]
    if not no_memory and not no_write_back:
        names.insert(0, "MulDivFpga16BitsDsp")
    if not no_memory:
        names[:0] = ["MulDivAsic", "MulDivFpgaNoDsp", "MulDivFpgaNoDspFastMul"]
    if "FORCE_MULDIV" not in u:
        names.insert(0, "NoMulDiv")
    if not no_memory and not no_write_back:
        names.insert(0, f"MulDivFpga{scala(r.next_boolean())}{scala(r.next_boolean())}")
    name = r.choice(names)
    return Position("MulDiv", name, {}, "MUL=no DIV=no" if name == "NoMulDiv" else "MUL=yes DIV=yes")


def shift(u: set[str], r: JavaRandom) -> Position:
    names = ["FullEarly", "Light"] if "NO_MEMORY" in u else ["FullLate", "FullEarly", "Light"]
    return Position("Shift", r.choice(names), {})


def branch(u: set[str], r: JavaRandom) -> Position:
    early = r.next_boolean() or "NO_MEMORY" in u
    return Position("Branch", "Early" if early else "Late", {"catchAll": "CATCH_ALL" in u, "early": early})


def hazard(u: set[str], r: JavaRandom) -> Position:
    if r.next_double() < 0.8:
        name = r.choice(["Interlock", "BypassAll"])
    else:
        name = r.choice(["BypassExecute", "BypassMemory", "BypassWriteBack", "BypassWriteBackBuffer"])
    return Position("Hazard", name, {})


def reg_file(u: set[str], r: JavaRandom) -> Position:
    execute_rf = "EXECUTE_RF" in u
    kind = r.choice(["ASYNC", "SYNC"])
    name = ("Async" if kind == "ASYNC" else "Sync") + ("ER" if execute_rf else "DR")
    return Position("RegFile", name, {"executeRf": execute_rf, "regFileReadyKind": f"plugin.{kind}"},
                    needs_anticipation=kind == "SYNC" and not execute_rf)


def src(u: set[str], r: JavaRandom) -> Position:
    separated = r.next_boolean()
    execute_insertion = "EXECUTE_RF" in u or r.next_boolean()
    name = ("AddSub" if separated else "") + ("Execute" if execute_insertion else "")
    return Position("Src", name, {"separatedAddSub": separated, "executeInsertion": execute_insertion})


def csr(u: set[str], r: JavaRandom, zephyr: str, linux: str) -> Position:
    if "SUPERVISOR" in u:
        return Position("Csr", "Supervisor", {},
                        f"FREERTOS=0 ZEPHYR={zephyr} LINUX_REGRESSION={linux} SUPERVISOR=yes CSR=yes")
    if "PMP" in u or "PMPNAPOT" in u:
        return Position("Csr", "Secure", {}, f"CSR=yes CSR_SKIP_TEST=yes FREERTOS=0 ZEPHYR={zephyr}")
    if "CATCH_ALL" in u:
        # 0001-enable-selected-csr-tests.patch changes this test parameter to CSR_SKIP_TEST=no.
        return Position("Csr", "MachineOs", {}, f"CSR=yes CSR_SKIP_TEST=no FREERTOS=0 ZEPHYR={zephyr}")
    if r.next_double() < 0.3:
        return Position("Csr", "AllNoException", {}, f"CSR=yes CSR_SKIP_TEST=yes FREERTOS=0 ZEPHYR={zephyr}")
    return Position("Csr", "None", {}, "CSR=no")


def decoder(u: set[str], r: JavaRandom) -> Position:
    return Position("Decoder", "", {"catchAll": "CATCH_ALL" in u})


def debug(u: set[str], r: JavaRandom) -> Position:
    name = r.choice(["None", "Enable"])
    return Position("Debug", name, {}, "DEBUG_PLUGIN=no" if name == "None" else "CONCURRENT_OS_EXECUTIONS=yes")


def mmu_pmp(u: set[str], r: JavaRandom) -> Position:
    for universe, name, param in (("MMU", "WithMmu", "MMU=yes PMP=no"), ("PMP", "WithPmp", "MMU=no PMP=yes"),
                                  ("PMPNAPOT", "WithPmpNapot", "MMU=no PMP=yes")):
        if universe in u:
            return Position("DBus", name, {}, param)
    return Position("DBus", "NoMemProtect", {}, "MMU=no PMP=no")


def universe_for(r: JavaRandom, rate: dict[str, float]) -> set[str]:
    u = set()
    if r.next_double() < 0.5:
        u.add("EXECUTE_RF")
    if rate["LINUX"] > r.next_double():
        u |= {"CATCH_ALL", "MMU", "FORCE_MULDIV", "SUPERVISOR"}
        if rate["DEMW"] < r.next_double():
            u.add("NO_WRITEBACK")
    elif rate["SECURE"] > r.next_double():
        u |= {"CACHE_ALL", "CATCH_ALL"}
        u.add("PMP" if rate["PMP_NAPOT_RANGE"] > r.next_double() else "PMPNAPOT")
        if rate["DEMW"] < r.next_double():
            u.add("NO_WRITEBACK")
    else:
        if rate["MACHINE_OS"] > r.next_double():
            u.add("CATCH_ALL")
            if rate["DEMW"] < r.next_double():
                u.add("NO_WRITEBACK")
        if rate["DEMW"] > r.next_double():
            pass
        elif rate["DEM"] > r.next_double():
            u.add("NO_WRITEBACK")
        else:
            u |= {"NO_WRITEBACK", "NO_MEMORY"}
    return u


def render(configuration: dict[str, str]) -> str:
    seed, test_id = int(configuration["VEXRISCV_REGRESSION_SEED"]), int(configuration["VEXRISCV_REGRESSION_TEST_ID"])
    rate = {key: float(configuration[f"VEXRISCV_REGRESSION_CONFIG_{key}_RATE"])
            for key in ("RVC", "LINUX", "MACHINE_OS", "SECURE", "DEMW", "DEM")}
    rate["PMP_NAPOT_RANGE"] = float(configuration["VEXRISCV_REGRESSION_CONFIG_PMP_NAPOT_RANGE"])
    zephyr = configuration["VEXRISCV_REGRESSION_ZEPHYR_COUNT"]
    linux = configuration.get("VEXRISCV_REGRESSION_LINUX_REGRESSION", "yes")
    r = JavaRandom(seed)
    for index in range(test_id + 1):
        u = universe_for(r, rate)
        while True:
            positions = [ibus(u, r, rate["RVC"]), dbus(u, r), mul_div(u, r), shift(u, r), branch(u, r),
                         hazard(u, r), reg_file(u, r), src(u, r), csr(u, r, zephyr, linux), decoder(u, r),
                         debug(u, r), mmu_pmp(u, r)]
            if all(not p.needs_anticipation or any(q.anticipated for q in positions) for p in positions):
                break
        test_seed = r.next_int()
    no_memory, no_write_back = "NO_MEMORY" in u, "NO_WRITEBACK" in u
    name = (("noMemoryStage_" if no_memory else "") + ("noWritebackStage_" if no_write_back else "")
            + "_".join(f"{p.dimension}_{p.name}" for p in positions))
    command = ("make run REGRESSION_PATH=../../src/test/cpp/regression VEXRISCV_FILE=VexRiscv.v WITH_USER_IO=no "
               "REDO=10 TRACE=yes TRACE_START=100000000000ll FLOW_INFO=no "
               f"STOP_ON_ERROR={configuration.get('VEXRISCV_REGRESSION_STOP_ON_ERROR', 'no')} DHRYSTONE=yes "
               f"COREMARK={configuration['VEXRISCV_REGRESSION_COREMARK']} THREAD_COUNT=1  SEED={test_seed} "
               + " ".join(p.test_param for p in positions))
    lines = [
        "# Written by harness/regression_configuration.py: the draws of TestIndividualFeatures for this seed and test ID.",
        "# The regression prints this START TEST line; the DebugPlugin problem prints CONCURRENT_OS_EXECUTIONS=no in the make line.",
        "",
        *[f"{key}={configuration[key]}" for key in sorted(configuration) if key.startswith("VEXRISCV_REGRESSION_")],
        "",
        f"START TEST test_id_{test_id}_{name}",
        command,
        "",
        "universe = " + ", ".join(sorted(u)),
        "",
        "VexRiscvConfig",
        f"  withMemoryStage = {scala(not no_memory)}",
        f"  withWriteBackStage = {scala(not no_write_back)}",
    ]
    for p in positions:
        lines += ["", f"{p.dimension} {p.name}".rstrip()]
        lines += [f"  {key} = {scala(value)}" for key, value in p.values.items()]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail unless the record matches")
    args = parser.parse_args()
    recipe = json.loads((CPU_ROOT / "TEST_RECIPE.json").read_text(encoding="utf-8"))
    text = render(recipe["configuration"])
    if args.check:
        if not RECORD.is_file() or RECORD.read_text(encoding="utf-8") != text:
            print(f"{RECORD} differs from the generated configuration", file=sys.stderr)
            return 1
        return 0
    RECORD.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
