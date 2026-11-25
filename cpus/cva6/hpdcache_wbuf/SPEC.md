# Implement `hpdcache_wbuf`

Implement the complete `hpdcache_wbuf` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_wbuf` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
      WtDcacheWbufDepth: int'(8),

```

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
    userCfg.wbufDirEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.wbufDataEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.wbufWords = 1;
    userCfg.wbufTimecntWidth = 3;

```

### `core/cache_subsystem/cva6_hpdcache_wrapper.sv`

```systemverilog
      .wbuf_empty_o(wbuffer_empty_o),

      .cfg_enable_i                       (dcache_enable_i),
      .cfg_wbuf_threshold_i               (3'd2),
      .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
      .cfg_wbuf_sequential_waw_i          (1'b0),
      .cfg_wbuf_inhibit_write_coalescing_i(1'b0),

```

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    //  Definition of interface with memory
    //  {{{
    typedef logic [7:0]                           hpdcache_mem_len_t;
    typedef logic [2:0]                           hpdcache_mem_size_t;

    typedef enum logic [1:0] {
        HPDCACHE_MEM_RESP_OK  = 2'b00,
        HPDCACHE_MEM_RESP_NOK = 2'b01
    } hpdcache_mem_error_e;

    typedef enum logic [1:0] {
        HPDCACHE_MEM_READ     = 2'b00,
        HPDCACHE_MEM_WRITE    = 2'b01,
        HPDCACHE_MEM_ATOMIC   = 2'b10
        //  Reserved        = 2'b11 - TODO: CMO ?
    } hpdcache_mem_command_e;

    typedef enum logic [3:0] {
        HPDCACHE_MEM_ATOMIC_ADD  = 4'b0000,
        HPDCACHE_MEM_ATOMIC_CLR  = 4'b0001,
        HPDCACHE_MEM_ATOMIC_SET  = 4'b0010,
        HPDCACHE_MEM_ATOMIC_EOR  = 4'b0011,
        HPDCACHE_MEM_ATOMIC_SMAX = 4'b0100,
        HPDCACHE_MEM_ATOMIC_SMIN = 4'b0101,
        HPDCACHE_MEM_ATOMIC_UMAX = 4'b0110,
        HPDCACHE_MEM_ATOMIC_UMIN = 4'b0111,
        HPDCACHE_MEM_ATOMIC_SWAP = 4'b1000,
        //  Reserved           = 4'b1001,
        //  Reserved           = 4'b1010,
        //  Reserved           = 4'b1011,
        HPDCACHE_MEM_ATOMIC_LDEX = 4'b1100,
        HPDCACHE_MEM_ATOMIC_STEX = 4'b1101
        //  Reserved           = 4'b1110,
        //  Reserved           = 4'b1111
    } hpdcache_mem_atomic_e;

    function automatic hpdcache_mem_size_t get_hpdcache_mem_size(int unsigned bytes);
        if      (bytes ==   0) return 0;
        else if (bytes <=   2) return 1;
        else if (bytes <=   4) return 2;
        else if (bytes <=   8) return 3;
        else if (bytes <=  16) return 4;
        else if (bytes <=  32) return 5;
        else if (bytes <=  64) return 6;
        else if (bytes <= 128) return 7;
        else begin
`ifndef HPDCACHE_ASSERT_OFF
            assert (1) $error("hpdcache: unsupported number of bytes");
`endif
            return 0;
        end
    endfunction
    //  }}}
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
        int unsigned reqDataWidth;
        int unsigned reqDataBytes;
        int unsigned mshrSetWidth;
        int unsigned mshrWayWidth;
        int unsigned cbufEntryWidth;
        int unsigned wbufDataWidth;
        int unsigned wbufDirPtrWidth;
        int unsigned wbufDataPtrWidth;
        int unsigned accessWidth;
        int unsigned accessBytes;
    } hpdcache_cfg_t;

    function automatic hpdcache_cfg_t hpdcacheBuildConfig(input hpdcache_user_cfg_t p);
        hpdcache_cfg_t ret;

        ret.u = p;

        ret.clWidth = p.clWords * p.wordWidth;
        ret.clOffsetWidth = $clog2(ret.clWidth / 8);
        ret.clWordIdxWidth = $clog2(p.clWords);
        ret.wordByteIdxWidth = $clog2(p.wordWidth / 8);
        ret.wayIndexWidth = (p.ways > 1) ? $clog2(p.ways) : 1;
        ret.setWidth = $clog2(p.sets);
        ret.nlineWidth = p.paWidth - ret.clOffsetWidth;
        ret.tagWidth = ret.nlineWidth - ret.setWidth;
        ret.reqWordIdxWidth = $clog2(p.reqWords);
        ret.reqOffsetWidth = p.paWidth - ret.tagWidth;
        ret.reqDataWidth = p.reqWords * p.wordWidth;
        ret.reqDataBytes = ret.reqDataWidth/8;

        ret.mshrSetWidth = (p.mshrSets > 1) ? $clog2(p.mshrSets) : 1;
        ret.mshrWayWidth = (p.mshrWays > 1) ? $clog2(p.mshrWays) : 1;

        ret.cbufEntryWidth = (p.cbufEntries > 1) ? $clog2(p.cbufEntries) : 1;

        ret.wbufDataWidth = ret.reqDataWidth*p.wbufWords;
        ret.wbufDirPtrWidth = $clog2(p.wbufDirEntries);
        ret.wbufDataPtrWidth = $clog2(p.wbufDataEntries);

        ret.accessWidth = p.accessWords * p.wordWidth;
        ret.accessBytes = ret.accessWidth/8;

        return ret;
    endfunction

```

## Module declaration

```systemverilog
module hpdcache_wbuf
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type wbuf_addr_t = logic,
    parameter type wbuf_timecnt_t = logic,

    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,

    localparam int unsigned WBUF_WORD_WIDTH = HPDcacheCfg.u.reqWords*HPDcacheCfg.u.wordWidth,
    localparam type wbuf_data_t = logic [WBUF_WORD_WIDTH-1:0],
    localparam type wbuf_be_t = logic [WBUF_WORD_WIDTH/8-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    //  Clock and reset signals
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Global control signals
    output logic                  empty_o,
    output logic                  full_o,
    input  logic                  flush_all_i,

    //  Configuration signals
    //    Timer threshold
    input  wbuf_timecnt_t         cfg_threshold_i,
    //    Reset timer on write
    input  logic                  cfg_reset_timecnt_on_write_i,
    //    Sequentialize write-after-write hazards
    input  logic                  cfg_sequential_waw_i,
    //    Inhibit write coalescing
    input  logic                  cfg_inhibit_write_coalescing_i,

    //  Write interface
    input  logic                  write_i,
    output logic                  write_ready_o,
    input  wbuf_addr_t            write_addr_i,
    input  wbuf_data_t            write_data_i,
    input  wbuf_be_t              write_be_i,  // byte-enable
    input  logic                  write_uc_i,  // uncacheable write

    //  Read hit interface
    input  wbuf_addr_t            read_addr_i,
    output logic                  read_hit_o,
    input  logic                  read_flush_hit_i,

    //  Replay hit interface
    input  wbuf_addr_t            replay_addr_i,
    input  logic                  replay_is_read_i,
    output logic                  replay_open_hit_o,
    output logic                  replay_pend_hit_o,
    output logic                  replay_sent_hit_o,
    output logic                  replay_not_ready_o,

    //  Memory interface
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i
);

```

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
        hpdcache_wbuf #(
            .HPDcacheCfg                        (HPDcacheCfg),
            .wbuf_addr_t                        (wbuf_addr_t),
            .wbuf_timecnt_t                     (wbuf_timecnt_t),
            .hpdcache_mem_id_t                  (hpdcache_mem_id_t),
            .hpdcache_mem_req_t                 (hpdcache_mem_req_t),
            .hpdcache_mem_req_w_t               (hpdcache_mem_req_w_t),
            .hpdcache_mem_resp_w_t              (hpdcache_mem_resp_w_t)
        ) hpdcache_wbuf_i(
            .clk_i,
            .rst_ni,

            .empty_o                            (wbuf_empty_o),
            .full_o                             (/* unused */),
            .flush_all_i                        (wbuf_flush_all),

            .cfg_threshold_i                    (cfg_wbuf_threshold_i),
            .cfg_reset_timecnt_on_write_i       (cfg_wbuf_reset_timecnt_on_write_i),
            .cfg_sequential_waw_i               (cfg_wbuf_sequential_waw_i),
            .cfg_inhibit_write_coalescing_i     (cfg_wbuf_inhibit_write_coalescing_i),

            .write_i                            (wbuf_write),
            .write_ready_o                      (wbuf_write_ready),
            .write_addr_i                       (wbuf_write_addr),
            .write_data_i                       (wbuf_write_data),
            .write_be_i                         (wbuf_write_be),
            .write_uc_i                         (wbuf_write_uncacheable),

            .read_addr_i                        (wbuf_write_addr),
            .read_hit_o                         (wbuf_read_hit),
            .read_flush_hit_i                   (wbuf_read_flush_hit),

            .replay_addr_i                      (wbuf_rtab_addr),
            .replay_is_read_i                   (wbuf_rtab_is_read),
            .replay_open_hit_o                  (wbuf_rtab_hit_open),
            .replay_pend_hit_o                  (wbuf_rtab_hit_pend),
            .replay_sent_hit_o                  (wbuf_rtab_hit_sent),
            .replay_not_ready_o                 (wbuf_rtab_not_ready),

            .mem_req_write_ready_i              (mem_req_write_wbuf_ready),
            .mem_req_write_valid_o              (mem_req_write_wbuf_valid),
            .mem_req_write_o                    (mem_req_write_wbuf),

            .mem_req_write_data_ready_i         (mem_req_write_wbuf_data_ready),
            .mem_req_write_data_valid_o         (mem_req_write_wbuf_data_valid),
            .mem_req_write_data_o               (mem_req_write_wbuf_data),

            .mem_resp_write_ready_o             (mem_resp_write_wbuf_ready),
            .mem_resp_write_valid_i             (mem_resp_write_wbuf_valid),
            .mem_resp_write_i                   (mem_resp_write_wbuf)
        );

```

## Dependency declarations

### `rtl/include/hpdcache_typedef.svh`

```systemverilog
`define HPDCACHE_DECL_MEM_REQ_T(__addr_t, __id_t) \
    struct packed { \
        __addr_t                              mem_req_addr; \
        hpdcache_pkg::hpdcache_mem_len_t      mem_req_len; \
        hpdcache_pkg::hpdcache_mem_size_t     mem_req_size; \
        __id_t                                mem_req_id; \
        hpdcache_pkg::hpdcache_mem_command_e  mem_req_command; \
        hpdcache_pkg::hpdcache_mem_atomic_e   mem_req_atomic; \
        logic                                 mem_req_cacheable; \
    }

`define HPDCACHE_DECL_MEM_RESP_R_T(__id_t, __data_t) \
    struct packed { \
        hpdcache_pkg::hpdcache_mem_error_e    mem_resp_r_error; \
        __id_t                                mem_resp_r_id; \
        __data_t                              mem_resp_r_data; \
        logic                                 mem_resp_r_last; \
    }

`define HPDCACHE_DECL_MEM_REQ_W_T(__data_t, __be_t) \
    struct packed { \
        __data_t                              mem_req_w_data; \
        __be_t                                mem_req_w_be; \
        logic                                 mem_req_w_last; \
    }

`define HPDCACHE_DECL_MEM_RESP_W_T(__id_t) \
    struct packed { \
        logic                                 mem_resp_w_is_atomic; \
        hpdcache_pkg::hpdcache_mem_error_e    mem_resp_w_error; \
        __id_t                                mem_resp_w_id; \
    }

`define HPDCACHE_TYPEDEF_MEM_ATTR_T(__addr_t, __id_t, __data_t, __be_t, __params) \
    typedef logic [  __params.u.memAddrWidth-1:0] __addr_t; \
    typedef logic [    __params.u.memIdWidth-1:0] __id_t; \
    typedef logic [  __params.u.memDataWidth-1:0] __data_t; \
    typedef logic [__params.u.memDataWidth/8-1:0] __be_t

`define HPDCACHE_TYPEDEF_MEM_REQ_T(__name__, __addr_t, __id_t) \
    typedef `HPDCACHE_DECL_MEM_REQ_T(__addr_t, __id_t) __name__

`define HPDCACHE_TYPEDEF_MEM_RESP_R_T(__name__, __id_t, __data_t) \
    typedef `HPDCACHE_DECL_MEM_RESP_R_T(__id_t, __data_t) __name__

`define HPDCACHE_TYPEDEF_MEM_REQ_W_T(__name__, __data_t, __be_t) \
    typedef `HPDCACHE_DECL_MEM_REQ_W_T(__data_t, __be_t) __name__

`define HPDCACHE_TYPEDEF_MEM_RESP_W_T(__name__, __id_t) \
    typedef `HPDCACHE_DECL_MEM_RESP_W_T(__id_t) __name__

```

### `rtl/src/common/hpdcache_1hot_to_binary.sv`

```systemverilog
module hpdcache_1hot_to_binary
    //  Parameters
    //  {{{
#(
    parameter  int unsigned N     = 0,
    localparam int unsigned Log2N = N > 1 ? $clog2(N) : 1,
    localparam type in_t  = logic unsigned [N-1:0],
    localparam type out_t = logic unsigned [Log2N-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  in_t    val_i,
    output out_t   val_o
);

```

### `rtl/src/common/hpdcache_demux.sv`

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

### `rtl/src/common/hpdcache_fifo_reg.sv`

```systemverilog
module hpdcache_fifo_reg
    //  Parameters
    //  {{{
#(
    parameter int unsigned FIFO_DEPTH = 0,
    parameter bit FEEDTHROUGH = 1'b0,
    parameter type fifo_data_t = logic
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  w_i,
    output logic                  wok_o,
    input  fifo_data_t            wdata_i,
    input  logic                  r_i,
    output logic                  rok_o,
    output fifo_data_t            rdata_o
);

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

```

### `rtl/src/common/hpdcache_rrarb.sv`

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

### `docs/source/architecture.rst`

```text
   * - **2**
     - **Cacheable LOAD or PREFETCH, there is a miss on the cache, and there is
       a hit (cacheline granularity) on an opened, pending or sent entry of the
       WBUF**
     - When there is a read miss on an address, the cache controller needs to
       read from the memory the missing cacheline. As the NoC implements
       different physical channels for read and write requests, there is a race
       condition between the read miss and a pending write operation.  If the
       read miss arrives first to the memory, it would read the old data (which
       violates :ref:`sec_mcrs`). This blocking condition causes that the LOAD
       or PREFETCH will have a delay penalty of up to two transaction delays:
       one for the write to complete, then one for the read.

...

The following table briefly describes the possible dependencies between
memory requests. For each kind of dependency, there is a corresponding
bit in the "deps bits" field of RTAB entries.

.. list-table::
   :widths: 25 75
   :header-rows: 1

   * - **Dependency**
     - **Description**
   * - MSHR Hit
     - Read miss and there is an outstanding miss request on the target address
   * - MSHR Full
     - Read miss and the MSHR has no available way for the requested address
   * - MSHR Not Ready
     - Read miss and the MSHR is busy and cannot send the miss request
   * - WBUF Hit
     - Read miss and there is a match with an open, pending, or sent entry in
       the write buffer
   * - WBUF Not Ready
     - Write miss and there is a match with a sent entry in the write buffer or
       the write-buffer is full

...

This cache implements a write-through policy. In this policy, the write accesses
from requesters are systematically transferred to the memory, regardless of
whether the write access hits or misses in the HPDcache.

To decouple write acknowledgements from the memory to the HPDcache, and the
write acknowledgements from the HPDcache to the requester, the HPDcache
implements a write-buffer. The goal is to increase the performance: the
requester does not wait the acknowledgement from the memory, which may suffer
from a very high latency. In addition, the write-buffer implements coalescing of
write data to improve the bandwidth utilization of data channels in the NoC.

The write-buffer implements two different parts: directory and data. The
directory enables tracking of active writes. The data buffers are used to
coalesce writes from the requesters.

Write-Buffer Organization
'''''''''''''''''''''''''

The write-buffer implements two flip-flop arrays: one for the directory and
another for the data.

...

The write-buffer directory allows to track pending write transactions.

A given entry in the directory of the write-buffer may be in four
different states:

.. list-table::
   :widths: 15 85
   :header-rows: 1

   * - **State**
     - **Description**
   * - **FREE**
     - The entry is available
   * - **OPEN**
     - The entry is valid and contains pending write data. The entry accepts
       new writes (coalescing)
   * - **PEND**
     - The entry is waiting to be sent to the memory. In this state, the entry
       continues to accept new writes (coalescing).
   * - **SENT**
     - The entry was forwarded to the memory, and is waiting for the
       acknowledgement


Each entry contains the following additional information:

.. list-table::
   :widths: 5 15 80
   :header-rows: 1

   * - Field
     - Description
     - Width (in bits)
   * - S
     - State
     - 2
   * - T
     - Write-Buffer Tag
     - :math:`\mathsf{HPDCACHE\_PA\_WIDTH - HPDCACHE\_WBUF\_OFFSET\_WIDTH}`
   * - C
     - Live counter
     - :math:`\mathsf{HPDCACHE\_WBUF\_TIMECNT\_WIDTH}`
   * - P
     - Pointer to the associated data buffer
     - :math:`\mathsf{log_2(HPDCACHE\_WBUF\_DATA\_ENTRIES)}`


The number of entries in the directory array is:

   :math:`\mathsf{CONF\_HPDCACHE\_WBUF\_DIR\_ENTRIES}`


...


Write-Buffer Data
~~~~~~~~~~~~~~~~~~~~~~

The number of entries (depth) of the data array is:

   :math:`\mathsf{CONF\_HPDCACHE\_WBUF\_DATA\_ENTRIES}`

The width (in bits) of data entries is:

   :math:`\mathsf{CONF\_HPDCACHE\_WBUF\_WORDS{}\times{}HPDCACHE\_WORD\_WIDTH}`

Data buffers may be as wide or wider than the data interface of requesters:

   :math:`\mathsf{CONF\_HPDCACHE\_WBUF\_WORDS \ge CONF\_HPDCACHE\_REQ\_WORDS}`

Designer may choose data buffers to be wider than requesters' data interface to
improve the NoC bandwidth utilization. There is however a constraint: data
buffers' width cannot be wider than the NoC interface. Therefore:

.. math::

      \mathsf{CONF\_HPDCACHE\_WBUF\_WORDS{}\times{}HPDCACHE\_WORD\_WIDTH} \le\\
      \mathsf{CONF\_HPDCACHE\_MEM\_DATA\_WIDTH}

...

The HPDcache complies with the RVWMO memory consistency model. Regarding writes,
in this consistency model, there are two important properties:

#. The order in which write accesses on different addresses are forwarded to
   memory MAY differ from the order they arrived from the requester (program
   order);

#. Writes onto the same address, MUST be visible in order. If there is a data
   written by a write A on address @x followed by an another write B on the same
   address, the data of A cannot be visible after the processing of B.

The second property allows write coalescing if the hardware ensures that the
last write persists.

The write-buffer exploits the first property. Multiple “in-flight” writes are
supported due to the multiple directory and data entries. These write
transactions can be forwarded to the memory in an order different from the
program order.

To comply with the second property, the write-buffer does not accept a write
access when there is an address conflict with a **SENT** entry. In that case,
the write access is put on-hold as described in :ref:`sec_onhold`.

The system may choose to relax the constraint of putting a write on-hold in case
of an address conflict with a **SENT** entry. This can be relaxed when the NoC
guaranties in-order delivery. The runtime configuration bit
``cfig_wbuf.S`` (see :ref:`sec_csr`) shall be set to 0 to relax this
dependency.

...

When an entry of the write-buffer directory is in the **OPEN** or **PEND**
states, there is an allocated data buffer, and it contains data that has not yet
been sent to the memory. When an entry of the write-buffer directory is in the
**SENT** state, the corresponding data was transferred to the memory, and the
corresponding data buffer was freed (and can be reused for another write). A
given entry in the write-buffer directory goes from **FREE** to **OPEN** state
when a new write is accepted, and cannot be coalesced with another **OPEN** or
**PEND** entry (i.e. not in the same address range).

A directory entry passes from **OPEN** to **PEND** after a given number of clock
cycles. This number of clock cycles depends on different runtime configuration
values. Each directory entry contains a life-time counter. This counter starts
at 0 when a new write is accepted (**FREE** :math:`\rightarrow` **OPEN**), and
incremented each cycle while in **OPEN**. When the counter reaches
``cfig_wbuf.T`` (see :ref:`sec_csr`), the write-buffer directory
entry goes to **PEND**. Another runtime configurable bit,
``cfig_wbuf.R`` (see :ref:`sec_csr`), defines the behavior of an entry when a
new write is coalesced into an **OPEN** entry. If this last configuration bit is
set, the life-time counter is reset to 0 when a new write is coalesced.
Otherwise, the counter continues to increment normally.

The life-time of a given write-buffer directory entry is longer than the
life-time of a data entry. A given directory entry is freed
(**SENT** :math:`\rightarrow` **FREE**) when the write acknowledgement is
received from the memory. The number of cycles to get an acknowledgement from
the memory may be significant and it is system-dependent. Thus, to improve
utilization of data buffers, the number of entries in the directory is
generally greater than the number of data buffers.  There is a trade-off
between area and performance when choosing the depth of the data buffer. The
area cost of data buffers is the most critical cost in the write-buffer.  The
synthesis-time parameters
:math:`\mathsf{CONF\_HPDCACHE\_WBUF\_DIR\_ENTRIES}` and
:math:`\mathsf{CONF\_HPDCACHE\_WBUF\_DATA\_ENTRIES}` define the number of
entries in the write-buffer directory and write-buffer data, respectively.

When the ``cfig_wbuf.I`` (see :ref:`sec_csr`) is set, the write buffer does not
perform any write coalescing. This means that the entry passes from **FREE** to
**PEND** (bypassing the **OPEN** state).  While an entry is in the **PEND**
state, and ``cfig_wbuf.I`` is set, that entry does not accept any new writes. It
only waits for the data to be sent. The ``cfig_wbuf.T`` is ignored by the write
buffer when ``cfig_wbuf.I`` is set.

...

Fence instructions shall be forwarded to the cache to ensure ordering of writes.
The fence will force the write-buffer to send all pending writes before
accepting new ones. This cache implements two ways of signalling a fence:
sending a specific CMO instruction from the core (described later on
:ref:`sec_cmo`), or by asserting ``wbuf_flush_i`` pin (during one cycle).

```

### `docs/source/interface.rst`

```text
- **Memory Write Interfaces**

.. _tab_write_req_channel_signals:

.. list-table:: CMI Write Request Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_req_write_valid_o``
     - Cache
     - Indicates that the channel is signaling a valid request
   * - ``mem_req_write_ready_i``
     - NoC
     - Indicates that the cache is ready to accept a response
   * - ``mem_req_write_o.mem_req_addr``
     - Cache
     - Target physical address of the request
   * - ``mem_req_write_o.mem_req_len``
     - Cache
     - Indicates the number of transfers in a burst minus one
   * - ``mem_req_write_o.mem_req_size``
     - Cache
     - Indicate the size of the access. The size is encoded as the
       power-of-two of the number of bytes
   * - ``mem_req_write_o.mem_req_id``
     - Cache
     - The identification tag for the request. The HPDcache always use unique
       IDs on the memory interface (i.e. two or more in-flight requests cannot
       share the same ID).
   * - ``mem_req_write_o.mem_req_command``
     - Cache
     - Indicates the type of operation to be performed
   * - ``mem_req_write_o.mem_req_atomic``
     - Cache
     - In case of atomic operations, it indicates its type
   * - ``mem_req_write_o.mem_req_cacheable``
     - Cache
     - This is a hint for the cache hierarchy in the system. It indicates if
       the write is bufferable by the cache hierarchy. This means that the
       write must be visible in a timely manner at the final destination.
       However, write responses can be obtained from an intermediate point


.. _tab_write_data_channel_signals:

.. list-table:: CMI Write Data Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_req_write_data_valid_o``
     - Cache
     - Indicates that the channel is transferring a valid data
   * - ``mem_req_write_data_ready_i``
     - NoC
     - Indicates that the target is ready to accept the data
   * - ``mem_req_write_data_o.mem_req_w_data``
     - Cache
     - Request write data. It shall be naturally aligned to the request
       address
   * - ``mem_req_write_data_o.mem_req_w_be``
     - Cache
     - Request write byte-enable. It shall be naturally aligned to the request
       address
   * - ``mem_req_write_data_o.mem_req_w_last``
     - Cache
     - Indicates the last transfer in a write request burst


.. _tab_write_resp_channel_signals:

.. list-table:: CMI Write Response Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_resp_write_valid_i``
     - NoC
     - Indicates that the channel is transferring a valid write acknowledgement
   * - ``mem_resp_write_ready_o``
     - Cache
     - Indicates that the cache is ready to accept the acknowledgement
   * - ``mem_resp_write_i.mem_resp_w_is_atomic``
     - NoC
     - Indicates whether the atomic operation was successfully processed
       (atomically)
   * - ``mem_resp_write_i.mem_resp_w_error``
     - NoC
     - Indicates whether there was an error condition while processing the
       request
   * - ``mem_resp_write_i.mem_resp_w_id``
     - NoC
     - The identification tag for the request. It corresponds to the ID
       transferred with the request

...


Valid/Ready handshake process
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

All interfaces in the HPDcache use a **valid**/**ready** handshake process to
transfer a payload between the source and the destination. The payload contains
the address, data and control information.

As a reminder, the 7 interfaces in the HPDcache are the following:

#. CRI request interface
#. CRI response interface
#. CMI read request interface
#. CMI read response interface
#. CMI write request interface
#. CMI write data request interface
#. CMI write response interface

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

- **Transaction IDs in the CMI wbuf write request channel**

The HPDcache can have the following number of in-flight write transactions:

   :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_WBUF\_DIR\_ENTRIES}`

Each in-flight transaction has a unique transaction ID. This ID is formatted as
follows:

  - For cacheable requests:

   The ID corresponds to the index of the entry in the write-buffer directory.

   ``wbuf_dir_index``

```
