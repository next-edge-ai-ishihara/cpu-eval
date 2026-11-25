# Implement `cva6`

Implement the complete `cva6` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cva6` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
package cva6_config_pkg;

  localparam CVA6ConfigXlen = 32;

  localparam CVA6ConfigRvfiTrace = 1;

  localparam CVA6ConfigAxiIdWidth = 4;  // axi_pkg.sv
  localparam CVA6ConfigAxiAddrWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigAxiDataWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigDataUserWidth = 32;  // axi_pkg.sv

  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
      ALUBypass: bit'(0),
      NrCommitPorts: unsigned'(1),
      AxiAddrWidth: unsigned'(CVA6ConfigAxiAddrWidth),
      AxiDataWidth: unsigned'(CVA6ConfigAxiDataWidth),
      AxiIdWidth: unsigned'(CVA6ConfigAxiIdWidth),
      AxiUserWidth: unsigned'(CVA6ConfigDataUserWidth),
      MemTidWidth: unsigned'(CVA6ConfigAxiIdWidth),
      NrLoadBufEntries: unsigned'(2),
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
      RVA: bit'(0),
      RVB: bit'(1),
      ZKN: bit'(0),
      RVV: bit'(0),
      RVC: bit'(1),
      RVH: bit'(0),
      RVZCMT: bit'(0),
      RVZCB: bit'(1),
      RVZCMP: bit'(0),
      XFVec: bit'(0),
      CvxifEn: bit'(1),
      CoproType: config_pkg::COPRO_EXAMPLE,
      RVZiCond: bit'(0),
      RVZiCbom: bit'(0),
      RVZicntr: bit'(0),
      RVZihpm: bit'(0),
      NrScoreboardEntries: unsigned'(4),
      PerfCounterEn: bit'(0),
      MmuPresent: bit'(0),
      RVS: bit'(0),
      RVU: bit'(0),
      SoftwareInterruptEn: bit'(0),
      HaltAddress: 64'h800,
      ExceptionAddress: 64'h808,
      RASDepth: unsigned'(2),
      BTBEntries: unsigned'(0),
      BPType: config_pkg::BHT,
      BHTEntries: unsigned'(32),
      BHTHist: unsigned'(3),
      DmBaseAddress: 64'h0,
      TvalEn: bit'(0),
      DirectVecOnly: bit'(1),
      NrPMPEntries: unsigned'(0),
      PMPCfgRstVal: {64{64'h0}},
      PMPAddrRstVal: {64{64'h0}},
      PMPEntryReadOnly: 64'd0,
      PMPNapotEn: bit'(0),
      NOCType: config_pkg::NOC_TYPE_AXI4_ATOP,
      NrNonIdempotentRules: unsigned'(0),
      NonIdempotentAddrBase: 1024'({64'b0, 64'b0}),
      NonIdempotentLength: 1024'({64'b0, 64'b0}),
      NrExecuteRegionRules: unsigned'(0),
      ExecuteRegionAddrBase: 1024'({64'h8000_0000, 64'h1_0000, 64'h0}),
      ExecuteRegionLength: 1024'({64'h40000000, 64'h10000, 64'h1000}),
      NrCachedRegionRules: unsigned'(1),
      CachedRegionAddrBase: 1024'({64'h8000_0000}),
      CachedRegionLength: 1024'({64'h40000000}),
      MaxOutstandingStores: unsigned'(7),
      DebugEn: bit'(0),
      Sdtrig: bit'(0),
      SdtrigMcontrol6: bit'(0),
      SdtrigMcontrol6ExecAddr: bit'(0),
      SdtrigMcontrol6ExecData: bit'(0),
      SdtrigMcontrol6Store: bit'(0),
      SdtrigMcontrol6LoadAddr: bit'(0),
      SdtrigMcontrol6LoadData: bit'(0),
      SdtrigIcount: bit'(0),
      SdtrigEtrigger: bit'(0),
      SdtrigItrigger: bit'(0),
      SdtrigNrTriggers: int'(4),
      SdtrigTriggerChaining: bit'(0),
      SdtrigSupportedActions: {2{2'b01}},
      SdtrigSupportedMatch: {10{10'b00_0000_0001}},
      SdtrigSupportTextra: bit'(0),
      AxiBurstWriteEn: bit'(0),
      IcacheByteSize: unsigned'(2048),
      IcacheSetAssoc: unsigned'(2),
      IcacheLineWidth: unsigned'(128),
      DCacheType: config_pkg::HPDCACHE_WT,
      DcacheByteSize: unsigned'(2028),
      DcacheSetAssoc: unsigned'(2),
      DcacheLineWidth: unsigned'(128),
      DcacheFlushOnFence: bit'(0),
      DcacheFlushOnFenceI: bit'(0),
      DcacheInvalidateOnFlush: bit'(0),
      DcacheEccEnable: bit'(0),
      DcacheEccScrubberEnable: bit'(0),
      DataUserEn: unsigned'(1),
      WtDcacheWbufDepth: int'(8),
      FetchUserWidth: unsigned'(32),
      FetchUserEn: unsigned'(1),
      InstrTlbEntries: int'(2),
      DataTlbEntries: int'(2),
      UseSharedTlb: bit'(1),
      SvnapotEn: bit'(0),
      SharedTlbDepth: int'(64),
      NrLoadPipeRegs: int'(0),
      NrStorePipeRegs: int'(0),
      DcacheIdWidth: int'(1)
  };
```

### `core/include/build_config_pkg.sv`

