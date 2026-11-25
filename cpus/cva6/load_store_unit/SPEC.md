# Implement `load_store_unit`

Implement the complete `load_store_unit` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module load_store_unit` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
// ...
      NrLoadBufEntries: unsigned'(2),
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
      RVA: bit'(0),
// ...
      RVV: bit'(0),
// ...
      RVH: bit'(0),
// ...
      NrScoreboardEntries: unsigned'(4),
// ...
      MmuPresent: bit'(0),
// ...
      TvalEn: bit'(0),
// ...
      NrPMPEntries: unsigned'(0),
// ...
      MaxOutstandingStores: unsigned'(7),
// ...
      Sdtrig: bit'(0),
// ...
      NrLoadPipeRegs: int'(0),
      NrStorePipeRegs: int'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
    int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;
// ...
    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = IS_XLEN32 ? 34 : 56;
    cfg.GPLEN = IS_XLEN32 ? 34 : 41;
    cfg.IS_XLEN32 = IS_XLEN32;
    cfg.IS_XLEN64 = IS_XLEN64;
    cfg.XLEN_ALIGN_BYTES = $clog2(CVA6Cfg.XLEN / 8);
    cfg.ASID_WIDTH = IS_XLEN64 ? 16 : 1;
    cfg.VMID_WIDTH = IS_XLEN64 ? 14 : 1;
// ...
    cfg.NR_SB_ENTRIES = CVA6Cfg.NrScoreboardEntries;
    cfg.TRANS_ID_BITS = $clog2(CVA6Cfg.NrScoreboardEntries);
```

## Module declaration

