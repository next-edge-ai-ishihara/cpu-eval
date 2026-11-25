# Implement `el2_dma_ctrl`

Implement the complete `el2_dma_ctrl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dma_ctrl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_dma_ctrl 
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic         clk,
   input logic         free_clk,
   input logic         rst_l,
   input logic         dma_bus_clk_en, // slave bus clock enable
   input logic         clk_override,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic         scan_mode,
   /*pragma coverage on*/

   // Debug signals
   input logic [31:0]  dbg_cmd_addr,
   input logic [31:0]  dbg_cmd_wrdata,
   input logic         dbg_cmd_valid,
   input logic         dbg_cmd_write, // 1: write command, 0: read_command
   input logic [1:0]   dbg_cmd_type, // 0:gpr 1:csr 2: memory
   input logic [1:0]   dbg_cmd_size, // size of the abstract mem access debug command

   input  logic        dbg_dma_bubble,   // Debug needs a bubble to send a valid
   output logic        dma_dbg_ready,    // DMA is ready to accept debug request

   output logic        dma_dbg_cmd_done,
   output logic        dma_dbg_cmd_fail,
   output logic [31:0] dma_dbg_rddata,

   // Core side signals
   output logic        dma_dccm_req,  // DMA dccm request (only one of dccm/iccm will be set)
   output logic        dma_iccm_req,  // DMA iccm request
   output logic [2:0]  dma_mem_tag,   // DMA Buffer entry number
   output logic [31:0] dma_mem_addr,  // DMA request address
   output logic [2:0]  dma_mem_sz,    // DMA request size
   output logic        dma_mem_write, // DMA write to dccm/iccm
   output logic [63:0] dma_mem_wdata, // DMA write data

   input logic         dccm_dma_rvalid,    // dccm data valid for DMA read
   input logic         dccm_dma_ecc_error, // ECC error on DMA read
   input logic [2:0]   dccm_dma_rtag,      // Tag of the DMA req
   input logic [63:0]  dccm_dma_rdata,     // dccm data for DMA read
   input logic         iccm_dma_rvalid,    // iccm data valid for DMA read
   input logic         iccm_dma_ecc_error, // ECC error on DMA read
   input logic [2:0]   iccm_dma_rtag,      // Tag of the DMA req
   input logic [63:0]  iccm_dma_rdata,     // iccm data for DMA read

   output logic        dma_active,         // DMA is busy
   output logic        dma_dccm_stall_any, // stall dccm pipe (bubble) so that DMA can proceed
   output logic        dma_iccm_stall_any, // stall iccm pipe (bubble) so that DMA can proceed
   input logic         dccm_ready, // dccm ready to accept DMA request
   input logic         iccm_ready, // iccm ready to accept DMA request
   input logic [2:0]   dec_tlu_dma_qos_prty,    // DMA QoS priority coming from MFDC [18:15]

   // PMU signals
   output logic        dma_pmu_dccm_read,
   output logic        dma_pmu_dccm_write,
   output logic        dma_pmu_any_read,
   output logic        dma_pmu_any_write,

   // AXI Write Channels
   input  logic                        dma_axi_awvalid,
   output logic                        dma_axi_awready,
   input  logic [pt.DMA_BUS_TAG-1:0]   dma_axi_awid,
   input  logic [31:0]                 dma_axi_awaddr,
   input  logic [2:0]                  dma_axi_awsize,


   input  logic                        dma_axi_wvalid,
   output logic                        dma_axi_wready,
   input  logic [63:0]                 dma_axi_wdata,
   input  logic [7:0]                  dma_axi_wstrb,

   output logic                        dma_axi_bvalid,
   input  logic                        dma_axi_bready,
   output logic [1:0]                  dma_axi_bresp,
   output logic [pt.DMA_BUS_TAG-1:0]   dma_axi_bid,

   // AXI Read Channels
   input  logic                        dma_axi_arvalid,
   output logic                        dma_axi_arready,
   input  logic [pt.DMA_BUS_TAG-1:0]   dma_axi_arid,
   input  logic [31:0]                 dma_axi_araddr,
   input  logic [2:0]                  dma_axi_arsize,

   output logic                        dma_axi_rvalid,
   input  logic                        dma_axi_rready,
   output logic [pt.DMA_BUS_TAG-1:0]   dma_axi_rid,
   output logic [63:0]                 dma_axi_rdata,
   output logic [1:0]                  dma_axi_rresp,
   output logic                        dma_axi_rlast
);
```

