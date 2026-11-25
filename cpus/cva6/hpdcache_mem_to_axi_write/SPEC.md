# Implement `hpdcache_mem_to_axi_write`

Implement the complete `hpdcache_mem_to_axi_write` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mem_to_axi_write` definition in a single SystemVerilog code
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

// ...
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

```

### `vendor/pulp-platform/axi/include/axi/typedef.svh`

```systemverilog
`define AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)  \
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
    axi_pkg::atop_t   atop;                                     \
    user_t            user;                                     \
  } aw_chan_t;
`define AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)  \
  typedef struct packed {                                       \
    data_t data;                                                \
    strb_t strb;                                                \
    logic  last;                                                \
    user_t user;                                                \
  } w_chan_t;
`define AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)  \
  typedef struct packed {                             \
    id_t            id;                               \
    axi_pkg::resp_t resp;                             \
    user_t          user;                             \
  } b_chan_t;

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

// ...

  // ATOP[5:0]
  /// - Sends a single data value with an address.
  /// - The target swaps the value at the addressed location with the data value that is supplied in
  ///   the transaction.
  /// - The original data value at the addressed location is returned.
  /// - Outbound data size is 1, 2, 4, or 8 bytes.
  /// - Inbound data size is the same as the outbound data size.
  localparam ATOP_ATOMICSWAP  = 6'b110000;
  /// - Sends two data values, the compare value and the swap value, to the addressed location.
  ///   The compare and swap values are of equal size.
  /// - The data value at the addressed location is checked against the compare value:
  ///   - If the values match, the swap value is written to the addressed location.
  ///   - If the values do not match, the swap value is not written to the addressed location.
  /// - The original data value at the addressed location is returned.
  /// - Outbound data size is 2, 4, 8, 16, or 32 bytes.
  /// - Inbound data size is half of the outbound data size because the outbound data contains both
  ///   compare and swap values, whereas the inbound data has only the original data value.
  localparam ATOP_ATOMICCMP   = 6'b110001;
  // ATOP[5:4]
  /// Perform no atomic operation.
  localparam ATOP_NONE        = 2'b00;
  /// - Sends a single data value with an address and the atomic operation to be performed.
  /// - The target performs the operation using the sent data and value at the addressed location as
  ///   operands.
  /// - The result is stored in the address location.
  /// - A single response is given without data.
  /// - Outbound data size is 1, 2, 4, or 8 bytes.
  localparam ATOP_ATOMICSTORE = 2'b01;
  /// Sends a single data value with an address and the atomic operation to be performed.
  /// - The original data value at the addressed location is returned.
  /// - The target performs the operation using the sent data and value at the addressed location as
  ///   operands.
  /// - The result is stored in the address location.
  /// - Outbound data size is 1, 2, 4, or 8 bytes.
  /// - Inbound data size is the same as the outbound data size.
  localparam ATOP_ATOMICLOAD  = 2'b10;
  // ATOP[3]
  /// For AtomicStore and AtomicLoad transactions `AWATOP[3]` indicates the endianness that is
  /// required for the atomic operation.  The value of `AWATOP[3]` applies to arithmetic operations
  /// only and is ignored for bitwise logical operations.
  /// When deasserted, this bit indicates that the operation is little-endian.
  localparam ATOP_LITTLE_END  = 1'b0;
  /// When asserted, this bit indicates that the operation is big-endian.
  localparam ATOP_BIG_END     = 1'b1;
  // ATOP[2:0]
  /// The value in memory is added to the sent data and the result stored in memory.
  localparam ATOP_ADD   = 3'b000;
  /// Every set bit in the sent data clears the corresponding bit of the data in memory.
  localparam ATOP_CLR   = 3'b001;
  /// Bitwise exclusive OR of the sent data and value in memory.
  localparam ATOP_EOR   = 3'b010;
  /// Every set bit in the sent data sets the corresponding bit of the data in memory.
  localparam ATOP_SET   = 3'b011;
  /// The value stored in memory is the maximum of the existing value and sent data. This operation
  /// assumes signed data.
  localparam ATOP_SMAX  = 3'b100;
  /// The value stored in memory is the minimum of the existing value and sent data. This operation
  /// assumes signed data.
  localparam ATOP_SMIN  = 3'b101;
  /// The value stored in memory is the maximum of the existing value and sent data. This operation
  /// assumes unsigned data.
  localparam ATOP_UMAX  = 3'b110;
  /// The value stored in memory is the minimum of the existing value and sent data. This operation
  /// assumes unsigned data.
  localparam ATOP_UMIN  = 3'b111;

```

## Module declaration

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Dcache memory request to axi write channels
 *  History       :
 */
module hpdcache_mem_to_axi_write
import hpdcache_pkg::*;
#(
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    parameter type aw_chan_t = logic,
    parameter type w_chan_t = logic,
    parameter type b_chan_t = logic
)
(
    output logic                          req_ready_o,
    input  logic                          req_valid_i,
    input  hpdcache_mem_req_t             req_i,

    output logic                          req_data_ready_o,
    input  logic                          req_data_valid_i,
    input  hpdcache_mem_req_w_t           req_data_i,

    input  logic                          resp_ready_i,
    output logic                          resp_valid_o,
    output hpdcache_mem_resp_w_t          resp_o,

    output logic                          axi_aw_valid_o,
    output aw_chan_t                      axi_aw_o,
    input  logic                          axi_aw_ready_i,

    output logic                          axi_w_valid_o,
    output w_chan_t                       axi_w_o,
    input  logic                          axi_w_ready_i,

    input  logic                          axi_b_valid_i,
    input  b_chan_t                       axi_b_i,
    output logic                          axi_b_ready_o
);

```

