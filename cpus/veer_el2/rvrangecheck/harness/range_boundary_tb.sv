`timescale 1ns/1ps
module range_boundary_tb;
logic [31:0] addr;
integer errors=0;
wire r0,g0;
rvrangecheck #(.CCM_SADR(32'hf0040000),.CCM_SIZE(64)) dut0(.addr(addr), .in_range(r0), .in_region(g0));
wire r1,g1;
rvrangecheck #(.CCM_SADR(32'hee000000),.CCM_SIZE(64)) dut1(.addr(addr), .in_range(r1), .in_region(g1));
wire r2,g2;
rvrangecheck #(.CCM_SADR(32'hf00c0000),.CCM_SIZE(32)) dut2(.addr(addr), .in_range(r2), .in_region(g2));
wire range_48k, region_48k, range_top, region_top;
rvrangecheck #(.CCM_SADR(32'h20010000), .CCM_SIZE(48)) dut_48k(.addr(addr), .in_range(range_48k), .in_region(region_48k));
rvrangecheck #(.CCM_SADR(32'hffff0000), .CCM_SIZE(64)) dut_top(.addr(addr), .in_range(range_top), .in_region(region_top));

task automatic check_boundary(
    input logic [31:0] address,
    input logic top_block,
    input logic [1:0] expected
);
    logic [1:0] actual;
    addr = address;
    #1;
    actual = top_block ? {range_top, region_top} : {range_48k, region_48k};
    if (actual !== expected) begin
        errors++;
        $display("RANGE_PROBE_MISMATCH top_block=%b addr=%h expected=%b actual=%b",
                 top_block, address, expected, actual);
    end
endtask

initial begin
addr=32'h00000000; #1;
if (r0 !== 1'b0 || g0 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=0 addr=%h expected=0,0 actual=%b,%b",addr,r0,g0); end
addr=32'hefffffff; #1;
if (r0 !== 1'b0 || g0 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=1 addr=%h expected=0,0 actual=%b,%b",addr,r0,g0); end
addr=32'hf0000000; #1;
if (r0 !== 1'b0 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=2 addr=%h expected=0,1 actual=%b,%b",addr,r0,g0); end
addr=32'hf003ffff; #1;
if (r0 !== 1'b0 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=3 addr=%h expected=0,1 actual=%b,%b",addr,r0,g0); end
addr=32'hf0040000; #1;
if (r0 !== 1'b1 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=4 addr=%h expected=1,1 actual=%b,%b",addr,r0,g0); end
addr=32'hf0040001; #1;
if (r0 !== 1'b1 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=5 addr=%h expected=1,1 actual=%b,%b",addr,r0,g0); end
addr=32'hf004ffff; #1;
if (r0 !== 1'b1 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=6 addr=%h expected=1,1 actual=%b,%b",addr,r0,g0); end
addr=32'hf0050000; #1;
if (r0 !== 1'b0 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=7 addr=%h expected=0,1 actual=%b,%b",addr,r0,g0); end
addr=32'hffffffff; #1;
if (r0 !== 1'b0 || g0 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=8 addr=%h expected=0,1 actual=%b,%b",addr,r0,g0); end
addr=32'h00000000; #1;
if (r1 !== 1'b0 || g1 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=9 addr=%h expected=0,0 actual=%b,%b",addr,r1,g1); end
addr=32'hdfffffff; #1;
if (r1 !== 1'b0 || g1 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=10 addr=%h expected=0,0 actual=%b,%b",addr,r1,g1); end
addr=32'he0000000; #1;
if (r1 !== 1'b0 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=11 addr=%h expected=0,1 actual=%b,%b",addr,r1,g1); end
addr=32'hedffffff; #1;
if (r1 !== 1'b0 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=12 addr=%h expected=0,1 actual=%b,%b",addr,r1,g1); end
addr=32'hee000000; #1;
if (r1 !== 1'b1 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=13 addr=%h expected=1,1 actual=%b,%b",addr,r1,g1); end
addr=32'hee000001; #1;
if (r1 !== 1'b1 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=14 addr=%h expected=1,1 actual=%b,%b",addr,r1,g1); end
addr=32'hee00ffff; #1;
if (r1 !== 1'b1 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=15 addr=%h expected=1,1 actual=%b,%b",addr,r1,g1); end
addr=32'hee010000; #1;
if (r1 !== 1'b0 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=16 addr=%h expected=0,1 actual=%b,%b",addr,r1,g1); end
addr=32'hefffffff; #1;
if (r1 !== 1'b0 || g1 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=17 addr=%h expected=0,1 actual=%b,%b",addr,r1,g1); end
addr=32'hf0000000; #1;
if (r1 !== 1'b0 || g1 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=18 addr=%h expected=0,0 actual=%b,%b",addr,r1,g1); end
addr=32'hffffffff; #1;
if (r1 !== 1'b0 || g1 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=19 addr=%h expected=0,0 actual=%b,%b",addr,r1,g1); end
addr=32'h00000000; #1;
if (r2 !== 1'b0 || g2 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=20 addr=%h expected=0,0 actual=%b,%b",addr,r2,g2); end
addr=32'hefffffff; #1;
if (r2 !== 1'b0 || g2 !== 1'b0) begin errors++; $display("RANGE_PROBE_MISMATCH vector=21 addr=%h expected=0,0 actual=%b,%b",addr,r2,g2); end
addr=32'hf0000000; #1;
if (r2 !== 1'b0 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=22 addr=%h expected=0,1 actual=%b,%b",addr,r2,g2); end
addr=32'hf00bffff; #1;
if (r2 !== 1'b0 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=23 addr=%h expected=0,1 actual=%b,%b",addr,r2,g2); end
addr=32'hf00c0000; #1;
if (r2 !== 1'b1 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=24 addr=%h expected=1,1 actual=%b,%b",addr,r2,g2); end
addr=32'hf00c0001; #1;
if (r2 !== 1'b1 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=25 addr=%h expected=1,1 actual=%b,%b",addr,r2,g2); end
addr=32'hf00c7fff; #1;
if (r2 !== 1'b1 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=26 addr=%h expected=1,1 actual=%b,%b",addr,r2,g2); end
addr=32'hf00c8000; #1;
if (r2 !== 1'b0 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=27 addr=%h expected=0,1 actual=%b,%b",addr,r2,g2); end
addr=32'hffffffff; #1;
if (r2 !== 1'b0 || g2 !== 1'b1) begin errors++; $display("RANGE_PROBE_MISMATCH vector=28 addr=%h expected=0,1 actual=%b,%b",addr,r2,g2); end
// The alignment window is 64 KiB; the block occupies only the first 48 KiB.
check_boundary(32'h1fffffff, 0, 2'b00);
check_boundary(32'h20000000, 0, 2'b01);
check_boundary(32'h2000ffff, 0, 2'b01);
check_boundary(32'h20010000, 0, 2'b11);
check_boundary(32'h2001bfff, 0, 2'b11);
check_boundary(32'h2001c000, 0, 2'b01);
check_boundary(32'h2001ffff, 0, 2'b01);
check_boundary(32'h30000000, 0, 2'b00);

// The final byte of a block can be the largest 32-bit address.
check_boundary(32'hefffffff, 1, 2'b00);
check_boundary(32'hf0000000, 1, 2'b01);
check_boundary(32'hfffeffff, 1, 2'b01);
check_boundary(32'hffff0000, 1, 2'b11);
check_boundary(32'hffff0001, 1, 2'b11);
check_boundary(32'hffffffff, 1, 2'b11);
check_boundary(32'h00000000, 1, 2'b00);

$display("RANGE_PROBE_COMPLETE checked=44 errors=%0d",errors);
$finish;
end
endmodule
