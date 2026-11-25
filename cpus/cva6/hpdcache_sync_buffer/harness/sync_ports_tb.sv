module tb;
  // FEEDTHROUGH and data widths of the hpdcache_sync_buffer instances in cv32a60x.
  localparam int WIDTHS[4] = '{4, 38, 86, 86};
  logic clk_i=0, rst_ni=1, w_i=0, r_i=0;
  logic [85:0] wdata_i=0;
  wire [3:0] wok, rok;
  wire [85:0] rd[4];
  integer current_case=0;
  for (genvar j=0; j<4; j++) begin : configurations
    wire [WIDTHS[j]-1:0] result;
    hpdcache_sync_buffer #(.FEEDTHROUGH(1'(j%2)), .data_t(logic[WIDTHS[j]-1:0])) dut
      (.clk_i,.rst_ni,.w_i,.wok_o(wok[j]),.wdata_i(wdata_i[WIDTHS[j]-1:0]),.r_i,.rok_o(rok[j]),.rdata_o(result));
    assign rd[j]=86'(result);
  end
  function automatic logic [85:0] word_of(input logic [7:0] value);
    return 86'({11{value}});
  endfunction
  function automatic logic [85:0] mask_of(input int j);
    return {86{1'b1}} >> (86 - WIDTHS[j]);
  endfunction
  task automatic mismatch(input integer configuration, input string reason);
    $display("MISMATCH config=%0d case=%0d reason=%s",configuration,current_case,reason);
    $finish;
  endtask
  task automatic check(input bit occupied, input logic[85:0] word);
    for (int j=0; j<4; j++) begin
      bit f, ew, er;
      logic [85:0] expected;
      f=1'(j%2); ew=!occupied||(f&&r_i); er=occupied||(f&&w_i);
      expected=(occupied ? word : wdata_i) & mask_of(j);
      if (wok[j]!==ew || rok[j]!==er) mismatch(j,"flags");
      if (er && rd[j]!==expected) mismatch(j,"valid_data");
    end
  endtask
  initial begin
    for (int occupied=0; occupied<2; occupied++)
      for (int write_request=0; write_request<2; write_request++)
        for (int ready=0; ready<2; ready++)
          for (int payload=0; payload<256; payload++) begin

            clk_i=0; rst_ni=0; w_i=0; r_i=0; wdata_i=word_of(8'h5a); #2;
            rst_ni=1; #2;
            check(0,0);
            if (occupied!=0) begin
              w_i=1; #2; check(0,0);
              clk_i=1; #2; clk_i=0; w_i=0; #2; check(1,word_of(8'h5a));
            end
            w_i=1'(write_request); r_i=1'(ready); wdata_i=word_of(8'(payload)); #2;
            check(1'(occupied),word_of(8'h5a));
            clk_i=1; #2; clk_i=0; w_i=0; r_i=0; #2;
            for (int j=0; j<4; j++) begin
              bit f, next_occupied, stored;
              logic [85:0] expected;
              f=1'(j%2);
              next_occupied=occupied!=0 ? (!1'(ready)||(f&&1'(write_request))) :
                (1'(write_request)&&!(f&&1'(ready)));
              stored=1'(write_request)&&(occupied!=0 ? f&&1'(ready) : !(f&&1'(ready)));
              expected=(stored ? word_of(8'(payload)) : word_of(8'h5a)) & mask_of(j);
              if (rok[j]!==next_occupied || wok[j]!==!next_occupied) mismatch(j,"post_edge_flags");
              if (next_occupied && rd[j]!==expected) mismatch(j,"post_edge_data");
            end

            wdata_i=word_of(8'(~payload)); #2;
            clk_i=1; #2; clk_i=0; #2;
            for (int j=0; j<4; j++) begin
              bit f, next_occupied, stored;
              logic [85:0] expected;
              f=1'(j%2);
              next_occupied=occupied!=0 ? (!1'(ready)||(f&&1'(write_request))) :
                (1'(write_request)&&!(f&&1'(ready)));
              stored=1'(write_request)&&(occupied!=0 ? f&&1'(ready) : !(f&&1'(ready)));
              expected=(stored ? word_of(8'(payload)) : word_of(8'h5a)) & mask_of(j);
              if (rok[j]!==next_occupied || wok[j]!==!next_occupied) mismatch(j,"hold_flags");
              if (next_occupied && rd[j]!==expected) mismatch(j,"hold_data");
            end
            $display("OBS case=%0d",current_case);
            current_case++;
          end
    $display("SUMMARY configurations=4 cases=2048 errors=0");
    $display("SYNC_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
