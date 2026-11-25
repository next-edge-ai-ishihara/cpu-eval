# Implement `store_buffer`

Implement the complete `store_buffer` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module store_buffer` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      RVA: bit'(0),
// ...
      RVZiCbom: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
// ...
    cfg.PLEN = IS_XLEN32 ? 34 : 56;
// ...
    cfg.DCACHE_INDEX_WIDTH = DCACHE_INDEX_WIDTH;
    cfg.DCACHE_TAG_WIDTH = cfg.PLEN - DCACHE_INDEX_WIDTH;
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  // depth of store-buffers, this needs to be a power of two
  localparam logic [2:0] DEPTH_SPEC = 'd4;

  // if CVA6Cfg.DCacheType = cva6_config_pkg::WT
  // we can use a small commit queue since we have a write buffer in the dcache
  // we could in principle do without the commit queue in this case, but the timing degrades if we do that due
  // to longer paths into the commit stage
  // if CVA6Cfg.DCacheType = cva6_config_pkg::WB
  // allocate more space for the commit buffer to be on the safe side, this needs to be a power of two
  localparam logic [2:0] DEPTH_COMMIT = 'd4;
```

## Module declaration

```systemverilog
module store_buffer
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg        = config_pkg::cva6_cfg_empty,
    parameter type                   dcache_req_i_t = logic,
    parameter type                   dcache_req_o_t = logic,
    parameter type                   cbo_t          = logic
) (
    input logic clk_i,  // Clock
    input logic rst_ni,  // Asynchronous reset active low
    input logic flush_i,  // if we flush we need to pause the transactions on the memory
                          // otherwise we will run in a deadlock with the memory arbiter
    input logic stall_st_pending_i,  // Stall issuing non-speculative request
    output logic         no_st_pending_o, // non-speculative queue is empty (e.g.: everything is committed to the memory hierarchy)
    output logic         store_buffer_empty_o, // there is no store pending in neither the speculative unit or the non-speculative queue

    input  logic [11:0]  page_offset_i,         // check for the page offset (the last 12 bit if the current load matches them)
    output logic         page_offset_matches_o, // the above input page offset matches -> let the store buffer drain

    input logic commit_i,  // commit the instruction which was placed there most recently
    output logic commit_ready_o,  // commit queue is ready to accept another commit request
    output logic ready_o,  // the store queue is ready to accept a new request
// ...
    input logic valid_i,  // this is a valid store
    input  logic         valid_without_flush_i, // just tell if the address is valid which we are current putting and do not take any further action

    input  logic [CVA6Cfg.PLEN-1:0]  paddr_i,         // physical address of store which needs to be placed in the queue
    output logic [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    input logic [CVA6Cfg.XLEN-1:0] data_i,  // data which is placed in the queue
    input logic [(CVA6Cfg.XLEN/8)-1:0] be_i,  // byte enable in
    input logic [1:0] data_size_i,  // type of request we are making (e.g.: bytes to write)
    input cbo_t cbo_op_i,  // type of cache block operation

    // D$ interface
    input  dcache_req_o_t req_port_i,
    output dcache_req_i_t req_port_o
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
    // D$ data requests
    localparam type dcache_req_i_t = struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
      cbo_t                                  cbo_op;
    },

    localparam type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
      logic                                 data_error;
    },
```

### core/store_unit.sv

```systemverilog
        VALID_STORE: begin
          valid_o = 1'b1;
          // post this store to the store buffer if we are not flushing
          if (!flush_i && !sdtrig_store_stall_i) st_valid = 1'b1;

          st_valid_without_flush = 1'b1;

          // we have another request and its not an AMO (the AMO buffer only has depth 1)
          if ((valid_i && CVA6Cfg.RVA && !instr_is_amo) || (valid_i && !CVA6Cfg.RVA)) begin

            translation_req_o = 1'b1;
            state_d = VALID_STORE;
            pop_st_o = 1'b1;

            if (CVA6Cfg.MmuPresent && !dtlb_hit_i) begin
              state_d  = WAIT_TRANSLATION;
              pop_st_o = 1'b0;
            end

            if (!st_ready) begin
              state_d  = WAIT_STORE_READY;
              pop_st_o = 1'b0;
            end
            // if we do not have another request go back to idle
          end else begin
            state_d = IDLE;
          end
        end
// ...
    if (CVA6Cfg.RVZiCbom) begin
      case (lsu_ctrl_i.operation)
        ariane_pkg::CBO_INVAL: cbo_op_d = ariane_pkg::CBO_INVAL;
        ariane_pkg::CBO_CLEAN: cbo_op_d = ariane_pkg::CBO_CLEAN;
        ariane_pkg::CBO_FLUSH: cbo_op_d = ariane_pkg::CBO_FLUSH;
        default:               cbo_op_d = ariane_pkg::CBO_NONE;
      endcase
    end else begin
      cbo_op_d = ariane_pkg::CBO_NONE;
    end
// ...
  logic store_buffer_valid, amo_buffer_valid;
  logic store_buffer_ready, amo_buffer_ready;

  // multiplex between store unit and amo buffer
  assign store_buffer_valid = st_valid & (!CVA6Cfg.RVA || (amo_op_q == AMO_NONE));
  assign amo_buffer_valid = st_valid & (CVA6Cfg.RVA && (amo_op_q != AMO_NONE));

  assign st_ready = store_buffer_ready & amo_buffer_ready;

  // ---------------
  // Store Queue
  // ---------------
  store_buffer #(
      .CVA6Cfg       (CVA6Cfg),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .cbo_t         (cbo_t)
  ) store_buffer_i (
      .clk_i,
      .rst_ni,
      .flush_i,
      .stall_st_pending_i,
      .no_st_pending_o,
      .store_buffer_empty_o,
      .page_offset_i,
      .page_offset_matches_o,
      .commit_i,
      .commit_ready_o,
      .ready_o              (store_buffer_ready),
      .valid_i              (store_buffer_valid),
      // the flush signal can be critical and we need this valid
      // signal to check whether the page_offset matches or not,
      // functionally it doesn't make a difference whether we use
      // the correct valid signal or not as we are flushing
      // the whole pipeline anyway
      .valid_without_flush_i(st_valid_without_flush),
      .paddr_i,
      .rvfi_mem_paddr_o     (rvfi_mem_paddr_o),
      .data_i               (st_data_q),
      .cbo_op_i             (cbo_op_q),
      .be_i                 (st_be_q),
      .data_size_i          (st_data_size_q),
      .req_port_i           (req_port_i),
      .req_port_o           (req_port_o)
  );
```

