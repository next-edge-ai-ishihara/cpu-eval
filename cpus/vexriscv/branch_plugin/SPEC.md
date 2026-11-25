# Implement `BranchPlugin`

Implement the complete `BranchPlugin` class. Keep the other definitions of the source file fixed.

Return only the complete `class BranchPlugin` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### cpus/vexriscv/REGRESSION_CONFIGURATION.txt

```text
Branch Early
  catchAll = true
  early = true
```

## Class declaration

### src/main/scala/vexriscv/plugin/BranchPlugin.scala

```scala
package vexriscv.plugin

import vexriscv.Riscv._
import vexriscv._
import spinal.core._
import spinal.lib._
// ...
class BranchPlugin(earlyBranch : Boolean,
                   catchAddressMisaligned : Boolean = false,
                   fenceiGenAsAJump : Boolean = false,
                   fenceiGenAsANop : Boolean = false,
                   decodeBranchSrc2 : Boolean = false) extends Plugin[VexRiscv] with PredictionInterface{
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
class BranchDimension extends VexRiscvDimension("Branch") {

  override def randomPositionImpl(universes: Seq[ConfigUniverse], r: Random) = {
    val catchAll = universes.contains(VexRiscvUniverse.CATCH_ALL)
    val early = r.nextBoolean() || universes.contains(VexRiscvUniverse.NO_MEMORY)
    new VexRiscvPosition(if(early) "Early" else "Late") {
      override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new BranchPlugin(
        earlyBranch = early,
        catchAddressMisaligned = catchAll
      )
    }
  }
}
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/BranchPlugin.scala

```scala
trait BranchPrediction
object NONE extends BranchPrediction
object STATIC  extends BranchPrediction
object DYNAMIC extends BranchPrediction
object DYNAMIC_TARGET extends BranchPrediction

object BranchCtrlEnum extends SpinalEnum(binarySequential){
  val INC,B,JAL,JALR = newElement()
}
object BRANCH_CTRL extends Stageable(BranchCtrlEnum())


case class DecodePredictionCmd() extends Bundle {
  val hadBranch = Bool
}
case class DecodePredictionRsp(stage : Stage) extends Bundle {
  val wasWrong = Bool
}
case class DecodePredictionBus(stage : Stage) extends Bundle {
  val cmd = DecodePredictionCmd()
  val rsp = DecodePredictionRsp(stage)
}

case class FetchPredictionCmd() extends Bundle{
  val hadBranch = Bool
  val targetPc = UInt(32 bits)
}
case class FetchPredictionRsp() extends Bundle{
  val wasRight = Bool
  val finalPc = UInt(32 bits)
  val sourceLastWord = UInt(32 bits)
}
case class FetchPredictionBus(stage : Stage) extends Bundle {
  val cmd = FetchPredictionCmd()
  val rsp = FetchPredictionRsp()
}


trait PredictionInterface{
  def askFetchPrediction() : FetchPredictionBus
  def askDecodePrediction() : DecodePredictionBus
  def inDebugNoFetch() : Unit
}
```

### src/main/scala/vexriscv/plugin/Plugin.scala

```scala
trait Plugin[T <: Pipeline] extends Nameable{
  var pipeline : T = null.asInstanceOf[T]
  setName(this.getClass.getSimpleName.replace("$",""))

  // Used to setup things with other plugins
  def setup(pipeline: T) : Unit = {}

  //Used to flush out the required hardware (called after setup)
  def build(pipeline: T) : Unit

  implicit class implicitsStage(stage: Stage){
    def plug[T <: Area](area : T) : T = {area.setCompositeName(stage,getName()).reflectNames();area}
  }
  implicit class implicitsPipeline(stage: Pipeline){
    def plug[T <: Area](area : T) = {area.setName(getName()).reflectNames();area}
  }
}
```

### src/main/scala/vexriscv/Services.scala

```scala
trait JumpService{
  def createJumpInterface(stage : Stage, priority : Int = 0) : Flow[UInt] //High priority win
}
// ...
trait DecoderService{
  def add(key : MaskedLiteral,values : Seq[(Stageable[_ <: BaseType],Any)])
  def add(encoding :Seq[(MaskedLiteral,Seq[(Stageable[_ <: BaseType],Any)])])
  def addDefault(key : Stageable[_ <: BaseType], value : Any)
  def forceIllegal() : Unit
}

