# Implement `cva6_icache`

Implement the complete `cva6_icache` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cva6_icache` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;

// ...

  localparam CVA6ConfigAxiIdWidth = 4;  // axi_pkg.sv
  localparam CVA6ConfigAxiAddrWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigAxiDataWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigDataUserWidth = 32;  // axi_pkg.sv

// ...

      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),

// ...

      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),

// ...

      AxiAddrWidth: unsigned'(CVA6ConfigAxiAddrWidth),
      AxiDataWidth: unsigned'(CVA6ConfigAxiDataWidth),
      AxiIdWidth: unsigned'(CVA6ConfigAxiIdWidth),
      AxiUserWidth: unsigned'(CVA6ConfigDataUserWidth),
      MemTidWidth: unsigned'(CVA6ConfigAxiIdWidth),

// ...

      NOCType: config_pkg::NOC_TYPE_AXI4_ATOP,
      NrNonIdempotentRules: unsigned'(0),
      NonIdempotentAddrBase: 1024'({64'b0, 64'b0}),
      NonIdempotentLength: 1024'({64'b0, 64'b0}),

// ...

      NrCachedRegionRules: unsigned'(1),
      CachedRegionAddrBase: 1024'({64'h8000_0000}),
      CachedRegionLength: 1024'({64'h40000000}),

// ...

      IcacheByteSize: unsigned'(2048),
      IcacheSetAssoc: unsigned'(2),
      IcacheLineWidth: unsigned'(128),

// ...

      FetchUserWidth: unsigned'(32),
      FetchUserEn: unsigned'(1),
```

### core/include/build_config_pkg.sv

```systemverilog
    int unsigned ICACHE_INDEX_WIDTH = $clog2(CVA6Cfg.IcacheByteSize / CVA6Cfg.IcacheSetAssoc);

// ...

    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = IS_XLEN32 ? 34 : 56;

// ...

    cfg.TechnoCut = CVA6Cfg.TechnoCut;

// ...

    cfg.AxiAddrWidth = CVA6Cfg.AxiAddrWidth;
    cfg.AxiDataWidth = CVA6Cfg.AxiDataWidth;
    cfg.AxiIdWidth = CVA6Cfg.AxiIdWidth;
    cfg.AxiUserWidth = CVA6Cfg.AxiUserWidth;
    cfg.MEM_TID_WIDTH = CVA6Cfg.MemTidWidth;

// ...

    cfg.NOCType = CVA6Cfg.NOCType;
    cfg.NrNonIdempotentRules = CVA6Cfg.NrNonIdempotentRules;
    cfg.NonIdempotentAddrBase = CVA6Cfg.NonIdempotentAddrBase;
    cfg.NonIdempotentLength = CVA6Cfg.NonIdempotentLength;

// ...

    cfg.NrCachedRegionRules = CVA6Cfg.NrCachedRegionRules;
    cfg.CachedRegionAddrBase = CVA6Cfg.CachedRegionAddrBase;
    cfg.CachedRegionLength = CVA6Cfg.CachedRegionLength;

// ...

    cfg.NonIdemPotenceEn = (CVA6Cfg.NrNonIdempotentRules > 0) && (CVA6Cfg.NonIdempotentLength > 0);

// ...

    cfg.ICACHE_SET_ASSOC = CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_SET_ASSOC_WIDTH = CVA6Cfg.IcacheSetAssoc > 1 ? $clog2(CVA6Cfg.IcacheSetAssoc) :
        CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_INDEX_WIDTH = ICACHE_INDEX_WIDTH;
    cfg.ICACHE_TAG_WIDTH = cfg.PLEN - ICACHE_INDEX_WIDTH;
    cfg.ICACHE_LINE_WIDTH = CVA6Cfg.IcacheLineWidth;
    cfg.ICACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.IcacheLineWidth;

// ...

    cfg.FETCH_USER_WIDTH = CVA6Cfg.FetchUserWidth;
    cfg.FETCH_USER_EN = CVA6Cfg.FetchUserEn;
    cfg.AXI_USER_EN = CVA6Cfg.DataUserEn | CVA6Cfg.FetchUserEn;

    cfg.FETCH_WIDTH = unsigned'(CVA6Cfg.SuperscalarEn ? 64 : 32);
    cfg.FETCH_ALIGN_BITS = $clog2(cfg.FETCH_WIDTH / 8);
    cfg.INSTR_PER_FETCH = cfg.FETCH_WIDTH / (CVA6Cfg.RVC ? 16 : 32);
```

