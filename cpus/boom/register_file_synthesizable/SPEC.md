# Implement `RegisterFileSynthesizable`

Implement the complete `RegisterFileSynthesizable` module. Preserve its class declaration and public interface shown below. Return only the complete `class RegisterFileSynthesizable` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2013 - 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Register File (Abstract class and Synthesizable RegFile)
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

package boom.exu

import scala.collection.mutable.ArrayBuffer

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters

import boom.common._
import boom.util.{BoomCoreStringPrefix}
```

## Class declaration

```scala
/**
 * A synthesizable model of a Register File. You will likely want to blackbox this for more than modest port counts.
 *
 * @param numRegisters number of registers
 * @param numReadPorts number of read ports
 * @param numWritePorts number of write ports
 * @param registerWidth size of registers in bits
 * @param bypassableArray list of write ports from func units to the read port of the regfile
 */
class RegisterFileSynthesizable(
   numRegisters: Int,
   numReadPorts: Int,
   numWritePorts: Int,
   registerWidth: Int,
   bypassableArray: Seq[Boolean])
   (implicit p: Parameters)
   extends RegisterFile(numRegisters, numReadPorts, numWritePorts, registerWidth, bypassableArray)
{
```

## Parent instantiation

### `src/main/scala/exu/core.scala`

```scala
  val iregfile         = Module(new RegisterFileSynthesizable(
                             numIntPhysRegs,
                             numIrfReadPorts,
                             numIrfWritePorts,
                             xLen,
                             Seq.fill(memWidth) {true} ++ exe_units.bypassable_write_port_mask)) // bypassable ll_wb
  val pregfile         = Module(new RegisterFileSynthesizable(
                            ftqSz,
                            exe_units.numIrfReaders,
                            1,
                            1,
                            Seq(true))) // The jmp unit is always bypassable
  pregfile.io := DontCare // Only use the IO if enableSFBOpt
// ...
  // Register Read <- Issue (rrd <- iss)
  iregister_read.io.rf_read_ports <> iregfile.io.read_ports
  iregister_read.io.prf_read_ports := DontCare
  if (enableSFBOpt) {
    iregister_read.io.prf_read_ports <> pregfile.io.read_ports
  }
```

### `src/main/scala/exu/fp-pipeline.scala`

```scala
  val fregfile       = Module(new RegisterFileSynthesizable(numFpPhysRegs,
                         exe_units.numFrfReadPorts,
                         exe_units.numFrfWritePorts + memWidth,
                         fLen+1,
                         // No bypassing for any FP units, + memWidth for ll_wb
                         Seq.fill(exe_units.numFrfWritePorts + memWidth){ false }
                         ))
// ...
  // Register Read <- Issue (rrd <- iss)
  fregister_read.io.rf_read_ports <> fregfile.io.read_ports
  fregister_read.io.prf_read_ports map { port => port.data := false.B }
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/exu/register-read/regfile.scala`

```scala
/**
 * IO bundle for a register read port
 *
 * @param addrWidth size of register address in bits
 * @param dataWidth size of register in bits
 */
class RegisterFileReadPortIO(val addrWidth: Int, val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
{
  val addr = Input(UInt(addrWidth.W))
  val data = Output(UInt(dataWidth.W))
}

/**
 * IO bundle for the register write port
 *
 * @param addrWidth size of register address in bits
 * @param dataWidth size of register in bits
 */
class RegisterFileWritePort(val addrWidth: Int, val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
{
  val addr = UInt(addrWidth.W)
  val data = UInt(dataWidth.W)
}

/**
 * Utility function to turn ExeUnitResps to match the regfile's WritePort I/Os.
 */
object WritePort
{
  def apply(enq: DecoupledIO[ExeUnitResp], addrWidth: Int, dataWidth: Int, rtype: UInt)
    (implicit p: Parameters): Valid[RegisterFileWritePort] = {
     val wport = Wire(Valid(new RegisterFileWritePort(addrWidth, dataWidth)))

     wport.valid     := enq.valid && enq.bits.uop.dst_rtype === rtype
     wport.bits.addr := enq.bits.uop.pdst
     wport.bits.data := enq.bits.data
     enq.ready       := true.B
     wport
  }
}

/**
 * Register file abstract class
 *
 * @param numRegisters number of registers
 * @param numReadPorts number of read ports
 * @param numWritePorts number of write ports
 * @param registerWidth size of registers in bits
 * @param bypassableArray list of write ports from func units to the read port of the regfile
 */
abstract class RegisterFile(
  numRegisters: Int,
  numReadPorts: Int,
  numWritePorts: Int,
  registerWidth: Int,
  bypassableArray: Seq[Boolean]) // which write ports can be bypassed to the read ports?
  (implicit p: Parameters) extends BoomModule
{
  val io = IO(new BoomBundle {
    val read_ports = Vec(numReadPorts, new RegisterFileReadPortIO(maxPregSz, registerWidth))
    val write_ports = Flipped(Vec(numWritePorts, Valid(new RegisterFileWritePort(maxPregSz, registerWidth))))
  })

  private val rf_cost = (numReadPorts + numWritePorts) * (numReadPorts + 2*numWritePorts)
  private val type_str = if (registerWidth == fLen+1) "Floating Point" else "Integer"
  override def toString: String = BoomCoreStringPrefix(
    "==" + type_str + " Regfile==",
    "Num RF Read Ports     : " + numReadPorts,
    "Num RF Write Ports    : " + numWritePorts,
    "RF Cost (R+W)*(R+2W)  : " + rf_cost,
    "Bypassable Units      : " + bypassableArray)
}
```

### `src/main/scala/chisel3/util/Valid.scala`

```scala
/** A [[Bundle]] that adds a `valid` bit to some data. This indicates that the user expects a "valid" interface between
  * a producer and a consumer. Here, the producer asserts the `valid` bit when data on the `bits` line contains valid
  * data. This differs from [[DecoupledIO]] or [[IrrevocableIO]] as there is no `ready` line that the consumer can use
  * to put back pressure on the producer.
  *
  * In most scenarios, the `Valid` class will ''not'' be used directly. Instead, users will create `Valid` interfaces
  * using the [[Valid$ Valid factory]].
  * @tparam T the type of the data
  * @param gen some data
  * @see [[Valid$ Valid factory]] for concrete examples
  * @groupdesc Signals The actual hardware fields of the Bundle
  */
class Valid[+T <: Data](gen: T) extends Bundle {

  /** A bit that will be asserted when `bits` is valid
    * @group Signals
    */
  val valid = Output(Bool())

  /** The data to be transferred, qualified by `valid`
    * @group Signals
    */
  val bits = Output(gen)

  /** True when `valid` is asserted
    * @return a Chisel [[Bool]] true if `valid` is asserted
    */
  def fire: Bool = valid
```

### `core/src/main/scala/chisel3/Mem.scala`

```scala
/** A combinational/asynchronous-read, sequential/synchronous-write memory.
  *
  * Writes take effect on the rising clock edge after the request. Reads are
  * combinational (requests will return data on the same cycle).
  * Read-after-write hazards are not an issue.
  *
  * @note when multiple conflicting writes are performed on a Mem element, the
  * result is undefined (unlike Vec, where the last assignment wins)
  */
sealed class Mem[T <: Data] private (t: T, length: BigInt) extends MemBase(t, length)
```

## Related source code

### `src/main/scala/exu/register-read/register-read.scala`

```scala
  var idx = 0 // index into flattened read_ports array
  for (w <- 0 until issueWidth) {
    val numReadPorts = numReadPortsArray(w)

    // NOTE:
    // rrdLatency==1, we need to send read address at end of ISS stage,
    //    in order to get read data back at end of RRD stage.

    val rs1_addr = io.iss_uops(w).prs1
    val rs2_addr = io.iss_uops(w).prs2
    val rs3_addr = io.iss_uops(w).prs3
    val pred_addr = io.iss_uops(w).ppred

    if (numReadPorts > 0) io.rf_read_ports(idx+0).addr := rs1_addr
    if (numReadPorts > 1) io.rf_read_ports(idx+1).addr := rs2_addr
    if (numReadPorts > 2) io.rf_read_ports(idx+2).addr := rs3_addr

    if (enableSFBOpt) io.prf_read_ports(w).addr := pred_addr

    if (numReadPorts > 0) rrd_rs1_data(w) := Mux(RegNext(rs1_addr === 0.U), 0.U, io.rf_read_ports(idx+0).data)
    if (numReadPorts > 1) rrd_rs2_data(w) := Mux(RegNext(rs2_addr === 0.U), 0.U, io.rf_read_ports(idx+1).data)
    if (numReadPorts > 2) rrd_rs3_data(w) := Mux(RegNext(rs3_addr === 0.U), 0.U, io.rf_read_ports(idx+2).data)

    if (enableSFBOpt) rrd_pred_data(w) := Mux(RegNext(io.iss_uops(w).is_sfb_shadow), io.prf_read_ports(w).data, false.B)
```

## Documentation

### `docs/sections/reg-file-bypass-network.rst`

```text
BOOM is a unified, **Physical Register File (PRF)** design. The register
files hold both the committed and speculative state. Additionally,
there are two register files: one for integer and one for floating point
register values. The **Rename Map Tables** track which physical register corresponds
to which ISA register.

BOOM uses the Berkeley hardfloat floating point units which use an
internal 65-bit operand format
(https://github.com/ucb-bar/berkeley-hardfloat). Therefore, all physical
floating point registers are 65-bits.

Register Read
-------------

The register file statically provisions all of the register read ports
required to satisfy all issued instructions. For example, if *issue port
#0* corresponds to an integer ALU and *issue port #1* corresponds to memory
unit, then the first two register read ports will statically serve the
ALU and the next two register read ports will service the memory unit for four
total read ports.
```