case class ExceptionCause(codeWidth : Int) extends Bundle{
  val code = UInt(codeWidth bits)
  val badAddr = UInt(32 bits)

  def resizeCode(width : Int): ExceptionCause ={
    val ret = ExceptionCause(width)
    ret.badAddr := badAddr
    ret.code := code.resized
    ret
  }
}

trait ExceptionService{
  def newExceptionPort(stage : Stage, priority : Int = 0, codeWidth : Int = 4) : Flow[ExceptionCause]
  def isExceptionPending(stage : Stage) : Bool
}
```

### src/main/scala/vexriscv/plugin/HazardSimplePlugin.scala

```scala
trait HazardService{
  def hazardOnExecuteRS : Bool
}
```

### src/main/scala/vexriscv/VexRiscv.scala

```scala
case class VexRiscvConfig(){
  var withMemoryStage = true
  var withWriteBackStage = true
  val plugins = ArrayBuffer[Plugin[VexRiscv]]()
// ...
  def withRvc = plugins.find(_.isInstanceOf[IBusFetcher]) match {
    case Some(x) => x.asInstanceOf[IBusFetcher].withRvc
    case None => false
  }
// ...
  object IS_RVC extends Stageable(Bool)
  object BYPASSABLE_EXECUTE_STAGE   extends Stageable(Bool)
  object BYPASSABLE_MEMORY_STAGE   extends Stageable(Bool)
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
  object RESULT extends Stageable(UInt(32 bits))
  object PC extends Stageable(UInt(32 bits))
// ...
  object INSTRUCTION extends Stageable(Bits(32 bits))
// ...
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))
// ...
  object SRC1   extends Stageable(Bits(32 bits))
  object SRC2   extends Stageable(Bits(32 bits))
  object SRC_ADD_SUB extends Stageable(Bits(32 bits))
  object SRC_ADD extends Stageable(Bits(32 bits))
  object SRC_SUB extends Stageable(Bits(32 bits))
  object SRC_LESS extends Stageable(Bool)
  object SRC_USE_SUB_LESS extends Stageable(Bool)
  object SRC_LESS_UNSIGNED extends Stageable(Bool)
  object SRC_ADD_ZERO extends Stageable(Bool)
// ...
  object HAS_SIDE_EFFECT extends Stageable(Bool)
// ...
  object Src1CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMU, PC_INCREMENT, URS1 = newElement()   //IMU, IMZ IMJB
  }

  object Src2CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMI, IMS, PC = newElement() //TODO remplacing ZERO could avoid 32 muxes if SRC_ADD can be disabled
  }
  object SRC1_CTRL  extends Stageable(Src1CtrlEnum())
  object SRC2_CTRL  extends Stageable(Src2CtrlEnum())
// ...
}
// ...
class VexRiscv(val config : VexRiscvConfig) extends Component with Pipeline{
  type  T = VexRiscv
  import config._

  //Define stages
  def newStage(): Stage = { val s = new Stage; stages += s; s }
  val decode    = newStage()
  val execute   = newStage()
  val memory    = ifGen(config.withMemoryStage)    (newStage())
  val writeBack = ifGen(config.withWriteBackStage) (newStage())

  def stagesFromExecute = stages.dropWhile(_ != execute)
// ...
}
```

### src/main/scala/vexriscv/plugin/IntAluPlugin.scala

```scala
object IntAluPlugin{
  object AluBitwiseCtrlEnum extends SpinalEnum(binarySequential){
    val XOR, OR, AND = newElement()
  }
  object AluCtrlEnum extends SpinalEnum(binarySequential){
    val ADD_SUB, SLT_SLTU, BITWISE = newElement()
  }