## Module declaration

```systemverilog
module cva6_icache
  import ariane_pkg::*;
  import wt_cache_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,
    /// ID to be used for read transactions
    parameter logic [CVA6Cfg.MEM_TID_WIDTH-1:0] RdTxId = 0
) (
    input logic clk_i,
    input logic rst_ni,

    /// flush the icache, flush and kill have to be asserted together
    input  logic         flush_i,
    /// enable icache
    input  logic         en_i,
    /// to performance counter
    output logic         miss_o,
    // address translation requests
    input  icache_areq_t areq_i,
    output icache_arsp_t areq_o,
    // data requests
    input  icache_dreq_t dreq_i,
    output icache_drsp_t dreq_o,
    // refill port
    input  logic         mem_rtrn_vld_i,
    input  icache_rtrn_t mem_rtrn_i,
    output logic         mem_data_req_o,
    input  logic         mem_data_ack_i,
    output icache_req_t  mem_data_o
);
```

## Parent instantiation

```systemverilog
  cva6_icache #(
      .CVA6Cfg(CVA6Cfg),
      .icache_areq_t(icache_areq_t),
      .icache_arsp_t(icache_arsp_t),
      .icache_dreq_t(icache_dreq_t),
      .icache_drsp_t(icache_drsp_t),
      .icache_req_t(icache_req_t),
      .icache_rtrn_t(icache_rtrn_t),
      .RdTxId(ICACHE_RDTXID)
  ) i_cva6_icache (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .flush_i       (icache_flush_i),
      .en_i          (icache_en_i),
      .miss_o        (icache_miss_o),
      .areq_i        (icache_areq_i),
      .areq_o        (icache_areq_o),
      .dreq_i        (icache_dreq_i),
      .dreq_o        (icache_dreq_o),
      .mem_rtrn_vld_i(icache_miss_resp_valid),
      .mem_rtrn_i    (icache_miss_resp),
      .mem_data_req_o(icache_miss_valid),
      .mem_data_ack_i(icache_miss_ready),
      .mem_data_o    (icache_miss)
  );
```

## Dependency declarations

### core/cva6.sv

```systemverilog
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

// ...

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
```

### core/include/wt_cache_pkg.sv

```systemverilog
  typedef enum logic [0:0] {
    ICACHE_INV_REQ,   // no ack from the core required
    ICACHE_IFILL_ACK
  } icache_in_t;
```

### core/include/config_pkg.sv

```systemverilog
  function automatic logic range_check(logic [63:0] base, logic [63:0] len, logic [63:0] address);
    // if len is a power of two, and base is properly aligned, this check could be simplified
    // Extend base by one bit to prevent an overflow.
    return (address >= base) && (({1'b0, address}) < (65'(base) + len));
  endfunction : range_check


  function automatic logic is_inside_nonidempotent_regions(cva6_cfg_t Cfg, logic [63:0] address);
    logic [NrMaxRules-1:0] pass;
    pass = '0;
    for (int unsigned k = 0; k < Cfg.NrNonIdempotentRules; k++) begin
      pass[k] = range_check(Cfg.NonIdempotentAddrBase[k], Cfg.NonIdempotentLength[k], address);
    end
    return |pass;
  endfunction : is_inside_nonidempotent_regions

// ...

  function automatic logic is_inside_cacheable_regions(cva6_cfg_t Cfg, logic [63:0] address);
    automatic logic [NrMaxRules-1:0] pass;
    pass = '0;
    for (int unsigned k = 0; k < Cfg.NrCachedRegionRules; k++) begin
      pass[k] = range_check(Cfg.CachedRegionAddrBase[k], Cfg.CachedRegionLength[k], address);
    end
    return |pass;
  endfunction : is_inside_cacheable_regions
```

