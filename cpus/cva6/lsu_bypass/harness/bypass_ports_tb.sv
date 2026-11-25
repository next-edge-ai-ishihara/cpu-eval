// SPDX-License-Identifier: Apache-2.0
module testbench;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
`include "cva6_types.svh"

  logic clk = 0;
  logic rst_n = 0;
  logic flush = 0;
  logic valid = 0;
  logic pop_ld = 0;
  logic pop_st = 0;
  logic ready;
  lsu_ctrl_t request = '0;
  lsu_ctrl_t outgoing;
  lsu_ctrl_t load_request;
  lsu_ctrl_t store_request;

  lsu_bypass #(
    .CVA6Cfg(CVA6Cfg),
    .lsu_ctrl_t(lsu_ctrl_t),
    .bp_resolve_t(bp_resolve_t)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n), .flush_i(flush), .lsu_req_i(request),
    .lsu_req_valid_i(valid), .pop_ld_i(pop_ld), .pop_st_i(pop_st),
    .resolved_branch_i(bp_resolve_t'('0)), .lsu_ctrl_o(outgoing), .ready_o(ready)
  );

  task automatic advance();
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task automatic drive(input lsu_ctrl_t next_request);
    request = next_request;
    valid = next_request.valid;
  endtask

  task automatic check_request(input string phase, input logic expected_ready,
                               input lsu_ctrl_t expected);
    #1;
    if (ready !== expected_ready || outgoing !== expected)
      $fatal(1, "FAIL: %s ready=%b expected_ready=%b request=%h expected_request=%h",
             phase, ready, expected_ready, outgoing, expected);
  endtask

  initial begin
    load_request = '0;
    load_request.valid = 1;
    load_request.vaddr = 32'h8100;
    load_request.be = 4'hf;
    load_request.fu = LOAD;
    load_request.operation = LW;
    load_request.trans_id = 1;
    store_request = '0;
    store_request.valid = 1;
    store_request.vaddr = 32'h8204;
    store_request.data = 32'h13579bdf;
    store_request.be = 4'hf;
    store_request.fu = STORE;
    store_request.operation = SW;
    store_request.trans_id = 2;

    advance();
    rst_n = 1;
    drive(load_request);
    check_request("empty bypass", 1, load_request);
    pop_ld = 1;
    advance();
    pop_ld = 0;
    drive(store_request);
    check_request("same-cycle completion leaves bypass empty", 1, store_request);
    advance();
    drive(load_request);
    check_request("store held while second issued request arrives", 0, store_request);
    advance();
    drive('0);
    check_request("store held with no incoming request", 0, store_request);
    pop_st = 1;
    advance();
    pop_st = 0;
    check_request("load follows store in issue order", 0, load_request);
    pop_ld = 1;
    advance();
    pop_ld = 0;
    drive(store_request);
    check_request("bypass available again after both pops", 1, store_request);
    $display("PASS: LSU bypass and retained requests");
    $finish;
  end
endmodule
