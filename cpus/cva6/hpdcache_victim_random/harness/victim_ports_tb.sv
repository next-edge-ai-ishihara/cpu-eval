// SPDX-License-Identifier: Apache-2.0
module testbench;
  import hpdcache_pkg::*;
  // The HPDcache configuration that cv32a60x instantiates.
  function automatic hpdcache_cfg_t selected_cfg();
    hpdcache_user_cfg_t u;
    u.nRequesters = 5; u.paWidth = 34; u.wordWidth = 32; u.sets = 64; u.ways = 2; u.clWords = 4;
    u.reqWords = 1; u.reqTransIdWidth = 1; u.reqSrcIdWidth = 3;
    u.victimSel = HPDCACHE_VICTIM_RANDOM; u.dataWaysPerRamWord = 2; u.dataSetsPerRam = 64;
    u.dataRamByteEnable = 1; u.accessWords = 2; u.mshrSets = 1; u.mshrWays = 2;
    u.mshrWaysPerRamWord = 2; u.mshrSetsPerRam = 1; u.mshrRamByteEnable = 1;
    u.mshrUseRegbank = 1; u.cbufEntries = 8; u.refillCoreRspFeedthrough = 1;
    u.refillFifoDepth = 4; u.wbufDirEntries = 8; u.wbufDataEntries = 8; u.wbufWords = 1;
    u.wbufTimecntWidth = 3; u.rtabEntries = 4; u.flushEntries = 8; u.flushFifoDepth = 8;
    u.memAddrWidth = 64; u.memIdWidth = 4; u.memDataWidth = 64; u.wtEn = 1; u.wbEn = 0;
    u.lowLatency = 1; u.eccEn = 0; u.eccScrubberEn = 0;
    return hpdcacheBuildConfig(u);
  endfunction
  localparam hpdcache_cfg_t C = selected_cfg();
  logic clk=0, rst_n=0;
  logic [1:0] valid_bits=0, fetch_bits=0, way;
  integer checked=0;
  logic [1:0] seen=0;
`ifdef TEST_SEL
  hpdcache_victim_sel #(.HPDcacheCfg(C), .hpdcache_set_t(logic [5:0]),
      .hpdcache_way_vector_t(logic [1:0])) dut (
`else
  hpdcache_victim_random #(.HPDcacheCfg(C)) dut (
`endif
      .clk_i(clk), .rst_ni(rst_n), .updt_i(1'b0),
      .updt_set_i(6'b0), .updt_way_i(2'b0),
      .sel_victim_i(1'b1), .sel_dir_valid_i(valid_bits),
      .sel_dir_wback_i(2'b0), .sel_dir_dirty_i(2'b0),
      .sel_dir_fetch_i(fetch_bits), .sel_victim_set_i(6'b0),
      .sel_victim_way_o(way));
  task automatic eligibility();
    logic [1:0] available, free_ways;
    available=~fetch_bits; free_ways=available & ~valid_bits;
    if ((way & fetch_bits) != 0 || !$onehot0(way) ||
        (available==0 ? way!=0 : way==0)) begin
      $display("FAIL: valid=%b fetch=%b victim=%b available=%b free=%b",valid_bits,fetch_bits,way,available,free_ways);
      $finish;
    end
    checked++;
  endtask
  initial begin
    #1; clk=1; #1; clk=0; rst_n=1;
    for (int phase=0; phase<256; phase++) begin
      for (int v=0; v<4; v++) for (int f=0; f<4; f++) begin
        valid_bits=2'(v); fetch_bits=2'(f); #1; eligibility();
      end
      valid_bits=2'b11; fetch_bits=0; #1; eligibility(); seen|=way;
      clk=1; #1; clk=0; #1;
    end
    if (seen!=2'b11) begin
      $display("FAIL: random policy never selected both available valid ways; seen=%b",seen);
      $finish;
    end
    $display("PASS: victim eligibility and random variation; cases=%0d",checked);
    $finish;
  end
endmodule
