// SPDX-License-Identifier: Apache-2.0
module iccm_correction_probe
import el2_pkg::*;
#(
  `include "el2_param.vh"
) ();
  bit clk;
  bit rst_l;
  bit iccm_wren, iccm_rden, iccm_buf_correct_ecc;
  bit [pt.ICCM_BITS-1:1] iccm_rw_addr;
  bit [2:0] iccm_wr_size;
  bit [77:0] iccm_wr_data;
  logic [77:0] iccm_rd_data_ecc;
  el2_mem_if #(.pt(pt)) memory_bus();
  assign memory_bus.clk = clk;

  el2_ifu_iccm_mem #(.pt(pt)) dut (
    .clk(clk), .active_clk(clk), .rst_l(rst_l), .clk_override(1'b0),
    .iccm_wren(iccm_wren), .iccm_rden(iccm_rden), .iccm_rw_addr(iccm_rw_addr),
    .iccm_buf_correct_ecc(iccm_buf_correct_ecc), .iccm_correction_state(1'b0),
    .iccm_wr_size(iccm_wr_size), .iccm_wr_data(iccm_wr_data),
    .iccm_mem_export(memory_bus.veer_iccm), .iccm_rd_data_ecc(iccm_rd_data_ecc),
    .scan_mode(1'b0)
  );

  // A single persistent flipped data bit in word 0x14, at the external SRAM boundary.
  for (genvar bank = 0; bank < pt.ICCM_NUM_BANKS; bank++) begin : banks
    wire [38:0] write_word = {memory_bus.iccm_bank_wr_ecc[bank], memory_bus.iccm_bank_wr_data[bank]};
    wire stuck_address = bank == 1 && memory_bus.iccm_addr_bank[bank] == 12'd1;
    wire [38:0] stored_word = write_word ^ {38'b0, stuck_address};
    ram_4096x39 ram (
      .CLK(clk), .ME(memory_bus.iccm_clken[bank]), .WE(memory_bus.iccm_wren_bank[bank]),
      .ADR(memory_bus.iccm_addr_bank[bank]), .D(stored_word),
      .Q({memory_bus.iccm_bank_ecc[bank], memory_bus.iccm_bank_dout[bank]}),
      .ROP(), .TEST1(1'b0), .RME(1'b0), .RM(4'b0), .LS(1'b0), .DS(1'b0), .SD(1'b0),
      .TEST_RNM(1'b0), .BC1(1'b0), .BC2(1'b0)
    );
  end

  task automatic cycle();
    #5 clk = 1;
    #5 clk = 0;
  endtask

  task automatic write_request(input int address, input bit [2:0] size,
                               input bit [77:0] data, input bit correction);
    iccm_rw_addr = address[pt.ICCM_BITS-1:1];
    iccm_wren = 1;
    iccm_rden = 0;
    iccm_buf_correct_ecc = correction;
    iccm_wr_size = size;
    iccm_wr_data = data;
    cycle();
  endtask

  int passed, failed;
  task automatic check_pair(input string label_text, input int address, input bit [2:0] size,
                            input bit [77:0] expected);
    iccm_rw_addr = address[pt.ICCM_BITS-1:1];
    iccm_wren = 0;
    iccm_rden = 1;
    iccm_buf_correct_ecc = 0;
    iccm_wr_size = size;
    cycle();
    if (iccm_rd_data_ecc === expected) begin
      $display("ICCM_OK %s %020h", label_text, iccm_rd_data_ecc);
      passed++;
    end else begin
      $display("ICCM_MISMATCH %s expected=%020h actual=%020h", label_text, expected, iccm_rd_data_ecc);
      failed++;
    end
  endtask

  localparam bit [31:0] neighbor_data = 32'hcb6553fa;
  localparam bit [31:0] initial_data = 32'h728a1c44;
  localparam bit [31:0] updated_data = 32'hf450807c;
  wire [6:0] neighbor_ecc, initial_ecc, updated_ecc;
  rvecc_encode encode_neighbor (.din(neighbor_data), .ecc_out(neighbor_ecc));
  rvecc_encode encode_initial (.din(initial_data), .ecc_out(initial_ecc));
  rvecc_encode encode_update (.din(updated_data), .ecc_out(updated_ecc));
  wire [38:0] neighbor = {neighbor_ecc, neighbor_data};
  wire [38:0] initial_word = {initial_ecc, initial_data};
  wire [38:0] updated_word = {updated_ecc, updated_data};

  initial begin
    if (pt.ICCM_BITS != 16 || pt.ICCM_NUM_BANKS != 4 || pt.ICCM_BANK_INDEX_LO != 4
        || pt.ICCM_ECC_WIDTH != 7) $fatal(1, "Expected default ICCM SRAM geometry");
    cycle();
    rst_l = 1;
    write_request('h10, 3, {initial_word, neighbor}, 0);
    check_pair("external_bit_flip", 'h12, 0, {initial_word ^ 39'b1, neighbor});
    write_request('h14, 0, {initial_word, initial_word}, 1);
    check_pair("corrected_read", 'h10, 3, {initial_word, neighbor});
    write_request('h14, 2, {updated_word, 39'b0}, 0);
    check_pair("coherent_word_write", 'h10, 3, {updated_word, neighbor});
    $display("ICCM_DONE passed=%0d failed=%0d", passed, failed);
    $finish;
  end
endmodule
