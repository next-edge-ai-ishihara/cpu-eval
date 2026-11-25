# Implement `hpdcache_rtab`

Implement the complete `hpdcache_rtab` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_rtab` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
    userCfg.rtabEntries = 4;

```

### `core/cache_subsystem/cva6_hpdcache_wrapper.sv`

```systemverilog
      .cfg_rtab_single_entry_i            (1'b0),

```

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    function automatic logic is_load(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_LOAD: return 1'b1;
            default:           return 1'b0;
        endcase
    endfunction
// ...
    function automatic logic is_cmo_prefetch(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_PREFETCH);
    endfunction
// ...
    //  Definition Replay Table (RTAB) dependencies
    //  {{{
    typedef struct packed {
        logic mshr_hit;
        logic mshr_full;
        logic mshr_ready;
        logic write_miss;
        logic wbuf_hit;
        logic wbuf_not_ready;
        logic dir_unavailable;
        logic dir_fetch;
        logic flush_hit;
        logic flush_not_ready;
        logic pend_trans;
    } hpdcache_rtab_deps_t;

```

## Module declaration

```systemverilog
module hpdcache_rtab
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_way_t = logic,

    parameter type hpdcache_req_addr_t = logic,

    parameter type rtab_ptr_t = logic,
    parameter type rtab_cnt_t = logic,
    parameter type rtab_entry_t = logic
)
//  }}}

//  Ports
//  {{{
(
    //  Clock and reset signals
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Global control signals
    output logic                  empty_o,  // RTAB is empty
    output logic                  full_o,   // RTAB is full
    output logic                  fence_o,  // There is a pending instruction with fence in the RTAB

    //  Check RTAB signals
    //     This interface allows to check if there is an address-overlapping
    //     request in the RTAB with respect to the given nline.
    input  logic                  check_i,          // Check for hit (nline) in the RTAB
    input  hpdcache_nline_t       check_nline_i,
    output logic                  check_hit_o,

    //  Allocate signals
    //     This interface allows to allocate a new request in a new linked list
    input  logic                  alloc_i,
    input  logic                  alloc_and_link_i,
    input  rtab_entry_t           alloc_req_i,
    input  hpdcache_rtab_deps_t   alloc_deps_i,

    //  Pop signals
    //     This interface allows to read (and remove) a request from the RTAB
    output logic                  pop_try_valid_o,  // Request ready to be replayed
    input  logic                  pop_try_i,
    output rtab_entry_t           pop_try_req_o,
    output rtab_ptr_t             pop_try_ptr_o,

    //  Pop Commit signals
    //     This interface allows to actually remove a popped request
    input  logic                  pop_commit_i,
    input  rtab_ptr_t             pop_commit_ptr_i,

    //  Pop Rollback signals
    //     This interface allows to put back a popped request
    input  logic                  pop_rback_i,
    input  rtab_ptr_t             pop_rback_ptr_i,

    //  Control signals from/to WBUF
    output hpdcache_req_addr_t    wbuf_addr_o,      // address to check against ongoing writes
    output logic                  wbuf_is_read_o,   // monitored request is read
    input  logic                  wbuf_hit_open_i,  // Hit on open entry in the write buf
    input  logic                  wbuf_hit_pend_i,  // Hit on pend entry in the write buf
    input  logic                  wbuf_hit_sent_i,  // Hit on sent entry in the write buf
    input  logic                  wbuf_not_ready_i, // Write buffer cannot accept the write

    //  Control signals from the Miss Handler
    input  logic                  miss_ready_i,     // Miss Handler is ready

    //  Control signals from the Refill Handler
    input  logic                  refill_i,           // Active refill
    input  logic                  refill_is_error_i,  // Active refill has error bit set
    input  hpdcache_nline_t       refill_nline_i,     // Cache-line index being refilled
    input  hpdcache_way_t         refill_way_index_i, // Way index being refilled

    //  Control signals from the Flush Controller
    input  logic                  flush_ack_i,        // Flush acknowledged
    input  hpdcache_nline_t       flush_ack_nline_i,  // Cache-line flush being acknowledged
    input  logic                  flush_ready_i,      // Flush controller is available

    //  Configuration parameters
    input  logic                  cfg_single_entry_i, // Enable only one entry of the table

    //  Global control signals
    input  logic                  no_pend_trans_i
);

