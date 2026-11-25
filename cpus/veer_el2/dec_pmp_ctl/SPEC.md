# Implement `el2_dec_pmp_ctl`

Implement the complete `el2_dec_pmp_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dec_pmp_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog

module el2_dec_pmp_ctl
  import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic clk,
   input logic free_l2clk,
   input logic csr_wr_clk,
   input logic rst_l,
   input logic        dec_csr_wen_r_mod,  // csr write enable at wb
   input logic [11:0] dec_csr_wraddr_r,   // write address for csr
   input logic [31:0] dec_csr_wrdata_r,   // csr write data at wb
   input logic [11:0] dec_csr_rdaddr_d,   // read address for csr

   input logic csr_pmpcfg,
   input logic csr_pmpaddr0,
   input logic csr_pmpaddr16,
   input logic csr_pmpaddr32,
   input logic csr_pmpaddr48,

   input logic dec_pause_state, // Paused
   input logic dec_tlu_pmu_fw_halted, // pmu/fw halted
   input logic internal_dbg_halt_timers, // debug halted

`ifdef RV_SMEPMP
   input el2_mseccfg_pkt_t mseccfg,
`endif

   output logic [31:0] dec_pmp_rddata_d,  // pmp CSR read data
   output logic        dec_pmp_read_d,    // pmp CSR address match

   output el2_pmp_cfg_pkt_t pmp_pmpcfg  [pt.PMP_ENTRIES],
   output logic [31:0]      pmp_pmpaddr [pt.PMP_ENTRIES],

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic        scan_mode
   /*pragma coverage on*/
   );
```

## Parent instantiation

### `design/dec/el2_dec_tlu_ctl.sv`

```systemverilog
   el2_dec_pmp_ctl  #(.pt(pt)) pmp(.*);
// ...
`ifdef RV_USER_MODE
   assign dec_csr_wen_r_mod = dec_csr_wen_r & ~i0_trigger_hit_r & ~rfpc_i0_r & ~csr_acc_r;
`else
   assign dec_csr_wen_r_mod = dec_csr_wen_r & ~i0_trigger_hit_r & ~rfpc_i0_r;
`endif
```

## Dependency declarations

### `design/include/el2_def.sv`

```systemverilog
  typedef enum logic [1:0] {
    OFF   = 2'b00,
    TOR   = 2'b01,
    NA4   = 2'b10,
    NAPOT = 2'b11
  } el2_pmp_mode_pkt_t;


  typedef struct packed {
    logic lock;
    logic [1:0] reserved;
    el2_pmp_mode_pkt_t mode;
    logic execute;
    logic write;
    logic read;
  } el2_pmp_cfg_pkt_t;
```

### `design/lib/beh_lib.sv`

```systemverilog


module rvdffe #( parameter WIDTH=1, SHORT=0, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic           en,
     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
if (SHORT == 1) begin : genblock
   if (1) begin : genblock
      assign dout = din;
   end
end
else begin : genblock

`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffe must be WIDTH >= 8");
`endif
end // else: !if(SHORT == 1)
```

## Related source code

### `design/dec/csrdecode_m`

```text
csr_pmpcfg =        [00111010....]
csr_pmpaddr0 =      [00111011....]
csr_pmpaddr16 =     [00111100....]
csr_pmpaddr32 =     [00111101....]
csr_pmpaddr48 =     [00111110....]

.input

csr = {
        dec_csr_rdaddr_d[11]
        dec_csr_rdaddr_d[10]
        dec_csr_rdaddr_d[9]
        dec_csr_rdaddr_d[8]
        dec_csr_rdaddr_d[7]
        dec_csr_rdaddr_d[6]
        dec_csr_rdaddr_d[5]
        dec_csr_rdaddr_d[4]
        dec_csr_rdaddr_d[3]
        dec_csr_rdaddr_d[2]
        dec_csr_rdaddr_d[1]
        dec_csr_rdaddr_d[0]
}
```

## Documentation

### `docs/source/physical-memory-protection.md`

```text
## Physical Memory Protection CSRs

The `pmpcfgX` and `pmpaddrX` CSRs are implemented in the [*el2_dec_tlu_ctl* module](../../design/dec/el2_dec_tlu_ctl.sv).
CSR address decoding is generated from either [*csrdecode_m*](../../design/dec/csrdecode_m) (Machine mode) or [*csrdecode_mu*](../../design/dec/csrdecode_mu) (Machine and User mode) description file.

The number of `pmpcfgX` registers is always 4 times smaller than the number of PMP entries, which are configurable using the `-set=pmp_entires=N` option, where *N* can be 0, 16 or 64.

