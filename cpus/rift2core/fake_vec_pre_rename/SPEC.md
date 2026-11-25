# Implement `FakeVecPreRename`

Implement the complete `FakeVecPreRename` class. Preserve the class name and interface shown below.

Return only the complete `class FakeVecPreRename` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class FakeVecPreRename()(implicit p: Parameters) extends RiftModule{
  val io: VecPreRenameIO = IO(new VecPreRenameIO)
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val preRename_stage = if(hasVector) { Module(new VecPreRename) } else { Module(new FakeVecPreRename) }
// ...
  if4.io.if4_resp <> preRename_stage.io.enq
  preRename_stage.io.deq <> rnm_stage.io.rnReq

  preRename_stage.io.vpuCsrMolloc <> iwb_stage.io.vpuCsrMolloc
```

## Dependency declarations

### src/main/scala/rift2Core/vector/VecPreRename.scala

```scala
class VecPreRenameIO()(implicit p: Parameters) extends RiftBundle{
  val enq = Vec(rnChn, Flipped(new DecoupledIO(new IF4_Bundle)))
  val deq = Vec(rnChn, new DecoupledIO(new IF4_Bundle))

  val vpuCsrMolloc    = Vec(rnChn, Decoupled(Bool()))
  val csrfiles   = Input(new CSR_Bundle)

  val isVStartRsv = Input(Bool())
  val isVSetRsv   = Input(Bool())
  val isFoFRsv    = Input(UInt((log2Ceil(cmChn)+1).W))

  val flush = Input(Bool())
}
```
