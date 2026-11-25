# Implement `hpdcache_sram`

Implement one complete `hpdcache_sram` module for the selected CPU configuration shown below. Preserve the module name, parameters, and ports.

Return only the complete `module hpdcache_sram` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
      DCacheType: config_pkg::HPDCACHE_WT,
      DcacheByteSize: unsigned'(2028),
      DcacheSetAssoc: unsigned'(2),
      DcacheLineWidth: unsigned'(128),
      DcacheFlushOnFence: bit'(0),
      DcacheFlushOnFenceI: bit'(0),
      DcacheInvalidateOnFlush: bit'(0),
      DcacheEccEnable: bit'(0),
      DcacheEccScrubberEnable: bit'(0),

```

## Module declaration

```systemverilog
module hpdcache_sram
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1,
    parameter bit          ECC_EN = 1'b0
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            cs,
    input  logic                            we,
    input  logic [ADDR_SIZE-1:0]            addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wdata,
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata,

    input  logic                            err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] err_inj_msk_i,
    output logic [NDATA-1:0]                err_cor_o,
    output logic [NDATA-1:0]                err_unc_o
);

```

## Parent instantiation

### `rtl/src/hpdcache_memctrl.sv`

```systemverilog
        //  Directory
        //
        for (dir_w = 0; dir_w < int'(HPDcacheCfg.u.ways); dir_w++) begin : gen_dir_sram
            hpdcache_sram #(
                .ADDR_SIZE (HPDCACHE_DIR_RAM_ADDR_WIDTH),
                .DATA_SIZE (HPDCACHE_DIR_RAM_WIDTH),
                .NDATA     (1),
                .ECC_EN    (HPDcacheCfg.u.eccEn)
            ) dir_sram(
                .clk           (clk_i),
                .rst_n         (rst_ni),
                .cs            (dir_cs[dir_w]),
                .we            (dir_we[dir_w]),
                .addr          (dir_addr),
                .wdata         (dir_wentry[dir_w]),
                .rdata         (dir_rentry[dir_w]),
                .err_inj_i     (1'b0),
                .err_inj_msk_i ('0),
                .err_cor_o     (dir_err_cor_o[dir_w]),
                .err_unc_o     (dir_err_unc_o[dir_w])
            );
            assign dir_err_valid_o[dir_w] = dir_rentry[dir_w].valid;
            assign dir_err_dirty_o[dir_w] = dir_rentry[dir_w].dirty;
        end

```

## Dependency declarations

### `rtl/src/common/macros/behav/hpdcache_sram_1rw.sv`

```systemverilog
module hpdcache_sram_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            cs,
    input  logic                            we,
    input  logic [ADDR_SIZE-1:0]            addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wdata,
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata
);

```

### `rtl/src/common/macros/behav/hpdcache_sram_ecc_1rw.sv`

```systemverilog
module hpdcache_sram_ecc_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            cs,
    input  logic                            we,
    input  logic [ADDR_SIZE-1:0]            addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wdata,
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata,

    input  logic                            err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] err_inj_msk_i,
    output logic [NDATA-1:0]                err_cor_o,
    output logic [NDATA-1:0]                err_unc_o
);

```
