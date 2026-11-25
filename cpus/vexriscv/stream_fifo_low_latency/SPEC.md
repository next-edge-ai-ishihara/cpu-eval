# Implement `StreamFifoLowLatency`

Implement the complete `StreamFifoLowLatency` class. The companion object remains fixed.

Return only the complete `class StreamFifoLowLatency` definition in a single Scala code block, with no text outside the block.

## Class declaration

### lib/src/main/scala/spinal/lib/Stream.scala

```scala
class StreamFifoLowLatency[T <: Data](val dataType: HardType[T],val depth: Int,val latency : Int = 0, useVec : Boolean = false, initPayload : => Option[T] = None) extends Component {
  assert(latency == 0 || latency == 1)

  val io = new Bundle with StreamFifoInterface[T]{
    val push = slave Stream (dataType)
    val pop = master Stream (dataType)
    val flush = in Bool() default(False)
    val occupancy    = out UInt (log2Up(depth + 1) bits)
    val availability = out UInt (log2Up(depth + 1) bits)
    override def pushOccupancy = occupancy
    override def popOccupancy = occupancy
  }
// ...
```

## Dependency declarations

### lib/src/main/scala/spinal/lib/Stream.scala

```scala
trait StreamFifoInterface[T <: Data]{
  def push          : Stream[T]
  def pop           : Stream[T]
  def pushOccupancy : UInt
  def popOccupancy  : UInt
}
// ...
/** First-In-First-Out queue with a `push` and `pop` [[Stream]]
  *   
  * - latency of 0, 1, 2 cycles
  *
  * Fully redesigned in release 1.8.2 allowing improved timing closure.
  * @param dataType
  * @param depth Number of element stored in the fifo, Note that if `withAsyncRead==false`,
  *              then one extra transaction can be stored.
  * @param withAsyncRead Read the memory using asynchronous read port (ex distributed ram).
  *                      If false, add 1 cycle latency.
  * @param withBypass Bypass the push port to the pop port when the fifo is empty.If false, add 
  *                   1 cycle latency. Only available if `withAsyncRead == true`.
  * @param forFMax Tune the design to get the maximal clock frequency.
  * @param useVec Use an Vec of register instead of a Mem to store the content
  *               Only available if `withAsyncRead == true`.
  * @param initPayload Initialize the `Vec` of register with the initial value.
  * 
  * @see [[StreamFifoCC]] and [[StreamCCByToggle]] for cross clock domain FIFOs
  */
class StreamFifo[T <: Data](val dataType: HardType[T],
                            val depth: Int,
                            val withAsyncRead : Boolean = false,
                            val withBypass : Boolean = false,
                            val allowExtraMsb : Boolean = true,
                            val forFMax : Boolean = false,
                            val useVec : Boolean = false,
                            initPayload : => Option[T] = None) extends Component {
  require(depth >= 0)

  if(withBypass) require(withAsyncRead)
  if(useVec) require (withAsyncRead)

  val io = new Bundle with StreamFifoInterface[T]{
    val push = slave Stream (dataType)
    val pop = master Stream (dataType)
    val flush = in Bool() default(False)
    val occupancy    = out UInt (log2Up(depth + 1) bits)
    val availability = out UInt (log2Up(depth + 1) bits)
    override def pushOccupancy = occupancy
    override def popOccupancy = occupancy
  }
// ...
object StreamFifoLowLatency{
  def apply[T <: Data](dataType: T, depth: Int) = new StreamFifoLowLatency(dataType,depth)
}
```

## Related source code

### lib/src/main/scala/spinal/lib/Stream.scala

```scala
  /** Connect this to a zero latency fifo and return its pop stream
    */
  def queueLowLatency(size: Int, latency : Int = 0): Stream[T] = {
    val fifo = new StreamFifoLowLatency(payloadType, size, latency).setCompositeName(this,"queueLowLatency", true)
    fifo.setPartialName(this, "fifo", true)
    fifo.io.push << this
    fifo.io.pop
  }
```

### tester/src/test/scala/spinal/lib/SpinalSimStreamFifoTester.scala

```scala
  test("lowLatency_0") {
    //Bundle used as fifo payload
    case class Transaction() extends Bundle {
      val flag = Bool()
      val data = Bits(8 bits)
      val color = Rgb(5, 6, 5)
    }

    val compiled = SimConfig.allOptimisation.compile(
      rtl = new StreamFifoLowLatency(
        dataType = Transaction(),
        depth = 2,
        latency = 0
      )
    )

    //Run the simulation
    compiled.doSim { dut =>
      //Inits
      SimTimeout(1000000 * 8)
      dut.clockDomain.forkStimulus(2)
      dut.clockDomain.forkSimSpeedPrinter()
      dut.io.flush #= false

      val scoreboard = ScoreboardInOrder[SimData]()

      //Drivers
      StreamDriver(dut.io.push, dut.clockDomain) { payload => payload.randomize(); true }
      StreamReadyRandomizer(dut.io.pop, dut.clockDomain)

      //Monitors
      StreamMonitor(dut.io.push, dut.clockDomain) { payload => scoreboard.pushRef(payload) }
      StreamMonitor(dut.io.pop, dut.clockDomain) { payload => scoreboard.pushDut(payload) }

      waitUntil(scoreboard.matches == 10000)
    }
  }


  test("lowLatency_1") {
    //Bundle used as fifo payload
    case class Transaction() extends Bundle {
      val flag = Bool()
      val data = Bits(8 bits)
      val color = Rgb(5, 6, 5)
    }

    val compiled = SimConfig.allOptimisation.compile(
      rtl = new StreamFifoLowLatency(
        dataType = Transaction(),
        depth = 4,
        latency = 1
      )
    )

    //Run the simulation
    compiled.doSim { dut =>
      //Inits
      SimTimeout(1000000 * 8)
      dut.clockDomain.forkStimulus(2)
      dut.clockDomain.forkSimSpeedPrinter()
      dut.io.flush #= false

      val scoreboard = ScoreboardInOrder[SimData]()

      //Drivers
      StreamDriver(dut.io.push, dut.clockDomain) { payload => payload.randomize(); true }
      StreamReadyRandomizer(dut.io.pop, dut.clockDomain)

      //Monitors
      StreamMonitor(dut.io.push, dut.clockDomain) { payload => scoreboard.pushRef(payload) }
      StreamMonitor(dut.io.pop, dut.clockDomain) { payload => scoreboard.pushDut(payload) }

      waitUntil(scoreboard.matches == 10000)
    }
  }
```

## Documentation

### lib/src/main/scala/spinal/lib/Stream.scala

```text
/** A simple interface with master payload `valid`, slave `ready` handshake.
  * 
  * When manually reading/driving the signals of a [[Stream]] keep in mind that:
  *
  *  - After being asserted, `valid` may only be deasserted once the current payload was
  *    acknowledged. This means `valid` can only toggle to 0 the cycle after a the slave did
  *    a read by asserting ready.
  *  - In contrast to that `ready` may change at any time.
  *  - A transfer is only done on cycles where both `valid` and `ready` are asserted.
  *  - `valid` of a [[Stream]] must not depend on `ready` in a combinatorial way and any path
  *    between the two must be registered.
  *
  * It is recommended that `valid` does not depend on `ready` at all.
...
```

## Additional requirement

At depth 0, `push.ready` equals `pop.ready`, `pop.valid` equals `push.valid` and `pop.payload` equals `push.payload` in every cycle.
