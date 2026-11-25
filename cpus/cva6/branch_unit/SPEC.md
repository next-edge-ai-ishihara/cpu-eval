# Implement `branch_unit`

Implement the complete `branch_unit` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module branch_unit` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;

// ...

      VLEN: unsigned'(32),

// ...

      RVC: bit'(1),
      RVH: bit'(0),
      RVZCMT: bit'(0),

// ...

      TvalEn: bit'(0),
```

## Module declaration

```systemverilog
module branch_unit #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type branchpredict_sbe_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Virtualization mode state - CSR_REGFILE
    input logic v_i,
    // Debug mode state - CSR_REGFILE
    input logic debug_mode_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // Instruction PC - ISSUE_STAGE
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // Is zcmt instruction - ISSUE_STAGE
    input logic is_zcmt_i,
    // Instruction is compressed - ISSUE_STAGE
    input logic is_compressed_instr_i,
    // Branch unit instruction is valid - ISSUE_STAGE
    input logic branch_valid_i,
    // ALU branch compare result - ALU
    input logic branch_comp_res_i,
    // Brach unit result - ISSUE_STAGE
    output logic [CVA6Cfg.VLEN-1:0] branch_result_o,
    // Information of branch prediction - ISSUE_STAGE
    input branchpredict_sbe_t branch_predict_i,
    // Signaling that we resolved the branch - ISSUE_STAGE
    output bp_resolve_t resolved_branch_o,
    // Branch is resolved, new entries can be accepted by scoreboard - ID_STAGE
    output logic resolve_branch_o,
    // Branch exception out - TO_BE_COMPLETED
    output exception_t branch_exception_o
);
```

## Parent instantiation

```systemverilog
  // 2. Branch Unit (combinatorial)
  // we don't silence the branch unit as this is already critical and we do
  // not want to add another layer of logic
  branch_unit #(
      .CVA6Cfg(CVA6Cfg),
      .bp_resolve_t(bp_resolve_t),
      .branchpredict_sbe_t(branchpredict_sbe_t),
      .exception_t(exception_t),
      .fu_data_t(fu_data_t)
  ) branch_unit_i (
      .clk_i,
      .rst_ni,
      .v_i,
      .debug_mode_i,
      .fu_data_i         (one_cycle_data),
      .pc_i,
      .is_zcmt_i,
      .is_compressed_instr_i,
      .branch_valid_i    (|branch_valid_i),
      .branch_comp_res_i (alu_branch_res),
      .branch_result_o   (branch_result),
      .branch_predict_i,
      .resolved_branch_o (resolved_branch),
      .resolve_branch_o,
      .branch_exception_o(flu_exception_o)
  );
```

## Dependency declarations

### core/include/ariane_pkg.sv

```systemverilog
  typedef enum logic [2:0] {
    NoCF,    // No control flow prediction
    Branch,  // Branch
    Jump,    // Jump to address from immediate
    JumpR,   // Jump to address from registers
    Return   // Return Address Prediction
  } cf_t;

// ...

    // comparisons
    LTS,
    LTU,
    GES,
    GEU,
    EQ,
    NE,
    // jumps
    JALR,
    BRANCH,

// ...

  function automatic logic op_is_branch(input fu_op op);
    unique case (op) inside
      EQ, NE, LTS, GES, LTU, GEU: return 1'b1;
      default:                    return 1'b0;  // all other ops
    endcase
  endfunction
```

### core/cva6.sv

```systemverilog
    // branchpredict scoreboard entry
    // this is the struct which we will inject into the pipeline to guide the various
    // units towards the correct branch decision and resolve
    localparam type branchpredict_sbe_t = struct packed {
      cf_t                     cf;               // type of control flow prediction
      logic [CVA6Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    },

    parameter type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
      // address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
      //timing of exception, timing = 0 : break immediately or timing = 1 break immediatemy AFTER (let current instruction commit but only this one)
      logic timing;
    },

// ...

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

### core/decoder.sv

```systemverilog
    instruction_o.op                       = ariane_pkg::ADD;

