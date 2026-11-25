# Implement `rvecc_decode_64`

Implement the complete `rvecc_decode_64` module. Preserve the module name and ports shown below. Return only the complete `module rvecc_decode_64` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvecc_decode_64  (
                      input         en,
                      input [63:0]  din,
                      input [6:0]   ecc_in,
                      output        ecc_error
                      );

```

## Parent instantiation

```verilog
  // Core-side alignment (byte-rotate) and ECC / parity check of the raw 142-bit
  // ic_rd_data input (ic_rd_data_aligned / ic_eccerr_int / ic_parerr_int declared above).
  if (pt.ICACHE_ECC) begin : g_ic_rd_ecc_core
     logic [63:0]  ic_rd_rot;
     logic [141:0] ic_rd_data_fixed;
     assign ic_rd_data_fixed = {ic_rd_data[141:135], ic_rd_data[134:71] ^ ic_rd_addr_infect,
                                ic_rd_data[70:64],   ic_rd_data[63:0]   ^ ic_rd_addr_infect};
     assign ic_rd_rot = (ic_rd_addr_lo == 2'b00) ? ic_rd_data_fixed[63:0]                              :
                        (ic_rd_addr_lo == 2'b01) ? {ic_rd_data_fixed[86:71],  ic_rd_data_fixed[63:16]} :
                        (ic_rd_addr_lo == 2'b10) ? {ic_rd_data_fixed[102:71], ic_rd_data_fixed[63:32]} :
                                                 {ic_rd_data_fixed[118:71], ic_rd_data_fixed[63:48]};
     assign ic_rd_data_aligned = ic_sel_premux_data ? ic_premux_data[63:0] : ic_rd_rot;
     for (genvar i=0; i<pt.ICACHE_BANKS_WAY; i++) begin : g_dec
        rvecc_decode_64 ecc_decode_64 (
           .en       (ic_rd_bank_check_en[i]),
           .din      (ic_rd_data_fixed[71*i +: 64]),
           .ecc_in   (ic_rd_data_fixed[71*i+64 +: 7]),
           .ecc_error(ic_eccerr_int[i]));
     end
     assign ic_parerr_int = '0;

```

## Related source code

### design/lib/beh_lib.sv

```verilog
module rvecc_encode_64  (
                      input [63:0] din,
                      output [6:0] ecc_out
                      );
  assign ecc_out[0] = din[0]^din[1]^din[3]^din[4]^din[6]^din[8]^din[10]^din[11]^din[13]^din[15]^din[17]^din[19]^din[21]^din[23]^din[25]^din[26]^din[28]^din[30]^din[32]^din[34]^din[36]^din[38]^din[40]^din[42]^din[44]^din[46]^din[48]^din[50]^din[52]^din[54]^din[56]^din[57]^din[59]^din[61]^din[63];

   assign ecc_out[1] = din[0]^din[2]^din[3]^din[5]^din[6]^din[9]^din[10]^din[12]^din[13]^din[16]^din[17]^din[20]^din[21]^din[24]^din[25]^din[27]^din[28]^din[31]^din[32]^din[35]^din[36]^din[39]^din[40]^din[43]^din[44]^din[47]^din[48]^din[51]^din[52]^din[55]^din[56]^din[58]^din[59]^din[62]^din[63];

   assign ecc_out[2] = din[1]^din[2]^din[3]^din[7]^din[8]^din[9]^din[10]^din[14]^din[15]^din[16]^din[17]^din[22]^din[23]^din[24]^din[25]^din[29]^din[30]^din[31]^din[32]^din[37]^din[38]^din[39]^din[40]^din[45]^din[46]^din[47]^din[48]^din[53]^din[54]^din[55]^din[56]^din[60]^din[61]^din[62]^din[63];

   assign ecc_out[3] = din[4]^din[5]^din[6]^din[7]^din[8]^din[9]^din[10]^din[18]^din[19]^din[20]^din[21]^din[22]^din[23]^din[24]^din[25]^din[33]^din[34]^din[35]^din[36]^din[37]^din[38]^din[39]^din[40]^din[49]^din[50]^din[51]^din[52]^din[53]^din[54]^din[55]^din[56];

   assign ecc_out[4] = din[11]^din[12]^din[13]^din[14]^din[15]^din[16]^din[17]^din[18]^din[19]^din[20]^din[21]^din[22]^din[23]^din[24]^din[25]^din[41]^din[42]^din[43]^din[44]^din[45]^din[46]^din[47]^din[48]^din[49]^din[50]^din[51]^din[52]^din[53]^din[54]^din[55]^din[56];

   assign ecc_out[5] = din[26]^din[27]^din[28]^din[29]^din[30]^din[31]^din[32]^din[33]^din[34]^din[35]^din[36]^din[37]^din[38]^din[39]^din[40]^din[41]^din[42]^din[43]^din[44]^din[45]^din[46]^din[47]^din[48]^din[49]^din[50]^din[51]^din[52]^din[53]^din[54]^din[55]^din[56];

   assign ecc_out[6] = din[57]^din[58]^din[59]^din[60]^din[61]^din[62]^din[63];

endmodule // rvecc_encode_64

```

### testbench/tests/icache_ecc/icache_ecc.c

```text
 * ICache Core-Side ECC & Parity Fault Recovery Test
 *
 * Architecture & Test Intent:
 * Commit 7dd5354d ("Move iCache ECC and parity check into DCLS") moved the
 * ICache read data decoding logic (both 7-bit Hamming SECDED ECC and 4-bit byte parity)
 * inside the DCLS core domain (el2_ifu_mem_ctl.sv).
 *
 * This test verifies:
 * 1. Single-bit memory read data fault injection (mailbox command 0x89) triggers
 *    the core-side ECC/Parity error decoders (rvecc_decode_64 / rveven_paritycheck).
 * 2. The Trap Logic Unit (TLU) increments the ICache Error Counter CSR (micect 0x7F0)
 *    by exactly 1.
 * 3. The core hardware cleanly flushes the pipeline and re-fetches the instruction,
 *    allowing program execution to continue seamlessly (verified by function execution
 *    counter == 3).
 * 4. Works in both `icache_ecc=1` (ECC) and `icache_ecc=0` (Parity) simulation builds.

```
