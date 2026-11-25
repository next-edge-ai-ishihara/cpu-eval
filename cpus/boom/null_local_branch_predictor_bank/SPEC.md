# Implement `NullLocalBranchPredictorBank`

Implement the complete `NullLocalBranchPredictorBank` module. Preserve its declaration. Return only the complete `class NullLocalBranchPredictorBank` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/ifu/bpd/local.scala`

```scala
package boom.ifu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.{Field, Parameters}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._

import boom.common._
import boom.util.{BoomCoreStringPrefix}
```

## Class declaration

```scala
class NullLocalBranchPredictorBank(implicit p: Parameters) extends AbstractLocalBranchPredictorBank
{
```

## Parent instantiation

### `src/main/scala/ifu/bpd/predictor.scala`

```scala
  val banked_lhist_providers = Seq.fill(nBanks) { Module(if (localHistoryNSets > 0) new LocalBranchPredictorBank else new NullLocalBranchPredictorBank) }
// ...
    banked_predictors(0).io.f1_lhist := banked_lhist_providers(0).io.f1_lhist
    banked_predictors(1).io.f1_lhist := banked_lhist_providers(1).io.f1_lhist
// ...
    io.resp.f3.lhist(0)   := banked_lhist_providers(0).io.f3_lhist
    io.resp.f3.lhist(1)   := banked_lhist_providers(1).io.f3_lhist
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/ifu/bpd/local.scala`

```scala
abstract class AbstractLocalBranchPredictorBank(implicit p: Parameters) extends BoomModule()(p)
  with HasBoomFrontendParameters
{
  val io = IO(new Bundle {
    val f0_valid = Input(Bool())
    val f0_pc    = Input(UInt(vaddrBitsExtended.W))

    val f1_lhist  = Output(UInt(localHistoryLength.W))

    val f3_lhist = Output(UInt(localHistoryLength.W))

    val f3_taken_br = Input(Bool())
    val f3_fire = Input(Bool())

    val update = Input(new Bundle {
      val valid      = Input(Bool())
      val mispredict = Input(Bool())
      val repair     = Input(Bool())
      val pc         = Input(UInt(vaddrBitsExtended.W))
      val lhist      = Input(UInt(localHistoryLength.W))
    })
  })
}
```

## Additional requirement

`io.f1_lhist` and `io.f3_lhist` must be zero in every cycle, independently of all inputs.
