# Implement `rvrangecheck`

Implement the complete `rvrangecheck` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvrangecheck` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
// Check if the S_ADDR <= addr < E_ADDR
module rvrangecheck  #(CCM_SADR = 32'h0,
                       CCM_SIZE  = 128) (
   input  logic [31:0]   addr,                             // Address to be checked for range
   output logic          in_range,                            // S_ADDR <= start_addr < E_ADDR
   output logic          in_region
);
```

## Parent instantiation

### design/ifu/el2_ifu_ifc_ctl.sv

```verilog
   rvrangecheck #( .CCM_SADR    (pt.ICCM_SADR),
                   .CCM_SIZE    (pt.ICCM_SIZE) ) iccm_rangecheck (
                                     .addr     ({ifc_fetch_addr_bf[31:1],1'b0}) ,
                                     .in_range (iccm_acc_in_range_bf) ,
                                     .in_region(iccm_acc_in_region_bf)
                                     );
```

### design/lsu/el2_lsu_addrcheck.sv

```verilog
      rvrangecheck #(.CCM_SADR(pt.DCCM_SADR),
                     .CCM_SIZE(pt.DCCM_SIZE)) start_addr_dccm_rangecheck (
         .addr(start_addr_d[31:0]),
         .in_range(start_addr_in_dccm_d),
         .in_region(start_addr_in_dccm_region_d)
      );
```

## Documentation

### docs/source/build-args.md

```markdown
Placement of VeeR EL2's core memories and memory-mapped register blocks in the 32-bit address range is very flexible.
Each memory or register block may be assigned to any region and within the region's 28-bit address range to any start address on a naturally aligned power-of-two address boundary relative to its own size (i.e., *start_address* = *n × size*, whereas n is a positive integer number).

For example, the start address of an 8KB-sized DCCM may be 0x0000_0000, 0x0000_2000, 0x0000_4000, 0x0000_6000, etc.
A memory or register block with a non-power-of-two size must be aligned to the next bigger power-of-two size.
For example, the starting address of a 48KB-sized DCCM must aligned to a 64KB boundary, i.e., it may be 0x0000_0000, 0x0001_0000, 0x0002_0000, 0x0003_0000, etc.

Also, no two memories or register blocks may overlap each other, and no memory or register block may cross a region boundary.

The start address of the memory or register block is specified with an offset relative to the start address of the region.

This offset must follow the rules described above.

### Memory-Related Build Arguments
* **ICCM**
  * Enable (RV_ICCM_ENABLE): 0, 1 *(0 = no ICCM; 1 = ICCM enabled)*
  * Region (RV_ICCM_REGION): 0..15
  * Offset (RV_ICCM_OFFSET): *offset in bytes from start of region satisfying rules in [](build-args.md#core-memories-and-memory-mapped-register-blocks-alignment-rules)*
  * Size (RV_ICCM_SIZE): 4, 8, 16, 32, 64, 128, 256, 512 *(in KB)*
* **DCCM**
  * Region (RV_DCCM_REGION): 0..15
  * Offset (RV_DCCM_OFFSET): *offset in bytes from start of region satisfying rules in [](build-args.md#core-memories-and-memory-mapped-register-blocks-alignment-rules)*
  * Size (RV_DCCM_SIZE): 4, 8, 16, 32, 48, 64, 128, 256, 512 *(in KB)*
```