### common/local/util/sram_cache.sv

```systemverilog
module sram_cache #(
    parameter DATA_WIDTH = 64,
    parameter USER_WIDTH = 1,
    parameter USER_EN    = 0,
    parameter NUM_WORDS  = 1024,
    parameter SIM_INIT   = "none",
    parameter BYTE_ACCESS = 1,
    parameter TECHNO_CUT = 0,
    parameter OUT_REGS   = 0     // enables output registers in FPGA macro (read lat = 2)
)(
   input  logic                          clk_i,
   input  logic                          rst_ni,
   input  logic                          req_i,
   input  logic                          we_i,
   input  logic [$clog2(NUM_WORDS)-1:0]  addr_i,
   input  logic [USER_WIDTH-1:0]         wuser_i,
   input  logic [DATA_WIDTH-1:0]         wdata_i,
   input  logic [(DATA_WIDTH+7)/8-1:0]   be_i,
   output logic [USER_WIDTH-1:0]         ruser_o,
   output logic [DATA_WIDTH-1:0]         rdata_o
);
```

### vendor/pulp-platform/common_cells/src/lzc.sv

```systemverilog
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

### vendor/pulp-platform/common_cells/src/lfsr.sv

```systemverilog
module lfsr #(
  parameter int unsigned          LfsrWidth     = 64,   // [4,64]
  parameter int unsigned          OutWidth      = 8,    // [1,LfsrWidth]
  parameter logic [LfsrWidth-1:0] RstVal        = '1,   // [1,2^LfsrWidth-1]
  // 0: disabled, the present cipher uses 31, but just a few layers (1-3) are enough
  // to break linear shifting patterns
  parameter int unsigned          CipherLayers  = 0,
  parameter bit                   CipherReg     = 1'b1  // additional output reg after cipher
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic                 en_i,
  output logic [OutWidth-1:0]  out_o
);
```

## Related source code

### core/frontend/frontend.sv

```systemverilog
  // Cache interface
  // Gate ICache requests and NPC updates during fence.i
  assign icache_dreq_o.req = instr_queue_ready & ~halt_frontend_i;
  assign if_ready = icache_dreq_i.ready & instr_queue_ready & ~halt_frontend_i;
  // We need to flush the cache pipeline if:
  // 1. We mispredicted
  // 2. Want to flush the whole processor front-end
  // 3. Need to replay an instruction because the fetch-fifo was full
  assign icache_dreq_o.kill_s1 = is_mispredict | flush_i | replay;
  // if we have a valid branch-prediction we need to only kill the last cache request
  // also if we killed the first stage we also need to kill the second stage (inclusive flush)
  assign icache_dreq_o.kill_s2 = icache_dreq_o.kill_s1 | bp_valid;
```

### core/cache_subsystem/cva6_icache_axi_wrapper.sv

```systemverilog
  // Keep read request asserted until we have an AXI grant. This is not guaranteed by icache (but
  // required by AXI).
  assign req_valid_d           = ~axi_rd_gnt & (icache_mem_data_req | req_valid_q);

  // Update read request information on a new request
  assign req_data_d            = (icache_mem_data_req) ? icache_mem_data : req_data_q;

  // We have a new or pending read request
  assign axi_rd_req            = icache_mem_data_req | req_valid_q;
  assign axi_rd_addr           = CVA6Cfg.AxiAddrWidth'(req_data_d.paddr);

  // Fetch a full cache line on a cache miss, or a single word on a bypassed access
  assign axi_rd_blen           = (req_data_d.nc) ? '0 : CVA6Cfg.ICACHE_LINE_WIDTH / 64 - 1;
  assign axi_rd_size           = $clog2(CVA6Cfg.AxiDataWidth / 8);  // Maximum
  assign axi_rd_id_in          = req_data_d.tid;
  assign axi_rd_rdy            = 1'b1;
  assign axi_rd_lock           = 1'b0;

  // Immediately acknowledge read request. This is an implicit requirement for the icache.
  assign icache_mem_data_ack   = icache_mem_data_req;

  // Return data as soon as last word arrives
  assign icache_mem_rtrn_vld   = axi_rd_valid & axi_rd_last;
  assign icache_mem_rtrn.data  = rd_shift_d;
  assign icache_mem_rtrn.tid   = req_data_q.tid;
  assign icache_mem_rtrn.rtype = wt_cache_pkg::ICACHE_IFILL_ACK;
  assign icache_mem_rtrn.inv   = '0;

