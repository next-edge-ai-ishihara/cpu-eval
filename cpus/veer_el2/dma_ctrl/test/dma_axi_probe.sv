`timescale 1ns/1ps
module dma_axi_probe;
  import el2_pkg::*;
  `include "el2_param.vh"
;
  logic  clk;
  logic  free_clk;
  logic  rst_l;
  logic  dma_bus_clk_en;
  logic  clk_override;
  logic  scan_mode;
  logic [31:0] dbg_cmd_addr;
  logic [31:0] dbg_cmd_wrdata;
  logic  dbg_cmd_valid;
  logic  dbg_cmd_write;
  logic [1:0] dbg_cmd_type;
  logic [1:0] dbg_cmd_size;
  logic  dbg_dma_bubble;
  logic  dma_dbg_ready;
  logic  dma_dbg_cmd_done;
  logic  dma_dbg_cmd_fail;
  logic [31:0] dma_dbg_rddata;
  logic  dma_dccm_req;
  logic  dma_iccm_req;
  logic [2:0] dma_mem_tag;
  logic [31:0] dma_mem_addr;
  logic [2:0] dma_mem_sz;
  logic  dma_mem_write;
  logic [63:0] dma_mem_wdata;
  logic  dccm_dma_rvalid;
  logic  dccm_dma_ecc_error;
  logic [2:0] dccm_dma_rtag;
  logic [63:0] dccm_dma_rdata;
  logic  iccm_dma_rvalid;
  logic  iccm_dma_ecc_error;
  logic [2:0] iccm_dma_rtag;
  logic [63:0] iccm_dma_rdata;
  logic  dma_active;
  logic  dma_dccm_stall_any;
  logic  dma_iccm_stall_any;
  logic  dccm_ready;
  logic  iccm_ready;
  logic [2:0] dec_tlu_dma_qos_prty;
  logic  dma_pmu_dccm_read;
  logic  dma_pmu_dccm_write;
  logic  dma_pmu_any_read;
  logic  dma_pmu_any_write;
  logic  dma_axi_awvalid;
  logic  dma_axi_awready;
  logic [pt.DMA_BUS_TAG-1:0] dma_axi_awid;
  logic [31:0] dma_axi_awaddr;
  logic [2:0] dma_axi_awsize;
  logic  dma_axi_wvalid;
  logic  dma_axi_wready;
  logic [63:0] dma_axi_wdata;
  logic [7:0] dma_axi_wstrb;
  logic  dma_axi_bvalid;
  logic  dma_axi_bready;
  logic [1:0] dma_axi_bresp;
  logic [pt.DMA_BUS_TAG-1:0] dma_axi_bid;
  logic  dma_axi_arvalid;
  logic  dma_axi_arready;
  logic [pt.DMA_BUS_TAG-1:0] dma_axi_arid;
  logic [31:0] dma_axi_araddr;
  logic [2:0] dma_axi_arsize;
  logic  dma_axi_rvalid;
  logic  dma_axi_rready;
  logic [pt.DMA_BUS_TAG-1:0] dma_axi_rid;
  logic [63:0] dma_axi_rdata;
  logic [1:0] dma_axi_rresp;
  logic  dma_axi_rlast;
  initial begin
    clk = 0;
    rst_l = 0;
    dma_bus_clk_en = 0;
    clk_override = 0;
    scan_mode = 0;
    dbg_cmd_addr = 0;
    dbg_cmd_wrdata = 0;
    dbg_cmd_valid = 0;
    dbg_cmd_write = 0;
    dbg_cmd_type = 0;
    dbg_cmd_size = 0;
    dbg_dma_bubble = 0;
    dccm_dma_rvalid = 0;
    dccm_dma_ecc_error = 0;
    dccm_dma_rtag = 0;
    dccm_dma_rdata = 0;
    iccm_dma_rvalid = 0;
    iccm_dma_ecc_error = 0;
    iccm_dma_rtag = 0;
    iccm_dma_rdata = 0;
    dccm_ready = 0;
    iccm_ready = 0;
    dec_tlu_dma_qos_prty = 0;
    dma_axi_awvalid = 0;
    dma_axi_awid = 0;
    dma_axi_awaddr = 0;
    dma_axi_awsize = 0;
    dma_axi_wvalid = 0;
    dma_axi_wdata = 0;
    dma_axi_wstrb = 0;
    dma_axi_bready = 0;
    dma_axi_arvalid = 0;
    dma_axi_arid = 0;
    dma_axi_araddr = 0;
    dma_axi_arsize = 0;
    dma_axi_rready = 0;
    clk_override = 1; dma_bus_clk_en = 1;
    dccm_ready = 1; iccm_ready = 1;
  end

  always #5 clk = ~clk;
  assign free_clk = clk;
  el2_dma_ctrl #(.pt(pt)) dut (.*);
  integer local_writes = 0;
  integer local_reads = 0;
  integer pmu_writes = 0;
  integer pmu_reads = 0;
  logic [31:0] last_addr;
  logic [63:0] last_data;
  logic [31:0] expected_read_addr;
  logic read_outstanding = 0;
  logic inject_ecc = 0;
  always @(posedge clk) begin
    dccm_dma_rvalid <= dma_dccm_req && !dma_mem_write;
    iccm_dma_rvalid <= dma_iccm_req && !dma_mem_write;
    dccm_dma_rtag <= dma_mem_tag;
    iccm_dma_rtag <= dma_mem_tag;
    dccm_dma_rdata <= 64'h0123456789abcdef;
    iccm_dma_rdata <= 64'h0123456789abcdef;
    dccm_dma_ecc_error <= inject_ecc;
    iccm_dma_ecc_error <= inject_ecc;
    if (rst_l) begin
      if (dma_pmu_any_write !== 1'b0) pmu_writes = pmu_writes + 1;
      if (dma_pmu_any_read !== 1'b0) pmu_reads = pmu_reads + 1;
    end
    if (rst_l && (dma_dccm_req || dma_iccm_req)) begin
      if (dma_dccm_req && dma_iccm_req)
        $fatal(1, "one request reached both memories");
      if ((dma_mem_addr == pt.ICCM_SADR && dma_dccm_req) ||
          ((dma_mem_addr == pt.DCCM_SADR || dma_mem_addr == pt.DCCM_SADR + 8) && dma_iccm_req))
        $fatal(1, "local request reached the wrong memory");
      if (!dma_mem_write && (!read_outstanding || dma_mem_addr != expected_read_addr))
        $fatal(1, "local read address does not match its AXI request");
      if ((dma_dccm_req && !dccm_ready) || (dma_iccm_req && !iccm_ready))
        $fatal(1, "local request asserted before the receiver is ready");
      if (!dma_mem_write) local_reads = local_reads + 1;
      if (dma_mem_write) begin
        local_writes = local_writes + 1;
        last_addr = dma_mem_addr;
        last_data = dma_mem_wdata;
      end
    end
  end
  task automatic cycles(input integer count);
    repeat (count) @(negedge clk);
  endtask
  task automatic write_request(input logic [31:0] addr, input integer id,
                               input bit data_first);
    integer writes_before;
    bit address_accepted, data_accepted;
    @(negedge clk);
    writes_before = local_writes;
    address_accepted = 0;
    data_accepted = 0;
    dma_axi_awaddr = addr; dma_axi_awsize = 3; dma_axi_awid = id;
    dma_axi_wdata = 64'hfedcba9876543210; dma_axi_wstrb = 8'hff;
    dma_axi_awvalid = !data_first;
    dma_axi_wvalid = data_first;
    for (integer i=0; i<100; i++) begin
      @(posedge clk);
      address_accepted |= dma_axi_awvalid && dma_axi_awready;
      data_accepted |= dma_axi_wvalid && dma_axi_wready;
      @(negedge clk);
      if (address_accepted) dma_axi_awvalid = 0;
      if (data_accepted) dma_axi_wvalid = 0;
      if (i < 3 && (local_writes != writes_before || dma_axi_bvalid))
        $fatal(1, "write or response advanced before both AW and W were presented");
      // A manager presents the second channel independently of either READY.
      if (i == 2) begin
        if (data_first) dma_axi_awvalid = 1;
        else dma_axi_wvalid = 1;
      end
      if (address_accepted && data_accepted) return;
    end
    $fatal(1, "AW and W were not both accepted");
  endtask
  task automatic write_response(input integer id, input logic [31:0] addr);
    for (integer i=0; i<100; i++) begin
      @(negedge clk);
      if (dma_axi_bvalid) begin
        repeat (3) begin
          if (!dma_axi_bvalid || dma_axi_bid != (id & ((1 << pt.DMA_BUS_TAG)-1)) || dma_axi_bresp != 0)
            $fatal(1, "B response mismatch or lost under backpressure");
          @(negedge clk);
        end
        if (last_addr != addr || last_data != 64'hfedcba9876543210)
          $fatal(1, "write did not reach the correct local address with its data");
        dma_axi_bready = 1; cycles(2); dma_axi_bready = 0; return;
      end
    end
    $fatal(1, "B response missing");
  endtask
  task automatic read_transaction(input logic [31:0] addr, input integer id,
                                  input logic [1:0] response);
    @(negedge clk);
    expected_read_addr = addr; read_outstanding = 1;
    dma_axi_araddr = addr; dma_axi_arsize = 3; dma_axi_arid = id;
    dma_axi_arvalid = 1;
    for (integer i=0; i<100; i++) begin
      @(posedge clk);
      if (dma_axi_arready) begin
        @(negedge clk); dma_axi_arvalid = 0; break;
      end
      if (i == 99) $fatal(1, "AR not accepted");
    end
    for (integer i=0; i<100; i++) begin
      @(negedge clk);
      if (dma_axi_rvalid) begin
        repeat (3) begin
          if (!dma_axi_rvalid || dma_axi_rid != (id & ((1 << pt.DMA_BUS_TAG)-1)) ||
              dma_axi_rresp != response || !dma_axi_rlast)
            $fatal(1, "R response mismatch or lost under backpressure");
          if (response == 0 && dma_axi_rdata != 64'h0123456789abcdef)
            $fatal(1, "local read data did not reach AXI");
          @(negedge clk);
        end
        dma_axi_rready = 1; cycles(2); dma_axi_rready = 0;
        read_outstanding = 0; return;
      end
    end
    $fatal(1, "R response missing");
  endtask
  initial begin
    $display("CONFIG DCCM_ENABLE=%0d ICCM_ENABLE=%0d DMA_BUS_TAG=%0d", pt.DCCM_ENABLE, pt.ICCM_ENABLE, pt.DMA_BUS_TAG);
    cycles(3); rst_l = 1; cycles(3);
    write_request(pt.DCCM_SADR, 1, 0); write_response(1, pt.DCCM_SADR);
    $display("PASS AWVALID-before-WVALID DCCM write and B backpressure");
    write_request(pt.DCCM_SADR + 8, 2, 1); write_response(2, pt.DCCM_SADR + 8);
    $display("PASS WVALID-before-AWVALID DCCM write and B backpressure");
    read_transaction(pt.DCCM_SADR, 3, 0);
    if (pt.ICCM_ENABLE) read_transaction(pt.ICCM_SADR, 4, 0);
    $display("PASS enabled local read data, IDs, RLAST and R backpressure");
    inject_ecc = 1; read_transaction(pt.DCCM_SADR, 5, 2);
    $display("PASS DCCM ECC read error");
    inject_ecc = 0; dccm_ready = 0; dec_tlu_dma_qos_prty = 7;
    fork
      read_transaction(pt.DCCM_SADR, 6, 0);
      begin
        for (integer i=0; i<100; i++) begin
          cycles(1);
          if (dma_dccm_stall_any) break;
          if (i == 99)
            $fatal(1, "QoS did not request a DCCM bubble after repeated denials");
        end
        dccm_ready = 1;
      end
    join
    $display("PASS DCCM receiver backpressure and QoS bubble");
    cycles(3);
    // Each PMU output is a per-cycle event: one active cycle per local transaction.
    if (pmu_reads != local_reads || pmu_writes != local_writes)
      $fatal(1, "PMU read/write totals %0d/%0d differ from local requests %0d/%0d",
             pmu_reads, pmu_writes, local_reads, local_writes);
    $display("PASS PMU transaction totals");
    $display("DMA_AXI_DIAGNOSTIC_PASS"); $finish;
  end
  initial begin #30000; $fatal(1, "diagnostic watchdog"); end
endmodule
