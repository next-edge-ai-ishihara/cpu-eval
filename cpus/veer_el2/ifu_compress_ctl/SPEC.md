# Implement `el2_ifu_compress_ctl`

Implement the complete `el2_ifu_compress_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_compress_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog

module el2_ifu_compress_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input  logic [15:0] din,        // 16-bit   compressed instruction
   output logic [31:0] dout        // 32-bit uncompressed instruction
   );

```

## Parent instantiation

```verilog
   el2_ifu_compress_ctl compress0 (.din((first2B) ? aligndata[15:0] : '0), .dout(uncompress0[31:0]));

```

## Documentation

### docs/source/overview.md

```markdown
# Core Overview

This chapter provides a high-level overview of the VeeR EL2 core and core complex. VeeR EL2 is a machinemode (M-mode) and usermode (U-mode), 32-bit CPU small core which supports RISC-V's integer (I), compressed instruction (C), multiplication and division (M), and instruction-fetch fence, CSR, and subset of bit manipulation instructions (Z) extensions. The core contains a 4-stage, scalar, in-order pipeline.

## Features

The VeeR EL2 core complex's feature set includes:
- RV32IMC-compliant RISC-V core with branch predictor

```

### src/c-st-ext.adoc

```asciidoc
=== Compressed Instruction Formats
((((compressed, formats))))

<<rvc-form>> shows the nine compressed instruction
formats. CR, CI, and CSS can use any of the 32 RVI registers, but CIW,
CL, CS, CA, and CB are limited to just 8 of them.
<<registers>> lists these popular registers, which
correspond to registers `x8` to `x15`. Note that there is a separate
version of load and store instructions that use the stack pointer as the
base address register, since saving to and restoring from the stack are
so prevalent, and that they use the CI and CSS formats to allow access
to all 32 data registers. CIW supplies an 8-bit immediate for the
ADDI4SPN instruction.

[NOTE]
====
The RISC-V ABI was changed to make the frequently used registers map to
registers 'x8-x15'. This simplifies the decompression decoder by
having a contiguous naturally aligned set of register numbers, and is
also compatible with the RV32E and RV64E base ISAs, which only have 16 integer
registers.
====
Compressed register-based floating-point loads and stores also use the
CL and CS formats respectively, with the eight registers mapping to `f8` to `f15`.
((((calling convention, standard))))
[NOTE]
====
_The standard RISC-V calling convention maps the most frequently used
floating-point registers to registers `f8` to `f15`, which allows the
same register decompression decoding as for integer register numbers._
====
((((register source spcifiers, c-ext))))
The formats were designed to keep bits for the two register source
specifiers in the same place in all instructions, while the destination
register field can move. When the full 5-bit destination register
specifier is present, it is in the same place as in the 32-bit RISC-V
encoding. Where immediates are sign-extended, the sign extension is
always from bit 12. Immediate fields have been scrambled, as in the base
specification, to reduce the number of immediate muxes required.
[NOTE]
====
The immediate fields are scrambled in the instruction formats instead of
in sequential order so that as many bits as possible are in the same
position in every instruction, thereby simplifying implementations.
====

For many RVC instructions, zero-valued immediates are disallowed and
`x0` is not a valid 5-bit register specifier. These restrictions free up
encoding space for other instructions requiring fewer operand bits.

//[[cr-register]]
//include::images/wavedrom/cr-register.edn[]
//.Compressed 16-bit RVC instructions
//(((compressed, 16-bit)))

[[rvc-form]]
.Compressed 16-bit RVC instruction formats
//[%header]
[float="center",align="center",cols="1a, 2a",frame="none",grid="none"]
|===
| 
[%autowidth,float="right",align="right",cols="^,^",frame="none",grid="none",options="noheader"]
!===
!Format ! Meaning
!CR ! Register
!CI ! Immediate
!CSS ! Stack-relative Store
!CIW ! Wide Immediate
!CL ! Load
!CS ! Store
!CA ! Arithmetic
!CB ! Branch/Arithmetic
!CJ ! Jump
!===
|
[float="left",align="left",cols="1,1,1,1,1,1,1",options="noheader"]
!===
^!15 14 13 ^!12 ^!11 10 ^!9 8 7 ^!6 5 ^!4 3 2 ^!1 0
2+^!funct4 2+^!rd/rs1 2+^!rs2 ^!  op
^!funct3 ^!imm 2+^!rd/rs1  2+^!imm ^!  op
^!funct3 3+^!imm  2+^!rs2 ^!  op
^!funct3 4+^!imm ^!rd&#x2032; ^! op
^!funct3 2+^!imm ^!rs1&#x2032; ^!imm ^!rd&#x2032; ^! op
^!funct3 2+^!imm ^!rs1&#x2032; ^! imm ^!rs2&#x2032; ^! op
3+^!funct6 ^!rd&#x2032;/rs1&#x2032; ^!funct2 ^!rs2&#x2032; ^! op
^!funct3 2+^!offset ^!rd&#x2032;/rs1&#x2032; 2+^!offset ^! op
^!funct3 5+^!jump target ^! op
!===
|===

[[registers]]
.Registers specified by the three-bit _rs1_&#x2032;, _rs2_&#x2032;, and _rd_&#x2032; fields of the CIW, CL, CS, CA, and CB formats.
//[cols="20%,10%,10%,10%,10%,10%,10%,10%,10%"]
[float="center",align="center",cols="1a, 1a",frame="none",grid="none"]
|===
| 
[%autowidth,cols="<",frame="none",grid="none",options="noheader"]
!===
!RVC Register Number
!Integer Register Number
!Integer Register ABI Name 
!Floating-Point Register Number
!Floating-Point Register ABI Name 
!===
|

[%autowidth,cols="^,^,^,^,^,^,^,^",options="noheader"]
!===
!`000` !`001` !`010` !`011` !`100` !`101` !`110` !`111`
!`x8` !`x9` !`x10` !`x11` !`x12` !`x13` !`x14`!`x15`
!`s0` !`s1` !`a0` !`a1` !`a2` !`a3` !`a4`!`a5`
!`f8` !`f9` !`f10` !`f11` !`f12` !`f13`!`f14` !`f15`
!`fs0` !`fs1` !`fa0` !`fa1` !`fa2`!`fa3` !`fa4` !`fa5`
!===
|===


=== Load and Store Instructions

To increase the reach of 16-bit instructions, data-transfer instructions
use zero-extended immediates that are scaled by the size of the data in
bytes: ×4 for words, ×8 for double
words, and ×16 for quad words.

RVC provides two variants of loads and stores. One uses the ABI stack
pointer, `x2`, as the base address and can target any data register. The
other can reference one of 8 base address registers and one of 8 data
registers.

==== Stack-Pointer-Based Loads and Stores

include::images/wavedrom/c-sp-load-store.edn[]
[[c-sp-load-store]]
//.Stack-Pointer-Based Loads and Stores--these instructions use the CI format.

These instructions use the CI format.

C.LWSP loads a 32-bit value from memory into register _rd_. It computes
an effective address by adding the _zero_-extended offset, scaled by 4,
to the stack pointer, `x2`. It expands to `lw rd, offset(x2)`. C.LWSP is
valid only when _rd_≠`x0`; the code points with _rd_=`x0` are reserved.

C.LDSP is an RV64C/RV128C-only instruction that loads a 64-bit value
from memory into register _rd_. It computes its effective address by
adding the zero-extended offset, scaled by 8, to the stack pointer,
`x2`. It expands to `ld rd, offset(x2)`. C.LDSP is valid only when
_rd_≠`x0`; the code points with
_rd_=`x0` are reserved.

C.LQSP is an RV128C-only instruction that loads a 128-bit value from
memory into register _rd_. It computes its effective address by adding
the zero-extended offset, scaled by 16, to the stack pointer, `x2`. It
expands to `lq rd, offset(x2)`. C.LQSP is valid only when
_rd_≠`x0`; the code points with
_rd_=`x0` are reserved.

C.FLWSP is an RV32FC-only instruction that loads a single-precision
floating-point value from memory into floating-point register _rd_. It
computes its effective address by adding the _zero_-extended offset,
scaled by 4, to the stack pointer, `x2`. It expands to
`flw rd, offset(x2)`.

C.FLDSP is an RV32DC/RV64DC-only instruction that loads a
double-precision floating-point value from memory into floating-point
register _rd_. It computes its effective address by adding the
_zero_-extended offset, scaled by 8, to the stack pointer, `x2`. It
expands to `fld rd, offset(x2)`.

include::images/wavedrom/c-sp-load-store-css.edn[]
[[c-sp-load-store-css]]
//.Stack-Pointer-Based Loads and Stores--these instructions use the CSS format.

These instructions use the CSS format.

C.SWSP stores a 32-bit value in register _rs2_ to memory. It computes an
effective address by adding the _zero_-extended offset, scaled by 4, to
the stack pointer, `x2`. It expands to `sw rs2, offset(x2)`.

C.SDSP is an RV64C/RV128C-only instruction that stores a 64-bit value in
register _rs2_ to memory. It computes an effective address by adding the
_zero_-extended offset, scaled by 8, to the stack pointer, `x2`. It
expands to `sd rs2, offset(x2)`.

C.SQSP is an RV128C-only instruction that stores a 128-bit value in
register _rs2_ to memory. It computes an effective address by adding the
_zero_-extended offset, scaled by 16, to the stack pointer, `x2`. It
expands to `sq rs2, offset(x2)`.

C.FSWSP is an RV32FC-only instruction that stores a single-precision
floating-point value in floating-point register _rs2_ to memory. It
computes an effective address by adding the _zero_-extended offset,
scaled by 4, to the stack pointer, `x2`. It expands to
`fsw rs2, offset(x2)`.

C.FSDSP is an RV32DC/RV64DC-only instruction that stores a
double-precision floating-point value in floating-point register _rs2_
to memory. It computes an effective address by adding the
_zero_-extended offset, scaled by 8, to the stack pointer, `x2`. It
expands to `fsd rs2, offset(x2)`.

[NOTE]
====
Register save/restore code at function entry/exit represents a
significant portion of static code size. The stack-pointer-based
compressed loads and stores in RVC are effective at reducing the
save/restore static code size by a factor of 2 while improving
performance by reducing dynamic instruction bandwidth.

A common mechanism used in other ISAs to further reduce save/restore
code size is load-multiple and store-multiple instructions. We
considered adopting these for RISC-V but noted the following drawbacks
to these instructions:

* These instructions complicate processor implementations.
* For virtual memory systems, some data accesses could be resident in
physical memory and some could not, which requires a new restart
mechanism for partially executed instructions.
* Unlike the rest of the RVC instructions, there is no IFD equivalent to
Load Multiple and Store Multiple.
* Unlike the rest of the RVC instructions, the compiler would have to be
aware of these instructions to both generate the instructions and to
allocate registers in an order to maximize the chances of the them being
saved and stored, since they would be saved and restored in sequential
order.
* Simple microarchitectural implementations will constrain how other
instructions can be scheduled around the load and store multiple
instructions, leading to a potential performance loss.
* The desire for sequential register allocation might conflict with the
featured registers selected for the CIW, CL, CS, CA, and CB formats.

Furthermore, much of the gains can be realized in software by replacing
prologue and epilogue code with subroutine calls to common prologue and
epilogue code, a technique described in Section 5.6 of cite:[waterman-phd].

While reasonable architects might come to different conclusions, we
decided to omit load and store multiple and instead use the
software-only approach of calling save/restore millicode routines to
attain the greatest code size reduction.
====

==== Register-Based Loads and Stores

[[reg-based-ldnstr]]
include::images/wavedrom/reg-based-ldnstr.edn[]
//.Compressed, register-based load and stores--these instructions use the CL format.
(((compressed, register-based load and store)))
These instructions use the CL format.

C.LW loads a 32-bit value from memory into register
`_rd′_`. It computes an effective address by adding the
_zero_-extended offset, scaled by 4, to the base address in register
`_rs1′_`. It expands to `lw rd′, offset(rs1′)`.

C.LD is an RV64C/RV128C-only instruction that loads a 64-bit value from
memory into register `_rd′_`. It computes an effective
address by adding the _zero_-extended offset, scaled by 8, to the base
address in register `_rs1′_`. It expands to
`ld rd′, offset(rs1′)`.

C.LQ is an RV128C-only instruction that loads a 128-bit value from
memory into register `_rd′_`. It computes an effective
address by adding the _zero_-extended offset, scaled by 16, to the base
address in register `_rs1′_`. It expands to
`lq rd′, offset(rs1′)`.

C.FLW is an RV32FC-only instruction that loads a single-precision
floating-point value from memory into floating-point register
`_rd′_`. It computes an effective address by adding the
_zero_-extended offset, scaled by 4, to the base address in register
`_rs1′_`. It expands to
`flw rd′, offset(rs1′)`.

C.FLD is an RV32DC/RV64DC-only instruction that loads a double-precision
floating-point value from memory into floating-point register
`_rd′_`. It computes an effective address by adding the
_zero_-extended offset, scaled by 8, to the base address in register
`_rs1′_`. It expands to
`fld rd′, offset(rs1′)`.

[[c-cs-format-ls]]
include::images/wavedrom/c-cs-format-ls.edn[]
//.Compressed, CS format load and store--these instructions use the CS format.
(((compressed, cs-format load and store)))

These instructions use the CS format.

C.SW stores a 32-bit value in register `_rs2′_` to memory.
It computes an effective address by adding the _zero_-extended offset,
scaled by 4, to the base address in register `_rs1′_`. It
expands to `sw rs2′, offset(rs1′)`.

C.SD is an RV64C/RV128C-only instruction that stores a 64-bit value in
register `_rs2′_` to memory. It computes an effective
address by adding the _zero_-extended offset, scaled by 8, to the base
address in register `_rs1′_`. It expands to
`sd rs2′, offset(rs1′)`.

C.SQ is an RV128C-only instruction that stores a 128-bit value in
register `_rs2′_` to memory. It computes an effective
address by adding the _zero_-extended offset, scaled by 16, to the base
address in register `_rs1′_`. It expands to
`sq rs2′, offset(rs1′)`.

C.FSW is an RV32FC-only instruction that stores a single-precision
floating-point value in floating-point register `_rs2′_` to
memory. It computes an effective address by adding the _zero_-extended
offset, scaled by 4, to the base address in register
`_rs1′_`. It expands to
`fsw rs2′, offset(rs1′)`.

C.FSD is an RV32DC/RV64DC-only instruction that stores a
double-precision floating-point value in floating-point register
`_rs2′_` to memory. It computes an effective address by
adding the _zero_-extended offset, scaled by 8, to the base address in
register `_rs1′_`. It expands to
`fsd rs2′, offset(rs1′)`.

=== Control Transfer Instructions

RVC provides unconditional jump instructions and conditional branch
instructions. As with base RVI instructions, the offsets of all RVC
control transfer instructions are in multiples of 2 bytes.

[[c-cj-format-ls]]
include::images/wavedrom/c-cj-format-ls.edn[]
//.Compressed, CJ format load and store--these instructions use the CJ format.
(((compressed, cj-format load and store)))

These instructions use the CJ format.

C.J performs an unconditional control transfer. The offset is
sign-extended and added to the `pc` to form the jump target address. C.J
can therefore target a &#177;2 KiB range. C.J expands to
`jal x0, offset`.

C.JAL is an RV32C-only instruction that performs the same operation as
C.J, but additionally writes the address of the instruction following
the jump (`pc+2`) to the link register, `x1`. C.JAL expands to
`jal x1, offset`.

[[c-cr-format-ls]]
include::images/wavedrom/c-cr-format-ls.edn[]
//.Compressed, CR format load and store--these instructions use the CR format.
(((compressed, cr-format load and store)))

These instructions use the CR format.

C.JR (jump register) performs an unconditional control transfer to the
address in register _rs1_. C.JR expands to `jalr x0, 0(rs1)`. C.JR is
valid only when _rs1_≠`x0`; the code
point with _rs1_=`x0` is reserved.

C.JALR (jump and link register) performs the same operation as C.JR, but
additionally writes the address of the instruction following the jump
(`pc`+2) to the link register, `x1`. C.JALR expands to
`jalr x1, 0(rs1)`. C.JALR is valid only when
_rs1_≠`x0`; the code point with
_rs1_=`x0` corresponds to the C.EBREAK
instruction.

[NOTE]
====
Strictly speaking, C.JALR does not expand exactly to a base RVI
instruction as the value added to the PC to form the link address is 2
rather than 4 as in the base ISA, but supporting both offsets of 2 and 4
bytes is only a very minor change to the base microarchitecture.
====

[[c-cb-format-ls]]
include::images/wavedrom/c-cb-format-ls.edn[]
//.Compressed, CB format load and store--these instructions use the CB format.
(((compressed, cb-format load and store)))

These instructions use the CB format.

C.BEQZ performs conditional control transfers. The offset is
sign-extended and added to the `pc` to form the branch target address.
It can therefore target a &#177;256 B range. C.BEQZ takes the
branch if the value in register _rs1′_ is zero. It
expands to `beq rs1′, x0, offset`.

C.BNEZ is defined analogously, but it takes the branch if
_rs1′_ contains a nonzero value. It expands to
`bne rs1′, x0, offset`.

=== Integer Computational Instructions

RVC provides several instructions for integer arithmetic and constant
generation.

==== Integer Constant-Generation Instructions

The two constant-generation instructions both use the CI instruction
format and can target any integer register.

[[c-integer-const-gen]]
include::images/wavedrom/c-integer-const-gen.edn[]
//.Integer constant generation format.
(((compressed, integer constant generation)))


C.LI loads the sign-extended 6-bit immediate, _imm_, into register _rd_.
C.LI expands into `addi rd, x0, imm`. C.LI is valid only when
_rd_≠`x0`; the code points with _rd_=`x0` encode HINTs.

C.LUI loads the non-zero 6-bit immediate field into bits 17–12 of the
destination register, clears the bottom 12 bits, and sign-extends bit 17
into all higher bits of the destination. C.LUI expands into
`lui rd, imm`. C.LUI is valid only when
_rd_≠{`x0`,`x2`},
and when the immediate is not equal to zero. The code points with
_imm_=0 are reserved; the remaining code points with _rd_=`x0` are
HINTs; and the remaining code points with _rd_=`x2` correspond to the
C.ADDI16SP instruction.

==== Integer Register-Immediate Operations

These integer register-immediate operations are encoded in the CI format
and perform operations on an integer register and a 6-bit immediate.

[[c-integer-register-immediate]]
include::images/wavedrom/c-int-reg-immed.edn[]
//.Integer register-immediate format.
(((compressed, integer register-immediate)))

C.ADDI adds the non-zero sign-extended 6-bit immediate to the value in
register _rd_ then writes the result to _rd_. C.ADDI expands into
`addi rd, rd, imm`. C.ADDI is valid only when
_rd_≠`x0` and _imm_≠0. The code
points with _rd_=`x0` encode the C.NOP instruction; the remaining code
points with _imm_=0 encode HINTs.

C.ADDIW is an RV64C/RV128C-only instruction that performs the same
computation but produces a 32-bit result, then sign-extends result to 64
bits. C.ADDIW expands into `addiw rd, rd, imm`. The immediate can be
zero for C.ADDIW, where this corresponds to `sext.w rd`. C.ADDIW is
valid only when _rd_≠`x0`; the code points with
_rd_=`x0` are reserved.

C.ADDI16SP (add immediate to stack pointer)
shares the opcode with C.LUI, but has a destination field of
`x2`. C.ADDI16SP adds the non-zero sign-extended 6-bit immediate to the
value in the stack pointer (`sp=x2`), where the immediate is scaled to
represent multiples of 16 in the range [-512, 496]. C.ADDI16SP is used to
adjust the stack pointer in procedure prologues and epilogues. It
expands into `addi x2, x2, nzimm[9:4]`. C.ADDI16SP is valid only when
_nzimm_≠0; the code point with _nzimm_=0 is reserved.

[NOTE]
====
In the standard RISC-V calling convention, the stack pointer `sp` is
always 16-byte aligned.
====

[[c-ciw]]
include::images/wavedrom/c-ciw.edn[]
//.CIW format.
(((compressed, CIW)))
C.ADDI4SPN (add immediate to stack pointer, non-destructive)
is a CIW-format instruction that adds a _zero_-extended
non-zero immediate, scaled by 4, to the stack pointer, `x2`, and writes
the result to `rd′`. This instruction is used to generate
pointers to stack-allocated variables, and expands to
`addi rd′, x2, nzuimm[9:2]`. C.ADDI4SPN is valid only when
_nzuimm_≠0; the code points with _nzuimm_=0 are
reserved.

[[c-ci]]
include::images/wavedrom/c-ci.edn[]
//.CI format.
(((compressed, CI)))

C.SLLI is a CI-format instruction that performs a logical left shift of
the value in register _rd_ then writes the result to _rd_. The shift
amount is encoded in the _shamt_ field. For RV128C, a shift amount of
zero is used to encode a shift of 64. C.SLLI expands into
`slli rd, rd, shamt[5:0]`, except for RV128C with `shamt=0`, which expands to
`slli rd, rd, 64`.

For RV32C, _shamt[5]_ must be zero; the code points with _shamt[5]_=1
are designated for custom extensions. For RV32C and RV64C, the shift
amount must be non-zero; the code points with _shamt_=0 are HINTs. For
all base ISAs, the code points with _rd_=`x0` are HINTs, except those
with _shamt[5]_=1 in RV32C.

[[c-srli-srai]]
include::images/wavedrom/c-srli-srai.edn[]
//.C-SRLI-SRAI format.
(((compressed, C.SRLI, C.SRAI)))

C.SRLI is a CB-format instruction that performs a logical right shift of
the value in register _rd′_ then writes the result to
_rd′_. The shift amount is encoded in the _shamt_ field.
For RV128C, a shift amount of zero is used to encode a shift of 64.
Furthermore, the shift amount is sign-extended for RV128C, and so the
legal shift amounts are 1-31, 64, and 96-127. C.SRLI expands into
`srli rd′, rd′, shamt`, except for
RV128C with `shamt=0`, which expands to
`srli rd′, rd′, 64`.

For RV32C, _shamt[5]_ must be zero; the code points with _shamt[5]_=1
are designated for custom extensions. For RV32C and RV64C, the shift
amount must be non-zero; the code points with _shamt_=0 are HINTs.

C.SRAI is defined analogously to C.SRLI, but instead performs an
arithmetic right shift. C.SRAI expands to
`srai rd′, rd′, shamt`.

[NOTE]
====
Left shifts are usually more frequent than right shifts, as left shifts
are frequently used to scale address values. Right shifts have therefore
been granted less encoding space and are placed in an encoding quadrant
where all other immediates are sign-extended. For RV128, the decision
was made to have the 6-bit shift-amount immediate also be sign-extended.
Apart from reducing the decode complexity, we believe right-shift
amounts of 96-127 will be more useful than 64-95, to allow extraction of
tags located in the high portions of 128-bit address pointers. We note
that RV128C will not be frozen at the same point as RV32C and RV64C, to
allow evaluation of typical usage of 128-bit address-space codes.
====
[[c-andi]]
include::images/wavedrom/c-andi.edn[]
//.C.ANDI format
(((compressed, C.ANDI)))

C.ANDI is a CB-format instruction that computes the bitwise AND of the
value in register _rd′_ and the sign-extended 6-bit
immediate, then writes the result to _rd′_. C.ANDI
expands to `andi rd′, rd′, imm`.

==== Integer Register-Register Operations

[[c-cr]]
include::images/wavedrom/c-int-reg-to-reg-cr-format.edn[]
//C.CR format
((((compressed. C.CR))))
These instructions use the CR format.

C.MV copies the value in register _rs2_ into register _rd_. C.MV expands
into `add rd, x0, rs2`. C.MV is valid only when
_rs2_≠`x0`; the code points with _rs2_=`x0` correspond to the C.JR instruction. The code points with _rs2_≠`x0` and _rd_=`x0` are HINTs.

[NOTE]
====
_C.MV expands to a different instruction than the canonical MV
pseudoinstruction, which instead uses ADDI. Implementations that handle
MV specially, e.g. using register-renaming hardware, may find it more
convenient to expand C.MV to MV instead of ADD, at slight additional
hardware cost._
====

C.ADD adds the values in registers _rd_ and _rs2_ and writes the result
to register _rd_. C.ADD expands into `add rd, rd, rs2`. C.ADD is only
valid when _rs2_≠`x0`; the code points with _rs2_=`x0` correspond to the C.JALR
and C.EBREAK instructions. The code points with _rs2_≠`x0` and _rd_=`x0` are HINTs.

[[c-ca]]
include::images/wavedrom/c-int-reg-to-reg-ca-format.edn[]
//C.CA format
((((compressed. C.CA))))

These instructions use the CA format.

`C.AND` computes the bitwise `AND` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. `C.AND` expands into
*`_and rd′, rd′, rs2′_`*.

`C.OR` computes the bitwise `OR` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. `C.OR` expands into
*`_or rd&#8242;, rd&#8242;, rs2&#8242;_`*.