```systemverilog
  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
    bit NSX = CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8 | CVA6Cfg.XFVec;  // Are non-standard extensions present?
    int unsigned FLen = CVA6Cfg.RVD ? 64 :  // D ext.
    CVA6Cfg.RVF ? 32 :  // F ext.
    CVA6Cfg.XF16 ? 16 :  // Xf16 ext.
    CVA6Cfg.XF16ALT ? 16 :  // Xf16alt ext.
    CVA6Cfg.XF8 ? 8 :  // Xf8 ext.
    1;  // Unused in case of no FP

    // Transprecision floating-point extensions configuration
    bit RVFVec     = CVA6Cfg.RVF     & CVA6Cfg.XFVec & FLen>32; // FP32 vectors available if vectors and larger fmt enabled
    bit XF16Vec    = CVA6Cfg.XF16    & CVA6Cfg.XFVec & FLen>16; // FP16 vectors available if vectors and larger fmt enabled
    bit XF16ALTVec = CVA6Cfg.XF16ALT & CVA6Cfg.XFVec & FLen>16; // FP16ALT vectors available if vectors and larger fmt enabled
    bit XF8Vec     = CVA6Cfg.XF8     & CVA6Cfg.XFVec & FLen>8;  // FP8 vectors available if vectors and larger fmt enabled

    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
    int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;

    int unsigned ICACHE_INDEX_WIDTH = $clog2(CVA6Cfg.IcacheByteSize / CVA6Cfg.IcacheSetAssoc);
    int unsigned DCACHE_INDEX_WIDTH = $clog2(CVA6Cfg.DcacheByteSize / CVA6Cfg.DcacheSetAssoc);
    int unsigned DCACHE_OFFSET_WIDTH = $clog2(CVA6Cfg.DcacheLineWidth / 8);

    // MMU
    int unsigned VpnLen = IS_XLEN64 ? (CVA6Cfg.RVH ? 29 : 27) : 20;
    int unsigned PtLevels = IS_XLEN64 ? 3 : 2;

    config_pkg::cva6_cfg_t cfg;

    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = IS_XLEN32 ? 34 : 56;
    cfg.GPLEN = IS_XLEN32 ? 34 : 41;
    cfg.IS_XLEN32 = IS_XLEN32;
    cfg.IS_XLEN64 = IS_XLEN64;
    cfg.XLEN_ALIGN_BYTES = $clog2(CVA6Cfg.XLEN / 8);
    cfg.ASID_WIDTH = IS_XLEN64 ? 16 : 1;
    cfg.VMID_WIDTH = IS_XLEN64 ? 14 : 1;

    cfg.FpgaEn = CVA6Cfg.FpgaEn;
    cfg.FpgaAlteraEn = CVA6Cfg.FpgaAlteraEn;
    cfg.TechnoCut = CVA6Cfg.TechnoCut;

    cfg.SuperscalarEn = CVA6Cfg.SuperscalarEn;
    cfg.NrCommitPorts = CVA6Cfg.SuperscalarEn ? unsigned'(2) : CVA6Cfg.NrCommitPorts;
    cfg.NrIssuePorts = unsigned'(CVA6Cfg.SuperscalarEn ? 2 : 1);
    cfg.SpeculativeSb = CVA6Cfg.SuperscalarEn;

    cfg.NrALUs = CVA6Cfg.SuperscalarEn ? unsigned'(2) : unsigned'(1);
    cfg.ALUBypass = CVA6Cfg.SuperscalarEn ? bit'(CVA6Cfg.ALUBypass) : bit'(0);

    cfg.NrLoadPipeRegs = CVA6Cfg.NrLoadPipeRegs;
    cfg.NrStorePipeRegs = CVA6Cfg.NrStorePipeRegs;
    cfg.AxiAddrWidth = CVA6Cfg.AxiAddrWidth;
    cfg.AxiDataWidth = CVA6Cfg.AxiDataWidth;
    cfg.AxiIdWidth = CVA6Cfg.AxiIdWidth;
    cfg.AxiUserWidth = CVA6Cfg.AxiUserWidth;
    cfg.MEM_TID_WIDTH = CVA6Cfg.MemTidWidth;
    cfg.NrLoadBufEntries = CVA6Cfg.NrLoadBufEntries;
    cfg.RVF = CVA6Cfg.RVF;
    cfg.RVD = CVA6Cfg.RVD;
    cfg.XF16 = CVA6Cfg.XF16;
    cfg.XF16ALT = CVA6Cfg.XF16ALT;
    cfg.XF8 = CVA6Cfg.XF8;
    cfg.RVA = CVA6Cfg.RVA;
    cfg.RVB = CVA6Cfg.RVB || CVA6Cfg.ZKN;  // ZKN requires RVB
    cfg.ZKN = CVA6Cfg.ZKN;
    cfg.RVV = CVA6Cfg.RVV;
    cfg.RVC = CVA6Cfg.RVC;
    cfg.RVH = CVA6Cfg.RVH;
    cfg.RVZCB = CVA6Cfg.RVZCB;
    cfg.RVZCMT = CVA6Cfg.RVZCMT;
    cfg.RVZCMP = CVA6Cfg.RVZCMP;
    cfg.XFVec = CVA6Cfg.XFVec;
    cfg.CvxifEn = CVA6Cfg.CvxifEn;
    cfg.CoproType = CVA6Cfg.CoproType;
```

## Package and imports

### `core/include/ariane_pkg.sv`

```systemverilog
  // Index of writeback ports
  localparam FLU_WB = 0;
  localparam STORE_WB = 1;
  localparam LOAD_WB = 2;
  localparam FPU_WB = 3;
  localparam ACC_WB = 4;
  localparam X_WB = 4;
```

### `core/include/cvxif_types.svh`

```systemverilog
`define CVXIF_REQ_T(Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t) struct packed { \
    logic              compressed_valid; \
    x_compressed_req_t compressed_req; \
    logic              issue_valid; \
    x_issue_req_t      issue_req; \
    logic              register_valid; \
    x_register_t       register; \
    logic              commit_valid; \
    x_commit_t         commit; \
    logic              result_ready; \
}

`define CVXIF_RESP_T(Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t) struct packed { \
    logic               compressed_ready; \
    x_compressed_resp_t compressed_resp; \
    logic               issue_ready; \
    x_issue_resp_t      issue_resp; \
    logic               register_ready; \
    logic               result_valid; \
    x_result_t          result; \
}
```

## Module declaration

### `core/cva6.sv`

```systemverilog
module cva6
  import ariane_pkg::*;
#(
    // CVA6 config
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
        cva6_config_pkg::cva6_cfg
    ),

    // RVFI PROBES
    parameter type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg),
    parameter type rvfi_probes_csr_t = `RVFI_PROBES_CSR_T(CVA6Cfg),
    parameter type rvfi_probes_t = struct packed {
      rvfi_probes_csr_t   csr;
      rvfi_probes_instr_t instr;
    },

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
    //JVT struct{base,mode}
    localparam type jvt_t = struct packed {
      logic [CVA6Cfg.XLEN-7:0] base;
      logic [5:0] mode;
    },

    // ID/EX/WB Stage
    localparam type scoreboard_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] pc;  // PC of instruction
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;      // this can potentially be simplified, we could index the scoreboard entry
      // with the transaction id in any case make the width more generic
      fu_t fu;  // functional unit to use
      fu_op op;  // operation to perform in each functional unit
      logic [REG_ADDR_SIZE-1:0] rs1;  // register source address 1
      logic [REG_ADDR_SIZE-1:0] rs2;  // register source address 2
      logic [REG_ADDR_SIZE-1:0] rd;  // register destination address
      logic [CVA6Cfg.XLEN-1:0] result;  // for unfinished instructions this field also holds the immediate,
      // for unfinished floating-point that are partly encoded in rs2, this field also holds rs2
      // for unfinished floating-point fused operations (FMADD, FMSUB, FNMADD, FNMSUB)
      // this field holds the address of the third operand from the floating-point register file
      logic valid;  // is the result valid
      logic use_imm;  // should we use the immediate as operand b?
      logic use_zimm;  // use zimm as operand a
      logic use_pc;  // set if we need to use the PC as operand a, PC from exception
      exception_t ex;  // exception has occurred
      branchpredict_sbe_t bp;  // branch predict scoreboard data structure
      logic                     is_compressed; // signals a compressed instructions, we need this information at the commit stage if
                                               // we want jump accordingly e.g.: +4, +2
      logic is_macro_instr;  // is an instruction executed as predefined sequence of instructions called macro definition
      logic is_last_macro_instr;  // is last decoded 32bit instruction of macro definition
      logic is_double_rd_macro_instr;  // is double move decoded 32bit instruction of macro definition
      logic vfp;  // is this a vector floating-point instruction?
      logic is_zcmt;  //is a zcmt instruction
    },
    localparam type writeback_t = struct packed {
      logic valid;  // wb data is valid
      logic [CVA6Cfg.XLEN-1:0] data;  //wb data
      logic ex_valid;  // exception from WB
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;  //transaction ID
    },

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

    // All information needed to determine whether we need to associate an interrupt
    // with the corresponding instruction or not.
    localparam type irq_ctrl_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] mie;
      logic [CVA6Cfg.XLEN-1:0] mip;
      logic [CVA6Cfg.XLEN-1:0] mideleg;
      logic [CVA6Cfg.XLEN-1:0] hideleg;
      logic                    sie;
      logic                    global_enable;
    },

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

    localparam type icache_req_t = struct packed {
      logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
      logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
      logic nc;  // noncacheable
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },
    localparam type icache_rtrn_t = struct packed {
      wt_cache_pkg::icache_in_t rtype;  // see definitions above
      logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] data;  // full cache line width
      logic [CVA6Cfg.ICACHE_USER_LINE_WIDTH-1:0] user;  // user bits
      struct packed {
        logic                                      vld;  // invalidate only affected way
        logic                                      all;  // invalidate all ways
        logic [CVA6Cfg.ICACHE_INDEX_WIDTH-1:0]     idx;  // physical address to invalidate
        logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to invalidate
      } inv;  // invalidation vector
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },

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

    // Accelerator - CVA6
    parameter type accelerator_req_t  = logic,
    parameter type accelerator_resp_t = logic,

    // Accelerator - CVA6's MMU
    parameter type acc_mmu_req_t  = logic,
    parameter type acc_mmu_resp_t = logic,

    // AXI types
    parameter type axi_ar_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_aw_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type axi_w_chan_t = struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    },
    parameter type b_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type r_chan_t = struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    },
    parameter type noc_req_t = struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    },
    parameter type noc_resp_t = struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    },
    //
    parameter type acc_cfg_t = logic,
    parameter acc_cfg_t AccCfg = '0,
    // CVXIF Types
    parameter type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    parameter type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    parameter type id_t = `ID_T(CVA6Cfg),
    parameter type hartid_t = `HARTID_T(CVA6Cfg),
    parameter type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    parameter type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
    parameter type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    parameter type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    parameter type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_result_t = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
    parameter type cvxif_req_t =
    `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t),
    parameter type cvxif_resp_t =
    `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t)
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Reset boot address - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Hard ID reflected as CSR - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Inter-processor (async) interrupt - SUBSYSTEM
    input logic ipi_i,
    // Timer (async) interrupt - SUBSYSTEM
    input logic time_irq_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Probes to build RVFI, can be left open when not used - RVFI
    output rvfi_probes_t rvfi_probes_o,
    // CVXIF request - SUBSYSTEM
    output cvxif_req_t cvxif_req_o,
    // CVXIF response - SUBSYSTEM
    input cvxif_resp_t cvxif_resp_i,
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input noc_resp_t noc_resp_i
);
```

## Parent instantiation

### `corev_apu/src/ariane.sv`

```systemverilog
  cva6 #(
    .CVA6Cfg ( CVA6Cfg ),
    .rvfi_probes_instr_t ( rvfi_probes_instr_t ),
    .rvfi_probes_csr_t ( rvfi_probes_csr_t ),
    .rvfi_probes_t ( rvfi_probes_t ),
    .axi_ar_chan_t (axi_ar_chan_t),
    .axi_aw_chan_t (axi_aw_chan_t),
    .axi_w_chan_t (axi_w_chan_t),
    .noc_req_t (noc_req_t),
    .noc_resp_t (noc_resp_t),
    .readregflags_t (readregflags_t),
    .writeregflags_t (writeregflags_t),
    .id_t (id_t),
    .hartid_t (hartid_t),
    .x_compressed_req_t (x_compressed_req_t),
    .x_compressed_resp_t (x_compressed_resp_t),
    .x_issue_req_t (x_issue_req_t),
    .x_issue_resp_t (x_issue_resp_t),
    .x_register_t (x_register_t),
    .x_commit_t (x_commit_t),
    .x_result_t (x_result_t),
    .cvxif_req_t (cvxif_req_t),
    .cvxif_resp_t (cvxif_resp_t)
  ) i_cva6 (
    .clk_i                ( clk_i                     ),
    .rst_ni               ( rst_ni                    ),
    .boot_addr_i          ( boot_addr_i               ),
    .hart_id_i            ( hart_id_i                 ),
    .irq_i                ( irq_i                     ),
    .ipi_i                ( ipi_i                     ),
    .time_irq_i           ( time_irq_i                ),
    .debug_req_i          ( debug_req_i               ),
    .rvfi_probes_o        ( rvfi_probes_o             ),
    .cvxif_req_o          ( cvxif_req                 ),
    .cvxif_resp_i         ( cvxif_resp                ),
    .noc_req_o            ( noc_req_o                 ),
    .noc_resp_i           ( noc_resp_i                )
  );