## Parent instantiation

### design/el2_veer.sv

```verilog
   assign core_dbg_cmd_done = dma_dbg_cmd_done | dec_dbg_cmd_done;
   assign core_dbg_cmd_fail = dma_dbg_cmd_fail | dec_dbg_cmd_fail;
   assign core_dbg_rddata[31:0] = dma_dbg_cmd_done ? dma_dbg_rddata[31:0] : dec_dbg_rddata[31:0];
// ...
   el2_dma_ctrl #(.pt(pt)) dma_ctrl (
                                      .clk(free_l2clk),
                                      .rst_l(core_rst_l),
                                      .clk_override(dec_tlu_misc_clk_override),

                                      // AXI signals
                                      .dma_axi_awvalid(dma_axi_awvalid_int),
                                      .dma_axi_awid(dma_axi_awid_int[pt.DMA_BUS_TAG-1:0]),
                                      .dma_axi_awaddr(dma_axi_awaddr_int[31:0]),
                                      .dma_axi_awsize(dma_axi_awsize_int[2:0]),
                                      .dma_axi_wvalid(dma_axi_wvalid_int),
                                      .dma_axi_wdata(dma_axi_wdata_int[63:0]),
                                      .dma_axi_wstrb(dma_axi_wstrb_int[7:0]),
                                      .dma_axi_bready(dma_axi_bready_int),

                                      .dma_axi_arvalid(dma_axi_arvalid_int),
                                      .dma_axi_arid(dma_axi_arid_int[pt.DMA_BUS_TAG-1:0]),
                                      .dma_axi_araddr(dma_axi_araddr_int[31:0]),
                                      .dma_axi_arsize(dma_axi_arsize_int[2:0]),
                                      .dma_axi_rready(dma_axi_rready_int),

                                      .*
                                      );
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
module rvdffsc #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );
// ...
module rvdff_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );
// ...
module rvdffs_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );
// ...
module rvdffsc_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
     input logic             clk,
     input logic             clken,
     input logic             rawclk,
     input logic             rst_l,

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
module rvrangecheck  #(CCM_SADR = 32'h0,
                       CCM_SIZE  = 128) (
   input  logic [31:0]   addr,                             // Address to be checked for range
   output logic          in_range,                            // S_ADDR <= start_addr < E_ADDR
   output logic          in_region
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

### design/dbg/el2_dbg.sv

```verilog
   assign abmem_addr[31:0]      = data1_reg[31:0];
   assign abmem_addr_core_local = (abmem_addr_in_dccm_region | abmem_addr_in_iccm_region | abmem_addr_in_pic_region);
   assign abmem_addr_external   = ~abmem_addr_core_local;

   assign abmem_addr_in_dccm_region = (abmem_addr[31:28] == pt.DCCM_REGION) & pt.DCCM_ENABLE;
   assign abmem_addr_in_iccm_region = (abmem_addr[31:28] == pt.ICCM_REGION) & pt.ICCM_ENABLE;
   assign abmem_addr_in_pic_region  = (abmem_addr[31:28] == pt.PIC_REGION);

   // interface for the core
   assign dbg_cmd_addr[31:0]    = (command_reg[31:24] == 8'h2) ? data1_reg[31:0]  : {20'b0, command_reg[11:0]};
   assign dbg_cmd_wrdata[31:0]  = data0_reg[31:0];
   assign dbg_cmd_valid         = (dbg_state == CORE_CMD_START) & ~((|abstractcs_reg[10:8]) | ((command_reg[31:24] == 8'h0) & ~command_reg[17]) | ((command_reg[31:24] == 8'h2) & abmem_addr_external)) & dma_dbg_ready;
   assign dbg_cmd_write         = command_reg[16];
   assign dbg_cmd_type[1:0]     = (command_reg[31:24] == 8'h2) ? 2'b10 : {1'b0, (command_reg[15:12] == 4'b0)};
   assign dbg_cmd_size[1:0]     = command_reg[21:20];
// ...
   // Ask DMA to stop taking bus trxns since debug request is done
   assign dbg_dma_bubble = ((dbg_state == CORE_CMD_START) & ~(|abstractcs_reg[10:8])) | (dbg_state == CORE_CMD_WAIT);