`C.XOR` computes the bitwise `XOR` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. `C.XOR` expands into
*`_xor rd′, rd′, rs2′_`*.

`C.SUB` subtracts the value in register _rs2′_ from the
value in register _rd′_, then writes the result to
register _rd′_. `C.SUB` expands into
*`_sub rd′, rd′, rs2′_`*.

`C.ADDW` is an RV64C/RV128C-only instruction that adds the values in
registers _rd′_ and _rs2′_, then
sign-extends the lower 32 bits of the sum before writing the result to
register _rd′_. `C.ADDW` expands into
*`_addw rd′, rd′, rs2′_`*.

`C.SUBW` is an RV64C/RV128C-only instruction that subtracts the value in
register _rs2′_ from the value in register
_rd′_, then sign-extends the lower 32 bits of the
difference before writing the result to register _rd′_.
`C.SUBW` expands into *`_subw rd′, rd′, rs2′_`*.

[NOTE]
====
This group of six instructions do not provide large savings
individually, but do not occupy much encoding space and are
straightforward to implement, and as a group provide a worthwhile
improvement in static and dynamic compression.
====

==== Defined Illegal Instruction

[[c-def-illegal-inst]]
include::images/wavedrom/c-def-illegal-inst.edn[]
((((compressed. C.DIINST))))

