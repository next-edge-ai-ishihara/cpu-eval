# Implement `hpdcache_core_arbiter`

Implement the complete `hpdcache_core_arbiter` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_core_arbiter` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_core_arbiter
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Clock and reset signals
    input  logic                          clk_i,
    input  logic                          rst_ni,

    //      Core request interface
    //         1st cycle
    input  logic                          core_req_valid_i [HPDcacheCfg.u.nRequesters],
    output logic                          core_req_ready_o [HPDcacheCfg.u.nRequesters],
    input  hpdcache_req_t                 core_req_i       [HPDcacheCfg.u.nRequesters],
    //         2nd cycle
    input  logic                          core_req_abort_i [HPDcacheCfg.u.nRequesters],
    input  hpdcache_tag_t                 core_req_tag_i   [HPDcacheCfg.u.nRequesters],
    input  hpdcache_pma_t                 core_req_pma_i   [HPDcacheCfg.u.nRequesters],

    //      Core response interface
    input  logic                          core_rsp_valid_i,
    input  hpdcache_rsp_t                 core_rsp_i,
    output logic                          core_rsp_valid_o [HPDcacheCfg.u.nRequesters],
    output hpdcache_rsp_t                 core_rsp_o       [HPDcacheCfg.u.nRequesters],

    //      Granted request
    output logic                          arb_req_valid_o,
    input  logic                          arb_req_ready_i,
    output hpdcache_req_t                 arb_req_o,
    output logic                          arb_abort_o,
    output hpdcache_tag_t                 arb_tag_o,
    output hpdcache_pma_t                 arb_pma_o
);

```

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
    hpdcache_core_arbiter #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_tag_t                     (hpdcache_tag_t),
        .hpdcache_req_t                     (hpdcache_req_t),
        .hpdcache_rsp_t                     (hpdcache_rsp_t)
    ) core_req_arbiter_i (
        .clk_i,
        .rst_ni,

        .core_req_valid_i,
        .core_req_ready_o,
        .core_req_i,
        .core_req_abort_i,
        .core_req_tag_i,
        .core_req_pma_i,

        .core_rsp_valid_i                   (core_rsp_valid),
        .core_rsp_i                         (core_rsp),
        .core_rsp_valid_o,
        .core_rsp_o,

        .arb_req_valid_o                    (arb_req_valid),
        .arb_req_ready_i                    (arb_req_ready),
        .arb_req_o                          (arb_req),
        .arb_abort_o                        (arb_abort),
        .arb_tag_o                          (arb_tag),
        .arb_pma_o                          (arb_pma)
    );

```

## Dependency declarations

### `rtl/include/hpdcache_typedef.svh`

```systemverilog
`define HPDCACHE_DECL_RSP_T(__data_t, __sid_t, __tid_t) \
    struct packed { \
        __data_t rdata; \
        __sid_t  sid; \
        __tid_t  tid; \
        logic    error; \
        logic    aborted; \
    }

`define HPDCACHE_TYPEDEF_RSP_T(__name__, __data_t, __sid_t, __tid_t) \
    typedef `HPDCACHE_DECL_RSP_T(__data_t, __sid_t, __tid_t) __name__

```

### `rtl/src/common/hpdcache_fxarb.sv`

```systemverilog
module hpdcache_fxarb
    //  Parameters
    //  {{{
#(
    //    Number of requesters
    parameter int unsigned N = 0
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic [N-1:0]          req_i,
    output logic [N-1:0]          gnt_o,
    input  logic                  ready_i
);
    //  }}}

    //  Declaration of internal wires and registers
    //  {{{
    logic [N-1:0]       gnt_q, gnt;
    logic               wait_q;
    //  }}}

    //  Compute the grant vector
    //  {{{
    hpdcache_prio_1hot_encoder #(.N(N)) prio_msk_i (.val_i(req_i), .val_o(gnt));
    //  }}}

    //  Compute the output grant vector
    //  {{{
    assign gnt_o = wait_q ? gnt_q : gnt;
    //  }}}

    //  Setting of internal state
    //  {{{
    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni) begin
            wait_q <= 1'b0;
            gnt_q  <= '0;
        end else begin
            wait_q <= ~ready_i & (wait_q | (|req_i));
            if (!ready_i && !wait_q && (|req_i)) begin
                gnt_q <= gnt;
            end
        end
    end
    //  }}}

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
    gnt_at_most_one_requester: assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            $onehot0(gnt_o)) else $error("arbiter: granting more than one requester");
`endif
    //  }}}

