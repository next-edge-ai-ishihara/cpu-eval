# Implement `Bru`

Implement the complete `Bru` class. Preserve the class name and interface shown below.

Return only the complete `class Bru` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/backend/Bru.scala

```scala
package rift2Core.backend


import chisel3._
import chisel3.util._
import chisel3.experimental.dataview._
import rift2Core.define._
import rift2Chip._
import org.chipsalliance.cde.config._
```

## Parent instantiation

### src/main/scala/rift2Core/backend/Execute.scala

```scala
  val bru = Module(new Bru)
// ...
  bru.io.bru_iss_exe <> io.bru_iss_exe
  bru.io.bru_exe_iwb <> io.bru_exe_iwb
  bru.io.flush <> io.flush

  bru.io.bftq <> io.bftq
  bru.io.jftq <> io.jftq

  io.bctq <> bru.io.bctq
  io.jctq <> bru.io.jctq

  io.bcmm_update := bru.io.bcmm_update
  io.jcmm_update := bru.io.jcmm_update
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Bru.scala

```scala
abstract class BruBase()(implicit p: Parameters) extends RiftModule {
  class BruIO extends Bundle{
    val bru_iss_exe = Flipped(new DecoupledIO(new Bru_iss_info))
    val bru_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))

    val bftq = Flipped(Decoupled(new Branch_FTarget_Bundle))
    val jftq = Flipped(Decoupled(new Jump_FTarget_Bundle))

    val bctq = Decoupled(new Branch_CTarget_Bundle)
    val jctq = Decoupled(new Jump_CTarget_Bundle)

    val bcmm_update = Valid(new Branch_CTarget_Bundle)
    val jcmm_update = Valid(new Jump_CTarget_Bundle)

    val flush = Input(Bool())    
  }

  val io: BruIO = IO(new BruIO)

  val bru_exe_iwb_fifo = Module( new Queue( new WriteBack_info(dw=64), 1, true, false ) )
  val bctq = Module(new Queue( new Branch_CTarget_Bundle, (if(!isMinArea) 4 else 1) ) )
  val jctq = Module(new Queue( new Jump_CTarget_Bundle,   (if(!isMinArea) 4 else 1) ) )

  val misPredict_locker = RegInit(false.B)

  val op1 = io.bru_iss_exe.bits.param.dat.op1
  val op2 = io.bru_iss_exe.bits.param.dat.op2
  val imm = io.bru_iss_exe.bits.param.imm
  val pc  = io.bru_iss_exe.bits.param.pc
  val isRVC = io.bru_iss_exe.bits.param.is_rvc
}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Bru_isa extends Bundle {
  val jal  = Bool()
  val jalr = Bool()
  val beq  = Bool()
  val bne  = Bool()
  val blt  = Bool()
  val bge  = Bool()
  val bltu = Bool()
  val bgeu = Bool()

  def is_bru = jal | jalr | beq | bne | blt | bge | bltu | bgeu
  def is_branch = beq | bne | blt | bge | bltu | bgeu
}
// ...
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}
// ...
class Bru_param(implicit p: Parameters) extends RD_PHY {
  val is_rvc = Bool()
  val pc = UInt(64.W)
  val imm = UInt(64.W)

  val dat = new Operation_source(dw=64)

  // override def cloneType = ( new Bru_param ).asInstanceOf[this.type]
}

class Bru_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Bru_isa
  val param = new Bru_param
}
// ...
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}
```

### src/main/scala/rift2Core/define/frontend.scala

```scala
class Branch_FTarget_Bundle(implicit p: Parameters) extends RiftBundle {
  /** Program counter of the branch instruction. */
  val pc = UInt(vlen.W)
  /** Global history register value at the time of the branch. */
  val ghist = UInt(64.W)
  /** Respond of the Bi-Model Predictor */
  val bimResp  = new BIMResp_Bundle
  /** Respond of the TAGE predictor */
  val tageResp = new TageResp_Bundle
  /** Indicates whether the branch is predicted to be taken. */
  val isPredictTaken = Bool()
}

