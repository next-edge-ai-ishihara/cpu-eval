// SPDX-License-Identifier: Apache-2.0
module testbench;
  localparam int Width = 256;
  localparam logic [Width-1:0] Word =
      256'h9585b4d7cab61e030cfa8340bec7b37a_5e241f789c4ad1f3d506b28c7b3c6d7e;
  logic clk = 0;
  logic req, we;
  logic [5:0] addr;
  logic [Width-1:0] wdata, rdata;

  tc_sram_wrapper_cache_techno #(
    .NumWords(64), .DataWidth(Width), .ByteWidth(8), .NumPorts(1),
    .Latency(1), .SimInit("none"), .BYTE_ACCESS(0)
  ) dut (
    .clk_i(clk), .rst_ni(1'b1), .req_i(req), .we_i(we), .addr_i(addr),
    .wdata_i(wdata), .be_i('1), .rdata_o(rdata)
  );

  task automatic tick;
    #5; clk = 1;
    #1; clk = 0;
  endtask

  initial begin
    req = 1;
    we = 1;
    addr = 6'd9;
    wdata = Word;
    tick();
    addr = 6'd42;
    wdata = ~Word;
    tick();

    we = 0;
    addr = 6'd9;
    tick();
    $display("READ addr=%0d actual=%h expected=%h", addr, rdata, Word);
    if (rdata !== Word) begin
      $display("FAIL: selected SRAM word");
      $finish;
    end
    addr = 6'd42;
    tick();
    $display("READ addr=%0d actual=%h expected=%h", addr, rdata, ~Word);
    if (rdata !== ~Word) begin
      $display("FAIL: selected SRAM word");
      $finish;
    end
    $display("PASS: selected SRAM words");
    $finish;
  end
endmodule
