// SPDX-License-Identifier: Apache-2.0
module pmp_write_ports_tb;
  localparam config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  logic [Cfg.PLEN-1:0] address;
  logic [Cfg.NrPMPEntries-1:0][Cfg.PLEN-3:0] boundaries;
  riscv::pmpcfg_t [Cfg.NrPMPEntries-1:0] entries;
  logic allow;

  pmp #(.CVA6Cfg(Cfg)) dut (
    .addr_i(address),
    .access_type_i(riscv::ACCESS_WRITE),
    .priv_lvl_i(riscv::PRIV_LVL_S),
    .conf_addr_i(boundaries),
    .conf_i(entries),
    .allow_o(allow)
  );

  task automatic check_store(input logic [Cfg.PLEN-1:0] physical, input bit expected);
    address = physical;
    #1;
    if (allow !== expected)
      $fatal(1, "FAIL: supervisor write address=%h expected=%b observed=%b",
             address, expected, allow);
  endtask

  initial begin
    boundaries = '0;
    entries = '0;
    boundaries[0] = 'h400;
    boundaries[1] = 'h800;
    entries[0].addr_mode = riscv::TOR;
    entries[0].locked = 1'b1;
    entries[0].access_type = 3'b001;
    entries[1].addr_mode = riscv::TOR;
    entries[1].locked = 1'b1;
    entries[1].access_type = 3'b011;
    check_store('h1008, 1'b1);
    check_store('h008, 1'b0);
    $display("PASS: supervisor writes respect the selected TOR entry");
    $finish;
  end
endmodule
