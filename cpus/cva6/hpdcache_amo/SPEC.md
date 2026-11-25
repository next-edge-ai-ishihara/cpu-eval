# Implement `hpdcache_amo`

Implement the complete `hpdcache_amo` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_amo` definition in a single SystemVerilog code block, with no text outside the block.

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
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

```

## Module declaration

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

## Parent instantiation

### `rtl/src/hpdcache_uncached.sv`

```systemverilog
                    req_op_q.is_amo_lr: begin
                        if (mem_resp_read_valid_i) begin
                            //  set a new reservation
                            if (!rd_error)
                            begin
                                lrsc_uc_set      = 1'b1;
                                lrsc_rsrv_addr_d = req_addr_q;
                            end
                            //  in case of a memory error, do not make the reservation and
                            //  invalidate an existing one (if valid)
                            else begin
                                lrsc_uc_reset = 1'b1;
                            end

                            if (req_uc_q || rd_error || !req_hit) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_AMO_WRITE_DATA;
                            end
                        end
                    end
                    req_op_q.is_amo_sc: begin
                        if (mem_resp_write_valid_i) begin
                            automatic bit is_atomic;

                            is_atomic = mem_resp_write_i.mem_resp_w_is_atomic && !wr_error;
                            uc_sc_retcode_d = is_atomic ? AMO_SC_SUCCESS : AMO_SC_FAILURE;

                            if (req_uc_q || !is_atomic || !req_hit) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_AMO_WRITE_DATA;
                            end
                        end
                    end
                    req_op_q.is_amo_swap,
                    req_op_q.is_amo_add,
                    req_op_q.is_amo_and,
                    req_op_q.is_amo_or,
                    req_op_q.is_amo_xor,
                    req_op_q.is_amo_max,
                    req_op_q.is_amo_maxu,
                    req_op_q.is_amo_min,
                    req_op_q.is_amo_minu: begin
                        //  wait for both old data and write acknowledged were received
                        if ((mem_resp_read_valid_i && mem_resp_write_valid_i) ||
                            (mem_resp_read_valid_i && mem_resp_write_valid_q) ||
                            (mem_resp_read_valid_q && mem_resp_write_valid_i))
                        begin
                            if (req_uc_q || rsp_error_q || rd_error || wr_error ||
                                !req_hit)
                            begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_AMO_WRITE_DATA;
                            end
                        end
                    end
// ...
    assign amo_ld_data = prepare_amo_data_operand(amo_req_ld_data, req_size_q,
            req_addr_q, amo_need_sign_extend(req_op_q));
    assign amo_st_data = prepare_amo_data_operand(amo_req_st_data, req_size_q,
            req_addr_q, amo_need_sign_extend(req_op_q));

    hpdcache_amo amo_unit_i (
        .ld_data_i           (amo_ld_data),
        .st_data_i           (amo_st_data),
        .op_i                (req_op_q),
        .result_o            (amo_result)
    );

    assign data_amo_write_o = (uc_fsm_q == UC_AMO_WRITE_DATA);
    assign data_amo_write_enable_o = req_hit;
    assign data_amo_write_set_o = req_addr_q[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.setWidth];
    assign data_amo_write_size_o = req_size_q;
    assign data_amo_write_word_o = req_addr_q[HPDcacheCfg.wordByteIdxWidth +:
                                              HPDcacheCfg.clWordIdxWidth];
    assign data_amo_write_way_o = req_hit_way_q;

    assign amo_write_data = prepare_amo_data_result(amo_result, req_size_q);
    if (HPDcacheCfg.reqDataWidth >= 64) begin : gen_amo_ram_write_data_ge_64
        assign data_amo_write_data = {HPDcacheCfg.reqDataWidth/64{amo_write_data}};
    end else begin : gen_amo_ram_write_data_lt_64
        assign data_amo_write_data = amo_write_data;
    end
// ...
        assign data_amo_write_data_o = data_amo_write_data;

```

## Documentation

### `src/a-st-ext.adoc`

```text
Complex atomic memory operations on a single memory word or doubleword
are performed with the load-reserved (LR) and store-conditional (SC)
instructions. LR.W loads a word from the address in _rs1_, places the
sign-extended value in _rd_, and registers a _reservation set_—a set of
bytes that subsumes the bytes in the addressed word. SC.W conditionally
writes a word in _rs2_ to the address in _rs1_: the SC.W succeeds only
if the reservation is still valid and the reservation set contains the
bytes being written. If the SC.W succeeds, the instruction writes the
word in _rs2_ to memory, and it writes zero to _rd_. If the SC.W fails,
the instruction does not write to memory, and it writes a nonzero value
to _rd_.  For the purposes of memory protection, a failed SC.W may be
treated like a store.  Regardless of success or failure, executing an
SC.W instruction invalidates any reservation held by this hart. LR.D and
SC.D act analogously on doublewords and are only available on RV64. For
RV64, LR.W and SC.W sign-extend the value placed in _rd_.
...
The atomic memory operation (AMO) instructions perform read-modify-write
operations for multiprocessor synchronization and are encoded with an
R-type instruction format. These AMO instructions atomically load a data
value from the address in _rs1_, place the value into register _rd_,
apply a binary operator to the loaded value and the original value in
_rs2_, then store the result back to the original address in _rs1_. AMOs
can either operate on _doublewords_ (RV64 only) or _words_ in memory. For
RV64, 32-bit AMOs always sign-extend the value placed in _rd_, and
ignore the upper 32 bits of the original value of _rs2_.
...
The operations supported are swap, integer add, bitwise AND, bitwise OR,
bitwise XOR, and signed and unsigned integer maximum and minimum.

```