endmodule

```

### `rtl/src/common/hpdcache_prio_1hot_encoder.sv`

```systemverilog
module hpdcache_prio_1hot_encoder
    //  Parameters
#(
    parameter int unsigned N = 0
)
    //  Ports
(
    input  logic [N-1:0] val_i,
    output logic [N-1:0] val_o
);

    assign val_o[0] = val_i[0];

    for (genvar i = 1; i < int'(N); i++) begin : gen_prio
        assign val_o[i] = val_i[i] & ~(|val_i[i-1:0]);
    end
endmodule

```

### `rtl/src/common/hpdcache_mux.sv`

```systemverilog
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

    if (NINPUT == 1) begin : gen_single_input
        assign data_o = data_i[0];

    end else begin : gen_multi_input
        //  Selector is one-hot encoded
        if (ONE_HOT_SEL == 1) begin : gen_onehot_sel
            always_comb
            begin : data_out_mux_comb
                data_o = '0;
                for (int unsigned i = 0; i < NINPUT; i++) begin
                    data_o |= sel_i[i] ? data_i[i] : '0;
                end
            end

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
.. list-table:: CRI Request Channel Signals
   :widths: 31 13 52
   :align: center
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``core_req_valid_i``
     - Requester
     - Indicates that the corresponding requester has a valid request
   * - ``core_req_ready_o``
     - Cache
     - Indicates that the cache is ready to accept a request from the
       corresponding requester
...
   * - ``core_req_tag_i``
     - Requester
     - Most significant bits of the target address of the request. This signal
       must be delayed of 1 cycle after
       ``(core_req_valid_i & core_req_ready_o) = 1``.
       It is valid when using virtual indexing
       (``core_req_i.phys_indexed = 0``)
...
.. _tab_resp_channel_signals:

.. list-table:: CRI Response Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``core_rsp_valid_o``
     - Cache
     - Indicates that the HPDcache has a valid response for the corresponding
       requester
   * - ``core_rsp_o.rdata``
     - Cache
     - Response read data
   * - ``core_rsp_o.sid``
     - Cache
     - The identification tag for the requester. It corresponds to the **sid**
       transferred with the request
   * - ``core_rsp_o.tid``
     - Cache
     - The identification tag for the request. It corresponds to the **tid**
       transferred with the request
   * - ``core_rsp_o.error``
     - Cache
     - Indicates whether there was an error condition while processing the
       request
   * - ``core_rsp_o.aborted``
     - Cache
     - Indicates if the request issued in the previous cycle shall be aborted.
       It is only considered if the previous request used virtual indexing
...
Source identifier
~~~~~~~~~~~~~~~~~

Each request identifies its source through the ``core_req_i.sid`` signal. The
``core_req_i.sid`` signal shall be decoded when the ``core_req_valid_i`` signal
is set to 1. The width of this signal is
:math:`\scriptsize\mathsf{CONF\_HPDCACHE\_REQ\_SRC\_ID\_WIDTH}` bits.
The HPDcache reflects the value of the **sid** of the request into the
corresponding **sid** of the response.

Each port must have a unique ID that corresponds to its number. Each port is
numbered from 0 to N-1. This number shall be constant for a given port
(requester). The HPDcache uses this information to route responses to the
correct requester.

```