```systemverilog
module load_store_unit
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type acc_mmu_req_t = logic,
    parameter type acc_mmu_resp_t = logic,
    parameter type cbo_t = logic,
    parameter type bp_resolve_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic flush_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic stall_st_pending_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic no_st_pending_o,
    // Shared TLB is busy processing a multi-cycle flush
    output logic shared_tlb_flush_busy_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic amo_valid_commit_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic [31:0] tinst_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // Load Store Unit is ready - ISSUE_STAGE
    output logic lsu_ready_o,
    // Load Store Unit instruction is valid - ISSUE_STAGE
    input logic lsu_valid_i,
    // Signals speculative loads for non-idempotent load handling - EX_STAGE
    input logic speculative_load_i,

    // Load transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] load_trans_id_o,
    // Load result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] load_result_o,
    // Load result is valid - ISSUE_STAGE
    output logic load_valid_o,
    // Load exception - ISSUE_STAGE
    output exception_t load_exception_o,

    // Store transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] store_trans_id_o,
    // Store result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] store_result_o,
    // Store result is valid - ISSUE_STAGE
    output logic store_valid_o,
    // Store exception - ISSUE_STAGE
    output exception_t store_exception_o,

    // Commit the first pending store - TO_BE_COMPLETED
    input logic commit_i,
    // Commit queue is ready to accept another commit request - TO_BE_COMPLETED
    output logic commit_ready_o,
    // Commit transaction ID - TO_BE_COMPLETED
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_i,
    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // Enable virtual memory translation - TO_BE_COMPLETED
    input logic enable_translation_i,
    // Enable G-Stage memory translation - TO_BE_COMPLETED
    input logic enable_g_translation_i,
    // Enable virtual memory translation for load/stores - TO_BE_COMPLETED
    input logic en_ld_st_translation_i,
    // Enable G-Stage memory translation for load/stores - TO_BE_COMPLETED
    input logic en_ld_st_g_translation_i,

    // Accelerator request for CVA6's MMU
    input  acc_mmu_req_t  acc_mmu_req_i,
    output acc_mmu_resp_t acc_mmu_resp_o,

    // Instruction cache input request - CACHES
    input  icache_arsp_t icache_areq_i,
    // Instruction cache output request - CACHES
    output icache_areq_t icache_areq_o,

    // Current privilege mode - CSR_REGFILE
    input  riscv::priv_lvl_t                          priv_lvl_i,
    // Data Endian mode - CSR_REGFILE
    input  logic                                      mbe_i,
    // Current virtualization mode - CSR_REGFILE
    input  logic                                      v_i,
    // Privilege level at which load and stores should happen - CSR_REGFILE
    input  riscv::priv_lvl_t                          ld_st_priv_lvl_i,
    // Virtualization mode at which load and stores should happen - CSR_REGFILE
    input  logic                                      ld_st_v_i,
    // Instruction is a hyp load/store - CSR_REGFILE
    output logic                                      csr_hs_ld_st_inst_o,
    // Supervisor User Memory - CSR_REGFILE
    input  logic                                      sum_i,
    // Virtual Supervisor User Memory - CSR_REGFILE
    input  logic                                      vs_sum_i,
    // Make Executable Readable - CSR_REGFILE
    input  logic                                      mxr_i,
    // Make Executable Readable Virtual Supervisor - CSR_REGFILE
    input  logic                                      vmxr_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.PPNW-1:0] satp_ppn_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.ASID_WIDTH-1:0] asid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.PPNW-1:0] vsatp_ppn_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.PPNW-1:0] hgatp_ppn_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.VMID_WIDTH-1:0] vmid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.ASID_WIDTH-1:0] asid_to_be_flushed_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.VMID_WIDTH-1:0] vmid_to_be_flushed_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.VLEN-1:0] vaddr_to_be_flushed_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [     CVA6Cfg.GPLEN-1:0] gpaddr_to_be_flushed_i,
    // TLB flush - CONTROLLER
    input  logic                                      flush_tlb_i,
    input  logic                                      flush_tlb_vvma_i,
    input  logic                                      flush_tlb_gvma_i,
    // Instruction TLB miss - PERF_COUNTERS
    output logic                                      itlb_miss_o,
    // Data TLB miss - PERF_COUNTERS
    output logic                                      dtlb_miss_o,

    // Data cache request output - CACHES
    input  dcache_req_o_t [2:0] dcache_req_ports_i,
    // Data cache request input - CACHES
    output dcache_req_i_t [2:0] dcache_req_ports_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic                dcache_wbuffer_empty_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic                dcache_wbuffer_not_ni_i,
    // AMO request - CACHE
    output amo_req_t            amo_req_o,
    // AMO response - CACHE
    input  amo_resp_t           amo_resp_i,

    // PMP configuration - CSR_REGFILE
    input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0]                   pmpcfg_i,
    // PMP address - CSR_REGFILE
    input logic           [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_i,

    // RVFI information - RVFI
    output lsu_ctrl_t                    rvfi_lsu_ctrl_o,
    // RVFI information - RVFI
    output logic      [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    //Trigger module communication
    input  logic                         sdtrig_load_stall_i,
    input  logic                         sdtrig_load_cancel_i,
    input  logic      [CVA6Cfg.XLEN-1:0] sdtrig_load_action_i,
    input  logic                         sdtrig_store_stall_i,
    input  logic      [CVA6Cfg.XLEN-1:0] sdtrig_store_action_i
);
```