// ...

  // Buffer burst data in shift register
  always_comb begin : p_axi_rtrn_shift
    first_d    = first_q;
    rd_shift_d = rd_shift_q;

    if (axi_rd_valid) begin
      first_d = axi_rd_last;
      if (CVA6Cfg.ICACHE_LINE_WIDTH == CVA6Cfg.AxiDataWidth) begin
        rd_shift_d = axi_rd_data;
      end else begin
        rd_shift_d = {axi_rd_data, rd_shift_q[CVA6Cfg.ICACHE_LINE_WIDTH/CVA6Cfg.AxiDataWidth-1:1]};
      end

      // If this is a single word transaction, we need to make sure that word is placed at offset 0
      if (first_q) begin
        rd_shift_d[0] = axi_rd_data;
      end
    end
  end

  // Registers
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_rd_buf
    if (!rst_ni) begin
      req_valid_q <= 1'b0;
      req_data_q  <= '0;
      first_q     <= 1'b1;
      rd_shift_q  <= '0;
    end else begin
      req_valid_q <= req_valid_d;
      req_data_q  <= req_data_d;
      first_q     <= first_d;
      rd_shift_q  <= rd_shift_d;
    end
```

### corev_apu/tb/tb_cva6_icache/hdl/tb.sv

```systemverilog
// Description: testbench for icache. includes the following tests:
//
// 0) random accesses with disabled cache
// 1) random accesses with enabled cache to cacheable and noncacheable memory
// 2) linear, wrapping sweep with enabled cache
// 3) 1) with random stalls on the memory side and TLB side
// 4) nr 3) with random invalidations
//
// note that we use a simplified address translation scheme to emulate the TLB.
// (random offsets).

