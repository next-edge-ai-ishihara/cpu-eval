# Implement `hwpf_stride`

Implement the complete `hwpf_stride` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hwpf_stride` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### rtl/src/hwpf_stride/hwpf_stride_pkg.sv

```systemverilog
package hwpf_stride_pkg;
    //  Base address configuration register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [63:6] base_cline;
            logic [5:3]  unused;
            logic        cycle;
            logic        rearm;
            logic        enable;
            } hwpf_stride_base_t;
    //  }}}

    //  Parameters configuration register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [63:48] nblocks;
            logic [47:32] nlines;
            logic [31:0]  stride;
            } hwpf_stride_param_t;
    //  }}}

    //  Throttle configuration register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [31:16] ninflight;
            logic [15:0]  nwait;
            } hwpf_stride_throttle_t;
```

### rtl/src/hpdcache_pkg.sv

```systemverilog
        HPDCACHE_REQ_CMO_FENCE             = 5'h10,
        HPDCACHE_REQ_CMO_PREFETCH          = 5'h11,
        HPDCACHE_REQ_CMO_INVAL_NLINE       = 5'h12,
// ...
    typedef struct packed {
        //  User configuration parameters
        hpdcache_user_cfg_t u;

        //  Internal parameters
        int unsigned clWidth;
        int unsigned clWordIdxWidth;
        int unsigned clOffsetWidth;
        int unsigned wordByteIdxWidth;
        int unsigned wayIndexWidth;
        int unsigned setWidth;
        int unsigned nlineWidth;
        int unsigned tagWidth;
        int unsigned reqWordIdxWidth;
        int unsigned reqOffsetWidth;
// ...
```

### rtl/include/hpdcache_typedef.svh

```systemverilog
`define HPDCACHE_DECL_REQ_T(__offset_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t) \
    struct packed { \
        __offset_t                        addr_offset; \
        __data_t                          wdata; \
        hpdcache_pkg::hpdcache_req_op_t   op; \
        __be_t                            be; \
        hpdcache_pkg::hpdcache_req_size_t size; \
        __sid_t                           sid; \
        __tid_t                           tid; \
        logic                             need_rsp; \
        logic                             phys_indexed; \
        __tag_t                           addr_tag; \
        hpdcache_pkg::hpdcache_pma_t      pma; \
    }

`define HPDCACHE_TYPEDEF_REQ_ATTR_T(__offset_t, __word_t, __word_be_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t, __params) \
    typedef logic       [         __params.tagWidth-1:0] __tag_t; \
    typedef logic       [      __params.u.wordWidth-1:0] __word_t; \
    typedef logic       [    __params.u.wordWidth/8-1:0] __word_be_t; \
    typedef logic       [   __params.reqOffsetWidth-1:0] __offset_t; \
    typedef __word_t    [       __params.u.reqWords-1:0] __data_t; \
    typedef __word_be_t [       __params.u.reqWords-1:0] __be_t; \
    typedef logic       [  __params.u.reqSrcIdWidth-1:0] __sid_t; \
    typedef logic       [__params.u.reqTransIdWidth-1:0] __tid_t

`define HPDCACHE_TYPEDEF_REQ_T(__name__, __offset_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t) \
    typedef `HPDCACHE_DECL_REQ_T(__offset_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t) __name__
```

## Module declaration

```systemverilog
module hwpf_stride
import hwpf_stride_pkg::*;
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                        clk_i,
    input  logic                        rst_ni,

    // CSR
    input  logic                        csr_base_set_i,
    input  hwpf_stride_base_t           csr_base_i,
    input  logic                        csr_param_set_i,
    input  hwpf_stride_param_t          csr_param_i,
    input  logic                        csr_throttle_set_i,
    input  hwpf_stride_throttle_t       csr_throttle_i,

    output hwpf_stride_base_t           csr_base_o,
    output hwpf_stride_param_t          csr_param_o,
    output hwpf_stride_throttle_t       csr_throttle_o,

    // If high, the prefetcher is enabled and active
    output logic                        busy_o,

    // Snooping
    //   Address to snoop on requests ports
    output hpdcache_nline_t             snoop_nline_o,
    //   If set to one, the snoop address matched one of the requests
    input  logic                        snoop_match_i,

    // D-Cache interface
    output logic                        hpdcache_req_valid_o,
    input  logic                        hpdcache_req_ready_i,
    output hpdcache_req_t               hpdcache_req_o,
    input  logic                        hpdcache_rsp_valid_i,
    input  hpdcache_rsp_t               hpdcache_rsp_i
);
```

## Parent instantiation

### rtl/src/hwpf_stride/hwpf_stride_wrapper.sv

```systemverilog
    for (genvar i = 0; i < NUM_HW_PREFETCH; i++) begin : gen_hwpf_stride
        assign hwpf_stride_enable[i] = hwpf_stride_base_o[i].enable;
