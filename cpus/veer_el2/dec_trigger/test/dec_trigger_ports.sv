// SPDX-License-Identifier: Apache-2.0

module dec_trigger_ports
  import el2_pkg::*;
#(
  `include "el2_param.vh"
) ();

  el2_trigger_pkt_t [3:0] packets [3];
  logic [31:1] pc [3];
  logic [3:0] match_bits [3];
  int failures = 0;

  for (genvar i = 0; i < 3; i++) begin : sample
    el2_dec_trigger #(.pt(pt)) dut (
      .trigger_pkt_any(packets[i]),
      .dec_i0_pc_d(pc[i]),
      .dec_i0_trigger_match_d(match_bits[i])
    );
  end

  function automatic el2_trigger_pkt_t packet(
    input logic [31:0] address, input bit masked, execute, m
  );
    el2_trigger_pkt_t value = '0;
    value.tdata2 = address;
    value.match = masked;
    value.execute = execute;
    value.m = m;
    return value;
  endfunction

  task automatic check(input string name, input logic [3:0] expected, actual);
    $display("TRIGGER_PORTS %s expected=%b actual=%b", name, expected, actual);
    if (actual !== expected)
      failures++;
  endtask

  initial begin
    pc[0] = 31'h0813; // Byte address 0x1026.
    packets[0][0] = packet(32'h1027, 0, 1, 1);
    packets[0][1] = packet(32'h1026, 0, 1, 0);
    packets[0][2] = packet(32'h1027, 0, 1, 1);
    packets[0][3] = packet(32'h1028, 0, 1, 1);

    pc[1] = 31'h0813;
    packets[1][0] = packet(32'h1023, 1, 1, 1);
    packets[1][1] = packet(32'h1023, 0, 1, 1);
    packets[1][2] = packet(32'h102b, 1, 1, 1);
    packets[1][3] = packet(32'h1023, 1, 1, 1);

    pc[2] = '0;
    packets[2][0] = packet(0, 0, 0, 1);
    packets[2][1] = packet(0, 0, 1, 1);
    packets[2][2] = packet(0, 0, 0, 1);
    packets[2][2].select = 1'b1;
    packets[2][3] = packet(32'h0002, 0, 1, 1);

    #1;
    check("exact_odd_tdata2_and_m_enable", 4'b0101, match_bits[0]);
    check("napot_range_0x1020_through_0x1027", 4'b1001, match_bits[1]);
    check("execute_disabled", 4'b0010, match_bits[2]);

    if (failures == 0)
      $display("TRIGGER_PORTS_PASS");
    else
      $display("TRIGGER_PORTS_FAIL mismatches=%0d", failures);
    $finish;
  end
endmodule
