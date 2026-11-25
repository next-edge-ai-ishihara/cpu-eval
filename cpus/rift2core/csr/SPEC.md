# Implement `CSR`

Implement the complete `CSR` class. Preserve the class name and interface shown below.

Return only the complete `class CSR` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class CSR(implicit p: Parameters) extends CSRBase 
```

## Parent instantiation

```scala
  val csr = Module(new CSR)
// ...
  csr.io.csr_iss_exe <> io.csr_iss_exe
  csr.io.csr_exe_iwb <> io.csr_exe_iwb
  csr.io.flush <> io.flush
  io.xpuCsrWriteBack := csr.io.xpuCsrWriteBack
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Csr.scala

```scala
abstract class CSRBase(implicit p: Parameters) extends RiftModule {

  class CsrIO extends Bundle {

    val csr_iss_exe = Flipped(new DecoupledIO(new Csr_iss_info))
    val csr_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))
    val xpuCsrWriteBack = Valid(new Exe_Port)

    val flush = Input(Bool())    
  }

  val io: CsrIO = IO(new CsrIO)

  val csr_exe_iwb_fifo = Module( new Queue( new WriteBack_info(dw=64), 1, true, false ) )
  io.csr_exe_iwb <> csr_exe_iwb_fifo.io.deq
  csr_exe_iwb_fifo.reset := reset.asBool | io.flush


  val rw = io.csr_iss_exe.bits.fun.rw
  val rs = io.csr_iss_exe.bits.fun.rs
  val rc = io.csr_iss_exe.bits.fun.rc
  
  val dat = io.csr_iss_exe.bits.param.dat.op1
  val addr = io.csr_iss_exe.bits.param.dat.op3(11,0)

  val dontWrite = (dat === 0.U) & ( rs | rc )


  io.csr_iss_exe.ready     := csr_exe_iwb_fifo.io.enq.fire



}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}
// ...
class Operation_source(dw: Int)(implicit p: Parameters) extends RiftBundle {
  val op0 = UInt(dw.W)
  val op1 = UInt(dw.W)
  val op2 = UInt(dw.W)
  val op3 = UInt(dw.W)
}
// ...
class Csr_function(implicit p: Parameters) extends RiftBundle {
  val rw  = Bool()
  val rs  = Bool()
  val rc  = Bool()

  val vsetvli  = Bool()
  val vsetivli = Bool()
  val vsetvl   = Bool()
}
// ...
class Csr_param(implicit p: Parameters) extends RD_PHY {
  val dat = new Operation_source(dw=64)

  // override def cloneType = ( new Csr_param ).asInstanceOf[this.type]
}
// ...
class Csr_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Csr_function
  val param = new Csr_param
}
// ...
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}
```

### src/main/scala/rift2Core/privilege/CsrFiles.scala

```scala
class CsrOperator extends Bundle{
  val dat_i = UInt(64.W)
  val op_rw = Bool()
  val op_rs = Bool()
  val op_rc = Bool()
}

class Exe_Port extends CsrOperator {
  val addr = UInt(12.W)
}
```

## Related source code

### src/main/scala/rift2Core/backend/Issue.scala

