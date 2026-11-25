# Implement `ras`

Implement the complete `ras` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ras` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      RASDepth: unsigned'(2),
```

## Module declaration

```systemverilog
// return address stack
module ras #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type ras_t = logic,
    parameter int unsigned DEPTH = 2
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Branch prediction flush request - zero
    input logic flush_bp_i,
    // Push address in RAS - FRONTEND
    input logic push_i,
    // Pop address from RAS - FRONTEND
    input logic pop_i,
    // Data to be pushed - FRONTEND
    input logic [CVA6Cfg.VLEN-1:0] data_i,
    // Popped data - FRONTEND
    output ras_t data_o
);
```

## Parent instantiation

### core/frontend/frontend.sv

```systemverilog
  localparam type ras_t = struct packed {
    logic                    valid;
    logic [CVA6Cfg.VLEN-1:0] ra;
  };
// ...
        // return
        4'b0100: begin
          // make sure to only alter the RAS if we actually consumed the instruction
          ras_pop = ras_predict.valid & instr_queue_consumed[i];
          ras_push = 1'b0;
          predict_address = ras_predict.ra;
          cf_type[i] = ariane_pkg::Return;
        end
// ...
      // if this instruction, in addition, is a call, save the resulting address
      // but only if we actually consumed the address
      if (is_call[i]) begin
        ras_push   = instr_queue_consumed[i];
        ras_update = addr[i] + (rvc_call[i] ? 2 : 4);
      end
// ...
  if (CVA6Cfg.RASDepth == 0) begin
    assign ras_predict = '0;
  end else begin : ras_gen
    ras #(
        .CVA6Cfg(CVA6Cfg),
        .ras_t  (ras_t),
        .DEPTH  (CVA6Cfg.RASDepth)
    ) i_ras (
        .clk_i,
        .rst_ni,
        .flush_bp_i(flush_bp_i),
        .push_i(ras_push),
        .pop_i(ras_pop),
        .data_i(ras_update),
        .data_o(ras_predict)
    );
  end
```

## Documentation

### docs/design/design-manual/source/cva6_frontend.adoc

```text
RAS is implemented as a LIFO which is composed of {RASDepth} entries.

When a "call" JAL instruction (rd = x1 or x5) is added to the instruction queue, the PC of the instruction following the JAL instruction is pushed into the stack.

When a "ret" JALR instruction (rs1 = x1 or x5, and rd != rs1) is added to the instruction queue, the predicted return address is popped from the stack.
If the predicted return address is wrong due for instance to speculation or RAS depth limitation, a mispredict will be generated.
```

### src/rv32.adoc

```text
Return-address prediction stacks are a common feature of
high-performance instruction-fetch units, but require accurate detection
of instructions used for procedure calls and returns to be effective.
For RISC-V, hints as to the instructions' usage are encoded implicitly
via the register numbers used. A JAL instruction should push the return
address onto a return-address stack (RAS) only when _rd_ is 'x1' or
`x5`. JALR instructions should push/pop a RAS as shown in <<rashints>>.

[[rashints]]
.Return-address stack prediction hints encoded in the register operands of a JALR instruction.
[%autowidth,float="center",align="center",cols="^,^,^,<",options="header"]
|===
|_rd_ is _x1/x5_ |_rs1_ is _x1/x5_ |_rd_=_rs1_ |RAS action

|No |No |-- |None

|No |Yes |-- |Pop

|Yes |No |-- |Push

|Yes |Yes |No |Pop, then push

|Yes |Yes |Yes |Push
|===
```
