# Implement `ibex_load_store_unit`

Implement the complete `ibex_load_store_unit` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_load_store_unit` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### ibex_configs.yaml

```yaml
small:
  BaseIsa                  : "ibex_pkg::BaseIsaRV32I"
  RV32E                    : 0
  RV32M                    : "ibex_pkg::RV32MFast"
  RV32B                    : "ibex_pkg::RV32BNone"
  RV32ZC                   : "ibex_pkg::RV32Zca"
  RegFile                  : "ibex_pkg::RegFileFF"
  BranchTargetALU          : 0
  WritebackStage           : 0
  ICache                   : 0
  ICacheECC                : 0
  ICacheScramble           : 0
  BranchPredictor          : 0
  DbgTriggerEn             : 0
  SecureIbex               : 0
  PMPEnable                : 0
  PMPGranularity           : 0
  PMPNumRegions            : 4
  MHPMCounterNum           : 0
  MHPMCounterWidth         : 40
```

## Package and imports

### rtl/ibex_pkg.sv

```systemverilog
  typedef enum integer {
    BaseIsaRV32I          = 0, // only RV32I
    BaseIsaRV32IorCHERIoT = 1  // dual base ISA: RV32I/CHERIoT runtime switchable
  } base_isa_e;
// ...
  // Multi-bit signal used for security hardening. For non-secure implementation all bits other than
  // the bottom bit are ignored.
  parameter int IbexMuBiWidth = 4;
  typedef logic [IbexMuBiWidth-1:0] ibex_mubi_t;

  // Note that if adjusting these parameters it is assumed the bottom bit is set for On and unset
  // for Off. This allows the use of IbexMuBiOn/IbexMuBiOff to work for both secure and non-secure
  // Ibex. If this assumption is broken the RTL that uses ibex_mubi_t types such as the fetch_enable
  // and core_busy signals within `ibex_core` may need adjusting.
  parameter ibex_mubi_t IbexMuBiOn  = 4'b0101;
  parameter ibex_mubi_t IbexMuBiOff = 4'b1010;
