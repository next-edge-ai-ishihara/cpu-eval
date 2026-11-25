#!/usr/bin/env python3
import json
from pathlib import Path
import re
import sys


def observe(text, require_paths=False):
    events, transactions, errors, invalid = [], [], [], []
    latest = {}
    presentation = active = None
    sequence = issues = accepted = rejected = 0
    format_seen = False
    for line in text.splitlines():
        if not line.startswith("CPU_EVAL_CVXIF "):
            continue
        if line == "CPU_EVAL_CVXIF FORMAT version=3":
            if format_seen:
                invalid.append("duplicate observation format header")
            format_seen = True
            continue
        if not format_seen:
            invalid.append("observation format header is missing")
        if line == "CPU_EVAL_CVXIF RESET":
            if any(t["complete"] and not t["notified"] for t in transactions):
                invalid.append("reset interrupts an unnotified completion")
            transactions, latest = [], {}
            presentation = active = None
            events.append(dict(kind="reset"))
            continue
        if line == "CPU_EVAL_CVXIF END_PRESENT":
            presentation = None
            continue
        match = re.fullmatch(r"CPU_EVAL_CVXIF (PRESENT|START|CANCEL) hart=(\d+) id=(\d+)", line)
        if match:
            kind, hart, identity = match.groups()
            key = int(hart), int(identity)
            if kind == "PRESENT":
                if presentation is None or presentation["key"] != key:
                    sequence += 1
                    presentation = dict(key=key, sequence=sequence, notified=False)
                    latest[key] = presentation
                continue
            events.append(dict(kind=kind.lower(), hart=key[0], id=key[1]))
            if kind == "START":
                if active is not None:
                    invalid.append("request starts without completion or cancellation")
                if presentation is None:
                    errors.append("request has no CPU presentation")
                elif presentation["key"] != key:
                    errors.append("request identity differs from the fixed parent instruction")
                sequence_number = presentation["sequence"] if presentation is not None else None
                active = dict(hart=key[0], id=key[1], sequence=sequence_number,
                              complete=False, notified=False)
                if presentation is not None:
                    presentation["notified"] = False
                transactions.append(active)
            elif active is None or (active["hart"], active["id"]) != key:
                invalid.append("cancellation has no matching request")
            else:
                transactions.remove(active)
                active = None
            continue
        match = re.fullmatch(r"CPU_EVAL_CVXIF ISSUE hart=(\d+) id=(\d+) accept=([01])", line)
        if match:
            hart, identity, accept = map(int, match.groups())
            events.append(dict(kind="issue", hart=hart, id=identity, accept=accept))
            issues += 1
            accepted += accept
            rejected += 1 - accept
            if active is None or (active["hart"], active["id"]) != (hart, identity):
                invalid.append("completion has no matching request start")
            else:
                active["complete"] = True
                active = None
            continue
        match = re.fullmatch(r"CPU_EVAL_CVXIF COMMIT hart=(\d+) id=(\d+) kill=([01])", line)
        if match:
            hart, identity, kill = map(int, match.groups())
            events.append(dict(kind="commit", hart=hart, id=identity, kill=kill))
            if kill:
                errors.append("kill is unsupported by the selected CVA6 configuration")
                continue
            boundary = latest.get((hart, identity))
            if boundary is not None:
                if boundary["notified"]:
                    continue
                affected = [t for t in transactions if t["hart"] == hart and not t["notified"]
                            and t["sequence"] is not None
                            and t["sequence"] <= boundary["sequence"]]
                for entry in latest.values():
                    if entry["key"][0] == hart and entry["sequence"] <= boundary["sequence"]:
                        entry["notified"] = True
                for transaction in affected:
                    transaction["notified"] = True
            continue
        invalid.append("malformed observation event")
    pending = [[t["hart"], t["id"]] for t in transactions if t["complete"] and not t["notified"]]
    missing_paths = require_paths and (accepted == 0 or rejected == 0)
    result = dict(events=events, issues=issues, accepted=accepted, rejected=rejected,
                  pending=pending, errors=errors, invalid=invalid)
    # A missing header or a split line comes from the fixed observer and its output stream; Verilator is
    # two-state, so every other irregular sequence comes from the submitted driver.
    observer_broken = not format_seen or bool({"duplicate observation format header",
                                               "malformed observation event"} & set(invalid))
    result["exit"] = 2 if observer_broken else (
        1 if invalid or issues == 0 or errors or pending or missing_paths else 0)
    return result


if __name__ == "__main__":
    source = Path(sys.argv[1])
    result = observe(source.read_text(errors="replace"), "cvxif-commit-notifications" in source.name)
    Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    sys.exit(result["exit"])