// ...

        riscv::OpcodeJalr: begin
          instruction_o.fu        = CTRL_FLOW;
          instruction_o.op        = ariane_pkg::JALR;
          instruction_o.rs1       = instr.itype.rs1;
          imm_select              = IIMM;
          instruction_o.rd        = instr.itype.rd;
          is_control_flow_instr_o = 1'b1;
          // invalid jump and link register -> reserved for vector encoding
          if (instr.itype.funct3 != 3'b0) illegal_instr = 1'b1;
        end
        // Jump and link
        riscv::OpcodeJal: begin
          instruction_o.fu        = CTRL_FLOW;
          imm_select              = JIMM;
          instruction_o.rd        = instr.utype.rd;
          is_control_flow_instr_o = 1'b1;
        end
```

### core/alu.sv

```systemverilog
    always_comb begin : branch_resolve
      // set comparison by default
      case (fu_data_i.operation)
        EQ:       alu_branch_res_o = adder_z_flag;
        NE:       alu_branch_res_o = ~adder_z_flag;
        LTS, LTU: alu_branch_res_o = less;
        GES, GEU: alu_branch_res_o = ~less;
        default:  alu_branch_res_o = 1'b1;
      endcase
    end
```

## Documentation

### docs/03_cva6_design/ex_stage.md

```text
#### Branch Unit

The branch unit's purpose is to manage all kind of control flow changes
i.e.: conditional and unconditional jumps. It does so by providing an
adder to calculate the target address and some comparison logic to
decide whether to take the branch or not. Furthermore it also decides if
a branch was mis-predicted or not and reporting corrective actions to
the PC Gen stage. Corrective actions include updating the BHT and
setting the PC if necessary. As it can be that jumps are predicted on
any instruction (including instructions which are no jumps at all - see
aliasing problem in PC Gen section) it needs to know whenever an instruction gets
issued to a functional unit and monitor the branch prediction
information. If a branch was accidentally predicted on a non-branch
instruction it also takes corrective action and re-sets the PC to the
correct address (depending on whether the instruction was compressed or
not it adds PC `+ 2` or PC `+ 4`).
```

### src/rv32.adoc

```text
==== Unconditional Jumps
The jump and link (JAL) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes. The offset
is sign-extended and added to the address of the jump instruction to
form the jump target address. Jumps can therefore target a
&#177;1 MiB range. JAL stores the address of the instruction
following the jump ('pc'+4) into register _rd_. The standard software
calling convention uses 'x1' as the return address register and 'x5' as
an alternate link register.

...

The indirect jump instruction JALR (jump and link register) uses the
I-type encoding. The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero. The address of the
instruction following the jump (`pc`+4) is written to register _rd_.
Register `x0` can be used as the destination if the result is not
required.

...

==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.
```

### src/c-st-ext.adoc

```text
=== Control Transfer Instructions

RVC provides unconditional jump instructions and conditional branch
instructions. As with base RVI instructions, the offsets of all RVC
control transfer instructions are in multiples of 2 bytes.

...

C.J performs an unconditional control transfer. The offset is
sign-extended and added to the `pc` to form the jump target address. C.J
can therefore target a &#177;2 KiB range. C.J expands to
`jal x0, offset`.

C.JAL is an RV32C-only instruction that performs the same operation as
C.J, but additionally writes the address of the instruction following
the jump (`pc+2`) to the link register, `x1`. C.JAL expands to
`jal x1, offset`.

...

C.JR (jump register) performs an unconditional control transfer to the
address in register _rs1_. C.JR expands to `jalr x0, 0(rs1)`. C.JR is
valid only when _rs1_≠`x0`; the code
point with _rs1_=`x0` is reserved.

C.JALR (jump and link register) performs the same operation as C.JR, but
additionally writes the address of the instruction following the jump
(`pc`+2) to the link register, `x1`. C.JALR expands to
`jalr x1, 0(rs1)`. C.JALR is valid only when
_rs1_≠`x0`; the code point with
_rs1_=`x0` corresponds to the C.EBREAK
instruction.
```