// ...
        hwpf_stride #(
            .HPDcacheCfg          (HPDcacheCfg),
            .hpdcache_nline_t     (hpdcache_nline_t),
            .hpdcache_tag_t       (hpdcache_tag_t),
            .hpdcache_set_t       (hpdcache_set_t),
            .hpdcache_req_t       (hpdcache_req_t),
            .hpdcache_rsp_t       (hpdcache_rsp_t)
        ) hwpf_stride_i(
            .clk_i,
            .rst_ni,

            .csr_base_set_i       (hwpf_stride_base_set_i[i]),
            .csr_base_i           (hwpf_stride_base_i[i]),
            .csr_param_set_i      (hwpf_stride_param_set_i[i]),
            .csr_param_i          (hwpf_stride_param_i[i]),
            .csr_throttle_set_i   (hwpf_stride_throttle_set_i[i]),
            .csr_throttle_i       (hwpf_stride_throttle_i[i]),

            .csr_base_o           (hwpf_stride_base_o[i]),
            .csr_param_o          (hwpf_stride_param_o[i]),
            .csr_throttle_o       (hwpf_stride_throttle_o[i]),

            .busy_o               (hwpf_stride_status_busy[i]),

            .snoop_nline_o        (hwpf_snoop_nline[i]),
            .snoop_match_i        (hwpf_snoop_match[i]),

            .hpdcache_req_valid_o (hwpf_stride_req_valid[i]),
            .hpdcache_req_ready_i (hwpf_stride_req_ready[i]),
            .hpdcache_req_o       (hwpf_stride_req[i]),
            .hpdcache_rsp_valid_i (hwpf_stride_arb_in_rsp_valid[i]),
            .hpdcache_rsp_i       (hwpf_stride_arb_in_rsp[i])
        );

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
```

## Documentation

### docs/old/source/hpdcache_spec.tex

```text
Each engine, if activated, fetches a stream of cachelines.
A stream is defined as a sequence of prefetch requests.
An engine reads one or multiple blocks of a given number of cachelines.
The first block starts at a given base cacheline.
Between blocks, one can configure a given address offset (also known as the stride).

The four parameters (base cacheline, number of cachelines in a block, number of blocks, and the stride) of each stream (one per engine) are configured through dedicated \acp{CSR}.

\section{Triggering}

A given prefetcher engine starts operating when the following conditions are met:

\begin{enumerate}
\item Each engine implements an enable bit in its dedicated \acp{CSR}.
This enable bit shall be set to 1 to allow the triggering of a given prefetcher engine.

\item Each enabled engine (condition 1 is met), snoops on the requests ports from the requesters.
If there is a match between the issued address and the configured base cacheline of the engine, the engine starts the prefetching.

\end{enumerate}

Once an engine starts its operation, it does not snoop anymore the request ports.
At that moment, it issues a sequence of prefetch operations starting from $\mathsf{base\_cline}$, until the cacheline in the equation below.
When the last cacheline is reached, the behavior of the engine is described in the following section.

\begin{equation*}
    \mathsf{end\_cline = base\_cline + (Nblocks + 1)\times{}(Stride + 1)}
