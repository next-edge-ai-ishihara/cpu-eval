# Implement `el2_btb_addr_hash`

Implement the complete `el2_btb_addr_hash` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_btb_addr_hash` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog

module el2_btb_addr_hash
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
                        input logic [pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO] pc,
                        output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] hash
                        );

```

## Parent instantiation

### `design/ifu/el2_ifu_aln_ctl.sv`

```verilog
   el2_btb_addr_hash #(.pt(pt)) firsthash (.pc(firstpc [pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO]),
                                            .hash(firstpc_hash [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]));
   el2_btb_addr_hash #(.pt(pt)) secondhash(.pc(secondpc[pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO]),
                                            .hash(secondpc_hash[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]));
```

### `design/ifu/el2_ifu_bp_ctl.sv`

```verilog
   el2_btb_addr_hash #(.pt(pt)) f1hash(.pc(ifc_fetch_addr_f[pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO]), .hash(btb_rd_addr_f[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]));
   // ...
   el2_btb_addr_hash #(.pt(pt)) f1hash_p1(.pc(fetch_addr_p1_f[pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO]), .hash(btb_rd_addr_p1_f[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]));
```
