# Implement `pmp_data_if`

Implement the complete `pmp_data_if` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module pmp_data_if` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv64a6_imafdc_sv39_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 64;
// ...
  localparam CVA6ConfigHExtEn = 0;  // always disabled
// ...
  localparam CVA6ConfigTvalEn = 1;

  localparam CVA6ConfigNrPMPEntries = 8;
// ...
  localparam CVA6ConfigMmuPresent = 1;
// ...
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(64),
// ...
      RVH: bit'(CVA6ConfigHExtEn),
// ...
      MmuPresent: bit'(CVA6ConfigMmuPresent),
// ...
      TvalEn: bit'(CVA6ConfigTvalEn),
      DirectVecOnly: bit'(0),
      NrPMPEntries: unsigned'(CVA6ConfigNrPMPEntries),
// ...
      NrExecuteRegionRules: unsigned'(3),
      ExecuteRegionAddrBase: 1024'({64'h8000_0000, 64'h1_0000, 64'h0}),
      ExecuteRegionLength: 1024'({64'h40000000, 64'h10000, 64'h1000}),
```

## Module declaration

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

## Parent instantiation

### core/load_store_unit.sv

```systemverilog
  pmp_data_if #(
      .CVA6Cfg      (CVA6Cfg),
      .icache_areq_t(icache_areq_t),
      .exception_t  (exception_t)
  ) i_pmp_data_if (
      .clk_i               (clk_i),
      .rst_ni              (rst_ni),
      .icache_areq_i       (pmp_icache_areq_i),
      .icache_areq_o       (icache_areq_o),
      .icache_fetch_vaddr_i(icache_areq_i.fetch_vaddr),
      .lsu_valid_i         (pmp_translation_valid),
      .lsu_paddr_i         (lsu_paddr),
      .lsu_vaddr_i         (mmu_vaddr),
      .lsu_exception_i     (pmp_exception),
      .lsu_is_store_i      (st_translation_req),
      .lsu_valid_o         (translation_valid),
      .lsu_paddr_o         (mmu_paddr),
      .lsu_exception_o     (mmu_exception),
      .priv_lvl_i          (priv_lvl_i),
      .v_i                 (v_i),
      .ld_st_priv_lvl_i    (ld_st_priv_lvl_i),
      .ld_st_v_i           (ld_st_v_i),
      .pmpcfg_i            (pmpcfg_i),
      .pmpaddr_i           (pmpaddr_i)
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

    // cache request ports
    // I$ address translation requests
    localparam type icache_areq_t = struct packed {
      logic                    fetch_valid;      // address translation valid
      logic [CVA6Cfg.PLEN-1:0] fetch_paddr;      // physical address in
      exception_t              fetch_exception;  // exception occurred during fetch
    },
```

### core/include/config_pkg.sv

```systemverilog
package config_pkg;
// ...
  function automatic logic is_inside_execute_regions(cva6_cfg_t Cfg, logic [63:0] address);
    // if we don't specify any region we assume everything is accessible
    logic [NrMaxRules-1:0] pass;
    if (Cfg.NrExecuteRegionRules != 0) begin
      pass = '0;
      for (int unsigned k = 0; k < Cfg.NrExecuteRegionRules; k++) begin
        pass[k] = range_check(Cfg.ExecuteRegionAddrBase[k], Cfg.ExecuteRegionLength[k], address);
      end
      return |pass;
    end else begin
      return 1;
    end
  endfunction : is_inside_execute_regions
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
// ...
  // PMP Access Type
  typedef enum logic [2:0] {
    ACCESS_NONE  = 3'b000,
    ACCESS_READ  = 3'b001,
    ACCESS_WRITE = 3'b010,
    ACCESS_EXEC  = 3'b100
  } pmp_access_t;
```

### core/pmp/src/pmp.sv

```systemverilog
module pmp
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Input
    input logic [CVA6Cfg.PLEN-1:0] addr_i,
    input riscv::pmp_access_t access_type_i,
    input riscv::priv_lvl_t priv_lvl_i,
    // Configuration
    input logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] conf_addr_i,
    input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] conf_i,
    // Output
    output logic allow_o
);
```

## Documentation

### docs/design/design-manual/source/mmu.adoc

```text
If the fetch physical address doesn't match any execute region, an
Instruction Access Fault is raised. When not translating, PMPs are
immediately checked against the physical address for access
verification.
...
When address translation is not enabled, the physical address is
immediately checked against Physical Memory Protections (PMPs). If there
is a request from LSU, no misaligned exception, and PMPs are violated,
it results in an access fault corresponding to the request being
indicated.
```
