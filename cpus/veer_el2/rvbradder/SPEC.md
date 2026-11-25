# Implement `rvbradder`

Implement the complete `rvbradder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvbradder` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvbradder
  (
    input [31:1] pc,
    input [12:1] offset,

    output [31:1] dout
    );
```

## Parent instantiation

### design/dec/el2_dec_decode_ctl.sv

```verilog
   rvbradder ibradder_correct (
                     .pc(exu_i0_pc_x[31:1]),
                     .offset(last_br_immed_x[12:1]),
                     .dout(pred_correct_npc_x[31:1]));
```

### design/exu/el2_exu_alu_ctl.sv

```verilog
   rvbradder ibradder (
                     .pc     ( pc_in[31:1]    ),
                     .offset ( brimm_in[12:1] ),
                     .dout   ( pcout[31:1]    ));
```

### design/ifu/el2_ifu_bp_ctl.sv

```verilog
   rvbradder predtgt_addr (.pc({adder_pc_in_f[31:2], bp_total_branch_offset_f}),
                         .offset(btb_rd_tgt_f[11:0]),
                         .dout(bp_btb_target_adder_f[31:1])
                         );
// ...
   rvbradder rs_addr (.pc({adder_pc_in_f[31:2], bp_total_branch_offset_f}),
                    .offset({11'b0,  ~btb_rd_pc4_f}),
                    .dout(bp_rs_call_target_f[31:1])
                         );
```

## Documentation

### src/rv32.adoc

```text
==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.
```
