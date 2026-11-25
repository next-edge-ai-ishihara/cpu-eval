# Implement `ibex_multdiv_fast`

Implement the complete `ibex_multdiv_fast` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_multdiv_fast` definition in a single SystemVerilog code block, with no text outside the block.

## Package and imports

### rtl/ibex_pkg.sv

```systemverilog
  typedef enum integer {
    RV32MNone        = 0,
    RV32MSlow        = 1,
    RV32MFast        = 2,
    RV32MSingleCycle = 3
  } rv32m_e;
// ...
  typedef enum logic [1:0] {
    // Multiplier/divider
    MD_OP_MULL,
    MD_OP_MULH,
    MD_OP_DIV,
    MD_OP_REM
  } md_op_e;
```

## Module declaration

```systemverilog
module ibex_multdiv_fast #(
  parameter ibex_pkg::rv32m_e RV32M = ibex_pkg::RV32MFast
  ) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             mult_en_i,  // dynamic enable signal, for FSM control
  input  logic             div_en_i,   // dynamic enable signal, for FSM control
  input  logic             mult_sel_i, // static decoder output, for data muxes
  input  logic             div_sel_i,  // static decoder output, for data muxes
  input  ibex_pkg::md_op_e operator_i,
  input  logic  [1:0]      signed_mode_i,
  input  logic [31:0]      op_a_i,
  input  logic [31:0]      op_b_i,
  input  logic [33:0]      alu_adder_ext_i,
  input  logic [31:0]      alu_adder_i,
  input  logic             equal_to_zero_i,
  input  logic             data_ind_timing_i,

  output logic [32:0]      alu_operand_a_o,
  output logic [32:0]      alu_operand_b_o,

  input  logic [33:0]      imd_val_q_i[2],
  output logic [33:0]      imd_val_d_o[2],
  output logic [1:0]       imd_val_we_o,

  input  logic             multdiv_ready_id_i,

  output logic [31:0]      multdiv_result_o,
  output logic             valid_o
);
```

## Parent instantiation

### rtl/ibex_ex_block.sv

```systemverilog
  if (RV32M != RV32MNone) begin : gen_multdiv_m
    assign multdiv_sel = mult_sel_i | div_sel_i;
  end else begin : gen_multdiv_no_m
    assign multdiv_sel = 1'b0;
  end

  // Intermediate Value Register Mux
  assign imd_val_d_o[0] = multdiv_sel ? multdiv_imd_val_d[0] : {2'b0, alu_imd_val_d[0]};
  assign imd_val_d_o[1] = multdiv_sel ? multdiv_imd_val_d[1] : {2'b0, alu_imd_val_d[1]};
  assign imd_val_we_o   = multdiv_sel ? multdiv_imd_val_we : alu_imd_val_we;

  assign alu_imd_val_q = '{imd_val_q_i[0][31:0], imd_val_q_i[1][31:0]};

  assign result_ex_o  = multdiv_sel ? multdiv_result : alu_result;
// ...
  ibex_alu #(
    .RV32B(RV32B)
  ) alu_i (
    .operator_i         (alu_operator_i),
    .operand_a_i        (alu_operand_a_i),
    .operand_b_i        (alu_operand_b_i),
    .instr_first_cycle_i(alu_instr_first_cycle_i),
    .imd_val_q_i        (alu_imd_val_q),
    .imd_val_we_o       (alu_imd_val_we),
    .imd_val_d_o        (alu_imd_val_d),
    .multdiv_operand_a_i(multdiv_alu_operand_a),
    .multdiv_operand_b_i(multdiv_alu_operand_b),
    .multdiv_sel_i      (multdiv_sel),
    .adder_result_o     (alu_adder_result_ex_o),
    .adder_result_ext_o (alu_adder_result_ext),
    .result_o           (alu_result),
    .comparison_result_o(alu_cmp_result),
    .is_equal_result_o  (alu_is_equal_result)
  );
// ...
  end else if (RV32M == RV32MFast || RV32M == RV32MSingleCycle) begin : gen_multdiv_fast
    ibex_multdiv_fast #(
      .RV32M(RV32M)
    ) multdiv_i (
      .clk_i             (clk_i),
      .rst_ni            (rst_ni),
      .mult_en_i         (mult_en_i),
      .div_en_i          (div_en_i),
      .mult_sel_i        (mult_sel_i),
      .div_sel_i         (div_sel_i),
      .operator_i        (multdiv_operator_i),
      .signed_mode_i     (multdiv_signed_mode_i),
      .op_a_i            (multdiv_operand_a_i),
      .op_b_i            (multdiv_operand_b_i),
      .alu_operand_a_o   (multdiv_alu_operand_a),
      .alu_operand_b_o   (multdiv_alu_operand_b),
      .alu_adder_ext_i   (alu_adder_result_ext),
      .alu_adder_i       (alu_adder_result_ex_o),
      .equal_to_zero_i   (alu_is_equal_result),
      .data_ind_timing_i (data_ind_timing_i),
      .imd_val_q_i       (imd_val_q_i),
      .imd_val_d_o       (multdiv_imd_val_d),
      .imd_val_we_o      (multdiv_imd_val_we),
      .multdiv_ready_id_i(multdiv_ready_id_i),
      .valid_o           (multdiv_valid),
      .multdiv_result_o  (multdiv_result)
    );
  end

  // Multiplier/divider may require multiple cycles. The ALU output is valid in the same cycle
  // unless the intermediate result register is being written (which indicates this isn't the
  // final cycle of ALU operation).
  assign ex_valid_o = multdiv_sel ? multdiv_valid : ~(|alu_imd_val_we);