/**
  * Bundle definition for the jump fetch target interface.
  * This bundle represents the information that has been predicted for a jump instruction.
  * @param p the set of parameters defining the RISC-V core
  */
class Jump_FTarget_Bundle(implicit p: Parameters) extends RiftBundle {
  /* Program counter of the jump instruction. */
  val pc       = UInt(vlen.W)
  /* Response of the BTB predictor. */
  val btbResp = new BTBResp_Bundle
  /* Response of the RAS predictor. */
  val rasResp = new RASPP_Bundle
  /* Indicates whether the RAS predictor is being used. */
  val isRas = Bool()

  /** @return true if the BTB predictor is being used, false */
  def isBtb = ~isRas
}

/**
  * Bundle definition for the branch commit target interface.
  * This bundle represents the actual outcome of a branch instruction after execution.
  * @param p the set of parameters defining the RISC-V core
  */
class Branch_CTarget_Bundle(implicit p: Parameters) extends Branch_FTarget_Bundle {
  /** Indicates whether the actual branch outcome is taken or not. */
  val isFinalTaken = Bool()
  /** Actual target address of the branch instruction after execution. */
  val finalTarget = UInt(64.W)

  /** @return true if the actual branch outcome is mispredicted, false otherwise */
  def isMisPredict = isPredictTaken =/= isFinalTaken
}

/**
  * Bundle definition for the jump commit target interface.
  * This bundle represents the actual outcome of a jump instruction after execution.
  * @param p the set of parameters defining the RISC-V core
  */
class Jump_CTarget_Bundle(implicit p: Parameters) extends Jump_FTarget_Bundle {
  /** Actual target address of the jump instruction after execution. */
  val finalTarget = UInt(64.W)

  /** @return true if the actual branch outcome is mispredicted, false otherwise */
  def isMisPredict = Mux(isRas, rasResp.target =/= finalTarget, btbResp.target =/= finalTarget )
}
```

## Related source code

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
  io.bftq <> bftq.io.deq(0)
  io.jftq <> jftq.io.deq(0)
// ...
  bftq.io.enq <> bRePort.io.deq
  jftq.io.enq <> jRePort.io.deq
// ...
    bRePort.io.enq(i).valid := io.if4_req(i).fire & is_branch(i)
    jRePort.io.enq(i).valid := io.if4_req(i).fire & is_jalr(i)
// ...
  instr_fifo.io.flush := io.flush
  bftq.io.flush := io.flush
  jftq.io.flush := io.flush
```

### src/main/scala/rift2Core/backend/Commit.scala

```scala
  io.bctq.ready := ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_branch }.foldLeft(false.B)(_|_)
  assert( ~(io.bctq.ready & ~io.bctq.valid) )
  assert( PopCount( ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_branch } ) <= 1.U )

  io.jctq.ready := ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_jalr }.foldLeft(false.B)(_|_)
  assert( ~(io.jctq.ready & ~io.jctq.valid) )
  assert( PopCount( ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_jalr } ) <= 1.U )
// ...
      .elsewhen( cmm_state(i).is_wb ) {
        when( io.rod(i).bits.is_branch ) {
          when( ( 0 until i ).map{ j => io.rod(j).bits.is_branch}.foldLeft(false.B)(_|_) ){//PopCount( (0 to i).map{ j => io.rod(j).bits.is_branch } ) > 1.U
            commit_state(i) := 0.U
          } .otherwise{
            commit_state(i) := Mux( io.bctq.bits.isMisPredict, 2.U, 3.U ) //mis-predict )
          }
        }
        .elsewhen( io.rod(i).bits.is_jalr ) {
          when( ( 0 until i ).map{ j => io.rod(j).bits.is_jalr}.foldLeft(false.B)(_|_) ){
            commit_state(i) := 0.U
          } .otherwise{
            commit_state(i) := Mux( io.jctq.bits.isMisPredict, 2.U, 3.U ) //mis-predict )
          }
        }
// ...
  for ( i <- 0 until cmChn ) {
    when(io.rod(i).bits.is_branch & io.bctq.bits.isMisPredict & is_retired(i)) {
      io.cmmRedirect.valid := true.B
      io.cmmRedirect.bits.pc := io.bctq.bits.finalTarget
```