  object ALU_BITWISE_CTRL extends Stageable(AluBitwiseCtrlEnum())
  object ALU_CTRL extends Stageable(AluCtrlEnum())
}
```

### src/main/scala/vexriscv/Riscv.scala

```scala
object Riscv{
// ...
  case class IMM(instruction  : Bits) extends Area{
    // immediates
    def i = instruction(31 downto 20)
    def h = instruction(31 downto 24)
    def s = instruction(31 downto 25) ## instruction(11 downto 7)
    def b = instruction(31) ## instruction(7) ## instruction(30 downto 25) ## instruction(11 downto 8)
    def u = instruction(31 downto 12) ## U"x000"
    def j = instruction(31) ## instruction(19 downto 12) ## instruction(20) ## instruction(30 downto 21)
    def z = instruction(19 downto 15)

    // sign-extend immediates
    def i_sext = B((19 downto 0) -> i(11)) ## i
    def h_sext = B((23 downto 0) -> h(7))  ## h
    def s_sext = B((19 downto 0) -> s(11)) ## s
    def b_sext = B((18 downto 0) -> b(11)) ## b ## False
    def j_sext = B((10 downto 0) -> j(19)) ## j ## False
  }
// ...
  def BEQ (rvc : Boolean) = if(rvc) M"-----------------000-----1100011" else M"-----------------000---0-1100011"
  def BNE (rvc : Boolean) = if(rvc) M"-----------------001-----1100011" else M"-----------------001---0-1100011"
  def BLT (rvc : Boolean) = if(rvc) M"-----------------100-----1100011" else M"-----------------100---0-1100011"
  def BGE (rvc : Boolean) = if(rvc) M"-----------------101-----1100011" else M"-----------------101---0-1100011"
  def BLTU(rvc : Boolean) = if(rvc) M"-----------------110-----1100011" else M"-----------------110---0-1100011"
  def BGEU(rvc : Boolean) = if(rvc) M"-----------------111-----1100011" else M"-----------------111---0-1100011"
  def JALR               = M"-----------------000-----1100111"
  def JAL(rvc : Boolean) = if(rvc) M"-------------------------1101111" else M"----------0--------------1101111"
// ...
  def FENCEI             = M"00000000000000000001000000001111"
// ...
}
```

### src/main/scala/vexriscv/Pipeline.scala

```scala
trait Pipeline {
  type T <: Pipeline
  val plugins = ArrayBuffer[Plugin[T]]()
  var stages = ArrayBuffer[Stage]()
// ...
  def service[T](clazz : Class[T]) = {
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
    assert(filtered.length == 1, s"??? ${clazz.getName}")
    filtered.head.asInstanceOf[T]
  }
// ...
```

### src/main/scala/vexriscv/Stage.scala

```scala
class Stageable[T <: Data](_dataType : => T) extends HardType[T](_dataType) with Nameable{
  def dataType = apply()
  setWeakName(this.getClass.getSimpleName.replace("$",""))
}

class Stage() extends Area{
// ...
  def input[T <: Data](key : Stageable[T]) : T = {
    inputs.getOrElseUpdate(key.asInstanceOf[Stageable[Data]],outsideCondScope{
      val input,inputDefault = key()
      inputsDefault(key.asInstanceOf[Stageable[Data]]) = inputDefault
      input := inputDefault
      input.setPartialName(this, key.getName())
    }).asInstanceOf[T]
  }

  def output[T <: Data](key : Stageable[T]) : T = {
    outputs.getOrElseUpdate(key.asInstanceOf[Stageable[Data]],outsideCondScope{
      val output,outputDefault = key()
      outputsDefault(key.asInstanceOf[Stageable[Data]]) = outputDefault
      output := outputDefault
      output //.setPartialName(this,"output_" + key.getName())
    }).asInstanceOf[T]
  }

  def insert[T <: Data](key : Stageable[T]) : T = inserts.getOrElseUpdate(key.asInstanceOf[Stageable[Data]],outsideCondScope(key())).asInstanceOf[T] //.setPartialName(this,key.getName())
//  def apply[T <: Data](key : Stageable[T]) : T = ???


