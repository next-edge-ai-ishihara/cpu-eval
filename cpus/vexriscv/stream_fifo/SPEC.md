# Implement `StreamFifo`

Implement the complete `StreamFifo` class. Keep the stream methods, the FIFO interface and the factory fixed.

Return only the complete `class StreamFifo` definition in a single Scala code block, with no text outside the block.

## Class declaration

### lib/src/main/scala/spinal/lib/Stream.scala

```scala
/** First-In-First-Out queue with a `push` and `pop` [[Stream]]
  *   
  * - latency of 0, 1, 2 cycles
  * ...
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
// ...
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

object StreamFifo{
  def apply[T <: Data](dataType: HardType[T],
                       depth: Int,
                       latency: Int = 2,
                       forFMax: Boolean = false,
                       initPayload: => Option[T] = None): StreamFifo[T] = {
    assert(latency >= 0 && latency <= 2)
    new StreamFifo(
      dataType,
      depth,
      withAsyncRead = latency < 2,
      withBypass = latency == 0,
      forFMax = forFMax,
      initPayload = initPayload
    )
  }
}
```

## Related source code

### lib/src/main/scala/spinal/lib/Stream.scala

```scala
/** Connect this to a fifo and return its pop stream
  */
  def queue(size: Int, latency : Int = 2, forFMax : Boolean = false): Stream[T] = new Composite(this){
    val fifo = StreamFifo(payloadType, size, latency = latency, forFMax = forFMax).setCompositeName(this,"queue", true)
    fifo.io.push << self
  }.fifo.io.pop

  /** Connect this to a register constructed fifo and return its pop stream
   */
  def queueOfReg(size: Int, latency : Int = 1, forFMax : Boolean = false, initPayload : => Option[T] = None): Stream[T] = new Composite(this){
    val fifo = new StreamFifo(payloadType, size, withBypass = latency == 0, withAsyncRead = true, useVec = true, forFMax = forFMax, initPayload = initPayload).setCompositeName(this,"queue", true)
    fifo.io.push << self
  }.fifo.io.pop

/** Connect this to an clock crossing fifo and return its pop stream
  */
  def queue(size: Int, pushClock: ClockDomain, popClock: ClockDomain): Stream[T] = {
    val fifo = new StreamFifoCC(payloadType, size, pushClock, popClock).setCompositeName(this,"queue", true)
    fifo.io.push << this
    fifo.io.pop
  }

/** Connect this to a fifo and return its pop stream and its occupancy
  */
  def queueWithOccupancy(size: Int, latency : Int = 2, forFMax : Boolean = false): (Stream[T], UInt) = {
    val fifo = StreamFifo(payloadType, size, latency = latency, forFMax = forFMax).setCompositeName(this,"queueWithOccupancy", true)
    fifo.io.push << this
    (fifo.io.pop, fifo.io.occupancy)
  }

  def queueWithAvailability(size: Int, latency : Int = 2, forFMax : Boolean = false): (Stream[T], UInt) = {
    val fifo = StreamFifo(payloadType, size, latency = latency, forFMax = forFMax).setCompositeName(this,"queueWithAvailability", true)
    fifo.io.push << this
    (fifo.io.pop, fifo.io.availability)
  }
```

### tester/src/test/scala/spinal/lib/SpinalSimStreamFifoTester.scala

```scala
  def testStreamFifo(depth: Int,
                     withAsyncRead: Boolean,
                     withBypass: Boolean,
                     forFMax : Boolean,
                     useVec : Boolean): Unit = test(s"StreamFifo_$depth-$withAsyncRead-$withBypass-$forFMax-$useVec") {

    //Compile the simulator
    val compiled = SimConfig.compile(
      rtl = new StreamFifo(
        dataType = Bits(32 bits),
        depth = depth,
        withAsyncRead = withAsyncRead,
        withBypass = withBypass,
        forFMax = forFMax,
        useVec = useVec
      )
    )

    //Run the simulation
    compiled.doSimUntilVoid { dut =>
      val queueModel = mutable.Queue[Long]()

      SimTimeout(1000000 * 8)
      dut.clockDomain.forkStimulus(2)

      dut.io.flush #= false

      var pushRatio, popRatio = 0.5
      var sampledFLush = false
      dut.clockDomain.onSamplings {
        if(sampledFLush){
          queueModel.clear()
        }
        if(Random.nextFloat() < 0.01){
          pushRatio = 0.5 + 0.5*Random.nextFloat()
          popRatio = 0.5 + 0.5*Random.nextFloat()
        }
        sampledFLush = dut.io.flush.toBoolean
        assert(dut.io.occupancy.toInt == queueModel.size)
        assert(dut.io.availability.toInt == depth - queueModel.size)
        dut.io.flush #= Random.nextFloat() < 0.005
      }


      //Push data randomly and fill the queueModel with pushed transactions
      dut.io.push.valid #= false
      dut.clockDomain.onSamplings {
        if (dut.io.push.valid.toBoolean && dut.io.push.ready.toBoolean) {
          queueModel.enqueue(dut.io.push.payload.toLong)
        }
        dut.io.push.valid #= Random.nextFloat() < pushRatio
        dut.io.push.payload.randomize()
      }

      //Pop data randomly and check that it match with the queueModel
      var popCount = 0
      dut.io.pop.ready #= true
      dut.clockDomain.onSamplings {
        dut.io.pop.ready #= Random.nextFloat() < popRatio
        if (dut.io.pop.valid.toBoolean && dut.io.pop.ready.toBoolean) {
          assert(dut.io.pop.payload.toLong == queueModel.dequeue())
          popCount += 1
        }
        if(popCount == 5000) simSuccess()
      }
    }
  }

  onlyVerilator()
//  testStreamFifo(depth = 8,
//    withAsyncRead = false,
//    withBypass = false,
//    occupancyFromRamOnly = false,
//    forFMax = false
//  )
  for (depth <- List(0, 1, 2, 3, 4, 15, 16, 17, 24);
       withAsyncRead <- List(false, true);
       withBypass <- List(false, true);
       forFMax <- List(false, true);
       useVec <- List(false, true);
       if !(!withAsyncRead && withBypass) && !(useVec && !withAsyncRead)) {
    testStreamFifo(depth = depth,
      withAsyncRead = withAsyncRead,
      withBypass = withBypass,
      forFMax = forFMax,
      useVec = useVec
    )
  }
  withAll()
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