## Parent instantiation

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

  load_store_unit #(
      .CVA6Cfg   (CVA6Cfg),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .exception_t(exception_t),
      .fu_data_t (fu_data_t),
      .icache_areq_t(icache_areq_t),
      .icache_arsp_t(icache_arsp_t),
      .icache_dreq_t(icache_dreq_t),
      .icache_drsp_t(icache_drsp_t),
      .lsu_ctrl_t(lsu_ctrl_t),
      .cbo_t(cbo_t),
      .acc_mmu_req_t(acc_mmu_req_t),
      .acc_mmu_resp_t(acc_mmu_resp_t),
      .bp_resolve_t(bp_resolve_t)
  ) lsu_i (
      .clk_i,
      .rst_ni,
      .flush_i,
      .stall_st_pending_i,
      .no_st_pending_o,
      .shared_tlb_flush_busy_o(shared_tlb_flush_busy_o),
      .fu_data_i              (lsu_data),
      .lsu_ready_o,
      .lsu_valid_i            (|lsu_valid_i),
      .speculative_load_i     (speculative_load),
      .load_trans_id_o,
      .load_result_o,
      .load_valid_o,
      .load_exception_o,
      .store_trans_id_o,
      .store_result_o,
      .store_valid_o,
      .store_exception_o,
      .commit_i               (lsu_commit_i),
      .commit_ready_o         (lsu_commit_ready_o),
      .commit_tran_id_i,
      .resolved_branch_i      (resolved_branch),
      .enable_translation_i,
      .enable_g_translation_i,
      .en_ld_st_translation_i,
      .en_ld_st_g_translation_i,
      .acc_mmu_req_i,
      .acc_mmu_resp_o,
      .icache_areq_i,
      .icache_areq_o,
      .priv_lvl_i,
      .mbe_i,
      .v_i,
      .ld_st_priv_lvl_i,
      .ld_st_v_i,
      .csr_hs_ld_st_inst_o,
      .sum_i,
      .vs_sum_i,
      .mxr_i,
      .vmxr_i,
      .satp_ppn_i,
      .vsatp_ppn_i,
      .hgatp_ppn_i,
      .asid_i,
      .vs_asid_i,
      .asid_to_be_flushed_i   (asid_to_be_flushed),
      .vmid_i,
      .vmid_to_be_flushed_i   (vmid_to_be_flushed),
      .vaddr_to_be_flushed_i  (vaddr_to_be_flushed),
      .gpaddr_to_be_flushed_i (gpaddr_to_be_flushed),
      .flush_tlb_i,
      .flush_tlb_vvma_i,
      .flush_tlb_gvma_i,
      .itlb_miss_o,
      .dtlb_miss_o,
      .dcache_req_ports_i,
      .dcache_req_ports_o,
      .dcache_wbuffer_empty_i,
      .dcache_wbuffer_not_ni_i,
      .amo_valid_commit_i,
      .amo_req_o,
      .amo_resp_i,
      .tinst_i                (lsu_tinst),
      .pmpcfg_i,
      .pmpaddr_i,
      .rvfi_lsu_ctrl_o,
      .rvfi_mem_paddr_o,
      //Trigger module command signals
      .sdtrig_load_stall_i    (sdtrig_load_stall_i),
      .sdtrig_load_cancel_i   (sdtrig_load_cancel_i),
      .sdtrig_load_action_i   (sdtrig_load_action_i),
      .sdtrig_store_stall_i   (sdtrig_store_stall_i),
      .sdtrig_store_action_i  (sdtrig_store_action_i)
  );

  //Sdtrig
  if(CVA6Cfg.SdtrigMcontrol6Store || CVA6Cfg.SdtrigMcontrol6LoadAddr || CVA6Cfg.SdtrigMcontrol6LoadData) begin
    assign sdtrig_lsu_inputs_operand_a_o = CVA6Cfg.VLEN'(lsu_data.operand_a + lsu_data.imm);
    assign sdtrig_lsu_inputs_operand_c_o = lsu_data.operand_b;
    assign sdtrig_lsu_inputs_we_o = lsu_data.fu == STORE;
    assign sdtrig_lsu_inputs_valid_o = |lsu_valid_i;
  end else begin
    assign sdtrig_lsu_inputs_operand_a_o = '0;
    assign sdtrig_lsu_inputs_operand_c_o = '0;
    assign sdtrig_lsu_inputs_we_o = '0;
    assign sdtrig_lsu_inputs_valid_o = '0;
  end