```

### rtl/ibex_cheriot_pkg.sv

```systemverilog
  parameter int unsigned ADDR_W    = 32;
  parameter int unsigned CBOUND_W  = 9;   // 9-bit compressed bound (T or B)
  parameter int unsigned CEXP_W    = 4;   // 4-bit compressed exponent
  parameter int unsigned EXP_W     = 5;   // 5-bit expanded exponent
  parameter int unsigned OTYPE_W   = 3;   // 3-bit object type (sealing)
  parameter int unsigned CPERMS_W  = 6;   // 6-bit compressed permissions
  parameter int unsigned PERMS_W   = 12;  // 12-bit expanded permissions
  // Width of the compressed capability type (cap_t) as a flat vector used for ECC protection.
  parameter int unsigned REGCAP_W = 35;

  // Capability typedefs
  typedef logic [CBOUND_W-1:0] cbound_t;  // 9-bit compressed bound (T or B)
  typedef logic [CEXP_W-1:0]   cexp_t;    // 4-bit compressed exponent
  typedef logic [EXP_W-1:0]    exp_t;     // 5-bit expanded exponent
  typedef logic [OTYPE_W-1:0]  otype_t;   // 3-bit object type (sealing)
  typedef logic [CPERMS_W-1:0] cperms_t;  // 6-bit compressed permissions
  typedef logic [1:0]          cap_cor_t; // 2-bit correction: [1]=top_hi^addr_hi, [0]=addr_hi

  // Expanded 12-bit permissions (spec v1.0, chapter 7.13.1)
  typedef struct packed {
    logic U0;  // [11] user permission (software-defined)
    logic SE;  // [10] seal
    logic US;  // [9]  unseal
    logic EX;  // [8]  execute
    logic SR;  // [7]  access system registers
    logic MC;  // [6]  load/store capability
    logic LD;  // [5]  load
    logic SL;  // [4]  store local capability
    logic LM;  // [3]  load mutable
    logic SD;  // [2]  store
    logic LG;  // [1]  load global
    logic GL;  // [0]  global
  } perms_t;

  // Sealing types (spec v1.0, chapter 7.13.2)
  parameter otype_t OTYPE_UNSEALED        = 3'd0; // unsealed
  parameter otype_t OTYPE_SENTRY_II_FWD   = 3'd1; // interrupt-inheriting forward sentry
  parameter otype_t OTYPE_SENTRY_ID_FWD   = 3'd2; // interrupt disabling forward sentry
  parameter otype_t OTYPE_SENTRY_IE_FWD   = 3'd3; // interrupt enabling forward sentry
  parameter otype_t OTYPE_SENTRY_ID_BKWD  = 3'd4; // interrupt disabling backward sentry
  parameter otype_t OTYPE_SENTRY_IE_BKWD  = 3'd5; // interrupt enabling backward sentry

  // Exponent (spec v1.0, chapter 7.13.3)
  parameter cexp_t MAXCEXP = 4'd15; // compressed maximum exponent encoding
  parameter exp_t  MAXEXP  = 5'd24; // expanded maximum exponent

  // -----------------------------------------------------------------------------------------------
  // Capability types
  // -----------------------------------------------------------------------------------------------
  // The CHERIoT ISA defines the capability format (spec v1.0, chapter 7.13, Figure 7.2).
  // Two types are used in the RTL:
  //
  //  cap_t          - The primary compressed form defined by the spec and used everywhere a
  //                   capability is stored (register file, CSR registers, load/store ports,
  //                   ECC/lockstep vectors). Its lower 33 bits (cap[32:0]) are a 1:1 match with the
  //                   spec so writing to memory is a simple truncation and a direct cast.
  //                   Bits [34:33] store the correction factors that are not in the spec but kept
  //                   in the register file to save recomputation costs. See the
  //                   `cheriot_compute_corrections` function below.
  //
  //  decoded_cap_t  - The uncompressed capability type used inside the core. Created by
  //                   `cheriot_decode_cap` and `cheriot_encode_cap`. Its lower 35 bits are the same
  //                   as cap_t so encode is simpley a cast. The upper bits add the decompressed
  //                   bounds and permissions.
  // -----------------------------------------------------------------------------------------------

  // Compressed capability + correction factors
  typedef struct packed {
    cap_cor_t cap_cor; // [34:33] correction factors
    // Capability according to spec v1.0, chapter 7.13
    logic     valid;   // [32]    tag bit
    logic     rsvd;    // [31]    reserved R
    cperms_t  cperms;  // [30:25] compressed permissions
    otype_t   otype;   // [24:22] object type
    cexp_t    cexp;    // [21:18] 4-bit compressed exponent
    cbound_t  top;     // [17:9]  top mantissa T
    cbound_t  base;    // [8:0]   base mantissa B
  } cap_t;  // 2+1+1+6+3+4+9+9 = 35 bits = REGCAP_W

  // Uncompressed capability
  typedef struct packed {
    logic [ADDR_W:0]   top33;  // 33 bits absolute top
    logic [ADDR_W-1:0] base32; // 32 bits absolute base
    perms_t            perms;  // 12 bits expanded permissions
    // Identical layout to cap_t from here
    cap_cor_t cap_cor; // [34:33] correction factors
    logic     valid;   // [32]    tag bit
    logic     rsvd;    // [31]    reserved R
    cperms_t  cperms;  // [30:25] compressed permissions
    otype_t   otype;   // [24:22] object type
    cexp_t    cexp;    // [21:18] 4-bit compressed exponent
    cbound_t  top;     // [17:9]  top mantissa T
    cbound_t  base;    // [8:0]   base mantissa B
  } decoded_cap_t;  // 33+32+12+35 = 112 bits


  // Types for bound computation in CHERIoT EX Stage
  typedef struct packed {
    logic [32:0]    top33req; // requested top = addr + length (33-bit)
    exp_t           exp1;     // exponent candidate from length (no overflow)
    exp_t           exp2;     // exp1 + 1 (used when exp1 path overflows)
    logic [EXP_W:0] explen;   // MSB position of length[31:9] (6-bit, can be 32)
    logic [EXP_W:0] expb;     // trailing-zero count of base address (6-bit)
    logic           in_bound; // addr..addr+length lies within parent bounds
  } bound_req_t;

  // The decoded capability plus the alignment mask and representable length.
  typedef struct packed {
    decoded_cap_t cap;   // resulting capability
    logic [31:0]  maska; // alignment mask    (CRAM result)
    logic [31:0]  rlen;  // representable len (CRRL result)
  } bound_result_t;

  // Permission-clearing control for capability loads (CLC instruction).
  // Each field corresponds to one CLC clearing rule from the spec.
  typedef struct packed {
    logic CTAG;   // [2] clear tag (valid) bit (loading cap lacks MC)
    logic SD_LM;  // [1] clear SD and LM       (loading cap lacks LM)
    logic GL_LG;  // [0] clear GL and LG       (loading cap lacks LG)
  } cap_clrperm_t;