```

## Dependency declarations

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

### `core/id_stage.sv`

```systemverilog
module id_stage #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type branchpredict_sbe_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type fetch_entry_t = logic,
    parameter type jvt_t = logic,
    parameter type irq_ctrl_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type interrupts_t = logic,
    parameter interrupts_t INTERRUPTS = '0,
    parameter type x_compressed_req_t = logic,
    parameter type x_compressed_resp_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Handshake's data between fetch and decode - FRONTEND
    input fetch_entry_t [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_i,
    // Handshake's valid between fetch and decode - FRONTEND
    input logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_valid_i,
    // Handshake's ready between fetch and decode - FRONTEND
    output logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_ready_o,
    // Handshake's data between decode and issue - ISSUE
    output scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_entry_o,
    output scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_entry_o_prev,
    // Instruction value - ISSUE
    output logic [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_o,
    // Handshake's valid between decode and issue - ISSUE
    output logic [CVA6Cfg.NrIssuePorts-1:0] issue_entry_valid_o,
    // Report if instruction is a control flow instruction - ISSUE
    output logic [CVA6Cfg.NrIssuePorts-1:0] is_ctrl_flow_o,
    // Handshake's acknowledge between decode and issue - ISSUE
    input logic [CVA6Cfg.NrIssuePorts-1:0] issue_instr_ack_i,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0] rvfi_is_compressed_o,
    // Current privilege level - CSR_REGFILE
    input riscv::priv_lvl_t priv_lvl_i,
    // Current virtualization mode - CSR_REGFILE
    input logic v_i,
    // Floating point extension status - CSR_REGFILE
    input riscv::xs_t fs_i,
    // Floating point extension virtual status - CSR_REGFILE
    input riscv::xs_t vfs_i,
    // Floating point dynamic rounding mode - CSR_REGFILE
    input logic [2:0] frm_i,
    // Vector extension status - CSR_REGFILE
    input riscv::xs_t vs_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Interrupt control status - CSR_REGFILE
    input irq_ctrl_t irq_ctrl_i,
    // Is current mode debug ? - CSR_REGFILE
    input logic debug_mode_i,
    // Trap virtual memory - CSR_REGFILE
    input logic tvm_i,
    // Timeout wait - CSR_REGFILE
    input logic tw_i,
    // Virtual timeout wait - CSR_REGFILE
    input logic vtw_i,
    // Trap sret - CSR_REGFILE
    input logic tsr_i,
    // Hypervisor user mode - CSR_REGFILE
    input logic hu_i,
    // machine-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t mcbie_i,
    // supervisor-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t scbie_i,
    // hypervisor-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t hcbie_i,
    // machine-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic mcbcfe_i,
    // supervisor-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic scbcfe_i,
    // hypervisor-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic hcbcfe_i,
    // CVXIF Compressed interface
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    input logic compressed_ready_i,
    //JVT
    input jvt_t jvt_i,
    input x_compressed_resp_t compressed_resp_i,
    output logic compressed_valid_o,
    output x_compressed_req_t compressed_req_o,
    // mcontrol6 address match breakpoint exc. generation request from trigg. module
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_decoder_action_i[CVA6Cfg.NrIssuePorts],
    // Data cache request ouput - CACHE
    input dcache_req_o_t dcache_req_ports_i,
    // Data cache request input - CACHE
    output dcache_req_i_t dcache_req_ports_o
);
```

### `core/issue_stage.sv`

```systemverilog
module issue_stage
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type branchpredict_sbe_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type writeback_t = logic,
    parameter type x_issue_req_t = logic,
    parameter type x_issue_resp_t = logic,
    parameter type x_register_t = logic,
    parameter type x_commit_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Is scoreboard full - PERF_COUNTERS
    output logic sb_full_o,
    // Prevent from issuing - CONTROLLER
    input logic flush_unissued_instr_i,
    // Flush whole scoreboard - CONTROLLER
    input logic flush_i,
    // Stall inserted by Acc dispatcher - ACC_DISPATCHER
    input logic stall_i,
    // Handshake's data with decode stage - ID_STAGE
    input scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_i,
    input scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_i_prev,
    // instruction value - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_i,
    // Handshake's valid with decode stage - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_valid_i,
    // Is instruction a control flow instruction - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] is_ctrl_flow_i,
    // Handshake's acknowledge with decode stage - ID_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_ack_o,
    // rs1 forwarding - EX_STAGE
    output [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs1_forwarding_o,
    // rs2 forwarding - EX_STAGE
    output [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs2_forwarding_o,
    // FU data useful to execute instruction - EX_STAGE
    output fu_data_t [CVA6Cfg.NrIssuePorts-1:0] fu_data_o,
    // ALU to ALU bypass control - EX_STAGE
    output alu_bypass_t alu_bypass_o,
    // Program Counter - EX_STAGE
    output logic [CVA6Cfg.VLEN-1:0] pc_o,
    // Is zcmt instruction - EX_STAGE
    output logic is_zcmt_o,
    // Is compressed instruction - EX_STAGE
    output logic is_compressed_instr_o,
    // Transformed trap instruction - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0][31:0] tinst_o,
    // Fixed Latency Unit is ready - EX_STAGE
    input logic flu_ready_i,
    // ALU output is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] alu_valid_o,
    // AES output is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] aes_valid_o,
    // Branch unit is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] branch_valid_o,
    // Information of branch prediction - EX_STAGE
    output branchpredict_sbe_t branch_predict_o,
    // Signaling that we resolved the branch - EX_STAGE
    input logic resolve_branch_i,
    // Load store unit FU is ready - EX_STAGE
    input logic lsu_ready_i,
    // Load store unit FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] lsu_valid_o,
    // Mult FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] mult_valid_o,
    // FPU FU is ready - EX_STAGE
    input logic fpu_ready_i,
    // FPU FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_o,
    // FPU fmt field - EX_STAGE
    output logic [1:0] fpu_fmt_o,
    // FPU rm field - EX_STAGE
    output logic [2:0] fpu_rm_o,
    // FPU early valid - EX_STAGE
    input logic fpu_early_valid_i,
    // ALU2 FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] alu2_valid_o,
    // CSR is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] csr_valid_o,
    // CVXIF FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] xfu_valid_o,
    // CVXIF is FU ready - EX_STAGE
    input logic xfu_ready_i,
    // CVXIF offloader instruction value - EX_STAGE
    output logic [31:0] x_off_instr_o,
    // CVA6 Hart ID - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // CVXIF Issue interface - EX_STAGE
    input logic x_issue_ready_i,
    // TO_BE_COMPLETED - EX_STAGE
    input x_issue_resp_t x_issue_resp_i,
    // TO_BE_COMPLETED - EX_STAGE
    output logic x_issue_valid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output x_issue_req_t x_issue_req_o,
    // CVXIF Register interface - EX_STAGE
    input logic x_register_ready_i,
    // TO_BE_COMPLETED - EX_STAGE
    output logic x_register_valid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output x_register_t x_register_o,
    // CVXIF Commit interface - EX_STAGE
    output logic x_commit_valid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output x_commit_t x_commit_o,
    // CVXIF Transaction rejected -> instruction is illegal - EX_STAGE
    output logic x_transaction_rejected_o,
    // Issue scoreboard entry - ACC_DISPATCHER
    output scoreboard_entry_t issue_instr_o,
    // TO_BE_COMPLETED - ACC_DISPATCHER
    output logic issue_instr_hs_o,
    // Transaction ID - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_i,
    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // Results to write back - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_i,
    // exception from execute stage or CVXIF - EX_STAGE
    input exception_t [CVA6Cfg.NrWbPorts-1:0] ex_ex_i,
    // Indicates valid results - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0] wt_valid_i,
    // CVXIF write enable - EX_STAGE
    input logic x_we_i,
    // CVXIF destination register - EX_STAGE
    input logic [4:0] x_rd_i,
    // Destination register in register file - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0][4:0] waddr_i,
    // Value to write to register file - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_i,
    // GPR write enable - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] we_gpr_i,
    // FPR write enable - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] we_fpr_i,
    // Instructions to commit - COMMIT_STAGE
    output scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_o,
    // Instruction is cancelled - COMMIT_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] commit_drop_o,
    // Commit acknowledge - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_i,
    // Issue stall - PERF_COUNTERS
    output logic stall_issue_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_issue_pointer_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_commit_pointer_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs1_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs2_o,
    // Original instruction bits for AES
    output logic [5:0] orig_instr_aes_bits
);
```

### `core/ex_stage.sv`

```systemverilog
module ex_stage
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type branchpredict_sbe_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type x_result_t = logic,
    parameter type acc_mmu_req_t = logic,
    parameter type acc_mmu_resp_t = logic,
    parameter type cbo_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // Debug mode is enabled - CSR_REGFILE
    input logic debug_mode_i,
    // rs1 forwarding - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs1_forwarding_i,
    // rs2 forwarding - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs2_forwarding_i,
    // FU data useful to execute instruction - ISSUE_STAGE
    input fu_data_t [CVA6Cfg.NrIssuePorts-1:0] fu_data_i,
    // ALU to ALU bypass control - ISSUE_STAGE
    input alu_bypass_t alu_bypass_i,
    // PC of the current instruction - ISSUE_STAGE
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // Is_zcmt instruction - ISSUE_STAGE
    input logic is_zcmt_i,
    // Report whether instruction is compressed - ISSUE_STAGE
    input logic is_compressed_instr_i,
    // Report instruction encoding - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] tinst_i,
    // Fixed Latency Unit result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] flu_result_o,
    // ID of the scoreboard entry at which a=to write back - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] flu_trans_id_o,
    // Fixed Latency Unit exception - ISSUE_STAGE
    output exception_t flu_exception_o,
    // FLU is ready - ISSUE_STAGE
    output logic flu_ready_o,
    // FLU result is valid - ISSUE_STAGE
    output logic flu_valid_o,
    // ALU instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] alu_valid_i,
    // AES instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] aes_valid_i,
    // Branch unit instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] branch_valid_i,
    // Information of branch prediction - ISSUE_STAGE
    input branchpredict_sbe_t branch_predict_i,
    // The branch engine uses the write back from the ALU - several_modules
    output bp_resolve_t resolved_branch_o,
    // Signaling that we resolved the branch - ISSUE_STAGE
    output logic resolve_branch_o,
    // CSR instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] csr_valid_i,
    // CSR address to write - COMMIT_STAGE
    output logic [11:0] csr_addr_o,
    // CSR commit - COMMIT_STAGE
    input logic csr_commit_i,
    // MULT instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] mult_valid_i,
    // LSU is ready - ISSUE_STAGE
    output logic lsu_ready_o,
    // LSU instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] lsu_valid_i,
    // Load result is valid - ISSUE_STAGE
    output logic load_valid_o,
    // Load result valid - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] load_result_o,
    // Load instruction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] load_trans_id_o,
    // Exception generated by load instruction - ISSUE_STAGE
    output exception_t load_exception_o,
    // Store result is valid - ISSUe_STAGE
    output logic store_valid_o,
    // Store result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] store_result_o,
    // Store instruction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] store_trans_id_o,
    // Exception generated by store instruction - ISSUE_STAGE
    output exception_t store_exception_o,
    // LSU commit - COMMIT_STAGE
    input logic lsu_commit_i,
    // Commit queue ready to accept another commit request - COMMIT_STAGE
    output logic lsu_commit_ready_o,
    // Commit transaction ID - COMMIT_STAGE
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_i,
    // TO_BE_COMPLETED - ACC_DISPATCHER
    input logic stall_st_pending_i,
    // TO_BE_COMPLETED - COMMIT_STAGE
    output logic no_st_pending_o,
    // Shared TLB is busy processing a multi-cycle flush
    output logic shared_tlb_flush_busy_o,
    // Atomic result is valid - COMMIT_STAGE
    input logic amo_valid_commit_i,
    // FU is ready - ISSUE_STAGE
    output logic fpu_ready_o,
    // FPU instruction is ready - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_i,
    // FPU format - ISSUE_STAGE
    input logic [1:0] fpu_fmt_i,
    // FPU rm - ISSUE_STAGE
    input logic [2:0] fpu_rm_i,
    // FPU frm - ISSUE_STAGE
    input logic [2:0] fpu_frm_i,
    // FPU precision control - CSR_REGFILE
    input logic [6:0] fpu_prec_i,
    // FPU transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] fpu_trans_id_o,
    // FPU result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] fpu_result_o,
    // FPU valid - ISSUE_STAGE
    output logic fpu_valid_o,
    // FPU exception - ISSUE_STAGE
    output exception_t fpu_exception_o,
    // FPU early valid - ISSUE_STAGE
    output logic fpu_early_valid_o,
    // ALU2 instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] alu2_valid_i,
    // CVXIF instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] x_valid_i,
    // CVXIF is ready - ISSUE_STAGE
    output logic x_ready_o,
    // CVXIF undecoded instruction
    input logic [31:0] x_off_instr_i,
    // CVXIF transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_o,
    // CVXIF exception - ISSUE_STAGE
    output exception_t x_exception_o,
    // CVXIF result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] x_result_o,
    // CVXIF result valid - ISSUE_STAGE
    output logic x_valid_o,
    // CVXIF write enable - ISSUE_STAGE
    output logic x_we_o,
    // CVXIF destination register - ISSUE_STAGE
    output logic [4:0] x_rd_o,
    // CVXIF Result interface - SUBSYSTEM
    input logic x_result_valid_i,
    input x_result_t x_result_i,
    output logic x_result_ready_o,
    // CVXIF Issue transaction rejected -> illegal instruction - ISSUE_STAGE
    input logic x_transaction_rejected_i,
    // accelerate port result is valid - ACC_DISPATCHER
    input logic acc_valid_i,
    // Accelerator MMU access
    input acc_mmu_req_t acc_mmu_req_i,
    output acc_mmu_resp_t acc_mmu_resp_o,
    // Enable virtual memory translation - CSR_REGFILE
    input logic enable_translation_i,
    // Enable G-Stage memory translation - CSR_REGFILE
    input logic enable_g_translation_i,
    // Enable virtual memory translation for load/stores - CSR_REGFILE
    input logic en_ld_st_translation_i,
    // Enable G-Stage memory translation for load/stores - CSR_REGFILE
    input logic en_ld_st_g_translation_i,
    // Flush TLB - CONTROLLER
    input logic flush_tlb_i,
    input logic flush_tlb_vvma_i,
    input logic flush_tlb_gvma_i,
    // Privilege mode - CSR_REGFILE
    input riscv::priv_lvl_t priv_lvl_i,
    // Data endianness - CSR REGFILE
    input logic mbe_i,
    // Virtualization mode - CSR_REGFILE
    input logic v_i,
    // Privilege level at which load and stores should happen - CSR_REGFILE
    input riscv::priv_lvl_t ld_st_priv_lvl_i,
    // Virtualization mode at which load and stores should happen - CSR_REGFILE
    input logic ld_st_v_i,
    // Instruction is hypervisor load/store - CSR_REGFILE
    output logic csr_hs_ld_st_inst_o,
    // Supervisor user memory - CSR_REGFILE
    input logic sum_i,
    // Virtual Supervisor user memory - CSR_REGFILE
    input logic vs_sum_i,
    // Make executable readable - CSR_REGFILE
    input logic mxr_i,
    // Make executable readable Virtual Supervisor - CSR_REGFILE
    input logic vmxr_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.PPNW-1:0] satp_ppn_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.ASID_WIDTH-1:0] asid_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.PPNW-1:0] vsatp_ppn_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.PPNW-1:0] hgatp_ppn_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_i,
    // icache translation response - CACHE
    input icache_arsp_t icache_areq_i,
    // icache translation request - CACHE
    output icache_areq_t icache_areq_o,
    // Data cache request output - CACHE
    input dcache_req_o_t [2:0] dcache_req_ports_i,
    // Data cache request input - CACHE
    output dcache_req_i_t [2:0] dcache_req_ports_o,
    // Write buffer is empty - CACHE
    input logic dcache_wbuffer_empty_i,
    // TO_BE_COMPLETED - CACHE
    input logic dcache_wbuffer_not_ni_i,
    // AMO request - CACHE
    output amo_req_t amo_req_o,
    // AMO response - CACHE
    input amo_resp_t amo_resp_i,
    // To count the instruction TLB misses - PERF_COUNTERS
    output logic itlb_miss_o,
    // To count the data TLB misses - PERF_COUNTERS
    output logic dtlb_miss_o,
    // Report the PMP configuration - CSR_REGFILE
    input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg_i,
    // Report the PMP addresses - CSR_REGFILE
    input logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_i,
    // Information dedicated to RVFI - RVFI
    output lsu_ctrl_t rvfi_lsu_ctrl_o,
    // Information dedicated to RVFI - RVFI
    output [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    // Original instruction AES bits
    input logic [5:0] orig_instr_aes_i,
    //Trigger module communication
    output logic [CVA6Cfg.VLEN-1:0] sdtrig_lsu_inputs_operand_a_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_lsu_inputs_operand_c_o,
    output logic sdtrig_lsu_inputs_we_o,
    output logic sdtrig_lsu_inputs_valid_o,
    input logic sdtrig_load_stall_i,
    input logic sdtrig_load_cancel_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_load_action_i,
    input logic sdtrig_store_stall_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_store_action_i
);
```

### `core/commit_stage.sv`

```systemverilog
module commit_stage
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type scoreboard_entry_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Request to halt the core - CONTROLLER
    input logic halt_i,
    // request to flush dcache, also flush the pipeline - CACHE
    input logic flush_dcache_i,
    // TO_BE_COMPLETED - EX_STAGE
    output exception_t exception_o,
    // Mark the F state as dirty - CSR_REGFILE
    output logic dirty_fp_state_o,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic single_step_i,
    // The instruction we want to commit - ISSUE_STAGE
    input scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_i,
    // The instruction is cancelled - ISSUE_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_drop_i,
    // Acknowledge that we are indeed committing - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_o,
    // Acknowledge that we are indeed committing - CSR_REGFILE
    output logic [CVA6Cfg.NrCommitPorts-1:0] commit_macro_ack_o,
    // Register file write address - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0][4:0] waddr_o,
    // Register file write data - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_o,
    // Register file write enable - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] we_gpr_o,
    // Floating point register enable - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] we_fpr_o,
    // Result of AMO operation - CACHE
    input amo_resp_t amo_resp_i,
    // TO_BE_COMPLETED - FRONTEND_CSR_REGFILE
    output logic [CVA6Cfg.VLEN-1:0] pc_o,
    // Decoded CSR operation - CSR_REGFILE
    output fu_op csr_op_o,
    // Data to write to CSR - CSR_REGFILE
    output logic [CVA6Cfg.XLEN-1:0] csr_wdata_o,
    // Data to read from CSR - CSR_REGFILE
    input logic [CVA6Cfg.XLEN-1:0] csr_rdata_i,
    // Write the fflags CSR - CSR_REGFILE
    output logic csr_write_fflags_o,
    // Exception or interrupt occurred in CSR stage (the same as commit) - CSR_REGFILE
    input exception_t csr_exception_i,
    // Commit the pending store - EX_STAGE
    output logic commit_lsu_o,
    // Commit buffer of LSU is ready - EX_STAGE
    input logic commit_lsu_ready_i,
    // Transaction id of first commit port - ID_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_o,
    // Valid AMO in commit stage - EX_STAGE
    output logic amo_valid_commit_o,
    // No store is pending - EX_STAGE
    input logic no_st_pending_i,
    // Commit the pending CSR instruction - EX_STAGE
    output logic commit_csr_o,
    // Flush I$ and pipeline - CONTROLLER
    output logic fence_i_o,
    // Flush D$ and pipeline - CONTROLLER
    output logic fence_o,
    // Request a pipeline flush - CONTROLLER
    output logic flush_commit_o,
    // Flush TLBs and pipeline - CONTROLLER
    output logic sfence_vma_o,
    // TO_BE_COMPLETED - CONTROLLER
    output logic hfence_vvma_o,
    // TO_BE_COMPLETED - CONTROLLER
    output logic hfence_gvma_o,
    // Shared TLB is still processing a multi-cycle flush
    input logic shared_tlb_flush_busy_i,
    // Trigger module
    input logic sdtrig_commit_icount_valid_i,
    input logic [$clog2(CVA6Cfg.NrCommitPorts)-1:0] sdtrig_commit_icount_nr_instr_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_commit_action_i,
    input logic sdtrig_commit_std_exception_valid_i
);
```

### `core/controller.sv`

```systemverilog
module controller
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Virtualization mode - CSR_REGFILE
    input logic v_i,
    // Set PC om PC Gen - FRONTEND
    output logic set_pc_commit_o,
    // Flush the IF stage - FRONTEND
    output logic flush_if_o,
    // Flush un-issued instructions of the scoreboard - FRONTEND
    output logic flush_unissued_instr_o,
    // Flush ID stage - ID_STAGE
    output logic flush_id_o,
    // Flush EX stage - EX_STAGE
    output logic flush_ex_o,
    // Flush branch predictors - FRONTEND
    output logic flush_bp_o,
    // Flush ICache - CACHE
    output logic flush_icache_o,
    // Flush DCache - CACHE
    output logic flush_dcache_o,
    // Acknowledge the whole DCache Flush - CACHE
    input logic flush_dcache_ack_i,
    // Flush TLBs - EX_STAGE
    output logic flush_tlb_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic flush_tlb_vvma_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic flush_tlb_gvma_o,
    // Halt request from CSR (WFI instruction) - CSR_REGFILE
    input logic halt_csr_i,
    // Halt request from accelerator dispatcher - ACC_DISPATCHER
    input logic halt_acc_i,
    // Halt frontend during fence.i to prevent fetching stale instructions
    output logic halt_frontend_o,
    // Halt signal to commit stage - COMMIT_STAGE
    output logic halt_o,
    // Return from exception - CSR_REGFILE
    input logic eret_i,
    // We got an exception, flush the pipeline - FRONTEND
    input logic ex_valid_i,
    // set the debug pc from CSR - FRONTEND
    input logic set_debug_pc_i,
    // We got a resolved branch, check if we need to flush the front-end - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // We got an instruction which altered the CSR, flush the pipeline - CSR_REGFILE
    input logic flush_csr_i,
    // fence.i in - ACC_DISPATCH
    input logic fence_i_i,
    // fence in - ACC_DISPATCH
    input logic fence_i,
    // We got an instruction to flush the TLBs and pipeline - COMMIT_STAGE
    input logic sfence_vma_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic hfence_vvma_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic hfence_gvma_i,
    // Flush request from commit stage - COMMIT_STAGE
    input logic flush_commit_i,
    // Flush request from accelerator - ACC_DISPATCHER
    input logic flush_acc_i
);
```

### `core/csr_regfile.sv`

```systemverilog
module csr_regfile
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg            = config_pkg::cva6_cfg_empty,
    parameter type                   exception_t        = logic,
    parameter type                   jvt_t              = logic,
    parameter type                   irq_ctrl_t         = logic,
    parameter type                   scoreboard_entry_t = logic,
    parameter type                   rvfi_probes_csr_t  = logic,
    parameter int                    VmidWidth          = 1,
    parameter int unsigned           MHPMCounterNum     = 6,
    parameter int unsigned           N_Triggers         = 4
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Timer threw an interrupt - SUBSYSTEM
    input logic time_irq_i,
    // send a flush request out when a CSR with a side effect changes - CONTROLLER
    output logic flush_o,
    // halt requested - CONTROLLER
    output logic halt_csr_o,
    // Instruction to be committed - ID_STAGE
    input scoreboard_entry_t commit_instr_i,
    // Commit acknowledged an instruction -> increase instret CSR - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_i,
    // Address from which to start booting, mtvec is set to the same address - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Hart id in a multicore environment (reflected in a CSR) - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // We've got an exception from the commit stage, take it - COMMIT_STAGE
    input exception_t ex_i,
    // Operation to perform on the CSR file - COMMIT_STAGE
    input fu_op csr_op_i,
    // Address of the register to read/write - EX_STAGE
    input logic [11:0] csr_addr_i,
    // Write data in - COMMIT_STAGE
    input logic [CVA6Cfg.XLEN-1:0] csr_wdata_i,
    // Read data out - COMMIT_STAGE
    output logic [CVA6Cfg.XLEN-1:0] csr_rdata_o,
    // Mark the FP state as dirty - COMMIT_STAGE
    input logic dirty_fp_state_i,
    // Write fflags register e.g.: we are retiring a floating point instruction - COMMIT_STAGE
    input logic csr_write_fflags_i,
    // Mark the V state as dirty - ACC_DISPATCHER
    input logic dirty_v_state_i,
    // PC of instruction accessing the CSR - COMMIT_STAGE
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // attempts to access a CSR without appropriate privilege - COMMIT_STAGE
    output exception_t csr_exception_o,
    // Output the exception PC to PC Gen, the correct CSR (mepc, sepc) is set accordingly - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] epc_o,
    // Return from exception, set the PC of epc_o - FRONTEND
    output logic eret_o,
    // Output base of exception vector, correct CSR is output (mtvec, stvec) - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] trap_vector_base_o,
    // Current privilege level the CPU is in - EX_STAGE
    output riscv::priv_lvl_t priv_lvl_o,
    // Data Endian mode
    output logic mbe_o,
    // Current virtualization mode state the CPU is in - EX_STAGE
    output logic v_o,
    // Imprecise FP exception from the accelerator (fcsr.fflags format) - ACC_DISPATCHER
    input logic [4:0] acc_fflags_ex_i,
    // An FP exception from the accelerator occurred - ACC_DISPATCHER
    input logic acc_fflags_ex_valid_i,
    // Floating point extension status - ID_STAGE
    output riscv::xs_t fs_o,
    // Floating point extension virtual status - ID_STAGE
    output riscv::xs_t vfs_o,
    // Floating-Point Occurred Exceptions - COMMIT_STAGE
    output logic [4:0] fflags_o,
    // Floating-Point Dynamic Rounding Mode - EX_STAGE
    output logic [2:0] frm_o,
    // Floating-Point Precision Control - EX_STAGE
    output logic [6:0] fprec_o,
    // Vector extension status - ID_STAGE
    output riscv::xs_t vs_o,
    // interrupt management to id stage - ID_STAGE
    output irq_ctrl_t irq_ctrl_o,
    // Enable virtual address translation - EX_STAGE
    output logic en_translation_o,
    // Enable G-Stage address translation - EX_STAGE
    output logic en_g_translation_o,
    // Enable virtual address translation for load and stores - EX_STAGE
    output logic en_ld_st_translation_o,
    // Enable G-Stage address translation for load and stores - EX_STAGE
    output logic en_ld_st_g_translation_o,
    // Privilege level at which load and stores should happen - EX_STAGE
    output riscv::priv_lvl_t ld_st_priv_lvl_o,
    // Virtualization mode at which load and stores should happen - EX_STAGE
    output logic ld_st_v_o,
    // Current instruction is a Hypervisor Load/Store Instruction - EX_STAGE
    input logic csr_hs_ld_st_inst_i,
    // Supervisor User Memory - EX_STAGE
    output logic sum_o,
    // Virtual Supervisor User Memory - EX_STAGE
    output logic vs_sum_o,
    // Make Executable Readable - EX_STAGE
    output logic mxr_o,
    // Make Executable Readable for VS-mode - EX_STAGE
    output logic vmxr_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.PPNW-1:0] satp_ppn_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.ASID_WIDTH-1:0] asid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.PPNW-1:0] vsatp_ppn_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.PPNW-1:0] hgatp_ppn_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_o,
    // machine-mode cache block invalidate enable - ID_STAGE
    output riscv::cbie_t mcbie_o,
    // supervisor-mode cache block invalidate enable - ID_STAGE
    output riscv::cbie_t scbie_o,
    // hypervisor-mode cache block invalidate enable - ID_STAGE
    output riscv::cbie_t hcbie_o,
    // machine-mode clean/flush cache block invalidate enable - ID_STAGE
    output logic mcbcfe_o,
    // supervisor-mode clean/flush cache block invalidate enable - ID_STAGE
    output logic scbcfe_o,
    // hypervisor-mode clean/flush cache block invalidate enable - ID_STAGE
    output logic hcbcfe_o,
    // external interrupt in - SUBSYSTEM
    input logic [1:0] irq_i,
    // inter processor interrupt -> connected to machine mode sw - SUBSYSTEM
    input logic ipi_i,
    // debug request in - ID_STAGE
    input logic debug_req_i,
    // TO_BE_COMPLETED - FRONTEND
    output logic set_debug_pc_o,
    // trap virtual memory - ID_STAGE
    output logic tvm_o,
    // timeout wait - ID_STAGE
    output logic tw_o,
    // virtual timeout wait - ID_STAGE
    output logic vtw_o,
    // trap sret - ID_STAGE
    output logic tsr_o,
    // hypervisor user mode - ID_STAGE
    output logic hu_o,
    // we are in debug mode -> that will change some decoding - EX_STAGE
    output logic debug_mode_o,
    // we are in single-step mode - COMMIT_STAGE
    output logic single_step_o,
    // L1 ICache Enable - CACHE
    output logic icache_en_o,
    // L1 DCache Enable - CACHE
    output logic dcache_en_o,
    output logic dcache_scrub_en_o,
    output logic [5:0] dcache_scrub_period_o,
    input logic dcache_scrub_cycle_i,
    input logic dcache_dat_cor_err_i,
    input logic dcache_dat_unc_err_i,
    input logic dcache_dir_cor_err_i,
    input logic dcache_dir_unc_err_i,
    // Accelerator memory consistent mode - ACC_DISPATCHER
    output logic acc_cons_en_o,
    // read/write address to performance counter module - PERF_COUNTERS
    output logic [11:0] perf_addr_o,
    // write data to performance counter module - PERF_COUNTERS
    output logic [CVA6Cfg.XLEN-1:0] perf_data_o,
    // read data from performance counter module - PERF_COUNTERS
    input logic [CVA6Cfg.XLEN-1:0] perf_data_i,
    // TO_BE_COMPLETED - PERF_COUNTERS
    output logic perf_we_o,
    // PMP configuration containing pmpcfg for max 64 PMPs - ACC_DISPATCHER
    output riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg_o,
    // PMP addresses - ACC_DISPATCHER
    output logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_o,
    // TO_BE_COMPLETED - PERF_COUNTERS
    output logic [31:0] mcountinhibit_o,
    // RVFI
    output rvfi_probes_csr_t rvfi_csr_o,
    //jvt output
    output jvt_t jvt_o,
    // trigger module signals
    input logic [CVA6Cfg.VLEN-1:0] sdtrig_lsu_inputs_vaddr_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_lsu_inputs_data_i,
    input logic sdtrig_lsu_inputs_fu_i,
    input logic sdtrig_lsu_inputs_valid_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_load_data_i,
    input logic sdtrig_load_valid_i,

    //LSU <-> trigger module commmunication
    output logic sdtrig_load_stall_o,
    output logic sdtrig_load_cancel_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_load_action_o,
    output logic sdtrig_store_stall_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_store_action_o,

    //Decoder/fetch <-> trigger module communication
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] fetch_sdtrig_pc_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] fetch_sdtrig_instr_i,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_decoder_action_o[CVA6Cfg.NrIssuePorts],

    //Commit <- trigger module
    output logic sdtrig_commit_icount_valid_o,
    output logic [$clog2(CVA6Cfg.NrCommitPorts)-1:0] sdtrig_commit_icount_nr_instr_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_commit_action_o,
    output logic sdtrig_commit_std_exception_valid_o
);
```

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
module cva6_hpdcache_subsystem
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter int NumPorts = 4,
    parameter int NrHwPrefetchers = 4,
    // AXI types
    parameter type axi_ar_chan_t = logic,
    parameter type axi_aw_chan_t = logic,
    parameter type axi_w_chan_t = logic,
    parameter type axi_b_chan_t = logic,
    parameter type axi_r_chan_t = logic,
    parameter type noc_req_t = logic,
    parameter type noc_resp_t = logic
)
//  }}}

//  Ports
//  {{{
(

    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,

    //  AXI port to upstream memory/peripherals
    //  {{{
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t  noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input  noc_resp_t noc_resp_i,
    //  }}}

    //  I$
    //  {{{
    // Instruction cache enable - CSR_REGFILE
    input logic icache_en_i,
    // Flush the instruction cache - CONTROLLER
    input logic icache_flush_i,
    // instruction cache miss - PERF_COUNTERS
    output logic icache_miss_o,
    // Input address translation request - EX_STAGE
    input icache_areq_t icache_areq_i,
    // Output address translation request - EX_STAGE
    output icache_arsp_t icache_areq_o,
    // Input data translation request - FRONTEND
    input icache_dreq_t icache_dreq_i,
    // Output data translation request - FRONTEND
    output icache_drsp_t icache_dreq_o,
    //   }}}

    //  D$
    //  {{{
    //    Cache management
    // Data cache enable - CSR_REGFILE
    input logic dcache_enable_i,
    // Data cache flush - CONTROLLER
    input logic dcache_flush_i,
    // Flush acknowledge - CONTROLLER
    output logic dcache_flush_ack_o,
    // Load or store miss - PERF_COUNTERS
    output logic dcache_miss_o,
    // Data cache scrubber enable - CSR_REGFILE
    input logic dcache_scrub_enable_i,
    // Data cache scrubber period - CSR_REGFILE
    input logic [5:0] dcache_scrub_period_i,
    // Data cache scrubber cycle - CSR_REGFILE
    output logic dcache_scrub_cycle_o,
    // Data cache data error corrected - CSR_REGFILE
    output logic dcache_dat_cor_err_o,
    // Data cache data error detected but not corrected - CSR_REGFILE
    output logic dcache_dat_unc_err_o,
    // Data cache tag error corrected - CSR_REGFILE
    output logic dcache_dir_cor_err_o,
    // Data cache tag error detected but not corrected - CSR_REGFILE
    output logic dcache_dir_unc_err_o,

    // AMO request - EX_STAGE
    input  ariane_pkg::amo_req_t                 dcache_amo_req_i,
    // AMO response - EX_STAGE
    output ariane_pkg::amo_resp_t                dcache_amo_resp_o,
    // Data cache input request ports - EX_STAGE
    input  dcache_req_i_t         [NumPorts-1:0] dcache_req_ports_i,
    // Data cache output request ports - EX_STAGE
    output dcache_req_o_t         [NumPorts-1:0] dcache_req_ports_o,
    // Write buffer status to know if empty - EX_STAGE
    output logic                                 wbuffer_empty_o,
    // Write buffer status to know if not non idempotent - EX_STAGE
    output logic                                 wbuffer_not_ni_o,

    //  Hardware memory prefetcher configuration
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0]       hwpf_base_set_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_base_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_base_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0]       hwpf_param_set_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_param_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_param_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0]       hwpf_throttle_set_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [               63:0]       hwpf_status_o
    //  }}}
);
// ...
  //    0: Page-Table Walk (PTW)
  //    1: Load unit
  //    2: Accelerator load
  //    3: Store/AMO
```

