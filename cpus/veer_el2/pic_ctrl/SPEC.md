# Implement `el2_pic_ctrl`

Implement the complete `el2_pic_ctrl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_pic_ctrl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_pic_ctrl 
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
                  (

                     input  logic                   clk,                  // Core clock
                     input  logic                   free_clk,             // free clock
                     input  logic                   rst_l,                // Reset for all flops
                     input  logic                   clk_override,         // Clock over-ride for gating
                     input  logic                   io_clk_override,      // PIC IO  Clock over-ride for gating
                     input  logic [pt.PIC_TOTAL_INT_PLUS1-1:0]   extintsrc_req,  // Interrupt requests
                     input  logic [31:0]            picm_rdaddr,          // Address of the register
                     input  logic [31:0]            picm_wraddr,          // Address of the register
                     input  logic [31:0]            picm_wr_data,         // Data to be written to the register
                     input  logic                   picm_wren,            // Write enable to the register
                     input  logic                   picm_rden,            // Read enable for the register
                     input  logic                   picm_mken,            // Read the Mask for the register
                     input  logic [3:0]             meicurpl,             // Current Priority Level
                     input  logic [3:0]             meipt,                // Current Priority Threshold

                     output logic                   mexintpend,           // External interrupt request to the core
                     output logic [7:0]             claimid,              // Claim Id of the requested interrupt
                     output logic [3:0]             pl,                   // Priority level of the requested interrupt
                     output logic [31:0]            picm_rd_data,         // Read data of the register
                     output logic                   mhwakeup,             // Wake-up interrupt request
                     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
                     /*pragma coverage off*/
                     input  logic                   scan_mode             // scan mode
                     /*pragma coverage on*/

);
```

## Parent instantiation

### design/el2_veer.sv

```verilog
   el2_pic_ctrl  #(.pt(pt)) pic_ctrl_inst (
                                            .clk(free_l2clk),
                                            .clk_override(dec_tlu_pic_clk_override),
                                            .io_clk_override(dec_tlu_picio_clk_override),
                                            .picm_mken (picm_mken),
                                            .extintsrc_req({extintsrc_req[pt.PIC_TOTAL_INT:1],1'b0}),
                                            .pl(pic_pl[3:0]),
                                            .claimid(pic_claimid[7:0]),
                                            .meicurpl(dec_tlu_meicurpl[3:0]),
                                            .meipt(dec_tlu_meipt[3:0]),
                                            .rst_l(core_rst_l),
                                            .*);
```

## Dependency declarations

### design/el2_pic_ctrl.sv

