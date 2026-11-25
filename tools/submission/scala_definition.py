"""Locate, extract and replace Scala class definitions in submissions."""

from __future__ import annotations

import re


_DECLARATION = r"(?:(?:abstract|case|final|sealed)\s+)*class"


def _string_end(text: str, opening: int) -> int:
    delimiter = '"""' if text.startswith('"""', opening) else '"'
    interpolated = opening > 0 and (text[opening - 1].isalnum() or text[opening - 1] in "_$`")
    index = opening + len(delimiter)
    while index < len(text):
        if text.startswith(delimiter, index):
            end = index + len(delimiter)
            if delimiter == '"""':
                while end < len(text) and text[end] == '"':
                    end += 1
            return end
        if interpolated and text.startswith("$$", index):
            index += 2
        elif interpolated and text.startswith("${", index):
            depth = 1
            index += 2
            while index < len(text) and depth:
                end = _non_code_end(text, index)
                if end is not None:
                    index = end
                    continue
                if text[index] == "{":
                    depth += 1
                elif text[index] == "}":
                    depth -= 1
                index += 1
        elif delimiter == '"' and text[index] == "\\":
            index += 2
        else:
            index += 1
    return len(text)


def _non_code_end(text: str, index: int) -> int | None:
    if text.startswith("//", index):
        newline = text.find("\n", index + 2)
        return len(text) if newline < 0 else newline
    if text.startswith("/*", index):
        depth = 1
        index += 2
        while index < len(text) and depth:
            if text.startswith("/*", index):
                depth += 1
                index += 2
            elif text.startswith("*/", index):
                depth -= 1
                index += 2
            else:
                index += 1
        return index
    if text[index] == '"':
        return _string_end(text, index)
    if text[index] == "`":
        closing = text.find("`", index + 1)
        return len(text) if closing < 0 else closing + 1
    if text[index] == "'":
        literal = re.match(r"'(?:\\.|[^'\\\r\n])'", text[index:])
        if literal:
            return index + len(literal.group())
    return None


def _code_mask(text: str) -> str:
    masked = list(text)
    index = 0
    while index < len(text):
        end = _non_code_end(text, index)
        if end is None:
            index += 1
            continue
        for position in range(index, min(end, len(text))):
            if text[position] != "\n":
                masked[position] = " "
        index = end
    return "".join(masked)


def _class_matches(text: str, name: str) -> list[re.Match[str]]:
    mask = _code_mask(text)
    pattern = re.compile(rf"(?m)^\s*{_DECLARATION}\s+{re.escape(name)}\b")
    return [
        match for match in pattern.finditer(text)
        if mask[match.end() - len(name):match.end()] == name
    ]


def _matching_brace(text: str, opening: int) -> int:
    depth = 0
    state = "code"
    block_depth = 0
    index = opening
    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if state == "line_comment":
            if char == "\n":
                state = "code"
        elif state == "block_comment":
            if char == "/" and nxt == "*":
                block_depth += 1
                index += 1
            elif char == "*" and nxt == "/":
                block_depth -= 1
                index += 1
                if block_depth == 0:
                    state = "code"
        elif state in {"string", "char"}:
            quote = '"' if state == "string" else "'"
            if char == "\\":
                index += 1
            elif char == quote:
                state = "code"
        elif char == "/" and nxt == "/":
            state = "line_comment"
            index += 1
        elif char == "/" and nxt == "*":
            state = "block_comment"
            block_depth = 1
            index += 1
        elif char == '"':
            state = "string"
        elif char == "'":
            state = "char"
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    raise ValueError("requested class has an unterminated body")


def _body_opening_or_definition_end(text: str, start: int) -> tuple[int | None, int]:
    paren_depth = 0
    bracket_depth = 0
    state = "code"
    block_depth = 0
    index = start
    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if state == "line_comment":
            if char == "\n":
                state = "code"
        elif state == "block_comment":
            if char == "/" and nxt == "*":
                block_depth += 1
                index += 1
            elif char == "*" and nxt == "/":
                block_depth -= 1
                index += 1
                if block_depth == 0:
                    state = "code"
        elif state in {"string", "char"}:
            quote = '"' if state == "string" else "'"
            if char == "\\":
                index += 1
            elif char == quote:
                state = "code"
        elif char == "/" and nxt == "/":
            state = "line_comment"
            index += 1
        elif char == "/" and nxt == "*":
            state = "block_comment"
            block_depth = 1
            index += 1
        elif char == '"':
            state = "string"
        elif char == "'":
            state = "char"
        elif char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth -= 1
        elif char == "[":
            bracket_depth += 1
        elif char == "]":
            bracket_depth -= 1
        elif char == "{" and paren_depth == 0 and bracket_depth == 0:
            return index, index
        elif (
            char == "\n"
            and nxt == "\n"
            and paren_depth == 0
            and bracket_depth == 0
        ):
            return None, index
        index += 1
    return None, len(text.rstrip())


