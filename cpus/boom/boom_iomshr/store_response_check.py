"""Observe the uncached_msip program at the IOMSHR response port."""

import csv
import hashlib
from pathlib import Path
import re
import sys


ANCHOR = "    resp_arb.io.in(cfg.nMSHRs + i) <> mshr.io.resp"
MONITOR = """    val checkingOrdinaryStore = RegInit(false.B)
    when (mshr.io.req.fire) {
      val command = mshr.io.req.bits.uop.mem_cmd
      val ordinaryStore = isWrite(command) && !isRead(command)
      checkingOrdinaryStore := ordinaryStore
      when (ordinaryStore) { printf(p"CPU_EVAL_IOMSHR_STORE_ACCEPTED ${Hexadecimal(mshr.io.req.bits.addr)}\\n") }
    }
    when (checkingOrdinaryStore && !mshr.io.req.fire && mshr.io.resp.valid) {
      printf("CPU_EVAL_IOMSHR_UNEXPECTED_STORE_RESPONSE\\n")
    }

"""


def prepare(source, inventory, output):
    source = Path(source)
    original = source.read_bytes()
    with Path(inventory).open(newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        fieldnames = reader.fieldnames
        rows = list(reader)
    matching = [row for row in rows if row["definition_path"] == "generators/boom/src/main/scala/lsu/mshrs.scala"]
    if any(row["source_file_sha256"] != hashlib.sha256(original).hexdigest() for row in matching):
        raise SystemExit("IOMSHR monitor requires the pinned source")
    if sum(row["source_unit"] == "BoomIOMSHR" for row in matching) != 1:
        raise SystemExit("IOMSHR is absent from the source inventory")
    anchor = ANCHOR.encode()
    if original.count(anchor) != 1:
        raise SystemExit("IOMSHR response connection is not unique")
    prelude, remainder = original.split(anchor)
    updated = prelude + MONITOR.encode() + anchor + remainder
    for row in matching:
        row["source_file_sha256"] = hashlib.sha256(updated).hexdigest()
    with Path(output).open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    source.write_bytes(updated)


def result(evidence, status):
    evidence = Path(evidence)
    for log in sorted((evidence / "tests").glob("*/rtl.log")):
        raw = log.read_bytes()
        if b"CPU_EVAL_IOMSHR_UNEXPECTED_STORE_RESPONSE" in raw.splitlines():
            (evidence / "verdict.tsv").write_text("FAIL\tunexpected_uncached_store_response\n")
            return 1
    if status == 0:
        uncached = list((evidence / "tests").glob("*-uncached_msip/rtl.log"))
        if len(uncached) != 1 or not re.search(
            rb"(?m)^CPU_EVAL_IOMSHR_STORE_ACCEPTED 0*2000000\r?$", uncached[0].read_bytes()
        ):
            (evidence / "verdict.tsv").write_text("FAIL\tuncached_store_observation_missing\n")
            return 1
    return status


if __name__ == "__main__":
    operation, *arguments = sys.argv[1:]
    if operation == "prepare":
        prepare(*arguments)
    elif operation == "result":
        raise SystemExit(result(arguments[0], int(arguments[1])))
    else:
        raise SystemExit(f"unknown operation: {operation}")
