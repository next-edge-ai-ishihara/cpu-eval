# Implement `hpdcache_uncached`

Implement the complete `hpdcache_uncached` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_uncached` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    function automatic logic is_load(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_LOAD: return 1'b1;
            default:           return 1'b0;
        endcase
    endfunction

    function automatic logic is_store(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_STORE: return 1'b1;
            default:            return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_LR,
            HPDCACHE_REQ_AMO_SC,
            HPDCACHE_REQ_AMO_SWAP,
            HPDCACHE_REQ_AMO_ADD,
            HPDCACHE_REQ_AMO_AND,
            HPDCACHE_REQ_AMO_OR,
            HPDCACHE_REQ_AMO_XOR,
            HPDCACHE_REQ_AMO_MAX,
            HPDCACHE_REQ_AMO_MAXU,
            HPDCACHE_REQ_AMO_MIN,
            HPDCACHE_REQ_AMO_MINU:
                return 1'b1;
            default:
                return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_lr(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_LR: return 1'b1;
            default:             return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_sc(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_SC: return 1'b1;
            default:             return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_swap(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_SWAP: return 1'b1;
            default:               return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_add(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_ADD: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_and(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_AND: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_or(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_OR:  return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_xor(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_XOR: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_max(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MAX: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_maxu(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MAXU: return 1'b1;
            default:               return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_min(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MIN: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_minu(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MINU: return 1'b1;
            default:               return 1'b0;
        endcase
    endfunction

    function automatic logic is_cmo_inval(input hpdcache_req_op_t op);
        return (op inside {HPDCACHE_REQ_CMO_INVAL_NLINE, HPDCACHE_REQ_CMO_INVAL_ALL});
    endfunction

    function automatic logic is_cmo_flush(input hpdcache_req_op_t op);
        return (op inside {HPDCACHE_REQ_CMO_FLUSH_NLINE,
                           HPDCACHE_REQ_CMO_FLUSH_ALL,
                           HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE,
                           HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL});
    endfunction

    function automatic logic is_cmo_fence(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FENCE);
    endfunction

    function automatic logic is_cmo_prefetch(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_PREFETCH);
    endfunction

    function automatic logic is_cmo_inval_by_nline(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_INVAL_NLINE);
    endfunction

    function automatic logic is_cmo_inval_all(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_INVAL_ALL);
    endfunction

    function automatic logic is_cmo_flush_by_nline(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_NLINE);
    endfunction

    function automatic logic is_cmo_flush_all(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_ALL);
    endfunction

    function automatic logic is_cmo_flush_inval_by_nline(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE);
    endfunction

    function automatic logic is_cmo_flush_inval_all(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL);
    endfunction

    function automatic logic is_cmo(input hpdcache_req_op_t op);
        return (is_cmo_flush(op) ||
                is_cmo_fence(op) ||
                is_cmo_inval(op) ||
                is_cmo_prefetch(op));
    endfunction
// ...
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

    //  Definition of constants and types for the uncacheable request handler (UC)
    //  {{{
    typedef struct packed {
        logic is_ld;
        logic is_st;
        logic is_amo_lr;
        logic is_amo_sc;
        logic is_amo_swap;
        logic is_amo_add;
        logic is_amo_and;
        logic is_amo_or;
        logic is_amo_xor;
        logic is_amo_max;
        logic is_amo_maxu;
        logic is_amo_min;
        logic is_amo_minu;
    } hpdcache_uc_op_t;
    //  }}}
// ...
    typedef struct packed {
        //  Number of requesters
        int unsigned nRequesters;
        //  Physical Address Width
        int unsigned paWidth;
        //  Word width (bits)
        int unsigned wordWidth;
        //  Number of sets
        int unsigned sets;
        //  Number of ways
        int unsigned ways;
        //  Cache-Line width (words)
        int unsigned clWords;
        //  Number of words in the request data channels (request and response)
        int unsigned reqWords;
        //  Request transaction ID width (bits)
        int unsigned reqTransIdWidth;
        //  Request source ID width (bits)
        int unsigned reqSrcIdWidth;
// ...
        //  Width of the address in the memory interface
        int unsigned memAddrWidth;
        //  Width of the ID in the memory interface
        int unsigned memIdWidth;
        //  Width of the data in the memory interface
        int unsigned memDataWidth;
        //  Enable support for the write-through policy
        bit wtEn;
        //  Enable support for the write-back policy
        bit wbEn;
        //  Enable fast loads.
        //  Perform loads in 1 cycle at the cost of structural hazard for stores
        bit lowLatency;
        //  Enable ECC in cache SRAMs
        bit eccEn;
        //  Enable error correction scrubber
        bit eccScrubberEn;
    } hpdcache_user_cfg_t;
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

```