```

### design/lsu/el2_lsu_lsc_ctl.sv

```verilog
   //Create DMA packet
   always_comb begin
      dma_pkt_d = '0;
      dma_pkt_d.valid   = dma_dccm_req;
      dma_pkt_d.dma     = 1'b1;
      dma_pkt_d.store   = dma_mem_write;
      dma_pkt_d.load    = ~dma_mem_write;
      dma_pkt_d.by      = (dma_mem_sz[2:0] == 3'b0);
      dma_pkt_d.half    = (dma_mem_sz[2:0] == 3'b1);
      dma_pkt_d.word    = (dma_mem_sz[2:0] == 3'b10);
      dma_pkt_d.dword   = (dma_mem_sz[2:0] == 3'b11);
   end
```

### design/lib/ahb_to_axi4.sv

```verilog
       // Address check  dccm
       rvrangecheck #(.CCM_SADR(pt.DCCM_SADR),
                      .CCM_SIZE(pt.DCCM_SIZE)) addr_dccm_rangecheck (
          .addr(ahb_haddr_q[31:0]),
          .in_range(ahb_addr_in_dccm),
          .in_region(ahb_addr_in_dccm_region_nc)
       );

      // Address check  iccm
      if (pt.ICCM_ENABLE == 1) begin: GenICCM
         rvrangecheck #(.CCM_SADR(pt.ICCM_SADR),
                        .CCM_SIZE(pt.ICCM_SIZE)) addr_iccm_rangecheck (
            .addr(ahb_haddr_q[31:0]),
            .in_range(ahb_addr_in_iccm),
            .in_region(ahb_addr_in_iccm_region_nc)
         );
      end else begin: GenNoICCM
         assign ahb_addr_in_iccm = '0;
         assign ahb_addr_in_iccm_region_nc = '0;
      end

      // PIC memory address check
      rvrangecheck #(.CCM_SADR(pt.PIC_BASE_ADDR),
                     .CCM_SIZE(pt.PIC_SIZE)) addr_pic_rangecheck (
         .addr(ahb_haddr_q[31:0]),
         .in_range(ahb_addr_in_pic),
         .in_region(ahb_addr_in_pic_region_nc)
      );
```

## Documentation

### docs/source/debugging.md

```markdown
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
```

### docs/source/memory-map.md

```markdown
### Access

The DMA slave port allows read/write access to the core's ICCM and DCCM.
However, the PIC memory-mapped control registers are not accessible via the DMA port.
...
### Quality Of Service

Accesses to the ICCM and DCCM by the core have higher priority if the DMA FIFO is not full.
However, to avoid starvation, the DMA slave port's DMA controller may periodically request a stall to get access to the pipe if a DMA request is continuously blocked.

The *dqc* field in the `mfdc` register (see {numref}`tab-feature-disable-cr`) specifies the maximum number of clock cycles a DMA access request waits at the head of the DMA FIFO before requesting a bubble to access the pipe.
For example, if *dqc* is 0, a DMA access requests a bubble immediately (i.e., in the same cycle); if *dqc* is 7 (the default value), a waiting DMA access requests a bubble on the 8th cycle.
For a DMA access to the ICCM, it may take up to 3 additional cycles25 before the access is granted.
Similarly, for a DMA access to the DCCM, it may take up to 4 additional cycles before the access is granted.
```

### docs/source/error-protection.md

```markdown
Empty fields shall be ignored as they provide structure information for the table

:::{list-table} Error Detection, Recovery, and Logging
:name: tab-error-detection-recovery-logging

* - **Memory Type**
  - **Detection**
  - **Recovery**
  - **Recovery**
  - **Logging**
  - **Logging**
* -
  -
  - **Single-bit Error**
  - **Double-bit Error**
  - **Single-bit Error**
  - **Double-bit Error**
...
* - DCCM
  -
    - Each 32-bit chunk protected with 7 ECC bits
    - ECC checked in pipeline
  -
    - Correct error in-line
    - Write [^fn-error-protection-6] corrected data/ECC back to DCCM
  - Fatal error [^fn-error-protection-7] (uncorrectable)
  -
    - Increment [^fn-error-protection-6] DCCM single- bit error counter
    - If error counter has reached threshold, signal correctable error local interrupt (see [](error-protection.md#dccm-correctable-error-counter-threshold-register-mdccmect))
  -
    - For loads [^fn-error-protection-7]:
      - Load access fault exception
    - For stores [^fn-error-protection-7]:
      - Store/AMO access fault exception
    - For DMA reads:
      - Send error response on DMA slave bus to master
```
