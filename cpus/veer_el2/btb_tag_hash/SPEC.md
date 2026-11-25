# Implement `el2_btb_tag_hash`

Implement the complete `el2_btb_tag_hash` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_btb_tag_hash` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_btb_tag_hash
import el2_pkg::*;
#(
`include "el2_param.vh"
 ) (
                       input logic [pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1] pc,
                       output logic [pt.BTB_BTAG_SIZE-1:0] hash
                       );

```

## Parent instantiation

### `design/ifu/el2_ifu_aln_ctl.sv`

```verilog
         el2_btb_tag_hash #(.pt(pt)) first_brhash (.pc(firstpc [pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1]),
                                                    .hash(firstbrtag_hash [pt.BTB_BTAG_SIZE-1:0]));
         el2_btb_tag_hash #(.pt(pt)) second_brhash(.pc(secondpc[pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1]),
                                                    .hash(secondbrtag_hash[pt.BTB_BTAG_SIZE-1:0]));
```

### `design/ifu/el2_ifu_bp_ctl.sv`

```verilog
         el2_btb_tag_hash #(.pt(pt)) rdtagf(.hash(fetch_rd_tag_f[pt.BTB_BTAG_SIZE-1:0]),
                                             .pc({ifc_fetch_addr_f[pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1]}));
         el2_btb_tag_hash #(.pt(pt)) rdtagp1f(.hash(fetch_rd_tag_p1_f[pt.BTB_BTAG_SIZE-1:0]),
                                               .pc({fetch_addr_p1_f[pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1]}));
```