  val arbitration = new Area{
    val haltItself  = False   //user settable, stuck the instruction, should only be set by the instruction itself
    val haltByOther = False   //When settable, stuck the instruction, should only be set by something else than the stucked instruction
    val removeIt    = False   //When settable, unschedule the instruction as if it was never executed (no side effect)
    val flushIt    = False   //When settable, unschedule the current instruction
    val flushNext    = False   //When settable, unschedule instruction above in the pipeline
    val isValid     = Bool //Inform if a instruction is in the current stage
    val isStuck     = Bool           //Inform if the instruction is stuck (haltItself || haltByOther)
    val isStuckByOthers = Bool       //Inform if the instruction is stuck by sombody else
    def isRemoved   = removeIt       //Inform if the instruction is going to be unschedule the current cycle
    val isFlushed   = Bool           //Inform if the instruction is flushed (flushAll set in the current or subsequents stages)
    val isMoving     = Bool           //Inform if the instruction is going somewere else (next stage or unscheduled)
    val isFiring    = Bool           //Inform if the current instruction will go to the next stage the next cycle (isValid && !isStuck && !removeIt)
  }


// ...
}
```

## Related source code

### src/main/scala/vexriscv/plugin/Fetcher.scala

```scala
    prediction match {
      case NONE =>
      case STATIC | DYNAMIC => {
        predictionJumpInterface = createJumpInterface(pipeline.decode)
        decodePrediction = pipeline.service(classOf[PredictionInterface]).askDecodePrediction()
      }
      case DYNAMIC_TARGET => {
        fetchPrediction = pipeline.service(classOf[PredictionInterface]).askFetchPrediction()
      }
    }
// ...
        val (iBusRspContext, iBusRspContextOutput, injectorContext) = stage1ToInjectorPipe(fetchContext)

        object PREDICTION_CONTEXT extends Stageable(PredictionResult())
        pipeline.decode.insert(PREDICTION_CONTEXT) := injectorContext
        val branchStage = fetchPrediction.stage
        val branchContext = branchStage.input(PREDICTION_CONTEXT)

        fetchPrediction.cmd.hadBranch := branchContext.hit && !branchContext.hazard && branchContext.line.branchWish.msb
        fetchPrediction.cmd.targetPc := branchContext.line.target