```

### core/cva6.sv

```systemverilog
  // D$ request
  // Since ZCMT is only enabled for embedded class so MMU should be disabled.
  // Cache port 0 is being utilized in implicit read access in ZCMT extension.
  if (CVA6Cfg.RVZCMT & ~(CVA6Cfg.MmuPresent)) begin
    assign dcache_req_to_cache[0] = dcache_req_ports_id_cache;
  end else begin
    assign dcache_req_to_cache[0] = dcache_req_ports_ex_cache[0];
  end
  assign dcache_req_to_cache[1] = dcache_req_ports_ex_cache[1];
  assign dcache_req_to_cache[2] = dcache_req_ports_acc_cache[0];
  assign dcache_req_to_cache[3] = dcache_req_ports_ex_cache[2].data_req ? dcache_req_ports_ex_cache [2] :
                                                                          dcache_req_ports_acc_cache[1];

  // D$ response
  // Since ZCMT is only enabled for embedded class so MMU should be disabled.
  // Cache port 0 is being utilized in implicit read access in ZCMT extension.
  if (CVA6Cfg.RVZCMT & ~(CVA6Cfg.MmuPresent)) begin
    assign dcache_req_ports_cache_id = dcache_req_from_cache[0];
    assign dcache_req_ports_cache_ex[0] = '0;
  end else begin
    assign dcache_req_ports_cache_ex[0] = dcache_req_from_cache[0];
    assign dcache_req_ports_cache_id = '0;
  end
  assign dcache_req_ports_cache_ex[1]  = dcache_req_from_cache[1];
  assign dcache_req_ports_cache_acc[0] = dcache_req_from_cache[2];
  always_comb begin : gen_dcache_req_store_data_gnt
    dcache_req_ports_cache_ex[2]  = dcache_req_from_cache[3];
    dcache_req_ports_cache_acc[1] = dcache_req_from_cache[3];

    // Set gnt signal
    dcache_req_ports_cache_ex[2].data_gnt &= dcache_req_ports_ex_cache[2].data_req;
    dcache_req_ports_cache_acc[1].data_gnt &= !dcache_req_ports_ex_cache[2].data_req;
  end
```

### core/cache_subsystem/cva6_hpdcache_subsystem.sv

```systemverilog
  //    0: Page-Table Walk (PTW)
  //    1: Load unit
  //    2: Accelerator load
  //    3: Store/AMO
```

## Dependency declarations

### core/cva6.sv

```systemverilog
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


    localparam type cbo_t = logic [7:0],

    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },
// ...
    // D$ data requests
    localparam type dcache_req_i_t = struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
      cbo_t                                  cbo_op;
    },

    localparam type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
      logic                                 data_error;
    },
