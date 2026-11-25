# Implement `cva6_hpdcache_wrapper`

Implement the complete `cva6_hpdcache_wrapper` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cva6_hpdcache_wrapper` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module cva6_hpdcache_wrapper
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter int NumPorts = 4,
    parameter int NrHwPrefetchers = 4,

    parameter type hpdcache_mem_addr_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_be_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_wbuf_timecnt_t = logic,
    parameter type hpdcache_data_be_t = logic,

    localparam type hpdcache_nline_t = logic [HPDcacheCfg.nlineWidth-1:0]
)
//  }}}

//  Ports
//  {{{
(

    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,

    //  D$
    //  {{{
    //    Cache management
    // Data cache enable - CSR_REGFILE
    input  logic dcache_enable_i,
    // Data cache flush - CONTROLLER
    input  logic dcache_flush_i,
    // Flush acknowledge - CONTROLLER
    output logic dcache_flush_ack_o,
    // Load or store miss - PERF_COUNTERS
    output logic dcache_miss_o,

    // AMO request/response - EX_STAGE
    input  ariane_pkg::amo_req_t                 dcache_amo_req_i,
    output ariane_pkg::amo_resp_t                dcache_amo_resp_o,
    // Data cache input request/response ports - EX_STAGE
    input  dcache_req_i_t         [NumPorts-1:0] dcache_req_ports_i,
    output dcache_req_o_t         [NumPorts-1:0] dcache_req_ports_o,
    // Data cache scrubber enable - CSR_REGFILE
    input  logic                                 dcache_scrub_enable_i,
    // Data cache scrubber period - CSR_REGFILE
    input  logic                  [         5:0] dcache_scrub_period_i,
    // Data cache scrub cycle - CSR_REGFILE
    output logic                                 dcache_scrub_cycle_o,
    // Data cache data error corrected - CSR_REGFILE
    output logic                                 dcache_dat_cor_err_o,
    // Data cache data error detected but not corrected - CSR_REGFILE
    output logic                                 dcache_dat_unc_err_o,
    // Data cache tag error corrected - CSR_REGFILE
    output logic                                 dcache_dir_cor_err_o,
    // Data cache tag error detected but not corrected - CSR_REGFILE
    output logic                                 dcache_dir_unc_err_o,

    // Write buffer status - EX_STAGE
    output logic wbuffer_empty_o,
    output logic wbuffer_not_ni_o,

    //  Hardware memory prefetcher configuration
    input  logic [NrHwPrefetchers-1:0]       hwpf_base_set_i,
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_base_i,
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_base_o,
    input  logic [NrHwPrefetchers-1:0]       hwpf_param_set_i,
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_param_i,
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_param_o,
    input  logic [NrHwPrefetchers-1:0]       hwpf_throttle_set_i,
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_i,
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_o,
    output logic [               63:0]       hwpf_status_o,

    input  logic              dcache_mem_req_read_ready_i,
    output logic              dcache_mem_req_read_valid_o,
    output hpdcache_mem_req_t dcache_mem_req_read_o,

    output logic                 dcache_mem_resp_read_ready_o,
    input  logic                 dcache_mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t dcache_mem_resp_read_i,

    input logic            dcache_mem_resp_read_inval_i,
    input hpdcache_nline_t dcache_mem_resp_read_inval_nline_i,

    input  logic              dcache_mem_req_write_ready_i,
    output logic              dcache_mem_req_write_valid_o,
    output hpdcache_mem_req_t dcache_mem_req_write_o,

    input  logic                dcache_mem_req_write_data_ready_i,
    output logic                dcache_mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t dcache_mem_req_write_data_o,

    output logic                 dcache_mem_resp_write_ready_o,
    input  logic                 dcache_mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t dcache_mem_resp_write_i
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
  dcache_req_i_t [NumPorts-1:0] dcache_req_to_cache;
  dcache_req_o_t [NumPorts-1:0] dcache_req_from_cache;

  // D$ request
  // Since ZCMT is only enabled for embedded class so MMU should be disabled.
  // Cache port 0 is being utilized in implicit read access in ZCMT extension.
  if (CVA6Cfg.RVZCMT & ~(CVA6Cfg.MmuPresent)) begin
    assign dcache_req_to_cache[0] = dcache_req_ports_id_cache;
  end else begin
    assign dcache_req_to_cache[0] = dcache_req_ports_ex_cache[0];
  end
  assign dcache_req_to_cache[1] = dcache_req_ports_ex_cache[1];
  assign dcache_req_to_cache[2] = dcache_req_ports_acc_cache[0];
  assign dcache_req_to_cache[3] = dcache_req_ports_ex_cache[2].data_req ? dcache_req_ports_ex_cache [2] :
                                                                          dcache_req_ports_acc_cache[1];
```