:::{list-table} CSR configurations for RV-32
:name: tab-riscv-pmp-csr-configuration-table
:header-rows: 1
:align: left
* - Number of PMP entries
  - Number of *pmpcfgX* CSRs
  - Number of *pmpaddrX* CSRs
* - 0
  - 0
  - 0
* - 16
  - 4
  - 16
* - 64
  - 16
  - 64
:::

### Configuration Registers (pmpcfgX)

Each `pmpcfgX` register holds a configuration for four PMP entries, with a byte used for each entry.

:::{list-table} Decoding of the *pmpcfgX* register
:name: tab-riscv-pmpcfgx-register
:header-rows: 1
:align: left
* - **Bit**
  - 7
  - 6
  - 5
  - 4
  - 3
  - 2
  - 1
  - 0
* - **Flag**
  - *L*
  - *0*
  - *0*
  - *A[1]*
  - *A[0]*
  - *X*
  - *W*
  - *R*
:::

Meaning of bit flags:
 - *L* - lock bit; when set to *1*, given entry cannot be changed (both configuration and address) until hart reset
 - *0* - unused bits, always set to *0*
 - *A[1:0]* - encodes address matching mode (*OFF*, *TOR*, *NA4*, *NAPOT*)
 - *X* - execute permission; when set to *1*, allows instruction fetch from the corresponding address region; otherwise memory access will result in an instruction access-fault exception
 - *W* - write permission; when set to *1*, allows data store to the corresponding address region; otherwise memory access will result in a store access-fault exception
 - *R* - read permission; when set to *1*, allows data load from the corresponding address region; otherwise memory access will result in a load access-fault exception.

### Address Registers (pmpaddrX)

PMP address registers (`pmpaddrX`) encode bits 33 to 2 (`address[33:2]`) in physical memory.
This address defines protected memory region boundaries, further interpreted according to address matching values encoded by bits 4 and 3 of the `pmpcfgX` register:

- *00* OFF Null region (disabled)
- *01* TOR Top of range
- *10* NA4 Naturally aligned four-byte region
- *11* NAPOT Naturally aligned power-of-two region, >=8 bytes
```

### `src/priv/csrs.adoc`

```text
4+^|Machine Memory Protection

|`0x3A0` |MRW |csr:pmpcfg0[]       |Physical memory protection configuration
|`0x3A1` |MRW |csr:pmpcfg1[]       |Physical memory protection configuration, RV32 only
|`0x3A2` |MRW |csr:pmpcfg2[]       |Physical memory protection configuration
|`0x3A3` |MRW |csr:pmpcfg3[]       |Physical memory protection configuration, RV32 only
|        |    |{vertical-ellipsis} |
|`0x3AE` |MRW |csr:pmpcfg14[]      |Physical memory protection configuration
|`0x3AF` |MRW |csr:pmpcfg15[]      |Physical memory protection configuration, RV32 only
|`0x3B0` |MRW |csr:pmpaddr0[]      |Physical memory protection address register
|`0x3B1` |MRW |csr:pmpaddr1[]      |Physical memory protection address register
|        |    |{vertical-ellipsis} |
|`0x3EF` |MRW |csr:pmpaddr63[]     |Physical memory protection address register
```

### `src/priv/machine.adoc`

```text
==== Physical Memory Protection CSRs