```

## Parent instantiation

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
    //  Definition of types and constants
    //  {{{
    typedef logic [$clog2(HPDcacheCfg.u.rtabEntries)-1:0] rtab_ptr_t;
    typedef logic [$clog2(HPDcacheCfg.u.rtabEntries):0]   rtab_cnt_t;

    //    Extended request type
    typedef struct packed {
        hpdcache_req_t req;

        // Replayed from the RTAB
        logic from_rtab;

        // Error tag: Used for replayed requests that has been tagged as an error
        // (e.g. write miss with allocation whose read response was an error)
        logic is_error;

        // Error scrubbing request
        //   - Do not trigger miss request to the memory in case of miss
        //   - Do not update the access state (e.g. LRU bits)
        //   - Address contains the indexes of the way, set and word
        logic err_scrubbing;
    } hpdcache_req_x_t;

    //    RTAB entry definition
    typedef struct packed {
        hpdcache_req_x_t req;
        hpdcache_way_t   way_fetch;
    } rtab_entry_t;
// ...
        .st1_rtab_pend_trans_o              (st1_rtab_deps.pend_trans),
// ...
    // No pending transaction across different handlers
    assign st1_no_pend_trans = st2_empty
                               & rtab_empty_o
                               & wbuf_empty_i
                               & mshr_empty_i
                               & flush_empty_i;
    assign rtab_no_pend_trans = ctrl_empty_o
                               & wbuf_empty_i
                               & mshr_empty_i
                               & flush_empty_i;
// ...
    rtab_entry_t st1_alloc_rtab;

    hpdcache_1hot_to_binary #(
        .N     (HPDcacheCfg.u.ways)
    ) dir_hit_way_encoder_i(
        .val_i (st1_dir_hit_way),
        .val_o (st1_dir_hit_way_index)
    );

    hpdcache_1hot_to_binary #(
        .N     (HPDcacheCfg.u.ways)
    ) refill_way_encoder_i(
        .val_i (refill_way_i),
        .val_o (refill_way_index)
    );

    assign st1_alloc_rtab = '{
        req       : st1_req,
        way_fetch : st1_dir_hit_way_index
    };

    hpdcache_rtab #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_nline_t                   (hpdcache_nline_t),
        .hpdcache_way_t                     (hpdcache_way_t),
        .hpdcache_req_addr_t                (hpdcache_req_addr_t),
        .rtab_ptr_t                         (rtab_ptr_t),
        .rtab_cnt_t                         (rtab_cnt_t),
        .rtab_entry_t                       (rtab_entry_t)
    ) hpdcache_rtab_i(
        .clk_i,
        .rst_ni,

        .empty_o                            (rtab_empty_o),
        .full_o                             (rtab_full),
        .fence_o                            (rtab_fence),

        .check_i                            (st1_rtab_check),
        .check_nline_i                      (st1_req_nline),
        .check_hit_o                        (st1_rtab_check_hit),

        .alloc_i                            (st1_rtab_alloc),
        .alloc_and_link_i                   (st1_rtab_alloc_and_link),
        .alloc_req_i                        (st1_alloc_rtab),
        .alloc_deps_i                       (st1_rtab_deps),

        .pop_try_valid_o                    (st0_rtab_pop_try_valid),
        .pop_try_i                          (st0_rtab_pop_try_ready),
        .pop_try_req_o                      (st0_rtab_pop_try_req),
        .pop_try_ptr_o                      (st0_rtab_pop_try_ptr),

        .pop_commit_i                       (st1_rtab_pop_try_commit),
        .pop_commit_ptr_i                   (st1_rtab_pop_try_ptr_q),

        .pop_rback_i                        (st1_rtab_pop_try_rback),
        .pop_rback_ptr_i                    (st1_rtab_pop_try_ptr_q),

        .wbuf_addr_o                        (wbuf_rtab_addr_o),
        .wbuf_is_read_o                     (wbuf_rtab_is_read_o),
        .wbuf_hit_open_i                    (wbuf_rtab_hit_open_i),
        .wbuf_hit_pend_i                    (wbuf_rtab_hit_pend_i),
        .wbuf_hit_sent_i                    (wbuf_rtab_hit_sent_i),
        .wbuf_not_ready_i                   (wbuf_rtab_not_ready_i),

        .miss_ready_i                       (st1_mshr_alloc_ready_i),

        .refill_i                           (refill_updt_rtab_i),
        .refill_is_error_i,
        .refill_nline_i,
        .refill_way_index_i                 (refill_way_index),

        .flush_ack_i                        (flush_ack_i),
        .flush_ack_nline_i                  (flush_ack_nline_i),
        .flush_ready_i                      (flush_alloc_ready_i),

        .cfg_single_entry_i                 (cfg_rtab_single_entry_i),

        .no_pend_trans_i                    (rtab_no_pend_trans)
    );

```

