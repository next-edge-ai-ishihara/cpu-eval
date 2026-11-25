# Implement `raw_checker`

Implement the complete `raw_checker` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module raw_checker` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
// ...
      NrScoreboardEntries: unsigned'(4),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.NR_SB_ENTRIES = CVA6Cfg.NrScoreboardEntries;
    cfg.TRANS_ID_BITS = $clog2(CVA6Cfg.NrScoreboardEntries);
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  // 32 registers
  localparam REG_ADDR_SIZE = 5;
```

## Module declaration

```systemverilog
module raw_checker
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Register source of the instruction to check RAW dependencies - SCOREBOARD
    input logic [REG_ADDR_SIZE-1:0] rs_i,
    // Type of register source (FPR or GPR) - SCOREBOARD
    input logic rs_fpr_i,
    // Registers of destination of the instructions already issued in the scoreboard - SCOREBOARD 
    input logic [CVA6Cfg.NR_SB_ENTRIES-1:0][REG_ADDR_SIZE-1:0] rd_i,
    // Type of registers of destination (FPR or GPR) - SCOREBOARD
    input logic [CVA6Cfg.NR_SB_ENTRIES-1:0] rd_fpr_i,
    // Instructions in the scoreboard are still issued - SCOREBOARD
    input logic [CVA6Cfg.NR_SB_ENTRIES-1:0] still_issued_i,
    // Issue pointer - SCOREBOARD
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer_i,

    // Index in the scoreboard of the most recent RAW dependency - SCOREBOARD
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] idx_o,
    // Indicates if there is a RAW dependency - SCOREBOARD
    output logic valid_o
);
```

## Parent instantiation

### core/issue_read_operands.sv

```systemverilog
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign rs1_fpr[i] = (CVA6Cfg.FpPresent && ariane_pkg::is_rs1_fpr(issue_instr_i[i].op));
    assign rs2_fpr[i] = (CVA6Cfg.FpPresent && ariane_pkg::is_rs2_fpr(issue_instr_i[i].op));
    assign rs3_fpr[i] = (CVA6Cfg.FpPresent && ariane_pkg::is_imm_fpr(issue_instr_i[i].op));
    assign rs3_gpr_cvxif[i] = CVA6Cfg.CvxifEn && (OPERANDS_PER_INSTR == 3)
        && issue_instr_i[i].op == OFFLOAD;
  end

  // ----------------------------------
  // Renaming
  // ----------------------------------
  for (genvar i = 0; i < CVA6Cfg.NR_SB_ENTRIES; i++) begin
    assign rd_list[i] = fwd_i.sbe[i].rd;
    assign rd_fpr[i]  = CVA6Cfg.FpPresent && ariane_pkg::is_rd_fpr(fwd_i.sbe[i].op);
  end

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin : gen_raw_checks
    raw_checker #(
        .CVA6Cfg(CVA6Cfg)
    ) i_rs1_last_raw (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .rs_i(issue_instr_i[i].rs1),
        .rs_fpr_i(rs1_fpr[i]),
        .rd_i(rd_list),
        .rd_fpr_i(rd_fpr),
        .still_issued_i(fwd_i.still_issued),
        .issue_pointer_i(fwd_i.issue_pointer),
        .idx_o(idx_hzd_rs1[i]),
        .valid_o(rs1_raw_check[i])
    );
```

## Related source code

### core/scoreboard.sv

```systemverilog
  assign issue_pointer[0] = issue_pointer_q;
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign issue_pointer[i+1] = issue_pointer[i] + 'd1;
  end
// ...
    for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      // make sure we assign the correct trans ID
      issue_instr_o[i].trans_id = issue_pointer[i];
// ...
    // if we got an acknowledge from the issue stage, put this scoreboard entry in the queue
    for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      if (decoded_instr_valid_i[i] && decoded_instr_ack_o[i] && !flush_unissued_instr_i) begin
        // the decoded instruction we put in there is valid (1st bit)
        // increase the issue counter and advance issue pointer
        num_issue += 'd1;
        mem_n[issue_pointer[i]] = '{
            issued: 1'b1,
            cancelled: 1'b0,
            is_rd_fpr_flag: CVA6Cfg.FpPresent && ariane_pkg::is_rd_fpr(decoded_instr_i[i].op),
            sbe: decoded_instr_i[i]
        };
// ...
  always_comb begin : assign_issue_pointer_n
    issue_pointer_n = issue_pointer[num_issue];
    if (flush_i) issue_pointer_n = '0;
// ...
  assign fwd_o.still_issued = still_issued;
  assign fwd_o.issue_pointer = issue_pointer[0];
  assign fwd_o.wb = wb;
  for (genvar i = 0; i < CVA6Cfg.NR_SB_ENTRIES; i++) begin
    assign fwd_o.sbe[i] = mem_q[i].sbe;
```

## Documentation

### docs/design/design-manual/source/cva6_issue_stage.adoc

```text
Issue_read_operands tracks hazards and gets the input operands for the instructions to execute.
The following hazards can prevent instructions from being issued.

* Data hazards: ISSUE_STAGE checks that the instruction operands are available.

** [[raw_hazard]] Read-After-Write (RAW): if one of the source registers of the instruction to issue is the destination register of one of the instructions in the Scoreboard, issue is blocked.
...
** Special case: there are no data hazards on `x0`.
```
