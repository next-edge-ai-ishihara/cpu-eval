# Implement `rvecc_decode`

Implement the complete `rvecc_decode` module. Preserve the module name and ports shown below. Return only the complete `module rvecc_decode` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvecc_decode  (
                      input         en,
                      input [31:0]  din,
                      input [6:0]   ecc_in,
                      input         sed_ded,    // only do detection and no correction. Used for the I$
                      output [31:0] dout,
                      output [6:0]  ecc_out,
                      output        single_ecc_error,
                      output        double_ecc_error

                      );

```

## Parent instantiation

### design/ifu/el2_ifu_ic_mem.sv

```verilog
        rvecc_decode  ecc_decode (
                         .en(~dec_tlu_core_ecc_disable & ic_rd_en_ff),
                         .sed_ded ( 1'b1 ),    // 1 : means only detection
                         .din({11'b0,ic_tag_data_raw[i][20:0]}),
                         .ecc_in({2'b0, ic_tag_data_raw[i][25:21]}),
                         .dout(ic_tag_corrected_data_unc[i][31:0]),
                         .ecc_out(ic_tag_corrected_ecc_unc[i][6:0]),
                         .single_ecc_error(ic_tag_single_ecc_error[i]),
                         .double_ecc_error(ic_tag_double_ecc_error[i]));
// ...
          rvecc_decode  ecc_decode (
                           .en(~dec_tlu_core_ecc_disable & ic_rd_en_ff),
                           .sed_ded ( 1'b1 ),    // 1 : means only detection
                           .din({11'b0,ic_tag_data_raw[i][20:0]}),
                           .ecc_in({2'b0, ic_tag_data_raw[i][25:21]}),
                           .dout(ic_tag_corrected_data_unc[i][31:0]),
                           .ecc_out(ic_tag_corrected_ecc_unc[i][6:0]),
                           .single_ecc_error(ic_tag_single_ecc_error[i]),
                           .double_ecc_error(ic_tag_double_ecc_error[i]));

```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
   rvecc_decode  ecc_decode (
                           .en(iccm_ecc_word_enable[i]),
                           .sed_ded ( 1'b0 ),    // 1 : means only detection
                           .din(iccm_rdmux_data[(39*i+31):(39*i)]),
                           .ecc_in(iccm_rdmux_data[(39*i+38):(39*i+32)]),
                           .dout(iccm_corrected_data[i][31:0]),
                           .ecc_out(iccm_corrected_ecc[i][6:0]),
                           .single_ecc_error(iccm_single_ecc_error[i]),
                           .double_ecc_error(iccm_double_ecc_error[i]));

```

### design/lsu/el2_lsu_ecc.sv

```verilog
      rvecc_decode lsu_ecc_decode_hi (
         // Inputs
         .en(is_ldst_hi_any),
         .sed_ded (1'b0),    // 1 : means only detection
         .din(dccm_rdata_hi_any[pt.DCCM_DATA_WIDTH-1:0]),
         .ecc_in(dccm_data_ecc_hi_any[pt.DCCM_ECC_WIDTH-1:0]),
         // Outputs
         .dout(sec_data_hi_any[pt.DCCM_DATA_WIDTH-1:0]),
         .ecc_out (ecc_out_hi_nc[6:0]),
         .single_ecc_error(single_ecc_error_hi_any),
         .double_ecc_error(double_ecc_error_hi_any),
         .*
      );

      //Detect/Repair for Lo
      rvecc_decode lsu_ecc_decode_lo (
         // Inputs
         .en(is_ldst_lo_any),
         .sed_ded (1'b0),    // 1 : means only detection
         .din(dccm_rdata_lo_any[pt.DCCM_DATA_WIDTH-1:0] ),
         .ecc_in(dccm_data_ecc_lo_any[pt.DCCM_ECC_WIDTH-1:0]),
         // Outputs
         .dout(sec_data_lo_any[pt.DCCM_DATA_WIDTH-1:0]),
         .ecc_out (ecc_out_lo_nc[6:0]),
         .single_ecc_error(single_ecc_error_lo_any),
         .double_ecc_error(double_ecc_error_lo_any),
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

## Documentation

### docs/source/error-protection.md

The ECC functions described are made possible by Hamming code, a relatively simple yet powerful ECC code.
It involves storing and transmitting data with multiple check bits (parity) and decoding the associated check bits when retrieving or receiving data to detect and correct errors.

The ECC feature can be implemented with Hamming based SECDED (Single-bit Error Correction and Double-bit Error Detection) algorithm.
The design can use the (39, 32) code - 32 data bits and 7 parity bits depicted in {numref}`fig-ecc-mem-diag` below.
In other words, the Hamming code word width is 39 bits, comprised of 32 data bits and 7 check bits.
The minimum number of check bits needed for correcting a single-bit error in a 32-bit word is six.
The extra check bit expands the function to detect double-bit errors as well.

ECC codes may also be used for error detection only if other means exist to correct the data.
For example, the Icache stores exact copies of cache lines which are also residing in SoC memory.
Instead of correcting corrupted data fetched from the I-cache, erroneous cache lines may also be invalidated in the I-cache and refetched from SoC memory.

## Additional requirement

When `sed_ded` is high, `dout` equals `din`, `ecc_out` equals `ecc_in`, and `single_ecc_error | double_ecc_error` is high exactly when `en` is high and `ecc_in[5:0]` differs from bits 5 to 0 of `riscv_ecc32(din)`.