## Parent instantiation

### `core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv`

```systemverilog
  hpdcache_mem_to_axi_write #(
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
      .aw_chan_t            (axi_aw_chan_t),
      .w_chan_t             (axi_w_chan_t),
      .b_chan_t             (axi_b_chan_t)
  ) i_hpdcache_mem_to_axi_write (
      .req_ready_o(dcache_write_ready_o),
      .req_valid_i(dcache_write_valid_i),
      .req_i      (dcache_write_i),

      .req_data_ready_o(dcache_write_data_ready_o),
      .req_data_valid_i(dcache_write_data_valid_i),
      .req_data_i      (dcache_write_data_i),

      .resp_ready_i(dcache_write_resp_ready_i),
      .resp_valid_o(dcache_write_resp_valid_o),
      .resp_o      (dcache_write_resp_o),

      .axi_aw_valid_o(axi_req_o.aw_valid),
      .axi_aw_o      (axi_req_o.aw),
      .axi_aw_ready_i(axi_resp_i.aw_ready),

      .axi_w_valid_o(axi_req_o.w_valid),
      .axi_w_o      (axi_req_o.w),
      .axi_w_ready_i(axi_resp_i.w_ready),

      .axi_b_valid_i(axi_resp_i.b_valid),
      .axi_b_i      (axi_resp_i.b),
      .axi_b_ready_o(axi_req_o.b_ready)
  );

```

## Related source code

### `rtl/src/utils/hpdcache_mem_to_axi_read.sv`

```systemverilog
    logic                lock;
    axi_pkg::cache_t     cache;
    hpdcache_mem_error_e resp;

    assign  lock  = (req_i.mem_req_command == HPDCACHE_MEM_ATOMIC) &&
                    (req_i.mem_req_atomic  == HPDCACHE_MEM_ATOMIC_LDEX);

    assign  cache = req_i.mem_req_cacheable ?
                    axi_pkg::CACHE_BUFFERABLE |
                    axi_pkg::CACHE_MODIFIABLE |
                    axi_pkg::CACHE_RD_ALLOC   |
                    axi_pkg::CACHE_WR_ALLOC   : axi_pkg::CACHE_MODIFIABLE;

    always_comb
    begin : resp_decode_comb
        case (axi_r_i.resp)
            axi_pkg::RESP_SLVERR,
            axi_pkg::RESP_DECERR: resp = HPDCACHE_MEM_RESP_NOK;
            default:              resp = HPDCACHE_MEM_RESP_OK;
        endcase
    end

    assign  req_ready_o       = axi_ar_ready_i,
            axi_ar_valid_o    = req_valid_i,
            axi_ar_o.id       = req_i.mem_req_id,
            axi_ar_o.addr     = req_i.mem_req_addr,
            axi_ar_o.len      = req_i.mem_req_len,
            axi_ar_o.size     = req_i.mem_req_size,
            axi_ar_o.burst    = axi_pkg::BURST_INCR,
            axi_ar_o.lock     = lock,
            axi_ar_o.cache    = cache,
            axi_ar_o.prot     = '0,
            axi_ar_o.qos      = '0,
            axi_ar_o.region   = '0,
            axi_ar_o.user     = '0;

    assign  axi_r_ready_o           = resp_ready_i,
            resp_valid_o            = axi_r_valid_i,
            resp_o.mem_resp_r_error = resp,
            resp_o.mem_resp_r_id    = axi_r_i.id,
            resp_o.mem_resp_r_data  = axi_r_i.data,
            resp_o.mem_resp_r_last  = axi_r_i.last;

```

### `core/cache_subsystem/axi_adapter.sv`

```systemverilog
  function automatic axi_pkg::atop_t atop_from_amo(ariane_pkg::amo_t amo);
    axi_pkg::atop_t result = 6'b000000;

    unique case (amo)
      ariane_pkg::AMO_NONE: result = {axi_pkg::ATOP_NONE, 4'b0000};
      ariane_pkg::AMO_SWAP: result = {axi_pkg::ATOP_ATOMICSWAP};
      ariane_pkg::AMO_ADD:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_ADD};
      ariane_pkg::AMO_AND:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_CLR};
      ariane_pkg::AMO_OR:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_SET};
      ariane_pkg::AMO_XOR:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_EOR};
      ariane_pkg::AMO_MAX:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_SMAX};
      ariane_pkg::AMO_MAXU:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_UMAX};
      ariane_pkg::AMO_MIN:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_SMIN};
      ariane_pkg::AMO_MINU:
      result = {axi_pkg::ATOP_ATOMICLOAD, axi_pkg::ATOP_LITTLE_END, axi_pkg::ATOP_UMIN};
      ariane_pkg::AMO_CAS1: result = {axi_pkg::ATOP_NONE, 4'b0000};  // Unsupported
      ariane_pkg::AMO_CAS2: result = {axi_pkg::ATOP_NONE, 4'b0000};  // Unsupported
      default: result = 6'b000000;
    endcase

    return result;
  endfunction

```

## Documentation

### `docs/source/interface.rst`

```text
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

...

In the case of the ``HPDCACHE_MEM_ATOMIC_STEX`` request, the write
acknowledgement contains an additional information in the
``mem_resp_w_is_atomic`` signal.
If this signal is set to 1, the exclusive store was "atomic", hence the data was
written in memory.
If this signal is set to 0, the exclusive store was "non-atomic". Hence the
write operation was abandoned.

```
