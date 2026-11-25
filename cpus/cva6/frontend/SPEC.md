# Implement `frontend`

Implement the complete `frontend` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module frontend` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
// ...
      RVC: bit'(1),
      RVH: bit'(0),
// ...
      MmuPresent: bit'(0),
      RVS: bit'(0),
      RVU: bit'(0),
// ...
      RASDepth: unsigned'(2),
      BTBEntries: unsigned'(0),
      BPType: config_pkg::BHT,
      BHTEntries: unsigned'(32),
      BHTHist: unsigned'(3),
// ...
      TvalEn: bit'(0),
// ...
      DebugEn: bit'(0),
```

### `core/include/build_config_pkg.sv`

```systemverilog
    cfg.FETCH_WIDTH = unsigned'(CVA6Cfg.SuperscalarEn ? 64 : 32);
    cfg.FETCH_ALIGN_BITS = $clog2(cfg.FETCH_WIDTH / 8);
    cfg.INSTR_PER_FETCH = cfg.FETCH_WIDTH / (CVA6Cfg.RVC ? 16 : 32);
    cfg.LOG2_INSTR_PER_FETCH = cfg.INSTR_PER_FETCH > 1 ? $clog2(cfg.INSTR_PER_FETCH) : 1;
```

## Package and imports

### `core/include/ariane_pkg.sv`

```systemverilog
  // ---------------
  // Fetch Stage
  // ---------------

  // leave as is (fails with >8 entries and wider fetch width)
  localparam int unsigned FETCH_FIFO_DEPTH = 4;
  localparam int unsigned FETCH_ADDR_FIFO_DEPTH = 2;

  typedef enum logic [2:0] {
    NoCF,    // No control flow prediction
    Branch,  // Branch
    Jump,    // Jump to address from immediate
    JumpR,   // Jump to address from registers
    Return   // Return Address Prediction
  } cf_t;

  typedef struct packed {
    logic valid;
    logic taken;
  } bht_prediction_t;

  typedef struct packed {
    logic       valid;
    logic [1:0] saturation_counter;
  } bht_t;
// ...
  typedef enum logic [1:0] {
    FE_NONE,
    FE_INSTR_ACCESS_FAULT,
    FE_INSTR_PAGE_FAULT,
    FE_INSTR_GUEST_PAGE_FAULT
  } frontend_exception_t;
```

## Module declaration

### `core/frontend/frontend.sv`

```systemverilog
module frontend
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type fetch_entry_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Next PC when reset - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Flush branch prediction - zero
    input logic flush_bp_i,
    // Flush requested by FENCE, mis-predict and exception - CONTROLLER
    input logic flush_i,
    // Halt requested by WFI and Accelerate port - CONTROLLER
    input logic halt_i,
    // Halt frontend - CONTROLLER (in the case of fence_i to avoid fetching an old instruction)
    input logic halt_frontend_i,
    // Set COMMIT PC as next PC requested by FENCE, CSR side-effect and Accelerate port - CONTROLLER
    input logic set_pc_commit_i,
    // COMMIT PC - COMMIT
    input logic [CVA6Cfg.VLEN-1:0] pc_commit_i,
    // Exception event - COMMIT
    input logic ex_valid_i,
    // Mispredict event and next PC - EXECUTE
    input bp_resolve_t resolved_branch_i,
    // Return from exception event - CSR
    input logic eret_i,
    // Next PC when returning from exception - CSR
    input logic [CVA6Cfg.VLEN-1:0] epc_i,
    // Next PC when jumping into exception - CSR
    input logic [CVA6Cfg.VLEN-1:0] trap_vector_base_i,
    // Debug event - CSR
    input logic set_debug_pc_i,
    // Debug mode state - CSR
    input logic debug_mode_i,
    // Handshake between CACHE and FRONTEND (fetch) - CACHES
    output icache_dreq_t icache_dreq_o,
    // Handshake between CACHE and FRONTEND (fetch) - CACHES
    input icache_drsp_t icache_dreq_i,
    // Handshake's data between fetch and decode - ID_STAGE
    output fetch_entry_t [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_o,
    // Handshake's valid between fetch and decode - ID_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_valid_o,
    // Handshake's ready between fetch and decode - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_ready_i
);
```

## Parent instantiation

