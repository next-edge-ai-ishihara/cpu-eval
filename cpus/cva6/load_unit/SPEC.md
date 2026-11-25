# Implement `load_unit`

Implement the complete `load_unit` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module load_unit` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

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
// ...
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
// ...
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
// ...
      NrLoadPipeRegs: int'(0),
      NrStorePipeRegs: int'(0),
      DcacheIdWidth: int'(1)
```

### core/include/build_config_pkg.sv

```systemverilog
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
// ...
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
// ...
    cfg.FpPresent = bit'(FpPresent);
    cfg.NSX = bit'(NSX);
    cfg.FLen = unsigned'(FLen);
    cfg.RVFVec = bit'(RVFVec);
    cfg.XF16Vec = bit'(XF16Vec);
    cfg.XF16ALTVec = bit'(XF16ALTVec);
    cfg.XF8Vec = bit'(XF8Vec);
    // Can take 2 or 3 in single issue. 4 or 6 in dual issue.
    cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 4 : 2);
    // cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 6 : 3);
    cfg.NrWbPorts = unsigned'(NrWbPorts);
    cfg.EnableAccelerator = bit'(EnableAccelerator);
    cfg.PerfCounterEn = CVA6Cfg.PerfCounterEn;
    cfg.MmuPresent = CVA6Cfg.MmuPresent;
// ...
    cfg.TvalEn = CVA6Cfg.TvalEn;
    cfg.DirectVecOnly = CVA6Cfg.DirectVecOnly;
    cfg.NrPMPEntries = CVA6Cfg.NrPMPEntries;
    cfg.PMPCfgRstVal = CVA6Cfg.PMPCfgRstVal;
    cfg.PMPAddrRstVal = CVA6Cfg.PMPAddrRstVal;
    cfg.PMPEntryReadOnly = CVA6Cfg.PMPEntryReadOnly;
    cfg.PMPNapotEn = CVA6Cfg.PMPNapotEn;
    cfg.NOCType = CVA6Cfg.NOCType;
    cfg.NrNonIdempotentRules = CVA6Cfg.NrNonIdempotentRules;
    cfg.NonIdempotentAddrBase = CVA6Cfg.NonIdempotentAddrBase;
    cfg.NonIdempotentLength = CVA6Cfg.NonIdempotentLength;
    cfg.NrExecuteRegionRules = CVA6Cfg.NrExecuteRegionRules;
    cfg.ExecuteRegionAddrBase = CVA6Cfg.ExecuteRegionAddrBase;
    cfg.ExecuteRegionLength = CVA6Cfg.ExecuteRegionLength;
    cfg.NrCachedRegionRules = CVA6Cfg.NrCachedRegionRules;
    cfg.CachedRegionAddrBase = CVA6Cfg.CachedRegionAddrBase;
    cfg.CachedRegionLength = CVA6Cfg.CachedRegionLength;
    cfg.MaxOutstandingStores = CVA6Cfg.MaxOutstandingStores;
    cfg.DebugEn = CVA6Cfg.DebugEn;

    cfg.Sdtrig = CVA6Cfg.Sdtrig;
    cfg.SdtrigMcontrol6 = CVA6Cfg.Sdtrig ? CVA6Cfg.SdtrigMcontrol6 : 1'b0;
    cfg.SdtrigIcount = CVA6Cfg.Sdtrig ? CVA6Cfg.SdtrigIcount : 1'b0;
    cfg.SdtrigEtrigger = CVA6Cfg.Sdtrig ? CVA6Cfg.SdtrigEtrigger : 1'b0;
    cfg.SdtrigItrigger = CVA6Cfg.Sdtrig ? CVA6Cfg.SdtrigItrigger : 1'b0;
    cfg.SdtrigNrTriggers = CVA6Cfg.Sdtrig ? CVA6Cfg.SdtrigNrTriggers : 32'd0;
    cfg.SdtrigMcontrol6ExecAddr = CVA6Cfg.SdtrigMcontrol6 ? CVA6Cfg.SdtrigMcontrol6ExecAddr : 1'b0;
    cfg.SdtrigMcontrol6ExecData = CVA6Cfg.SdtrigMcontrol6 ? CVA6Cfg.SdtrigMcontrol6ExecData : 1'b0;
    cfg.SdtrigMcontrol6Store = CVA6Cfg.SdtrigMcontrol6 ? CVA6Cfg.SdtrigMcontrol6Store : 1'b0;
    cfg.SdtrigMcontrol6LoadAddr = CVA6Cfg.SdtrigMcontrol6 ? CVA6Cfg.SdtrigMcontrol6LoadAddr : 1'b0;
    cfg.SdtrigMcontrol6LoadData = CVA6Cfg.SdtrigMcontrol6 ? CVA6Cfg.SdtrigMcontrol6LoadData : 1'b0;
    cfg.SdtrigTriggerChaining = CVA6Cfg.SdtrigMcontrol6 ? CVA6Cfg.SdtrigTriggerChaining : 1'b0;
    cfg.SdtrigSupportedActions = CVA6Cfg.Sdtrig ? (CVA6Cfg.DebugEn ? CVA6Cfg.SdtrigSupportedActions : 2'b01) : 2'b00;
    cfg.SdtrigSupportedMatch = CVA6Cfg.Sdtrig ? CVA6Cfg.SdtrigSupportedMatch : 10'b00_0000_0000;
    cfg.SdtrigSupportTextra = 1'b0;  //Trigger Extra not supported : no use implemented yet

    cfg.NonIdemPotenceEn = (CVA6Cfg.NrNonIdempotentRules > 0) && (CVA6Cfg.NonIdempotentLength > 0);
    cfg.AxiBurstWriteEn = CVA6Cfg.AxiBurstWriteEn;

    cfg.ICACHE_SET_ASSOC = CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_SET_ASSOC_WIDTH = CVA6Cfg.IcacheSetAssoc > 1 ? $clog2(CVA6Cfg.IcacheSetAssoc) :
        CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_INDEX_WIDTH = ICACHE_INDEX_WIDTH;
    cfg.ICACHE_TAG_WIDTH = cfg.PLEN - ICACHE_INDEX_WIDTH;
    cfg.ICACHE_LINE_WIDTH = CVA6Cfg.IcacheLineWidth;
    cfg.ICACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.IcacheLineWidth;
    cfg.DCacheType = CVA6Cfg.DCacheType;
    cfg.DcacheIdWidth = CVA6Cfg.DcacheIdWidth;
    cfg.DCACHE_SET_ASSOC = CVA6Cfg.DcacheSetAssoc;
    cfg.DCACHE_SET_ASSOC_WIDTH = CVA6Cfg.DcacheSetAssoc > 1 ? $clog2(CVA6Cfg.DcacheSetAssoc) :
        CVA6Cfg.DcacheSetAssoc;
    cfg.DCACHE_INDEX_WIDTH = DCACHE_INDEX_WIDTH;
    cfg.DCACHE_TAG_WIDTH = cfg.PLEN - DCACHE_INDEX_WIDTH;
    cfg.DCACHE_LINE_WIDTH = CVA6Cfg.DcacheLineWidth;
    cfg.DCACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.DcacheLineWidth;
    cfg.DCACHE_USER_WIDTH = CVA6Cfg.AxiUserWidth;
    cfg.DCACHE_OFFSET_WIDTH = DCACHE_OFFSET_WIDTH;
```