        historyWrite.valid := False
        historyWrite.address := fetchPrediction.rsp.sourceLastWord(2, historyRamSizeLog2 bits)
        historyWrite.data.source := fetchPrediction.rsp.sourceLastWord.asBits >> 2 + historyRamSizeLog2
        historyWrite.data.target := fetchPrediction.rsp.finalPc
        if(compressedGen) historyWrite.data.last2Bytes := fetchPrediction.stage.input(PC)(1) && fetchPrediction.stage.input(IS_RVC)
// ...
```

### src/main/scala/vexriscv/plugin/DebugPlugin.scala

```scala
      when(godmode) {
        pipeline.plugins.foreach{
          case p : ExceptionInhibitor => p.inhibateException()
          case _ =>
        }
        pipeline.plugins.foreach{
          case p : PrivilegeService => p.forceMachine()
          case _ =>
        }
        pipeline.plugins.foreach{
          case p : PredictionInterface => p.inDebugNoFetch()
          case _ =>
        }
        if(pipeline.things.contains(DEBUG_BYPASS_CACHE)) pipeline(DEBUG_BYPASS_CACHE) := True
      }
// ...
```

## Documentation

### README.md

```text
#### BranchPlugin

This plugin implements all branch/jump instructions (JAL/JALR/BEQ/BNE/BLT/BGE/BLTU/BGEU) with primitives used by the cpu frontend plugins to implement branch prediction. The prediction implementation is set in the frontend plugins (IBusX).

| Parameters | type | description |
| ------ | ----------- | ------ |
| earlyBranch | Boolean | By default the branch is done in the Memory stage to relax timings, but if this option is set it's done in the Execute stage|
| catchAddressMisaligned | Boolean | If a jump/branch is done in an unaligned PC address, it will fire an trap exception |

Each miss predicted jumps will produce between 2 and 4 cycles penalty depending the `earlyBranch` and the `PcManagerSimplePlugin.relaxedPcCalculation` configurations

##### Prediction NONE

No prediction: each PC change due to a jump/branch will produce a penalty.

##### Prediction STATIC

In the decode stage, a conditional branch pointing backwards or a JAL is branched speculatively. If the speculation is right, the branch penalty is reduced to a single cycle,
otherwise the standard penalty is applied.

##### Prediction DYNAMIC

Same as the STATIC prediction, except that to do the prediction, it uses a direct mapped 2 bit history cache (BHT) which remembers if the branch is more likely to be taken or not.

##### Prediction DYNAMIC_TARGET

This predictor uses a direct mapped branch target buffer (BTB) in the Fetch stage which stores the PC of the instruction, the target PC of the instruction and a 2 bit history to remember
if the branch is more likely to be taken or not. This is actually the most efficient branch predictor implemented on VexRiscv, because when the branch prediction is right, it produces no branch penalty.
The downside is that this predictor has a long combinatorial path coming from the prediction cache read port to the programm counter, passing through the jump interface.

```

### src/rv32.adoc

```text
==== Unconditional Jumps
The jump and link (JAL) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes. The offset
is sign-extended and added to the address of the jump instruction to
form the jump target address. Jumps can therefore target a
&#177;1 MiB range. JAL stores the address of the instruction
following the jump ('pc'+4) into register _rd_. The standard software
calling convention uses 'x1' as the return address register and 'x5' as
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

Plain unconditional jumps (assembler pseudoinstruction J) are encoded as
a JAL with _rd_=`x0`.

...
The indirect jump instruction JALR (jump and link register) uses the
I-type encoding. The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero. The address of the
instruction following the jump (`pc`+4) is written to register _rd_.
Register `x0` can be used as the destination if the result is not
required.

Plain unconditional indirect jumps (assembler pseudoinstruction JR) are
encoded as a JALR with _rd_=`x0`.
Procedure returns in the standard calling convention (assembler
pseudoinstruction RET) are encoded as a JALR with _rd_=`x0`, _rs1_=`x1`, and
_imm_=0.
...
[NOTE]
====
The unconditional jump instructions all use PC-relative addressing to
help support position-independent code. The JALR instruction was defined
to enable a two-instruction sequence to jump anywhere in a 32-bit
absolute address range. A LUI instruction can first load _rs1_ with the
upper 20 bits of a target address, then JALR can add in the lower bits.
Similarly, AUIPC then JALR can jump anywhere in a 32-bit `pc`-relative
address range.

Note that the JALR instruction does not treat the 12-bit immediate as
multiples of 2 bytes, unlike the conditional branch instructions. This
avoids one more immediate format in hardware. In practice, most uses of
JALR will have either a zero immediate or be paired with a LUI or AUIPC,
so the slight reduction in range is not significant.

Clearing the least-significant bit when calculating the JALR target
address both simplifies the hardware slightly and allows the low bit of
function pointers to be used to store auxiliary information. Although
there is potentially a slight loss of error checking in this case, in
practice jumps to an incorrect instruction address will usually quickly
raise an exception.

When used with a base _rs1_=`x0`, JALR can be used to
implement a single instruction subroutine call to the lowest or highest
address region from anywhere in the address space, which could be used
to implement fast calls to a small runtime library. Alternatively, an
ABI could dedicate a general-purpose register to point to a library
elsewhere in the address space.
====

The JAL and JALR instructions will generate an
instruction-address-misaligned exception if the target address is not
aligned to a four-byte boundary.

[NOTE]
====
Instruction-address-misaligned exceptions are not possible on machines
that support extensions with 16-bit aligned instructions, such as the
compressed instruction-set extension, C.
====
...
==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.

...
Branch instructions compare two registers. BEQ and BNE take the branch
if registers _rs1_ and _rs2_ are equal or unequal respectively. BLT and
BLTU take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively. BGE and BGEU take the branch if _rs1_
is greater than or equal to _rs2_, using signed and unsigned comparison
respectively. Note, BGT, BGTU, BLE, and BLEU can be synthesized by
reversing the operands to BLT, BLTU, BGE, and BGEU, respectively.

[NOTE]
====
Signed array bounds may be checked with a single BLTU instruction, since
any negative index will compare greater than any nonnegative bound.
====
...
The conditional branch instructions will generate an
instruction-address-misaligned exception if the target address is not
aligned to a four-byte boundary and the branch condition evaluates to
true. If the branch condition evaluates to false, the
instruction-address-misaligned exception will not be raised.
```

### src/machine.adoc

```text
If `mtval` is written with a nonzero value when a breakpoint,
address-misaligned, access-fault, or page-fault exception occurs on an
instruction fetch, load, or store, then `mtval` will contain the
faulting virtual address.
```
