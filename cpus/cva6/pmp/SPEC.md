# Implement `pmp`

Implement the complete `pmp` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module pmp` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv64a6_imafdc_sv39_config_pkg.sv

```systemverilog
  localparam CVA6ConfigNrPMPEntries = 8;
```

## Module declaration

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

## Dependency declarations

### core/include/riscv_pkg.sv

```systemverilog
package riscv;
// ...
  typedef enum logic [1:0] {
    PRIV_LVL_M  = 2'b11,
    PRIV_LVL_HS = 2'b10,
    PRIV_LVL_S  = 2'b01,
    PRIV_LVL_U  = 2'b00
  } priv_lvl_t;
// ...
  // PMP
  typedef enum logic [1:0] {
    OFF   = 2'b00,
    TOR   = 2'b01,
    NA4   = 2'b10,
    NAPOT = 2'b11
  } pmp_addr_mode_t;

  // PMP Access Type
  typedef enum logic [2:0] {
    ACCESS_NONE  = 3'b000,
    ACCESS_READ  = 3'b001,
    ACCESS_WRITE = 3'b010,
    ACCESS_EXEC  = 3'b100
  } pmp_access_t;

  typedef struct packed {
    logic x;
    logic w;
    logic r;
  } pmpcfg_access_t;

  // packed struct of a PMP configuration register (8bit)
  typedef struct packed {
    logic           locked;       // lock this configuration
    logic [1:0]     reserved;
    pmp_addr_mode_t addr_mode;    // Off, TOR, NA4, NAPOT
    pmpcfg_access_t access_type;
  } pmpcfg_t;
```

### core/pmp/src/pmp_entry.sv

```systemverilog
// Description: single PMP entry

module pmp_entry #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter int unsigned PLEN = 56,
    parameter int unsigned PMP_LEN = 54
) (
    // Input
    input logic [CVA6Cfg.PLEN-1:0] addr_i,

    // Configuration
    input logic [CVA6Cfg.PLEN-3:0] conf_addr_i,
    input logic [CVA6Cfg.PLEN-3:0] conf_addr_prev_i,
    input riscv::pmp_addr_mode_t conf_addr_mode_i,

    // Output
    output logic match_o
);
```

## Documentation

### src/machine.adoc

```text
If TOR is selected, the associated address register forms the top of the
address range, and the preceding PMP address register forms the bottom
of the address range. If PMP entry __i__'s A field is set to
TOR, the entry matches any address _y_ such that `pmpaddr~i-1~`&#8804;__y__<``pmpaddr~i~`` (irrespective of the value of `pmpcfg~i-1~`). If PMP entry 0's A field is set to TOR, zero is used for the lower bound, and so it matches
any address `y<pmpaddr~0~`.
...
In addition to locking the PMP entry, the L bit indicates whether the
R/W/X permissions are enforced on M-mode accesses. When the L bit is
set, these permissions are enforced for all privilege modes. When the L
bit is clear, any M-mode access matching the PMP entry will succeed; the
R/W/X permissions apply only to S and U modes.

===== Priority and Matching Logic

PMP entries are statically prioritized. The lowest-numbered PMP entry
that matches any byte of an access determines whether that access
succeeds or fails. The matching PMP entry must match all bytes of an
access, or the access fails, irrespective of the L, R, W, and X bits.
For example, if a PMP entry is configured to match the four-byte range
`0xC`–`0xF`, then an 8-byte access to the range `0x8`–`0xF` will fail,
assuming that PMP entry is the highest-priority entry that matches those
addresses.

If a PMP entry matches all bytes of an access, then the L, R, W, and X
bits determine whether the access succeeds or fails. If the L bit is
clear and the privilege mode of the access is M, the access succeeds.
Otherwise, if the L bit is set or the privilege mode of the access is S
or U, then the access succeeds only if the R, W, or X bit corresponding
to the access type is set.

If no PMP entry matches an M-mode access, the access succeeds. If no PMP
entry matches an S-mode or U-mode access, but at least one PMP entry is
implemented, the access fails.
```