```

## Module declaration

```verilog
module ibex_load_store_unit import ibex_pkg::*; import ibex_cheriot_pkg::*; #(
  parameter base_isa_e   BaseIsa      = BaseIsaRV32I,
  parameter bit          MemECC       = 1'b0,
  parameter int unsigned MemDataWidth = MemECC ? 32 + 7 : 32
) (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  ibex_mubi_t   cheriot_enable_i,

  // data interface
  output logic         data_req_o,
  input  logic         data_gnt_i,
  input  logic         data_rvalid_i,
  input  logic         data_bus_err_i,
  input  logic         data_pmp_err_i,

  output logic [31:0]             data_addr_o,
  output logic                    data_we_o,
  output logic [3:0]              data_be_o,
  output logic [MemDataWidth-1:0] data_wdata_o,
  output logic                    data_tag_o,
  input  logic [MemDataWidth-1:0] data_rdata_i,
  input  logic                    data_tag_i,

  // signals to/from ID/EX stage
  input  logic         lsu_we_i,             // write enable                     -> from ID/EX
  input  logic         lsu_is_cap_i,         // capability load/store            -> from ID/EX
  input  logic         lsu_cheriot_err_i,    // CHERIoT access error               -> from ID/EX
  input  logic [1:0]   lsu_type_i,           // data type: word, half word, byte -> from ID/EX
  input  logic [31:0]  lsu_wdata_i,          // data to write to memory          -> from ID/EX
  input  cap_t         lsu_wcap_i,           // capability to write to memory    -> from ID/EX
  input  cap_clrperm_t lsu_lc_clrperm_i,     // cap load clear permissions       -> from ID/EX
  input  logic         lsu_sign_ext_i,       // sign extension                   -> from ID/EX

  output cap_t         lsu_rcap_o,           // capability read from memory      -> to ID/EX
  output logic [31:0]  lsu_rdata_o,          // requested data                   -> to ID/EX
  output logic         lsu_rdata_valid_o,
  input  logic         lsu_req_i,            // data request                     -> from ID/EX

  input  logic [31:0]  adder_result_ex_i,    // address computed in ALU          -> from ID/EX

  output logic         addr_incr_req_o,      // request address increment for
                                             // misaligned accesses              -> to ID/EX
  output logic [31:0]  addr_last_o,          // address of last transaction      -> to controller
                                             // -> mtval
                                             // -> AGU for misaligned accesses

  output logic         lsu_req_done_o,       // Signals that data request is complete
                                             // (only need to await final data
                                             // response)                        -> to ID/EX

  output logic         lsu_resp_valid_o,     // LSU has response from transaction -> to ID/EX & WB

  // exception signals
  output logic         load_err_o,
  output logic         load_resp_intg_err_o,
  output logic         store_err_o,
  output logic         store_resp_intg_err_o,
  output logic         lsu_err_is_cheriot_o,

  output logic         busy_o,

  output logic         perf_load_o,
  output logic         perf_store_o
);
```

## Parent instantiation

### rtl/ibex_core.sv

```verilog
  ibex_load_store_unit #(
    .MemECC(MemECC),
    .MemDataWidth(MemDataWidth),
    .BaseIsa(BaseIsa)
  ) load_store_unit_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .cheriot_enable_i (cheriot_enable_i),
    // data interface
    .data_req_o    (data_req_out),
    .data_gnt_i    (data_gnt_i),
    .data_rvalid_i (data_rvalid_i),
    .data_bus_err_i(data_err_i),
    .data_pmp_err_i(pmp_req_err[PMP_D]),

    .data_addr_o      (data_addr_o),
    .data_we_o        (data_we_o),
    .data_be_o        (data_be_o),
    .data_wdata_o     (data_wdata_o),
    .data_tag_o       (data_tag_o),
    .data_rdata_i     (data_rdata_i),
    .data_tag_i       (data_tag_i),

    // signals to/from ID/EX stage
    .lsu_we_i      (lsu_we),
    .lsu_type_i    (lsu_type),
    .lsu_wdata_i   (lsu_wdata),
    .lsu_wcap_i    (lsu_wcap),
    .lsu_sign_ext_i(lsu_sign_ext),

    .lsu_rdata_o      (rf_wdata_lsu),
    .lsu_rcap_o       (rf_wcap_lsu),
    .lsu_rdata_valid_o(lsu_rdata_valid),
    .lsu_req_i        (lsu_req),
    .lsu_is_cap_i     (lsu_is_cap),
    .lsu_lc_clrperm_i (lsu_lc_clrperm),
    .lsu_cheriot_err_i(lsu_cheriot_err),
    .adder_result_ex_i(lsu_addr),

    .addr_incr_req_o(lsu_addr_incr_req),
    .addr_last_o    (lsu_addr_last),

    .lsu_req_done_o   (lsu_req_done),
    .lsu_resp_valid_o (lsu_resp_valid),

    // exception signals
    .load_err_o           (lsu_load_err_raw),
    .load_resp_intg_err_o (lsu_load_resp_intg_err),
    .store_err_o          (lsu_store_err_raw),
    .store_resp_intg_err_o(lsu_store_resp_intg_err),
    .lsu_err_is_cheriot_o (lsu_err_is_cheriot),

    .busy_o(lsu_busy),

    .perf_load_o (perf_load),
    .perf_store_o(perf_store)
  );
