# Implement `rvecc_encode`

Implement the complete `rvecc_encode` module. Preserve the module name and ports shown below. Return only the complete `module rvecc_encode` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvecc_encode  (
                      input [31:0] din,
                      output [6:0] ecc_out
                      );

```

## Parent instantiation

### design/ifu/el2_ifu_ic_mem.sv

```verilog
           rvecc_encode  tag_ecc_encode (
                                  .din    ({{pt.ICACHE_TAG_LO{1'b0}}, ic_rw_addr[31:pt.ICACHE_TAG_LO]}),
                                  .ecc_out({ ic_tag_ecc[6:0]}));
// ...
           rvecc_encode  tag_ecc_encode (
                                  .din    ({{pt.ICACHE_TAG_LO{1'b0}}, ic_rw_addr[31:pt.ICACHE_TAG_LO]}),
                                  .ecc_out({ ic_tag_ecc[6:0]}));

```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
         rvecc_encode  iccm_ecc_encode0 (
                           .din(dma_mem_wdata[31:0]),
                           .ecc_out(dma_mem_ecc[6:0]));

         rvecc_encode  iccm_ecc_encode1 (
                           .din(dma_mem_wdata[63:32]),
                           .ecc_out(dma_mem_ecc[13:7]));

```

### design/lsu/el2_lsu_ecc.sv

```verilog
      rvecc_encode lsu_ecc_encode_hi (
         //Inputs
         .din(dccm_wdata_hi_any[pt.DCCM_DATA_WIDTH-1:0]),
         //Outputs
         .ecc_out(dccm_wdata_ecc_hi_any[pt.DCCM_ECC_WIDTH-1:0]),
         .*
      );
      rvecc_encode lsu_ecc_encode_lo (
         //Inputs
         .din(dccm_wdata_lo_any[pt.DCCM_DATA_WIDTH-1:0]),
         //Outputs
         .ecc_out(dccm_wdata_ecc_lo_any[pt.DCCM_ECC_WIDTH-1:0]),
         .*
      );

```

## Related source code

### testbench/tb_top.sv

```systemverilog
function[6:0] riscv_ecc32(input[31:0] data);
reg[6:0] synd;
synd[0] = ^(data & 32'h56aa_ad5b);
synd[1] = ^(data & 32'h9b33_366d);
synd[2] = ^(data & 32'he3c3_c78e);
synd[3] = ^(data & 32'h03fc_07f0);
synd[4] = ^(data & 32'h03ff_f800);
synd[5] = ^(data & 32'hfc00_0000);
synd[6] = ^{data, synd[5:0]};
return synd;
endfunction

```
