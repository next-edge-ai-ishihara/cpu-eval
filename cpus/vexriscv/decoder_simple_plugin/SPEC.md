# Implement `DecoderSimplePlugin`

Implement the complete `DecoderSimplePlugin` class. Keep the `Masked` definition fixed.

Return only the complete `class DecoderSimplePlugin` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### cpus/vexriscv/REGRESSION_CONFIGURATION.txt

```text
Decoder
  catchAll = true
```

## Class declaration

### src/main/scala/vexriscv/plugin/DecoderSimplePlugin.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
import spinal.core.internals.Literal
import spinal.lib._
import vexriscv.demo.GenFull

import scala.collection.mutable
import scala.collection.mutable.ArrayBuffer
// ...
class DecoderSimplePlugin(catchIllegalInstruction : Boolean = false,
                          throwIllegalInstruction : Boolean = false,
                          assertIllegalInstruction : Boolean = false,
                          forceLegalInstructionComputation : Boolean = false,
                          decoderIsolationBench : Boolean = false,
                          stupidDecoder : Boolean = false) extends Plugin[VexRiscv] with DecoderService {
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
class DecoderDimension extends VexRiscvDimension("Decoder") {

  override def randomPositionImpl(universes: Seq[ConfigUniverse], r: Random) = {
    val catchAll = universes.contains(VexRiscvUniverse.CATCH_ALL)
    new VexRiscvPosition("") {
      override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new DecoderSimplePlugin(
        catchIllegalInstruction = catchAll,
        throwIllegalInstruction = false
      )

//      override def isCompatibleWith(positions: Seq[ConfigPosition[VexRiscvConfig]]) = catchAll == positions.exists(_.isInstanceOf[CatchAllPosition])
    }
  }
}
```

## Dependency declarations

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

### core/src/main/scala/spinal/core/MaskedLiteral.scala

```scala
object MaskedLiteral{

  def apply(str: String): MaskedLiteral = {
    val strCleaned = str.replace("_", "")

    for(c <- strCleaned) assert(c == '1' || c == '0' || c == '-', s"""M"$str" is not correctly formated.""")

    val careAbout = strCleaned.map(c => if(c == '-') '0' else '1')
    val value = strCleaned.map(c => if(c == '-') '0' else c)
    new MaskedLiteral(BigInt(value, 2),BigInt(careAbout, 2), strCleaned.length())
  }
}
// ...
class MaskedLiteral(val value: BigInt, val careAbout: BigInt, val width: Int) {
  override def hashCode() = value.hashCode() + careAbout.hashCode() + width
  override def equals(o: scala.Any) = o match {
    case o : MaskedLiteral => this.value == o.value && this.careAbout == o.careAbout && this.width == o.width
    case _ => false
  }

  def withDontCare = careAbout != (BigInt(1) << width)-1

  def getWidth() = width
  def apply(index : Int): MaskedBoolean = {
    if(index >= width){
      SpinalError(s"Accessing MaskedLiteral at $index is outside its range ($width bits)")
    }
    new MaskedBoolean(value.testBit(index), careAbout.testBit(index))
  }
  def ===(that: BitVector): Bool = {
    if(that.getWidth != width){
      SpinalError(s"Masked literal width=$width doesn't match the one of $that")
    }
    (that.asBits & careAbout) === value
  }

  def =/=(that: BitVector): Bool = !(this === that)
// ...
```

### src/main/scala/vexriscv/VexRiscv.scala

```scala
case class VexRiscvConfig(){
// ...
  //Default Stageables
  object IS_RVC extends Stageable(Bool)
  object BYPASSABLE_EXECUTE_STAGE   extends Stageable(Bool)
  object BYPASSABLE_MEMORY_STAGE   extends Stageable(Bool)
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
  object RESULT extends Stageable(UInt(32 bits))
  object PC extends Stageable(UInt(32 bits))
  object PC_CALC_WITHOUT_JUMP extends Stageable(UInt(32 bits))
  object INSTRUCTION extends Stageable(Bits(32 bits))
  object INSTRUCTION_ANTICIPATED extends Stageable(Bits(32 bits))
  object LEGAL_INSTRUCTION extends Stageable(Bool)
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))

  object MPP extends PipelineThing[UInt]
  object DEBUG_BYPASS_CACHE extends PipelineThing[Bool]

  object SRC1   extends Stageable(Bits(32 bits))
  object SRC2   extends Stageable(Bits(32 bits))
  object SRC_ADD_SUB extends Stageable(Bits(32 bits))
  object SRC_ADD extends Stageable(Bits(32 bits))
  object SRC_SUB extends Stageable(Bits(32 bits))
  object SRC_LESS extends Stageable(Bool)
  object SRC_USE_SUB_LESS extends Stageable(Bool)
  object SRC_LESS_UNSIGNED extends Stageable(Bool)
  object SRC_ADD_ZERO extends Stageable(Bool)


  object HAS_SIDE_EFFECT extends Stageable(Bool)

  //Formal verification purposes
  object FORMAL_HALT       extends Stageable(Bool)
  object FORMAL_PC_NEXT    extends Stageable(UInt(32 bits))
  object FORMAL_MEM_ADDR   extends Stageable(UInt(32 bits))
  object FORMAL_MEM_RMASK  extends Stageable(Bits(4 bits))
  object FORMAL_MEM_WMASK  extends Stageable(Bits(4 bits))
  object FORMAL_MEM_RDATA  extends Stageable(Bits(32 bits))
  object FORMAL_MEM_WDATA  extends Stageable(Bits(32 bits))
  object FORMAL_INSTRUCTION extends Stageable(Bits(32 bits))
  object FORMAL_MODE       extends Stageable(Bits(2 bits))


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

### src/main/scala/vexriscv/plugin/DecoderSimplePlugin.scala

```scala
case class Masked(value : BigInt,care : BigInt){
  assert((value & ~care) == 0)
  var isPrime = true

  def < (that: Masked) = value < that.value || value == that.value && ~care < ~that.care

  def intersects(x: Masked) = ((value ^ x.value) & care & x.care) == 0

  def covers(x: Masked) = ((value ^ x.value) & care | (~x.care) & care) == 0

  def setPrime(value : Boolean) = {
    isPrime = value
    this
  }

  def mergeOneBitDifSmaller(x: Masked) = {
    val bit = value - x.value
    val ret = new Masked(value &~ bit, care & ~bit)
    //    ret.isPrime = isPrime || x.isPrime
    isPrime = false
    x.isPrime = false
    ret
  }
  def isSimilarOneBitDifSmaller(x: Masked) = {
    val diff = value - x.value
    care == x.care && value > x.value && (diff & diff - 1) == 0
  }


  def === (hard : Bits) : Bool = (hard & care) === (value & care)

  def toString(bitCount : Int) = (0 until bitCount).map(i => if(care.testBit(i)) (if(value.testBit(i)) "1" else "0") else "-").reverseIterator.reduce(_+_)
}
// ...
object Symplify{
  val cache = mutable.LinkedHashMap[Bits,mutable.LinkedHashMap[Masked,Bool]]()
  def getCache(addr : Bits) = cache.getOrElseUpdate(addr,mutable.LinkedHashMap[Masked,Bool]())

  //Generate terms logic for the given input
  def logicOf(input : Bits,terms : Seq[Masked]) = terms.map(t => getCache(input).getOrElseUpdate(t,t === input)).asBits.orR

  //Decode 'input' b using an mapping[key, decoding] specification
  def apply(input: Bits, mapping: Iterable[(Masked, Masked)],resultWidth : Int) : Bits = {
    val addrWidth = widthOf(input)
    (for(bitId <- 0 until resultWidth) yield{
      val trueTerm = mapping.filter { case (k,t) => (t.care.testBit(bitId) && t.value.testBit(bitId))}.map(_._1)
      val falseTerm = mapping.filter { case (k,t) => (t.care.testBit(bitId) &&  !t.value.testBit(bitId))}.map(_._1)
      val symplifiedTerms = SymplifyBit.getPrimeImplicantsByTrueAndFalse(trueTerm.toSeq, falseTerm.toSeq, addrWidth)
      logicOf(input, symplifiedTerms)
    }).asBits
  }
}

object SymplifyBit{
// ...
  def getPrimeImplicantsByTrue(trueTerms: Seq[Masked], inputWidth : Int) : Seq[Masked] = getPrimeImplicantsByTrueAndDontCare(trueTerms, Nil, inputWidth)

  // Return primes implicants for the trueTerms, default value is False.
  // You can insert don't care values by adding non-prime implicants in the trueTerms
  // Will simplify the trueTerms from the most constrained ones to the least constrained ones
  def getPrimeImplicantsByTrueAndDontCare(trueTerms: Seq[Masked],dontCareTerms: Seq[Masked], inputWidth : Int): Seq[Masked] = {
    val primes = mutable.LinkedHashSet[Masked]()
    trueTerms.foreach(_.isPrime = true)
    dontCareTerms.foreach(_.isPrime = false)
    val termsByCareCount = (inputWidth to 0 by -1).map(b => (trueTerms ++ dontCareTerms).filter(b == _.care.bitCount))
    //table[Vector[HashSet[Masked]]](careCount)(bitSetCount)
    val table = termsByCareCount.map(c => (0 to inputWidth).map(b => collection.mutable.Set(c.filter(m => b == m.value.bitCount): _*)))
    for (i <- 0 to inputWidth) {
      for (j <- 0 until inputWidth - i){
        for(term <- table(i)(j)){
          table(i+1)(j) ++= table(i)(j+1).withFilter(_.isSimilarOneBitDifSmaller(term)).map(_.mergeOneBitDifSmaller(term))
        }
      }
      for (r <- table(i))
        for (p <- r; if p.isPrime)
          primes += p
    }


    def optimise() {
      val duplicateds = primes.filter(prime => checkTrue(primes.filterNot(_ == prime), trueTerms))
      if(duplicateds.nonEmpty) {
        primes -= duplicateds.maxBy(_.care.bitCount)
        optimise()
      }
    }

    optimise()


    var duplication = 0
    for(prime <- primes){
      if(checkTrue(primes.filterNot(_ == prime), trueTerms)){
        duplication += 1
      }
    }
    if(duplication != 0){
      PendingError(s"Duplicated primes : $duplication")
    }
    primes.toSeq
  }
// ...
```

### src/main/scala/vexriscv/Pipeline.scala

```scala
trait Pipeline {
  type T <: Pipeline
  val plugins = ArrayBuffer[Plugin[T]]()
  var stages = ArrayBuffer[Stage]()
  var unremovableStages = mutable.Set[Stage]()
  val things = mutable.LinkedHashMap[PipelineThing[_], Any]()
//  val services = ArrayBuffer[Any]()

  def stageBefore(stage : Stage) = stages(indexOf(stage)-1)

  def indexOf(stage : Stage) = stages.indexOf(stage)

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
  def outsideCondScope[T](that : => T) : T = {
    val body = Component.current.dslBody  // Get the head of the current component symboles tree (AST in other words)
    val ctx = body.push()                           // Now all access to the SpinalHDL API will be append to it (instead of the current context)
    val swapContext = body.swap()         // Empty the symbole tree (but keep a reference to the old content)
    val ret = that                        // Execute the block of code (will be added to the recently empty body)
    ctx.restore()                            // Restore the original context in which this function was called
    swapContext.appendBack()              // append the original symboles tree to the modified body
    ret                                   // return the value returned by that
  }

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


  val inputs   = mutable.LinkedHashMap[Stageable[Data],Data]()
  val outputs  = mutable.LinkedHashMap[Stageable[Data],Data]()
  val signals  = mutable.LinkedHashMap[Stageable[Data],Data]()
  val inserts  = mutable.LinkedHashMap[Stageable[Data],Data]()

  val inputsDefault   = mutable.LinkedHashMap[Stageable[Data],Data]()
  val outputsDefault  = mutable.LinkedHashMap[Stageable[Data],Data]()
// ...
}
```

## Related source code

### src/main/scala/vexriscv/plugin/DecoderSimplePlugin.scala

```scala
object DecodingBench extends App{
  SpinalVerilog{
    val top = GenFull.cpu()
    top.service(classOf[DecoderSimplePlugin]).bench(top)
    top
  }
}
```

## Documentation

### README.md

````text
#### DecoderSimplePlugin

This plugin provides instruction decoding capabilities to other plugins.

For instance, for a given instruction, the pipeline hazard plugin needs to know if it uses the register file source 1/2 in order to stall the pipeline until the hazard is gone.
Each plugin that implements an instruction provides this kind of information to the DecoderSimplePlugin plugin.

| Parameters | type | description |
| ------ | ----------- | ------ |
| catchIllegalInstruction | Boolean | When true, instructions that don't match a decoding specification will generate a trap exception  |

Here is a usage example:

```scala
    //Specify the instruction decoding which should be applied when the instruction matches the 'key' pattern
    decoderService.add(
      //Bit pattern of the new instruction
      key = M"0000011----------000-----0110011",

      //Decoding specification when the 'key' pattern is recognized in the instruction
      List(
        IS_SIMD_ADD              -> True, //Inform the pipeline that the current instruction is a SIMD_ADD instruction
        REGFILE_WRITE_VALID      -> True, //Notify the hazard management unit that this instruction writes to the register file
        BYPASSABLE_EXECUTE_STAGE -> True, //Notify the hazard management unit that the instruction result is already accessible in the EXECUTE stage (Bypass ready)
        BYPASSABLE_MEMORY_STAGE  -> True, //Same as above but for the memory stage
        RS1_USE                  -> True, //Notify the hazard management unit that this instruction uses the RS1 value
        RS2_USE                  -> True  //Same than above but for RS2.
      )
    )
  }
```

This plugin operates in the Decode stage.
````
