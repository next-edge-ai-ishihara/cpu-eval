module register_file_ff_tb;
  timeunit 1ns;
  timeprecision 1ps;
  import ibex_pkg::*;
  localparam int CapWidth = ibex_cheriot_pkg::REGCAP_W;

  logic clk, rst_n, write_enable;
  logic [4:0] read_a, read_b;
  logic [CapWidth-1:0] cap_a, cap_b;

  ibex_register_file_ff #(
    .BaseIsa(BaseIsaRV32I),
    .RV32E(1'b0),
    .DataWidth(32),
    .DummyInstructions(1'b0),
    .WordZeroVal(32'(prim_secded_pkg::SecdedInv3932ZeroWord))
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .test_en_i(1'b0),
    .dummy_instr_id_i(1'b0),
    .dummy_instr_wb_i(1'b0),
    .cheriot_enable_i(IbexMuBiOff),
    .raddr_a_i(read_a),
    .rdata_a_o(),
    .rcap_a_o(cap_a),
    .raddr_b_i(read_b),
    .rdata_b_o(),
    .rcap_b_o(cap_b),
    .waddr_a_i(5'd19),
    .wdata_a_i(32'h12345678),
    .wcap_a_i({CapWidth{1'b1}}),
    .we_a_i(write_enable)
  );

  task automatic check_capabilities();
    if (cap_a !== '0 || cap_b !== '0) begin
      $display("REGFILE_CAP_MISMATCH a[%0d]=%h b[%0d]=%h expected=0 write=%b",
               read_a, cap_a, read_b, cap_b, write_enable);
      $finish;
    end
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    write_enable = 0;
    read_a = 0;
    read_b = 0;
    #1 clk = 1;
    #1 clk = 0;
    rst_n = 1;
    write_enable = 1;
    read_a = 19;
    read_b = 19;
    #1 check_capabilities();
    clk = 1;
    #1 check_capabilities();
    clk = 0;
    write_enable = 0;
    for (int address = 0; address < 32; address++) begin
      read_a = 5'(address);
      read_b = 5'(31 - address);
      #1 check_capabilities();
    end
    #1 $display("REGFILE_CAP_PASS");
    $finish;
  end
endmodule