\end{equation*}

A prefetch operation behaves as a read in the cache, but no data is expected in response by the prefetcher.
This means, that prefetch operations do not need to enable the data array of the cache (thus reducing the energy consumption for this operation).
Prefetch operations only access cache directory memories to check if the requested cacheline is cached or if it needs to be fetched from the memory.
...
The prefetcher engines implement different automatic activation/deactivation policies:

\begin{tabular}{p{.3\linewidth}p{.65\linewidth}}
\toprule
\textbf{Policies}
& \\
\midrule
\textbf{Disarm when finished}
& When the engine completes the configured stream, it is automatically disabled.\\
\midrule

\textbf{Rearm when finished}
& When the prefetcher completes the configured stream, it does not disable.
However, it stops and waits to be triggered again.

At that point, the base cacheline \ac{CSR} of the engine saves the last accessed cacheline plus the stride.
This is, it saves the next address to prefetch.

The \acp{CSR} for the number of blocks, cachelines per block and stride keep their originally configured values.\\
\midrule

\textbf{Rearm and Cycle when finished}
& In this policy, the prefetch engine behaves as in the "Rearm when finished" policy, but the base cacheline \ac{CSR} is reset to the originally configured value.\\

\end{tabular}
...
\begin{description}

\item [\textsf{Stride} parameter] \mbox{}\\
It is an unsigned, one-based ($\mathsf{value + 1}$), 32-bits wide value.
The stride is in number of cachelines.
This means that the stride is always a multiple of $\mathsf{(HPDCACHE\_CL\_WIDTH/8)}$ bytes.

\item [\textsf{Nblocks} parameter] \mbox{}\\
It is an unsigned, one-based ($\mathsf{value + 1}$), 16-bits wide value.
This value corresponds to the number of blocks to prefetch.
The 16-bit value allows the prefetcher to prefetch up to 65536 blocks (of at least one cacheline).
This parameter is clearly over-dimensioned with respect to the usual capacity of the \ac{HPDcache} (e.g. 512, 64-byte, cachelines with a 32KB capacity).

\item [\textsf{Nlines} parameter] \mbox{}\\
It is an unsigned, one-based, 16-bits wide value.
It indicates the number of cachelines within blocks.
As the number of bits is 16, the maximum number of cachelines in a given block is 65536.

\item [\textsf{Nwait} parameter] \mbox{}\\
It is an unsigned, one-based, 16-bits wide value.
It defines the number of cycles (plus 1) between two requests of the prefetcher engine.
The zero value indicates that the engine can issue a request every cycle.

\item [\textsf{Ninflight} parameter] \mbox{}\\
It is an unsigned, zero-based, 16-bits wide value.
It defines the maximum number of in-flight (sent but not yet acknowledged) transactions from the prefetcher engine.
This parameter allows to throttle the memory bandwidth solicited by the prefetcher engine.
The zero value indicates that the number of in-flight transactions is unlimited.
...
\item [\textsf{C} bit] \mbox{}\\
This bit is only considered when the R bit (rearm) is also set.
When this cycle bit is set, after the prefetcher engine completes the prefetch stream, it resets the base cacheline to the originally configured one (see \secref{prefetch_activation_policies}).

\item [\textsf{R} bit] \mbox{}\\
When this rearm bit is set, after the prefetcher engine completes the prefetch stream, it "rearms" itself (remains enabled), and snoops for core requests (see \secref{prefetch_activation_policies}).
The address it snoops after it finishes depends on the Cycles (C) bit.
If the C bit is set, the behavior is described here above.
If the C bit is unset, after the prefetcher engine finishes, the snoop address is set to $\mathsf{end\_cline}$.

\end{description}
...
\section{Prefetch Request Algorithm}

\Algref{prefetch_issue} shows how a prefetch engine calculates the address to prefetch and the operation of the throttling mechanisms.

