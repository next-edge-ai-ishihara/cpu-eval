# Implement `BreakpointUnit`

Implement one complete `BreakpointUnit` source-level hardware definition. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class BreakpointUnit` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package freechips.rocketchip.rocket

import chisel3._
import chisel3.util.{Cat}
import Chisel.ImplicitConversions._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile.{CoreBundle, HasCoreParameters}
import freechips.rocketchip.util._
```

## Class declaration

```scala
class BreakpointUnit(n: Int)(implicit val p: Parameters) extends Module with HasCoreParameters {
  val io = IO(new Bundle {
    val status = Input(new MStatus())
    val bp = Input(Vec(n, new BP))
    val pc = Input(UInt(vaddrBits.W))
    val ea = Input(UInt(vaddrBits.W))
    val mcontext = Input(UInt(coreParams.mcontextWidth.W))
    val scontext = Input(UInt(coreParams.scontextWidth.W))
    val xcpt_if  = Output(Bool())
    val xcpt_ld  = Output(Bool())
    val xcpt_st  = Output(Bool())
    val debug_if = Output(Bool())
    val debug_ld = Output(Bool())
    val debug_st = Output(Bool())
    val bpwatch  = Output(Vec(n, new BPWatch(1)))
  })
```

## Parent instantiation

### src/main/scala/ifu/frontend.scala

```scala
      val bpu = Module(new BreakpointUnit(nBreakpoints))
      bpu.io.status   := io.cpu.status
      bpu.io.bp       := io.cpu.bp
      bpu.io.ea       := DontCare
      bpu.io.mcontext := io.cpu.mcontext
      bpu.io.scontext := io.cpu.scontext
// ...
      f3_fetch_bundle.bp_debug_if_oh(i) := bpu.io.debug_if
      f3_fetch_bundle.bp_xcpt_if_oh (i) := bpu.io.xcpt_if
```

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
  val bkptu = Module(new BreakpointUnit(nBreakpoints))
  bkptu.io.status   := io.status
  bkptu.io.bp       := io.bp
  bkptu.io.pc       := DontCare
  bkptu.io.ea       := effective_address
  bkptu.io.mcontext := io.mcontext
  bkptu.io.scontext := io.scontext

  val ma_ld  = io.req.valid && io.req.bits.uop.uopc === uopLD && misaligned
  val ma_st  = io.req.valid && (io.req.bits.uop.uopc === uopSTA || io.req.bits.uop.uopc === uopAMO_AG) && misaligned
  val dbg_bp = io.req.valid && ((io.req.bits.uop.uopc === uopLD  && bkptu.io.debug_ld) ||
                                (io.req.bits.uop.uopc === uopSTA && bkptu.io.debug_st))
  val bp     = io.req.valid && ((io.req.bits.uop.uopc === uopLD  && bkptu.io.xcpt_ld) ||
                                (io.req.bits.uop.uopc === uopSTA && bkptu.io.xcpt_st))
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/rocket/Breakpoint.scala

