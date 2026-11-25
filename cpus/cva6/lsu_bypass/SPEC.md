# Implement `lsu_bypass`

Implement the complete `lsu_bypass` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module lsu_bypass` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      SuperscalarEn: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.SuperscalarEn = CVA6Cfg.SuperscalarEn;
// ...
    cfg.SpeculativeSb = CVA6Cfg.SuperscalarEn;
```

## Module declaration

```systemverilog
module lsu_bypass
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type lsu_ctrl_t = logic,
    parameter type bp_resolve_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic flush_i,

    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input lsu_ctrl_t lsu_req_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic      lsu_req_valid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic      pop_ld_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic      pop_st_i,

    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,

    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output lsu_ctrl_t lsu_ctrl_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic      ready_o
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
    // branch-predict
    // this is the struct we get back from ex stage and we will use it to update
    // all the necessary data structures
    // bp_resolve_t
    localparam type bp_resolve_t = struct packed {
      logic                    valid;           // prediction with all its values is valid
      logic [CVA6Cfg.VLEN-1:0] pc;              // PC of predict or mis-predict
      logic [CVA6Cfg.VLEN-1:0] target_address;  // target address at which to jump, or not
      logic                    is_mispredict;   // set if this was a mis-predict
      logic                    is_taken;        // branch is taken
      cf_t                     cf_type;         // Type of control flow change
    },
// ...
    localparam type lsu_ctrl_t = struct packed {
      logic                             valid;
      logic [CVA6Cfg.VLEN-1:0]          vaddr;
      logic [31:0]                      tinst;
      logic                             hs_ld_st_inst;
      logic                             hlvx_inst;
      logic                             overflow;
      logic                             g_overflow;
      logic [CVA6Cfg.XLEN-1:0]          data;
      logic [(CVA6Cfg.XLEN/8)-1:0]      be;
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
      logic                             is_speculative_load;
      logic                             is_speculative_load_miss;
    },
```

### core/load_store_unit.sv

```systemverilog
  // ------------------
  // LSU Control
  // ------------------
  // new data arrives here
  lsu_ctrl_t lsu_req_i;

  assign lsu_req_i = {
    lsu_valid_i,
    vaddr_i,
    tinst_i,
    hs_ld_st_inst,
    hlvx_inst,
    overflow,
    g_overflow,
    fu_data_i.operand_b,
    be_i,
    fu_data_i.fu,
    fu_data_i.operation,
    fu_data_i.trans_id,
    speculative_load_i,
    1'b0
  };

  lsu_bypass #(
      .CVA6Cfg(CVA6Cfg),
      .lsu_ctrl_t(lsu_ctrl_t),
      .bp_resolve_t(bp_resolve_t)
  ) lsu_bypass_i (
      .clk_i,
      .rst_ni,
      .flush_i,
      .lsu_req_i      (lsu_req_i),
      .lsu_req_valid_i(lsu_valid_i),
      .pop_ld_i       (pop_ld),
      .pop_st_i       (pop_st),
      .resolved_branch_i,

      .lsu_ctrl_o(lsu_ctrl_byp),
      .ready_o   (lsu_ready_o)
  );
```

## Related source code

### core/ex_stage.sv

```systemverilog
  // ----------------
  // Load-Store Unit
  // ----------------
  fu_data_t lsu_data;
  logic [31:0] lsu_tinst;
  logic speculative_load;
  always_comb begin
    lsu_data = lsu_valid_i[0] ? fu_data_i[0] : '0;
    lsu_tinst = tinst_i[0];
    speculative_load = 1'b0;

    if (CVA6Cfg.SuperscalarEn) begin
      if (lsu_valid_i[1]) begin
        lsu_data  = fu_data_i[1];
        lsu_tinst = tinst_i[1];
        if (CVA6Cfg.SpeculativeSb) begin
          speculative_load = branch_valid_i[0];
        end
      end
    end
  end
```

## Documentation

### docs/03_cva6_design/ex_stage.md

```text
##### LSU Bypass {#par:lsu_bypass}

The LSU bypass module is an auxiliary module which manages the LSU status
information (full flag etc.) which it presents to the issue stage. This
is necessary for the following reason: The design of the LSU is critical in
most aspects as it directly interfaces the relatively slow SRAMs. It additionally
needs to do some costly operation in sequence. The most costly (in terms
of timing) being address generation, address translation and checking
the store buffer for potential aliasing. Therefore it is only known very
late whether the current load/store can go to memory or if additional
cycles are needed. From which aliasing on the store buffer and TLB miss
are the most prominent ones. As the issue stage relies on the
ready signal to dispatch new instructions this would result in an overly
long path which would considerably slow down the whole design because of
some corner cases.

To mitigate this problem a FIFO is added which can hold
another request from issue stage. Therefore the ready flag of the
functional units can be delayed by one cycle which eases timing.
The LSU bypass model further decouples the functional unit
from the issue stage. This is mostly necessary as the issue stage can't
stall as soon as it issued an instruction. In particular the LSU bypass
is called that way because it is either bypassed or serves the load or
store unit from its internal FIFO until they signal completion to the
LSU bypass module.
```

### docs/design/design-manual/source/cva6_execute.adoc

```text
[[lsu_bypass]]
====== lsu_bypass

The LSU bypass is a FIFO which keeps instructions from the issue stage when the store unit or the load unit are not available immediately.

include::port_lsu_bypass.adoc[]
```

## Additional requirement

Drive `ready_o` high exactly when no request is held, and in that case pass `lsu_req_i` to `lsu_ctrl_o` in the same cycle.