### core/cache_subsystem/cva6_hpdcache_subsystem.sv

```systemverilog
  //    0: Page-Table Walk (PTW)
  //    1: Load unit
  //    2: Accelerator load
  //    3: Store/AMO
  //    .
  //    .
  //    .
  //    NumPorts: Hardware Memory Prefetcher (hwpf)
  localparam int HPDCACHE_NREQUESTERS = NumPorts + 1;

// ...

  cva6_hpdcache_wrapper #(
      .CVA6Cfg(CVA6Cfg),
      .HPDcacheCfg(HPDcacheCfg),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .NumPorts(NumPorts),
      .NrHwPrefetchers(NrHwPrefetchers),
      .hpdcache_mem_addr_t(hpdcache_mem_addr_t),
      .hpdcache_mem_id_t(hpdcache_mem_id_t),
      .hpdcache_mem_data_t(hpdcache_mem_data_t),
      .hpdcache_mem_be_t(hpdcache_mem_be_t),
      .hpdcache_mem_req_t(hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t(hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_data_word_t(hpdcache_data_word_t),
      .hpdcache_req_data_t(hpdcache_req_data_t),
      .hpdcache_req_be_t(hpdcache_req_be_t),
      .hpdcache_req_sid_t(hpdcache_req_sid_t),
      .hpdcache_req_tid_t(hpdcache_req_tid_t),
      .hpdcache_tag_t(hpdcache_tag_t),
      .hpdcache_req_t(hpdcache_req_t),
      .hpdcache_rsp_t(hpdcache_rsp_t),
      .hpdcache_wbuf_timecnt_t(hpdcache_wbuf_timecnt_t),
      .hpdcache_data_be_t(hpdcache_data_be_t)
  ) i_dcache (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .dcache_enable_i(dcache_enable_i),
      .dcache_flush_i(dcache_flush_i),
      .dcache_flush_ack_o(dcache_flush_ack_o),
      .dcache_miss_o(dcache_miss_o),
      .dcache_amo_req_i(dcache_amo_req_i),
      .dcache_amo_resp_o(dcache_amo_resp_o),
      .dcache_req_ports_i(dcache_req_ports_i),
      .dcache_req_ports_o(dcache_req_ports_o),
      .dcache_scrub_enable_i,
      .dcache_scrub_period_i,
      .dcache_scrub_cycle_o,
      .dcache_dat_cor_err_o,
      .dcache_dat_unc_err_o,
      .dcache_dir_cor_err_o,
      .dcache_dir_unc_err_o,
      .wbuffer_empty_o(wbuffer_empty_o),
      .wbuffer_not_ni_o(wbuffer_not_ni_o),
      .hwpf_base_set_i(hwpf_base_set_i),
      .hwpf_base_i(hwpf_base_i),
      .hwpf_base_o(hwpf_base_o),
      .hwpf_param_set_i(hwpf_param_set_i),
      .hwpf_param_i(hwpf_param_i),
      .hwpf_param_o(hwpf_param_o),
      .hwpf_throttle_set_i(hwpf_throttle_set_i),
      .hwpf_throttle_i(hwpf_throttle_i),
      .hwpf_throttle_o(hwpf_throttle_o),
      .hwpf_status_o(hwpf_status_o),

      .dcache_mem_req_read_ready_i(dcache_read_ready),
      .dcache_mem_req_read_valid_o(dcache_read_valid),
      .dcache_mem_req_read_o(dcache_read),

      .dcache_mem_resp_read_ready_o(dcache_read_resp_ready),
      .dcache_mem_resp_read_valid_i(dcache_read_resp_valid),
      .dcache_mem_resp_read_i(dcache_read_resp),

      .dcache_mem_resp_read_inval_i(dcache_resp_read_inval),
      .dcache_mem_resp_read_inval_nline_i(dcache_resp_read_inval_nline),

      .dcache_mem_req_write_ready_i(dcache_write_ready),
      .dcache_mem_req_write_valid_o(dcache_write_valid),
      .dcache_mem_req_write_o(dcache_write),

      .dcache_mem_req_write_data_ready_i(dcache_write_data_ready),
      .dcache_mem_req_write_data_valid_o(dcache_write_data_valid),
      .dcache_mem_req_write_data_o(dcache_write_data),

      .dcache_mem_resp_write_ready_o(dcache_write_resp_ready),
      .dcache_mem_resp_write_valid_i(dcache_write_resp_valid),
      .dcache_mem_resp_write_i(dcache_write_resp)
  );
```