## Dependency declarations

### `rtl/include/hpdcache_typedef.svh`

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

```

### `rtl/src/hpdcache_wbuf.sv`

```systemverilog
    //  Replay hit interface
    input  wbuf_addr_t            replay_addr_i,
    input  logic                  replay_is_read_i,
    output logic                  replay_open_hit_o,
    output logic                  replay_pend_hit_o,
    output logic                  replay_sent_hit_o,
    output logic                  replay_not_ready_o,

```

## Related source code

### `rtl/src/hpdcache_wbuf.sv`

```systemverilog
    //  Check if there is a match between the replay address and the tag of one
    //  of the used slots in the write buffer directory
    generate
        for (gen_i = 0; gen_i < WBUF_DIR_NENTRIES; gen_i++) begin : gen_replay_match
            assign replay_match[gen_i] = replay_is_read_i ?
                    /* replay is read: compare address block tag (e.g. cache line) */
                    (wbuf_tag_to_match_addr(wbuf_dir_q[gen_i].tag) ==
                        replay_addr_i[HPDcacheCfg.u.paWidth - 1:
                                      HPDcacheCfg.u.paWidth - WBUF_READ_MATCH_WIDTH]) :
                    /* replay is write: compare wbuf tag */
                    (wbuf_dir_q[gen_i].tag ==
                        replay_addr_i[HPDcacheCfg.u.paWidth - 1:
                                      HPDcacheCfg.u.paWidth - WBUF_TAG_WIDTH]);

            assign replay_open_hit[gen_i] = replay_match[gen_i] & wbuf_dir_open_bv[gen_i];
            assign replay_pend_hit[gen_i] = replay_match[gen_i] & wbuf_dir_pend_bv[gen_i];
            assign replay_sent_hit[gen_i] = replay_match[gen_i] & wbuf_dir_sent_bv[gen_i];
        end
    endgenerate

    assign replay_open_hit_o = |replay_open_hit;
    assign replay_pend_hit_o = |replay_pend_hit;
    assign replay_sent_hit_o = |replay_sent_hit;

    always_comb
    begin : replay_wbuf_not_ready_comb
        replay_not_ready_o = 1'b0;
        if (replay_pend_hit_o) begin
            replay_not_ready_o = 1'b1;
        end else if (replay_sent_hit_o && cfg_sequential_waw_i) begin
            replay_not_ready_o = 1'b1;
        end else if (!replay_open_hit_o && (!wbuf_dir_free || !wbuf_data_free)) begin
            replay_not_ready_o = 1'b1;
        end
    end

```

### `rtl/src/hpdcache_ctrl_pe.sv`

```systemverilog
    //      Determine if the new request is a "fence". Here, fence instructions are considered those
    //      that need to be executed in program order (irrespectively of addresses). This means that
    //      all memory operations arrived before the "fence" instruction need to be finished, and
    //      only then the "fence" instruction is executed. In the same manner, all instructions
    //      following the "fence" need to wait the completion of this last before being executed.
    assign st1_fence = st1_req_is_amo_i         |
                       st1_req_is_uncacheable_i |
                       st1_req_is_cmo_fence_i   |
                       st1_req_is_cmo_inval_i   |
                       st1_req_is_cmo_flush_i;

    //      When allocating an entry in the RTAB for fence-like operations, make sure that it cannot
    //      be replayed until all pending operations are completed
    assign st1_rtab_pend_trans_o = st1_fence;

```

## Documentation

### `docs/source/architecture.rst`

```text
Replay Table (RTAB)
-------------------