A 16-bit instruction with all bits zero is permanently reserved as an
illegal instruction.

[NOTE]
====
We reserve all-zero instructions to be illegal instructions to help trap
attempts to execute zero-ed or non-existent portions of the memory
space. The all-zero value should not be redefined in any non-standard
extension. Similarly, we reserve instructions with all bits set to 1
(corresponding to very long instructions in the RISC-V variable-length
encoding scheme) as illegal to capture another common value seen in
non-existent memory regions.
====

==== NOP Instruction

[[c-nop-instr]]
include::images/wavedrom/c-nop-instr.edn[]
((((compressed. C.NOPINSTR))))

`C.NOP` is a CI-format instruction that does not change any user-visible
state, except for advancing the `pc` and incrementing any applicable
performance counters. `C.NOP` expands to `nop`. `C.NOP` is valid only when
_imm_=0; the code points with _imm_≠0 encode HINTs.

==== Breakpoint Instruction

[[c-breakpoint-instr]]
include::images/wavedrom/c-breakpoint-instr.edn[]
((((compressed. C.BREAKPOINTINSTR))))

Debuggers can use the `C.EBREAK` instruction, which expands to `ebreak`,
to cause control to be transferred back to the debugging environment.
`C.EBREAK` shares the opcode with the `C.ADD` instruction, but with _rd_ and
_rs2_ both zero, thus can also use the `CR` format.

