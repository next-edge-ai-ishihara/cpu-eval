import sys
from pathlib import Path

def invalid():
    raise SystemExit(2)

def fail():
    raise SystemExit(1)

try:
    from compare_architectural_traces import parse_trace
    spike = parse_trace(Path(sys.argv[2]))
    # Bind the fixed program's two mcycle reads and subtraction to Spike PCs.
    instructions = {0xb0002973: 18, 0xb00029f3: 19, 0x41298a33: 20}
    locations = {}
    for instruction in instructions:
        matches = [(i, item.hart, item.pc) for i, item in enumerate(spike)
                   if item.instruction == instruction]
        if len(matches) != 1:
            invalid()
        locations[instruction] = matches[0]
    begin, end, delta = (locations[instruction] for instruction in instructions)
    if not (begin[0] < end[0] < delta[0] and begin[1] == end[1] == delta[1]
            and end[2] < delta[2] and delta[2] == end[2] + 4):
        invalid()
except (OSError, ValueError, TypeError, KeyError, IndexError, ImportError):
    invalid()
try:
    rtl = parse_trace(Path(sys.argv[1]), observed_rtl=True)
except ValueError:
    # The RTL trace comes from the answer, so a malformed one is a mismatch.
    fail()
except OSError:
    invalid()

start = next((i for i, item in enumerate(rtl)
              if (item.pc, item.instruction) == (spike[0].pc, spike[0].instruction)), None)
if start is None:
    fail()
rtl = rtl[start:start + len(spike)]
states = [dict.fromkeys(range(32), 0), dict.fromkeys(range(32), 0)]
values = [{}, {}]
for index, (left, right) in enumerate(zip(rtl, spike)):
    if (left.hart, left.pc, left.instruction, left.memory_updates) != (
            right.hart, right.pc, right.instruction, right.memory_updates):
        fail()
    register = instructions.get(right.instruction)
    if register is not None and locations[right.instruction] != (index, right.hart, right.pc):
        invalid()
    for side, item in enumerate((left, right)):
        # A malformed RTL record is an RTL error; a malformed Spike record makes the trace unusable.
        reject = fail if side == 0 else invalid
        if any(not 0 < rd < 32 or not 0 <= value <= 0xffffffff
               for rd, value in item.register_updates):
            reject()
        if register is not None:
            if len(item.register_updates) != 1 or item.register_updates[0][0] != register:
                reject()
            values[side][register] = item.register_updates[0][1]
        if any(len({value for reg, value in item.register_updates if reg == rd}) > 1
               for rd, _ in item.register_updates):
            reject()
        states[side].update(item.register_updates)
    if register is None:
        written = {rd for rd, _ in left.register_updates + right.register_updates}
        if any(states[0][rd] != states[1][rd] for rd in written):
            fail()
if len(rtl) < len(spike):
    fail()
if any(set(side) != {18, 19, 20} for side in values):
    invalid()
for side, reject in ((values[1], invalid), (values[0], fail)):
    if side[20] != ((side[19] - side[18]) & 0xffffffff):
        reject()
print(values[0][20])