```

### core/include/ariane_pkg.sv

```systemverilog
  typedef enum logic [3:0] {
    NONE,       // 0
    LOAD,       // 1
    STORE,      // 2
    ALU,        // 3
// ...
  function automatic logic [3:0] be_gen_32(logic [1:0] addr, logic [1:0] size);
    case (size)
      2'b10: begin
        return 4'b1111;
      end
      2'b01: begin
        case (addr[1:0])
          2'b00:   return 4'b0011;
          2'b01:   return 4'b0110;
          2'b10:   return 4'b1100;
          default: ;  // Do nothing
        endcase
      end
      2'b00: begin
        case (addr[1:0])
          2'b00: return 4'b0001;
          2'b01: return 4'b0010;
          2'b10: return 4'b0100;
          2'b11: return 4'b1000;
        endcase
      end
      default: return 4'b0;
    endcase
    return 4'b0;
  endfunction

  // ----------------------
  // Extract Bytes from Op
  // ----------------------
  function automatic logic [1:0] extract_transfer_size(fu_op op);
    case (op)
      LD, HLV_D, SD, HSV_D, FLD, FSD,
            AMO_LRD,   AMO_SCD,
            AMO_SWAPD, AMO_ADDD,
            AMO_ANDD,  AMO_ORD,
            AMO_XORD,  AMO_MAXD,
            AMO_MAXDU, AMO_MIND,
            AMO_MINDU: begin
        return 2'b11;
      end
      LW, LWU, HLV_W, HLV_WU, HLVX_WU,
            SW, HSV_W, FLW, FSW,
            AMO_LRW,   AMO_SCW,
            AMO_SWAPW, AMO_ADDW,
            AMO_ANDW,  AMO_ORW,
            AMO_XORW,  AMO_MAXW,
            AMO_MAXWU, AMO_MINW,
            AMO_MINWU: begin
        return 2'b10;
      end
      LH, LHU, HLV_H, HLV_HU, HLVX_HU, SH, HSV_H, FLH, FSH: return 2'b01;
      LB, LBU, HLV_B, HLV_BU, SB, HSV_B, FLB, FSB:          return 2'b00;
      CBO_CLEAN, CBO_FLUSH, CBO_INVAL:                      return 2'b00;
      default:                                              return 2'b11;
    endcase
  endfunction
```

### core/include/riscv_pkg.sv

```systemverilog
package riscv;
// ...
  localparam logic [XLEN-1:0] LD_ADDR_MISALIGNED = 4;
  localparam logic [XLEN-1:0] LD_ACCESS_FAULT = 5;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ST_ADDR_MISALIGNED = 6;
```

### core/pmp/src/pmp_data_if.sv

```systemverilog
module pmp_data_if
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter type                   icache_areq_t = logic,
    parameter type                   exception_t   = logic
) (
    input logic clk_i,
    input logic rst_ni,
    // IF interface
    input icache_areq_t icache_areq_i,
    output icache_areq_t icache_areq_o,
    input [CVA6Cfg.VLEN-1:0] icache_fetch_vaddr_i,  // virtual address for tval only
    // LSU interface
    // this is a more minimalistic interface because the actual addressing logic is handled
    // in the LSU as we distinguish load and stores, what we do here is simple address translation
    input logic lsu_valid_i,  // request lsu access
    input logic [CVA6Cfg.PLEN-1:0] lsu_paddr_i,  // physical address in
    input logic [CVA6Cfg.VLEN-1:0] lsu_vaddr_i,  // virtual address in, for tval only
    input exception_t lsu_exception_i,  // lsu exception coming from MMU, or misaligned exception
    input logic lsu_is_store_i,  // the translation is requested by a store
    output logic lsu_valid_o,  // translation is valid
    output logic [CVA6Cfg.PLEN-1:0] lsu_paddr_o,  // translated address
    output exception_t lsu_exception_o,  // address translation threw an exception
    // General control signals
    input riscv::priv_lvl_t priv_lvl_i,
    input logic v_i,
    input riscv::priv_lvl_t ld_st_priv_lvl_i,
    input logic ld_st_v_i,
    // PMP
    input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg_i,
    input logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_i
);
```

### core/load_unit.sv

```systemverilog
module load_unit
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type lsu_ctrl_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Flush signal - CONTROLLER
    input logic flush_i,
    // Load request is valid - LSU_BYPASS
    input logic valid_i,
    // Load request input - LSU_BYPASS
    input lsu_ctrl_t lsu_ctrl_i,
    // Pop the load request from the LSU bypass FIFO - LSU_BYPASS
    output logic pop_ld_o,
    // Load unit result is valid - ISSUE_STAGE
    output logic valid_o,
    // Load transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_o,
    // Load result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] result_o,
    // Load exception - ISSUE_STAGE
    output exception_t ex_o,
    // Data Endian mode - CSR_REGFILE
    input logic mbe_i,
    // Request address translation - MMU
    output logic translation_req_o,
    // Virtual address - MMU
    output logic [CVA6Cfg.VLEN-1:0] vaddr_o,
    // Transformed trap instruction out - MMU
    output logic [31:0] tinst_o,
    // Instruction is a hyp load store instruction - MMU
    output logic hs_ld_st_inst_o,
    // Hyp load store with execute permissions - MMU
    output logic hlvx_inst_o,
    // Physical address - MMU
    input logic [CVA6Cfg.PLEN-1:0] paddr_i,
    // Excepted which appears before load - MMU
    input exception_t ex_i,
    // Data TLB hit - MMU
    input logic dtlb_hit_i,
    // Physical page number from the DTLB - MMU
    input logic [CVA6Cfg.PPNW-1:0] dtlb_ppn_i,
    // Page offset for address checking - STORE_UNIT
    output logic [11:0] page_offset_o,
    // Indicates if the page offset matches a store unit entry - STORE_UNIT
    input logic page_offset_matches_i,
    // Store buffer is empty - STORE_UNIT
    input logic store_buffer_empty_i,
    // Transaction ID of the committing instruction - COMMIT_STAGE
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_i,
    // Data cache request out - CACHES
    input dcache_req_o_t req_port_i,
    // Data cache request in - CACHES
    output dcache_req_i_t req_port_o,
    // Presence of non-idempotent operations in the D$ write buffer - CACHES
    input logic dcache_wbuffer_not_ni_i,

    //Trigger module
    input logic sdtrig_load_stall_i,
    input logic sdtrig_load_cancel_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_load_action_i
);
```

### core/store_unit.sv

```systemverilog
module store_unit
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type cbo_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Flush - CONTROLLER
    input logic flush_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic stall_st_pending_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic no_st_pending_o,
    // Store buffer is empty - TO_BE_COMPLETED
    output logic store_buffer_empty_o,
    // Store instruction is valid - ISSUE_STAGE
    input logic valid_i,
    // Data input - ISSUE_STAGE
    input lsu_ctrl_t lsu_ctrl_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic pop_st_o,
    // Instruction commit - TO_BE_COMPLETED
    input logic commit_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic commit_ready_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic amo_valid_commit_i,
    // Data Endian mode - CSR_REGFILE
    input logic mbe_i,
    // Store result is valid - ISSUE_STAGE
    output logic valid_o,
    // Transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_o,
    // Store result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] result_o,
    // Store exception output - TO_BE_COMPLETED
    output exception_t ex_o,
    // Address translation request - TO_BE_COMPLETED
    output logic translation_req_o,
    // Virtual address - TO_BE_COMPLETED
    output logic [CVA6Cfg.VLEN-1:0] vaddr_o,
    // RVFI information - RVFI
    output logic [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    // Transformed trap instruction out - TO_BE_COMPLETED
    output logic [31:0] tinst_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic hs_ld_st_inst_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic hlvx_inst_o,
    // Physical address - TO_BE_COMPLETED
    input logic [CVA6Cfg.PLEN-1:0] paddr_i,
    // Exception raised before store - TO_BE_COMPLETED
    input exception_t ex_i,
    // Data TLB hit - lsu
    input logic dtlb_hit_i,
    // Address to be checked - load_unit
    input logic [11:0] page_offset_i,
    // Address check result - load_unit
    output logic page_offset_matches_o,
    // AMO request - CACHES
    output amo_req_t amo_req_o,
    // AMO response - CACHES
    input amo_resp_t amo_resp_i,
    // Data cache request - CACHES
    input dcache_req_o_t req_port_i,
    // Data cache response - CACHES
    output dcache_req_i_t req_port_o,
    //Trigger module
    input logic sdtrig_store_stall_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_store_action_i
);
```

### core/lsu_bypass.sv

```systemverilog
// ------------------
// LSU Control
// ------------------
// The LSU consists of two independent blocks which share a common address translation block.
// One block is the load unit, the other one is the store unit. They will signal their readiness
// with separate signals. If they are not ready the LSU control should keep the last applied signals stable.
// Furthermore it can be the case that another request for one of the two store units arrives in which case
// the LSU control should sample it and store it for later application to the units. It does so, by storing it in a
// two element FIFO. This is necessary as we only know very late in the cycle whether the load/store will succeed (address check,
// TLB hit mainly). So we better unconditionally allow another request to arrive and store this request in case we need to.
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