### `core/cva6_rvfi_probes.sv`

```systemverilog
module cva6_rvfi_probes
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type bp_resolve_t = logic,
    parameter type rvfi_probes_instr_t = logic,
    parameter type rvfi_probes_csr_t = logic,
    parameter type rvfi_probes_t = logic

) (

    input logic                                  flush_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_ack_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0]       fetch_entry_valid_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] instruction_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0]       is_compressed_i,

    input logic [CVA6Cfg.NrIssuePorts-1 : 0][CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer_i,
    input logic [ CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] commit_pointer_i,

    input logic flush_unissued_instr_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_valid_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_ack_i,

    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rs1_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rs2_i,

    input scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_i,
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_drop_i,
    input exception_t ex_commit_i,
    input riscv::priv_lvl_t priv_lvl_i,

    input lsu_ctrl_t                                               lsu_ctrl_i,
    input logic      [    CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_i,
    input logic      [CVA6Cfg.NrCommitPorts-1:0]                   commit_ack_i,
    input logic      [         CVA6Cfg.PLEN-1:0]                   mem_paddr_i,
    input logic                                                    debug_mode_i,
    input logic      [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_i,

    input rvfi_probes_csr_t csr_i,
    input logic [1:0] irq_i,
    input bp_resolve_t resolved_branch_i,
    input [CVA6Cfg.TRANS_ID_BITS-1:0] flu_trans_id_ex_id_i,

    output rvfi_probes_t rvfi_probes_o
);
```