[#norm:pmp_entry_structure]#PMP entries are described by an 8-bit configuration register and one
MXLEN-bit address register. Some PMP settings additionally use the
address register associated with the preceding PMP entry.# [#norm:pmp_entry_count]#Up to 64 PMP
entries are supported. Implementations may implement zero, 16, or 64 PMP
entries; the lowest-numbered PMP entries must be implemented first.# [#norm:pmp_csrs_warl_access]#All
PMP CSR fields are *WARL* and may be read-only zero.# [#norm:pmp_csr_mode]#PMP CSRs are only
accessible to M-mode.#

The PMP configuration registers are densely packed into CSRs to minimize
context-switch time. [#norm:pmp_cfg_rv32_layout]#For RV32, sixteen CSRs, `pmpcfg0`–`pmpcfg15`, hold
the configurations `pmp0cfg`–`pmp63cfg` for the 64 PMP entries, as shown
in <<pmpcfg-rv32>>.# [#norm:pmp_cfg_rv64_layout]#For RV64, eight
even-numbered CSRs, `pmpcfg0`, `pmpcfg2`, …, `pmpcfg14`, hold the
configurations for the 64 PMP entries, as shown in
<<pmpcfg-rv64>>.# [#norm:pmp_cfg_rv64_illegal]#For RV64, the odd-numbered
configuration registers, `pmpcfg1`, `pmpcfg3`, …, `pmpcfg15`, are
illegal.#

[NOTE]
====
RV64 harts use `pmpcfg2`, rather than `pmpcfg1`, to hold
configurations for PMP entries 8-15. This design reduces the cost of
supporting multiple MXLEN values, since the configurations for PMP
entries 8-11 appear in `pmpcfg2`[31:0] for both RV32 and RV64.
====

[[pmpcfg-rv32]]
.RV32 PMP configuration CSR layout.
include::images/bytefield/pmp-rv32.edn[]

[[pmpcfg-rv64]]
.RV64 PMP configuration CSR layout.
include::images/bytefield/pmp-rv64.edn[]


[#norm:pmp_addr_registers]#The PMP address registers are CSRs named `pmpaddr0`-`pmpaddr63`.# [#norm:pmp_addr_encoding]#Each
PMP address register encodes bits 33-2 of a 34-bit physical address for
RV32, as shown in <<pmpaddr-rv32>>. For RV64,
each PMP address register encodes bits 55-2 of a 56-bit physical
address, as shown in <<pmpaddr-rv64>>.# [#norm:pmp_addr_warl]#Not all
physical address bits may be implemented, and so the `pmpaddr` registers
are *WARL*.#

[NOTE]
====
The Sv32 page-based virtual-memory scheme described in
<<sv32>> supports 34-bit physical addresses for
RV32, so the PMP scheme must support addresses wider than XLEN for RV32.
The Sv39 and Sv48 page-based virtual-memory schemes described in
<<sv39>> and <<sv48>> support a
56-bit physical address space, so the RV64 PMP address registers impose
the same limit.
====

[[pmpaddr-rv32]]
.PMP address register format, RV32.
include::images/bytefield/pmpaddr-rv32.edn[]

[[pmpaddr-rv64]]
.PMP address register format, RV64.
include::images/bytefield/pmpaddr-rv64.edn[]

[#norm:pmp_cfg_permissions]#<<pmpcfg>> shows the layout of a PMP configuration
register. The R, W, and X bits, when set, indicate that the PMP entry
permits read, write, and instruction execution, respectively. When one
of these bits is clear, the corresponding access type is denied.#
[#norm:pmp_rwx_warl]#The R,
W, and X fields form a collective *WARL* field for which the combinations with R=0 and W=1 are reserved.# The remaining two fields, A and L, are described in the following sections.
...
[[pmp-locking]]
===== Locking and Privilege Mode

[#norm:pmp_l_bit_function]#The L bit indicates that the PMP entry is locked, i.e., writes to the
configuration register and associated address registers are ignored.#
Locked PMP entries remain locked until the hart is reset. [#norm:pmp_l_bit_write_protection]#If PMP entry
_i_ is locked, writes to ``pmp``__i__``cfg`` and ``pmpaddr``__i__ are ignored. Additionally, if PMP
entry _i_ is locked and ``pmp``__i__``cfg.A`` is set
to TOR, writes to ``pmpaddr``__i__-1 are ignored.#

[NOTE]
====
Setting the L bit locks the PMP entry even when the A field is set to
OFF.
====
```

### `docs/source/clocks.md`

```text
## Reset

The VeeR EL2 core complex provides two reset signals, the core complex reset, see [](#core-complex-reset-rst_l) and the Debug Module reset, see [](#debug-module-reset-dbg_rst_l).

### Core Complex Reset (rst_l)

As shown in {numref}`fig-clock-reset-timing`, the core complex reset signal (`rst_l`) is active-low, may be asynchronously asserted, but must be synchronously deasserted to avoid any glitches.
The `rst_l` input signal is not synchronized to the core clock (`clk`) inside the core complex logic.
All core complex flops are reset asynchronously.
```

### `docs/source/dual-core-lock-step.md`

```text
Signals not compared due to their special meaning:
* `clk` - [core complex clock](clocks.md#clocking),
* `free_l2clk` - core complex clock always enabled, routed through one clock header,
* `active_l2clk` - core complex clock enabled when the core is active, routed through one clock header,
* `rst_l` - [core complex reset](clocks.md#core-complex-reset-rst-l),
* `dbg_rst_l` - [debug module reset](clocks.md#debug-module-reset-dbg-rst-l).
```

## Additional requirement

Writes take effect on a rising edge of `free_l2clk`, bits 31:30 of every `pmpaddr` register are always zero, and a `pmpcfg` byte written with R=0 is stored with W=0.
