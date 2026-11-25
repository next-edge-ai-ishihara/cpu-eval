# Implement `el2_dec_ib_ctl`

Implement the complete `el2_dec_ib_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dec_ib_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog

module el2_dec_ib_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic                 dbg_cmd_valid,                      // valid dbg cmd

   input logic                 dbg_cmd_write,                      // dbg cmd is write
   input logic [1:0]           dbg_cmd_type,                       // dbg type
   input logic [31:0]          dbg_cmd_addr,                       // expand to 31:0

   input el2_br_pkt_t i0_brp,                                     // i0 branch packet from aligner
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index,    // BP index
   input logic [pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr,               // BP FGHR
   input logic [pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag,              // BP tag
   input logic [$clog2(pt.BTB_SIZE)-1:0] ifu_i0_fa_index,          // Fully associative btb index

   input logic       ifu_i0_pc4,                                   // i0 is 4B inst else 2B
   input logic       ifu_i0_valid,                                 // i0 valid from ifu
   input logic       ifu_i0_icaf,                                  // i0 instruction access fault
   input logic [1:0] ifu_i0_icaf_type,                             // i0 instruction access fault type

   input logic   ifu_i0_icaf_second,                               // i0 has access fault on second 2B of 4B inst
   input logic   ifu_i0_dbecc,                                     // i0 double-bit error
   input logic [31:0]  ifu_i0_instr,                               // i0 instruction from the aligner
   input logic [31:1]  ifu_i0_pc,                                  // i0 pc from the aligner


   output logic dec_ib0_valid_d,                                   // ib0 valid
   output logic dec_debug_valid_d,                                 // Debug read or write at D-stage


   output logic [31:0] dec_i0_instr_d,                             // i0 inst at decode

   output logic [31:1] dec_i0_pc_d,                                // i0 pc at decode

   output logic dec_i0_pc4_d,                                      // i0 is 4B inst else 2B

   output el2_br_pkt_t dec_i0_brp,                                // i0 branch packet at decode
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] dec_i0_bp_index,   // i0 branch index
   output logic [pt.BHT_GHR_SIZE-1:0] dec_i0_bp_fghr,              // BP FGHR
   output logic [pt.BTB_BTAG_SIZE-1:0] dec_i0_bp_btag,             // BP tag
   output logic [$clog2(pt.BTB_SIZE)-1:0] dec_i0_bp_fa_index,          // Fully associative btb index

   output logic dec_i0_icaf_d,                                     // i0 instruction access fault at decode
   output logic dec_i0_icaf_second_d,                              // i0 instruction access fault on second 2B of 4B inst
   output logic [1:0] dec_i0_icaf_type_d,                          // i0 instruction access fault type
   output logic dec_i0_dbecc_d,                                    // i0 double-bit error at decode
   output logic dec_debug_wdata_rs1_d,                             // put debug write data onto rs1 source: machine is halted

   output logic dec_debug_fence_d                                  // debug fence inst

   );

```

## Parent instantiation

```verilog


  el2_dec_ib_ctl #(.pt(pt)) instbuff (.*);

```

## Dependency declarations

### `design/include/el2_def.sv`

```verilog
typedef struct packed {
                       logic valid;
                       logic [11:0] toffset;
                       logic [1:0] hist;
                       logic br_error;
                       logic br_start_error;
                       logic  bank;
                       logic [31:1] prett;  // predicted ret target
                       logic way;
                       logic ret;
                       } el2_br_pkt_t;

```

## Related source code

### `design/dbg/el2_dbg.sv`

```verilog
   assign dbg_cmd_addr[31:0]    = (command_reg[31:24] == 8'h2) ? data1_reg[31:0]  : {20'b0, command_reg[11:0]};
   assign dbg_cmd_wrdata[31:0]  = data0_reg[31:0];
   assign dbg_cmd_valid         = (dbg_state == CORE_CMD_START) & ~((|abstractcs_reg[10:8]) | ((command_reg[31:24] == 8'h0) & ~command_reg[17]) | ((command_reg[31:24] == 8'h2) & abmem_addr_external)) & dma_dbg_ready;
   assign dbg_cmd_write         = command_reg[16];
   assign dbg_cmd_type[1:0]     = (command_reg[31:24] == 8'h2) ? 2'b10 : {1'b0, (command_reg[15:12] == 4'b0)};

```

