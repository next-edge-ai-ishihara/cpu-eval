# Implement `FakeVecPreIssue`

Implement the complete `FakeVecPreIssue` class. Preserve the class name and interface shown below.

Return only the complete `class FakeVecPreIssue` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class FakeVecPreIssue()(implicit p: Parameters) extends RiftModule{
  val io: VecPreIssueIO = IO(new VecPreIssueIO)
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val preIssue_stage = if(hasVector) { Module(new VecPreIssue) } else { Module(new FakeVecPreIssue) }
// ...
  rnm_stage.io.rnRsp <> preIssue_stage.io.enq
  
  preIssue_stage.io.deq <> iss_stage.io.dptReq

  preIssue_stage.io.molloc <> iwb_stage.io.vMolloc
  preIssue_stage.io.readOp <> iwb_stage.io.vReadOp
```

## Dependency declarations

### src/main/scala/rift2Core/vector/VecPreIssue.scala

```scala
class VecPreIssueIO()(implicit p: Parameters) extends RiftBundle{
  val enq = Vec(rnChn, Flipped(new DecoupledIO(new Dpt_info)))
  val deq = Vec(rnChn, new DecoupledIO(new Dpt_info))

  val molloc = Decoupled(new Vector_Molloc_Bundle) //molloc at read op
  val readOp = Flipped(Vec( 32, Valid(UInt( (vParams.vlen).W )) ) )

  val csrfiles = Input(new CSR_Bundle)
  val isPndVStore = Input(Bool())

  val flush = Input(Bool())
}
```