```

## Related source code

### rtl/ibex_alu.sv

```systemverilog
  output logic [31:0]       adder_result_o,
  output logic [33:0]       adder_result_ext_o,
// ...
  logic [32:0] adder_in_a, adder_in_b;
  logic [31:0] adder_result;
// ...
  // prepare operand a
  always_comb begin
    unique case (1'b1)
      multdiv_sel_i:     adder_in_a = multdiv_operand_a_i;
      adder_op_a_shift1: adder_in_a = {operand_a_i[30:0],2'b01};
      adder_op_a_shift2: adder_in_a = {operand_a_i[29:0],3'b001};
      adder_op_a_shift3: adder_in_a = {operand_a_i[28:0],4'b0001};
      default:           adder_in_a = {operand_a_i,1'b1};
    endcase
  end

  // prepare operand b
  assign operand_b_neg = {operand_b_i,1'b0} ^ {33{1'b1}};
  always_comb begin
    unique case (1'b1)
      multdiv_sel_i:     adder_in_b = multdiv_operand_b_i;
      adder_op_b_negate: adder_in_b = operand_b_neg;
      default:           adder_in_b = {operand_b_i, 1'b0};
    endcase
  end

  // actual adder
  assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);

  assign adder_result       = adder_result_ext_o[32:1];

  assign adder_result_o     = adder_result;
// ...
  assign is_equal = (adder_result == 32'b0);
  assign is_equal_result_o = is_equal;
```

### rtl/ibex_id_stage.sv

```systemverilog
  for (genvar i = 0; i < 2; i++) begin : gen_intermediate_val_reg
    always_ff @(posedge clk_i or negedge rst_ni) begin : intermediate_val_reg
      if (!rst_ni) begin
        imd_val_q[i] <= '0;
      end else if (imd_val_we_ex_i[i]) begin
        imd_val_q[i] <= imd_val_d_ex_i[i];
      end
    end
  end

  assign imd_val_q_ex_o = imd_val_q;
// ...
  // Note for the two-stage configuration ready_wb_i is always set
  assign multdiv_ready_id_o = ready_wb_i;
```

### rtl/ibex_multdiv_slow.sv

```systemverilog
  // Sign extend the input operands
  assign sign_a   = op_a_i[31] & signed_mode_i[0];
  assign sign_b   = op_b_i[31] & signed_mode_i[1];
```

## Documentation

### doc/03_reference/instruction_decode_execute.rst

```text
Multiplier/Divider Block (MULT/DIV)
-----------------------------------
Source Files: :file:`rtl/ibex_multdiv_slow.sv` :file:`rtl/ibex_multdiv_fast.sv`

The Multiplier/Divider (MULT/DIV) is a state machine driven block to perform multiplication and division.
The fast and slow versions differ in multiplier only. All versions implement the same form of long division algorithm. The ALU block is used by the long division algorithm in all versions.

Multiplier
  The multiplier can be implemented in three variants controlled via the enumerated parameter ``RV32M`` defined in :file:`rtl/ibex_pkg.sv`.

  Single-Cycle Multiplier
    This implementation is chosen by setting the ``RV32M`` parameter to "ibex_pkg::RV32MSingleCycle".
    The single-cycle multiplier makes use of three parallel multiplier units, designed to be mapped to hardware multiplier primitives on FPGAs.
    It is therefore the **first choice for FPGA synthesis**.

    - Using three parallel 17-bit x 17-bit multiplication units and a 34-bit accumulator, it completes a MUL instruction in 1 cycle. MULH is completed in 2 cycles.
    - This MAC is internal to the mult/div block (no external ALU use).
    - Beware it is simply implemented with the ``*`` and ``+`` operators so results heavily depend upon the synthesis tool used.
    - ASIC synthesis has not yet been tested but is expected to consume 3-4x the area of the fast multiplier for ASIC.

  Fast Multi-Cycle Multiplier
    This implementation is chosen by setting the ``RV32M`` parameter to "ibex_pkg::RV32MFast".
    The fast multi-cycle multiplier provides a reasonable trade-off between area and performance. It is the **first choice for ASIC synthesis**.

    - Completes multiply in 3-4 cycles using a MAC (multiply accumulate) which is capable of a 17-bit x 17-bit multiplication with a 34-bit accumulator.
    - A MUL instruction takes 3 cycles, MULH takes 4.
    - This MAC is internal to the mult/div block (no external ALU use).
    - Beware it is simply implemented with the ``*`` and ``+`` operators so results heavily depend upon the synthesis tool used.
    - In some cases it may be desirable to replace this with a specific implementation such as an explicit gate level implementation.

  Slow Multi-Cycle Multiplier
    To select the slow multi-cycle multiplier, set the ``RV32M`` parameter to "ibex_pkg::RV32MSlow".

    - Completes multiply in clog2(``op_b``) + 1 cycles (for MUL) or 33 cycles (for MULH) using a Baugh-Wooley multiplier.
    - The ALU block is used to compute additions.

Divider
  Both the fast and slow blocks use the same long division algorithm, it takes 37 cycles to compute (though only requires 2 cycles when there is a divide by 0) and proceeds as follows:

    - Cycle 0: Check for divide by 0
    - Cycle 1: Compute absolute value of operand A (or return result on divide by 0)
    - Cycle 2: Compute absolute value of operand B
    - Cycles 4 - 36: Perform long division as described here: https://en.wikipedia.org/wiki/Division_algorithm#Integer_division_(unsigned)_with_remainder.

By setting the ``RV32M`` parameter to "ibex_pkg::RV32MNone", the M-extension can be disabled completely.
```
