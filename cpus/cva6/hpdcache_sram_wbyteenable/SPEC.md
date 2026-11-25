# Implement `hpdcache_sram_wbyteenable`

Implement the complete `hpdcache_sram_wbyteenable` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_sram_wbyteenable` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_sram_wbyteenable
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1,
    parameter bit          ECC_EN = 1'b0
)
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata,

    input  logic                              err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   err_inj_msk_i,
    output logic [NDATA-1:0]                  err_cor_o,
    output logic [NDATA-1:0]                  err_unc_o
);

```

## Dependency declarations

### `rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv`

```systemverilog
module hpdcache_sram_wbyteenable_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata
);

```

### `rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_ecc_1rw.sv`

```systemverilog
module hpdcache_sram_wbyteenable_ecc_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata,

    input  logic                              err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   err_inj_msk_i,
    output logic [NDATA-1:0]                  err_cor_o,
    output logic [NDATA-1:0]                  err_unc_o
);

```
