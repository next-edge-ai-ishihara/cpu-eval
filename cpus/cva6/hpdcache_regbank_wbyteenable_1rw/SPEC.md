# Implement `hpdcache_regbank_wbyteenable_1rw`

Implement the complete `hpdcache_regbank_wbyteenable_1rw` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_regbank_wbyteenable_1rw` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
        //  MSHR macros implement write byte enable
        //  -  Write byte enable (1'b1)
        //  -  Write bit mask (1'b0)
        bit mshrRamByteEnable;
        //  MSHR uses whether FFs or SRAM
        bit mshrUseRegbank;

```

## Module declaration

```systemverilog
module hpdcache_regbank_wbyteenable_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE
)
(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   cs,
    input  logic                   we,
    input  logic [ADDR_SIZE-1:0]   addr,
    input  logic [DATA_SIZE-1:0]   wdata,
    input  logic [DATA_SIZE/8-1:0] wbyteenable,
    output logic [DATA_SIZE-1:0]   rdata
);

```

## Parent instantiation

### `rtl/src/hpdcache_mshr.sv`

```systemverilog
    typedef logic [HPDCACHE_MSHR_RAM_ENTRY_BITS/8-1:0] mshr_sram_wbyteenable_t;
    typedef logic [HPDCACHE_MSHR_RAM_ENTRY_BITS-1:0] mshr_sram_wmask_t;
    if (HPDcacheCfg.u.mshrRamByteEnable) begin : gen_mshr_wbyteenable
        mshr_sram_wbyteenable_t [HPDcacheCfg.u.mshrWays-1:0] mshr_wbyteenable;

        always_comb
        begin : mshr_wbyteenable_comb
            for (int unsigned i = 0; i < HPDcacheCfg.u.mshrWays; i++) begin
                mshr_wbyteenable[i] = (hpdcache_uint32'(alloc_way_o) == i) ? '1 : '0;
            end
        end

        if (HPDcacheCfg.u.mshrUseRegbank) begin : gen_mshr_regbank
            hpdcache_regbank_wbyteenable_1rw #(
                .DATA_SIZE     (HPDcacheCfg.u.mshrWays*HPDCACHE_MSHR_RAM_ENTRY_BITS),
                .ADDR_SIZE     (HPDcacheCfg.mshrSetWidth),
                .DEPTH         (HPDcacheCfg.u.mshrSets)
            ) mshr_mem(
                .clk           (clk_i),
                .rst_n         (rst_ni),
                .cs            (mshr_cs),
                .we            (mshr_we),
                .addr          (mshr_addr),
                .wbyteenable   (mshr_wbyteenable),
                .wdata         (mshr_wdata),
                .rdata         (mshr_rdata)
            );
        end else begin : gen_mshr_sram
            hpdcache_sram_wbyteenable #(
                .DATA_SIZE     (HPDCACHE_MSHR_RAM_ENTRY_BITS),
                .ADDR_SIZE     (HPDcacheCfg.mshrSetWidth),
                .DEPTH         (HPDcacheCfg.u.mshrSets),
                .NDATA         (HPDcacheCfg.u.mshrWays)
            ) mshr_mem(
                .clk           (clk_i),
                .rst_n         (rst_ni),
                .cs            (mshr_cs),
                .we            (mshr_we),
                .addr          (mshr_addr),
                .wbyteenable   (mshr_wbyteenable),
                .wdata         (mshr_wdata),
                .rdata         (mshr_rdata),
                .err_inj_i     (1'b0),
                .err_inj_msk_i ('0),
                .err_cor_o     (/*open*/),
                .err_unc_o     (/*open*/)
            );
        end

```

## Documentation

### `docs/source/architecture.rst`

```text
The HPDcache cache uses SRAM macros for the directory and data parts of the
cache. These RAM macros are synchronous, read/write, single-port RAMs.

The organization of the RAMs, for the directory and the data, targets the
following:

#. **High memory bandwidth to/from the requesters**

   The organization allows to read 1, 2, 4, 8, 16, 32 or 64 bytes per cycle. The
   maximum number of bytes per cycle is a configuration parameter of the cache.
   Read latency is one cycle.

```