### vendor/pulp-platform/common_cells/src/shift_reg.sv

```systemverilog
// Description: Simple shift register for arbitrary depth and types

module shift_reg #(
    parameter type dtype         = logic,
    parameter int unsigned Depth = 1
)(
    input  logic clk_i,    // Clock
    input  logic rst_ni,   // Asynchronous reset active low
    input  dtype d_i,
    output dtype d_o
);
```

### core/cva6_mmu/cva6_mmu.sv

```systemverilog
    // LSU interface
    // this is a more minimalistic interface because the actual addressing logic is handled
    // in the LSU as we distinguish load and stores, what we do here is simple address translation
    input exception_t misaligned_ex_i,
    input logic lsu_req_i,  // request address translation
    input logic [CVA6Cfg.VLEN-1:0] lsu_vaddr_i,  // virtual address in
    input logic [31:0] lsu_tinst_i,  // transformed instruction in
    input logic lsu_is_store_i,  // the translation is requested by a store
    output logic csr_hs_ld_st_inst_o,  // hyp load store instruction
    // if we need to walk the page table we can't grant in the same cycle
    // Cycle 0
    output logic lsu_dtlb_hit_o,  // sent in same cycle as the request if translation hits in DTLB
    output logic [CVA6Cfg.PPNW-1:0] lsu_dtlb_ppn_o,  // ppn (send same cycle as hit)
    // Cycle 1
    output logic lsu_valid_o,  // translation is valid
    output logic [CVA6Cfg.PLEN-1:0] lsu_paddr_o,  // translated address
    output exception_t lsu_exception_o,  // address translation threw an exception
```

