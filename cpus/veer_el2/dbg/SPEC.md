# Implement `el2_dbg`

Implement the complete `el2_dbg` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dbg` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$dccm_enable=1;
$dccm_region="0xf";
...
$iccm_enable=1;
$iccm_region="0xe";
...
$pic_region="0xf";
```

## Module declaration

```verilog
module el2_dbg
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   // outputs to the core for command and data interface
   output logic [31:0]                 dbg_cmd_addr,
   output logic [31:0]                 dbg_cmd_wrdata,
   output logic                        dbg_cmd_valid,
   output logic                        dbg_cmd_write,             // 1: write command, 0: read_command
   output logic [1:0]                  dbg_cmd_type,              // 0:gpr 1:csr 2: memory
   output logic [1:0]                  dbg_cmd_size,              // size of the abstract mem access debug command
   output logic                        dbg_core_rst_l,            // core reset from dm

   // inputs back from the core/dec
   input logic [31:0]                  core_dbg_rddata,
   input logic                         core_dbg_cmd_done,         // This will be treated like a valid signal
   input logic                         core_dbg_cmd_fail,         // Exception during command run

   // Signals to dma to get a bubble
   output logic                        dbg_dma_bubble,            // Debug needs a bubble to send a valid
   input  logic                        dma_dbg_ready,             // DMA is ready to accept debug request

   // interface with the rest of the core to halt/resume handshaking
   output logic                        dbg_halt_req,              // This is a pulse
   output logic                        dbg_resume_req,            // Debug sends a resume requests. Pulse
   input  logic                        dec_tlu_debug_mode,        // Core is in debug mode
   input  logic                        dec_tlu_dbg_halted,        // The core has finished the queiscing sequence. Core is halted now
   input  logic                        dec_tlu_mpc_halted_only,   // Only halted due to MPC
   input  logic                        dec_tlu_resume_ack,        // core sends back an ack for the resume (pulse)

   // inputs from the JTAG
   input logic                         dmi_reg_en,                // read or write
   input logic [6:0]                   dmi_reg_addr,              // address of DM register
   input logic                         dmi_reg_wr_en,             // write instruction
   input logic [31:0]                  dmi_reg_wdata,             // write data

   // output
   output logic [31:0]                 dmi_reg_rdata,             // read data

   // AXI Write Channels
   output logic                        sb_axi_awvalid,
   input  logic                        sb_axi_awready,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [pt.SB_BUS_TAG-1:0]    sb_axi_awid,
   /*pragma coverage on*/
   output logic [31:0]                 sb_axi_awaddr,
   output logic [3:0]                  sb_axi_awregion,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [7:0]                  sb_axi_awlen,
   /*pragma coverage on*/
   output logic [2:0]                  sb_axi_awsize,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [1:0]                  sb_axi_awburst,
   output logic                        sb_axi_awlock,
   output logic [3:0]                  sb_axi_awcache,
   output logic [2:0]                  sb_axi_awprot,
   output logic [3:0]                  sb_axi_awqos,
   /*pragma coverage on*/

   output logic                        sb_axi_wvalid,
   input  logic                        sb_axi_wready,
   output logic [63:0]                 sb_axi_wdata,
   output logic [7:0]                  sb_axi_wstrb,
   output logic                        sb_axi_wlast,

   input  logic                        sb_axi_bvalid,
   output logic                        sb_axi_bready,
   input  logic [1:0]                  sb_axi_bresp,

   // AXI Read Channels
   output logic                        sb_axi_arvalid,
   input  logic                        sb_axi_arready,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [pt.SB_BUS_TAG-1:0]    sb_axi_arid,
   /*pragma coverage on*/
   output logic [31:0]                 sb_axi_araddr,
   output logic [3:0]                  sb_axi_arregion,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [7:0]                  sb_axi_arlen,
   /*pragma coverage on*/
   output logic [2:0]                  sb_axi_arsize,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [1:0]                  sb_axi_arburst,
   output logic                        sb_axi_arlock,
   output logic [3:0]                  sb_axi_arcache,
   output logic [2:0]                  sb_axi_arprot,
   output logic [3:0]                  sb_axi_arqos,
   /*pragma coverage on*/

   input  logic                        sb_axi_rvalid,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic                        sb_axi_rready,
   /*pragma coverage on*/
   input  logic [63:0]                 sb_axi_rdata,
   input  logic [1:0]                  sb_axi_rresp,

   input logic                         dbg_bus_clk_en,

   // DCCM write-readback sticky fault capture (see el2_lsu_dccm_ctl), exposed
   // read-only over DMI at 0x70/0x71/0x72. dccm_wr_rdbk_fault_clear re-arms
   // capture for the next fault.
   input logic                           dccm_wr_rdbk_fault_valid,
   input logic [pt.DCCM_BITS-1:0]        dccm_wr_rdbk_fault_addr,
   input logic [pt.DCCM_FDATA_WIDTH-1:0] dccm_wr_rdbk_fault_data,
   output logic                          dccm_wr_rdbk_fault_clear,

   // general inputs
   input logic                         clk,
   input logic                         free_clk,
   input logic                         rst_l,        // This includes both top rst and debug rst
   input logic                         dbg_rst_l,
   input logic                         clk_override,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                         scan_mode
   /*pragma coverage on*/
);
```