## Module declaration

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

## Parent instantiation

### core/load_store_unit.sv

```systemverilog
  // ------------------
  // Load Unit
  // ------------------
  load_unit #(
      .CVA6Cfg(CVA6Cfg),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .exception_t(exception_t),
      .lsu_ctrl_t(lsu_ctrl_t)
  ) i_load_unit (
      .clk_i,
      .rst_ni,
      .flush_i,
      .valid_i   (ld_valid_i),
      .lsu_ctrl_i(lsu_ctrl),
      .pop_ld_o  (pop_ld),

      .valid_o              (ld_valid),
      .trans_id_o           (ld_trans_id),
      .result_o             (ld_result),
      .ex_o                 (ld_ex),
      .mbe_i                (mbe_i),
      // MMU port
      .translation_req_o    (ld_translation_req),
      .vaddr_o              (ld_vaddr),
      .tinst_o              (ld_tinst),
      .hs_ld_st_inst_o      (ld_hs_ld_st_inst),
      .hlvx_inst_o          (ld_hlvx_inst),
      .paddr_i              (cva6_mmu_paddr),
      .ex_i                 (cva6_mmu_exception),
      .dtlb_hit_i           (cva6_dtlb_hit),
      .dtlb_ppn_i           (cva6_dtlb_ppn),
      // to store unit
      .page_offset_o        (page_offset),
      .page_offset_matches_i(page_offset_matches),
      .store_buffer_empty_i (store_buffer_empty),
      .commit_tran_id_i,
      // to memory arbiter
      .req_port_i           (dcache_req_ports_i[1]),
      .req_port_o           (dcache_req_ports_o[1]),
      .dcache_wbuffer_not_ni_i,
      //sdtrig
      .sdtrig_load_stall_i  (sdtrig_load_stall_i),
      .sdtrig_load_cancel_i (sdtrig_load_cancel_i),
      .sdtrig_load_action_i (sdtrig_load_action_i)
  );
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
    // LSU functions
    LD,
    SD,
    LW,
    LWU,
    SW,
    LH,
    LHU,
    SH,
    LB,
    SB,
    LBU,
    // Hypervisor Virtual-Machine Load and Store Instructions
    HLV_B,
    HLV_BU,
    HLV_H,
    HLV_HU,
    HLVX_HU,
    HLV_W,
    HLVX_WU,
    HSV_B,
    HSV_H,
// ...
    // cache block operations (CBO)
    CBO_CLEAN,
    CBO_FLUSH,
    CBO_INVAL,
    CBO_NONE,
// ...
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
  localparam logic [XLEN-1:0] INSTR_ADDR_MISALIGNED = 0;
  localparam logic [XLEN-1:0] INSTR_ACCESS_FAULT    = 1;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ILLEGAL_INSTR = 2;
  localparam logic [XLEN-1:0] BREAKPOINT = 3;
  localparam logic [XLEN-1:0] LD_ADDR_MISALIGNED = 4;
  localparam logic [XLEN-1:0] LD_ACCESS_FAULT = 5;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ST_ADDR_MISALIGNED = 6;
  localparam logic [XLEN-1:0] ST_ACCESS_FAULT = 7;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ENV_CALL_UMODE = 8;  // environment call from user mode or virtual user mode
  localparam logic [XLEN-1:0] ENV_CALL_SMODE = 9;  // environment call from hypervisor-extended supervisor mode
  localparam logic [XLEN-1:0] ENV_CALL_VSMODE = 10; // environment call from virtual supervisor mode
  localparam logic [XLEN-1:0] ENV_CALL_MMODE = 11;  // environment call from machine mode
  localparam logic [XLEN-1:0] INSTR_PAGE_FAULT = 12;  // Instruction page fault
  localparam logic [XLEN-1:0] LOAD_PAGE_FAULT = 13;  // Load page fault
  localparam logic [XLEN-1:0] STORE_PAGE_FAULT = 15;  // Store page fault
  localparam logic [XLEN-1:0] HARDWARE_ERROR = 19;  // Transient error (e.g., bit-flip error in caches' SRAMs)
  localparam logic [XLEN-1:0] INSTR_GUEST_PAGE_FAULT = 20;  // Instruction guest-page fault
  localparam logic [XLEN-1:0] LOAD_GUEST_PAGE_FAULT = 21;  // Load guest-page fault
  localparam logic [XLEN-1:0] VIRTUAL_INSTRUCTION = 22;  // virtual instruction
```

