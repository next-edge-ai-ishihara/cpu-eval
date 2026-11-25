# Implement `sram_cache`

Implement the complete `sram_cache` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module sram_cache` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      TechnoCut: bit'(1),
// ...
      DataUserEn: unsigned'(1),
// ...
      FetchUserWidth: unsigned'(32),
      FetchUserEn: unsigned'(1),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.ICACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.IcacheLineWidth;
// ...
    cfg.DCACHE_USER_WIDTH = CVA6Cfg.AxiUserWidth;
// ...
    cfg.DATA_USER_EN = CVA6Cfg.DataUserEn;
// ...
    cfg.FETCH_USER_EN = CVA6Cfg.FetchUserEn;
```

## Module declaration

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

## Parent instantiation

### core/cache_subsystem/cva6_icache.sv

```systemverilog
    sram_cache #(
        // tag + valid bit
        .DATA_WIDTH (CVA6Cfg.ICACHE_TAG_WIDTH + 1),
        .BYTE_ACCESS(0),
        .TECHNO_CUT (CVA6Cfg.TechnoCut),
        .NUM_WORDS  (ICACHE_NUM_WORDS)
    ) tag_sram (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .req_i  (vld_req[i]),
        .we_i   (vld_we),
        .addr_i (vld_addr),
        // we can always use the saved tag here since it takes a
        // couple of cycle until we write to the cache upon a miss
        .wuser_i('0),
        .wdata_i({vld_wdata[i], cl_tag_q}),
        .be_i   ('1),
        .ruser_o(),
        .rdata_o(cl_tag_valid_rdata[i])
    );
// ...
    sram_cache #(
        .USER_WIDTH (CVA6Cfg.ICACHE_USER_LINE_WIDTH),
        .DATA_WIDTH (CVA6Cfg.ICACHE_LINE_WIDTH),
        .USER_EN    (CVA6Cfg.FETCH_USER_EN),
        .BYTE_ACCESS(0),
        .TECHNO_CUT (CVA6Cfg.TechnoCut),
        .NUM_WORDS  (ICACHE_NUM_WORDS)
    ) data_sram (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .req_i  (cl_req[i]),
        .we_i   (cl_we),
        .addr_i (cl_index),
        .wuser_i(mem_rtrn_i.user),
        .wdata_i(mem_rtrn_i.data),
        .be_i   ('1),
        .ruser_o(cl_ruser[i]),
        .rdata_o(cl_rdata[i])
    );
```

### core/cache_subsystem/wt_dcache_mem.sv

```systemverilog
    sram_cache #(
        .USER_WIDTH (CVA6Cfg.DCACHE_SET_ASSOC * CVA6Cfg.DCACHE_USER_WIDTH),
        .DATA_WIDTH (CVA6Cfg.DCACHE_SET_ASSOC * CVA6Cfg.XLEN),
        .USER_EN    (CVA6Cfg.DATA_USER_EN),
        .BYTE_ACCESS(1),
        .TECHNO_CUT (CVA6Cfg.TechnoCut),
        .NUM_WORDS  (CVA6Cfg.DCACHE_NUM_WORDS)
    ) i_data_sram (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .req_i  (bank_req[k]),
        .we_i   (bank_we[k]),
        .addr_i (bank_idx[k]),
        .wuser_i(bank_wuser[k]),
        .wdata_i(bank_wdata[k]),
        .be_i   (bank_be[k]),
        .ruser_o(bank_ruser[k]),
        .rdata_o(bank_rdata[k])
    );
```

## Dependency declarations

### common/local/util/tc_sram_wrapper_cache_techno.sv

```systemverilog
// Copy of tc_sram_wrapper_cache
// To be replaced by the wrapper of the technology used to avoid having black box at synthesis

module tc_sram_wrapper_cache_techno #(
  parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
  parameter int unsigned DataWidth    = 32'd128,  // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
  parameter int unsigned NumPorts     = 32'd2,    // Number of read and write ports
  parameter int unsigned Latency      = 32'd1,    // Latency when the read data is available
  parameter              SimInit      = "none",   // Simulation initialization
  parameter              BYTE_ACCESS  = 1,
  parameter bit          PrintSimCfg  = 1'b0,     // Print configuration
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic                 clk_i,      // Clock
  input  logic                 rst_ni,     // Asynchronous reset active low
  // input ports
  input  logic  [NumPorts-1:0] req_i,      // request
  input  logic  [NumPorts-1:0] we_i,       // write enable
  input  addr_t [NumPorts-1:0] addr_i,     // request address
  input  data_t [NumPorts-1:0] wdata_i,    // write data
  input  be_t   [NumPorts-1:0] be_i,       // write byte enable
  // output ports
  output data_t [NumPorts-1:0] rdata_o     // read data
);
```

## Related source code

### vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv

```systemverilog
// Description: Functional module of a generic SRAM
//
// Parameters:
// - NumWords:    Number of words in the macro. Address width can be calculated with:
//                `AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1`
//                The module issues a warning if there is a request on an address which is
//                not in range.
// - DataWidth:   Width of the ports `wdata_i` and `rdata_o`.
// - ByteWidth:   Width of a byte, the byte enable signal `be_i` can be calculated with the
//                ceiling division `ceil(DataWidth, ByteWidth)`.
// - NumPorts:    Number of read and write ports. Each is a full port. Ports with a higher
//                index read and write after the ones with lower indices.
// - Latency:     Read latency, the read data is available this many cycles after a request.
// - SimInit:     Macro simulation initialization. Values are:
//                "zeros":  Each bit gets initialized with 1'b0.
//                "ones":   Each bit gets initialized with 1'b1.
//                "random": Each bit gets random initialized with 1'b0 or 1'b1.
//                "none":   Each bit gets initialized with 1'bx. (default)
// ...
// Ports:
// - `clk_i`:   Clock
// - `rst_ni`:  Asynchronous reset, active low
// - `req_i`:   Request, active high
// - `we_i`:    Write request, active high
// - `addr_i`:  Request address
// - `wdata_i`: Write data, has to be valid on request
// - `be_i`:    Byte enable, active high
// - `rdata_o`: Read data, valid `Latency` cycles after a request with `we_i` low.
// ...
// - Read data on write: This implementation will not produce a read data output on the signal
//                       `rdata_o` when `req_i` and `we_i` are asserted. The output data is stable
//                       on write requests.
```
