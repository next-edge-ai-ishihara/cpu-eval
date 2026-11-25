// SPDX-License-Identifier: Apache-2.0
module testbench;
  localparam config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  logic [31:0] instruction, expansion;
  logic illegal, compressed, macro_instruction, zcmt;
  typedef struct packed {
    logic [31:0] word, expansion;
    logic illegal, compressed;
  } comparison_t;
  comparison_t comparisons [2178];
  int comparison_count, legal_count, illegal_count;

  compressed_decoder #(.CVA6Cfg(Cfg)) dut (
    .instr_i(instruction), .instr_o(expansion), .illegal_instr_o(illegal),
    .is_compressed_o(compressed), .is_macro_instr_o(macro_instruction), .is_zcmt_instr_o(zcmt)
  );

  function automatic logic [4:0] xreg(input logic [2:0] index);
    return 5'd8 + {2'b00, index};
  endfunction

  function automatic logic [31:0] i_type(
    input logic [11:0] immediate, input logic [4:0] rs1,
    input logic [2:0] funct3, input logic [4:0] rd, input logic [6:0] opcode
  );
    return {immediate, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] store(
    input logic [11:0] offset, input logic [4:0] rs1, rs2, input logic [2:0] funct3
  );
    return {offset[11:5], rs2, rs1, funct3, offset[4:0], 7'h23};
  endfunction

  task automatic add_comparison(
    input logic [31:0] word, expected, input logic expect_illegal, expect_compressed
  );
    comparisons[comparison_count] = '{word, expected, expect_illegal, expect_compressed};
    comparison_count++;
  endtask

  task automatic valid_zcb(input logic [15:0] halfword, input logic [31:0] expanded);
    add_comparison({16'hcafe, halfword}, expanded, 1'b0, 1'b1);
    legal_count++;
  endtask

  task automatic reserved_zcb(input logic [15:0] halfword);
    add_comparison({16'hbabe, halfword}, {16'hbabe, halfword}, 1'b1, 1'b1);
    illegal_count++;
  endtask

  initial begin
    add_comparison(32'h8765_0013, 32'h8765_0013, 1'b0, 1'b0);
    for (int r = 0; r < 8; r++) begin
      logic [2:0] rd_prime;
      logic [4:0] rsd;
      rd_prime = r[2:0];
      rsd = xreg(rd_prime);
      for (int s = 0; s < 8; s++) begin
        logic [2:0] second_prime;
        logic [4:0] second;
        second_prime = s[2:0];
        second = xreg(second_prime);
        for (int offset = 0; offset < 4; offset++) begin
          valid_zcb({6'b100000, rd_prime, offset[0], offset[1], second_prime, 2'b00},
                    i_type(12'(offset), rsd, 3'b100, second, 7'h03));
          valid_zcb({6'b100010, rd_prime, offset[0], offset[1], second_prime, 2'b00},
                    store(12'(offset), rsd, second, 3'b000));
          for (int funct = 4; funct < 8; funct++)
            reserved_zcb({3'b100, funct[2:0], rd_prime, offset[1:0], second_prime, 2'b00});
        end
        for (int offset = 0; offset < 4; offset += 2) begin
          valid_zcb({6'b100001, rd_prime, 1'b0, offset[1], second_prime, 2'b00},
                    i_type(12'(offset), rsd, 3'b101, second, 7'h03));
          valid_zcb({6'b100001, rd_prime, 1'b1, offset[1], second_prime, 2'b00},
                    i_type(12'(offset), rsd, 3'b001, second, 7'h03));
          valid_zcb({6'b100011, rd_prime, 1'b0, offset[1], second_prime, 2'b00},
                    store(12'(offset), rsd, second, 3'b001));
          reserved_zcb({6'b100011, rd_prime, 1'b1, offset[1], second_prime, 2'b00});
        end
        valid_zcb({6'b100111, rd_prime, 2'b10, second_prime, 2'b01},
                  {7'h01, second, rsd, 3'b000, rsd, 7'h33});
      end
      valid_zcb({6'b100111, rd_prime, 5'b11000, 2'b01}, i_type(12'h0ff, rsd, 3'b111, rsd, 7'h13));
      valid_zcb({6'b100111, rd_prime, 5'b11001, 2'b01}, i_type(12'h604, rsd, 3'b001, rsd, 7'h13));
      valid_zcb({6'b100111, rd_prime, 5'b11010, 2'b01}, {7'h04, 5'b0, rsd, 3'b100, rsd, 7'h33});
      valid_zcb({6'b100111, rd_prime, 5'b11011, 2'b01}, i_type(12'h605, rsd, 3'b001, rsd, 7'h13));
      valid_zcb({6'b100111, rd_prime, 5'b11101, 2'b01}, i_type(12'hfff, rsd, 3'b100, rsd, 7'h13));
      reserved_zcb({6'b100111, rd_prime, 5'b11100, 2'b01}); // C.ZEXT.W is RV64-only.
      reserved_zcb({6'b100111, rd_prime, 5'b11110, 2'b01});
      reserved_zcb({6'b100111, rd_prime, 5'b11111, 2'b01});
    end
    add_comparison(32'h1357_0013, 32'h1357_0013, 1'b0, 1'b0);
    for (int i = 0; i < comparison_count; i++) begin
      comparison_t expected;
      expected = comparisons[i];
      instruction = expected.word;
      #1;
      if ({illegal, compressed, macro_instruction, zcmt, expansion} !==
          {expected.illegal, expected.compressed, 2'b00, expected.expansion}) begin
        $display("FAIL: input=%08x expected=%08x illegal=%b compressed=%b actual=%08x illegal=%b compressed=%b macro=%b zcmt=%b",
                 expected.word, expected.expansion, expected.illegal, expected.compressed,
                 expansion, illegal, compressed, macro_instruction, zcmt);
        $finish;
      end
    end
    $display("PASS: decoded %0d legal and returned %0d reserved Zcb halfwords", legal_count, illegal_count);
    $finish;
  end
endmodule
