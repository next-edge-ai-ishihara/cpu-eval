# Implement `hpdcache_mem_to_axi_read`

Implement the complete `hpdcache_mem_to_axi_read` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mem_to_axi_read` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
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

// ...

        HPDCACHE_MEM_ATOMIC_LDEX = 4'b1100,
        HPDCACHE_MEM_ATOMIC_STEX = 4'b1101

```

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

```

### `vendor/pulp-platform/axi/include/axi/typedef.svh`

```systemverilog
`define AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)  \
  typedef struct packed {                                       \
    id_t              id;                                       \
    addr_t            addr;                                     \
    axi_pkg::len_t    len;                                      \
    axi_pkg::size_t   size;                                     \
    axi_pkg::burst_t  burst;                                    \
    logic             lock;                                     \
    axi_pkg::cache_t  cache;                                    \
    axi_pkg::prot_t   prot;                                     \
    axi_pkg::qos_t    qos;                                      \
    axi_pkg::region_t region;                                   \
    user_t            user;                                     \
  } ar_chan_t;
`define AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)  \
  typedef struct packed {                                     \
    id_t            id;                                       \
    data_t          data;                                     \
    axi_pkg::resp_t resp;                                     \
    logic           last;                                     \
    user_t          user;                                     \
  } r_chan_t;

```

### `vendor/pulp-platform/axi/src/axi_pkg.sv`

```systemverilog
  /// Normal access success.  Indicates that a normal access has been successful. Can also indicate
  /// that an exclusive access has failed.
  localparam RESP_OKAY   = 2'b00;
  /// Exclusive access okay.  Indicates that either the read or write portion of an exclusive access
  /// has been successful.
  localparam RESP_EXOKAY = 2'b01;
  /// Slave error.  Used when the access has reached the slave successfully, but the slave wishes to
  /// return an error condition to the originating master.
  localparam RESP_SLVERR = 2'b10;
  /// Decode error.  Generated, typically by an interconnect component, to indicate that there is no
  /// slave at the transaction address.
  localparam RESP_DECERR = 2'b11;

  /// When this bit is asserted, the interconnect, or any component, can delay the transaction
  /// reaching its final destination for any number of cycles.
  localparam CACHE_BUFFERABLE = 4'b0001;
  /// When HIGH, Modifiable indicates that the characteristics of the transaction can be modified.
  /// When Modifiable is LOW, the transaction is Non-modifiable.
  localparam CACHE_MODIFIABLE = 4'b0010;
  /// When this bit is asserted, read allocation of the transaction is recommended but is not
  /// mandatory.
  localparam CACHE_RD_ALLOC   = 4'b0100;
  /// When this bit is asserted, write allocation of the transaction is recommended but is not
  /// mandatory.
  localparam CACHE_WR_ALLOC   = 4'b1000;

```

## Module declaration

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Dcache memory request to axi read channels
 *  History       :
 */
module hpdcache_mem_to_axi_read
import hpdcache_pkg::*;
#(
    parameter type hpdcache_mem_req_t    = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type ar_chan_t = logic,
    parameter type r_chan_t  = logic
)
(
    output logic                          req_ready_o,
    input  logic                          req_valid_i,
    input  hpdcache_mem_req_t             req_i,

    input  logic                          resp_ready_i,
    output logic                          resp_valid_o,
    output hpdcache_mem_resp_r_t          resp_o,

    output logic                          axi_ar_valid_o,
    output ar_chan_t                      axi_ar_o,
    input  logic                          axi_ar_ready_i,

    input  logic                          axi_r_valid_i,
    input  r_chan_t                       axi_r_i,
    output logic                          axi_r_ready_o
);

```

## Parent instantiation

### `core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv`