```

## Dependency declarations

### vendor/lowrisc_ip/ip/prim_generic/rtl/prim_buf.sv

```verilog
module prim_buf #(
  parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);
```

## Related source code

### rtl/ibex_top.sv

```systemverilog
  parameter bit                     SecureIbex                   = 1'b0,
  // ...
  parameter bit                     MemECC                       = SecureIbex,
  parameter int unsigned            MemDataWidth                 = MemECC ? 32 + 7 : 32,

  // ...

  ibex_core #(
    // ...
    .MemECC               (MemECC),
    .MemDataWidth         (MemDataWidth),
```

### rtl/ibex_decoder.sv

```systemverilog
        // store size
        unique case (instr[13:12])
          2'b00:   data_type_o  = 2'b10; // sb
          2'b01:   data_type_o  = 2'b01; // sh
          2'b10:   data_type_o  = 2'b00; // sw
          default: data_type_o  = 2'b00;
        endcase
```

### rtl/ibex_id_stage.sv

```systemverilog
  // Misaligned loads/stores result in two aligned loads/stores, compute second address
  assign alu_op_a_mux_sel = lsu_addr_incr_req_i ? OP_A_FWD        : alu_op_a_mux_sel_dec;
  assign alu_op_b_mux_sel = lsu_addr_incr_req_i ? OP_B_IMM        : alu_op_b_mux_sel_dec;
  assign imm_b_mux_sel    = lsu_addr_incr_req_i ? IMM_B_INCR_ADDR : imm_b_mux_sel_dec;
// ...
  // Main ALU MUX for Operand A
  always_comb begin : alu_operand_a_mux
    unique case (alu_op_a_mux_sel)
      OP_A_REG_A:  alu_operand_a = rf_rdata_a_fwd;
      OP_A_FWD:    alu_operand_a = lsu_addr_last_i;
      OP_A_CURRPC: alu_operand_a = pc_id_i;
      OP_A_IMM:    alu_operand_a = imm_a;
      default:     alu_operand_a = pc_id_i;
    endcase
  end
// ...
  if (BranchTargetALU) begin : g_btalu_muxes
// ...
  end else begin : g_nobtalu
// ...
    // Full main ALU immediate MUX for Operand B
    always_comb begin : immediate_b_mux
      unique case (imm_b_mux_sel)
        IMM_B_I:         imm_b = imm_i_type;
        IMM_B_S:         imm_b = imm_s_type;
        IMM_B_B:         imm_b = imm_b_type;
        IMM_B_U:         imm_b = imm_u_type;
        IMM_B_J:         imm_b = imm_j_type;
        IMM_B_INCR_PC:   imm_b = instr_is_compressed_i ? 32'h2 : 32'h4;
        IMM_B_INCR_ADDR: imm_b = 32'h4;
        default:         imm_b = 32'h4;
      endcase
    end
