# Implement `hwpf_stride_arb`

Implement the complete `hwpf_stride_arb` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hwpf_stride_arb` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### rtl/include/hpdcache_typedef.svh

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

## Module declaration

```systemverilog
module hwpf_stride_arb
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter int NUM_HW_PREFETCH = 4,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                                clk_i,
    input  logic                                rst_ni,

    // Dcache input interface
    input  logic          [NUM_HW_PREFETCH-1:0] hwpf_stride_req_valid_i,
    output logic          [NUM_HW_PREFETCH-1:0] hwpf_stride_req_ready_o,
    input  hpdcache_req_t [NUM_HW_PREFETCH-1:0] hwpf_stride_req_i,
    output logic          [NUM_HW_PREFETCH-1:0] hwpf_stride_rsp_valid_o,
    output hpdcache_rsp_t [NUM_HW_PREFETCH-1:0] hwpf_stride_rsp_o,       // Not used

    // Dcache output interface
    output logic                                hpdcache_req_valid_o,
    input  logic                                hpdcache_req_ready_i,
    output hpdcache_req_t                       hpdcache_req_o,
    input  logic                                hpdcache_rsp_valid_i,
    input  hpdcache_rsp_t                       hpdcache_rsp_i           // Not used
);
```

## Parent instantiation

### rtl/src/hwpf_stride/hwpf_stride_wrapper.sv

```systemverilog
        assign hwpf_stride_req_ready[i]               = hwpf_stride_arb_in_req_ready[i],
               hwpf_stride_arb_in_req_valid[i]        = hwpf_stride_req_valid[i],
               hwpf_stride_arb_in_req[i].addr_offset  = hwpf_stride_req[i].addr_offset,
               hwpf_stride_arb_in_req[i].wdata        = hwpf_stride_req[i].wdata,
               hwpf_stride_arb_in_req[i].op           = hwpf_stride_req[i].op,
               hwpf_stride_arb_in_req[i].be           = hwpf_stride_req[i].be,
               hwpf_stride_arb_in_req[i].size         = hwpf_stride_req[i].size,
               hwpf_stride_arb_in_req[i].sid          = hpdcache_req_sid_i,
               hwpf_stride_arb_in_req[i].tid          = hpdcache_req_tid_t'(i),
               hwpf_stride_arb_in_req[i].need_rsp     = hwpf_stride_req[i].need_rsp,
               hwpf_stride_arb_in_req[i].phys_indexed = hwpf_stride_req[i].phys_indexed,
// ...
               hwpf_stride_arb_in_req[i].pma          = '0;
    end
    //  }}}

    //  Hardware prefetcher arbiter between engines
    //  {{{
    hwpf_stride_arb #(
        .NUM_HW_PREFETCH          (NUM_HW_PREFETCH),
        .hpdcache_req_t           (hpdcache_req_t),
        .hpdcache_rsp_t           (hpdcache_rsp_t)
    ) hwpf_stride_arb_i (
        .clk_i,
        .rst_ni,

        // DCache input interface
        .hwpf_stride_req_valid_i  (hwpf_stride_arb_in_req_valid),
        .hwpf_stride_req_ready_o  (hwpf_stride_arb_in_req_ready),
        .hwpf_stride_req_i        (hwpf_stride_arb_in_req),
        .hwpf_stride_rsp_valid_o  (hwpf_stride_arb_in_rsp_valid),
        .hwpf_stride_rsp_o        (hwpf_stride_arb_in_rsp),

        // DCache output interface
        .hpdcache_req_valid_o,
        .hpdcache_req_ready_i,
        .hpdcache_req_o,
        .hpdcache_rsp_valid_i,
        .hpdcache_rsp_i
    );
```

## Dependency declarations

### rtl/src/common/hpdcache_mux.sv

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
```

### rtl/src/common/hpdcache_rrarb.sv

```systemverilog
module hpdcache_rrarb
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
```

## Documentation

### docs/old/source/hpdcache_spec.tex

```text
The \ac{HPDcache} implements a prefetcher that contains multiple prefetch engines.
Each prefetch engine works independently, and simultaneously.
A round-robin arbiter at the output of the prefetcher allows to select one prefetch request from one of the engines per cycle.
This arbiter guarantees the correct behavior when multiple prefetch engines are active.
```

### docs/source/interface.rst

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

## Additional requirement

When `hpdcache_rsp_valid_i` is set, set `hwpf_stride_rsp_valid_o` only for the engine whose index equals `hpdcache_rsp_i.tid`.