### vendor/pulp-platform/common_cells/src/lzc.sv

```systemverilog
/// A trailing zero counter / leading zero counter.
/// Set MODE to 0 for trailing zero counter => cnt_o is the number of trailing zeros (from the LSB)
/// Set MODE to 1 for leading zero counter  => cnt_o is the number of leading zeros  (from the MSB)
/// If the input does not contain a zero, `empty_o` is asserted. Additionally `cnt_o` contains
/// the maximum number of zeros - 1. For example:
///   in_i = 000_0000, empty_o = 1, cnt_o = 6 (mode = 0)
///   in_i = 000_0001, empty_o = 0, cnt_o = 0 (mode = 0)
///   in_i = 000_1000, empty_o = 0, cnt_o = 3 (mode = 0)
/// Furthermore, this unit contains a more efficient implementation for Verilator (simulation only).
/// This speeds up simulation significantly.
module lzc #(
  /// The width of the input vector.
  parameter int unsigned WIDTH = 2,
  /// Mode selection: 0 -> trailing zero, 1 -> leading zero
  parameter bit          MODE  = 1'b0,
  /// Dependent parameter. Do **not** change!
  ///
  /// Width of the output signal with the zero count.
  parameter int unsigned CNT_WIDTH = cf_math_pkg::idx_width(WIDTH)
) (
  /// Input vector to be counted.
  input  logic [WIDTH-1:0]     in_i,
  /// Count of the leading / trailing zeros.
  output logic [CNT_WIDTH-1:0] cnt_o,
  /// Counter is empty: Asserted if all bits in in_i are zero.
  output logic                 empty_o
);
```