// ...

  task automatic genRandReq();
    automatic bit ok;
    automatic logic [63:0] val;
    dreq_i.req     = 0;
    dreq_i.kill_s1 = 0;
    dreq_i.kill_s2 = 0;
    num_vectors    = 100000;
    stim_end       = 0;

    stim_start     = 1;
    `APPL_WAIT_CYC(clk_i,10)
    stim_start     = 0;

    // start with clean cache
    flush_i        = 1;
    `APPL_WAIT_CYC(clk_i,1)
    flush_i        = 0;

     while(~acq_done) begin
      // randomize request
      dreq_i.req = 0;
      ok = randomize(val) with {val > 0; val <= 100;};
      if (val < SeqRate) begin
        dreq_i.req = 1;
        // generate random address
        ok = randomize(val) with {val >= 0; val < (MemBytes-TlbOffset)>>2;};
        dreq_i.vaddr = val<<2;// align to 4Byte
        // generate random control events
        ok = randomize(val) with {val > 0; val <= 100;};
        dreq_i.kill_s1 = (val < S1KillRate);
        ok = randomize(val) with {val > 0; val <= 100;};
        dreq_i.kill_s2 = (val < S2KillRate);
        ok = randomize(val) with {val > 0; val <= 100;};
        flush_i = (val < FlushRate);
        `APPL_WAIT_SIG(clk_i, dut_in_rdy)
      end else begin
        `APPL_WAIT_CYC(clk_i,1)
      end
    end
    stim_end       = 1;
  endtask : genRandReq


  task automatic genSeqRead();
    automatic bit ok;
    automatic logic [63:0] val;
    automatic logic [63:0] addr;
    dreq_i.req     = 0;
    dreq_i.kill_s1 = 0;
    dreq_i.kill_s2 = 0;
    num_vectors    = 32*4*1024;
    addr           = 0;
    stim_end       = 0;

    stim_start     = 1;
    `APPL_WAIT_CYC(clk_i,10)
    stim_start     = 0;

    // start with clean cache
    flush_i        = 1;
    `APPL_WAIT_CYC(clk_i,1)
    flush_i        = 0;

    while(~acq_done) begin
      dreq_i.req = 1;
      dreq_i.vaddr = addr;
      // generate linear read
      addr = (addr + 4) % (MemBytes - TlbOffset);
      `APPL_WAIT_SIG(clk_i, dut_in_rdy)
    end
    stim_end       = 1;
  endtask : genSeqRead

// ...

  // connect interface to expected response channel of memory emulation
  assign stim_vaddr = dreq_i.vaddr;
  assign stim_push  = dreq_i.req & dreq_o.ready & (~dreq_i.kill_s1) & (~flush_i);
  assign stim_flush = 0;
  assign exp_pop    = (dreq_o.valid | dreq_i.kill_s2) & (~exp_empty);

///////////////////////////////////////////////////////////////////////////////
// stimuli application process
///////////////////////////////////////////////////////////////////////////////

  assign dut_in_rdy = dreq_o.ready;

// ...

    // TEST 0
    en_i = 0;
    genRandReq();
    `APPL_WAIT_CYC(clk_i,200);
    ///////////////////////////////////////////////
    // TEST 1
    test_name = "TEST1, enabled cache";
    en_i = 1;
    genRandReq();
    `APPL_WAIT_CYC(clk_i,200);
    ///////////////////////////////////////////////
    // TEST 2
    test_name = "TEST2, enabled cache, sequential reads";
    en_i        = 1;
    genSeqRead();
    `APPL_WAIT_CYC(clk_i,200);
    ///////////////////////////////////////////////
    // TEST 3
    test_name = "TEST3, enabled cache, random stalls in mem and TLB side";
    en_i        = 1;
    mem_rand_en = 1;
    tlb_rand_en = 1;
    genRandReq();
    `APPL_WAIT_CYC(clk_i,200);
    ///////////////////////////////////////////////
    // TEST 4
    test_name = "TEST4, +random invalidations";
    en_i        = 1;
    mem_rand_en = 1;
    tlb_rand_en = 1;
    inv_rand_en = 1;
    genRandReq();
    `APPL_WAIT_CYC(clk_i,200);

// ...

  assign dut_out_vld = dreq_o.valid;

// ...

        // wait for response
        `ACQ_WAIT_SIG(clk_i, dut_out_vld);

        ok=(dreq_o.data == exp_data[FETCH_WIDTH-1:0]) && (dreq_o.vaddr == exp_vaddr);
```

### corev_apu/tb/tb_cva6_icache/hdl/mem_emul.sv