\begin{figure}[hptb]
\begin{lstlisting}[%
frame=single, language=c, numbers=left,%
basicstyle=\footnotesize]
const bit [63:0] LINES_PER_BLOCK = Nlines + 1;
const bit [63:0] BLOCK_INCREMENT = Stride + 1;
bit [63:0] block_nline;

// Iterates over the blocks of cachelines
block_nline = Base_cline;
for (nb = 0; nb < (Nblocks + 1); nb++)
  //  Iterates over the cachelines within each block.
  for (nl = 0; nl < LINES_PER_BLOCK; nl++) {
    //  Skip the first cacheline of the first block as it is already requested by the
    //  request triggering the prefetcher
    if ((nl == 0) && (nb == 0)) continue;

    if (Ninflight > 0) {
      //  Wait while the number of in-flight prefetch requests is equal to the configured
      //  threshold (Ninflight). This is a throttling mechanism.
      //  The inflight counter is decremented by another process each time the prefetcher
      //  receives an acknowledgement for an inflight request.
      while (inflight >= Ninflight) {
        wait (1); // cycles
      }
    }

    //  Send the prefetch operation for the calculated cacheline.
    //  Cachelines are contiguous within a block.
    prefetch_address((block_nline + nl)*64);

    //  The inflight counter is incremented each time the prefetcher sends a prefetch request.
    inflight++;

    //  Wait a given number of cycles between two prefetch requests.
    //  This is a throttling mechanism
    wait (Nwait + 1); // cycles
  }

  //  The first cacheline of a block is offset (defined by the Stride)
  //  with respect to the previous block.
  block_nline += BLOCK_INCREMENT;
}

//  If the cycle bit is not set, update the Base_cline with the
//  address that would follow the last accessed one.
if (!cfig.base_cline.c) {
  Base_cline = block_nline;
}
\end{lstlisting}
\caption{\alglabel{prefetch_issue}Request issuing algorithm of prefetch engines}
\end{figure}
...
\section{Prefetch Abort}

It is possible for the user to abort an active prefetch sequence from an engine.
To do that, the user can reset to 0 the $\mathsf{enable(E)}$ bit in the $\mathsf{base\_cline}$ \ac{CSR} register of the corresponding prefetcher engine.

Such action, makes the corresponding target engine to stop its current sequence of prefetch requests.
If there were inflight not-yet-acknowledge requests from that engine, it will wait for the corresponding acknowledgements.
During this time, the prefetcher engine is not usable, and its corresponding $\mathsf{busy}$ bit in the $\mathsf{Status}$ \ac{CSR} is kept set to 1.
While the $\mathsf{busy}$ bit is set to 1, any write in \ac{CSR} registers of that prefetcher engine has no effect on the engine behavior.
However, the modified \ac{CSR} registers will keep the written values.

When all acknowledgements are received, the corresponding prefetcher engine has its $\mathsf{busy}$ bit set to 0.
All other \ac{CSR} of the prefetcher engine keep their configured values.
At this point, the prefetcher engine is usable and can be reconfigured normally.
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
...
The requester shall send the tag and PMAs the next cycle after the
``core_req_valid_i`` and ``core_req_ready_o`` signals were set to 1 and the
``core_req_i.phys_indexed`` signal was set to 0.The number of bits of the
address offset (``addr_offset``) depends on the number of cache sets
(:math:`\scriptsize\mathsf{CONF\_HPDCACHE\_SETS}`) and the size of the cachelines
(:math:`\scriptsize\mathsf{CONF\_HPDCACHE\_CL\_WIDTH/8}`).
The address offset represents the concatenation of these two fields of the
address: the byte offset in the cacheline and the set index. Requests can be
sent back-to-back with no idle cycle in-between.

If requesters do not need virtual indexing, they can send the full address in
the first cycle by setting the ``core_req_i.phys_indexed`` bit to 1. The address
offset and the tag shall be sent through the ``core_req_i.addr_offset`` and
``core_req_i.addr_tag``, respectively. A given requester is free to alternate
between virtual and physical indexing on different clock cycles. Different
requesters can use different indexing schemes (virtual or physical).
```
