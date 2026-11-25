# Implement `el2_btb_ghr_hash`

Implement the complete `el2_btb_ghr_hash` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_btb_ghr_hash` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog

module el2_btb_ghr_hash
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
                       input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] hashin,
                       input logic [pt.BHT_GHR_SIZE-1:0] ghr,
                       output logic [pt.BHT_ADDR_HI:pt.BHT_ADDR_LO] hash
                       );

```

## Parent instantiation

```verilog
   el2_btb_ghr_hash #(.pt(pt)) mpghrhs  (.hashin(exu_mp_addr[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]), .ghr(exu_mp_eghr[pt.BHT_GHR_SIZE-1:0]), .hash(mp_hashed[pt.BHT_ADDR_HI:pt.BHT_ADDR_LO]));
   el2_btb_ghr_hash #(.pt(pt)) br0ghrhs (.hashin(dec_tlu_br0_addr_wb[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]), .ghr(exu_i0_br_fghr_wb[pt.BHT_GHR_SIZE-1:0]), .hash(br0_hashed_wb[pt.BHT_ADDR_HI:pt.BHT_ADDR_LO]));
   el2_btb_ghr_hash #(.pt(pt)) fghrhs (.hashin(btb_rd_addr_f[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]), .ghr(fghr[pt.BHT_GHR_SIZE-1:0]), .hash(bht_rd_addr_hashed_f[pt.BHT_ADDR_HI:pt.BHT_ADDR_LO]));
   el2_btb_ghr_hash #(.pt(pt)) fghrhs_p1 (.hashin(btb_rd_addr_p1_f[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]), .ghr(fghr[pt.BHT_GHR_SIZE-1:0]), .hash(bht_rd_addr_hashed_p1_f[pt.BHT_ADDR_HI:pt.BHT_ADDR_LO]));
```
