// Binary selection with the data widths that cv32a60x instantiates.
module tb;
  logic sel;
  logic d1;
  logic [3:0] d4;
  logic [70:0] d71;
  wire [1:0][0:0] o1;
  wire [1:0][3:0] o4;
  wire [1:0][70:0] o71;
  hpdcache_demux #(.NOUTPUT(2), .DATA_WIDTH(1), .ONE_HOT_SEL(0)) u_w1(d1,sel,o1);
  hpdcache_demux #(.NOUTPUT(2), .DATA_WIDTH(4), .ONE_HOT_SEL(0)) u_w4(d4,sel,o4);
  hpdcache_demux #(.NOUTPUT(2), .DATA_WIDTH(71), .ONE_HOT_SEL(0)) u_w71(d71,sel,o71);
  integer checks=0, errors=0;
  logic [141:0] expected, actual;
  task check_value(input integer width_bits, input integer selected, input logic [70:0] value);
    d1=1'(value); d4=4'(value); d71=value;
    sel=1'(selected);
    #1;
    case (width_bits)
      1: begin expected=142'(1'(value)) << selected; actual=142'(o1); end
      4: begin expected=142'(4'(value)) << (4*selected); actual=142'(o4); end
      default: begin expected=142'(value) << (71*selected); actual=142'(o71); end
    endcase
    checks++;
    $display("OBS check=%0d width=%0d selected=%0d data=%0h actual=%0h expected=%0h",checks,width_bits,selected,value,actual,expected);
    if(actual !== expected) begin
      errors++;
      $display("MISMATCH check=%0d",checks);
    end
  endtask
  initial begin
    for(integer selected=0;selected<2;selected++) begin
      check_value(1,selected,0);
      check_value(1,selected,1);
      check_value(4,selected,0);
      check_value(4,selected,1);
      check_value(4,selected,8);
      check_value(4,selected,15);
      check_value(71,selected,0);
      check_value(71,selected,1);
      check_value(71,selected,71'(1) << 70);
      check_value(71,selected,'1);
    end
    $display("SUMMARY checks=%0d errors=%0d",checks,errors);
    if(errors==0) $display("DEMUX_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
