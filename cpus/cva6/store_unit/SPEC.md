# Implement `store_unit`

Implement the complete `store_unit` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module store_unit` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      VLEN: unsigned'(32),
// ...
      RVF: bit'(0),
// ...
      RVA: bit'(0),
// ...
      RVH: bit'(0),
// ...
      RVZiCbom: bit'(0),
// ...
      MmuPresent: bit'(0),
// ...
      Sdtrig: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = IS_XLEN32 ? 34 : 56;
    cfg.GPLEN = IS_XLEN32 ? 34 : 41;
    cfg.IS_XLEN32 = IS_XLEN32;
    cfg.IS_XLEN64 = IS_XLEN64;
    cfg.XLEN_ALIGN_BYTES = $clog2(CVA6Cfg.XLEN / 8);
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  typedef enum logic [7:0] {  // basic ALU op
// ...
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
// ...
  } fu_op;
// ...
  typedef enum logic [3:0] {
    AMO_NONE = 4'b0000,
    AMO_LR   = 4'b0001,
    AMO_SC   = 4'b0010,
    AMO_SWAP = 4'b0011,
    AMO_ADD  = 4'b0100,
    AMO_AND  = 4'b0101,
    AMO_OR   = 4'b0110,
    AMO_XOR  = 4'b0111,
    AMO_MAX  = 4'b1000,
    AMO_MAXU = 4'b1001,
    AMO_MIN  = 4'b1010,
    AMO_MINU = 4'b1011,
    AMO_CAS1 = 4'b1100,  // unused, not part of riscv spec, but provided in OpenPiton
    AMO_CAS2 = 4'b1101   // unused, not part of riscv spec, but provided in OpenPiton
  } amo_t;
// ...
  // AMO request going to cache. this request is unconditionally valid as soon
  // as request goes high.
  // Furthermore, those signals are kept stable until the response indicates
  // completion by asserting ack.
  typedef struct packed {
    logic        req;        // this request is valid
    amo_t        amo_op;     // atomic memory operation to perform
    logic [1:0]  size;       // 2'b10 --> word operation, 2'b11 --> double word operation
    logic [63:0] operand_a;  // address
    logic [63:0] operand_b;  // data as layouted in the register
  } amo_req_t;

  // AMO response coming from cache.
  typedef struct packed {
    logic        ack;     // response is valid
    logic [63:0] result;  // sign-extended, result
  } amo_resp_t;
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

## Module declaration

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

## Parent instantiation

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


    localparam type cbo_t = logic [7:0],
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

### core/load_store_unit.sv

```systemverilog
    // dcache request without mmu for load or store,
    // Delay of 1 cycle to match MMU latency giving the address tag
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
        lsu_paddr <= '0;
        pmp_exception <= '0;
        pmp_translation_valid <= 1'b0;
      end else begin
        if (CVA6Cfg.VLEN >= CVA6Cfg.PLEN) begin : gen_virtual_physical_address_lsu
          lsu_paddr <= mmu_vaddr[CVA6Cfg.PLEN-1:0];
        end else begin
          lsu_paddr <= CVA6Cfg.PLEN'(mmu_vaddr);
        end
        pmp_exception <= misaligned_exception;
        pmp_translation_valid <= translation_req;
      end
    end

    // dcache interface of PTW not used
    assign dcache_req_ports_o[0].address_index = '0;
    assign dcache_req_ports_o[0].address_tag   = '0;
    assign dcache_req_ports_o[0].data_wdata    = '0;
    assign dcache_req_ports_o[0].data_req      = 1'b0;
    assign dcache_req_ports_o[0].data_be       = '1;
    assign dcache_req_ports_o[0].data_size     = 2'b11;
    assign dcache_req_ports_o[0].data_we       = 1'b0;
    assign dcache_req_ports_o[0].data_wuser    = '0;
    assign dcache_req_ports_o[0].kill_req      = '0;
    assign dcache_req_ports_o[0].tag_valid     = 1'b0;

    assign itlb_miss_o                         = 1'b0;
    assign dtlb_miss_o                         = 1'b0;
    assign dtlb_ppn                            = lsu_paddr[CVA6Cfg.PLEN-1:12];
    assign dtlb_hit                            = 1'b1;