The RTAB is implemented as an array of linked lists. It is a fully-associative
multi-entry buffer where each valid entry belongs to a linked list. It is
implemented in flip-flops. Each linked lists contain requests that target the
same cacheline. There can be multiple linked lists but each shall target a
different cacheline. The head of each linked list contains the oldest request
while the tail contains the newest request. The requests are processed from the
head to the tail to respect the rules explained in section :ref:`sec_mcrs`.

Regarding the pop operation (extracting a ready request from the replay table),
it is possible that once the request is replayed, some of the resources it needs
are again busy. Therefore, the request needs to be put on-hold again. In this
case, the request needs to keep its position as head of the linked list. This is
to preserve the program order. This is the reason why the pop operation is
implemented as a two-step operation: pop then commit, or pop then rollback. The
commit operation allows to actually retire the request, while the rollback
allows to undo the pop.

...

RTAB operations
'''''''''''''''

The RTAB implements the following operations:

+--------------------------+----------------------------------+
| **Operation**            | **Description**                  |
+==========================+==================================+
| ``rtab_alloc``           | Allocate a new linked list       |
+--------------------------+----------------------------------+
| ``rtab_alloc_and_link``  | Allocate a new entry and link it |
|                          | to an existing linked list       |
+--------------------------+----------------------------------+
| ``rtab_pop_try``         | Get a ready request from one of  |
|                          | the linked list (without         |
|                          | actually removing it from the    |
|                          | list)                            |
+--------------------------+----------------------------------+
| ``rtab_pop_commit``      | Actually remove a popped request |
|                          | from the list                    |
+--------------------------+----------------------------------+
| ``rtab_pop_rollback``    | Rollback a previously popped     |
|                          | request (with a possible update  |
|                          | of its dependencies)             |
+--------------------------+----------------------------------+
| ``rtab_find_ready``      | Find a ready request among the   |
|                          | heads of valid linked lists      |
+--------------------------+----------------------------------+
| ``rtab_update_deps``     | Update the dependency bits of    |
|                          | valid requests                   |
+--------------------------+----------------------------------+
| ``rtab_find_empty``      | Find an empty request            |
+--------------------------+----------------------------------+
| ``rtab_is_full``         | Is the RTAB full ?               |
+--------------------------+----------------------------------+
| ``rtab_is_empty``        | Is the RTAB empty ?              |
+--------------------------+----------------------------------+
| ``rtab_match_tail``      | Find a 'tail' entry matching a   |
|                          | given nline                      |
+--------------------------+----------------------------------+
| ``rtab_match``           | Find an entry matching a given   |
|                          | nline                            |
+--------------------------+----------------------------------+

The C-like functions below briefly describe the algorithms implemented in the
RTL code of the RTAB.

...

The following function is called by the cache controller when it detects that
one or more of the conditions in :ref:`tab_onhold` is met, and the request shall
be put on hold.

.. code:: c

   int rtab_alloc(req_t r, deps_t d)
   {
     int index = rtab_find_empty();
     rtab[index] = {
       valid     : 1,
       deps      : d,
       ll_head   : 1,
       ll_tail   : 1,
       ll_next   : 0,
       request   : r
     };
     return index;
   }

The following function is called by the cache controller when it detects that
the request in the pipeline targets the same cacheline that one or more on-hold
requests. In this case, the request is linked in the tail of the corresponding list in the RTAB.

.. code:: c

   int rtab_alloc_and_link(req_t r)
   {
     int index = rtab_find_empty();
     int match = rtab_match_tail(get_nline(r));

     //  replace the tail of the linked list
     rtab[match].ll_tail = 0;

     //  make the next pointer of the old tail to point to the new entry
     rtab[match].ll_next = index;

     //  add the new request as the tail of the linked list
     rtab[index] = {
       valid     : 1,
       deps      : 0,
       ll_head   : 0,
       ll_tail   : 1,
       ll_next   : 0,
       request   : r
     };

     return index;
   }

...

The following function is called by the cache controller to select a ready
request (dependencies have been resolved) from the RTAB.

.. code:: c

   req_t rtab_pop_try()
   {
     //  These are global states (preserved between function calls)
     static int pop_state = HEAD;
     static int last = 0;
     static int next = 0;

     int index;

     //  Brief description of the following code:
     //    The rtab_pop_try function tries to retire all the requests of a given
     //    linked list. Then it passes to another one.
     switch (pop_state) {
       case HEAD:
         //  Find a list whose head request is ready
         //  (using a round-robin policy)
         index = rtab_find_ready(last);

         //  If there is no ready entry, or there is an ongoing rollback,
         //  return an invalid index
         if ((index == -1) || rtab_pop_rollback)
           return -1;

         //  Update the pointer to the last linked list served
         last = index;

         //  If the list have more than one request, the next time this function
         //  is called, serve the next request of the list
         if (!rtab[index].ll_tail) {
            next = rtab[index].ll_next;
            pop_state = NEXT;
         }

         //  Temporarily unset the head bit. This is to prevent the
         //  request to be rescheduled.
         rtab[index].ll_head = 0;
         break;

       case NEXT:
         index = next;

         //  If there is an ongoing rollback, abandon the current pop
         if (rtab_pop_rollback) {
            pop_state = HEAD;
            return -1;
         }

         //  If the list have more than one request, the next time this function
         //  is called, serve the next request of the list
         if (!rtab[next].ll_tail) {
            next = rtab[index].ll_next;
            pop_state = NEXT;
         }
         //  It it is the last element of the list, return to the HEAD state
         else {
            pop_state = HEAD;
         }

         //  Temporarily unset the head bit. This is to prevent the
         //  request to be rescheduled.
         rtab[index].ll_head = 0;
     }

     //  Pop the selected request
     return rtab[index].req;
   }

...

The following function is called by the cache controller when the replayed
request is retired (processed).

.. code:: c

   void rtab_pop_commit(int index)
   {
     rtab[index].valid = 0;
   }

The following function is called by the cache controller when the replayed
request cannot be retired because, again, one or more of the conditions in
:ref:`tab_onhold` is met. In this case, the request is restored into the RTAB
with updated dependency bits. The restored request keeps the same position it
its corresponding linked list to respect the program execution order.

.. code:: c

   void rtab_pop_rollback(int index, bitvector deps)
   {
     rtab[index].ll_head = 1;
     rtab[index].deps    = deps;
   }


The following function is used to find a linked list whose head request can be
replayed (dependencies have been resolved).

.. code:: c

   int rtab_find_ready(int last)
   {
     // choose a ready entry using a round-robin policy
     int i = (last + 1) % RTAB_NENTRIES;
     for (;;) {
       //  ready entry found
       if (rtab[i].valid && rtab[i].ll_head && (rtab[i].deps == 0))
         return i;

       //  there is no ready entry
       if (i == last)
         return -1;

       i = (i + 1) % RTAB_NENTRIES;
     }
   }

...

The following function is called by the miss handler and the write buffer on the
completion of any pending transaction. It allows to update the dependency bits
of any matching request (with the same cacheline address) in the RTAB.

.. code:: c

   void rtab_update_deps(nline_t nline, bitvector deps)
   {
     int index = rtab_match(nline);
     if (index != -1) {
       rtab[index].deps = deps;
     }
   }


The following utility functions are used by functions above.

.. code:: c

   int rtab_find_empty()
   {
     for (int i = 0; i < RTAB_NENTRIES; i++)
       if (!rtab[i].valid)
         return i;

     return -1;
   }

.. code:: c

   bool rtab_is_full()
   {
     return (rtab_find_empty() == -1);
   }


.. code:: c

   int rtab_is_empty()
   {
     for (int i = 0; i < RTAB_NENTRIES; i++)
       if (rtab[i].valid)
         return 0;

     return 1;
   }


.. code:: c

   int rtab_match_tail(nline_t nline)
   {
     for (int i = 0; i < RTAB_NENTRIES; i++)
       if (rtab[i].valid && get_nline(rtab[i].req) == nline && rtab[i].ll_tail)
         return i;

     return -1;
   }


.. code:: c

   int rtab_match(nline_t nline)
   {
     for (int i = 0; i < RTAB_NENTRIES; i++)
       if (rtab[i].valid && get_nline(rtab[i].req) == nline)
         return i;

     return -1;
   }

```

## Additional requirement

After a rollback through `pop_rback_i`, a later `pop_try_req_o` for that entry returns the `alloc_req_i` value presented with the rollback, including its `way_fetch` field.
