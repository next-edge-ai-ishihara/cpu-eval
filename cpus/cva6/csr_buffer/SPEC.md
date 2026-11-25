# Implement `csr_buffer`

Implement the complete `csr_buffer` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module csr_buffer` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module csr_buffer
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Flush CSR - CONTROLLER
    input logic flush_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // CSR FU is ready - ISSUE_STAGE
    output logic csr_ready_o,
    // CSR instruction is valid - ISSUE_STAGE
    input logic csr_valid_i,
    // CSR buffer result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] csr_result_o,
    // commit the pending CSR OP - TO_BE_COMPLETED
    input logic csr_commit_i,
    // CSR address to write - COMMIT_STAGE
    output logic [11:0] csr_addr_o
);
```

## Parent instantiation

### core/ex_stage.sv

```systemverilog
  csr_buffer #(
      .CVA6Cfg  (CVA6Cfg),
      .fu_data_t(fu_data_t)
  ) csr_buffer_i (
      .clk_i,
      .rst_ni,
      .flush_i,
      .fu_data_i   (one_cycle_data),
      .csr_valid_i (|csr_valid_i),
      .csr_ready_o (csr_ready),
      .csr_result_o(csr_result),
      .csr_commit_i,
      .csr_addr_o
  );
```

## Dependency declarations

### core/cva6.sv

```systemverilog
    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },
```

## Related source code

### core/ex_stage.sv

```systemverilog
  assign flu_valid_o = |one_cycle_select | mult_valid;

  // result MUX
  always_comb begin
    // Branch result as default case
    flu_result_o   = {{CVA6Cfg.XLEN - CVA6Cfg.VLEN{1'b0}}, branch_result};
    flu_trans_id_o = one_cycle_data.trans_id;
    // ALU result
    if (|alu_valid_i) begin
      flu_result_o = alu_result[0];
      // CSR result
    end else if (|csr_valid_i) begin
      flu_result_o = csr_result;
    end else if (mult_valid) begin
      flu_result_o   = mult_result;
      flu_trans_id_o = mult_trans_id;
    end else if (|aes_valid_i) begin
      flu_result_o = aes_result;
    end
  end

  // ready flags for FLU
  always_comb begin
    flu_ready_o = csr_ready & mult_ready;
  end
```

### core/commit_stage.sv

```systemverilog
        // CSR Logic
        // ---------
        // check whether the instruction we retire was a CSR instruction and it did not
        // throw an exception
        if (commit_instr_i[0].fu == CSR) begin
          // write the CSR file
          csr_op_o    = commit_instr_i[0].op;
          csr_wdata_o = commit_instr_i[0].result;
          if (!commit_drop_i[0]) begin
            if (!csr_exception_i.valid) begin
              commit_csr_o = 1'b1;
              wdata_o[0]   = csr_rdata_i;
            end else begin
              commit_ack_o[0] = 1'b0;
              we_gpr_o[0] = 1'b0;
```

### core/decoder.sv

```systemverilog
            // atomically swaps values in the CSR and integer register
            3'b001: begin  // CSRRW
              imm_select = IIMM;
              instruction_o.op = ariane_pkg::CSR_WRITE;
            end
            // atomically set values in the CSR and write back to rd
            3'b010: begin  // CSRRS
              imm_select = IIMM;
              // this is just a read
              if (instr.itype.rs1 == '0) instruction_o.op = ariane_pkg::CSR_READ;
              else instruction_o.op = ariane_pkg::CSR_SET;
            end
            // atomically clear values in the CSR and write back to rd
            3'b011: begin  // CSRRC
              imm_select = IIMM;
              // this is just a read
              if (instr.itype.rs1 == '0) instruction_o.op = ariane_pkg::CSR_READ;
              else instruction_o.op = ariane_pkg::CSR_CLEAR;
            end
            // use zimm and iimm
            3'b101: begin  // CSRRWI
              instruction_o.rs1 = instr.itype.rs1;
              imm_select = IIMM;
              instruction_o.use_zimm = 1'b1;
              instruction_o.op = ariane_pkg::CSR_WRITE;
            end
            3'b110: begin  // CSRRSI
              instruction_o.rs1 = instr.itype.rs1;
              imm_select = IIMM;
              instruction_o.use_zimm = 1'b1;
              // this is just a read
              if (instr.itype.rs1 == 5'b0) instruction_o.op = ariane_pkg::CSR_READ;
              else instruction_o.op = ariane_pkg::CSR_SET;
            end
            3'b111: begin  // CSRRCI
              instruction_o.rs1 = instr.itype.rs1;
              imm_select = IIMM;
              instruction_o.use_zimm = 1'b1;
              // this is just a read
              if (instr.itype.rs1 == '0) instruction_o.op = ariane_pkg::CSR_READ;
              else instruction_o.op = ariane_pkg::CSR_CLEAR;

// ...

    // NOIMM, IIMM, SIMM, SBIMM, UIMM, JIMM, RS3
    // select immediate
    case (imm_select)
      IIMM: begin
        instruction_o.result  = imm_i_type;
        instruction_o.use_imm = 1'b1;
      end
```

### core/issue_read_operands.sv