### `design/el2_veer.sv`

```verilog
   logic [31:0]            dbg_cmd_addr;              // the address of the debug command to used by the core
   logic [31:0]            dbg_cmd_wrdata;            // If the debug command is a write command, this has the data to be written to the CSR/GPR
   logic                   dbg_cmd_valid;             // commad is being driven by the dbg module. One pulse. Only dirven when core_halted has been seen
   logic                   dbg_cmd_write;             // 1: write command; 0: read_command
   logic [1:0]             dbg_cmd_type;              // 0:gpr 1:csr 2: memory

```

### `design/ifu/el2_ifu.sv`

```verilog
   output logic       ifu_i0_icaf,         // Instruction 0 access fault. From Aligner to Decode
   output logic [1:0] ifu_i0_icaf_type, // Instruction 0 access fault type

   output logic  ifu_i0_valid,        // Instruction 0 valid. From Aligner to Decode
   output logic  ifu_i0_icaf_second,  // Instruction 0 has access fault on second 2B of 4B inst
   output logic  ifu_i0_dbecc,        // Instruction 0 has double bit ecc error
   output logic  iccm_dma_sb_error,   // Single Bit ECC error from a DMA access
   output logic[31:0] ifu_i0_instr,   // Instruction 0 . From Aligner to Decode
   output logic[31:1] ifu_i0_pc,      // Instruction 0 pc. From Aligner to Decode
   output logic ifu_i0_pc4,           // Instruction 0 is 4 byte. From Aligner to Decode

   output logic ifu_miss_state_idle,   // There is no outstanding miss. Cache miss state is idle.

   output el2_br_pkt_t i0_brp,           // Instruction 0 branch packet. From Aligner to Decode
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index, // BP index
   output logic [pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr, // BP FGHR
   output logic [pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag, // BP tag
   output logic [$clog2(pt.BTB_SIZE)-1:0]         ifu_i0_fa_index,          // Fully associative btb index

```

### `design/exu/el2_exu.sv`

```verilog
   assign i0_rs1_d[31:0]           = ({32{ i0_rs1_bypass_en_d                                           }}             & i0_rs1_bypass_data_d[31:0]) |
                                     ({32{~i0_rs1_bypass_en_d &  dec_i0_select_pc_d                     }}             & {dec_i0_pc_d[31:1],1'b0}  ) |    // for jal's
                                     ({32{~i0_rs1_bypass_en_d &  dec_debug_wdata_rs1_d                  }}             & dbg_cmd_wrdata[31:0]      ) |
                                     ({32{~i0_rs1_bypass_en_d & ~dec_debug_wdata_rs1_d & dec_i0_rs1_en_d}}             & gpr_i0_rs1_d[31:0]        );

```

### `design/dec/el2_dec_decode_ctl.sv`

```verilog
// debug fence csr
   assign debug_fence_i     = dec_debug_fence_d & dbg_cmd_wrdata[0];
   assign debug_fence_raw   = dec_debug_fence_d & dbg_cmd_wrdata[1];

   assign debug_fence       = debug_fence_raw | debug_fence_i;    // fence_i causes a fence

   assign i0_csr_write = i0_dp.csr_write & ~dec_debug_fence_d;
// end debug

```

## Documentation

### `docs/source/debugging.md`