## Module declaration

```systemverilog
module hpdcache_uncached
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_offset_t = logic,
    parameter type hpdcache_word_t = logic,

    parameter type hpdcache_req_addr_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_way_vector_t = logic,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Cache-side request interface
    //  {{{
    input  logic                  req_valid_i,
    output logic                  req_ready_o,
    input  hpdcache_uc_op_t       req_op_i,
    input  hpdcache_req_addr_t    req_addr_i,
    input  hpdcache_req_size_t    req_size_i,
    input  hpdcache_req_data_t    req_data_i,
    input  hpdcache_req_be_t      req_be_i,
    input  logic                  req_uc_i,
    input  hpdcache_req_sid_t     req_sid_i,
    input  hpdcache_req_tid_t     req_tid_i,
    input  logic                  req_need_rsp_i,
    input  hpdcache_way_vector_t  req_hit_way_i,
    input  hpdcache_req_data_t    req_old_data_i,
    //  }}}

    //  AMO Cache Interface
    //  {{{
    output logic                  data_amo_write_o,
    output logic                  data_amo_write_enable_o,
    output hpdcache_set_t         data_amo_write_set_o,
    output hpdcache_req_size_t    data_amo_write_size_o,
    output hpdcache_word_t        data_amo_write_word_o,
    output hpdcache_way_vector_t  data_amo_write_way_o,
    output hpdcache_req_data_t    data_amo_write_data_o,
    output hpdcache_req_be_t      data_amo_write_be_o,
    // }}}

    //  LR/SC reservation buffer
    //  {{{
    input  logic                  lrsc_snoop_i,
    input  hpdcache_req_addr_t    lrsc_snoop_addr_i,
    input  hpdcache_req_size_t    lrsc_snoop_size_i,
    //  }}}

    //  Core response interface
    //  {{{
    input  logic                  core_rsp_ready_i,
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,
    //  }}}

    //  MEMORY interfaces
    //  {{{
    //      Memory request unique identifier
    input  hpdcache_mem_id_t      mem_read_id_i,
    input  hpdcache_mem_id_t      mem_write_id_i,

    //      Read interface
    input  logic                  mem_req_read_ready_i,
    output logic                  mem_req_read_valid_o,
    output hpdcache_mem_req_t     mem_req_read_o,

    output logic                  mem_resp_read_ready_o,
    input  logic                  mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t  mem_resp_read_i,

    //      Write interface
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i,
    //  }}}

    //  Configuration interface
    //  {{{
    input  logic                  cfg_error_on_cacheable_amo_i
    //  }}}
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
// ...
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

### `rtl/src/hpdcache_amo.sv`

```systemverilog
module hpdcache_amo
import hpdcache_pkg::*;
//  Ports
//  {{{
(
    input  logic [63:0]           ld_data_i,
    input  logic [63:0]           st_data_i,
    input  hpdcache_uc_op_t       op_i,
    output logic [63:0]           result_o
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

## Documentation

### `docs/source/architecture.rst`

```text
Uncacheable Handler
-------------------

This block is responsible for processing uncacheable load and store requests
(see :ref:`sec_req_cacheability`), as well as atomic requests (regardless of
whether they are cacheable or not). For more information about atomic requests
see :ref:`sec_amo`.

If :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_SUPPORT\_AMO}` is set to 0, the
HPDcache does not support AMOs from requesters. In this case, the AMO has no
effect and the Uncacheable Handler responds with an error to the corresponding
requester (when ``core_req_i.need_rsp`` is set to 1). If ``core_req_i.need_rsp``
is set to 0, the Uncacheable Handler ignores the AMO.

All requests handled by this block produce a request to the memory. These
requests to the memory are issued through the CMI interfaces. Uncacheable read
requests are forwarded to the memory through the CMI read. Uncacheable write
requests or atomic requests are forwarded through the CMI write.


```

### `docs/source/interface.rst`

```text
The address (``core_req_i.addr_offset``), size (``core_req_i.size``),
byte-enable (``core_req_i.be``), write data (``core_req_i.wdata``) and
read data (``core_rsp_o.rdata``) signals shall comply with the alignment
constraints defined in section
:ref:`Address, data, and byte enable alignment <sec_req_alignment>`.

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

.. _sec_req_alignment:

Address, data and byte enable alignment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Address alignment
'''''''''''''''''

The address transferred (**addr**) in all request interfaces (CRI and CMI)
shall be byte-aligned to the value of the corresponding **size** signal in that
interface.

Some examples are illustrated in
:numref:`Figure %s <fig_request_data_alignment>`. In the first case, the
**size** value is 2 (which corresponds to :math:`\scriptsize\mathsf{2^2=4}` bytes).
Thus, the address must be a multiple of 4; In the second case, **size** value
is 3. Thus, the address must be a multiple of 8. Finally, in the third case,
**size** value is 0. Thus, there is no constraint on the address alignment.

Data alignment
''''''''''''''

The data must be naturally aligned to the address (**addr**) and the maximum
valid bytes of the transfer must be equal to :math:`\scriptsize\mathsf{2^{size}}`.
This means that the first valid byte in the **data** signal must be at the
indicated offset of the address. Here, the offset corresponds to the least
significant bits of the address, that allow to indicate a byte within the
**data** word. For example, if the **data** signal is 128 bits wide (16
bytes), then the offset corresponds to the first 4 bits of the **addr** signal.

Some examples are illustrated in
:numref:`Figure %s <fig_request_data_alignment>`. As illustrated, within the
data word, only bytes in the range from the indicated offset in the address, to
that offset plus :math:`\scriptsize\mathsf{2^{size}}` can contain valid data. Other bytes must
be ignored by the destination.

Additionally, within the range described above, the **be** signal indicates
which bytes within that range are actually valid. Bytes in the **data**
signal where the **be** signals are set to 0, must be ignored by the
destination.

Byte Enable (BE) alignment
''''''''''''''''''''''''''

The **be** signal must be naturally aligned to the address (**addr**) and the
number of bits set in this signal must be less or equal to
:math:`\scriptsize\mathsf{2^\text{size}}`. This means that the first valid bit in the
**be** signal must be at the indicated offset of the address. The offset is
the same as the one explained above in the "Data alignment" paragraph.

Some examples are illustrated in
:numref:`Figure %s <fig_request_data_alignment>`. As illustrated, within the
**be** word, only bits in the range from the indicated offset in the address,
to that offset plus :math:`\scriptsize\mathsf{2^{size}}` can be set. Other bits
outside that range must be set to 0.

...

CRI Type of Operation
~~~~~~~~~~~~~~~~~~~~~

A requester indicates the required operation on the 5-bit, ``HPDCACHE_REQ_OP``
signal. The supported operation are detailed in :numref:`tab_req_op_types`.

.. _tab_req_op_types:

.. list-table:: Requesters Operation Types
   :widths: 30 15 55
   :header-rows: 1

   * - Mnemonic
     - Encoding
     - Type
   * - ``HPDCACHE_REQ_LOAD``
     - 0b00000
     - Read operation
   * - ``HPDCACHE_REQ_STORE``
     - 0b00001
     - Write operation
   * - ``HPDCACHE_REQ_AMO_LR``
     - 0b00100
     - Atomic Load-reserved operation
   * - ``HPDCACHE_REQ_AMO_SC``
     - 0b00101
     - Atomic Store-conditional operation
   * - ``HPDCACHE_REQ_AMO_SWAP``
     - 0b00110
     - Atomic SWAP operation
   * - ``HPDCACHE_REQ_AMO_ADD``
     - 0b00111
     - Atomic integer ADD operation
   * - ``HPDCACHE_REQ_AMO_AND``
     - 0b01000
     - Atomic bitwise AND operation
   * - ``HPDCACHE_REQ_AMO_OR``
     - 0b01001
     - Atomic bitwise OR operation
   * - ``HPDCACHE_REQ_AMO_XOR``
     - 0b01010
     - Atomic bitwise XOR operation
   * - ``HPDCACHE_REQ_AMO_MAX``
     - 0b01011
     - Atomic integer signed MAX operation
   * - ``HPDCACHE_REQ_AMO_MAXU``
     - 0b01100
     - Atomic integer unsigned MAX operation
   * - ``HPDCACHE_REQ_AMO_MIN``
     - 0b01101
     - Atomic integer signed MIN operation
   * - ``HPDCACHE_REQ_AMO_MINU``
     - 0b01110
     - Atomic integer unsigned MIN operation

...

Need response
~~~~~~~~~~~~~

For any given request, a requester can set the bit ``core_req_i.need_rsp`` to 0
to indicate that it does not want a response for that request. The
``core_req_i.need_rsp`` signal shall be decoded when the ``core_req_valid_i``
signal is set to 1.

When ``core_req_i.need_rsp`` is set to 0, the HPDcache processes the request
but it does not send an acknowledgement to the corresponding requester when the
transaction is completed.

...

Error response
~~~~~~~~~~~~~~

The response interface contains a single-bit ``core_rsp_o.error`` signal.  This
signal is set to 1 by the HPDcache when some error condition occurred during the
processing of the corresponding request. The ``core_rsp_o.error`` signal shall
be decoded when the ``core_rsp_valid_o`` signal is set to 1.

When the ``core_rsp_o.error`` signal is set to 1 in the response, the effect of
the corresponding request is undefined. If this **error** signal is set in the
case of **LOAD** or **AMOs** operations, the **rdata** signal does not contain
any valid data.

...

CMI Type of operation
~~~~~~~~~~~~~~~~~~~~~

.. list-table:: Memory request operation types
   :widths: 35 15 50
   :header-rows: 1

   * - Mnemonic
     - Encoding
     - Type
   * - ``HPDCACHE_MEM_READ``
     - 0b00
     - Read operation
   * - ``HPDCACHE_MEM_WRITE``
     - 0b01
     - Write operation
   * - ``HPDCACHE_MEM_ATOMIC``
     - 0b10
     - Atomic operation

``HPDCACHE_MEM_READ`` and ``HPDCACHE_MEM_WRITE`` are respectively normal read
and write operations from/to the specified address.

In case of an atomic operation request (``HPDCACHE_MEM_ATOMIC``), the specific
operation is specified in the ``MEM_REQ_ATOMIC`` signal. These operations are
listed in :numref:`tab_mem_req_atomics_types`. Note that these
operations are compatible with the ones defined in the AMBA AXI protocol.

.. _tab_mem_req_atomics_types:

.. list-table:: Memory request atomic operation types
   :widths: 35 15 50
   :header-rows: 1

   * - Mnemonic
     - Encoding
     - Type
   * - ``HPDCACHE_MEM_ATOMIC_ADD``
     - 0b0000
     - Atomic fetch-and-add operation
   * - ``HPDCACHE_MEM_ATOMIC_CLR``
     - 0b0001
     - Atomic fetch-and-clear operation
   * - ``HPDCACHE_MEM_ATOMIC_SET``
     - 0b0010
     - Atomic fetch-and-set operation
   * - ``HPDCACHE_MEM_ATOMIC_EOR``
     - 0b0011
     - Atomic fetch-and-exclusive-or operation
   * - ``HPDCACHE_MEM_ATOMIC_SMAX``
     - 0b0100
     - Atomic fetch-and-maximum (signed) operation
   * - ``HPDCACHE_MEM_ATOMIC_SMIN``
     - 0b0101
     - Atomic fetch-and-minimum (signed) operation
   * - ``HPDCACHE_MEM_ATOMIC_UMAX``
     - 0b0110
     - Atomic fetch-and-maximum (unsigned) operation
   * - ``HPDCACHE_MEM_ATOMIC_UMIN``
     - 0b0111
     - Atomic fetch-and-minimum (unsigned) operation
   * - ``HPDCACHE_MEM_ATOMIC_SWAP``
     - 0b1000
     - Atomic swap operation
   * - ``HPDCACHE_MEM_ATOMIC_LDEX``
     - 0b1100
     - Load-exclusive operation
   * - ``HPDCACHE_MEM_ATOMIC_STEX``
     - 0b1101
     - Store-exclusive operation


Type of operation per CMI request channel
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As a reminder, the HPDcache implements two request channels to the memory:

#. Memory read request channel
#. Memory write request channel

:numref:`tab_optypes_by_cmi_req_channel` indicates the type of
operations that each of these two request channels can issue.

.. _tab_optypes_by_cmi_req_channel:

.. list-table:: Operation Types Supported by CMI Request Channels
   :widths: 30 50
   :header-rows: 1

   * - Type
     - Channels
   * - ``HPDCACHE_MEM_READ``
     - - CMI read request
   * - ``HPDCACHE_MEM_WRITE``
     - - CMI write request
   * - ``HPDCACHE_MEM_ATOMIC``
     - - CMI write request


Read-Modify-Write Atomic Operations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The following atomic operations behave as read-modify-write operations:

- ``HPDCACHE_MEM_ATOMIC_ADD``
- ``HPDCACHE_MEM_ATOMIC_CLR``
- ``HPDCACHE_MEM_ATOMIC_SET``
- ``HPDCACHE_MEM_ATOMIC_EOR``
- ``HPDCACHE_MEM_ATOMIC_SMAX``
- ``HPDCACHE_MEM_ATOMIC_SMIN``
- ``HPDCACHE_MEM_ATOMIC_UMAX``
- ``HPDCACHE_MEM_ATOMIC_UMIN``
- ``HPDCACHE_MEM_ATOMIC_SWAP``

These requests are forwarded to the memory through the CMI write request
interface. A particularity of these requests is that they generate two responses
from the memory:

#. Old data value from memory is returned through the CMI read response
   interface.

#. Write acknowledgement is returned through the CMI write response interface.

Both responses may arrive in any given order to the initiating HPDcache.

Regarding errors, if any response has its **error** signal set to 1
(``mem_resp_*_i.mem_resp_r_error`` or ``mem_resp_*_i.mem_resp_w_error``), the
HPDcache considers that the operation was not completed. It waits for both
responses and it forwards an error response (``core_rsp_o.error = 1``) to the
corresponding requester on the HPDcache requesters’ side.


Exclusive Load/Store Atomic Operations
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Exclusive load and store operations are issued as normal load and store
operations on the CMI read request interface and CMI write request interface,
respectively.

Specific operation types are however used on these exclusive requests:
``HPDCACHE_MEM_ATOMIC_LDEX`` for loads; and
``HPDCACHE_MEM_ATOMIC_STEX`` for stores.

These requests behave similarly to normal load and store to the memory but
provide some additional properties described in :ref:`sec_amo`.

In the case of the ``HPDCACHE_MEM_ATOMIC_STEX`` request, the write
acknowledgement contains an additional information in the
``mem_resp_w_is_atomic`` signal.
If this signal is set to 1, the exclusive store was "atomic", hence the data was
written in memory.
If this signal is set to 0, the exclusive store was "non-atomic". Hence the
write operation was abandoned.

The HPDcache uses exclusive stores in case of SC operations from requesters.
Depending on the ``mem_resp_w_is_atomic`` value, the HPDcache responds to the
requester according to the rules explained in :ref:`sec_amo`. A "non-atomic"
response is considered a **SC Failure**, and a "atomic" response is considered a
**SC Success**.

...

   - For uncacheable requests

   The HPDcache can issue up to 1 in-flight, uncached, read transaction.
   Uncached transactions have a unique transaction ID with all bits set to 1.

...

  - For uncacheable requests

    The HPDcache can issue up to 1 in-flight, uncached, write transaction.
    Uncached transactions have a unique transaction ID with all bits set to 1.

```

### `docs/source/amo.rst`

```text
Supported AMOs
--------------

On the interface from requesters, the supported AMOs are the ones listed in
:numref:`Table %s <tab_req_op_types>`. The supported AMOs are the ones defined
in the atomic (A) extension of the RISC-V ISA specification [RISCVUP2019]_.

Implementation
--------------

If :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_SUPPORT\_AMO}` is set to 0, the
HPDcache does not support AMOs from requesters.
See :ref:`sec_uncacheable_handler` for more details.

When a requester performs an AMO operation, the HPDcache needs to forward it to
the PoS. It is only at the PoS that AMOs from different caches converge and thus
where the correct result may be computed in case of multiple, simultaneous,
address-colliding AMOs. In the case a cache has a replica of the target address,
as the modification is performed at the PoS, that replica becomes obsolete
(cache obsolescence problem). This issue shall be solved through a hardware (or
software) cache coherency protocol.

To provide a consistent view of the data, the HPDcache updates the local replica
based on the result from the memory. The procedure is as follows: Forward the
AMO to the PoS, and wait for the response with the old data. If the target
address is replicated in the HPDcache, the HPDcache computes the new value
locally based on the data from the AMO request and the old data from the memory
(not the data of the local replica). Then it updates the replica. This allows
the core to have a consistent view with regards to its operations (single-thread
consistency). However, a cache coherency protocol (hardware or software) is
still required to ensure coherency in multi-core systems.

The HPDcache handle AMOs as non-allocating operations. This is, AMOs never fetch
a replica of the target cacheline from the memory to the cache. If the target
cacheline IS NOT replicated in the cache, the AMO modifies ONLY the memory. If
the target cacheline IS replicated in the cache, the AMO modifies BOTH the
memory and the cache.

...

AMO ordering
------------

As specified in the RISC-V ISA specification [RISCVUP2019]_, the base RISC-V ISA
has a relaxed memory model. To provide additional ordering constraints, AMOs
(including LR/SC) specify two bits, *aq* and *rl*, for *acquire* and *release*
semantics.

The HPDcache ignores *aq* and *rl* bits. It considers that they are always set.
Hence, HPDcache handles AMOs as sequentially consistent memory operations. The
HPDcache waits for all pending read and write operations to complete before
serving the AMO request.

This behavior implies that when the HPDcache forwards an AMO to the NoC, it will
be the only pending request from the HPDcache. In addition, no new requests from
the requesters are served until the AMO is completed.

...

LR/SC support
-------------

LR and SC are part of the Atomic (A) extension of the RISC-V ISA specification
[RISCVUP2019]_. These instructions allow *"complex atomic operations on a single
memory word or double-word"*.

The HPDcache fully supports all the instructions of the A extension of the
RISC-V ISA, including LR and SC operations.

In the specification of these instructions in the RISC-V ISA document, some
details are dependent to the implementation. Namely, the size of the reservation
set and the return code of a SC failure.

LR/SC reservation set
~~~~~~~~~~~~~~~~~~~~~

When a requester executes a LR operation, it "reserves" a set of bytes in
memory. This set contains at least the bytes solicited in the request but may
contain more. RISC-V ISA defines two sizes for LR operations: 4 bytes or 8
bytes. **The HPDcache reserves 8-bytes (double-word) containing the addressed
memory location regardless of whether the LR size is 4 or 8 bytes**. The start
address of the reservation set is a 8-bytes aligned address.

When the LR size is 8 bytes, the address is also aligned to 8 bytes.  In this
case, the reservation set matches exactly the address interval defined in the
request. When the LR size is 4 bytes, there are two possibilities:

-# the target address is not aligned to 8 bytes. The start address of the
reservation set contains additional 4 bytes before the target address

-# the target address is aligned to 8 bytes. The reservation set starts at the
target address but contains additional 4 bytes after the requested ones.

In summary, in case of LR operation, the reservation set address range is
computed as follows:

.. math::

   \small\mathbf{reservation\_set =}
       \begin{cases}
       \mathsf{(\lfloor{}HPDCACHE\_REQ\_ADDR / 8\rfloor{} \times 8)} &
         (\text{start address}) \\
       \mathsf{(\lfloor{}HPDCACHE\_REQ\_ADDR / 8\rfloor{} \times 8) + 8} &
         (\text{end address}) \\
       \end{cases}

**When a requester executes a SC operation, the HPDcache forwards the operation
to the memory ONLY IF the bytes addressed by the SC are part of an active
reservation set**. If the SC accesses a smaller number of bytes that those in
the active reservation set but within that reservation set, the SC is still
forwarded to the memory.

After a SC operation, the active reservation set, if any, is invalidated. This
is regardless whether the SC operation succeeds or not.

.. admonition:: Caution
   :class: caution

   The HPDcache keeps a unique active reservation set. If multiple requesters
   perform LR operations, the unique active reservation set is the one specified
   by the last LR operation.


The HPDcache also invalidates an active reservation set when there is an
address-colliding STORE operation. If a STORE access from any requester writes
one or more bytes within the active reservation set, the latter is invalidated.


SC failure response code
~~~~~~~~~~~~~~~~~~~~~~~~

The RISC-V ISA [RISCVUP2019]_ specifies that when a SC operation succeeds, the
core shall write zero into the destination register of the operation. Otherwise,
in case of SC failure, the core shall write a non-zero value into the
destination register.

The HPDcache returns the status of an SC operation into the ``core_rsp_o.rdata``
signal of the response interface to requesters. The following table specifies
the values returned by the HPDcache into the ``core_rsp_o.rdata`` signal in case
of SC operation.

.. list-table::
   :widths: 30 30
   :header-rows: 1
   :align: center

   * - **Case**
     - **Return value**
   * - SC Success
     - :math:`\small\mathsf{0x0000\_0000}`
   * - SC Failure
     - :math:`\small\mathsf{0x0000\_0001}`


```