## Related source code

### `core/decoder.sv`

```systemverilog
  logic [CVA6Cfg.XLEN-1:0] interrupt_cause;
// ...
    // Interrupt Control
    // -----------------
    // we decode an interrupt the same as an exception, hence it will be taken if the instruction did not
    // throw any previous exception.
    // we have three interrupt sources: external interrupts, software interrupts, timer interrupts (order of precedence)
    // for two privilege levels: Supervisor and Machine Mode
    // Virtual Supervisor Timer Interrupt
    if (CVA6Cfg.RVH) begin
      if (irq_ctrl_i.mie[riscv::IRQ_VS_TIMER] && irq_ctrl_i.mip[riscv::IRQ_VS_TIMER]) begin
        interrupt_cause = INTERRUPTS.VS_TIMER;
      end
      // Virtual Supervisor Software Interrupt
      if (irq_ctrl_i.mie[riscv::IRQ_VS_SOFT] && irq_ctrl_i.mip[riscv::IRQ_VS_SOFT]) begin
        interrupt_cause = INTERRUPTS.VS_SW;
      end
      // Virtual Supervisor External Interrupt
      if (irq_ctrl_i.mie[riscv::IRQ_VS_EXT] && (irq_ctrl_i.mip[riscv::IRQ_VS_EXT])) begin
        interrupt_cause = INTERRUPTS.VS_EXT;
      end
      // Hypervisor Guest External Interrupts
      if (irq_ctrl_i.mie[riscv::IRQ_HS_EXT] && irq_ctrl_i.mip[riscv::IRQ_HS_EXT]) begin
        interrupt_cause = INTERRUPTS.HS_EXT;
      end
    end
    if (CVA6Cfg.RVS) begin
      // Supervisor Timer Interrupt
      if (irq_ctrl_i.mie[riscv::IRQ_S_TIMER] && irq_ctrl_i.mip[riscv::IRQ_S_TIMER]) begin
        interrupt_cause = INTERRUPTS.S_TIMER;
      end
      // Supervisor Software Interrupt
      if (irq_ctrl_i.mie[riscv::IRQ_S_SOFT] && irq_ctrl_i.mip[riscv::IRQ_S_SOFT]) begin
        interrupt_cause = INTERRUPTS.S_SW;
      end
      // Supervisor External Interrupt
      // The logical-OR of the software-writable bit and the signal from the external interrupt controller is
      // used to generate external interrupts to the supervisor
      if (irq_ctrl_i.mie[riscv::IRQ_S_EXT] && (irq_ctrl_i.mip[riscv::IRQ_S_EXT] | irq_i[ariane_pkg::SupervisorIrq])) begin
        interrupt_cause = INTERRUPTS.S_EXT;
      end
    end
    // Machine Timer Interrupt
    if (irq_ctrl_i.mip[riscv::IRQ_M_TIMER] && irq_ctrl_i.mie[riscv::IRQ_M_TIMER]) begin
      interrupt_cause = INTERRUPTS.M_TIMER;
    end
    if (CVA6Cfg.SoftwareInterruptEn) begin
      // Machine Mode Software Interrupt
      if (irq_ctrl_i.mip[riscv::IRQ_M_SOFT] && irq_ctrl_i.mie[riscv::IRQ_M_SOFT]) begin
        interrupt_cause = INTERRUPTS.M_SW;
      end
    end
    // Machine Mode External Interrupt
    if (irq_ctrl_i.mip[riscv::IRQ_M_EXT] && irq_ctrl_i.mie[riscv::IRQ_M_EXT]) begin
      interrupt_cause = INTERRUPTS.M_EXT;
    end

    if (interrupt_cause[CVA6Cfg.XLEN-1] && irq_ctrl_i.global_enable) begin
      // However, if bit i in mideleg is set, interrupts are considered to be globally enabled if the hart’s current privilege
      // mode equals the delegated privilege mode (S or U) and that mode’s interrupt enable bit
      // (SIE or UIE in mstatus) is set, or if the current privilege mode is less than the delegated privilege mode.
      if (irq_ctrl_i.mideleg[interrupt_cause[$clog2(CVA6Cfg.XLEN)-1:0]]) begin
        if (CVA6Cfg.RVH) begin : hyp_int_gen
          if (v_i && irq_ctrl_i.hideleg[interrupt_cause[$clog2(CVA6Cfg.XLEN)-1:0]]) begin
            if ((irq_ctrl_i.sie && priv_lvl_i == riscv::PRIV_LVL_S) || priv_lvl_i == riscv::PRIV_LVL_U) begin
              instruction_o.ex.valid = 1'b1;
              instruction_o.ex.cause = interrupt_cause;
            end
          end else if (v_i && ~irq_ctrl_i.hideleg[interrupt_cause[$clog2(CVA6Cfg.XLEN)-1:0]]) begin
            instruction_o.ex.valid = 1'b1;
            instruction_o.ex.cause = interrupt_cause;
          end else if (!v_i && ((irq_ctrl_i.sie && priv_lvl_i == riscv::PRIV_LVL_S) || priv_lvl_i == riscv::PRIV_LVL_U) && ~irq_ctrl_i.hideleg[interrupt_cause[$clog2(
                  CVA6Cfg.XLEN
              )-1:0]]) begin
            instruction_o.ex.valid = 1'b1;
            instruction_o.ex.cause = interrupt_cause;
          end
        end else begin
          if ((CVA6Cfg.RVS && irq_ctrl_i.sie && priv_lvl_i == riscv::PRIV_LVL_S) || (CVA6Cfg.RVU && priv_lvl_i == riscv::PRIV_LVL_U)) begin
            instruction_o.ex.valid = 1'b1;
            instruction_o.ex.cause = interrupt_cause;
          end
        end
      end else begin
        instruction_o.ex.valid = 1'b1;
        instruction_o.ex.cause = interrupt_cause;
      end
    end
```