=== Usage of C Instructions in LR/SC Sequences

On implementations that support the C extension, compressed forms of the
I instructions permitted inside constrained LR/SC sequences, as
described in <<sec:lrscseq>>, are also permitted
inside constrained LR/SC sequences.

[NOTE]
====
The implication is that any implementation that claims to support both
the A and C extensions must ensure that LR/SC sequences containing valid
C instructions will eventually complete.
====

[[rvc-hints]]
=== HINT Instructions

A portion of the RVC encoding space is reserved for microarchitectural
HINTs. Like the HINTs in the RV32I base ISA (see
<<rv32i-hints>>), these instructions do not
modify any architectural state, except for advancing the `pc` and any
applicable performance counters. HINTs are executed as no-ops on
implementations that ignore them.

RVC HINTs are encoded as computational instructions that do not modify
the architectural state, either because _rd_=`x0` (e.g.
`C.ADD _x0_, _t0_`), or because _rd_ is overwritten with a copy of itself
(e.g. `C.ADDI _t0_, 0`).

[NOTE]
====
This HINT encoding has been chosen so that simple implementations can
ignore HINTs altogether, and instead execute a HINT as a regular
computational instruction that happens not to mutate the architectural
state.
====

RVC HINTs do not necessarily expand to their RVI HINT counterparts. For
example, `C.ADD` _x0_, _a0_ might not encode the same HINT as
`ADD` _x0_, _x0_, _a0_.

