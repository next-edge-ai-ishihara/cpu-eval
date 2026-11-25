// SPDX-License-Identifier: Apache-2.0
`include "hpdcache_typedef.svh"
`include "axi/typedef.svh"

module tb;
  import hpdcache_pkg::*;

  typedef logic [63:0] addr_t;
  typedef logic [63:0] data_t;
  typedef logic [63:0] user_t;
  typedef logic [3:0] id_t;
  typedef logic [7:0] strb_t;
  `HPDCACHE_TYPEDEF_MEM_REQ_T(mem_req_t, addr_t, id_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(mem_data_t, data_t, strb_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(mem_resp_t, id_t);
  `AXI_TYPEDEF_AW_CHAN_T(aw_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_t, id_t, user_t)

  mem_req_t request;
  mem_data_t write_data;
  mem_resp_t response;
  aw_t aw;
  w_t w;
  b_t b;
  logic request_ready, request_valid, data_ready, data_valid, response_ready, response_valid;
  logic aw_valid, aw_ready, w_valid, w_ready, b_valid, b_ready;
  int checks, errors;

  hpdcache_mem_to_axi_write #(
    .hpdcache_mem_req_t(mem_req_t), .hpdcache_mem_req_w_t(mem_data_t),
    .hpdcache_mem_resp_w_t(mem_resp_t), .aw_chan_t(aw_t), .w_chan_t(w_t), .b_chan_t(b_t)
  ) dut (
    .req_ready_o(request_ready), .req_valid_i(request_valid), .req_i(request),
    .req_data_ready_o(data_ready), .req_data_valid_i(data_valid), .req_data_i(write_data),
    .resp_ready_i(response_ready), .resp_valid_o(response_valid), .resp_o(response),
    .axi_aw_valid_o(aw_valid), .axi_aw_o(aw), .axi_aw_ready_i(aw_ready),
    .axi_w_valid_o(w_valid), .axi_w_o(w), .axi_w_ready_i(w_ready),
    .axi_b_valid_i(b_valid), .axi_b_i(b), .axi_b_ready_o(b_ready)
  );

  task automatic check(input logic correct, input string name);
    checks++;
    if (correct !== 1'b1) begin
      errors++;
      $display("MISMATCH %s", name);
    end
  endtask

  task automatic address_attributes(input hpdcache_mem_atomic_e operation,
                                     input axi_pkg::atop_t atop, input logic lock);
    request.mem_req_atomic = operation;
    #1;
    check(aw.atop === atop, $sformatf("AW.ATOP operation=%0d expected=%0h actual=%0h",
                                     operation, atop, aw.atop));
    check(aw.lock === lock, $sformatf("AW.LOCK operation=%0d expected=%0b actual=%0b",
                                     operation, lock, aw.lock));
  endtask

  task automatic write_response(input axi_pkg::resp_t code, input id_t id,
                                input hpdcache_mem_error_e expected_error,
                                input logic exclusive_success);
    b = '{id: id, resp: code, user: '1};
    #1;
    check(response.mem_resp_w_id === id, $sformatf("B.ID expected=%0h actual=%0h",
                                                   id, response.mem_resp_w_id));
    check(response.mem_resp_w_error === expected_error, $sformatf("B.RESP error resp=%0d", code));
    check(response.mem_resp_w_is_atomic === exclusive_success,
          $sformatf("B.RESP exclusive resp=%0d expected=%0b actual=%0b",
                    code, exclusive_success, response.mem_resp_w_is_atomic));
  endtask

  initial begin
    request = '0;
    write_data = '0;
    b = '0;
    for (int pattern = 0; pattern < 64; pattern++) begin
      {request_valid, data_valid, b_valid, aw_ready, w_ready, response_ready} = 6'(pattern);
      #1;
      check({aw_valid, request_ready} === {request_valid, aw_ready},
            $sformatf("AW handshake pattern=%06b", 6'(pattern)));
      check({w_valid, data_ready} === {data_valid, w_ready},
            $sformatf("W handshake pattern=%06b", 6'(pattern)));
      check({response_valid, b_ready} === {b_valid, response_ready},
            $sformatf("B handshake pattern=%06b", 6'(pattern)));
    end

    request = '{mem_req_addr: 64'h1_2345_6780, mem_req_len: 8'd1, mem_req_size: 3'd3,
                mem_req_id: 4'h2, mem_req_command: HPDCACHE_MEM_WRITE,
                mem_req_atomic: HPDCACHE_MEM_ATOMIC_ADD, mem_req_cacheable: 1'b1};
    aw_ready = 0;
    b_valid = 0;
    #1;
    check({aw.addr, aw.id, aw.len, aw.size} === {64'h1_2345_6780, 4'h2, 8'd1, 3'd3}, "AW payload");
    check(aw.burst === axi_pkg::BURST_INCR, "AW.BURST incrementing");
    check({aw.prot, aw.qos, aw.region, aw.user} === '0, "AW fixed attributes");
    check(aw.cache === 4'b1111, "AW.CACHE cacheable write");
    check({aw.lock, aw.atop} === '0, "ordinary write ignores atomic operation");

    w_ready = 1;
    write_data = '{mem_req_w_data: 64'h5741_6552_7633_7844, mem_req_w_be: 8'h39, mem_req_w_last: 0};
    #1;
    check({w.data, w.strb, w.last, w.user} === {64'h5741_6552_7633_7844, 8'h39, 1'b0, 64'b0},
          "W first beat while AW blocked");
    write_data = '{mem_req_w_data: 64'h0fad_1e23_9734_ac56, mem_req_w_be: 8'hd2, mem_req_w_last: 1};
    #1;
    check({w.data, w.strb, w.last, w.user} === {64'h0fad_1e23_9734_ac56, 8'hd2, 1'b1, 64'b0},
          "W final beat while AW blocked");
    aw_ready = 1;
    data_valid = 0;
    #1;

    request.mem_req_id = 4'hf;
    request.mem_req_len = 0;
    request.mem_req_cacheable = 0;
    request.mem_req_command = HPDCACHE_MEM_ATOMIC;
    data_valid = 1;
    address_attributes(HPDCACHE_MEM_ATOMIC_STEX, 6'h00, 1);
    check(aw.cache === 4'b0010, "AW.CACHE noncacheable exclusive store");

    request_valid = 0;
    data_valid = 0;
    request.mem_req_id = 4'h2;
    request.mem_req_command = HPDCACHE_MEM_WRITE;
    b_valid = 1;
    response_ready = 0;
    write_response(axi_pkg::RESP_OKAY,   4'h9, HPDCACHE_MEM_RESP_OK,  0);
    response_ready = 1;
    #1;
    write_response(axi_pkg::RESP_EXOKAY, 4'hf, HPDCACHE_MEM_RESP_OK,  1);
    write_response(axi_pkg::RESP_SLVERR, 4'hc, HPDCACHE_MEM_RESP_NOK, 0);
    write_response(axi_pkg::RESP_DECERR, 4'h5, HPDCACHE_MEM_RESP_NOK, 0);

    b_valid = 0;
    request_valid = 1;
    request.mem_req_len = 0;
    request.mem_req_cacheable = 0;
    request.mem_req_command = HPDCACHE_MEM_ATOMIC;
    address_attributes(HPDCACHE_MEM_ATOMIC_SWAP, 6'h30, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_ADD,  6'h20, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_CLR,  6'h21, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_EOR,  6'h22, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_SET,  6'h23, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_SMAX, 6'h24, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_SMIN, 6'h25, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_UMAX, 6'h26, 0);
    address_attributes(HPDCACHE_MEM_ATOMIC_UMIN, 6'h27, 0);
    check(aw.cache === 4'b0010, "AW.CACHE noncacheable atomic operation");

    $display("SUMMARY checks=%0d errors=%0d", checks, errors);
    $display("AXI_WRITE_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