```text
### Abstract Command Register (command)

Writes to the command register `cause` the corresponding abstract command to be executed.

Writing this register while an abstract command is executing causes the *cmderr* field in the abstractcs register (see [](debugging.md#abstract-control-and-status-register-abstractcs)) to be set to '1' (i.e., 'busy'), if it is '0'.
If the *cmderr* field is non-zero, writes to the command register are ignored.

:::{note}
A non-zero *cmderr* field inhibits starting a new abstract command to accommodate debuggers which, for performance reasons, may send several commands to be executed in a row without checking the *cmderr* field in between. Checking the *cmderr* field only at the end of a sequence of commands is safe because later commands which might depend on a previous, but failed command are not executed.
:::

:::{note}
Access register and access memory abstract commands may only be executed when the core is in the debug halt (db-halt) state. If the debugger is requesting the execution of an abstract command while the core is not in the debug halt state, the command is aborted and the *cmderr* field is set to '4' (i.e., 'halt/resume'), if it is '0'.
:::

:::{note}
The access memory abstract command method provides access to ICCM, DCCM, and PIC memory ranges as well as to SoC memories.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} Abstract Command Register (command, at Debug Module Offset 0x17)
:name: tab-command
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - cmdtype
  - 31:24
  - Abstract command type:
    - 0: Access Register Command
    - 2: Access Memory Command

    **Note**: Other values not implemented or reserved for future use. Writing this field to value different than ‘0’ or ‘2’ causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘2’.
  - R0/W
  - 0
* - **Access Register Command**
  -
  -
  -
  -
* - Reserved
  - 23
  - Reserved
  - R
  - 0
* - aarsize
  - 22:20
  - Register access size:
      - 2: 32-bit access

    **Note**: Other size values not implemented. Writing this field to value different than ‘2’ causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘2’, except if transfer is ‘0’.
  - R/W
  - 2
* - aarpostincrement
  - 19
  - Access register post-increment control:
    - 0: No post-increment
    - 1: After every successful access register command completion, increment *regno* field (wrapping around to 0)
  - R/W
  - 0
* - postexec
  - 18
  - Not implemented (i.e., 0: No effect)

    **Note**: Writing to ‘1’ causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘2’.
  - R
  - 0
* - transfer
  - 17
  - Transfer:
    - 0: Do not perform operation specified by write

      **Note**: Selection of unimplemented options (except for *aarsize* and *regno* fields) causes cmderr field of `abstractcs` register to be set to ‘2’.
    - 1: Perform operation specified by write

      **Note**: Selection of unimplemented options causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘2’.
  - R
  - 1
* - write
  - 16
  - Read or write register:
    - 0 (read): Copy data from register specified in *regno* field into `data0` register ([Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data0-1))
    - 1 (write): Copy data from `data0` register ([Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data0-1)) into register specified in *regno* field
  - R0/W
  - 0
* - regno
  - 15:0
  - Register access:
    - 0x0000 - 0x0FFF: CSRs
    - 0x1000 - 0x101F: GPRs
    - 0x1020 - 0xFFFF: Not implemented or reserved

    **Note**: Selecting illegal register address causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘3’, except if transfer is ‘0’.

```

### `docs/source/memory-map.md`

```text
### Memory Synchronization Trigger Register (dmst)

The `dmst` register provides triggers to force the synchronization of memory accesses. Specifically, it allows a debugger to initiate operations that are equivalent to the `fence.i` (see [](memory-map.md#instructions)) and `fence` (see [](memory-map.md#data)) instructions.

:::{note}
 This register is accessible in **Debug Mode only**. Attempting to access this register in machine mode raises an illegal instruction exception.
:::

The *fence_i* and *fence* fields of the `dmst` register have W1R0 (Write 1, Read 0) behavior, as also indicated in the
'Access' column.

This register is mapped to the non-standard read/write CSR address space.

:::{list-table} Memory Synchronization Trigger Register (dmst, at CSR 0x7C4)
:name: tab-memory-synchronization-trigger-register
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:2
  - Reserved
  - R
  - 0
* - fence
  - 1
  - Trigger operation equivalent to `fence` instruction
  - R0/W1
  - 0
* - fence_i
  - 0
  - Trigger operation equivalent to `fence.i` instruction
  - R0/W1
  - 0
:::

```

## Additional requirement

While `dbg_cmd_valid` is 1, `dec_i0_instr_d` must be `or x0, xN, x0` to read GPR xN, `or xN, x0, x0` to write GPR xN, `csrrs x0, csr, x0` to read CSR csr, and `csrrw x0, csr, x0` to write CSR csr when `dbg_cmd_type` is 0 or 1, and every output must keep the value it has with `dbg_cmd_valid` at 0 when `dbg_cmd_type` is 2.
