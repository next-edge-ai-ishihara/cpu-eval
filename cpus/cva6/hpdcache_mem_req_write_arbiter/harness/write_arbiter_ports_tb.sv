module tb;
  // hpdcache instantiates the write arbiter with N=3 and these memory request layouts.
  localparam int N = 3;
  localparam int REQUESTS = 8;
  typedef struct packed {
    logic [63:0] mem_req_addr;
    logic [7:0] mem_req_len;
    logic [2:0] mem_req_size;
    logic [3:0] mem_req_id;
    logic [1:0] mem_req_command;
    logic [3:0] mem_req_atomic;
    logic mem_req_cacheable;
  } req_t;
  typedef struct packed {
    logic [63:0] mem_req_w_data;
    logic [7:0] mem_req_w_be;
    logic mem_req_w_last;
  } data_t;
  logic clk = 0, rst = 0;
  logic [N-1:0] rv, rr, dv, dr;
  req_t [N-1:0] req;
  data_t [N-1:0] data_in;
  logic ready, data_ready, valid, data_valid;
  req_t out_req;
  data_t out_data;
  int sent[N], data_req[N], data_beat[N];
  int owner[128], serial[128];
  bit order_selected[128];
  int accepted = 0, forwarded = 0, completed = 0, output_beat = 0;
  bit data_accepted[N][REQUESTS][3];
  bit previous_request_stall = 0, previous_data_stall = 0;
  req_t stalled_req;
  data_t stalled_data;
  int cycle;
  int request_stalls=0, data_stalls=0, competing_cycles=0, data_transfers=0;

  hpdcache_mem_req_write_arbiter #(.N(N), .hpdcache_mem_req_t(req_t),
    .hpdcache_mem_req_w_t(data_t)) dut (
    .clk_i(clk), .rst_ni(rst), .mem_req_write_ready_o(rr),
    .mem_req_write_valid_i(rv), .mem_req_write_i(req),
    .mem_req_write_data_ready_o(dr), .mem_req_write_data_valid_i(dv),
    .mem_req_write_data_i(data_in), .mem_req_write_ready_i(ready),
    .mem_req_write_valid_o(valid), .mem_req_write_o(out_req),
    .mem_req_write_data_ready_i(data_ready),
    .mem_req_write_data_valid_o(data_valid), .mem_req_write_data_o(out_data));

  function automatic int beats(int request_index);
    return 1 + request_index % 3;
  endfunction

  function automatic req_t request_payload(int source, int request_index);
    req_t r;
    r.mem_req_addr = {32'h0000_0080, 32'(16'h3100 + source * 32 + request_index)};
    r.mem_req_len = 8'(beats(request_index) - 1);
    r.mem_req_size = 3'd3;
    r.mem_req_id = 4'(source * 4 + request_index % 4);
    r.mem_req_command = 2'b01;
    r.mem_req_atomic = '0;
    r.mem_req_cacheable = 1'b0;
    return r;
  endfunction

  function automatic logic [63:0] data_payload(int source, int request_index, int beat);
    logic [31:0] low = 32'(16'ha000 + source * 256 + request_index * 4 + beat);
    return {~low, low};
  endfunction

  function automatic logic [7:0] byte_enable(int source, int request_index, int beat);
    return 8'(17 * (1 + (source + request_index + beat) % 3));
  endfunction

  task automatic mismatch(string reason);
    $display("MISMATCH cycle=%0d reason=%s", cycle, reason);
    $fatal(1, "external transfer mismatch");
  endtask

  task automatic select_order(int position, int source, int request_index);
    int found, temporary;
    if (position >= accepted) mismatch("output_without_source_request");
    if (order_selected[position]) begin
      if (owner[position] != source || serial[position] != request_index)
        mismatch("request_data_order_disagreement");
    end else begin
      found = -1;
      for (int i=position; i<accepted; i++) begin
        if (owner[i] == source && serial[i] < request_index)
          mismatch("source_request_order");
        if (owner[i] == source && serial[i] == request_index) found = i;
      end
      if (found < 0) mismatch("request_order_or_payload");
      temporary = owner[position]; owner[position] = owner[found]; owner[found] = temporary;
      temporary = serial[position]; serial[position] = serial[found]; serial[found] = temporary;
      order_selected[position] = 1;
    end
  endtask

  task automatic observe;
    int s, q, b, delta;
    $display("OBS cycle=%0d rv=%h rr=%h dv=%h dr=%h ready=%b valid=%b req=%h data_ready=%b data_valid=%b data=%h accepted=%0d forwarded=%0d completed=%0d", cycle, rv, rr, dv, dr, ready, valid, out_req, data_ready, data_valid, out_data, accepted, forwarded, completed);
    if (previous_request_stall && (!valid || out_req !== stalled_req))
      mismatch("request_not_stable_under_stall");
    if (previous_data_stall && (!data_valid || out_data !== stalled_data))
      mismatch("data_not_stable_under_stall");
    previous_request_stall = valid && !ready;
    previous_data_stall = data_valid && !data_ready;
    if (previous_request_stall) request_stalls++;
    if (previous_data_stall) data_stalls++;
    if ($countones(rv) > 1) competing_cycles++;
    stalled_req = out_req;
    stalled_data = out_data;
    for (s = 0; s < N; s++) begin
      if (rv[s] && rr[s]) begin
        $display("ACCEPT source=%0d cycle=%0d request=%0d", s, cycle, sent[s]);
        owner[accepted] = s;
        serial[accepted] = sent[s];
        order_selected[accepted] = 0;
        accepted++;
        sent[s]++;
      end
      if (dv[s] && dr[s]) begin
        q = data_req[s];
        b = data_beat[s];
        data_accepted[s][q][b] = 1;
        if (b == beats(q)-1) begin data_req[s]++; data_beat[s] = 0; end
        else data_beat[s]++;
      end
    end
    if (valid && ready) begin
      if (forwarded >= accepted) mismatch("request_without_source_transfer");
      delta = int'(out_req.mem_req_addr[31:0]) - 'h3100;
      if (delta < 0 || delta >= N*32 || delta%32 >= REQUESTS)
        mismatch("request_order_or_payload");
      select_order(forwarded, delta/32, delta%32);
      if (forwarded == 0)
        $display("PRIORITY first_forwarded_source=%0d", owner[forwarded]);
      if (out_req !== request_payload(owner[forwarded], serial[forwarded]))
        mismatch("request_order_or_payload");
      forwarded++;
    end
    if (data_valid && data_ready) begin
      if (completed >= accepted) mismatch("data_without_request");
      delta = int'(out_data.mem_req_w_data[31:0]) - 'ha000;
      if (delta < 0 || delta >= N*256 || (delta%256)/4 >= REQUESTS)
        mismatch("data_owner_or_order");
      select_order(completed, delta/256, (delta%256)/4);
      s = owner[completed]; q = serial[completed]; b = output_beat;
      if (!data_accepted[s][q][b]) mismatch("data_without_source_transfer");
      if (out_data.mem_req_w_data !== data_payload(s,q,b)) mismatch("data_owner_or_order");
      if (out_data.mem_req_w_be !== byte_enable(s,q,b)) mismatch("byte_enable");
      if (out_data.mem_req_w_last !== (b == beats(q)-1)) mismatch("burst_last");
      data_accepted[s][q][b] = 0;
      data_transfers++;
      if (b == beats(q)-1) begin completed++; output_beat = 0; end
      else output_beat++;
    end
  endtask

  initial begin : run_test
    rv = 0; dv = 0; req = '0; data_in = '0; ready = 0; data_ready = 0;
    for (int s=0; s<N; s++) begin
      sent[s]=0; data_req[s]=0; data_beat[s]=0;
      for (int q=0; q<REQUESTS; q++) for (int b=0; b<3; b++) data_accepted[s][q][b]=0;
    end
    #4; clk=1; #1; clk=0; #4; clk=1; #1; clk=0; rst=1;
    for (cycle=0; cycle<600; cycle++) begin
      ready = (cycle % 17 >= 5);
      data_ready = (cycle % 23 >= 7);
      for (int s=0; s<N; s++) begin
        rv[s] = sent[s] < REQUESTS;
        req[s] = request_payload(s,sent[s]);
        dv[s] = data_req[s] < sent[s];
        data_in[s] = '{mem_req_w_data:data_payload(s,data_req[s],data_beat[s]),
          mem_req_w_be:byte_enable(s,data_req[s],data_beat[s]),
          mem_req_w_last:(data_beat[s] == beats(data_req[s])-1)};
      end
      #4; observe(); clk=1; #1; clk=0;
    end
    if (accepted != N*REQUESTS || forwarded != N*REQUESTS || completed != N*REQUESTS) begin
      $display("INCOMPLETE cycle_budget=600 accepted=%0d forwarded=%0d completed=%0d", accepted, forwarded, completed);
      $finish;
      disable run_test;
    end
    for (int s=0; s<N; s++) if (data_req[s] != REQUESTS) begin
      $display("INCOMPLETE source=%0d data_requests=%0d", s, data_req[s]);
      $finish;
      disable run_test;
    end
    $display("COVERAGE request_stalls=%0d data_stalls=%0d competing_cycles=%0d data_transfers=%0d", request_stalls, data_stalls, competing_cycles, data_transfers);
    $display("SUMMARY cycles=600 requests=24 bursts=24 errors=0");
    $display("WRITE_ARBITER_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