## Related source code

### core/load_unit.sv

```systemverilog
  // page offset is defined as the lower 12 bits, feed through for address checker
  assign page_offset_o = lsu_ctrl_i.vaddr[11:0];
// ...
                // check if the page offset matches with a store, if it does then stall and wait
                if (!page_offset_matches_i) begin
                  // make a load request to memory
                  req_port_o.data_req = 1'b1;
```

## Documentation

### docs/03_cva6_design/ex_stage.md

```text
##### Load Unit {#par:load_unit}

The load unit takes care of all loads. Loads are issued as soon as
possible as they do not have any side effects. Before issuing a
load the load unit needs to check the store buffer for stores which are
not committed into the memory hierarchy yet in order to avoid loading
stale data. As a full comparison is quite costly only the lower 12 bit
(the page-offset where physical and virtual addresses are the same) are
compared. This has two major advantages: the comparison is only 12-bit
instead of 64-bit and therefore faster when done on the whole buffer
and the physical address is not needed which implies
that we don't need to wait for address translation to finish. If the
page offset matches with one of the outstanding stores the load unit
simply stalls and waits until the store buffer is drained. As an
improvement one could do some more elaborate data forwarding as the data
in the store buffer is the most up-to-date. This is not done at the
moment.
...
##### Store Buffer {#par:store_buffer}

The store buffer keeps track of all stores. It actually consists of two
buffers: One is for already committed instructions and one is for
outstanding instructions which are still speculative. On a flush only
the instruction which are already committed are persisted while the
speculative queue is completely emptied. To prevent buffer overflows the
two queues maintain a full flag. The full flag of the speculative queue
directly goes to the store unit, which will stall the LSU bypass module
and therefore not receive any more requests. On the contrast the full
signal of the commit queue goes to the commit stage. Commit stage will
stall if it the commit queue can't accept any new data items. On every
committed store the commit stage also asserts the `lsu_commit` signal
which will put the particular entry from the speculative queue into the
non-speculative (commit) queue.

As soon as a store is in the commit queue the queue will automatically
try to commit the oldest store in the queue to memory as soon as the
cache grants the request.

The store buffer only works with physical addresses. At the time when
they are committed the translation is already correct. For stores in the
speculative queue addresses are potentially not correct but this fact
will resolve if address translation data structures are updated as those
instructions will also automatically flush the whole speculative buffer.
```

### docs/design/design-manual/source/mmu.adoc

```text
[cols=",,",options="header",]
|=======================================================================
|Signal |Type |Description
|`address_index` |logic [DCACHE_INDEX_WIDTH-1:0] |Index of the Dcache
Line

|`address_tag` |logic [DCACHE_TAG_WIDTH-1:0] |Tag of the Dcache Line

|`data_wdata` |riscv::xlen_t |Data to write in the Dcache

|`data_wuser` |logic [DCACHE_USER_WIDTH-1:0] |data_wuser

|`data_req` |logic |Data Request

|`data_we` |logic |Data Write enabled

|`data_be` |logic [(riscv::XLEN/8)-1:0] |Data Byte enable

|`data_size` |logic [1:0] |Size of data

|`data_id` |logic [DCACHE_TID_WIDTH-1:0] |Data ID

|`kill_req` |logic |Kill the D cache request

|`tag_valid` |logic |Indicate that teh tag is valid
|=======================================================================
```