## Documentation

### src/unpriv/rv32.adoc

```text
===== Unconditional Jumps
The insn:jal[] (jump and link) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes.
[#norm:jal_target]#The offset is sign-extended and added to the address of the jump instruction to
form the jump target address.# Jumps can therefore target a {pm}1{nbsp}MiB range.
[#norm:jal_op]#insn:jal[] stores the address of the instruction
following the jump (`pc`+4) into register _rd_.#
The standard software calling convention uses `x1` as the return address register and `x5` as
an alternate link register.

[NOTE]
====
The alternate link register supports calling millicode routines (e.g.,
those to save and restore registers in compressed code) while preserving
the regular return address register. The register `x5` was chosen as the
alternate link register as it maps to a temporary in the standard
calling convention, and has an encoding that is only one bit different
than the regular link register.
====

Plain unconditional jumps (assembler pseudoinstruction insn:j[]) are encoded as
a insn:jal[] with _rd_=`x0`.

include::images/wavedrom/ct-unconditional.edn[]
[[ct-unconditional]]
//.The unconditional-jump instruction, JAL

The indirect jump instruction insn:jalr[] (jump and link register) uses the I-type encoding.
[#norm:jalr_target]#The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero.#
[#norm:jalr_op]#The address of the
instruction following the jump (`pc`+4) is written to register _rd_.#
Register `x0` can be used as the destination if the result is not
required.

Plain unconditional indirect jumps (assembler pseudoinstruction insn:jr[]) are
encoded as a insn:jalr[] with _rd_=`x0`.
Procedure returns in the standard calling convention (assembler
pseudoinstruction insn:ret[]) are encoded as a insn:jalr[] with _rd_=`x0`, _rs1_=`x1`, and
_imm_=0.

include::images/wavedrom/ct-unconditional-2.edn[]
[[ct-unconditional-2]]
//.The indirect unconditional-jump instruction, JALR

...

===== Conditional Branches

All branch instructions use the B-type instruction format.
[#norm:br_target]#The 12-bit B-immediate encodes signed offsets in multiples-of-two bytes. The offset
is sign-extended and added to the address of the branch instruction to give the target address.#
The conditional branch range is {pm}4{nbsp}KiB.

include::images/wavedrom/ct-conditional.edn[]
[[ct-conditional]]
//.Conditional branches

Branch instructions compare two registers.
[#norm:beq_bne_op]#insn:beq[] and insn:bne[] take the branch if registers _rs1_ and _rs2_ are equal or unequal respectively.#
[#norm:blt_bltu_op]#insn:blt[] and insn:bltu[] take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively.#
[#norm:bge_bgeu_op]#insn:bge[] and insn:bgeu[] take the branch if _rs1_ is greater than or equal to _rs2_,
using signed and unsigned comparison respectively.#
```

### src/unpriv/cfi.adoc

```text
The ext:zca[] standard extension for compressed instructions provides unconditional
jump and conditional branch instructions. The insn:c.j[] and insn:c.jal[] instructions
encode an offset in the immediate field of the instruction and thus are not
susceptible to control-flow subversion. The insn:c.jr[] and insn:c.jalr[] instructions
perform an unconditional control transfer to the address in register `rs1`. The
insn:c.jalr[] additionally writes the address of the instruction following the jump
(`pc+2`) to the link register `x1` and is a procedure call. The insn:c.jr[] is a
return from procedure if `rs1` is a conventional link register (i.e. `x1` or
`x5`); else it is an indirect jump.
```

## Additional requirement

Each accepted `bru_iss_exe` transfer, including a conditional branch, produces exactly one `bru_exe_iwb` transfer carrying its `rd0`, and records not yet transferred on `bru_exe_iwb`, `bctq` or `jctq` are discarded when `flush` is asserted.
