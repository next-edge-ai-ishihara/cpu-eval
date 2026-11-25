# Implement `el2_pmp`

Implement the complete `el2_pmp` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_pmp` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
my $smepmp=0;
...
$user_mode=0;
```

## Module declaration

```verilog
module el2_pmp
  import el2_pkg::*;
#(
    parameter PMP_CHANNELS = 3,
    // Granularity of NAPOT access,
    // 0 = No restriction, 1 = 8 byte, 2 = 16 byte, 3 = 32 byte, etc.
    parameter PMP_GRANULARITY = 0,  // TODO: Move to veer.config
    `include "el2_param.vh"
) (
    input logic clk,       // Top level clock
    input logic rst_l,     // Reset
    /* pragma coverage off */
    input logic scan_mode, // Scan mode
    /* pragma coverage on */

`ifdef RV_SMEPMP
    input el2_mseccfg_pkt_t mseccfg, // mseccfg CSR content, RLB, MMWP and MML bits
`endif

`ifdef RV_USER_MODE
    input logic priv_mode_ns,   // operating privilege mode (next clock cycle)
    input logic priv_mode_eff,  // operating effective privilege mode
`endif

    input el2_pmp_cfg_pkt_t        pmp_pmpcfg [pt.PMP_ENTRIES],
    input logic             [31:0] pmp_pmpaddr[pt.PMP_ENTRIES],

    input  logic              [31:0] pmp_chan_addr[PMP_CHANNELS],
    input  el2_pmp_type_pkt_t        pmp_chan_type[PMP_CHANNELS],
    output logic                     pmp_chan_err [PMP_CHANNELS]
);
```

## Parent instantiation

### design/el2_veer.sv

```verilog
  assign pmp_chan_addr[0] = {ifu_pmp_addr, 1'b0};
  assign pmp_chan_type[0] = EXEC;
  assign ifu_pmp_error    = pmp_chan_err[0];
  assign pmp_chan_addr[1] = lsu_pmp_addr_start;
  assign pmp_chan_type[1] = lsu_pmp_we ? WRITE : (lsu_pmp_re ? READ : NONE);
  assign lsu_pmp_error_start = pmp_chan_err[1];
  assign pmp_chan_addr[2] = lsu_pmp_addr_end;
  assign pmp_chan_type[2] = lsu_pmp_we ? WRITE : (lsu_pmp_re ? READ : NONE);
  assign lsu_pmp_error_end = pmp_chan_err[2];

  el2_pmp #(
      .PMP_CHANNELS(3),
      .pt(pt)
  ) pmp (
      .clk  (active_l2clk),
      .rst_l(core_rst_l),
      .*
  );
```

## Dependency declarations

### design/include/el2_def.sv

```verilog
  typedef enum logic [2:0] {
    NONE  = 3'b000,
    READ  = 3'b001,
    WRITE = 3'b010,
    EXEC  = 3'b100
  } el2_pmp_type_pkt_t;


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

  typedef struct packed {
    logic RLB;
    logic MMWP;
    logic MML;
  } el2_mseccfg_pkt_t;
```

## Related source code

### design/ifu/el2_ifu.sv

```verilog
  assign ifu_pmp_addr = ifc_fetch_addr_bf;
```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
      assign ifc_region_acc_okay = ~ifu_pmp_error;
```

### design/lsu/el2_lsu.sv

```verilog
  assign lsu_pmp_addr_start = lsu_addr_d;
  assign lsu_pmp_addr_end   = end_addr_d;
// ...
  assign lsu_pmp_we = lsu_pkt_d.store & lsu_pkt_d.valid;
  assign lsu_pmp_re = lsu_pkt_d.load & lsu_pkt_d.valid;
```

### design/lsu/el2_lsu_addrcheck.sv

```verilog
    if (pt.PMP_ENTRIES > 0) begin
      assign mpu_access_fault_d   = (lsu_pmp_error_start | lsu_pmp_error_end);                                         // X. Address is in blocked region
    end else begin
      assign mpu_access_fault_d   = (~start_addr_in_dccm_region_d & ~non_dccm_access_ok);                              // 3. Address is not in a populated non-dccm region
    end
```

## Documentation

### docs/source/physical-memory-protection.md

```markdown
# Physical Memory Protection

The Physical Memory Protection unit implemented in the VeeR EL2 Core is compliant with "Section 3.7 Physical Memory Protection" of [[5]](intro.md#ref-5).
...
## Theory of Operation

The PMP module adds a set of CSRs which define memory regions and Read/Write/Execute (RWX) access permissions.
For each memory access, the PMP module checks if accessed memory is on the allowlist.
In case of impermissible memory access, a precise exception is thrown and execution flow is switched to the trap handler.
The PMP distinguishes 3 types of memory accesses: instruction fetch, data load and data store.
...
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
...
## PMP module

The PMP module is implemented in [el2_pmp.sv](../../design/el2_pmp.sv).
It is meant to be connected to the:

- CSR configuration table
- CSR addresses table
- configuration inputs for each channel (marking permissions to be checked on a given channel)
- address inputs for each channel (one for IFU, one for LSU)
- error outputs for each channel

The following functionality has been implemented:

- decoding address ranges (start address and mask) from address CSRs depending on the address matching mode for a given entry
- comparing addresses coming from a channel to defined ranges
- asserting error flags for given channels depending on permissions from the first matching range.

Error handling is performed using existing logic in IFU and LSU modules, reusing previously implemented mechanisms.
```

### src/priv/machine.adoc

```text
[#norm:pmp_l_bit_m_mode_enforcement]#In addition to locking the PMP entry, the L bit indicates whether the
R/W/X permissions are additionally enforced on M-mode accesses.
When the L bit is
set, these permissions are enforced for all privilege modes. When the L
bit is clear, any M-mode access matching the PMP entry will succeed; the
R/W/X permissions apply only to S and U modes.#
...
[#norm:pmp_rwx_check]#If a PMP entry matches all bytes of a memory operation, then the L, R, W, and X
bits determine whether the operation succeeds or fails. If the L bit is
clear and the privilege mode of the access is M, the operation succeeds.
Otherwise, if the L bit is set or the privilege mode of the access is S
or U, then the operation succeeds only if the R, W, or X bit corresponding
to the access type is set.#

[#norm:pmp_no_entry_match]#If no PMP entry matches an M-mode memory operation, the operation succeeds.
If no PMP entry matches an S-mode or U-mode memory operation, the operation
fails if at least one PMP entry is implemented and succeeds otherwise.#
```
