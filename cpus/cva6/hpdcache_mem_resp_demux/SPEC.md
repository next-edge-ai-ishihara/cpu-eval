# Implement `hpdcache_mem_resp_demux`

Implement the complete `hpdcache_mem_resp_demux` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mem_resp_demux` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : June, 2022
 *  Description   : Dcache Memory Response Demultiplexer
 *  History       :
 */
module hpdcache_mem_resp_demux
//  Parameters
//  {{{
#(
  parameter int         N  = 0,
  parameter type resp_t    = logic,
  parameter type resp_id_t = logic,

  localparam int RT_DEPTH  = (1 << $bits(resp_id_t)),
  localparam type rt_t     = resp_id_t [RT_DEPTH-1:0]
)
//  }}}

//  Ports
//  {{{
(
  input  logic           clk_i,
  input  logic           rst_ni,

  output logic           mem_resp_ready_o,
  input  logic           mem_resp_valid_i,
  input  resp_id_t       mem_resp_id_i,
  input  resp_t          mem_resp_i,

  input  logic           mem_resp_ready_i [N-1:0],
  output logic           mem_resp_valid_o [N-1:0],
  output resp_t          mem_resp_o       [N-1:0],

  input  rt_t            mem_resp_rt_i
);

```

## Parent instantiation

### `core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv`

```systemverilog
  //  Read response demultiplexor
  //  {{{
  logic                 mem_resp_read_ready;
  logic                 mem_resp_read_valid;
  hpdcache_mem_resp_r_t mem_resp_read;

  logic                 mem_resp_read_ready_arb[1:0];
  logic                 mem_resp_read_valid_arb[1:0];
  hpdcache_mem_resp_r_t mem_resp_read_arb      [1:0];

  mem_resp_rt_t         mem_resp_read_rt;

  always_comb begin
    for (int i = 0; i < MEM_RESP_RT_DEPTH; i++) begin
      mem_resp_read_rt[i] = (i == int'(icache_miss_id_i)) ? 0 : 1;
    end
  end

  hpdcache_mem_resp_demux #(
      .N        (2),
      .resp_t   (hpdcache_mem_resp_r_t),
      .resp_id_t(hpdcache_mem_id_t)
  ) i_mem_resp_read_demux (
      .clk_i,
      .rst_ni,

      .mem_resp_ready_o(mem_resp_read_ready),
      .mem_resp_valid_i(mem_resp_read_valid),
      .mem_resp_id_i   (mem_resp_read.mem_resp_r_id),
      .mem_resp_i      (mem_resp_read),

      .mem_resp_ready_i(mem_resp_read_ready_arb),
      .mem_resp_valid_o(mem_resp_read_valid_arb),
      .mem_resp_o      (mem_resp_read_arb),

      .mem_resp_rt_i(mem_resp_read_rt)
  );

  assign icache_miss_resp_w = mem_resp_read_valid_arb[0];
  assign icache_miss_resp_wdata = mem_resp_read_arb[0];
  assign mem_resp_read_ready_arb[0] = icache_miss_resp_wok;

  assign dcache_read_resp_valid_o = mem_resp_read_valid_arb[1];
  assign dcache_read_resp_o = mem_resp_read_arb[1];
  assign mem_resp_read_ready_arb[1] = dcache_read_resp_ready_i;

```

## Dependency declarations

### `rtl/src/common/hpdcache_demux.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Simple multiplexor
 *  History       :
 */
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
//  }}}

// ...

    end else begin : gen_bin_sel
        always_comb
        begin : demux_comb
            for (int unsigned i = 0; i < NOUTPUT; i++) begin
                data_o[i] = (sel_t'(i) == sel_i) ? data_i : '0;
            end
        end
    end

```

### `rtl/src/common/hpdcache_mux.sv`

```systemverilog
/*
 *  Author(s)     : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Simple multiplexor
 *  History       :
 */
module hpdcache_mux
    //  Parameters
    //  {{{
#(
    //  Number of inputs
    parameter  int unsigned NINPUT      = 0,

    //  Width in bits of each input
    parameter  int unsigned DATA_WIDTH  = 0,

    //  Selector signal is one-hot encoded
    parameter  bit          ONE_HOT_SEL = 0,

    //  Compute the width of the selection signal
    localparam int unsigned NINPUT_LOG2 = $clog2(NINPUT),
    localparam int unsigned SEL_WIDTH   = ONE_HOT_SEL ? NINPUT : NINPUT_LOG2,

    localparam type data_t = logic [DATA_WIDTH-1:0],
    localparam type sel_t  = logic [SEL_WIDTH-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  data_t [NINPUT-1:0] data_i,
    input  sel_t               sel_i,
    output data_t              data_o
);
    //  }}}

    typedef int unsigned uint32;

// ...

        //  Selector is binary encoded
        end else begin : gen_binary_sel
            always_comb
            begin : data_out_mux_comb
                data_o = '0;
                for (int unsigned i = 0; i < NINPUT; i++) begin
                    data_o |= (i == uint32'(sel_i)) ? data_i[i] : '0;
                end
            end
        end
    end
endmodule

```

## Documentation

### `docs/source/interface.rst`

```text
The source sets to 1 the **valid** signal to indicate when the payload is
available. The destination sets to 1 the **ready** signal to indicate that it
can accept that payload. Transfer occurs only when both the **valid** and
**ready** signals are set to 1 on the next rising edge of the clock.

A source is not permitted to wait until **ready** is set to 1 before setting
**valid** to 1.

A destination may or not wait for **valid** to set the **ready** to 1
(:numref:`cases (a) and (d) in Table %s <tab_ready_valid_scenarios>`).
In other words, a destination may set **ready** to 1 before an actual transfer
is available.

When **valid** is set to 1, the source must keep it that way until the
handshake occurs. This is, at the next rising edge when both **valid** and
**ready** (from the destination) are set to 1. In other words, a source cannot
retire a pending **valid** transfer
(:numref:`Case (b) in Table %s <tab_ready_valid_scenarios>`).

After an effective transfer (**valid** and **ready** set to 1), the source may
keep **valid** set to 1 in the next cycle to signal a new transfer (with a new
payload). In the same manner, the destination may keep **ready** set to 1 if it
can accept a new transfer. This allows back-to-back transfers, with no idle
cycles, between a source and a destination
(:numref:`Case (d) in Table %s <tab_ready_valid_scenarios>`).

All interfaces are synchronous to the rising edge of the same global
clock (``clk_i``).

```