[NOTE]
====
The primary reason to not require an RVC HINT to expand to an RVI HINT
is that HINTs are unlikely to be compressible in the same manner as the
underlying computational instruction. Also, decoupling the RVC and RVI
HINT mappings allows the scarce RVC HINT space to be allocated to the
most popular HINTs, and in particular, to HINTs that are amenable to
macro-op fusion.
====

<<rvc-t-hints, Table 32>> lists all RVC HINT code points. For RV32C, 78%
of the HINT space is reserved for standard HINTs. The remainder of the HINT space is designated for custom HINTs;
no standard HINTs will ever be defined in this subspace.

[[rvc-t-hints]]
.RVC HINT instructions.
[cols="<,<,>,<",options="header",]
|===
|Instruction |Constraints |Code Points |Purpose

|C.NOP |_imm_≠0 |63 .6+.^|_Designated for future standard use_

|C.ADDI | _rd_≠`x0`, _imm_=0 |31

|C.LI | _rd_=`x0` |64

|C.LUI | _rd_=`x0`, _imm_≠0 |63

|C.MV | _rd_=`x0`, _rs2_≠`x0` |31

|C.ADD | _rd_=`x0`, _rs2_≠`x0`, _rs2_≠`x2-x5` | 27

|C.ADD | _rd_=`x0`, _rs2_≠`x2-x5` |4|(rs2=x2) C.NTL.P1 (rs2=x3) C.NTL.PALL (rs2=x4) C.NTL.S1 (rs2=x5) C.NTL.ALL