```scala
  def Pkg_csr_iss(idx: Int): Csr_iss_info = {
    val res = Wire(new Csr_iss_info)
    val csrSel = bufInfo(idx).param.imm(11,0)

    res.fun.rc  := bufInfo(idx).csrIsa.rc | bufInfo(idx).csrIsa.rci
    res.fun.rs  := bufInfo(idx).csrIsa.rs | bufInfo(idx).csrIsa.rsi
    res.fun.rw  := bufInfo(idx).csrIsa.rw | bufInfo(idx).csrIsa.rwi
    res.fun.vsetvli  := ( if(hasVector) {bufInfo(idx).csrIsa.vsetvli  } else {false.B} )
    res.fun.vsetivli := ( if(hasVector) {bufInfo(idx).csrIsa.vsetivli } else {false.B} )
    res.fun.vsetvl   := ( if(hasVector) {bufInfo(idx).csrIsa.vsetvl   } else {false.B} )

    res.param.dat.op1 := 
      Mux1H(
        Seq(
          bufInfo(idx).csrIsa.rw  -> postBufOperator(idx)(1), bufInfo(idx).csrIsa.rwi -> bufInfo(idx).param.raw.rs1,
          bufInfo(idx).csrIsa.rs  -> postBufOperator(idx)(1), bufInfo(idx).csrIsa.rsi -> bufInfo(idx).param.raw.rs1,
          bufInfo(idx).csrIsa.rc  -> postBufOperator(idx)(1), bufInfo(idx).csrIsa.rci -> bufInfo(idx).param.raw.rs1,
        ) ++
        ( if(hasVector){
          Seq(
            bufInfo(idx).csrIsa.vsetvli  -> Mux( bufInfo(idx).param.raw.rs1 =/= 0.U, postBufOperator(idx)(1), Mux(bufInfo(idx).param.raw.rd0 =/= 0.U, Fill(64,1.U), io.csrfiles.vl) ),
            bufInfo(idx).csrIsa.vsetivli -> bufInfo(idx).param.raw.rs1,
            bufInfo(idx).csrIsa.vsetvl   -> Mux( bufInfo(idx).param.raw.rs1 =/= 0.U, postBufOperator(idx)(1), Mux(bufInfo(idx).param.raw.rd0 =/= 0.U, Fill(64,1.U), io.csrfiles.vl) ),
          ) } else {Seq()})
      )




    /** automatically create csr address mux according CSRInfoTable */
    res.param.dat.op2 := 
      Mux(
        bufInfo(idx).csrIsa.isXCSR,
        Mux1H(
          (for ( info <- CSRInfoTable.CSRGroup; io <- io.csrfiles.elements; if( (info.name == io._1) ) ) yield {
            (csrSel === (info.address).U) -> ( io._2.asUInt )
          }) ++

          (for( i <- 0 until pmpNum by 2 ) yield{
            ((csrSel === ("h3A0".U + i.U)) -> io.csrfiles.pmpcfg(i).asUInt)
          }) ++

          (for( i <- 0 until pmpNum*8 ) yield{
            ((csrSel === ("h3B0".U + i.U)) -> io.csrfiles.pmpaddr(i).asUInt)
          }) ++

          (for( i <- 3 until 32 ) yield{
            ((csrSel === ("hB00".U + i.U)) -> io.csrfiles.mhpmcounter(i))
          }) ++

          (for( i <- 3 until 32 ) yield{
            ((csrSel === ("h320".U + i.U)) -> io.csrfiles.mhpmevent(i))
          }) ++ 

          (for( i <- 3 until 32 ) yield{
            ((csrSel === ("hC00".U + i.U)) -> io.csrfiles.hpmcounter(i))
          })
        ),
        (if(hasVector){ Mux1H(Seq(
          bufInfo(idx).csrIsa.vsetvli  -> bufInfo(idx).param.imm(10,0),
          bufInfo(idx).csrIsa.vsetivli -> bufInfo(idx).param.imm(9,0),
          bufInfo(idx).csrIsa.vsetvl   -> postBufOperator(idx)(2),
        ))} else {0.U})
      )


    res.param.dat.op0 := 0.U
    res.param.dat.op3 := 
      Mux(
        ( if(hasVector){ bufInfo(idx).csrIsa.vsetvli | bufInfo(idx).csrIsa.vsetivli | bufInfo(idx).csrIsa.vsetvl } else {false.B} ),
        "hffe".U(12.W),
        bufInfo(idx).param.imm(11,0)
      )
      

    res.param.rd0     := bufInfo(idx).phy.rd0

    return res
  }
```

### src/main/scala/rift2Core/privilege/CsrFiles.scala

```scala
object Reg_Exe_Port {

  def apply( csr_reg: UInt, addr: UInt, ep: Exe_Port ): (Bool, UInt) = {
    val enable = (ep.addr === addr) & (ep.op_rw | ep.op_rs | ep.op_rc)
    val dnxt = Mux1H(Seq(
        ep.op_rw -> ( ep.dat_i),
        ep.op_rs -> (csr_reg | ep.dat_i),
        ep.op_rc -> (csr_reg & ~ep.dat_i),
      ))
    return (enable, dnxt)
  }
}
```

### src/main/scala/rift2Core/backend/WriteBack.scala

```scala
  val cReg = Module(new CsrScoreBoard)
// ...
  io.xpuCsrWriteBack <> cReg.io.xpu.writeBack
```

### src/main/scala/rift2Core/privilege/CsrScoreBoard.scala

```scala
class XPUCsrIO(implicit p: Parameters) extends RiftBundle{
  /** The csr allocation signal, used at rename stage */
  val molloc    = Vec(rnChn, Flipped(Decoupled(UInt(12.W))))
  /** The write-back signal, used at execute stage */
  val writeBack = Flipped(Valid(new Exe_Port))
  /** The commit signal, used at commit stage */
  val commit    = Decoupled(new Exe_Port)
}
// ...
    xpuInflyCounter.io.enq.valid := io.xpu.molloc.map{ x => x.fire }.foldLeft(false.B)(_|_)
    xpuInflyCounter.io.enq.bits  := DontCare
// ...
  xpuWriteBackFifo.io.enq.valid := io.xpu.writeBack.fire
  xpuWriteBackFifo.io.enq.bits  := io.xpu.writeBack.bits
  assert(~(xpuWriteBackFifo.io.enq.valid & ~xpuWriteBackFifo.io.enq.ready), "Assert Failed at xpuWriteBackFifo, Overflow!\n")

  for( i <- 0 until cmChn ) {
    xpuInflyCounter.io.deq.ready := io.xpu.commit.fire
    assert( ~(xpuInflyCounter.io.deq.ready & ~xpuInflyCounter.io.deq.valid) )
    
    io.xpu.commit <> xpuWriteBackFifo.io.deq
    assert( ~(xpuWriteBackFifo.io.deq.ready & ~xpuWriteBackFifo.io.deq.valid) )
  }
```

