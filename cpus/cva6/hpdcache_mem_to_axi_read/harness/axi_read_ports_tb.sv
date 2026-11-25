// SPDX-License-Identifier: Apache-2.0
`include "hpdcache_typedef.svh"
`include "typedef.svh"

module tb;
  import hpdcache_pkg::*;

  typedef logic [63:0] addr_t;
  typedef logic [63:0] data_t;
  typedef logic [3:0] id_t;
  typedef logic [31:0] user_t;
  typedef `HPDCACHE_DECL_MEM_REQ_T(addr_t, id_t) req_t;
  typedef `HPDCACHE_DECL_MEM_RESP_R_T(id_t, data_t) resp_t;
  `AXI_TYPEDEF_AR_CHAN_T(ar_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_t, data_t, id_t, user_t)

  logic req_ready_o, req_valid_i, resp_ready_i, resp_valid_o;
  logic axi_ar_valid_o, axi_ar_ready_i, axi_r_valid_i, axi_r_ready_o;
  req_t req_i;
  resp_t resp_o;
  ar_t axi_ar_o;
  r_t axi_r_i;

  hpdcache_mem_to_axi_read #(
    .hpdcache_mem_req_t(req_t), .hpdcache_mem_resp_r_t(resp_t),
    .ar_chan_t(ar_t), .r_chan_t(r_t)
  ) dut (.*);

  task automatic check_ar(input string label, input logic expected_lock, input axi_pkg::cache_t expected_cache);
    #1;
    if (req_ready_o !== axi_ar_ready_i || axi_ar_valid_o !== 1'b1)
      $fatal(1, "BRIDGE_MISMATCH %s request handshake", label);
    if (axi_ar_o.lock !== expected_lock)
      $fatal(1, "BRIDGE_MISMATCH %s ARLOCK expected=%0b observed=%0b", label, expected_lock, axi_ar_o.lock);
    if (axi_ar_o.id !== req_i.mem_req_id || axi_ar_o.addr !== req_i.mem_req_addr ||
        axi_ar_o.len !== req_i.mem_req_len || axi_ar_o.size !== req_i.mem_req_size ||
        axi_ar_o.burst !== axi_pkg::BURST_INCR || axi_ar_o.cache !== expected_cache ||
        {axi_ar_o.prot, axi_ar_o.qos, axi_ar_o.region, axi_ar_o.user} !== '0)
      $fatal(1, "BRIDGE_MISMATCH %s AXI request fields", label);
    $display("AR %s ready=%0b lock=%0b cache=%04b", label, req_ready_o, axi_ar_o.lock, axi_ar_o.cache);
  endtask

  task automatic check_r(input string label, input hpdcache_mem_error_e expected_error);
    #1;
    if (axi_r_ready_o !== resp_ready_i || resp_valid_o !== 1'b1)
      $fatal(1, "BRIDGE_MISMATCH %s response handshake", label);
    if (resp_o.mem_resp_r_error !== expected_error)
      $fatal(1, "BRIDGE_MISMATCH %s error expected=%0d observed=%0d",
             label, expected_error, resp_o.mem_resp_r_error);
    if (resp_o.mem_resp_r_id !== axi_r_i.id || resp_o.mem_resp_r_data !== axi_r_i.data ||
        resp_o.mem_resp_r_last !== axi_r_i.last)
      $fatal(1, "BRIDGE_MISMATCH %s CMI response fields", label);
    $display("R %s ready=%0b error=%0d last=%0b",
             label, axi_r_ready_o, resp_o.mem_resp_r_error, resp_o.mem_resp_r_last);
  endtask

  initial begin
    req_valid_i = 1;
    axi_ar_ready_i = 0;
    resp_ready_i = 0;
    axi_r_valid_i = 0;
    req_i = '{mem_req_addr:64'h80000120, mem_req_len:1, mem_req_size:3, mem_req_id:1,
              mem_req_command:HPDCACHE_MEM_READ, mem_req_atomic:HPDCACHE_MEM_ATOMIC_ADD,
              mem_req_cacheable:1};
    axi_r_i = '0;
    check_ar("cacheable-held", 0, axi_pkg::CACHE_BUFFERABLE | axi_pkg::CACHE_MODIFIABLE |
                                 axi_pkg::CACHE_RD_ALLOC | axi_pkg::CACHE_WR_ALLOC);
    axi_ar_ready_i = 1;
    check_ar("cacheable-ready", 0, axi_pkg::CACHE_BUFFERABLE | axi_pkg::CACHE_MODIFIABLE |
                                  axi_pkg::CACHE_RD_ALLOC | axi_pkg::CACHE_WR_ALLOC);
    req_valid_i = 0;

    axi_r_valid_i = 1;
    axi_r_i = '{id:1, data:64'h1020304050607080, resp:axi_pkg::RESP_OKAY, last:0, user:0};
    check_r("okay-held", HPDCACHE_MEM_RESP_OK);
    resp_ready_i = 1;
    check_r("okay-ready", HPDCACHE_MEM_RESP_OK);
    axi_r_i.data = 64'h0123456789abcdef;
    axi_r_i.last = 1;
    axi_r_i.resp = axi_pkg::RESP_SLVERR;
    check_r("slave-error", HPDCACHE_MEM_RESP_NOK);
    axi_r_valid_i = 0;

    req_valid_i = 1;
    req_i.mem_req_addr = 64'h80000238;
    req_i.mem_req_id = 15;
    req_i.mem_req_len = 0;
    req_i.mem_req_size = 2;
    req_i.mem_req_cacheable = 0;
    check_ar("uncached-read", 0, axi_pkg::CACHE_MODIFIABLE);
    req_valid_i = 0;
    axi_r_valid_i = 1;
    axi_r_i.id = 15;
    axi_r_i.resp = axi_pkg::RESP_DECERR;
    check_r("decode-error", HPDCACHE_MEM_RESP_NOK);
    axi_r_valid_i = 0;

    req_valid_i = 1;
    req_i.mem_req_command = HPDCACHE_MEM_ATOMIC;
    req_i.mem_req_atomic = HPDCACHE_MEM_ATOMIC_LDEX;
    check_ar("exclusive-read", 1, axi_pkg::CACHE_MODIFIABLE);
    req_valid_i = 0;
    axi_r_valid_i = 1;
    axi_r_i.resp = axi_pkg::RESP_EXOKAY;
    check_r("exclusive-okay", HPDCACHE_MEM_RESP_OK);
    $display("AXI_READ_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