## Related source code

### core/cache_subsystem/cva6_hpdcache_if_adapter.sv

```systemverilog
      //    Request forwarding
      assign hpdcache_req_valid_o = cva6_req_i.data_req;
      assign hpdcache_req.addr_offset = cva6_req_i.address_index;
      assign hpdcache_req.wdata = '0;
      assign hpdcache_req.op = hpdcache_pkg::HPDCACHE_REQ_LOAD;
      assign hpdcache_req.be = cva6_req_i.data_be;
      assign hpdcache_req.size = cva6_req_i.data_size;
      assign hpdcache_req.sid = hpdcache_req_sid_i;
      assign hpdcache_req.tid = cva6_req_i.data_id;
      assign hpdcache_req.need_rsp = 1'b1;
      assign hpdcache_req.phys_indexed = 1'b0;
      assign hpdcache_req.addr_tag = '0;  // unused on virtually indexed request
      assign hpdcache_req.pma.uncacheable = 1'b0;
      assign hpdcache_req.pma.io = 1'b0;
      assign hpdcache_req.pma.wr_policy_hint = hpdcache_pkg::HPDCACHE_WR_POLICY_AUTO;

      assign hpdcache_req_abort_o = cva6_req_i.kill_req;
      assign hpdcache_req_tag_o = cva6_req_i.address_tag;
      assign hpdcache_req_pma_o.uncacheable = hpdcache_req_is_uncacheable;
      assign hpdcache_req_pma_o.io = 1'b0;
      assign hpdcache_req_pma_o.wr_policy_hint = hpdcache_pkg::HPDCACHE_WR_POLICY_AUTO;

      //    Response forwarding
      assign cva6_req_o.data_rvalid = hpdcache_rsp_valid_i;
      assign cva6_req_o.data_rdata = hpdcache_rsp_i.rdata;
      assign cva6_req_o.data_rid = hpdcache_rsp_i.tid;
      assign cva6_req_o.data_error = hpdcache_rsp_i.error;
      assign cva6_req_o.data_gnt = hpdcache_req_ready_i;
```

## Documentation

### docs/03_cva6_design/ex_stage.md

```text
##### Load Unit {#par:load_unit}

The load unit takes care of all loads. Loads are issued as soon as
possible as they do not have any side effects. Before issuing a
load the load unit needs to check the store buffer for stores which are
not committed into the memory hierarchy yet in order to avoid loading
stale data. As a full comparison is quite costly only the lower 12 bit
(the page-offset where physical and virtual addresses are the same) are
compared. This has two major advantages: the comparison is only 12-bit
instead of 64-bit and therefore faster when done on the whole buffer
and the physical address is not needed which implies
that we don't need to wait for address translation to finish. If the
page offset matches with one of the outstanding stores the load unit
simply stalls and waits until the store buffer is drained. As an
improvement one could do some more elaborate data forwarding as the data
in the store buffer is the most up-to-date. This is not done at the
moment.

Furthermore the load unit needs to perform address translation. It makes
use of virtually indexed and physically tagged D\$ access scheme
in order to reduce the number of cycles needed for load accesses. As it
can happen that a load blocks the D\$ it
has to kill the current request on the memory interface to give way to
the hardware PTW on the cache side. Some more advanced caching
infrastructure (like a non-blocking cache) would alleviate this problem.
```