## Documentation

### src/unpriv/zicsr.adoc

```text
==== CSR Instructions

All CSR instructions atomically read-modify-write a single CSR, whose
CSR specifier is encoded in the 12-bit _csr_ field of the instruction
held in bits 31-20. The immediate forms use a 5-bit zero-extended
immediate encoded in the _rs1_ field.

include::images/wavedrom/csr-instr.edn[]

[[norm:csrrw_op]]
The insn:csrrw[] (Atomic Read/Write CSR) instruction atomically swaps values in
the CSRs and integer registers. insn:csrrw[] reads the old value of the CSR,
zero-extends the value to XLEN bits, then writes it to integer register
_rd_. The initial value in _rs1_ is written to the CSR. If _rd_=`x0`,
then the instruction shall not read the CSR and shall not cause any of
the side effects that might occur on a CSR read.

[[norm:csrrs_op]]
The insn:csrrs[] (Atomic Read and Set Bits in CSR) instruction reads the value
of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be set in the CSR.
Any bit that is high in _rs1_ will cause the corresponding bit to be set
in the CSR, if that CSR bit is writable.

[[norm:csrrc_op]]
The insn:csrrc[] (Atomic Read and Clear Bits in CSR) instruction reads the
value of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be cleared in the
CSR. Any bit that is high in _rs1_ will cause the corresponding bit to
be cleared in the CSR, if that CSR bit is writable.

[NOTE]
====
Since insn:csrrs[] and insn:csrrc[] perform a read-modify-write operation, any bits that read as
a different value to their underlying value may be modified by these
instructions even if the corresponding bit is not set in _rs1_. For example,
pmpaddr__n__[G-1] may have an underlying value of 1 but read as 0. Executing
insn:csrrc[] or insn:csrrs[] to modify a different bit will cause 0 to be read from
pmpaddr__n__[G-1] and then written back, updating the underlying value to 0.
====

[[norm:csrrs_csrrc_rs1_x0]]
For both insn:csrrs[] and insn:csrrc[], if _rs1_=`x0`, then the instruction will not
write to the CSR at all, and so shall not cause any of the side effects
that might otherwise occur on a CSR write, nor raise illegal-instruction
exceptions on accesses to read-only CSRs. Both insn:csrrs[] and insn:csrrc[] always
read the addressed CSR and cause any read side effects regardless of
_rs1_ and _rd_ fields.
Note that if _rs1_ specifies a register other than `x0`, and that register
holds a zero value, the instruction will not action any attendant per-field
side effects, but will action any side effects caused by writing to the entire
CSR.

[[norm:csrrw_rs1_x0]]
A insn:csrrw[] with _rs1_=`x0` will attempt to write zero to the destination CSR.

[[norm:csrrwi_csrrsi_csrrci_ops]]
The insn:csrrwi[], insn:csrrsi[], and insn:csrrci[] variants are similar to insn:csrrw[], insn:csrrs[], and
insn:csrrc[] respectively, except they update the CSR using an XLEN-bit value
obtained by zero-extending a 5-bit unsigned immediate (uimm[4:0]) field
encoded in the _rs1_ field instead of a value from an integer register.
[#norm:csrrsi_csrrci_uimm_zero]#For insn:csrrsi[] and insn:csrrci[], if the uimm[4:0] field is zero, then these
instructions will not write to the CSR, and shall not cause any of the
side effects that might otherwise occur on a CSR write, nor raise
illegal-instruction exceptions on accesses to read-only CSRs.# [#norm:csrrwi_rd_x0]#For
insn:csrrwi[], if _rd_=`x0`, then the instruction shall not read the CSR and
shall not cause any of the side effects that might occur on a CSR read.#
Both insn:csrrsi[] and insn:csrrci[] will always read the CSR and cause any read side
effects regardless of _rd_ and _rs1_ fields.

[[csrsideeffects]]
.Conditions determining whether a CSR instruction reads or writes the specified CSR.
[%autowidth,float="center",align="center",cols="<,^,^,^,^",options="header",]
|===
5+^|*Register operand*
|Instruction |_rd_ is `x0` |_rs1_ is `x0` |Reads CSR |Writes CSR

|insn:csrrw[] |Yes |- |No |Yes

|insn:csrrw[] |No |- |Yes |Yes

|insn:csrrs[]/insn:csrrc[] |- |Yes |Yes |No

|insn:csrrs[]/insn:csrrc[] |- |No |Yes |Yes

5+^|*Immediate operand*

|Instruction |_rd_ is `x0` |_uimm_=0 |Reads CSR |Writes
CSR

|insn:csrrwi[] |Yes |- |No |Yes

|insn:csrrwi[] |No |- |Yes |Yes

|insn:csrrsi[]/insn:csrrci[] |- |Yes |Yes |No

|insn:csrrsi[]/insn:csrrci[] |- |No |Yes |Yes
|===
```