|C.SLLI |_rd_=`x0`, _imm_≠0 |31 (RV32), 63 (RV64/128)  .5+.^|_Designated for custom use_

|C.SLLI64 | _rd_=`x0` |1

|C.SLLI64 | _rd_≠`x0`, RV32 and RV64 only |31

|C.SRLI64 | RV32 and RV64 only |8

|C.SRAI64 | RV32 and RV64 only |8
|===

=== RVC Instruction Set Listings

<<rvcopcodemap>> shows a map of the major
opcodes for RVC. Each row of the table corresponds to one quadrant of
the encoding space. The last quadrant, which has the two
least-significant bits set, corresponds to instructions wider than 16
bits, including those in the base ISAs. Several instructions are only
valid for certain operands; when invalid, they are marked either _RES_
to indicate that the opcode is reserved for future standard extensions;
_Custom_ to indicate that the opcode is designated for custom
extensions; or _HINT_ to indicate that the opcode is reserved for
microarchitectural hints (see <<rvc-hints>>).

<<<

[[rvcopcodemap]]
.RVC opcode map instructions.
[%autowidth,float="center",align="center",cols=">,^,^,^,^,^,^,^,^,^,<]
|===
2+>|inst[15:13] +
inst[1:0] ^.^s|000 ^.^s|001 ^.^s|010 ^.^s|011 ^.^s|100 ^.^s|101 ^.^s|110 ^.^s|111 |

2+>.^|00 .^|ADDI4SPN ^.^|FLD +
FLD +
LQ ^.^| LW ^.^| FLW +
LD +
LD ^.^| _Reserved_ ^.^| FSD +
FSD +
SQ ^.^| SW ^.^| FSW +
SD +
SD 
^.^| RV32 +
RV64 +
RV128

2+>.^|01 ^.^|ADDI ^.^|JAL +
ADDIW +
ADDIW ^.^|LI ^.^|LUI/ADDI16SP ^.^|MISC-ALU ^.^|J ^.^|BEQZ ^.^|BNEZ ^.^|RV32 +
RV64 +
RV128

2+>.^|10 ^.^|SLLI ^.^|FLDSP +
FLDSP +
LQSP ^.^|LWSP ^.^|FLWSP +
LDSP +
LDSP ^.^|J[AL]R/MV/ADD ^.^|FSDSP +
FSDSP +
SQSP ^.^|SWSP ^.^|FSWSP +
SDSP +
SDSP ^.^|RV32 +
RV64 +
RV128

2+>.^|11 9+^|>16b
|===

<<rvc-instr-table0>>, <<rvc-instr-table1>>, and <<rvc-instr-table2>> list the RVC instructions.

[[rvc-instr-table0]]
.Instruction listing for RVC, Quadrant 0
include::images/bytefield/rvc-instr-quad0.edn[]
//include::images/bytefield/rvc-instr-quad0.png[]

[[rvc-instr-table1]]
.Instruction listing for RVC, Quadrant 1
include::images/bytefield/rvc-instr-quad1.edn[]
//include::images/bytefield/rvc-instr-quad1.png[]

[[rvc-instr-table2]]
.Instruction listing for RVC, Quadrant 2
include::images/bytefield/rvc-instr-quad2.edn[]
//include::images/bytefield/rvc-instr-quad2.png[]

```

### src/images/bytefield/rvc-instr-quad0.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback"}])
(def row-height 35 )
(def row-header-fn nil)
(def left-margin 0)
(def right-margin 40)
(def boxes-per-row 23)
(draw-column-headers {:labels (reverse ["" "" "" "" "" "" "" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15"])})
(draw-box "000" {:span 3 :vertical-align "middle"})
(draw-box "0" {:span 8})
(draw-box "0" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "Illegal instruction" {:font-style "italic"}) {:span 7 :text-anchor "start" :borders {}})

(draw-box "000" {:span 3})
(draw-box "uimm[5:4|9:6|2|3]" {:span 8})
(draw-box (text "rd′" [:plain {:font-family "M+ 1p Fallback"}]) {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.ADDI4SPN" :math [:sub "RES, uimm=0"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.FLD" :math [:sub "(RV32/64)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "uimm[5:4|8]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.LQ" :math [:sub "(RV128)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "010" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box "C.LW" {:span 7 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.FLW" :math [:sub "(RV32)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.LD" :math [:sub "(RV64/128)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "---" {:span 11})
(draw-box "00" {:span 2})
(draw-box (text "Reserved"  {:font-style "italic"}) {:span 7 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.FSD" :math [:sub "(RV32/64)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "uimm[5:4|8]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.SQ" :math [:sub "(RV128)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "110" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box "C.SW" {:span 7 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.FSW" :math [:sub "(RV32)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.SD" :math [:sub "(RV64/128)"]) {:span 7 :text-anchor "start" :borders {}})
----
```

### src/images/bytefield/rvc-instr-quad1.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-weight "bold" :font-family "M+ 1p Fallback"}])
(def row-height 50 )
(def row-header-fn nil)
(def left-margin 0)
(def right-margin 0)
(def boxes-per-row 19)
(def box-width 70)
(draw-column-headers {:labels (reverse ["" "" "" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15"])})

(draw-box "000" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.NOP" :math [:sub "(HINT, imm≠0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "000" {:span 3})
(draw-box "imm[5]") {:span 1}
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDI" :math [:sub "(HINT, imm=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "imm[11|4|9:8|10|6|7|3:1|5]" {:span 11})
(draw-box "01" {:span 2})
(draw-box (text "C.JAL" :math [:sub "(RV32)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDIW" :math [:sub "(RV64/128; RES, rd=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "010" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "rd̸=0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.LI" :math [:sub "(HINT, rd=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box "imm[9]" {:span 1})
(draw-box "2" {:span 5})
(draw-box "imm[4|6|8:7|5]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDI16SP" :math [:sub "(RES, imm=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box (text "imm[17]" {:font-width 11}) {:span 1})
(draw-box "rd̸={0, 2}" {:span 5})
(draw-box "imm[16:12]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.LUI" :math [:sub "(RES, imm=0; HINT, rd=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box (text "uimm[5]" {:font-width 11}) {:span 1})
(draw-box "00" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "uimm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.SRLI" :math [:sub "(RV32 Custom, uimm[5]=1)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "00" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "0" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.SRLI64" :math [:sub "(RV128; RV32/64 HINT)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box (text "uimm[5]" {:font-width 11}) {:span 1})
(draw-box "01" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "uimm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.SRAI" :math [:sub "(RV32 Custom, uimm[5]=1)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "01" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "0" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.SRAI64" :math [:sub "(RV128; RV32/64 HINT)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "10" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box "C.ANDI" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "00" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.SUB" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "01" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.XOR" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "10" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.OR" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "11" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.AND" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "00" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "C.SUBW" :math [:sub "(RV64/128; RV32 RES)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "01" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDW" :math [:sub "(RV64/128; RV32 RES)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "---" {:span 3})
(draw-box "10" {:span 2})
(draw-box "---" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "Reserved" {:font-style "italic"}) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "---" {:span 3})
(draw-box "11" {:span 2})
(draw-box "---" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "Reserved" {:font-style "italic"}) {:span 3 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "imm[11|4|9:8|10|6|7|3:1|5]" {:span 11})
(draw-box "01" {:span 2})
(draw-box "C.J" {:span 3 :text-anchor "start" :borders {}})

(draw-box "110" {:span 3})
(draw-box "imm[8|4:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box "imm[7:6|2:1|5]" {:span 5})
(draw-box "01" {:span 2})
(draw-box "C.BEQZ" {:span 3 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "imm[8|4:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box "imm[7:6|2:1|5]" {:span 5})
(draw-box "01" {:span 2})
(draw-box "C.BNEZ" {:span 3 :text-anchor "start" :borders {}})
----
```

### src/images/bytefield/rvc-instr-quad2.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback"}])
(def row-height 50 )
(def row-header-fn nil)
(def left-margin 0)
(def right-margin 40)
(def boxes-per-row 22)
(def box-width 70)
(draw-column-headers {:labels (reverse ["" "" "" "" "" "" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15"])})

(draw-box "000" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "uimm[4:0]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.SLLI" :math [:sub "(HINT, rd=0; RV32 Custom, uimm[5]=1)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "000" {:span 3})
(draw-box "0" {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.SLLI64" :math [:sub "(RV128; RV32/64 HINT; HINT, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd" {:span 5})
(draw-box "uimm[4:3|8:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.FLDSP" :math [:sub "(RV32/64)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "uimm[4|9:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.LQSP" :math [:sub "(RV128; RES, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "010" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "uimm[4:2|7:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.LWSP" :math [:sub "(RES, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd" {:span 5})
(draw-box "uimm[4:2|7:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.FLWSP" :math [:sub "(RV32)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "uimm[4:3|8:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.LDSP" :math [:sub "(RV64/128; RES, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "rs1≠0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.JR" :math [:sub "(RES, rs1=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "rs2≠0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.MV" :math [:sub "(HINT, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.EBREAK" {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "rs1≠0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.JALR" {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "rs2≠0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.ADD" :math [:sub "(HINT, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "uimm[5:3|8:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.FSDSP" :math [:sub "(RV32/64)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "uimm[5:4|9:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.SQSP" :math [:sub "(RV128)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "110" {:span 3})
(draw-box "uimm[5:2|7:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.SWSP" {:span 6 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:2|7:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.FSWSP" :math [:sub "(RV32)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:3|8:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.SDSP" :math [:sub "(RV64/128)"]) {:span 6 :text-anchor "start" :borders {}})
----
```