```scala
class BPControl(implicit p: Parameters) extends CoreBundle()(p) {
  val ttype = UInt(4.W)
  val dmode = Bool()
  val maskmax = UInt(6.W)
  val reserved = UInt((xLen - (if (coreParams.useBPWatch) 26 else 24)).W)
  val action = UInt((if (coreParams.useBPWatch) 3 else 1).W)
  val chain = Bool()
  val zero = UInt(2.W)
  val tmatch = UInt(2.W)
  val m = Bool()
  val h = Bool()
  val s = Bool()
  val u = Bool()
  val x = Bool()
  val w = Bool()
  val r = Bool()

  def tType = 2
  def maskMax = 4
  def enabled(mstatus: MStatus) = !mstatus.debug && Cat(m, h, s, u)(mstatus.prv)
}

class TExtra(implicit p: Parameters) extends CoreBundle()(p) {
  def mvalueBits: Int = if (xLen == 32) coreParams.mcontextWidth min  6 else coreParams.mcontextWidth min 13
  def svalueBits: Int = if (xLen == 32) coreParams.scontextWidth min 16 else coreParams.scontextWidth min 34
  def mselectPos: Int = if (xLen == 32) 25 else 50
  def mvaluePos : Int = mselectPos + 1
  def sselectPos: Int = 0
  def svaluePos : Int = 2

  val mvalue  = UInt(mvalueBits.W)
  val mselect = Bool()
  val pad2    = UInt((mselectPos - svalueBits - 2).W)
  val svalue  = UInt(svalueBits.W)
  val pad1    = UInt(1.W)
  val sselect = Bool()
}

class BP(implicit p: Parameters) extends CoreBundle()(p) {
  val control = new BPControl
  val address = UInt(vaddrBits.W)
  val textra  = new TExtra

  def contextMatch(mcontext: UInt, scontext: UInt) =
    (if (coreParams.mcontextWidth > 0) (!textra.mselect || (mcontext(textra.mvalueBits-1,0) === textra.mvalue)) else true.B) &&
    (if (coreParams.scontextWidth > 0) (!textra.sselect || (scontext(textra.svalueBits-1,0) === textra.svalue)) else true.B)

  def mask(dummy: Int = 0) =
    (0 until control.maskMax-1).scanLeft(control.tmatch(0))((m, i) => m && address(i)).asUInt

  def pow2AddressMatch(x: UInt) =
    (~x | mask()) === (~address | mask())

  def rangeAddressMatch(x: UInt) =
    (x >= address) ^ control.tmatch(0)

  def addressMatch(x: UInt) =
    Mux(control.tmatch(1), rangeAddressMatch(x), pow2AddressMatch(x))
}

class BPWatch (val n: Int) extends Bundle() {
  val valid = Vec(n, Bool())
  val rvalid = Vec(n, Bool())
  val wvalid = Vec(n, Bool())
  val ivalid = Vec(n, Bool())
  val action = UInt(3.W)
}
```

## Related source code

### src/main/scala/rocket/RocketCore.scala

```scala
    ex_reg_wphit := bpu.io.bpwatch.map { bpw => bpw.ivalid(0) }
// ...
    wb_reg_wphit := mem_reg_wphit | bpu.io.bpwatch.map { bpw => (bpw.rvalid(0) && mem_reg_load) || (bpw.wvalid(0) && mem_reg_store) }
// ...
  for (((iobpw, wphit), bp) <- io.bpwatch zip wb_reg_wphit zip csr.io.bp) {
    iobpw.valid(0) := wphit
    iobpw.action := bp.control.action
  }
```

## Documentation

### xml/hwbp_registers.xml

```text
        <field name="action" bits="17:12" access="R/W" reset="0">
            Determines what happens when this trigger matches.

            0: Raise a breakpoint exception. (Used when software wants to use
            the trigger module without an external debugger attached.)

            1: Enter Debug Mode. (Only supported when \Fdmode is 1.)

            2: Start tracing.

            3: Stop tracing.

            4: Emit trace data for this match. If it is a data access match,
            emit appropriate Load/Store Address/Data. If it is an instruction
            execution, emit its PC.

            Other values are reserved for future use.
        </field>
        <field name="chain" bits="11" access="R/W" reset="0">
            0: When this trigger matches, the configured action is taken.

            1: While this trigger does not match, it prevents the trigger with
            the next index from matching.
        </field>
...
        <field name="m" bits="6" access="R/W" reset="0">
            When set, enable this trigger in M mode.
        </field>
        <field name="h" bits="5" access="R/W" reset="0">
            When set, enable this trigger in H mode.
        </field>
        <field name="s" bits="4" access="R/W" reset="0">
            When set, enable this trigger in S mode.
        </field>
        <field name="u" bits="3" access="R/W" reset="0">
            When set, enable this trigger in U mode.
        </field>
        <field name="execute" bits="2" access="R/W" reset="0">
            When set, the trigger fires on the virtual address or opcode of an
            instruction that is executed.
        </field>
        <field name="store" bits="1" access="R/W" reset="0">
            When set, the trigger fires on the virtual address or data of a store.
        </field>
        <field name="load" bits="0" access="R/W" reset="0">
            When set, the trigger fires on the virtual address or data of a load.
        </field>
```
