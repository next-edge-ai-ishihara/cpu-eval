# Implement `hwpf_stride_wrapper`

Implement the complete `hwpf_stride_wrapper` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hwpf_stride_wrapper` definition in a single SystemVerilog code
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
    //  }}}

    //  Status register of the hardware memory prefetcher
    //  {{{
    typedef struct packed {
            logic [63:48] unused1;
            logic [47:32] busy;
            logic         free;
            logic [30:20] unused0;
            logic [19:16] free_index;
            logic [15:0]  enabled;
            } hwpf_stride_status_t;
```

### rtl/src/hpdcache_pkg.sv

```systemverilog
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

## Module declaration

```systemverilog
module hwpf_stride_wrapper
import hwpf_stride_pkg::*;
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter int unsigned NUM_HW_PREFETCH = 4,
    parameter int unsigned NUM_SNOOP_PORTS = 1,

    //  Request Interface Definitions
    //  {{{
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
    //  }}}
)
//  }}}

//  Ports
//  {{{
(
    input  logic                                        clk_i,
    input  logic                                        rst_ni,

    //  CSR
    //  {{{
    input  logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_base_set_i,
    input  hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_i,
    output hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_o,

    input  logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_param_set_i,
    input  hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_i,
    output hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_o,

    input  logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_set_i,
    input  hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_i,
    output hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_o,

    output hwpf_stride_status_t                         hwpf_stride_status_o,
    //  }}}

    // Snooping
    //  {{{
    input  logic                 [NUM_SNOOP_PORTS-1:0]  snoop_valid_i,
    input  logic                 [NUM_SNOOP_PORTS-1:0]  snoop_abort_i,
    input  hpdcache_req_offset_t [NUM_SNOOP_PORTS-1:0]  snoop_addr_offset_i,
    input  hpdcache_tag_t        [NUM_SNOOP_PORTS-1:0]  snoop_addr_tag_i,
    input  logic                 [NUM_SNOOP_PORTS-1:0]  snoop_phys_indexed_i,
    //  }}}

    //  Dcache interface
    //  {{{
    input  hpdcache_req_sid_t                           hpdcache_req_sid_i,
    output logic                                        hpdcache_req_valid_o,
    input  logic                                        hpdcache_req_ready_i,
    output hpdcache_req_t                               hpdcache_req_o,
    output logic                                        hpdcache_req_abort_o,
    output hpdcache_tag_t                               hpdcache_req_tag_o,
    output hpdcache_pma_t                               hpdcache_req_pma_o,
    input  logic                                        hpdcache_rsp_valid_i,
    input  hpdcache_rsp_t                               hpdcache_rsp_i
    //  }}}
);
```

## Parent instantiation

### core/cache_subsystem/cva6_hpdcache_wrapper.sv

```systemverilog
  hwpf_stride_wrapper #(
      .HPDcacheCfg          (HPDcacheCfg),
      .NUM_HW_PREFETCH      (NrHwPrefetchers),
      .NUM_SNOOP_PORTS      (2),
      .hpdcache_tag_t       (hpdcache_tag_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_data_t  (hpdcache_req_data_t),
      .hpdcache_req_be_t    (hpdcache_req_be_t),
      .hpdcache_req_sid_t   (hpdcache_req_sid_t),
      .hpdcache_req_tid_t   (hpdcache_req_tid_t),
      .hpdcache_req_t       (hpdcache_req_t),
      .hpdcache_rsp_t       (hpdcache_rsp_t)
  ) i_hwpf_stride_wrapper (
      .clk_i,
      .rst_ni,

      .hwpf_stride_base_set_i    (hwpf_base_set_i),
      .hwpf_stride_base_i        (hwpf_base_i),
      .hwpf_stride_base_o        (hwpf_base_o),
      .hwpf_stride_param_set_i   (hwpf_param_set_i),
      .hwpf_stride_param_i       (hwpf_param_i),
      .hwpf_stride_param_o       (hwpf_param_o),
      .hwpf_stride_throttle_set_i(hwpf_throttle_set_i),
      .hwpf_stride_throttle_i    (hwpf_throttle_in),
      .hwpf_stride_throttle_o    (hwpf_throttle_out),
      .hwpf_stride_status_o      (hwpf_status_o),

      .snoop_valid_i       (snoop_valid),
      .snoop_abort_i       (snoop_abort),
      .snoop_addr_offset_i (snoop_addr_offset),
      .snoop_addr_tag_i    (snoop_addr_tag),
      .snoop_phys_indexed_i(snoop_phys_indexed),

      .hpdcache_req_sid_i(hpdcache_req_sid_t'(NumPorts)),

      .hpdcache_req_valid_o(dcache_req_valid[NumPorts]),
      .hpdcache_req_ready_i(dcache_req_ready[NumPorts]),
      .hpdcache_req_o      (dcache_req[NumPorts]),
      .hpdcache_req_abort_o(dcache_req_abort[NumPorts]),
      .hpdcache_req_tag_o  (dcache_req_tag[NumPorts]),
      .hpdcache_req_pma_o  (dcache_req_pma[NumPorts]),
      .hpdcache_rsp_valid_i(dcache_rsp_valid[NumPorts]),
      .hpdcache_rsp_i      (dcache_rsp[NumPorts])
  );
```

## Dependency declarations

### rtl/src/hwpf_stride/hwpf_stride.sv

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

### rtl/src/hwpf_stride/hwpf_stride_arb.sv

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

## Documentation

### docs/old/source/hpdcache_spec.tex

```text
The \ac{HPDcache} implements a prefetcher that contains multiple prefetch engines.
Each prefetch engine works independently, and simultaneously.
A round-robin arbiter at the output of the prefetcher allows to select one prefetch request from one of the engines per cycle.
This arbiter guarantees the correct behavior when multiple prefetch engines are active.
...
A given prefetcher engine starts operating when the following conditions are met:

\begin{enumerate}
\item Each engine implements an enable bit in its dedicated \acp{CSR}.
This enable bit shall be set to 1 to allow the triggering of a given prefetcher engine.

\item Each enabled engine (condition 1 is met), snoops on the requests ports from the requesters.
If there is a match between the issued address and the configured base cacheline of the engine, the engine starts the prefetching.

\end{enumerate}
...
There is also a global status register for the prefetcher to monitor the status of the different prefetcher engines:

\begin{itemize}
  \item Status register

    \begin{bytefield}[endianness=big,bitwidth=\linewidth/16,%
      boxformatting={\centering\footnotesize\sf}]{16}
      \bitheader[lsb=48]{48,63} \\
        \bitbox{16}{\color{lightgray}\rule{\width}{\height}} &%
        \\[.5em]%
      \bitheader[lsb=32]{32,33,34,35,36,47} \\
        \bitbox{12}{\color{lightgray}\rule{\width}{\height}} &%
        \bitbox{1}{P3 busy} &%
        \bitbox{1}{P2 busy} &%
        \bitbox{1}{P1 busy} &%
        \bitbox{1}{P0 busy}%
        \\[.5em]%
      \bitheader[lsb=16]{16,19,20,30,31} \\
        \bitbox{1}{Free} &%
        \bitbox{11}{\color{lightgray}\rule{\width}{\height}} &%
        \bitbox{4}{Free Index} &%
        \\[.5em]%
      \bitheader[lsb=0]{0,1,2,3,4,15} \\
        \bitbox{12}{\color{lightgray}\rule{\width}{\height}} &%
        \bitbox{1}{P3 en} &%
        \bitbox{1}{P2 en} &%
        \bitbox{1}{P1 en} &%
        \bitbox{1}{P0 en}%
    \end{bytefield}
\end{itemize}

\begin{description}
  \item [\textsf{P0-P3~enable bits}] \mbox{}\\
    Indicate if the corresponding prefetcher is enabled.

  \item [\textsf{Free~index bits}] \mbox{}\\
      Indicate the index (decimal) of the first available prefetcher from 0 to 3.
      The software can use this information to easily compute the address offset of the configuration registers of the target prefetcher engine.

  \item [\textsf{Free bit}] \mbox{}\\
    It is set when the \emph{Free Index} is valid, this is, when there is effectively a free prefetcher.

  \item [\textsf{P0-P3~busy bits}] \mbox{}\\
    Indicate if the corresponding prefetcher is busy (it is enabled and active).

\end{description}
```

### docs/source/interface.rst

```text
The HPDcache allows the address and physical memory attributes (PMA) to be sent
by the requesters in two different (but consecutive) cycles.

This is useful to allow the pipelining of the address translation mechanism
(when the core has one). This is illustrated in
:numref:`Figure %s <fig_vipt>`.
Doing the translation and directly forwarding to the cache is usually too
costly in terms of timing. Instead, the requesters can:

.. list-table::
   :widths: 15 85
   :header-rows: 0

   * - Cycle 0
     - During the first cycle, forward the least significant bits of the
       address (``addr_offset``), which usually do not need to be translated,
       along with the other fields of the request (operation, identifiers,
       etc). In the meanwhile the core can perform the translation of the
       address to compute the most significant bits (``addr_tag``)

   * - Cycle 1
     - During the second cycle, forward the previously translated most
       significant bits of the address (``addr_tag``), and the corresponding
       PMAs. PMAs are sent during this second cycle because usually they depend
       on the target physical address. The requester can abort the request
       during this cycle as explained in the next section (:ref:`sec_req_abort`).

.. _fig_vipt:

.. figure:: images/hpdcache_vipt.*
   :align: center
   :width: 80%
   :alt: Pipelining of the Virtual and Physical Part of the Address

   Pipelining of the Virtual and Physical Part of the Address

This kind of indexing is named **Virtually-Indexed Physically-Tagged (VIPT)**.

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