## Dependency declarations

### core/cache_subsystem/cva6_hpdcache_if_adapter.sv

```systemverilog
module cva6_hpdcache_if_adapter
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter bit InvalidateOnFlush = 1'b0,
    parameter bit IsLoadPort = 1'b1
)
//  }}}

//  Ports
//  {{{
(
    //  Clock and active-low reset pins
    input logic clk_i,
    input logic rst_ni,

    //  Port ID
    input hpdcache_req_sid_t hpdcache_req_sid_i,

    //  Request/response ports from/to the CVA6 core
    input  dcache_req_i_t         cva6_req_i,
    output dcache_req_o_t         cva6_req_o,
    input  ariane_pkg::amo_req_t  cva6_amo_req_i,
    output ariane_pkg::amo_resp_t cva6_amo_resp_o,

    //  Dcache flush signal
    input  logic cva6_dcache_flush_i,
    output logic cva6_dcache_flush_ack_o,

    //  Request port to the L1 Dcache
    output logic                        hpdcache_req_valid_o,
    input  logic                        hpdcache_req_ready_i,
    output hpdcache_req_t               hpdcache_req_o,
    output logic                        hpdcache_req_abort_o,
    output hpdcache_tag_t               hpdcache_req_tag_o,
    output hpdcache_pkg::hpdcache_pma_t hpdcache_req_pma_o,

    //  Response port from the L1 Dcache
    input logic          hpdcache_rsp_valid_i,
    input hpdcache_rsp_t hpdcache_rsp_i
);
```

### rtl/src/hpdcache.sv