```systemverilog
  // sequential process holding the state of the memory readout process
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_tlb_rand
    automatic bit ok  = 0;
    automatic int rnd = 0;
    automatic logic [31:0] val;
    automatic logic [63:0] lval;

    if(~rst_ni) begin
      mem_ready_q   <= '0;
      mem_inv_q     <= '0;
      rand_addr_q   <= '0;
      initialized_q <= '0;
    end else begin

      // fill the memory once with random data
      if (~initialized_q) begin
        for (int k=0; k<MemWords; k++) begin
          ok=randomize(val);
          mem_array[k]        <= val;
          mem_array_shadow[k] <= val;
        end
          initialized_q       <= 1;
      end

      // re-randomize noncacheable I/O space if requested
      if (io_rand_en_i) begin
        for (int k=0; k<CachedAddrBeg; k++) begin
          ok = randomize(val);
          mem_array[k]        <= val;
        end
      end

      // generate random contentions
      if (mem_rand_en_i) begin
        ok = randomize(rnd) with {rnd > 0; rnd <= 100;};
        if(rnd < MemRandHitRate) begin
          mem_ready_q <= '1;
        end else
          mem_ready_q <= '0;
      end else begin
        mem_ready_q <= '1;
      end

      // generate random invalidations

      if (inv_rand_en_i) begin
        if (infifo_push) begin
          // update coherent memory view for expected responses
          while(inval_addr_queue.size()>0)begin
            lval = inval_addr_queue.pop_back();
            val  = inval_data_queue.pop_back();
            mem_array_shadow[lval] <= val;
          end
        end

        ok = randomize(rnd) with {rnd > 0; rnd <= 100;};
        if(rnd < MemRandInvRate) begin
          mem_inv_q = '1;
          ok = randomize(lval) with {lval>=0; lval<MemWords;};
          ok = randomize(val);
          // save for coherent view above
          inval_addr_queue.push_front(lval);
          inval_data_queue.push_front(val);
          // overwrite the memory with new random data value
          rand_addr_q     <= lval<<2;
          mem_array[lval] <= val;
        end else begin
          mem_inv_q <= '0;
        end
      end
    end
  end

// ...

  // readout process
  always_comb begin : proc_mem
    infifo_push       = 0;
    infifo_data       = '0;
    outfifo_pop       = 0;
    infifo_data.rtype = ICACHE_IFILL_ACK;

    // generate random invalidation
    if (mem_inv_q) begin

      infifo_data.rtype = ICACHE_INV_REQ;

      // since we do not keep a mirror tag table here,
      // we always invalidate all ways of the aliased index.
      // this is not entirely correct and will produce
      // too many invalidations
      infifo_data.inv.idx = rand_addr_q[CVA6Cfg.ICACHE_INDEX_WIDTH-1:0];
      infifo_data.inv.all = '1;
      infifo_push         = 1'b1;

    end else if ((~outfifo_empty) && (~infifo_full) && mem_ready_q) begin
      outfifo_pop     = 1'b1;
      infifo_push     = 1'b1;

      // address goes to I/O space
      if (outfifo_data.nc) begin
        // replicate words (this is done in openpiton, too)
        // note: openpiton replicates the words here.
        for (int k=0; k<ICACHE_LINE_WIDTH/32; k++) begin
          infifo_data.data[k*32 +:32] = mem_array[outfifo_data.paddr>>2];
        end
        infifo_data.data[0 +:32] = mem_array[outfifo_data.paddr>>2];
      end else begin
        // replicate words (this is done in openpiton, too)
        for (int k=0; k<ICACHE_LINE_WIDTH/32; k++) begin
          infifo_data.data[k*32 +:32] = mem_array[(outfifo_data.paddr>>2) + k];
        end
      end
    end
  end

// ...

  assign outfifo_push   = mem_data_req_i & (~outfifo_full);
  assign mem_data_ack_o = outfifo_push;

  fifo_v3 #(
    .dtype(icache_rtrn_t),
    .DEPTH(2)
  ) i_infifo (
    .clk_i       ( clk_i         ),
    .rst_ni      ( rst_ni        ),
    .flush_i     ( 1'b0          ),
    .testmode_i  ( 1'b0          ),
    .full_o      ( infifo_full   ),
    .empty_o     ( infifo_empty  ),
    .usage_o     (               ),
    .data_i      ( infifo_data   ),
    .push_i      ( infifo_push   ),
    .data_o      ( mem_rtrn_o    ),
    .pop_i       ( infifo_pop    )
  );

  assign infifo_pop     = ~infifo_empty;
  assign mem_rtrn_vld_o = infifo_pop;

// ...

  assign exp_empty_o = exp_empty | stim_flush_i;
  // use last seen memory state in case random invalidations are present
  assign exp_data_o  = (inv_rand_en_i) ? mem_array_shadow[(stim_addr>>2) + (tlb_offset_i>>2)] :
                                         mem_array       [(stim_addr>>2) + (tlb_offset_i>>2)];
  assign exp_vaddr_o = stim_addr;

  align0: assert property (
    @(posedge clk_i) disable iff (~rst_ni) ~exp_empty |-> stim_addr[1:0] == 0)
       else $fatal(1,"stim_addr is not 32bit word aligned");

  align1: assert property (
    @(posedge clk_i) disable iff (~rst_ni) ~outfifo_empty |-> outfifo_data.paddr[1:0] == 0)
       else $fatal(1,"paddr is not 32bit word aligned");
```
