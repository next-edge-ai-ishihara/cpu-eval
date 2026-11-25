`timescale 1ns/1ps
module dbg_port_probe;
 import el2_pkg::*;
 `include "el2_param.vh"
;
  logic [31:0] dbg_cmd_addr;
  logic [31:0] dbg_cmd_wrdata;
  logic  dbg_cmd_valid;
  logic  dbg_cmd_write;
  logic [1:0] dbg_cmd_type;
  logic [1:0] dbg_cmd_size;
  logic  dbg_core_rst_l;
  logic [31:0] core_dbg_rddata=0;
  logic  core_dbg_cmd_done=0;
  logic  core_dbg_cmd_fail=0;
  logic  dbg_dma_bubble;
  logic  dma_dbg_ready=0;
  logic  dbg_halt_req;
  logic  dbg_resume_req;
  logic  dec_tlu_debug_mode=0;
  logic  dec_tlu_dbg_halted=0;
  logic  dec_tlu_mpc_halted_only=0;
  logic  dec_tlu_resume_ack=0;
  logic  dmi_reg_en=0;
  logic [6:0] dmi_reg_addr=0;
  logic  dmi_reg_wr_en=0;
  logic [31:0] dmi_reg_wdata=0;
  logic [31:0] dmi_reg_rdata;
  logic  sb_axi_awvalid;
  logic  sb_axi_awready=0;
  logic [pt.SB_BUS_TAG-1:0] sb_axi_awid;
  logic [31:0] sb_axi_awaddr;
  logic [3:0] sb_axi_awregion;
  logic [7:0] sb_axi_awlen;
  logic [2:0] sb_axi_awsize;
  logic [1:0] sb_axi_awburst;
  logic  sb_axi_awlock;
  logic [3:0] sb_axi_awcache;
  logic [2:0] sb_axi_awprot;
  logic [3:0] sb_axi_awqos;
  logic  sb_axi_wvalid;
  logic  sb_axi_wready=0;
  logic [63:0] sb_axi_wdata;
  logic [7:0] sb_axi_wstrb;
  logic  sb_axi_wlast;
  logic  sb_axi_bvalid=0;
  logic  sb_axi_bready;
  logic [1:0] sb_axi_bresp=0;
  logic  sb_axi_arvalid;
  logic  sb_axi_arready=0;
  logic [pt.SB_BUS_TAG-1:0] sb_axi_arid;
  logic [31:0] sb_axi_araddr;
  logic [3:0] sb_axi_arregion;
  logic [7:0] sb_axi_arlen;
  logic [2:0] sb_axi_arsize;
  logic [1:0] sb_axi_arburst;
  logic  sb_axi_arlock;
  logic [3:0] sb_axi_arcache;
  logic [2:0] sb_axi_arprot;
  logic [3:0] sb_axi_arqos;
  logic  sb_axi_rvalid=0;
  logic  sb_axi_rready;
  logic [63:0] sb_axi_rdata=0;
  logic [1:0] sb_axi_rresp=0;
  logic  dbg_bus_clk_en=0;
  logic  dccm_wr_rdbk_fault_valid=0;
  logic [pt.DCCM_BITS-1:0] dccm_wr_rdbk_fault_addr=0;
  logic [pt.DCCM_FDATA_WIDTH-1:0] dccm_wr_rdbk_fault_data=0;
  logic  dccm_wr_rdbk_fault_clear;
  logic  clk=0;
  logic  rst_l=0;
  logic  dbg_rst_l=0;
  logic  clk_override=0;
  logic  scan_mode=0;
 wire free_clk=clk;
 el2_dbg #(.pt(pt)) dut (.*);

  always #5 clk = ~clk;
  always @(posedge clk) begin
    if (dbg_halt_req) halt_seen = 1;
    if (dbg_resume_req) resume_seen = 1;
    if (sb_axi_awvalid && sb_axi_awready) aw_count++;
    if (sb_axi_wvalid && sb_axi_wready) w_count++;
    if (sb_axi_arvalid && sb_axi_arready) ar_count++;
    if (sb_axi_bvalid && sb_axi_bready) b_count++;
    if (sb_axi_rvalid && sb_axi_rready) r_count++;
    if (dbg_cmd_valid && dma_dbg_ready) begin
      core_count++;
      accepted_addr=dbg_cmd_addr; accepted_data=dbg_cmd_wrdata;
      accepted_type=dbg_cmd_type; accepted_size=dbg_cmd_size;
      accepted_write=dbg_cmd_write;
    end
  end
  int aw_count=0, w_count=0, ar_count=0;
  int b_count=0, r_count=0;
  int core_count=0;
  logic [31:0] accepted_addr, accepted_data;
  logic [1:0] accepted_type, accepted_size;
  bit accepted_write;
  bit halt_seen=0, resume_seen=0;
  logic [31:0] status;
  task automatic tick(input int n=1);
    repeat(n) begin @(posedge clk); #1; end
  endtask
  task automatic write_dmi(input logic [6:0] addr, input logic [31:0] data);
    @(negedge clk); dmi_reg_addr=addr; dmi_reg_wdata=data;
    dmi_reg_en=1; dmi_reg_wr_en=1;
    tick(); @(negedge clk); dmi_reg_en=0; dmi_reg_wr_en=0; tick();
  endtask
  task automatic read_dmi(input logic [6:0] addr, output logic [31:0] data);
    @(negedge clk); dmi_reg_addr=addr; dmi_reg_en=1; dmi_reg_wr_en=0;
    tick(); data=dmi_reg_rdata;
    @(negedge clk); dmi_reg_en=0; tick();
  endtask
  task automatic wait_core_reset(input bit expected);
    for (int i=0;i<32;i++) begin
      tick();
      if (dbg_core_rst_l===expected) return;
    end
    $display("DBG_PORT_DIAGNOSTIC_FAIL: core reset wait bound"); $finish; #1;
  endtask
  task automatic wait_idle;
    for (int i=0;i<32;i++) begin
      read_dmi('h38,status);
      if (!status[21]) return;
    end
    $display("DBG_PORT_DIAGNOSTIC_FAIL: system bus wait bound"); $finish; #1;
  endtask
  task automatic wait_status(input logic [31:0] mask, input logic [31:0] expected);
    for (int i=0;i<32;i++) begin
      read_dmi('h11,status);
      if ((status & mask)==expected) return;
    end
    $display("DBG_PORT_DIAGNOSTIC_FAIL: debug status wait bound"); $finish; #1;
  endtask
  task automatic core_access(input logic [31:0] command, input logic [31:0] addr,
                             input logic [1:0] kind, input bit writing);
    int before_count;
    before_count=core_count;
    write_dmi('h4,32'h76543210); write_dmi('h5,addr);
    @(negedge clk); dma_dbg_ready=1;
    write_dmi('h17,command);
    for (int i=0;i<32 && core_count==before_count;i++) tick();
    if (core_count==before_count) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: core command wait bound"); $finish; #1;
    end
    if (accepted_type!=kind || (kind==2 && accepted_size!=2) || accepted_write!=writing ||
        (kind==0 ? accepted_addr[4:0]!=addr[4:0] :
         kind==1 ? accepted_addr[11:0]!=addr[11:0] : accepted_addr!=addr) ||
        (writing && accepted_data!=32'h76543210))
      $fatal(1,"Abstract command port fields");
    tick(2); @(negedge clk); core_dbg_rddata=32'h89abcdef; core_dbg_cmd_done=1;
    tick(); @(negedge clk); core_dbg_cmd_done=0;
    for (int i=0;i<32;i++) begin
      read_dmi('h16,status);
      if (!status[12]) break;
    end
    if (status[12]) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: abstract completion wait bound"); $finish; #1;
    end
    if (status[10:8]!=0 || core_count-before_count!=1)
      $fatal(1,"Abstract command completion or duplicate request");
    if (!writing) begin
      read_dmi('h4,status);
      if (status!=32'h89abcdef) $fatal(1,"Abstract read result");
    end
  endtask
  task automatic bad_access(input int size, input logic [31:0] addr, input int error);
    write_dmi('h38,(size<<17)|32'h7000);
    write_dmi('h39,addr); write_dmi('h3c,32'h12345678);
    wait_idle();
    if (status[14:12]!=error || sb_axi_awvalid || sb_axi_wvalid || sb_axi_arvalid)
      $fatal(1,"Invalid access error or external request");
  endtask
  task automatic ordered_write(input bit address_first);
    int aw_before, w_before, b_before;
    aw_before=aw_count; w_before=w_count; b_before=b_count;
    write_dmi('h38,32'h47000); write_dmi('h39,32'h80000000);
    write_dmi('h3c,32'h12345678);
    for (int i=0;i<32;i++) begin
      if (sb_axi_awvalid && sb_axi_wvalid) break;
      tick();
    end
    if (!sb_axi_awvalid || !sb_axi_wvalid) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: write channel wait bound"); $finish; #1;
    end
    if (sb_axi_awaddr!=32'h80000000 || sb_axi_awsize!=2 ||
        sb_axi_wstrb!=8'h0f || sb_axi_wdata[31:0]!=32'h12345678)
      $fatal(1,"Write address, size, mask or active data");
    @(negedge clk); sb_axi_awready=address_first; sb_axi_wready=!address_first;
    tick(); @(negedge clk); sb_axi_awready=0; sb_axi_wready=0;
    tick(3);
    if (address_first ? !sb_axi_wvalid : !sb_axi_awvalid)
      $fatal(1,"Unaccepted channel was dropped");
    @(negedge clk); sb_axi_awready=!address_first; sb_axi_wready=address_first;
    tick(); @(negedge clk); sb_axi_awready=0; sb_axi_wready=0;
    tick(2); @(negedge clk); sb_axi_bvalid=1;
    for (int i=0;i<32 && b_count==b_before;i++) tick();
    if (b_count==b_before) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: write response wait bound"); $finish; #1;
    end
    @(negedge clk); sb_axi_bvalid=0; wait_idle();
    if (status[14:12]!=0 || aw_count-aw_before!=1 || w_count-w_before!=1)
      $fatal(1,"Write completion or duplicate channels");
  endtask
  task automatic bus_read;
    int before_count, response_before;
    before_count=ar_count; response_before=r_count;
    write_dmi('h38,32'h157000); write_dmi('h39,32'h80000004);
    for (int i=0;i<32 && !sb_axi_arvalid;i++) tick();
    if (!sb_axi_arvalid) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: read channel wait bound"); $finish; #1;
    end
    if (sb_axi_araddr!=32'h80000004 || sb_axi_arsize!=2)
      $fatal(1,"Read address or size");
    @(negedge clk); sb_axi_arready=1; tick();
    @(negedge clk); sb_axi_arready=0; tick(2);
    @(negedge clk); sb_axi_rdata=64'hcafebabedeadbeef; sb_axi_rvalid=1;
    for (int i=0;i<32 && r_count==response_before;i++) tick();
    if (r_count==response_before) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: read response wait bound"); $finish; #1;
    end
    @(negedge clk); sb_axi_rvalid=0; wait_idle();
    if (status[14:12]!=0 || ar_count-before_count!=1) $fatal(1,"Read completion");
    read_dmi('h3c,status);
    if (status!=32'hcafebabe) $fatal(1,"Read data lane");
    read_dmi('h39,status);
    if (status!=32'h80000008) $fatal(1,"Read address increment");
  endtask
  initial begin
    clk_override=1; dbg_bus_clk_en=1;
    tick(3); @(negedge clk); rst_l=1; dbg_rst_l=1; tick(3);
    wait_core_reset(1);
    write_dmi('h10,1); write_dmi('h10,3);
    wait_core_reset(0);
    write_dmi('h10,1);
    wait_core_reset(1);
    write_dmi('h10,32'h80000001); tick(4);
    for (int i=0;i<32 && !halt_seen;i++) tick();
    if (!halt_seen) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: halt request wait bound"); $finish; #1;
    end
    @(negedge clk); dec_tlu_debug_mode=1; dec_tlu_dbg_halted=1; tick(4);
    wait_status(32'h300,32'h300);
    core_access(32'h00221001,32'h1,0,0);
    core_access(32'h00220300,32'h300,1,0);
    core_access(32'h02200000,32'hf0040000,2,0);
    core_access(32'h02210000,32'hf0040004,2,1);
    write_dmi('h10,32'h40000001); tick(4);
    for (int i=0;i<32 && !resume_seen;i++) tick();
    if (!resume_seen) begin
      $display("DBG_PORT_DIAGNOSTIC_FAIL: resume request wait bound"); $finish; #1;
    end
    @(negedge clk); dec_tlu_resume_ack=1; dec_tlu_debug_mode=0; dec_tlu_dbg_halted=0;
    tick(); @(negedge clk); dec_tlu_resume_ack=0; tick(4);
    wait_status(32'h30300,32'h30000);
    bad_access(1,32'h80000001,3); bad_access(2,32'h80000002,3);
    bad_access(3,32'h80000004,3); bad_access(4,32'h80000000,4);
    if (aw_count || w_count || ar_count) $fatal(1,"Invalid bus side effects");
    ordered_write(1); ordered_write(0);
    bus_read();
    $display("DBG_PORT_DIAGNOSTIC_PASS"); $finish;
  end
  initial begin #20000; $display("DBG_PORT_DIAGNOSTIC_FAIL: watchdog"); $finish; end
endmodule
