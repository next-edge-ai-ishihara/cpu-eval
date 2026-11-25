module mux_configuration #(
  parameter integer N=2, W=1, MODE=0, ID=0
) (output logic done, output integer checks, errors);
  localparam integer S=MODE ? N : $clog2(N);
  localparam integer PATTERNS=W<=2 ? (1<<(W*N)) : 16;
  logic [N-1:0][W-1:0] data;
  logic [S-1:0] selector;
  wire [W-1:0] actual;
  logic [W-1:0] expected;
  hpdcache_mux #(.NINPUT(N), .DATA_WIDTH(W), .ONE_HOT_SEL(MODE))
    dut (.data_i(data), .sel_i(selector), .data_o(actual));
  initial begin
    done=0; checks=0; errors=0;
    for (integer selected=0; selected<N; selected++) begin
      for (integer pattern=0; pattern<PATTERNS; pattern++) begin
        for (integer input_index=0; input_index<N; input_index++) begin
          if (W<=2) data[input_index]=W'(pattern >> (W*input_index));
          else data[input_index]=W'({4{32'(53*pattern+29*(input_index-selected)+1) * 32'h9e3779b9}});
        end
        selector=$bits(selector)'(MODE ? (1<<selected) : selected);
        expected=data[selected];
        #1;
        checks++;
        $display("OBS config=%0d check=%0d n=%0d width=%0d mode=%0d selected=%0d selector=%0h inputs=%0h actual=%0h expected=%0h",
          ID,checks,N,W,MODE,selected,selector,data,actual,expected);
        if (actual !== expected) begin
          errors++;
          $display("MISMATCH config=%0d check=%0d",ID,checks);
        end
      end
    end
    done=1;
  end
endmodule

// The NINPUT, DATA_WIDTH and ONE_HOT_SEL combinations that cv32a60x instantiates.
module tb;
  localparam integer CONFIGURATIONS=20;
  localparam integer NS[CONFIGURATIONS]='{2,2,2,1,2,2,2,2,3,3,4,4,4,4,5,5,5,5,8,8};
  localparam integer WS[CONFIGURATIONS]='{1,32,64,128,24,32,64,86,73,86,1,34,89,93,1,5,24,89,3,36};
  localparam integer MS[CONFIGURATIONS]='{0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
  wire [CONFIGURATIONS-1:0] done;
  wire integer checks [CONFIGURATIONS], errors [CONFIGURATIONS];
  for (genvar i=0; i<CONFIGURATIONS; i++) begin : configurations
    mux_configuration #(.N(NS[i]), .W(WS[i]), .MODE(MS[i]), .ID(i))
      instance_i(done[i], checks[i], errors[i]);
  end
  integer total_checks, total_errors;
  initial begin
    wait (&done);
    total_checks=0; total_errors=0;
    for (integer i=0; i<CONFIGURATIONS; i++) begin
      total_checks+=checks[i]; total_errors+=errors[i];
    end
    $display("SUMMARY checks=%0d errors=%0d",total_checks,total_errors);
    if (total_errors==0) $display("MUX_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