### docs/design/design-manual/source/cva6_execute.adoc

```text
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
```

### src/rv32.adoc

```text
The EEI will define whether the memory system is little-endian or
big-endian. In RISC-V, endianness is byte-address invariant.

[NOTE]
====
In a system for which endianness is byte-address invariant, the
following property holds: if a byte is stored to memory at some address
in some endianness, then a byte-sized load from that address in any
endianness returns the stored value.

In a little-endian configuration, multibyte stores write the
least-significant register byte at the lowest memory byte address,
followed by the other register bytes in ascending order of their
significance. Loads similarly transfer the contents of the lesser memory
byte addresses to the less-significant register bytes.

In a big-endian configuration, multibyte stores write the
most-significant register byte at the lowest memory byte address,
followed by the other register bytes in descending order of their
significance. Loads similarly transfer the contents of the greater
memory byte addresses to the less-significant register bytes.
====
...
Load and store instructions transfer a value between the registers and
memory. Loads are encoded in the I-type format and stores are S-type.
The effective address is obtained by adding register _rs1_ to the
sign-extended 12-bit offset. Loads copy a value from memory to register
_rd_. Stores copy the value in register _rs2_ to memory.

The LW instruction loads a 32-bit value from memory into _rd_. LH loads
a 16-bit value from memory, then sign-extends to 32-bits before storing
in _rd_. LHU loads a 16-bit value from memory but then zero extends to
32-bits before storing in _rd_. LB and LBU are defined analogously for
8-bit values. The SW, SH, and SB instructions store 32-bit, 16-bit, and
8-bit values from the low bits of register _rs2_ to memory.
```

### src/machine.adoc

```text
===== Endianness Control in `mstatus` and `mstatush` Registers

The MBE, SBE, and UBE bits in `mstatus` and `mstatush` are *WARL* fields that
control the endianness of memory accesses other than instruction
fetches. Instruction fetches are always little-endian.

MBE controls whether non-instruction-fetch memory accesses made from
M-mode (assuming `mstatus`.MPRV=0) are little-endian (MBE=0) or
big-endian (MBE=1).
```

### docs/source/interface.rst

```text
The address (``core_req_i.addr_offset``), size (``core_req_i.size``),
byte-enable (``core_req_i.be``), write data (``core_req_i.wdata``) and
read data (``core_rsp_o.rdata``) signals shall comply with the alignment
constraints defined in section
:ref:`Address, data, and byte enable alignment <sec_req_alignment>`.
...
Data alignment
''''''''''''''

The data must be naturally aligned to the address (**addr**) and the maximum
valid bytes of the transfer must be equal to :math:`\scriptsize\mathsf{2^{size}}`.
This means that the first valid byte in the **data** signal must be at the
indicated offset of the address. Here, the offset corresponds to the least
significant bits of the address, that allow to indicate a byte within the
**data** word. For example, if the **data** signal is 128 bits wide (16
bytes), then the offset corresponds to the first 4 bits of the **addr** signal.
...
Request Abortion
~~~~~~~~~~~~~~~~~~~~~

When using the virtual indexing, the requester can abort the request during the
second cycle of the addressing pipeline. In that case, the requester needs to
set the req_abort signal to 1.

When a request is aborted, and the ``core_req_i.need_rsp`` field was set to 1, the
HPDcache respond to the corresponding requester with the bit
``core_rsp_o.aborted`` set to 1.
```

## Additional requirement

A load whose data-cache response has not arrived when `flush_i` is asserted produces no `valid_o` completion, including when that response arrives after the flush.