// ...
  store_unit #(
      .CVA6Cfg(CVA6Cfg),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .exception_t(exception_t),
      .lsu_ctrl_t(lsu_ctrl_t),
      .cbo_t(cbo_t)
  ) i_store_unit (
      .clk_i,
      .rst_ni,
      .flush_i,
      .stall_st_pending_i,
      .no_st_pending_o,
      .store_buffer_empty_o(store_buffer_empty),

      .valid_i   (st_valid_i),
      .lsu_ctrl_i(lsu_ctrl),
      .pop_st_o  (pop_st),
      .commit_i,
      .commit_ready_o,
      .amo_valid_commit_i,
      .mbe_i     (mbe_i),

      .valid_o              (st_valid),
      .trans_id_o           (st_trans_id),
      .result_o             (st_result),
      .ex_o                 (st_ex),
      // MMU port
      .translation_req_o    (cva6_st_translation_req),
      .vaddr_o              (st_vaddr),
      .rvfi_mem_paddr_o     (rvfi_mem_paddr_o),
      .tinst_o              (st_tinst),
      .hs_ld_st_inst_o      (st_hs_ld_st_inst),
      .hlvx_inst_o          (st_hlvx_inst),
      .paddr_i              (cva6_mmu_paddr),
      .ex_i                 (cva6_mmu_exception),
      .dtlb_hit_i           (cva6_dtlb_hit),
      // Load Unit
      .page_offset_i        (page_offset),
      .page_offset_matches_o(page_offset_matches),
      // AMOs
      .amo_req_o,
      .amo_resp_i,
      // to memory arbiter
      .req_port_i           (dcache_req_ports_i[2]),
      .req_port_o           (dcache_req_ports_o[2]),
      //Trigger module
      .sdtrig_store_stall_i (sdtrig_store_stall_i),
      .sdtrig_store_action_i(sdtrig_store_action_i)
  );
// ...
  // ---------------
  // Byte Enable
  // ---------------
  // we can generate the byte enable from the virtual address since the last
  // 12 bit are the same anyway
  // and we can always generate the byte enable from the address at hand

  if (CVA6Cfg.IS_XLEN64) begin : gen_8b_be
    assign be_i = be_gen(vaddr_i[2:0], extract_transfer_size(fu_data_i.operation));
  end else begin : gen_4b_be
    assign be_i = be_gen_32(vaddr_i[1:0], extract_transfer_size(fu_data_i.operation));
  end
// ...
  // ------------------
  // LSU Control
  // ------------------
  // new data arrives here
  lsu_ctrl_t lsu_req_i;

  assign lsu_req_i = {
    lsu_valid_i,
    vaddr_i,
    tinst_i,
    hs_ld_st_inst,
    hlvx_inst,
    overflow,
    g_overflow,
    fu_data_i.operand_b,
    be_i,
    fu_data_i.fu,
    fu_data_i.operation,
    fu_data_i.trans_id,
    speculative_load_i,
    1'b0
  };
```

## Dependency declarations

### core/store_buffer.sv

```systemverilog
module store_buffer
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg        = config_pkg::cva6_cfg_empty,
    parameter type                   dcache_req_i_t = logic,
    parameter type                   dcache_req_o_t = logic,
    parameter type                   cbo_t          = logic
) (
    input logic clk_i,  // Clock
    input logic rst_ni,  // Asynchronous reset active low
    input logic flush_i,  // if we flush we need to pause the transactions on the memory
                          // otherwise we will run in a deadlock with the memory arbiter
    input logic stall_st_pending_i,  // Stall issuing non-speculative request
    output logic         no_st_pending_o, // non-speculative queue is empty (e.g.: everything is committed to the memory hierarchy)
    output logic         store_buffer_empty_o, // there is no store pending in neither the speculative unit or the non-speculative queue

    input  logic [11:0]  page_offset_i,         // check for the page offset (the last 12 bit if the current load matches them)
    output logic         page_offset_matches_o, // the above input page offset matches -> let the store buffer drain

    input logic commit_i,  // commit the instruction which was placed there most recently
    output logic commit_ready_o,  // commit queue is ready to accept another commit request
    output logic ready_o,  // the store queue is ready to accept a new request
                           // it is only ready if it can unconditionally commit the instruction, e.g.:
                           // the commit buffer needs to be empty
    input logic valid_i,  // this is a valid store
    input  logic         valid_without_flush_i, // just tell if the address is valid which we are current putting and do not take any further action

    input  logic [CVA6Cfg.PLEN-1:0]  paddr_i,         // physical address of store which needs to be placed in the queue
    output logic [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    input logic [CVA6Cfg.XLEN-1:0] data_i,  // data which is placed in the queue
    input logic [(CVA6Cfg.XLEN/8)-1:0] be_i,  // byte enable in
    input logic [1:0] data_size_i,  // type of request we are making (e.g.: bytes to write)
    input cbo_t cbo_op_i,  // type of cache block operation

    // D$ interface
    input  dcache_req_o_t req_port_i,
    output dcache_req_i_t req_port_o
);
```

## Related source code

### core/csr_regfile.sv

```systemverilog
      for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) assign sdtrig_decoder_action_o[i] = '0;
      assign sdtrig_load_stall_o = '0;
      assign sdtrig_load_cancel_o = '0;
      assign sdtrig_load_action_o = '0;
      assign sdtrig_store_stall_o = '0;
      assign sdtrig_store_action_o = '0;
      assign sdtrig_commit_icount_valid_o = '0;
      assign sdtrig_commit_action_o = '0;