```verilog
module el2_cmp_and_mux #(parameter ID_BITS=8,
                               INTPRIORITY_BITS = 4)
                    (
                        input  logic [ID_BITS-1:0]       a_id,
                        input  logic [INTPRIORITY_BITS-1:0] a_priority,

                        input  logic [ID_BITS-1:0]       b_id,
                        input  logic [INTPRIORITY_BITS-1:0] b_priority,

                        output logic [ID_BITS-1:0]       out_id,
                        output logic [INTPRIORITY_BITS-1:0] out_priority

                    );
// ...
module el2_configurable_gw (
                             input logic gw_clk,
                             input logic rawclk,
                             input logic clken,
                             input logic rst_l,
                             input logic extintsrc_req ,
                             input logic meigwctrl_polarity ,
                             input logic meigwctrl_type ,
                             input logic meigwclr ,

                             output logic extintsrc_req_config
                            );
```

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
module rvsyncss_fpga #(parameter WIDTH = 251)
   (
     input  logic                 gw_clk,
     input  logic                 rawclk,
     input  logic                 clken,
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

## Related source code

### design/lsu/el2_lsu_dccm_ctl.sv

```verilog
   // PIC signals. PIC ignores the lower 2 bits of address since PIC memory registers are 32-bits
   assign picm_wren          = (lsu_pkt_r.valid & lsu_pkt_r.store & addr_in_pic_r & lsu_commit_r) | dma_pic_wen;
   assign picm_rden          = lsu_pkt_d.valid & lsu_pkt_d.load  & addr_in_pic_d;
   assign picm_mken          = lsu_pkt_d.valid & lsu_pkt_d.store & addr_in_pic_d;  // Get the mask for stores
   assign picm_rdaddr[31:0]  = pt.PIC_BASE_ADDR | {{32-pt.PIC_BITS{1'b0}},lsu_addr_d[pt.PIC_BITS-1:0]};

   assign picm_wraddr[31:0]  = pt.PIC_BASE_ADDR | {{32-pt.PIC_BITS{1'b0}},(dma_pic_wen ? dma_mem_addr[pt.PIC_BITS-1:0] : lsu_addr_r[pt.PIC_BITS-1:0])};

   assign picm_wr_data[31:0] = dma_pic_wen ? dma_mem_wdata[31:0] : store_datafn_lo_r[31:0];

   assign picm_mask_data_m[31:0] = picm_rd_data_m[31:0];
   assign picm_rd_data_m[63:0]   = {picm_rd_data[31:0],picm_rd_data[31:0]};
```

### design/lsu/el2_lsu_lsc_ctl.sv

```verilog
   assign store_data_m[31:0] = (picm_mask_data_m[31:0] | {32{~addr_in_pic_m}}) & ((lsu_pkt_m.store_data_bypass_m) ? lsu_result_m[31:0] : store_data_pre_m[31:0]);
// ...
   rvdff #(1) addr_in_pic_mff(.din(addr_in_pic_d), .dout(addr_in_pic_m), .clk(lsu_c1_m_clk), .*);
   rvdff #(1) addr_in_pic_rff(.din(addr_in_pic_m), .dout(addr_in_pic_r), .clk(lsu_c1_r_clk), .*);
```

## Documentation

### docs/source/interrupts.md

```markdown
Each external interrupt source connects to a dedicated gateway.
The gateway is responsible for synchronizing the interrupt request to the core's clock domain, and for converting the request signal to a common interrupt request format (i.e., active-high and level-triggered) for the PIC.
The PIC core can only handle one single interrupt request per interrupt source at a time.
...
The PIC core's responsibility is to evaluate all pending and enabled interrupt requests and to pick the highest-priority request with the lowest interrupt source ID.
It then compares this priority with a programmable priority threshold and, to support nested interrupts, the priority of the interrupt handler if one is currently running.
If the picked request's priority is higher than both thresholds, it sends an interrupt notification to the core.
In addition, it compares the picked request's priority with the wake-up threshold (highest priority level) and sends a wake-up signal to the core, if the priorities match.
The PIC core also provides the interrupt source ID of the picked request in a status register.
...
The PIC logic always operates in regular priority order. When in reverse priority order mode, firmware reads and writes the control/status registers with reverse priority order values. The values written to and read from the control/status registers are inverted. Therefore, from the firmware's perspective, the PIC operates in reverse priority order.
...
11. Maximum priority is compared to the higher of the two priority thresholds (i.e., *prithresh* field of the `meipt` and *currpri* field of the `meicurpl` registers):
    1. If maximum priority is higher than the two priority thresholds, the `mexintirq` signal is asserted.
    1. If maximum priority is the same as or lower than the two priority thresholds, the `mexintirq` signal is deasserted.
12. The `mexintirq` signal's state is then reflected in the meip bit of the RISC-V hart's `mip` register.
13. In addition, maximum priority is compared to the wake-up priority level:
    1. If maximum priority is 15 (or 0 for reversed priority order), the wake-up notification (WUN) bit is set.
    1. If maximum priority is lower than 15 (or 0 for reversed priority order), the wake-up notification (WUN) bit is not set.
14. The WUN state is indicated to the target hart with the `mhwakeup` signal [^fn-interrupts-1].
...
16. The external interrupt handler writes to the `meicpct`register to trigger the capture of the interrupt source ID of the currently highest-priority pending external interrupt (in the meihap register) and its corresponding priority (in the `meicidpl` register). Note that the captured content of the claimid field of the meihap register and its corresponding priority in the `meicidpl` register is neither affected by the priority thresholds (prithresh field of the meipt and currpri field of the `meicurpl` registers) nor by the core's external interrupt enable bit (meie bit of the RISC-V hart's `mie` register).
...
All reserved and unused bits in these control/status registers must be hardwired to '0'. Unless otherwise noted, all read/write control/status registers must have WARL (Write Any value, Read Legal value) behavior.
...
:::{note}
Accessing unused addresses within the 32KB PIC address range do not trigger an unmapped address exception. Reads to unmapped addresses return 0, writes to unmapped addresses are silently dropped.
:::
...
:::{list-table} PIC Configuration Register (mpiccfg, at PIC_base_addr+0x3000)
:name: tab-pic-configuration-register

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
* - priord
  - 0
  - Priority order:
    - 0: RISC-V standard compliant priority order (0=lowest to 15=highest)
    - 1: Reverse priority order (15=lowest to 0=highest)
  - R/W
  - 0
:::
...
:::{list-table} External Interrupt Priority Level Register S=1..255 (meiplS, at PIC_base_addr+S*4)
:name: tab-external-interrupt-priority-level-register

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:4
  - Reserved
  - R
  - 0
* - priority
  - 3:0
  - External interrupt priority level for interrupt source ID S
    - RISC-V standard compliant priority order:
      - 0: Never interrupt
      - 1..15: Interrupt priority level (1 is lowest, 15 is highest)
    - Reverse priority order:
      - 15: Never interrupt
      - 14..0: Interrupt priority level (14 is lowest, 0 is highest)
  - R/W
  - 0
:::
...
:::{list-table} External Interrupt Pending Register X=0..7 (meipX, at PIC_base_addr+0x1000+X*4)
:name: tab-external-interrupt-pending-register

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - `X = 0, Y = 1..31 and X = 1..7, Y = 0..31`
  -
  -
  -
  -
* - intpendX*32+Y
  - Y
  - External interrupt pending for interrupt source ID X*32+Y:
    - 0: Interrupt not pending
    - 1: Interrupt pending
  - R
  - 0
* - `X = 0, Y = 0`
  -
  -
  -
  -
* - Reserved
  - 0
  - Reserved
  - R
  - 0
:::
...
:::{list-table} External Interrupt Enable Register *S=1..255* (meieS, at PIC_base_addr+0x2000+S*4)
:name: tab-external-interrupt-enable-register

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
* - inten
  - 0
  - External interrupt enable for interrupt source ID S:
    - 0: Interrupt disabled
    - 1: Interrupt enabled
  - R/W
  - 0
:::
...
:::{list-table} External Interrupt Gateway Configuration Register S=1..255 (meigwctrlS, at PIC_base_addr+0x4000+S*4)
:name: tab-external-interrupt-gateway-configuration-register

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
* - type
  - 1
  - External interrupt type for interrupt source ID S:
    - 0: Level-triggered interrupt
    - 1: Edge-triggered interrupt
  - R/W
  - 0
* - polarity
  - 0
  - External interrupt polarity for interrupt source ID S:
    - 0: Active-high interrupt
    - 1: Active-low interrupt
  - R/W
  - 0
:::
...
Each configurable gateway has a dedicated clear register to reset its interrupt pending (IP) bit.
For edge-triggered interrupts, firmware must clear the gateway's IP bit while servicing the external interrupt of source ID S by writing to the `meigwclrS` register.
...
:::{list-table} External Interrupt Gateway Clear Register *S=1..255* (meigwclrS, at PIC_base_addr+0x5000+S*4)
:name: tab-external-interrupt-gateway-clear-register

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:0
  - Reserved
  - R0/WA
  - 0
:::
```
