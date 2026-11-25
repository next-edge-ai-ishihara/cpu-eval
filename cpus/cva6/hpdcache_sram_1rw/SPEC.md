# Implement `hpdcache_sram_1rw`

Implement the complete `hpdcache_sram_1rw` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_sram_1rw` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Documentation

### `docs/source/architecture.rst`

```text
The HPDcache cache uses SRAM macros for the directory and data parts of the
cache. These RAM macros are synchronous, read/write, single-port RAMs.

...

   Read latency is one cycle.

```
