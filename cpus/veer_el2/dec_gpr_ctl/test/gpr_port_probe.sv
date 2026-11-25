`timescale 1ns/1ps
module gpr_port_probe;
  import el2_pkg::*;

  logic clk = 0;
  logic rst_l = 1;
  logic scan_mode = 0;
  logic [4:0] raddr0 = 0, raddr1 = 0;
  logic wen0 = 0, wen1 = 0, wen2 = 0;
  logic [4:0] waddr0 = 0, waddr1 = 0, waddr2 = 0;
  logic [31:0] wd0 = 0, wd1 = 0, wd2 = 0;
  logic [31:0] rd0, rd1;
  el2_dec_gpr_ctl dut (.*);

  task automatic check(input string phase, input logic [31:0] expected0, expected1);
    if (rd0 !== expected0 || rd1 !== expected1) begin
      $display("GPR_PORT_MISMATCH: %s expected=%08h,%08h actual=%08h,%08h",
               phase, expected0, expected1, rd0, rd1);
      $fatal(1, "GPR port mismatch");
    end
    $display("GPR_PORT_OBSERVED: %s rd0=%08h rd1=%08h", phase, rd0, rd1);
  endtask

  task automatic clock_write();
    #1 clk = 1;
    #1 clk = 0;
    #1;
  endtask

  initial begin
    #1 rst_l = 0;
    #1 rst_l = 1;
    raddr0 = 5'd9;
    raddr1 = 5'd17;
    waddr0 = 5'd17;
    wd0 = 32'hc071e872;
    wen0 = 1;
    waddr1 = 5'd9;
    wd1 = 32'h5ad34f19;
    wen1 = 1;
    #1 check("before write edge", 32'h0, 32'h0);
    clock_write();
    check("nonblocking load plus normal writeback", 32'h5ad34f19, 32'hc071e872);

    wen0 = 0;
    waddr1 = 0;
    wd1 = 32'hffffffff;
    raddr0 = 0;
    raddr1 = 5'd9;
    clock_write();
    check("load write to x0", 32'h0, 32'h5ad34f19);

    wen1 = 0;
    raddr0 = 5'd17;
    #1 check("before asynchronous reset", 32'hc071e872, 32'h5ad34f19);
    rst_l = 0;
    #1 check("asynchronous reset without a clock edge", 32'h0, 32'h0);
    $display("GPR_PORT_PASS");
    $finish;
  end
endmodule