## Documentation

### docs/design/design-manual/source/cva6_execute.adoc

```text
load_store_unit (LSU)
+++++++++++++++++++++

The load store module interfaces with the data cache (D$) to manage the load and store operations.

The LSU does not handle misaligned accesses.
Misaligned accesses are double word accesses which are not aligned to a 64-bit boundary, word accesses which are not aligned to a 32-bit boundary and half word accesses which are not aligned on 16-bit boundary.
If the LSU encounters a misaligned load or store, it throws a misaligned exception.
...
The store_unit module manages the data store operations.

As stores can be speculative, the store instructions need to be committed by ISSUE_STAGE module before possibly altering the processor state.
Store buffer keeps track of store requests.
Outstanding store instructions (which are speculative) are differentiated from committed stores.
When ISSUE_STAGE module commits a store instruction, outstanding stores
become committed.

When commit buffer is not empty, the buffer automatically tries to write the oldest store to the data cache.

Furthermore, the store_unit module provides information to the load_unit to know if an outstanding store matches addresses with a load.
...
[[load_unit]]
====== load_unit

The load unit module manages the data load operations.

Before issuing a load, the load unit needs to check the store buffer for potential aliasing.
It stalls until it can satisfy the current request. This means:

* Two loads to the same address are allowed.
* Two stores to the same address are allowed.
* A store after a load to the same address is allowed.
* A load after a store to the same address can only be processed if the store has already been sent to the cache i.e there is no forwarding.

After the check of the store buffer, a read request is sent to the D$ with the index field of the address (1).
The load unit stalls until the D$ acknowledges this request (2).
In the next cycle, the tag field of the address is sent to the D$ (3).
If the load request address is non-idempotent, it stalls until the write buffer of the D$ is empty of non-idempotent requests and the store buffer is empty.
It also stalls until the incoming load instruction is the next instruction to be committed.
When the D$ allows the read of the data, the data is sent to the load unit and the load instruction can be committed (4).
...
[[lsu_bypass]]
====== lsu_bypass

The LSU bypass is a FIFO which keeps instructions from the issue stage when the store unit or the load unit are not available immediately.
```

### docs/design/design-manual/source/mmu.adoc

```text
When address translation is not enabled, the physical address is
immediately checked against Physical Memory Protections (PMPs). If there
is a request from LSU, no misaligned exception, and PMPs are violated,
it results in an access fault corresponding to the request being
indicated.
```