def definition_span(text: str, name: str, *, allow_braceless: bool = False) -> tuple[int, int]:
    matches = _class_matches(text, name)
    if not matches:
        raise ValueError(f"requested class was not found: {name}")
    if len(matches) != 1:
        raise ValueError(f"requested class is not unique: {name}")
    match = matches[0]
    opening, braceless_end = _body_opening_or_definition_end(text, match.end())
    if opening is None:
        if not allow_braceless:
            raise ValueError(f"requested class has no body: {name}")
        if re.search(rf"(?m)^\s*(?:class|object|trait)\s+", text[match.end():braceless_end]):
            raise ValueError("candidate contains an additional top-level definition")
        return match.start(), braceless_end
    return match.start(), _matching_brace(text, opening)


def _envelope_is_allowed(text: str, *, allow_header: bool) -> bool:
    index = 0
    while index < len(text):
        if text[index].isspace():
            index += 1
        elif text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
        elif text.startswith("/*", index):
            depth = 1
            index += 2
            while index < len(text) and depth:
                if text.startswith("/*", index):
                    depth += 1
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            if depth:
                return False
        elif allow_header:
            declaration = re.match(r"(?:package|import)\s+[^\n;]+(?:;|\n|$)", text[index:])
            if declaration is None:
                return False
            index += declaration.end()
        else:
            return False
    return True


def candidate_definition(text: str, name: str, *, allow_braceless: bool = True) -> str:
    start, end = definition_span(text, name, allow_braceless=allow_braceless)
    if not _envelope_is_allowed(text[:start], allow_header=True):
        raise ValueError("candidate prefix contains content other than package, imports, or comments")
    if not _envelope_is_allowed(text[end:], allow_header=False):
        raise ValueError("candidate suffix contains content other than comments")
    return text[start:end]


class CandidateDefinitionError(ValueError):
    """The submitted text demonstrably violates the required class declaration."""


def integrate_submission(base: str, candidate: str, name: str) -> str:
    """Return `base` with class `name` replaced by the submitted class and the declarations around it."""
    base_start, base_end = definition_span(base, name, allow_braceless=True)
    requested = _class_matches(candidate, name)
    if not requested:
        if name not in candidate and r"\u" not in candidate:
            raise CandidateDefinitionError(f"submitted text does not contain the required class name {name}")
        raise ValueError(f"requested class was not found: {name}")
    if len(requested) != 1:
        # Two successive declarations in the same scope prove duplication.
        # Matches in nested classes or separate packages need further interpretation.
        first, second = requested[:2]
        exact_names = all(
            not candidate[m.end():m.end() + 1]
            or candidate[m.end()].isspace() or candidate[m.end()] in "([{;"
            for m in (first, second)
        )
        if exact_names and _envelope_is_allowed(candidate[:first.start()], allow_header=True):
            try:
                candidate_definition(_code_mask(candidate[first.start():second.start()]), name)
            except ValueError:
                pass
            else:
                raise CandidateDefinitionError(f"submitted text declares class {name} twice in the same scope")
        raise ValueError(f"requested class is not unique: {name}")
    class_start = requested[0].start()
    prefix = re.sub(r"(?m)^\s*package\s+[^\n;]+(?:;|$)\s*", "", candidate[:class_start])
    submitted_declarations = prefix + candidate[class_start:]
    suffix = base[base_end:]
    if submitted_declarations.endswith("\n") and suffix.startswith("\n"):
        suffix = suffix[1:]
    integrated = base[:base_start] + submitted_declarations + suffix
    if not integrated.endswith("\n"):
        integrated += "\n"
    return integrated


def prepare_submission(candidate: str, name: str, fixed_header: str) -> str:
    requested = _class_matches(candidate, name)
    if not requested:
        raise ValueError(f"requested class was not found: {name}")
    if len(requested) != 1:
        raise ValueError(f"requested class is not unique: {name}")
    if re.search(r"(?m)^\s*package\s+", _code_mask(candidate)):
        submission = candidate
    else:
        submission = fixed_header + candidate
    if not submission.endswith("\n"):
        submission += "\n"
    return submission