```systemverilog
module hpdcache
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type wbuf_timecnt_t = logic,

    //  Request Interface Definitions
    //  {{{
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    //  }}}

    //  Memory Interface Definitions
    //  {{{
    parameter type hpdcache_mem_addr_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_be_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    //  }}}

    localparam type hpdcache_nline_t = logic [HPDcacheCfg.nlineWidth-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Clock and reset signals
    input  logic                          clk_i,
    input  logic                          rst_ni,

    //      Force the write buffer to send all pending writes
    input  logic                          wbuf_flush_i,

    //      Core request interface
    //         1st cycle
    input  logic                          core_req_valid_i [HPDcacheCfg.u.nRequesters],
    output logic                          core_req_ready_o [HPDcacheCfg.u.nRequesters],
    input  hpdcache_req_t                 core_req_i       [HPDcacheCfg.u.nRequesters],
    //         2nd cycle
    input  logic                          core_req_abort_i [HPDcacheCfg.u.nRequesters],
    input  hpdcache_tag_t                 core_req_tag_i   [HPDcacheCfg.u.nRequesters],
    input  hpdcache_pma_t                 core_req_pma_i   [HPDcacheCfg.u.nRequesters],

    //      Core response interface
    output logic                          core_rsp_valid_o [HPDcacheCfg.u.nRequesters],
    output hpdcache_rsp_t                 core_rsp_o       [HPDcacheCfg.u.nRequesters],

    //      Read / Invalidation memory interface
    input  logic                          mem_req_read_ready_i,
    output logic                          mem_req_read_valid_o,
    output hpdcache_mem_req_t             mem_req_read_o,

    output logic                          mem_resp_read_ready_o,
    input  logic                          mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_read_i,

    input  logic                          mem_resp_read_inval_i,
    input  hpdcache_nline_t               mem_resp_read_inval_nline_i,

    //      Write memory interface
    input  logic                          mem_req_write_ready_i,
    output logic                          mem_req_write_valid_o,
    output hpdcache_mem_req_t             mem_req_write_o,

    input  logic                          mem_req_write_data_ready_i,
    output logic                          mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t           mem_req_write_data_o,

    output logic                          mem_resp_write_ready_o,
    input  logic                          mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_write_i,

    //      Performance events
    output logic                          evt_cache_write_miss_o,
    output logic                          evt_cache_read_miss_o,
    output logic                          evt_cache_dir_unc_err_o,
    output logic                          evt_cache_dir_cor_err_o,
    output logic                          evt_cache_dat_unc_err_o,
    output logic                          evt_cache_dat_cor_err_o,
    output logic                          evt_scrub_complete_o,
    output logic                          evt_uncached_req_o,
    output logic                          evt_cmo_req_o,
    output logic                          evt_write_req_o,
    output logic                          evt_read_req_o,
    output logic                          evt_prefetch_req_o,
    output logic                          evt_req_on_hold_o,
    output logic                          evt_rtab_rollback_o,
    output logic                          evt_stall_refill_o,
    output logic                          evt_stall_o,

    //      Status interface
    output logic                          wbuf_empty_o,

    //      Configuration interface
    input  logic                          cfg_enable_i,
    input  wbuf_timecnt_t                 cfg_wbuf_threshold_i,
    input  logic                          cfg_wbuf_reset_timecnt_on_write_i,
    input  logic                          cfg_wbuf_sequential_waw_i,
    input  logic                          cfg_wbuf_inhibit_write_coalescing_i,
    input  logic                          cfg_prefetch_updt_plru_i,
    input  logic                          cfg_error_on_cacheable_amo_i,
    input  logic                          cfg_rtab_single_entry_i,
    input  logic                          cfg_default_wb_i,
    input  logic                          cfg_scrub_enable_i,
    input  logic unsigned [5:0]           cfg_scrub_period_i,
    input  logic                          cfg_scrub_restart_i
);
```

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

### rtl/src/hwpf_stride/hwpf_stride_wrapper.sv

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

## Related source code

### rtl/lint/hpdcache_lint.sv

```systemverilog
      .cfg_enable_i                       (1'b1),
      .cfg_wbuf_threshold_i               (3'd2),
      .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
      .cfg_wbuf_sequential_waw_i          (1'b0),
      .cfg_wbuf_inhibit_write_coalescing_i(1'b0),
      .cfg_prefetch_updt_plru_i           (1'b1),
      .cfg_error_on_cacheable_amo_i       (1'b0),
      .cfg_rtab_single_entry_i            (1'b0),
      .cfg_default_wb_i                   (1'b0),
      .cfg_scrub_enable_i                 (1'b0),
      .cfg_scrub_period_i                 (6'd10),
      .cfg_scrub_restart_i                (1'b1)
  );
```

## Documentation

### docs/source/interface.rst

```rst
   * - ``core_req_i.sid``
     - Requester
     - The identification tag for the requester. It shall be identical to the
       index of the request port bound to that requester
```