// ...
  end

  // ALU MUX for Operand B
  assign alu_operand_b = (alu_op_b_mux_sel == OP_B_IMM) ? imm_b : rf_rdata_b_fwd;
```

### rtl/ibex_core.sv

```systemverilog
  // Capture read data from LSU when it becomes valid
  always_comb begin
    if (load_store_unit_i.resp_is_cap_q & lsu_resp_valid) begin
      rvfi_mem_rdata_d = rf_wdata_lsu;
      rvfi_mem_rcap_d  = rf_wcap_lsu;
    end else if (lsu_resp_valid) begin
      rvfi_mem_rdata_d = rf_wdata_lsu;
      rvfi_mem_rcap_d  = rvfi_mem_rcap_q;
    end else begin
      rvfi_mem_rdata_d = rvfi_mem_rdata_q;
      rvfi_mem_rcap_d  = rvfi_mem_rcap_q;
    end
  end
```

### dv/verilator/simple_system_cosim/ibex_simple_system_cosim_checker.sv

```systemverilog
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      outstanding_store <= 1'b0;
    end else begin
      if (host_dmem_req && host_dmem_gnt) begin
        outstanding_store      <= host_dmem_we;
        outstanding_addr       <= host_dmem_addr;
        outstanding_be         <= host_dmem_be;
        outstanding_store_data <= host_dmem_wdata;
        outstanding_misaligned_first <=
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.handle_misaligned_d |
          ((u_top.u_ibex_top.u_ibex_core.load_store_unit_i.lsu_type_i == 2'b01) &
           (u_top.u_ibex_top.u_ibex_core.load_store_unit_i.data_offset == 2'b01));

        outstanding_misaligned_second <=
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.addr_incr_req_o;

        outstanding_misaligned_first_saw_error <=
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.addr_incr_req_o &
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.lsu_err_d;

        outstanding_m_mode_access <=
          u_top.u_ibex_top.u_ibex_core.priv_mode_lsu == ibex_pkg::PRIV_LVL_M;
      end

      if (host_dmem_rvalid) begin
        riscv_cosim_notify_dside_access(cosim_handle, outstanding_store, outstanding_addr,
          outstanding_store ? outstanding_store_data : host_dmem_rdata, outstanding_be,
          host_dmem_err, outstanding_misaligned_first, outstanding_misaligned_second,
          outstanding_misaligned_first_saw_error, outstanding_m_mode_access);
      end
    end
  end
```

### dv/cosim/cosim.h

```cpp
// Information about a dside transaction observed on the DUT memory interface
struct DSideAccessInfo {
  // set when the access is a store, in which case `data` is the store data from
  // the DUT. Otherwise `data` is the load data provided to the DUT.
  bool store;
  // `addr` is the address and must be 32-bit aligned. `data` and `be` are
  // aligned to the address. For example an 8-bit store of 0xff to 0x12 has
  // `data` as 0x00ff0000, `addr` as 0x10 and `be` as 0b0100.
  uint32_t data;
  uint32_t addr;
  uint32_t be;

  // set if an error response to the transaction is seen.
  bool error;

  // `misaligned_first` and `misaligned_second` are set when the transaction is
  // generated for a misaligned store or load instruction.  `misaligned_first`
  // is true when the transaction is for the lower half and `misaligned_second`
  // is true when the transaction is for the upper half, if it exists.
  //
  // For example an unaligned 32-bit load to 0x3 produces a transaction with
  // `addr` as 0x0 and `misaligned_first` set to true, then a transaction with
  // `addr` as 0x4 and `misaligned_second` set to true. An unaligned 16-bit load
  // to 0x01 only produces a transaction with `addr` as 0x0 and
  // `misaligned_first` set to true, there is no second half.
  bool misaligned_first;
  bool misaligned_second;

  bool misaligned_first_saw_error;

  bool m_mode_access;
};
```

## Documentation

### doc/03_reference/load_store_unit.rst

```text
Load-Store Unit
===============
:file:`rtl/ibex_load_store_unit.sv`

The Load-Store Unit (LSU) of the core takes care of accessing the data memory.
Loads and stores of words (32 bit), half words (16 bit) and bytes (8 bit) are supported.

Any load or store will stall the ID/EX stage for at least a cycle to await the response (whether that is awaiting load data or a response indicating whether an error has been seen for a store).

Data-Side Memory Interface
--------------------------

Signals that are used by the LSU:

+----------------------------+-----------+-----------------------------------------------+
| Signal                     | Direction | Description                                   |
+============================+===========+===============================================+
| ``data_req_o``             | output    | Request valid, must stay high until           |
|                            |           | ``data_gnt_i`` is high for one cycle          |
+----------------------------+-----------+-----------------------------------------------+
| ``data_addr_o[31:0]``      | output    | Address, word aligned                         |
+----------------------------+-----------+-----------------------------------------------+
| ``data_we_o``              | output    | Write Enable, high for writes, low for        |
|                            |           | reads. Sent together with ``data_req_o``      |
+----------------------------+-----------+-----------------------------------------------+
| ``data_be_o[3:0]``         | output    | Byte Enable. Is set for the bytes to          |
|                            |           | write/read, sent together with ``data_req_o`` |
+----------------------------+-----------+-----------------------------------------------+
| ``data_wdata_o[31:0]``     | output    | Data to be written to memory, sent together   |
|                            |           | with ``data_req_o``                           |
+----------------------------+-----------+-----------------------------------------------+
| ``data_wdata_intg_o[6:0]`` | output    | Integrity bits to be written to memory, sent  |
|                            |           | together with ``data_req_o`` (not used unless |
|                            |           | the SecureIbex parameter is set)              |
+----------------------------+-----------+-----------------------------------------------+
| ``data_gnt_i``             | input     | The other side accepted the request.          |
|                            |           | Outputs may change in the next cycle.         |
+----------------------------+-----------+-----------------------------------------------+
| ``data_rvalid_i``          | input     | ``data_err_i`` and ``data_rdata_i`` hold      |
|                            |           | valid data when ``data_rvalid_i`` is high.    |
|                            |           | This signal will be high for exactly one      |
|                            |           | cycle per request.                            |
+----------------------------+-----------+-----------------------------------------------+
| ``data_err_i``             | input     | Error response from the bus or the memory:    |
|                            |           | request cannot be handled. High in case of an |
|                            |           | error.                                        |
+----------------------------+-----------+-----------------------------------------------+
| ``data_rdata_i[31:0]``     | input     | Data read from memory                         |
+----------------------------+-----------+-----------------------------------------------+
| ``data_rdata_intg_i[6:0]`` | input     | Integrity bits read from memory (ignored      |
|                            |           | unless the SecureIbex parameter is set)       |
+----------------------------+-----------+-----------------------------------------------+
...
Misaligned Accesses
-------------------

The LSU is able to handle misaligned memory accesses, meaning accesses that are not aligned on natural word boundaries.
However, it does so by performing two separate word-aligned accesses.
This means that at least two cycles are needed for misaligned loads and stores.

If an error response is received for the first transaction, the second transaction will still be issued.
The second transaction will then follow the normal bus protocol, but its response/data will be ignored.
If a new load/store request is received while waiting for an abandoned second part to complete, it will not be serviced until the state machine returns to IDLE.

.. _lsu-protocol:

Protocol
--------

The protocol that is used by the LSU to communicate with a memory works as follows:

1. The LSU provides a valid address in ``data_addr_o`` and sets ``data_req_o`` high. In the case of a store, the LSU also sets ``data_we_o`` high and configures ``data_be_o`` and ``data_wdata_o``. The memory then answers with a ``data_gnt_i`` set high as soon as it is ready to serve the request. This may happen in the same cycle as the request was sent or any number of cycles later.

2. After receiving a grant, the address may be changed in the next cycle by the LSU. In addition, the ``data_wdata_o``, ``data_we_o`` and ``data_be_o`` signals may be changed as it is assumed that the memory has already processed and stored that information.

3. The memory answers with a ``data_rvalid_i`` set high for exactly one cycle to signal the response from the bus or the memory using ``data_err_i`` and ``data_rdata_i`` (during the very same cycle). This may happen one or more cycles after the grant has been received. If ``data_err_i`` is low, the request could successfully be handled at the destination and in the case of a load, ``data_rdata_i`` contains valid data. If ``data_err_i`` is high, an error occurred in the memory system and the core will raise an exception.

4. When multiple granted requests are outstanding, it is assumed that the memory requests will be kept in-order and one ``data_rvalid_i`` will be signalled for each of them, in the order they were issued.
```