```systemverilog
  hpdcache_mem_to_axi_read #(
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .ar_chan_t            (axi_ar_chan_t),
      .r_chan_t             (axi_r_chan_t)
  ) i_hpdcache_mem_to_axi_read (
      .req_ready_o(mem_req_read_ready_arb),
      .req_valid_i(mem_req_read_valid_arb),
      .req_i      (mem_req_read_arb),

      .resp_ready_i(mem_resp_read_ready),
      .resp_valid_o(mem_resp_read_valid),
      .resp_o      (mem_resp_read),

      .axi_ar_valid_o(axi_req_o.ar_valid),
      .axi_ar_o      (axi_req_o.ar),
      .axi_ar_ready_i(axi_resp_i.ar_ready),

      .axi_r_valid_i(axi_resp_i.r_valid),
      .axi_r_i      (axi_resp_i.r),
      .axi_r_ready_o(axi_req_o.r_ready)
  );

```

## Related source code

### `rtl/src/hpdcache_uncached.sv`

```systemverilog
            req_op_q.is_amo_lr: begin
                mem_req_read_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_read_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_LDEX;
                mem_req_read_valid_o           = (uc_fsm_q == UC_MEM_REQ);

```

### `rtl/src/utils/hpdcache_mem_to_axi_write.sv`

```systemverilog
    always_comb
    begin : atop_comb
        lock = 1'b0;
        atop = '0;
        case (req_i.mem_req_command)
            HPDCACHE_MEM_ATOMIC: begin
                case (req_i.mem_req_atomic)
                    HPDCACHE_MEM_ATOMIC_STEX: lock = 1'b1;

// ...

    assign  cache = (req_i.mem_req_cacheable && !lock) ?
                        axi_pkg::CACHE_BUFFERABLE |
                        axi_pkg::CACHE_MODIFIABLE |
                        axi_pkg::CACHE_RD_ALLOC   |
                        axi_pkg::CACHE_WR_ALLOC   : axi_pkg::CACHE_MODIFIABLE;

    always_comb
    begin : resp_decode_comb
        case (axi_b_i.resp)
            axi_pkg::RESP_SLVERR,
            axi_pkg::RESP_DECERR: resp = HPDCACHE_MEM_RESP_NOK;
            default:              resp = HPDCACHE_MEM_RESP_OK;
        endcase
    end

    assign  req_ready_o                     = axi_aw_ready_i,
            axi_aw_valid_o                  = req_valid_i,
            axi_aw_o.id                     = req_i.mem_req_id,
            axi_aw_o.addr                   = req_i.mem_req_addr,
            axi_aw_o.len                    = req_i.mem_req_len,
            axi_aw_o.size                   = req_i.mem_req_size,
            axi_aw_o.burst                  = axi_pkg::BURST_INCR,
            axi_aw_o.lock                   = lock,
            axi_aw_o.cache                  = cache,
            axi_aw_o.prot                   = '0,
            axi_aw_o.qos                    = '0,
            axi_aw_o.region                 = '0,
// ...
            axi_aw_o.user                   = '0;

// ...

    assign  axi_b_ready_o                   = resp_ready_i,
            resp_valid_o                    = axi_b_valid_i,
            resp_o.mem_resp_w_error         = resp,
            resp_o.mem_resp_w_id            = axi_b_i.id,

```

## Documentation

### `docs/source/interface.rst`

```text
   * - ``mem_resp_read_valid_i``
     - NoC
     - Indicates that the channel is signaling a valid response
   * - ``mem_resp_read_ready_o``
     - Cache
     - Indicates that the cache is ready to accept a response
   * - ``mem_resp_read_i.mem_resp_r_error``
     - NoC
     - Indicates whether there was an error condition while processing the
       request
   * - ``mem_resp_read_i.mem_resp_r_id``
     - NoC
     - The identification tag for the request. It corresponds to the ID
       transferred with the request
   * - ``mem_resp_read_i.mem_resp_r_data``
     - NoC
     - Response read data. It shall be naturally aligned to the request address
   * - ``mem_resp_read_i.mem_resp_r_last``
     - NoC
     - Indicates the last transfer in a read response burst

```