```

### core/cache_subsystem/wt_dcache_wbuffer.sv

```systemverilog
        // mark bytes as dirty
        for (int k = 0; k < (CVA6Cfg.XLEN / 8); k++) begin
          if (req_port_i.data_be[k]) begin
            wbuffer_d[wr_ptr].valid[k]     = 1'b1;
            wbuffer_d[wr_ptr].dirty[k]     = 1'b1;
            wbuffer_d[wr_ptr].data[k*8+:8] = req_port_i.data_wdata[k*8+:8];
            if (CVA6Cfg.DATA_USER_EN) begin
              wbuffer_d[wr_ptr].user[k*8+:8] = req_port_i.data_wuser[k*8+:8];
            end
          end
        end
```

## Documentation

### src/rv32.adoc

```text
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
...
The LW instruction loads a 32-bit value from memory into _rd_. LH loads
a 16-bit value from memory, then sign-extends to 32-bits before storing
in _rd_. LHU loads a 16-bit value from memory but then zero extends to
32-bits before storing in _rd_. LB and LBU are defined analogously for
8-bit values. The SW, SH, and SB instructions store 32-bit, 16-bit, and
8-bit values from the low bits of register _rs2_ to memory.
```

### docs/03_cva6_design/ex_stage.md

```text
##### Store Buffer {#par:store_buffer}

The store buffer keeps track of all stores. It actually consists of two
buffers: One is for already committed instructions and one is for
outstanding instructions which are still speculative. On a flush only
the instruction which are already committed are persisted while the
speculative queue is completely emptied. To prevent buffer overflows the
two queues maintain a full flag. The full flag of the speculative queue
directly goes to the store unit, which will stall the LSU bypass module
and therefore not receive any more requests. On the contrast the full
signal of the commit queue goes to the commit stage. Commit stage will
stall if it the commit queue can't accept any new data items. On every
committed store the commit stage also asserts the `lsu_commit` signal
which will put the particular entry from the speculative queue into the
non-speculative (commit) queue.

As soon as a store is in the commit queue the queue will automatically
try to commit the oldest store in the queue to memory as soon as the
cache grants the request.

The store buffer only works with physical addresses. At the time when
they are committed the translation is already correct. For stores in the
speculative queue addresses are potentially not correct but this fact
will resolve if address translation data structures are updated as those
instructions will also automatically flush the whole speculative buffer.
```

### docs/design/design-manual/source/cva6_execute.adoc

```text
====== store_unit

The store_unit module manages the data store operations.

As stores can be speculative, the store instructions need to be committed by ISSUE_STAGE module before possibly altering the processor state.
Store buffer keeps track of store requests.
Outstanding store instructions (which are speculative) are differentiated from committed stores.
When ISSUE_STAGE module commits a store instruction, outstanding stores
become committed.

When commit buffer is not empty, the buffer automatically tries to write the oldest store to the data cache.

Furthermore, the store_unit module provides information to the load_unit to know if an outstanding store matches addresses with a load.
```