## Parent instantiation

### design/el2_veer.sv

```verilog
   el2_dbg #(.pt(pt)) dbg (
      .rst_l(core_rst_l),
      .clk(free_l2clk),
      .clk_override(dec_tlu_misc_clk_override),

      // AXI signals
      .sb_axi_awready(sb_axi_awready_int),
      .sb_axi_wready(sb_axi_wready_int),
      .sb_axi_bvalid(sb_axi_bvalid_int),
      .sb_axi_bresp(sb_axi_bresp_int[1:0]),

      .sb_axi_arready(sb_axi_arready_int),
      .sb_axi_rvalid(sb_axi_rvalid_int),
      .sb_axi_rdata(sb_axi_rdata_int[63:0]),
      .sb_axi_rresp(sb_axi_rresp_int[1:0]),
      .*
   );
// ...
   assign core_rst_l = rst_l & (dbg_core_rst_l | scan_mode);
```

## Dependency declarations

### design/lib/beh_lib.sv

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );
// ...
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );
// ...
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
// ...
module rvsyncss #(parameter WIDTH = 251)
   (
     input  logic                 clk,
     input  logic                 rst_l,
     input  logic [WIDTH-1:0]     din,
     output logic [WIDTH-1:0]     dout
     );
// ...
module rvoclkhdr
  (
   input  logic en,
   input  logic clk,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic scan_mode,
   /*pragma coverage on*/
   output logic l1clk
   );
```

## Documentation

### docs/source/debugging.md

```markdown
# Debug Support