```systemverilog
  assign csr_valid_o = csr_valid_q;

// ...

  // ---------------
  // Issue Stage
  // ---------------

  always_comb begin : structural_hazards
    fus_busy = '0;
    // CVXIF is always ready to try a new transaction on 1st issue port
    // If a transaction is already pending then we stall until the transaction is done.(issue_ack_o[0] = 0)
    // Since we can not have two CVXIF instruction on 1st issue port, CVXIF is always ready for the pending instruction.
    if (!flu_ready_i) begin
      fus_busy[0].alu = 1'b1;
      fus_busy[0].aes = 1'b1;
      fus_busy[0].ctrl_flow = 1'b1;
      fus_busy[0].csr = 1'b1;
      fus_busy[0].mult = 1'b1;
    end

// ...

  // Forwarding/Output MUX
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    always_comb begin : forwarding_operand_select
      // default is regfiles (gpr or fpr)
      fu_data_n[i].operand_a = operand_a_regfile[i];
      fu_data_n[i].operand_b = operand_b_regfile[i];

// ...

      // use the zimm as operand a
      if (issue_instr_i[i].use_zimm) begin
        // zero extend operand a
        fu_data_n[i].operand_a = {{CVA6Cfg.XLEN - 5{1'b0}}, issue_instr_i[i].rs1[4:0]};
      end
      // or is it an immediate (including PC), this is not the case for a store, control flow, and accelerator instructions
      // also make sure operand B is not already used as an FP operand
      if (issue_instr_i[i].use_imm && (issue_instr_i[i].fu != STORE) && (issue_instr_i[i].fu != CTRL_FLOW) && (issue_instr_i[i].fu != ACCEL) && !(CVA6Cfg.FpPresent && is_rs2_fpr(
              issue_instr_i[i].op
          ))) begin
        fu_data_n[i].operand_b = issue_instr_i[i].result;
      end

// ...

    csr_valid_n    = '0;
    branch_valid_n = '0;
    for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      if (!issue_instr_i[i].ex.valid && issue_instr_valid_i[i] && issue_ack_o[i]) begin
        case (issue_instr_i[i].fu)
          ALU: begin
            if (CVA6Cfg.SuperscalarEn && use_alu2[i]) begin
              alu2_valid_n[i] = 1'b1;
            end else begin
              alu_valid_n[i] = 1'b1;
            end
          end
          CTRL_FLOW: begin
            branch_valid_n[i] = 1'b1;
          end
          MULT: begin
            mult_valid_n[i] = 1'b1;
          end
          LOAD, STORE: begin
            lsu_valid_n[i] = 1'b1;
          end
          CSR: begin
            csr_valid_n[i] = 1'b1;
          end

// ...

  // FU select, assert the correct valid out signal (in the next cycle)
  // This needs to be like this to make verilator happy. I know it's ugly.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      alu_valid_q    <= '0;
      aes_valid_q    <= '0;
      lsu_valid_q    <= '0;
      mult_valid_q   <= '0;
      fpu_valid_q    <= '0;
      fpu_fmt_q      <= '0;
      fpu_rm_q       <= '0;
      alu2_valid_q   <= '0;
      csr_valid_q    <= '0;
      branch_valid_q <= '0;
    end else begin
      alu_valid_q    <= alu_valid_n;
      aes_valid_q    <= aes_valid_n;
      lsu_valid_q    <= lsu_valid_n;
      mult_valid_q   <= mult_valid_n;
      fpu_valid_q    <= fpu_valid_n;
      fpu_fmt_q      <= fpu_fmt_n;
      fpu_rm_q       <= fpu_rm_n;
      alu2_valid_q   <= alu2_valid_n;
      csr_valid_q    <= csr_valid_n;
      branch_valid_q <= branch_valid_n;
    end
  end
```

## Documentation

### docs/03_cva6_design/ex_stage.md

```text
#### CSR Buffer

The CSR buffer is a functional unit which only purpose is to store the
address of the CSR register the instruction is going to read/write.
There are two reasons why we need to do this. The first reason is that
a CSR instruction alters the architectural state, hence this
instruction has to be buffered and can only be executed as soon as the
commit stage decides to commit the instruction. The second reason is the
way the scoreboard entry is structured: It has only one result
field but for any CSR instruction we need to keep the data we want to
write and the address of the CSR which this instruction is going to
alter. In order to not clutter the scoreboard with some special case bit
fields the CSR buffer comes into play. It simply holds the address and
if the CSR instruction is going to execute it will use the stored
address.

The clear disadvantage is that with the buffer being just one element we
can't execute more than one CSR instruction back to back without a
pipeline stall. Since CSR instructions are quite rare this is not too
much of a problem. Some CSR instructions will cause a pipeline flush
anyway.
```

### docs/03_cva6_design/commit_stage.rst

```text
We can distinguish two categories of retiring instructions. The first
category just write the architectural register file. The second might as
well write the register file but needs some further business logic to
happen. At the time of this writing the only two places where this is
necessary it the store unit where the commit stage needs to tell the
store unit to actually commit the store to memory and the CSR buffer
which needs to be freed as soon as the corresponding CSR instruction
retires.
```
