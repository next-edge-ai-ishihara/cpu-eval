# Implement `ibex_register_file_ff`

Implement the complete `ibex_register_file_ff` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_register_file_ff` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### ibex_configs.yaml

```yaml
small:
  BaseIsa                  : "ibex_pkg::BaseIsaRV32I"
  RV32E                    : 0
  RV32M                    : "ibex_pkg::RV32MFast"
  RV32B                    : "ibex_pkg::RV32BNone"
  RV32ZC                   : "ibex_pkg::RV32Zca"
  RegFile                  : "ibex_pkg::RegFileFF"
  BranchTargetALU          : 0
  WritebackStage           : 0
  ICache                   : 0
  ICacheECC                : 0
  ICacheScramble           : 0
  BranchPredictor          : 0
  DbgTriggerEn             : 0
  SecureIbex               : 0
  PMPEnable                : 0
  PMPGranularity           : 0
  PMPNumRegions            : 4
  MHPMCounterNum           : 0
  MHPMCounterWidth         : 40
```

## Package and imports

### rtl/ibex_pkg.sv

```systemverilog
  typedef enum integer {
    BaseIsaRV32I          = 0, // only RV32I
    BaseIsaRV32IorCHERIoT = 1  // dual base ISA: RV32I/CHERIoT runtime switchable
  } base_isa_e;

  typedef enum integer {
    RegFileFF    = 0,
    RegFileFPGA  = 1,
    RegFileLatch = 2
  } regfile_e;
// ...
  // Multi-bit signal used for security hardening. For non-secure implementation all bits other than
  // the bottom bit are ignored.
  parameter int IbexMuBiWidth = 4;
  typedef logic [IbexMuBiWidth-1:0] ibex_mubi_t;

  // Note that if adjusting these parameters it is assumed the bottom bit is set for On and unset
  // for Off. This allows the use of IbexMuBiOn/IbexMuBiOff to work for both secure and non-secure
  // Ibex. If this assumption is broken the RTL that uses ibex_mubi_t types such as the fetch_enable
  // and core_busy signals within `ibex_core` may need adjusting.
  parameter ibex_mubi_t IbexMuBiOn  = 4'b0101;
  parameter ibex_mubi_t IbexMuBiOff = 4'b1010;
```

## Module declaration

```verilog
module ibex_register_file_ff import ibex_pkg::*; #(
  parameter base_isa_e            BaseIsa           = BaseIsaRV32I,
  parameter bit                   RV32E             = 0,
  parameter int unsigned          DataWidth         = 32,
  parameter bit                   DummyInstructions = 0,
  parameter logic [DataWidth-1:0] WordZeroVal       = '0,
  // Capability port width
  parameter int unsigned          CapWidth          = ibex_cheriot_pkg::REGCAP_W,
  parameter logic [CapWidth-1:0]  CapWordZeroVal    = '0
) (
  // Clock and Reset
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  logic                 test_en_i,
  input  logic                 dummy_instr_id_i,
  input  logic                 dummy_instr_wb_i,

  input  ibex_mubi_t           cheriot_enable_i,

  // Read port R1
  input  logic [4:0]           raddr_a_i,
  output logic [DataWidth-1:0] rdata_a_o,
  output logic [CapWidth-1:0]  rcap_a_o,

  // Read port R2
  input  logic [4:0]           raddr_b_i,
  output logic [DataWidth-1:0] rdata_b_o,
  output logic [CapWidth-1:0]  rcap_b_o,

  // Write port W1
  input  logic [4:0]           waddr_a_i,
  input  logic [DataWidth-1:0] wdata_a_i,
  input  logic [CapWidth-1:0]  wcap_a_i,
  input  logic                 we_a_i
);
```

## Parent instantiation

### rtl/ibex_top.sv

```systemverilog
  localparam bit          DummyInstructions     = SecureIbex;
  localparam bit          RegFileECC            = 1'b0;
  localparam bit          RegFileLockstepECC    = Lockstep;
  localparam int unsigned RegFileDataWidth      = 32;
// ...
  if (RegFile == RegFileFF) begin : gen_regfile_ff

    ibex_register_file_ff #(
      .BaseIsa          (BaseIsa),
      .RV32E            (RV32E),
      .DataWidth        (RegFileDataWidth),
      .DummyInstructions(DummyInstructions),
      .WordZeroVal      (RegFileDataWidth'(prim_secded_pkg::SecdedInv3932ZeroWord))
    ) register_file_i (
      .clk_i (clk),
      .rst_ni(rst_ni),

      .test_en_i        (test_en_i),
      .dummy_instr_id_i (dummy_instr_id),
      .dummy_instr_wb_i (dummy_instr_wb),
      .cheriot_enable_i (cheriot_enable_i),

      .raddr_a_i(rf_raddr_a),
      .rdata_a_o(rf_rdata_a),
      .rcap_a_o (rf_rcap_a),
      .raddr_b_i(rf_raddr_b),
      .rdata_b_o(rf_rdata_b),
      .rcap_b_o (rf_rcap_b),
      .waddr_a_i(rf_waddr_wb),
      .wdata_a_i(rf_wdata_wb),
      .wcap_a_i (rf_wcap),
      .we_a_i   (rf_we_wb)
    );
```

## Documentation

### doc/02_user/integration.rst

```text
Register File
-------------

Ibex comes with three different register file implementations that can be selected using the enumerated parameter ``RegFile`` defined in :file:`rtl/ibex_pkg.sv`.
Depending on the target technology, either the flip-flop-based ("ibex_pkg::RegFileFF", default), the latch-based ("ibex_pkg::RegFileLatch") or an FPGA-targeted ("ibex_pkg::RegFileFPGA") implementation should be selected.
For more information about the three register file implementations and their trade-offs, check out :ref:`register-file`.
```

### doc/03_reference/register_file.rst

```text
Register File
=============
Source Files: :file:`rtl/ibex_register_file_ff.sv` :file:`rtl/ibex_register_file_fpga.sv` :file:`rtl/ibex_register_file_latch.sv`

Ibex has either 31 or 15 32-bit registers if the RV32E extension is disabled or enabled, respectively.
Register ``x0`` is statically bound to 0 and can only be read, it does not contain any sequential logic.

The register file has two read ports and one write port, register file data is available the same cycle a read is requested.
There is no write to read forwarding path so if one register is being both read and written the read will return the current value rather than the value being written.

There are three flavors of register file available, each having their own benefits and trade-offs.
The register file flavor is selected via the enumerated parameter ``RegFile`` defined in :file:`rtl/ibex_pkg.sv`.

Flip-Flop-Based Register File
-----------------------------

The flip-flop-based register file uses regular, positive-edge-triggered flip-flops to implement the registers.

This makes it the **first choice when simulating the design using Verilator**.

This implementation can be selected by setting the ``RegFile`` parameter to "ibex_pkg::RegFileFF".
It is the default selection.
```

## Additional requirement

When `BaseIsa` is `BaseIsaRV32I`, `rcap_a_o` and `rcap_b_o` output `CapWordZeroVal` for every read address.