The VeeR EL2 core conforms to the "RISC-V Debug Specification 0.13.2, with JTAG DTM" document [[3]](intro.md#ref-3).
This chapter provides a description of the implemented debug-related control and status register definitions.
For a RISC-V debug overview and detailed feature descriptions, refer to corresponding sections in [[3]](intro.md#ref-3).
...
### Control/Status Registers in Debug Module Interface Address Space

{numref}`tab-registers-dmi` Summarizes The Control/Status Registers In The Debug Module Interface Address Space.

Registers in the Debug Module Interface address space are accessed through the `dmi` register in the JTAG address space (see [](debugging.md#debug-module-interface-access-register-dmi)).
The *address* field of the `dmi` register selects the Debug Module Interface register to be accessed, the *data* field either provides the value to be written to the selected register or captures that register's value, and the *op* field selects the operation to be performed.

Addresses shown below are offsets relative to the Debug Module base address. VeeR EL2 supports a single Debug Module with a base address of 0x00.

:::{list-table} Registers in Debug Module Interface Address Space
:name: tab-registers-dmi
:header-rows: 1

* - **DMI Address**
  - **Name**
  - **Description**
  - **Section**
* - 0x04
  - data0
  - Abstract data 0
  - [Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data01)
* - 0x05
  - data1
  - Abstract data 1
  - [Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data01)
* - 0x10
  - dmcontrol
  - Debug module control
  - [System Bus Address 31:0 Register (sbaddress0)](debugging.md#debug-module-control-register-dmcontrol)
* - 0x11
  - dmstatus
  - Debug module status
  - [](debugging.md#debug-module-status-register-dmstatus)
* - 0x16
  - abstractcs
  - Abstract control and status
  - [](debugging.md#abstract-control-and-status-register-abstractcs)
* - 0x17
  - command
  - Abstract command
  - [](debugging.md#abstract-command-register-command)
* - 0x18
  - abstractauto
  - Abstract command autoexec
  - [](debugging.md#abstract-command-autoexec-register-abstractauto)
* - 0x38
  - sbcs
  - System bus access control and status
  - [](debugging.md#system-bus-access-control-and-status-register-sbcs)
* - 0x39
  - sbaddress0
  - System bus address 31:0
  - [](debugging.md#system-bus-address-310-register-sbaddress0)
* - 0x3C
  - sbdata0
  - System bus data 31:0
  - [](debugging.md#system-bus-data-310-register-sbdata0)
* - 0x3D
  - sbdata1
  - System bus data 63:32
  - [](debugging.md#system-bus-data-6332-register-sbdata1)
* - 0x40
  - haltsum0
  - Halt summary 0
  - [](debugging.md#halt-summary-0-register-haltsum0)
* - 0x70
  - dccm_wr_rdbk_status
  - DCCM write-readback fault status/address (custom, vendor-specific)
  - [](debugging.md#dccm-write-readback-fault-status-register-dccm_wr_rdbk_status)
* - 0x71
  - dccm_wr_rdbk_data
  - DCCM write-readback fault data (custom, vendor-specific)
  - [](debugging.md#dccm-write-readback-fault-data-register-dccm_wr_rdbk_data)
* - 0x72
  - dccm_wr_rdbk_ecc
  - DCCM write-readback fault ecc (custom, vendor-specific)
  - [](debugging.md#dccm-write-readback-fault-ecc-register-dccm_wr_rdbk_ecc)
:::

:::{note}
ICCM, DCCM, and PIC memory ranges are only accessible using the access memory abstract command.
:::

### Debug Module Control Register (dmcontrol)

The `dmcontrol` register controls the overall Debug Module as well as the hart.

:::{note}
On any given write, a debugger may only write '1' to either the *resumereq* or *ackhavereset* bit. The other bit must be written to '0'.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} Debug Module Control Register (dmcontrol, at Debug Module Offset 0x10)
:name: tab-dmcontrol
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - haltreq
  - 31
  - Halt request:
    - 0: Clears halt request bit.

      **Note**: May cancel outstanding halt request.
    - 1: Sets halt request bit.

      **Note**: Running hart halts whenever halt request bit is set.
   - R0/W
   - 0
* - resumereq
  - 30
  - Resume request:
    - 0: No effect
    - 1: Causes hart to resume, if halted

    **Note**: Also clears resume ack bit for hart.

    **Note**: Setting *resumereq* bit is ignored if *haltreq* bit is set.
  - R0/W1
  - 0
* - hartreset
  - 29
  - Not implemented (i.e., 0: Deasserted)
  - R
  - 0
* - ackhavereset
  - 28
  - Reset core-internal, sticky `havereset` state:
    - 0: No effect
    - 1: Clear `havereset` state
  - R0/W1
  - 0
* - Reserved
  - 27
  - Reserved
  - R
  - 0
* - hasel
  - 26
  - Selects definition of currently selected harts:
    * 0: Single currently selected hart (VeeR EL2 is single-thread)
  - R
  - 0
* - hartsello
  - 25:16
  - Not implemented (VeeR EL2 is single-thread)
  - R
  - 0
* - hartselhi
  - 15:6
  - Not implemented (VeeR EL2 is single-thread)
  - R
  - 0
* - Reserved
  - 5:4
  - Reserved
  - R
  - 0
* - setresethaltreq
  - 3
  - Not implemented

    **Note**: *hasresethaltreq* bit in `dmstatus` register ({numref}`tab-dmstatus`) is ‘0’.
  - R
  - 0
* - clrresethaltreq
  - 2
  - Not implemented

    **Note**: *hasresethaltreq* bit in `dmstatus` register ({numref}`tab-dmstatus`) is ‘0’.
  - R
  - 0
* - ndmreset
  - 1
  - Controls reset signal from DM to VeeR EL2 core. Signal resets hart, but not DM. To perform a reset, debugger writes ‘1’, and then writes ‘0’ to deassert reset.
  - R/W
  - 0
* - dmactive
  - 0
  - Reset signal for Debug Module (DM):
    - 0: Module's state takes its reset values

      **Note**: Only *dmactive* bit may be written to value other than its reset value. Writes to all other bits of this register are ignored.
    - 1: Module functions normally

      Debugger may pulse this bit low to get Debug Module into known state.

      **Note**: The core complex’s `dbg_rst_l` signal (see [](complex-ports.md)) resets the Debug Module. It should only be used to reset the Debug Module at power up or possibly with a global reset signal which resets the entire platform.
  - R/W
  - 0
:::

#### Debug Module Status Register (dmstatus)

The `dmstatus` register reports status for the overall Debug Module as well as the hart.

This register is read-only.

This register is mapped to the Debug Module Interface address space.

:::{list-table} Debug Module Status Register (dmstatus, at Debug Module Offset 0x11)
:name: tab-dmstatus
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:23
  - Reserved
  - R
  - 0
* - impebreak
  - 22
  - Not implemented

    **Note**: VeeR EL2 does not implement a Program Buffer.
  - R
  - 0
* - Reserved
  - 21:20
  - Reserved
  - R
  - 0
* - allhavereset
  - 19
  - '1' when hart has been reset and reset has not been acknowledged
  - R
  - \-
* - anyhavereset
  - 18
  - '1' when hart has been reset and reset has not been acknowledged
  - R
  - \-
* - allresumeack
  - 17
  - '1' when hart has acknowledged last resume request
  - R
  - \-
* - anyresumeack
  - 16
  - '1' when hart has acknowledged last resume request
  - R
  - \-
* - allnonexistent
  - 15
  - Not implemented (VeeR EL2 is single-thread)
  - R
  - 0
* - anynonexistent
  - 14
  - Not implemented (VeeR EL2 is single-thread)
  - R
  - 0
* - allunavail
  - 13
  - '1' when hart is unavailable [^fn-debugging-1]
  - R
  - \-
* - anyunavail
  - 12
  - '1' when hart is unavailable [^fn-debugging-1]
  - R
  - \-
* - allrunning
  - 11
  - '1' when hart is running
  - R
  - \-
* - anyrunning
  - 10
  - '1' when hart is running
  -  R
  - \-
* - allhalted
  - 9
  - '1' when hart is halted
  - R
  - \-
* - anyhalted
  - 8
  - '1' when hart is halted
  - R
  - \-
* - authenticated
  - 7
  - Not implemented (i.e., 1: Always authenticated)
  - R
  - 1
* - authbusy
  - 6
  - Not implemented (i.e., 0: Authentication module never busy)
  - R
  - 0
* - hasresethaltreq
  - 5
  - Not implemented

    **Note**: VeeR EL2 implements halt-on-reset with *haltreq* set out of reset method.
  - R
  - 0
* - confstrptrvalid
  - 4
  - Not implemented

    **Note**: VeeR EL2 does not provide information relevant to configuration string.
  - R
  - 0
* - version
  - 3:0
  - Debug Module present, conforming to RISC-V Debug specification Version 0.13.2
  - R
  - 2
:::

[^fn-debugging-1]: Hart is in reset or ndmreset bit of dmstatus register is ‘1’.

#### Halt Summary 0 Register (haltsum0)

Each bit in the `haltsum0` register indicates whether a specific hart is halted or not.
Since VeeR EL2 is singlethreaded, only one bit is implemented.

:::{note}
Unavailable/nonexistent harts are not considered to be halted.
:::

This register is read-only.

This register is mapped to the Debug Module Interface address space.

:::{list-table} Halt Summary 0 Register (haltsum0, at Debug Module Offset 0x40)
:name: tab-haltsum0
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:1
  - Reserved
  - R
  - 0
* - halted
  - 0
  - '1' when hart halted
  - R
  - 0
:::

#### Abstract Control and Status Register (abstractcs)

The `abstractcs` register provides status information of the abstract command interface and enables clearing of detected command errors.

:::{note}
Writing this register while an abstract command is executing causes its *cmderr* field to be set to '1' (i.e., 'busy'), if it is '0'.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} Abstract Control and Status Register (abstractcs, at Debug Module Offset 0x16)
:name: tab-abstractcs
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:29
  - Reserved
  - R
  - 0
* - progbufsize
  - 28:24
  - Not implemented

    **Note**: VeeR EL2 does not implement a Program Buffer.
  - R
  - 0
* - Reserved
  - 23:13
  - Reserved
  - R
  - 0
* - busy
  - 12
  - Abstract command interface activity:

    - 0: Abstract command interface idle

    - 1: Abstract command currently being executed

    **Note**: ‘Busy’ indication set when command register (see [](debugging.md#abstract-command-register-command)) is written, cleared after command has completed.
  - R
  - 0
* - Reserved
  - 11
  - Reserved
  - R
  - 0
* - cmderr
  - 10:8
  - Set if abstract command fails.

    Reason for failure:
    - 0 (none): No error
    - 1 (busy): Abstract command was executing when `command`, `abstractcs`, or `abstractauto` register was written, or when `data0` or `data1` register was read or written
    - 2 (not supported): Requested command or option not supported, regardless of whether hart is running or not (i.e., illegal command, access register command not word-sized or postexec bit set, or access memory command size larger than word)
    - 3 (exception): Exception occurred while executing abstract command (i.e., illegal register address, address outside of ICCM/DCCM/PIC memory range but in internal memory region, ICCM/DCCM uncorrectable ECC error, or ICCM/PIC access not word-sized)
    - 4 (halt/resume): Abstract command couldn't execute because hart wasn't in required state (running/halted), or unavailable
    - 5 (bus): Abstract command failed for SoC memory access due to bus error (e.g., unmapped address, uncorrectable error, incorrect alignment, or unsupported access size)
    - 6: Reserved
    - 7 (other): Register or memory access size not 32 bits wide or unaligned

    **Note**: Bits in this field remain set until cleared by writing ‘111’.

    **Note**: Next abstract command not started until value is reset to ‘0’.

    **Note**: Only contains valid value if *busy* is ‘0’.
  - R/W1C
  - 0
* - Reserved
  - 7:4
  - Reserved
  - R
  - 0
* - datacount
  - 3:0
  - 2 data registers implemented as part of abstract command interface
  - R
  - 2
:::

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
  - R0/W
  - 0
* - **Access Memory Command (ICCM, DCCM, PIC, and SoC Memories)**
  -
  -
  -
  -
* - aamvirtual
  - 23
  - Not implemented (i.e., 0: Addresses are physical)

    **Note**: VeeR EL2 supports physical addresses only. Since physical and virtual address are identical, no error is flagged [^fn-debugging-2] even if written to ‘1’.
  - R
  - 0
* - aamsize
  - 22:20
  - Memory access size:
    - 0: 8-bit access (for DCCM and SoC memories)
    - 1: 16-bit access (for DCCM and SoC memories)
    - 2: 32-bit access (for ICCM, DCCM, PIC, and SoC memories)

    **Note**: Writing this field to value ‘0’ or ‘1’ for ICCM or PIC memory access causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘3’.

    **Note**: Other size values not implemented. Writing this field to value higher than ‘2’ causes abstract command to fail and *cmderr* field of `abstractcs` register to be set to ‘2’.
  - R/W
  - 2
* - aampostincrement
  - 19
  - Access memory post-increment control:
    - 0: No post-increment
    - 1: After every successful access memory command completion, increment `data1` register (which contains memory address, see [Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data0-1)) by number of bytes encoded in *aamsize* field
  - R/W
  - 0
* - Reserved
  - 18:17
  - Reserved
  - R
  - 0
* - write
  - 16
  - Read or write memory location:
    * 0 (read): Copy data from memory location specified in data1 register (i.e., address) into data0 register (i.e., data) ([Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data0-1))
    * 1 (write): Copy data from data0 register (i.e., data) into memory location specified in data1 register (i.e., address) ([Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data0-1))
  - R0/W
  - 0
* - target-specific
  - 15:14
  - Not implemented

    **Note**: VeeR EL2 does not use target-specific bits.
  - R
  - 0
* - Reserved
  - 13:0
  - Reserved
  - R
  - 0
:::

[^fn-debugging-2]: The RISC-V Debug specification [[3]](intro.md#ref-3) states that an implementation must fail accesses that it does not support.
However, the Debug Task Group community agreed in an email exchange on the group’s reflector as well as in a group meeting that not reporting an error is acceptable for implementations without address translation (i.e., the physical address equals the virtual address).

#### Abstract Command Autoexec Register (abstractauto)

The `abstractauto` register controls if reading or writing the `data0/1` registers (see [Abstract Data 0 / 1 Registers (data0/1)](debugging.md#abstract-data-0-1-registers-data0-1)) automatically triggers the next execution of the abstract command in the `command` register (see [](debugging.md#abstract-command-register-command)).
This feature allows more efficient burst accesses.

Writing this register while an abstract command is executing causes the *cmderr* field in the abstractcs register (see [](debugging.md#abstract-control-and-status-register-abstractcs)) to be set to '1' (i.e., 'busy'), if it is '0'.

This register is mapped to the Debug Module Interface address space.

:::{list-table} Abstract Command Autoexec Register (abstractauto, at Debug Module Offset 0x18)
:name: tab-abstractauto
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
* - autoexecdata1
  - 1
  - Auto-execution control for `data1` register:
    * 0: No automatic triggering of abstract command execution
    * 1: Reading or writing `data1` causes abstract command to be executed again
  - R/W
  - 0
* - autoexecdata0
  - 0
  - Auto-execution control for `data0` register:
    - 0: No automatic triggering of abstract command execution
    - 1: Reading or writing `data0` causes abstract command to be executed again
  - R/W
  - 0
:::

### Abstract Data 0 / 1 Registers (data0/1)

The `data0/1` registers are basic read/write registers which may be read or changed by abstract commands.

:::{note}
The *datacount* field of the `abstractcs` register (see {numref}`tab-abstractcs`) indicates that 2 (out of possible 12) registers are implemented in VeeR EL2.
:::

The `data0` register sources the value for and provides the return value of an abstract command.
The `data1` register provides the address for an access memory abstract command.

:::{note}
Selecting an address outside of the ICCM, DCCM, or PIC memory range but in one of the core-internal memory regions causes the abstract command to fail and the *cmderr* field of the `abstractcs` register to be set to '3'. Similarly, selecting an unmapped SoC memory address causes the abstract command to fail, provided the SoC responds with a bus error, and the *cmderr* field of the `abstractcs` register to be set to '5'.
:::

Accessing these registers while an abstract command is executing causes the *cmderr* field of the `abstractcs` register (see {numref}`tab-abstractcs`) to be set to '1' (i.e., 'busy'), if it was '0'.

Attempts to write the `data0/1` registers while the *busy* bit of the abstractcs register (see {numref}`tab-abstractcs`) is set does not change their value.

The values in these registers may not be preserved after an abstract command has been executed.
The only guarantees on their contents are the ones offered by the executed abstract command.
If the abstract command fails, no assumptions should be made about the contents of these registers.

These registers are mapped to the Debug Module Interface address space.

:::{list-table} Abstract Data 0 / 1 Register (data0/1, at Debug Module Offset 0x04 / 0x05)
:name: tab-data-0-1
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - data
  - 31:0
  - Abstract command data:
    - data0: data value (access register and access memory command)
    - data1: address (access memory command)
  - R/W
  - 0
:::

#### System Bus Access Control and Status Register (sbcs)

The `sbcs` register provides controls and status information of the system bus access interface.

:::{note}
The system bus access method provides access to SoC memories only. Access to ICCM, DCCM, and PIC memory ranges is only available using the access memory abstract command method.
:::

:::{note}
The operation of the system bus access method does not depend on the core's state. SoC memory locations may be accessed using this method even when the core is running.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} System Bus Access Control and Status Register (sbcs, at Debug Module Offset 0x38)
:name: tab-sbcs
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - sbversion
  - 31:29
  - System Bus interface conforms to RISC-V Debug specification, Version 0.13.2
  - R
  - 1
* - Reserved
  - 28:23
  - Reserved
  - R
  - 0
* - sbbusyerror
  - 22
  - Set when debugger attempts to read data while a read is in progress, or when debugger initiates a new access while one is still in progress (i.e., while *sbbusy* bit is set). Remains set until explicitly cleared by debugger.

    **Note**: When set, Debug Module cannot initiate more system bus accesses.
  - R/W1C
  - 0
* - sbbusy
  - 21
  - System bus master interface status:
    * 0: System bus master idle
    * 1: System bus master busy (Set when read or write access requested, remains set until access fully completed)

    **Note**: Writes to this register while *sbbusy* bit is set result in undefined behavior. Debugger must not write this register until it reads *sbbusy* bit as ‘0’.

    **Note**: Bit reflects if system bus master interface is busy, not status of system bus itself.
  - R
  - 0
* - sbreadonaddr
  - 20
  - Auto-read on address write:
    - 0: No auto-read on address write
    - 1: Every write to `sbaddress0` (see [](debugging.md#system-bus-address-310-register-sbaddress0)) automatically triggers system bus read at new address
  - R/W
  - 0
* - sbaccess
  - 19:17
  - Access size for system bus access:
    - 0: 8-bit access
    - 1: 16-bit access
    - 2: 32-bit access
    - 3: 64-bit access

    **Note**: Other values not supported. No access performed, *sberror* field set to ‘4’.
  - R/W
  - 2
* - sbautoincrement
  - 16
  - Auto-address increment:
    - 0: No auto-address increment
    - 1: `sbaddress0` register (see [](debugging.md#system-bus-address-310-register-sbaddress0)) incremented by access size (in bytes) selected in sbaccess field after every successful system bus access
  - R/W
  - 0
* - sbreadondata
  - 15
  - Auto-read on data read:
    - 0: No auto-read on data read
    - 1: Every read from `sbdata0` register (see [](debugging.md#system-bus-data-310-register-sbdata0)) automatically triggers new system bus read at (possibly auto- incremented) address
  - R/W
  - 0
* - sberror
  - 14:12
  - Set when Debug Module's system bus master encounters an error: While this field is non-zero, no more system bus accesses can be initiated by the Debug Module.
    - 0: No bus error
    - 1: Not implemented (no timeout)
    - 2: Bad address accessed
    - 3: Alignment error
    - 4: Access of unsupported size requested
    - 5..7: Not implemented (no other error conditions)

    **Note**: Bits in this field remain set until cleared by writing ‘111’.

    **Note**: Debug Module may not initiate next system bus access until value is reset to ‘0’.
  - R/W1C
  - 0
* - sbasize
  - 11:5
  - Width of system bus addresses (in bits)
  - R
  - 32
* - sbaccess128
  - 4
  - 128-bit system bus accesses not supported
  - R
  - 0
* - sbaccess64
  - 3
  - 64-bit system bus accesses supported
  - R
  - 1
* - sbaccess32
  - 2
  - 32-bit system bus accesses supported
  - R
  - 1
* - sbaccess16
  - 1
  - 16-bit system bus accesses supported
  - R
  - 1
* - sbaccess8
  - 0
  - 8-bit system bus accesses supported
  - R
  - 1
:::

#### System Bus Address 31:0 Register (sbaddress0)

The `sbaddress0` register provides the address of the system bus access.

If the *sbreadonaddr* bit of the `sbcs` register is '1', writing the `sbaddress0` register triggers a system bus read access from the new address.

:::{note}
The *sberror* and *sbbusyerror* fields of the `sbcs` register must both be '0' for a system bus read operation to be performed.
:::

:::{note}
If the system bus master interface is busy (i.e., *sbbusy* bit of the `sbcs` register is '1') when a write access to this register is performed, the *sbbusyerror* bit in the `sbcs` register is set and the access is aborted.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} System Bus Address 31:0 Register (sbaddress0, at Debug Module Offset 0x39)
:name: tab-sbaddress0
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - address
  - 31:0
  - System bus address
  - R/W
  - 0
:::

#### System Bus Data 31:0 Register (sbdata0)

The `sbdata0` register holds the right-justified lower bits for system bus read and write accesses.

A successful system bus read updates the `sbdata0/1` registers with the value read from the system bus at the memory location addressed by the sbaddress0 register.
If the width of the read access is less than 64 bits, the remaining high bits may take on any value.

Reading the `sbdata0` register provides the current value of this register.
If the *sbreadondata* bit of the sbcs register is '1', reading this register also triggers a system bus read access which updates the `sbdata0/1` registers with the value read from the memory location addressed by the `sbaddress0` register.

Writing the `sbdata0` register triggers a system bus write access which updates the memory location addressed by the `sbaddress0` register with the new values in the `sbdata0/1` registers.

:::{note}
Only the `sbdata0` register has this behavior. Accessing the `sbdata1` register has no side effects.
A debugger must access the `sbdata1` register first, before accessing the sbdata0 register.
:::

:::{note}
The *sberror* and *sbbusyerror* fields of the `sbcs` register must both be '0' for a system bus read or write operation to be performed.
:::

:::{note}
If the system bus master interface is busy (i.e., *sbbusy* bit of the sbcs register is '1') when a read or write access to this register is performed, the *sbbusyerror* bit in the `sbcs` register is set and the access is aborted.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} System Bus Data 31:0 Register (sbdata0, at Debug Module Offset 0x3C)
:name: tab-sbdata0
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - data
  - 31:0
  - System bus data[31:0] for system bus read and write accesses
  - R/W
  - 0
:::

#### System Bus Data 63:32 Register (sbdata1)

The `sbdata1` register holds the upper 32 bits of the 64-bit wide system bus for read and write accesses.

:::{note}
If the system bus master interface is busy (i.e., *sbbusy* bit of the sbcs register is '1') when a read or write access to this register is performed, the *sbbusyerror* bit in the `sbcs` register is set and the access is aborted.
:::

This register is mapped to the Debug Module Interface address space.

:::{list-table} System Bus Data 63:32 Register (sbdata1, at Debug Module Offset 0x3D)
:name: tab-sbdata1
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - data
  - 31:0
  - System bus data[63:32] for system bus read and write accesses
  - R/W
  - 0
:::

#### DCCM Write-Readback Fault Status Register (dccm_wr_rdbk_status)

The `dccm_wr_rdbk_status` register exposes the first-fault-wins sticky capture from the [DCCM write-readback check](error-protection.md#dccm-write-readback-check) (only meaningful when built with `RV_DCCM_WR_READBACK`, otherwise this register always reads 0).
Together with `dccm_wr_rdbk_data` and `dccm_wr_rdbk_ecc`, it is intended for pentest and reliability debugging.

The *valid* field is set the first time a write-readback fault occurs after being cleared.
Subsequent faults are not captured while *valid* is still set, so a debugger always sees the earliest fault since the last clear.

Writing '1' to the *valid* field clears it, re-arming capture for the next fault.

:::{list-table} DCCM Write-Readback Fault Status Register (dccm_wr_rdbk_status, at Debug Module Offset 0x70)
:name: tab-dccm-wr-rdbk-status
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - address
  - DCCM_BITS-1:0
  - Address of the captured fault (valid iff *valid* is set)
  - R
  - 0
* - reserved
  - 30:DCCM_BITS
  - Reserved, reads 0x0
  - R
  - 0
* - valid
  - 31
  - A fault is latched, write '1' to clear
  - R/W1C
  - 0
:::

#### DCCM Write-Readback Fault Data Register (dccm_wr_rdbk_data)

The `dccm_wr_rdbk_data` register holds the actual data that was read back during the latched fault captured in `dccm_wr_rdbk_status`, i.e. the value that failed to match what was written.
It is valid iff the *valid* field of `dccm_wr_rdbk_status` is set, and is cleared the same way (by writing '1' to that field).

:::{list-table} DCCM Write-Readback Fault Data Register (dccm_wr_rdbk_data, at Debug Module Offset 0x71)
:name: tab-dccm-wr-rdbk-data
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - data
  - 31:0
  - Actual data read back during the latched fault
  - R
  - 0
:::

#### DCCM Write-Readback Fault ECC Register (dccm_wr_rdbk_ecc)

The `dccm_wr_rdbk_ecc` register holds the ECC bits associated with the data in `dccm_wr_rdbk_data`, i.e. the ECC bits that were read back alongside the actual data during the latched fault.
Together, `dccm_wr_rdbk_data` and `dccm_wr_rdbk_ecc` form the complete, ECC-protected DCCM word at adjacent Debug Module offsets.
It is valid iff the *valid* field of `dccm_wr_rdbk_status` is set, and is cleared the same way (by writing '1' to that field).

:::{list-table} DCCM Write-Readback Fault ECC Register (dccm_wr_rdbk_ecc, at Debug Module Offset 0x72)
:name: tab-dccm-wr-rdbk-ecc
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - ecc
  - DCCM_ECC_WIDTH-1:0
  - ECC bits read back alongside the faulty data
  - R
  - 0
* - reserved
  - 31:DCCM_ECC_WIDTH
  - Reserved, reads 0x0
  - R
  - 0
:::
```

### docs/source/memory-map.md

```markdown
The 32-bit address space is subdivided into sixteen fixed-sized, contiguous 256MB regions.
...
Core-local memories and system bus-attached memories must be mapped to different regions. Mapping both classes of memory types to the same region is not allowed.
```