## Documentation

### `docs/01_cva6_user/Introduction.rst`

```text
CVA6 Overview
--------------
**CVA6** is a RISC-V compatible application processor core that can be configured
as a 32- or 64-bit core: **CV32A6** and **CV64A6**.

CVA6 can be configured to the users' and application needs thanks to several
parameters and optional features (MMU, PMP, FPU, cache organization and size...).
It targets **FPGA** and **ASIC** technologies.

CVA6, as an application core, can run many operating systems. It has already been
demonstrated with embedded **Linux** distributions (built with **BuildRoot** and
**Yocto**), **FreeRTOS** and **Zephyr**.

CVA6 features the **CV-X-IF** coprocessor interface to extend the set of instructions it can execute.

The goal of CVA6 is to be **fully compliant** with RISC-V specifications and feature no or extremely
few custom extensions (except through extensions on CV-X-IF interface).

CV32A6 and CV64A6 share the same **SystemVerilog** source code, available in this GitHub_ repository.

.. _GitHub: https://github.com/openhwgroup/cva6/

CV64A6 is an industrial evolution of ARIANE created by ETH Zürich and the
University of Bologna. CV32A6 is a later addition by Thales. CVA6 is now
curated at the OpenHW Group by its members.
```

## Additional requirement

`cva6` must declare the `interrupts_t` type and the `INTERRUPTS` value that it passes to `id_stage`.
