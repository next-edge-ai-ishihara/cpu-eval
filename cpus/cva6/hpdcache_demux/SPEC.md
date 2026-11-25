# Implement `hpdcache_demux`

Implement the complete `hpdcache_demux` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_demux` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_demux
//  Parameters
//  {{{
#(
    //  Number of outputs
    parameter  int unsigned NOUTPUT     = 0,

    //  Width in bits of each input
    parameter  int unsigned DATA_WIDTH  = 0,

    //  Selector signal is one-hot encoded
    parameter  bit          ONE_HOT_SEL = 0,

    //  Compute the width of the selection signal
    localparam int unsigned NOUTPUT_LOG2 = $clog2(NOUTPUT),
    localparam int unsigned SEL_WIDTH    = ONE_HOT_SEL ? NOUTPUT : NOUTPUT_LOG2,

    localparam type data_t = logic [DATA_WIDTH-1:0],
    localparam type sel_t  = logic [SEL_WIDTH-1:0]
)
//  }}}

//  Ports
//  {{{
(
    input  data_t               data_i,
    input  sel_t                sel_i,
    output data_t [NOUTPUT-1:0] data_o
);
```

## Parent instantiation

### `rtl/src/utils/hpdcache_mem_resp_demux.sv`

```systemverilog
  typedef logic [$clog2(N)-1:0] sel_t;

  logic    [N-1:0] mem_resp_demux_valid;
  resp_t   [N-1:0] mem_resp_demux;
  logic    [N-1:0] mem_resp_demux_ready;
  sel_t            mem_resp_demux_sel;

  //  Route the response according to the response ID and the routing table
  assign mem_resp_demux_sel = mem_resp_rt_i[int'(mem_resp_id_i)];

  //  Forward the response to the corresponding output port
  hpdcache_demux #(
      .NOUTPUT        (N),
      .DATA_WIDTH     (1),
      .ONE_HOT_SEL    (0)
  ) i_resp_valid_demux (
      .data_i         (mem_resp_valid_i),
      .sel_i          (mem_resp_demux_sel),
      .data_o         (mem_resp_demux_valid)
  );

  hpdcache_demux #(
      .NOUTPUT        (N),
      .DATA_WIDTH     ($bits(resp_t)),
      .ONE_HOT_SEL    (0)
  ) i_resp_demux (
      .data_i         (mem_resp_i),
      .sel_i          (mem_resp_demux_sel),
      .data_o         (mem_resp_demux)
  );
// ...
  //  Pack/unpack responses
  generate
      for (genvar gen_i = 0; gen_i < int'(N); gen_i++) begin : pack_unpack_resp_gen
        assign mem_resp_valid_o      [gen_i] = mem_resp_demux_valid [gen_i];
        assign mem_resp_o            [gen_i] = mem_resp_demux       [gen_i];
        assign mem_resp_demux_ready  [gen_i] = mem_resp_ready_i     [gen_i];
      end
  endgenerate
```