### `core/cva6.sv`

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

    // cache request ports
    // I$ address translation requests
    localparam type icache_areq_t = struct packed {
      logic                    fetch_valid;      // address translation valid
      logic [CVA6Cfg.PLEN-1:0] fetch_paddr;      // physical address in
      exception_t              fetch_exception;  // exception occurred during fetch
    },
    localparam type icache_arsp_t = struct packed {
      logic                    fetch_req;    // address translation request
      logic [CVA6Cfg.VLEN-1:0] fetch_vaddr;  // virtual address out
    },

    // I$ data requests
    localparam type icache_dreq_t = struct packed {
      logic                    req;      // we request a new word
      logic                    kill_s1;  // kill the current request
      logic                    kill_s2;  // kill the last request
      logic                    spec;     // request is speculative
      logic [CVA6Cfg.VLEN-1:0] vaddr;    // 1st cycle: 12 bit index is taken for lookup
    },
    localparam type icache_drsp_t = struct packed {
      logic                                ready;  // icache is ready
      logic                                valid;  // signals a valid read
      logic [CVA6Cfg.FETCH_WIDTH-1:0]      data;   // 2+ cycle out: tag
      logic [CVA6Cfg.FETCH_USER_WIDTH-1:0] user;   // User bits
      logic [CVA6Cfg.VLEN-1:0]             vaddr;  // virtual address out
      exception_t                          ex;     // we've encountered an exception
    },

    // IF/ID Stage
    // store the decompressed instruction
    localparam type fetch_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] address;  // the address of the instructions from below
      logic [31:0] instruction;  // instruction word
      branchpredict_sbe_t     branch_predict; // this field contains branch prediction information regarding the forward branch path
      exception_t             ex;             // this field contains exceptions which might have happened earlier, e.g.: fetch exceptions
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
  frontend #(
      .CVA6Cfg(CVA6Cfg),
      .bp_resolve_t(bp_resolve_t),
      .fetch_entry_t(fetch_entry_t),
      .icache_dreq_t(icache_dreq_t),
      .icache_drsp_t(icache_drsp_t)
  ) i_frontend (
      .clk_i,
      .rst_ni,
      .boot_addr_i        (boot_addr_i[CVA6Cfg.VLEN-1:0]),
      .flush_bp_i         ((CVA6Cfg.RVU || CVA6Cfg.RVS) ? flush_ctrl_bp : 1'b0),
      // below line is not entirely correct
      .flush_i            (flush_ctrl_if),
      .halt_i             (halt_ctrl),
      .halt_frontend_i    (halt_frontend),
      .set_pc_commit_i    (set_pc_ctrl_pcgen),
      .pc_commit_i        (pc_commit),
      .ex_valid_i         (ex_commit.valid),
      .resolved_branch_i  (resolved_branch),
      .eret_i             (eret),
      .epc_i              (epc_commit_pcgen),
      .trap_vector_base_i (trap_vector_base_commit_pcgen),
      .set_debug_pc_i     (set_debug_pc),
      .debug_mode_i       (debug_mode),
      .icache_dreq_o      (icache_dreq_if_cache),
      .icache_dreq_i      (icache_dreq_cache_if),
      .fetch_entry_o      (fetch_entry_if_id),
      .fetch_entry_valid_o(fetch_valid_if_id),
      .fetch_entry_ready_i(fetch_ready_id_if)
  );
```

## Dependency declarations

### `core/instr_realign.sv`

```systemverilog
module instr_realign
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // 32-bit block is valid - CACHE
    input logic valid_i,
    // Instruction is unaligned - FRONTEND
    output logic serving_unaligned_o,
    // 32-bit block address - CACHE
    input logic [CVA6Cfg.VLEN-1:0] address_i,
    // 32-bit block - CACHE
    input logic [CVA6Cfg.FETCH_WIDTH-1:0] data_i,
    // instruction is valid - FRONTEND
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0] valid_o,
    // Instruction address - FRONTEND
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0][CVA6Cfg.VLEN-1:0] addr_o,
    // Instruction - instr_scan&instr_queue
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0][31:0] instr_o
);
  // as a maximum we support a fetch width of 64-bit, hence there can be 4 compressed instructions
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] instr_is_compressed;

  for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
    // LSB != 2'b11
    assign instr_is_compressed[i] = ~&data_i[i*16+:2];
  end

  // save the unaligned part of the instruction to this ff
  logic [15:0] unaligned_instr_d, unaligned_instr_q;
  // the last instruction was unaligned
  logic unaligned_d, unaligned_q;
  // register to save the unaligned address
  logic [CVA6Cfg.VLEN-1:0] unaligned_address_d, unaligned_address_q;
  // we have an unaligned instruction
  assign serving_unaligned_o = unaligned_q;

  // Instruction re-alignment
  if (CVA6Cfg.FETCH_WIDTH == 32) begin : realign_bp_32
    always_comb begin : re_align
      unaligned_d = unaligned_q;
      unaligned_address_d = {address_i[CVA6Cfg.VLEN-1:2], 2'b10};
      unaligned_instr_d = data_i[31:16];

      valid_o[0] = valid_i;
      instr_o[0] = unaligned_q ? {data_i[15:0], unaligned_instr_q} : data_i[31:0];
      addr_o[0] = unaligned_q ? unaligned_address_q : address_i;

      if (CVA6Cfg.INSTR_PER_FETCH != 1) begin
        valid_o[CVA6Cfg.INSTR_PER_FETCH-1] = 1'b0;
        instr_o[CVA6Cfg.INSTR_PER_FETCH-1] = '0;
        addr_o[CVA6Cfg.INSTR_PER_FETCH-1]  = {address_i[CVA6Cfg.VLEN-1:2], 2'b10};
      end
      // this instruction is compressed or the last instruction was unaligned
      if (instr_is_compressed[0] || unaligned_q) begin
        // check if this is instruction is still unaligned e.g.: it is not compressed
        // if its compressed re-set unaligned flag
        // for 32 bit we can simply check the next instruction and whether it is compressed or not
        // if it is compressed the next fetch will contain an aligned instruction
        // is instruction 1 also compressed
        // yes? -> no problem, no -> we've got an unaligned instruction
        if (instr_is_compressed[CVA6Cfg.INSTR_PER_FETCH-1] && CVA6Cfg.RVC) begin
          unaligned_d = 1'b0;
          valid_o[CVA6Cfg.INSTR_PER_FETCH-1] = valid_i;
          instr_o[CVA6Cfg.INSTR_PER_FETCH-1] = {16'b0, data_i[31:16]};
        end else begin
          // save the upper bits for next cycle
          unaligned_d = 1'b1;
          unaligned_instr_d = data_i[31:16];
          unaligned_address_d = {address_i[CVA6Cfg.VLEN-1:2], 2'b10};
        end
      end  // else -> normal fetch

      // we started to fetch on a unaligned boundary with a whole instruction -> wait until we've
      // received the next instruction
      if (valid_i && address_i[1]) begin
        // the instruction is not compressed so we can't do anything in this cycle
        if (!instr_is_compressed[0]) begin
          valid_o = '0;
          unaligned_d = 1'b1;
          unaligned_address_d = {address_i[CVA6Cfg.VLEN-1:2], 2'b10};
          unaligned_instr_d = data_i[15:0];
          // the instruction isn't compressed but only the lower is ready
        end else begin
          valid_o = {{CVA6Cfg.INSTR_PER_FETCH - 1{1'b0}}, 1'b1};
        end
      end
    end
// ...
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      unaligned_q         <= 1'b0;
      unaligned_address_q <= '0;
      unaligned_instr_q   <= '0;
    end else begin
      if (valid_i) begin
        unaligned_address_q <= unaligned_address_d;
        unaligned_instr_q   <= unaligned_instr_d;
      end

      if (flush_i) begin
        unaligned_q <= 1'b0;
      end else if (valid_i) begin
        unaligned_q <= unaligned_d;
      end
    end
  end
endmodule
```

### `core/frontend/instr_scan.sv`

```systemverilog
module instr_scan #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Instruction to be predecoded - instr_realign
    input logic [31:0] instr_i,
    // Return instruction - FRONTEND
    output logic rvi_return_o,
    // JAL instruction - FRONTEND
    output logic rvi_call_o,
    // Branch instruction - FRONTEND
    output logic rvi_branch_o,
    // JALR instruction - FRONTEND
    output logic rvi_jalr_o,
    // Unconditional jump instruction - FRONTEND
    output logic rvi_jump_o,
    // Instruction immediate - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] rvi_imm_o,
    // Branch compressed instruction - FRONTEND
    output logic rvc_branch_o,
    // Unconditional jump compressed instruction - FRONTEND
    output logic rvc_jump_o,
    // JR compressed instruction - FRONTEND
    output logic rvc_jr_o,
    // Return compressed instruction - FRONTEND
    output logic rvc_return_o,
    // JALR compressed instruction - FRONTEND
    output logic rvc_jalr_o,
    // JAL compressed instruction - FRONTEND
    output logic rvc_call_o,
    // Instruction compressed immediate - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] rvc_imm_o
);

  function automatic logic [CVA6Cfg.VLEN-1:0] uj_imm(logic [31:0] instruction_i);
    return {
      {44 + CVA6Cfg.VLEN - 64{instruction_i[31]}},
      instruction_i[19:12],
      instruction_i[20],
      instruction_i[30:21],
      1'b0
    };
  endfunction

  function automatic logic [CVA6Cfg.VLEN-1:0] sb_imm(logic [31:0] instruction_i);
    return {
      {51 + CVA6Cfg.VLEN - 64{instruction_i[31]}},
      instruction_i[31],
      instruction_i[7],
      instruction_i[30:25],
      instruction_i[11:8],
      1'b0
    };
  endfunction

  logic rv32_rvc_jal;
  assign rv32_rvc_jal = CVA6Cfg.IS_XLEN32 & ((instr_i[15:13] == riscv::OpcodeC1Jal) & (instr_i[1:0] == riscv::OpcodeC1));

  logic is_xret;
  assign is_xret = logic'(instr_i[31:30] == 2'b00) & logic'(instr_i[28:0] == 29'b10000001000000000000001110011);

  // check that rs1 is either x1 or x5 and that rd is not rs1
  assign rvi_return_o = rvi_jalr_o & ((instr_i[19:15] == 5'd1) | instr_i[19:15] == 5'd5)
                                     & (instr_i[19:15] != instr_i[11:7]);
  // Opcode is JAL[R] and destination register is either x1 or x5
  assign rvi_call_o = (rvi_jalr_o | rvi_jump_o) & ((instr_i[11:7] == 5'd1) | instr_i[11:7] == 5'd5);
  // differentiates between JAL and BRANCH opcode, JALR comes from BHT
  assign rvi_imm_o = is_xret ? '0 : (instr_i[3]) ? uj_imm(instr_i) : sb_imm(instr_i);
  assign rvi_branch_o = (instr_i[6:0] == riscv::OpcodeBranch);
  assign rvi_jalr_o = (instr_i[6:0] == riscv::OpcodeJalr);
  assign rvi_jump_o = logic'(instr_i[6:0] == riscv::OpcodeJal) | is_xret;

  // opcode JAL
  assign rvc_jump_o   = ((instr_i[15:13] == riscv::OpcodeC1J) & (instr_i[1:0] == riscv::OpcodeC1)) | rv32_rvc_jal;

  // always links to register 0
  logic is_jal_r;
  assign is_jal_r     = (instr_i[15:13] == riscv::OpcodeC2JalrMvAdd)
                        & (instr_i[11:7] != 5'b00000)
                        & (instr_i[6:2] == 5'b00000)
                        & (instr_i[1:0] == riscv::OpcodeC2);
  assign rvc_jr_o = is_jal_r & ~instr_i[12];
  // always links to register 1 e.g.: it is a jump
  assign rvc_jalr_o = is_jal_r & instr_i[12];
  assign rvc_call_o = rvc_jalr_o | rv32_rvc_jal;

  assign rvc_branch_o = ((instr_i[15:13] == riscv::OpcodeC1Beqz) | (instr_i[15:13] == riscv::OpcodeC1Bnez))
                        & (instr_i[1:0] == riscv::OpcodeC1);
  // check that rs1 is x1 or x5
  assign rvc_return_o = ((instr_i[11:7] == 5'd1) | (instr_i[11:7] == 5'd5)) & rvc_jr_o;

  // differentiates between JAL and BRANCH opcode, JALR comes from BHT
  assign rvc_imm_o    = (instr_i[14]) ? {{56+CVA6Cfg.VLEN-64{instr_i[12]}}, instr_i[6:5], instr_i[2], instr_i[11:10], instr_i[4:3], 1'b0}
                                       : {{53+CVA6Cfg.VLEN-64{instr_i[12]}}, instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], 1'b0};
endmodule
```

### `core/frontend/instr_queue.sv`

```systemverilog
module instr_queue
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fetch_entry_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // Instruction - instr_realign
    input logic [CVA6Cfg.INSTR_PER_FETCH-1:0][31:0] instr_i,
    // Instruction address - instr_realign
    input logic [CVA6Cfg.INSTR_PER_FETCH-1:0][CVA6Cfg.VLEN-1:0] addr_i,
    // Instruction is valid - instr_realign
    input logic [CVA6Cfg.INSTR_PER_FETCH-1:0] valid_i,
    // Handshake’s ready with CACHE - CACHE
    output logic ready_o,
    // Indicates instructions consumed, or popped by ID_STAGE - FRONTEND
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0] consumed_o,
    // Exception (which is page-table fault) - CACHE
    input ariane_pkg::frontend_exception_t exception_i,
    // Exception address - CACHE
    input logic [CVA6Cfg.VLEN-1:0] exception_addr_i,
    input logic [CVA6Cfg.GPLEN-1:0] exception_gpaddr_i,
    input logic [31:0] exception_tinst_i,
    input logic exception_gva_i,
    // Branch predict - FRONTEND
    input logic [CVA6Cfg.VLEN-1:0] predict_address_i,
    // Instruction predict address - FRONTEND
    input ariane_pkg::cf_t [CVA6Cfg.INSTR_PER_FETCH-1:0] cf_type_i,
    // Replay instruction because one of the FIFO was full - FRONTEND
    output logic replay_o,
    // Address at which to replay the fetch - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] replay_addr_o,
    // Handshake’s data with ID_STAGE - ID_STAGE
    output fetch_entry_t [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_o,
    // Handshake’s valid with ID_STAGE - ID_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_valid_o,
    // Handshake’s ready with ID_STAGE - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_ready_i
);

  // Calculate next index based on whether superscalar is enabled or not.
  localparam NID = CVA6Cfg.SuperscalarEn ? 1 : 0;

  typedef struct packed {
    logic [31:0]                     instr;      // instruction word
    ariane_pkg::cf_t                 cf;         // branch was taken
    ariane_pkg::frontend_exception_t ex;         // exception happened
    logic [CVA6Cfg.VLEN-1:0]         ex_vaddr;   // lower VLEN bits of tval for exception
    logic [CVA6Cfg.GPLEN-1:0]        ex_gpaddr;  // lower GPLEN bits of tval2 for exception
    logic [31:0]                     ex_tinst;   // tinst of exception
    logic                            ex_gva;
  } instr_data_t;
// ...
    always_comb begin
      idx_ds_d = '0;
      idx_is_d = '0;
      fetch_entry_o[0].instruction = instr_data_out[0].instr;
      fetch_entry_o[0].address = pc_q;

      fetch_entry_o[0].ex.valid = instr_data_out[0].ex != ariane_pkg::FE_NONE;
      if (instr_data_out[0].ex == ariane_pkg::FE_INSTR_ACCESS_FAULT) begin
        fetch_entry_o[0].ex.cause = riscv::INSTR_ACCESS_FAULT;
      end else begin
        fetch_entry_o[0].ex.cause = riscv::INSTR_PAGE_FAULT;
      end
      if (CVA6Cfg.TvalEn)
        fetch_entry_o[0].ex.tval = {{64 - CVA6Cfg.VLEN{1'b0}}, instr_data_out[0].ex_vaddr};
      else fetch_entry_o[0].ex.tval = '0;
      if (CVA6Cfg.RVH) begin
        fetch_entry_o[0].ex.tval2 = instr_data_out[0].ex_gpaddr;
        fetch_entry_o[0].ex.tinst = instr_data_out[0].ex_tinst;
        fetch_entry_o[0].ex.gva   = instr_data_out[0].ex_gva;
      end else begin
        fetch_entry_o[0].ex.tval2 = '0;
        fetch_entry_o[0].ex.tinst = '0;
        fetch_entry_o[0].ex.gva   = 1'b0;
      end

      fetch_entry_o[0].branch_predict.predict_address = address_out;
      fetch_entry_o[0].branch_predict.cf = instr_data_out[0].cf;

      pop_instr[0] = fetch_entry_valid_o[0] & fetch_entry_ready_i[0];
    end
  end

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign fetch_entry_is_cf[i] = fetch_entry_o[i].branch_predict.cf != ariane_pkg::NoCF;
    assign fetch_entry_fire[i]  = fetch_entry_valid_o[i] & fetch_entry_ready_i[i];
  end

  assign pop_address = |(fetch_entry_is_cf & fetch_entry_fire);

  // ----------------------
  // Calculate (Next) PC
  // ----------------------
  assign pc_j[0] = pc_q;
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign pc_j[i+1] = fetch_entry_is_cf[i] ? address_out : (
      pc_j[i] + ((fetch_entry_o[i].instruction[1:0] != 2'b11) ? 'd2 : 'd4)
    );
  end

  always_comb begin
    pc_d = pc_q;
    reset_address_d = flush_i ? 1'b1 : reset_address_q;

    if (fetch_entry_fire[0]) begin
      pc_d = pc_j[1];
      if (CVA6Cfg.SuperscalarEn) begin
        if (fetch_entry_fire[NID]) begin
          pc_d = pc_j[2];
        end
      end
    end
```

### `core/frontend/bht.sv`

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
  // the last bit is always zero, we don't need it for indexing
  localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
  // re-shape the branch history table
  localparam NR_ROWS = NR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
  // number of bits needed to index the row
  localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
  localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
  // number of bits we should use for prediction
  localparam PREDICTION_BITS = $clog2(NR_ROWS) + OFFSET + ROW_ADDR_BITS;

  struct packed {
    logic       valid;
    logic [1:0] saturation_counter;
  }
      bht_d[NR_ROWS-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0],
      bht_q[NR_ROWS-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0];

  logic [$clog2(NR_ROWS)-1:0] index, update_pc;
  logic [ROW_INDEX_BITS-1:0] update_row_index, update_row_index_q, check_update_row_index;

  assign index     = vpc_i[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];
  assign update_pc = bht_update_i.pc[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];
  if (CVA6Cfg.RVC) begin : gen_update_row_index
    assign update_row_index = bht_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];
  end else begin
    assign update_row_index = '0;
  end

  if (!CVA6Cfg.FpgaEn) begin : gen_asic_bht  // ASIC TARGET

    logic [1:0] saturation_counter;
    // prediction assignment
    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_bht_output
      assign bht_prediction_o[i].valid = bht_q[index][i].valid;
      assign bht_prediction_o[i].taken = bht_q[index][i].saturation_counter[1] == 1'b1;
    end

    always_comb begin : update_bht
      bht_d = bht_q;
      saturation_counter = bht_q[update_pc][update_row_index].saturation_counter;

      if ((bht_update_i.valid && CVA6Cfg.DebugEn && !debug_mode_i) || (bht_update_i.valid && !CVA6Cfg.DebugEn)) begin
        bht_d[update_pc][update_row_index].valid = 1'b1;

        if (saturation_counter == 2'b11) begin
          // we can safely decrease it
          if (!bht_update_i.taken)
            bht_d[update_pc][update_row_index].saturation_counter = saturation_counter - 1;
          // then check if it saturated in the negative regime e.g.: branch not taken
        end else if (saturation_counter == 2'b00) begin
          // we can safely increase it
          if (bht_update_i.taken)
            bht_d[update_pc][update_row_index].saturation_counter = saturation_counter + 1;
        end else begin  // otherwise we are not in any boundaries and can decrease or increase it
          if (bht_update_i.taken)
            bht_d[update_pc][update_row_index].saturation_counter = saturation_counter + 1;
          else bht_d[update_pc][update_row_index].saturation_counter = saturation_counter - 1;
        end
      end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        for (int unsigned i = 0; i < NR_ROWS; i++) begin
          for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
            bht_q[i][j] <= '0;
          end
        end
      end else begin
        // evict all entries
        if (flush_bp_i) begin
          for (int i = 0; i < NR_ROWS; i++) begin
            for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
              bht_q[i][j].valid <= 1'b0;
              bht_q[i][j].saturation_counter <= 2'b10;
            end
          end
        end else begin
          bht_q <= bht_d;
        end
      end
    end
```

### `core/frontend/ras.sv`

```systemverilog
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

  ras_t [DEPTH-1:0] stack_d, stack_q;

  assign data_o = stack_q[0];

  always_comb begin
    stack_d = stack_q;

    // push on the stack
    if (push_i) begin
      stack_d[0].ra = data_i;
      // mark the new return address as valid
      stack_d[0].valid = 1'b1;
      stack_d[DEPTH-1:1] = stack_q[DEPTH-2:0];
    end

    if (pop_i) begin
      stack_d[DEPTH-2:0] = stack_q[DEPTH-1:1];
      // we popped the value so invalidate the end of the stack
      stack_d[DEPTH-1].valid = 1'b0;
      stack_d[DEPTH-1].ra = 'b0;
    end
    // leave everything untouched and just push the latest value to the
    // top of the stack
    if (pop_i && push_i) begin
      stack_d = stack_q;
      stack_d[0].ra = data_i;
      stack_d[0].valid = 1'b1;
    end

    if (flush_bp_i) begin
      stack_d = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      stack_q <= '0;
    end else begin
      stack_q <= stack_d;
    end
  end
endmodule
```

## Related source code

### `core/controller.sv`

```systemverilog
  always_comb begin : flush_ctrl
    fence_active_d         = fence_active_q;
    fence_i_active_d       = fence_i_active_q;
    set_pc_commit_o        = 1'b0;
    flush_if_o             = 1'b0;
    flush_unissued_instr_o = 1'b0;
    flush_id_o             = 1'b0;
    flush_ex_o             = 1'b0;
    flush_dcache           = 1'b0;
    flush_icache_o         = 1'b0;
    flush_tlb_o            = 1'b0;
    flush_tlb_vvma_o       = 1'b0;
    flush_tlb_gvma_o       = 1'b0;
    flush_bp_o             = 1'b0;
    // ------------
    // Mis-predict
    // ------------
    // flush on mispredict
    if (resolved_branch_i.is_mispredict) begin
      // flush only un-issued instructions
      flush_unissued_instr_o = 1'b1;
      // and if stage
      flush_if_o             = 1'b1;
    end

    // ---------------------------------
    // FENCE
    // ---------------------------------
    if (fence_i) begin
      // this can be seen as a CSR instruction with side-effect
      set_pc_commit_o        = 1'b1;
      flush_if_o             = 1'b1;
      flush_unissued_instr_o = 1'b1;
// ...
    // ---------------------------------
    // FENCE.I
    // ---------------------------------
    if (fence_i_i) begin
      set_pc_commit_o        = 1'b1;
      flush_if_o             = 1'b1;
      flush_unissued_instr_o = 1'b1;
      flush_id_o             = 1'b1;
      flush_ex_o             = 1'b1;
      flush_icache_o         = 1'b1;
      // this is not needed in the case since we
      // have a write-through cache in this case
      // When handling fence.i, flush both caches and activate fence_i state
      if (CVA6Cfg.DcacheFlushOnFenceI) begin
        flush_dcache = 1'b1;
        fence_active_d = 1'b1;
        fence_i_active_d = 1'b1;
      end
    end
// ...
    // ---------------------------------
    // CSR side effects and accelerate port
    // ---------------------------------
    // Set PC to commit stage and flush pipeline
    if (flush_csr_i || flush_acc_i) begin
      set_pc_commit_o        = 1'b1;
      flush_if_o             = 1'b1;
      flush_unissued_instr_o = 1'b1;
      flush_id_o             = 1'b1;
      flush_ex_o             = 1'b1;
    end else if (CVA6Cfg.RVA && flush_commit_i) begin
      set_pc_commit_o        = 1'b1;
      flush_if_o             = 1'b1;
      flush_unissued_instr_o = 1'b1;
      flush_id_o             = 1'b1;
      flush_ex_o             = 1'b1;
    end

    // ---------------------------------
    // 1. Exception
    // 2. Return from exception
    // ---------------------------------
    if (ex_valid_i || eret_i || (CVA6Cfg.DebugEn && set_debug_pc_i)) begin
      // don't flush pcgen as we want to take the exception: Flush PCGen is not a flush signal
      // for the PC Gen stage but instead tells it to take the PC we gave it
      set_pc_commit_o        = 1'b0;
      flush_if_o             = 1'b1;
      flush_unissued_instr_o = 1'b1;
      flush_id_o             = 1'b1;
      flush_ex_o             = 1'b1;
      // this potentially reduces performance, but is needed
      // to suppress speculative fetches to virtual memory from
      // machine mode. TODO: remove when PMA checkers have been
      // added to the system
      flush_bp_o             = 1'b1;
    end
// ...
  // ----------------------
  // Halt Logic
  // ----------------------
  always_comb begin
    // halt the core if the fence is active
    halt_o = halt_csr_i || halt_acc_i || ((CVA6Cfg.DcacheFlushOnFence || CVA6Cfg.DcacheFlushOnFenceI) && fence_active_q);
    // Halt frontend during fence.i to synchronize ICache/DCache flushes
    halt_frontend_o = fence_i_active_q;
  end
```

### `core/cache_subsystem/cva6_icache.sv`

```systemverilog
  // pass exception through
  assign dreq_o.ex = areq_i.fetch_exception;

  // latch this in case we have to stall later on
  // make sure this is 32bit aligned
  assign vaddr_d = (dreq_o.ready & dreq_i.req) ? dreq_i.vaddr : vaddr_q;
  assign areq_o.fetch_vaddr = (vaddr_q >> CVA6Cfg.FETCH_ALIGN_BITS) << CVA6Cfg.FETCH_ALIGN_BITS;
// ...
  assign dreq_o.vaddr   = vaddr_q;
// ...
    // interfaces
    dreq_o.ready = 1'b0;
    areq_o.fetch_req = 1'b0;
    dreq_o.valid = 1'b0;
    mem_data_req_o = 1'b0;
    // performance counter
    miss_o = 1'b0;

    // handle invalidations unconditionally
    // note: invals are mutually exclusive with
    // ifills, since both arrive over the same IF
    // however, we need to make sure below that we
    // do not trigger a cache readout at the same time...
    if (mem_rtrn_vld_i && mem_rtrn_i.rtype == ICACHE_INV_REQ) begin
      inv_en = 1'b1;
    end

    unique case (state_q)
      //////////////////////////////////
      // this clears all valid bits
      FLUSH: begin
        flush_en = 1'b1;
        if (flush_done) begin
          state_d = IDLE;
          flush_d = 1'b0;
          // if the cache was not enabled set this
          cache_en_d = en_i;
        end
      end
      //////////////////////////////////
      // wait for an incoming request
      IDLE: begin
        // only enable tag comparison if cache is enabled
        cmp_en_d = cache_en_q;

        // handle pending flushes, or perform cache clear upon enable
        if (flush_d || (en_i && !cache_en_q)) begin
          state_d = FLUSH;
          // wait for incoming requests
        end else begin
          // mem requests are for sure invals here
          if (!mem_rtrn_vld_i) begin
            dreq_o.ready = 1'b1;
            // we have a new request
            if (dreq_i.req) begin
              cache_rden = 1'b1;
              state_d    = READ;
            end
          end
          if (dreq_i.kill_s1) begin
            state_d = IDLE;
          end
        end
      end
      //////////////////////////////////
      // check whether we have a hit
      // in case the cache is disabled,
      // or in case the address is NC, we
      // reuse the miss mechanism to handle
      // the request
      READ: begin
        areq_o.fetch_req = '1;
        // only enable tag comparison if cache is enabled
        cmp_en_d    = cache_en_q;
        // readout speculatively
        cache_rden  = cache_en_q;

        if (areq_i.fetch_valid && (!dreq_i.spec || ((CVA6Cfg.NonIdemPotenceEn && !addr_ni) || (!CVA6Cfg.NonIdemPotenceEn)))) begin
          // check if we have to flush
          if (flush_d) begin
            state_d = IDLE;
            // we have a hit or an exception output valid result
          end else if (((|cl_hit && cache_en_q) || areq_i.fetch_exception.valid) && !inv_q) begin
            dreq_o.valid = ~dreq_i.kill_s2;  // just don't output in this case
            state_d      = IDLE;

            // we can accept another request
            // and stay here, but only if no inval is coming in
            // note: we are not expecting ifill return packets here...
            if (!mem_rtrn_vld_i) begin
              dreq_o.ready = 1'b1;
              if (dreq_i.req) begin
                state_d = READ;
              end
            end
            // if a request is being killed at this stage,
            // we have to bail out and wait for the address translation to complete
            if (dreq_i.kill_s1) begin
              state_d = IDLE;
            end
            // we have a miss / NC transaction
          end else if (dreq_i.kill_s2) begin
            state_d = IDLE;
          end else if (!inv_q) begin
            cmp_en_d = 1'b0;
            // only count this as a miss if the cache is enabled, and
            // the address is cacheable
            // send out ifill request
            mem_data_req_o = 1'b1;
            if (mem_data_ack_i) begin
              miss_o  = ~paddr_is_nc;
              state_d = MISS;
            end
          end
          // bail out if this request is being killed (and we missed on the TLB)
        end else if (dreq_i.kill_s2 || flush_d) begin
          state_d = KILL_ATRANS;
        end
      end
// ...
      MISS: begin
        // note: this is mutually exclusive with ICACHE_INV_REQ,
        // so we do not have to check for invals here
        if (mem_rtrn_vld_i && mem_rtrn_i.rtype == ICACHE_IFILL_ACK) begin
          state_d = IDLE;
          // only return data if request is not being killed
          if (!(dreq_i.kill_s2 || flush_d)) begin
            dreq_o.valid = 1'b1;
            // only write to cache if this address is cacheable
            cache_wren   = ~paddr_is_nc;
          end
          // bail out if this request is being killed
        end else if (dreq_i.kill_s2 || flush_d) begin
          state_d = KILL_MISS;
        end
// ...
  always_comb begin
    if (cmp_en_q) begin
      dreq_o.data = cl_sel[hit_idx];
      dreq_o.user = CVA6Cfg.FETCH_USER_EN ? cl_user[hit_idx] : '0;
    end else begin
      dreq_o.data = mem_rtrn_i.data[{cl_offset_q, 3'b0}+:CVA6Cfg.FETCH_WIDTH];
      dreq_o.user = CVA6Cfg.FETCH_USER_EN ? mem_rtrn_i.user[{cl_offset_q, 3'b0}+:CVA6Cfg.FETCH_USER_WIDTH] : '0;
    end
  end
```

## Documentation

### `docs/design/design-manual/source/cva6_frontend.adoc`

```text
Description
^^^^^^^^^^^

The FRONTEND module implements two first stages of the cva6 pipeline,
PC gen and Fetch stages.

PC gen stage is responsible for generating the next program counter.
It hosts a Branch Target Buffer (BTB), a Branch History Table (BHT) and a Return Address Stack (RAS) to speculate on control flow instructions.

Fetch stage requests data to the CACHE module, realigns the data to store them in instruction queue and transmits the instructions to the DECODE module.
FRONTEND can fetch up to {instr-per-fetch} instructions per cycle, but DECODE module decodes up to {issue-width} instruction(s) per cycle.

The module is connected to:

* CACHES module provides fetched instructions to FRONTEND.
* DECODE module receives instructions from FRONTEND.
* CONTROLLER module can order to flush and to halt FRONTEND PC gen stage
* EXECUTE, CONTROLLER, CSR and COMMIT modules trigger PC jumping due to
a branch misprediction, an exception, a return from an exception, a
debug entry or a pipeline flush. They provides the PC next value.
* CSR module states about debug mode.

include::port_frontend.adoc[]

[[frontend-functionality]]
Functionality
^^^^^^^^^^^^^

[[pc-generation-stage]]
PC Generation stage
^^^^^^^^^^^^^^^^^^^

PC gen generates the next program counter. The next PC can originate from the following sources (listed in order of precedence):

* *Reset state:* At reset, the PC is assigned to the boot address.

* *Branch Prediction:* The fetched instruction is predecoded by the
instr_scan submodule. When the instruction is a control flow, three
cases are considered:
+
________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________
1.  When the instruction is a JALR which corresponds to a return (rs1 = x1 or rs1 = x5).
RAS provides next PC as a prediction.
2.  When the instruction is a JALR which *does not* correspond to a return.
If BTB (Branch Target Buffer) returns a valid address, then BTB predicts next PC.
Else JALR is not considered as a control flow instruction, which will generate a mispredict.
3.  When the instruction is a conditional branch.
If BHT (Branch History table) returns a valid address, then BHT predicts next PC.
Else the prediction depends on the PC relative jump offset sign: if sign is negative the prediction is taken, otherwise the prediction is not taken.
________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________________
+
Then the PC gen informs the Fetch stage that it performed a prediction on the PC.

* *Default:* The next {ifetch-len}-bit block is fetched.
PC Gen fetches word boundary {ifetch-len}-bits block from CACHES module.
And the fetch stage identifies the instructions from the {ifetch-len}-bits blocks.

* *Mispredict:* Misprediction are feedbacked by EX_STAGE module.
In any case we need to correct our action and start fetching from the correct address.

* *Replay instruction fetch:* When the instruction queue is full, the instr_queue submodule asks the fetch replay and provides the address to be replayed.
...
* *Exception/Interrupt:* If an exception is triggered by CSR_REGISTER, next PC takes the value of the trap vector base address CSR.
...
* *Pipeline starting fetching from COMMIT PC:* When the commit stage is halted by a WFI instruction or when the pipeline has been flushed due to CSR change, next PC takes the value of the PC coming from the COMMIT submodule.
As CSR instructions do not exist in a compressed form, PC is unconditionally incremented by 4.
...
All program counters are logical addressed.
...
[[fetch-stage]]
Fetch Stage
^^^^^^^^^^^

Fetch stage controls the CACHE module by a handshaking protocol.
Fetched data is a {ifetch-len}-bit block with a word-aligned address.
A granted fetch is processed by the instr_realign submodule to produce instructions.
Then instructions are pushed into an internal instruction FIFO called instruction queue (instr_queue submodule).
This submodule stores the instructions with its associated address and sends them to the DECODE module.

Before sending the instructions to the DECODE stage, the frontend calculates a prediction address in case of a JUMP or Branch. This predicted address is sent to the DECODE stage along with the instruction and its fetch address.
The prediction address is not valid if there is no prediction.
Instructions following a predicted taken control flow instruction are dropped.
...
Memory can feedback potential exceptions which can be bus errors, invalid accesses or instruction page faults.
The FRONTEND transmits the exception from CACHES to DECODE.
...
[[instr_realign-submodule]]
Instr_realign submodule
+++++++++++++++++++++++

The {ifetch-len}-bit aligned block coming from the CACHE module enters the instr_realign submodule.
This submodule extracts the instructions from the {ifetch-len}-bit blocks.
Based on the fetch address and the fetched data, the instr_realign module extracts the valid instructions to be sent to the queue.
It is possible to fetch up to {instr-per-fetch} instructions per cycle when C extension is used.
A not-compressed instruction can be misaligned on the block size, interleaved with two cache blocks.
In that case, two cache accesses are needed to get the whole instruction.
The instr_realign submodule provides up to {instr-per-fetch} instructions per cycle when compressed extension is enabled, else one instruction per cycle.
Incomplete instruction is stored in instr_realign submodule until its second half is fetched.
...
ifeval::[{Superscalar} == false]

|==========================================================
|*Address[2:1]*	|*Incomplete Access* |*32-16*	|*16-0*
.5+^.^|0

.3+^.^|0
2.+^.^|I
|C
|C
|UI
|C

.2+^.^|1
|UI
|UI
|C
|UI

.2+^.^|1
.2+^.^|__
|* |C
|* |UI

|==========================================================

endif::[]

The Instr_realign can be flushed when the frontend requests the cache to kill the incoming instruction, in this case the incomplete instruction is deleted.
...
[[instr_queue-submodule]]
Instr_queue submodule
+++++++++++++++++++++

The instr_queue receives multiple instructions from instr_realign submodule to create a valid stream to be executed.
Frontend pushes instructions and all related information into the FIFO for storage, including details needed in case of a misprediction or exception: the instructions themselves, instruction control flow type, exception, exception address, and predicted address.
DECODE pops them when decode stage is ready and indicates to the FRONTEND the instruction has been consumed.


The instruction queue contains two FIFOs: one for instructions and one for addresses, which stores addresses in case of a prediction.
The instruction FIFO can hold up to 4×{instr-per-fetch} instructions, while the address FIFO can hold up to 2 addresses.
If the instruction FIFO is full, a replay request is sent to inform the fetch mechanism to replay the fetch.
If the address FIFO is full and there is a prediction, a replay request is sent to inform the fetch mechanism to replay the fetch, even if the instruction FIFO is not full.

The instruction queue can be flushed by the flush signal coming from the CONTROLLER.


include::port_instr_queue.adoc[]

[[instr_scan-submodule]]
Instr_scan submodule
++++++++++++++++++++

As compressed extension is enabled, {instr-per-fetch} instr_scan are instantiated to handle up to {instr-per-fetch} instructions per cycle.

Each instr_scan submodule pre-decodes the fetched instructions coming from the instr_realign module, also calculate the immediate, instructions could be compressed or not.
The instr_scan submodule is a flow controller which provides the instruction type: branch, jump, return, jalr, imm, call or others.
These outputs are used by the branch prediction feature.

include::port_instr_scan.adoc[]
...
ifeval::[{BHTEntries} > 0]
[[bht-branch-history-table-submodule]]
BHT (Branch History Table) submodule
++++++++++++++++++++++++++++++++++++

The BHT is implemented as a memory which is composed of {BHTEntries} entries.
The BHT is a two-dimensional table:

*	The first dimension represents the access address, with a length equal to `{BHTEntries} / {instr-per-fetch}`.
*	The second dimension represents the row index, with a length equal to `{instr-per-fetch}`.

In the case of branch prediction, the BHT uses only part of the virtual address to get the value of the saturation counter.
In the case of a valid misprediction, the BHT uses only part of the misprediction address to access the BHT table and update the saturation counter.

`UPPER_ADDRESS_INDEX = $clog2(BHTDepth) + ((RVC == 1) ? 1 : 2)`

`LOWER_ADDRESS_INDEX = (RVC == 1) ? 1 : 2 + $clog2(INSTR_PER_FETCH)`

`ACCESS_ADDRESS = PC/MISPREDICT_ADDRESS [ UPPER_ADDRESS_INDEX : LOWER_ADDRESS_INDEX ]`

The lower address bits of the virtual address point to the memory entry.

`UPPER_ADDRESS_INDEX = (RVC == 1) ? 1 : 2 +  $clog2(INSTR_PER_FETCH)`

`LOWER_ADDRESS_INDEX = (RVC == 1) ? 1 : 2 +    $clog2(INSTR_PER_FETCH)`

`ACCESS_INDEX = PC/MISPREDICT_ADDRESS [ UPPER_ADDRESS_INDEX : LOWER_ADDRESS_INDEX]`

_Two distinct branches with different addresses can share the same BHT entry if they have the same ACCESS_ADDRESS._

Each BHT entry contains a two-bit saturating counter and a valid bit.
On reset, the counters are set to 0 (strongly not taken) and the valid bits are cleared.
When a branch instruction is resolved by the EX_STAGE module, the valid bit is set and the counter is updated.
The two bit counter is updated by the successive execution of the instructions as shown in the following figure.
...
When a branch instruction is pre-decoded by instr_scan submodule, the BHT valids whether the PC address is inside the BHT and provides the taken or not prediction.
The prediction is the most significant bit from the counter, where 1 means "taken".

When the Execute stage processes a branch instruction, it sends the branch status (whether it's taken or not) to the Frontend to update the BHT table
...
The BHT is never flushed.
...
ifeval::[{BTBEntries} == 0]
There is no BTB in {ohg-config}.
As a consequence, no valid address is returned from BTB.
...
ifeval::[{RASDepth} > 0]
[[ras-return-address-stack-submodule]]
RAS (Return Address Stack) submodule
++++++++++++++++++++++++++++++++++++

RAS is implemented as a LIFO which is composed of {RASDepth} entries.

When a "call" JAL instruction (rd = x1 or x5) is added to the instruction queue, the PC of the instruction following the JAL instruction is pushed into the stack.

When a "ret" JALR instruction (rs1 = x1 or x5, and rd != rs1) is added to the instruction queue, the predicted return address is popped from the stack.
If the predicted return address is wrong due for instance to speculation or RAS depth limitation, a mispredict will be generated.

The RAS is never flushed.
```
