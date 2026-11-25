# Implement `bht`

Implement the complete `bht` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module bht` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      FpgaEn: bit'(0),
      // ...
      SuperscalarEn: bit'(0),
      // ...
      RVC: bit'(1),
      // ...
      BPType: config_pkg::BHT,
      BHTEntries: unsigned'(32),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.FETCH_WIDTH = unsigned'(CVA6Cfg.SuperscalarEn ? 64 : 32);
    // ...
    cfg.INSTR_PER_FETCH = cfg.FETCH_WIDTH / (CVA6Cfg.RVC ? 16 : 32);
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  typedef struct packed {
    logic valid;
    logic taken;
  } bht_prediction_t;
```

## Module declaration

```systemverilog
module bht #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter int unsigned NR_ENTRIES = 1024
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Branch prediction flush request - zero
    input logic flush_bp_i,
    // Debug mode state - CSR
    input logic debug_mode_i,
    // Virtual PC - CACHE
    input logic [CVA6Cfg.VLEN-1:0] vpc_i,
    // Update bht with resolved address - EXECUTE
    input bht_update_t bht_update_i,
    // Prediction from bht - FRONTEND
    output ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o
);
```

## Parent instantiation

### core/frontend/frontend.sv

```systemverilog
  localparam type bht_update_t = struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
    logic                    taken;
  };
  // ...
  if (CVA6Cfg.BHTEntries == 0) begin
    assign bht_prediction = '0;
  end else if (CVA6Cfg.BPType == config_pkg::BHT) begin : bht_gen
    bht #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(CVA6Cfg.BHTEntries)
    ) i_bht (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_bht),
        .bht_update_i    (bht_update),
        .bht_prediction_o(bht_prediction)
    );
  // ...
```

## Documentation

### docs/design/design-manual/source/cva6_frontend.adoc

```text
[[bht-branch-history-table-submodule]]
BHT (Branch History Table) submodule
++++++++++++++++++++++++++++++++++++

The BHT is implemented as a memory which is composed of {BHTEntries} entries.
The BHT is a two-dimensional table:

*	The first dimension represents the access address, with a length equal to `{BHTEntries} / {instr-per-fetch}`.
*	The second dimension represents the row index, with a length equal to `{instr-per-fetch}`.

In the case of branch prediction, the BHT uses only part of the virtual address to get the value of the saturation counter.
In the case of a valid misprediction, the BHT uses only part of the misprediction address to access the BHT table and update the saturation counter.
...
Each BHT entry contains a two-bit saturating counter and a valid bit.
On reset, the counters are set to 0 (strongly not taken) and the valid bits are cleared.
When a branch instruction is resolved by the EX_STAGE module, the valid bit is set and the counter is updated.
...
When a branch instruction is pre-decoded by instr_scan submodule, the BHT valids whether the PC address is inside the BHT and provides the taken or not prediction.
The prediction is the most significant bit from the counter, where 1 means "taken".

When the Execute stage processes a branch instruction, it sends the branch status (whether it's taken or not) to the Frontend to update the BHT table
```

### docs/sections/branch-prediction/backing-predictor.rst

```text
The basic building block of most branch predictors is the "Two-bit
Counter Table" (2BC). As a particular branch is repeatedly taken, the
counter saturates upwards to the max value 3 (*0b11*) or *strongly
taken*. Likewise, repeatedly not-taken branches saturate towards zero
(*0b00*). The high-order bit specifies the *prediction* and the
low-order bit specifies the *hysteresis* (how “strong” the
prediction is).
```

## Additional requirement

Without waiting for a clock edge, `bht_prediction_o[k]` reports the entry trained by the valid updates whose `bht_update_i.pc[5:1]` equals `{vpc_i[5:2], k}`.
