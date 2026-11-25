# Implement `el2_dec`

Implement the complete `el2_dec` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dec` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_dec
  import el2_pkg::*;
#(
    `include "el2_param.vh"
) (
    input logic clk,                          // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
    input logic active_clk,                   // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
    input logic free_clk,                     // Clock always.                  Through two clock headers. For flops without second clock header built in.
    input logic free_l2clk,                   // Clock always.                  Through one clock header.  For flops with    second header built in.

    input logic lsu_fastint_stall_any,        // needed by lsu for 2nd pass of dma with ecc correction, stall next cycle

    output logic dec_extint_stall,  // Stall on external interrupt

    output logic dec_i0_decode_d,    // Valid instruction at D-stage and not blocked
    output logic dec_pause_state_cg, // to top for active state clock gating

    output logic dec_tlu_core_empty,

    input logic        rst_l,   // reset, active low
    // rst_vec is supposed to be connected to a constant in the top level
    /*pragma coverage off*/
    input logic [31:1] rst_vec, // reset vector, from core pins
    /*pragma coverage on*/

    input logic        nmi_int,  // NMI pin
    // nmi_vec is supposed to be connected to a constant in the top level
    /*pragma coverage off*/
    input logic [31:1] nmi_vec,  // NMI vector, from pins
    /*pragma coverage on*/

    input logic i_cpu_halt_req,  // Asynchronous Halt request to CPU
    input logic i_cpu_run_req,   // Asynchronous Restart request to CPU

    output logic o_cpu_halt_status,  // Halt status of core (pmu/fw)
    output logic o_cpu_halt_ack,  // Halt request ack
    output logic o_cpu_run_ack,  // Run request ack
    output logic o_debug_mode_status,         // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request

    /*pragma coverage off*/
    input logic [31:4] core_id,  // CORE ID
    /*pragma coverage on*/

    // external MPC halt/run interface
    input  logic mpc_debug_halt_req,  // Async halt request
    input  logic mpc_debug_run_req,   // Async run request
    input  logic mpc_reset_run_req,   // Run/halt after reset
    output logic mpc_debug_halt_ack,  // Halt ack
    output logic mpc_debug_run_ack,   // Run ack
    output logic debug_brkpt_status,  // debug breakpoint

    input logic exu_pmu_i0_br_misp,    // slot 0 branch misp
    input logic exu_pmu_i0_br_ataken,  // slot 0 branch actual taken
    input logic exu_pmu_i0_pc4,        // slot 0 4 byte branch


    input logic lsu_nonblock_load_valid_m,  // valid nonblock load at m
    input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_m,  // -> corresponding tag
    input logic lsu_nonblock_load_inv_r,  // invalidate request for nonblock load r
    input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_r,  // -> corresponding tag
    input logic lsu_nonblock_load_data_valid,  // valid nonblock load data back
    input logic lsu_nonblock_load_data_error,  // nonblock load bus error
    input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,  // -> corresponding tag
    input logic [31:0] lsu_nonblock_load_data,  // nonblock load data

    input logic lsu_pmu_bus_trxn,          // D side bus transaction
    input logic lsu_pmu_bus_misaligned,    // D side bus misaligned
    input logic lsu_pmu_bus_error,         // D side bus error
    input logic lsu_pmu_bus_busy,          // D side bus busy
    input logic lsu_pmu_misaligned_m,      // D side load or store misaligned
    input logic lsu_pmu_load_external_m,   // D side bus load
    input logic lsu_pmu_store_external_m,  // D side bus store
    input logic dma_pmu_dccm_read,         // DMA DCCM read
    input logic dma_pmu_dccm_write,        // DMA DCCM write
    input logic dma_pmu_any_read,          // DMA read
    input logic dma_pmu_any_write,         // DMA write

    input logic [31:1] lsu_fir_addr,  // Fast int address
    input logic [ 1:0] lsu_fir_error, // Fast int lookup error

    input logic ifu_pmu_instr_aligned,  // aligned instructions
    input logic ifu_pmu_fetch_stall,    // fetch unit stalled
    input logic ifu_pmu_ic_miss,        // icache miss
    input logic ifu_pmu_ic_hit,         // icache hit
    input logic ifu_pmu_bus_error,      // Instruction side bus error
    input logic ifu_pmu_bus_busy,       // Instruction side bus busy
    input logic ifu_pmu_bus_trxn,       // Instruction side bus transaction

    input logic ifu_ic_error_start,         // IC single bit error
    input logic ifu_iccm_rd_ecc_single_err, // ICCM single bit error

    input logic [ 3:0] lsu_trigger_match_m,
    input logic        dbg_cmd_valid,        // debugger abstract command valid
    input logic        dbg_cmd_write,        // command is a write
    input logic [ 1:0] dbg_cmd_type,         // command type
    input logic [31:0] dbg_cmd_addr,         // command address
    input logic [ 1:0] dbg_cmd_wrdata,       // command write data, for fence/fence_i


    input logic       ifu_i0_icaf,      // icache access fault
    input logic [1:0] ifu_i0_icaf_type, // icache access fault type

    input logic ifu_i0_icaf_second,  // i0 has access fault on second 2B of 4B inst
    input logic ifu_i0_dbecc,        // icache/iccm double-bit error

    input logic lsu_idle_any,  // lsu idle for halting

    input el2_br_pkt_t                                 i0_brp,           // branch packet
    input logic        [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index,  // BP index
    input logic        [          pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr,   // BP FGHR
    input logic        [         pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag,   // BP tag
    input logic        [      $clog2(pt.BTB_SIZE)-1:0] ifu_i0_fa_index,  // Fully associative btb index

    input el2_lsu_error_pkt_t lsu_error_pkt_r,           // LSU exception/error packet
    input logic               lsu_single_ecc_error_incr, // LSU inc SB error counter

    input logic        lsu_imprecise_error_load_any,   // LSU imprecise load bus error
    input logic        lsu_imprecise_error_store_any,  // LSU imprecise store bus error
    input logic [31:0] lsu_imprecise_error_addr_any,   // LSU imprecise bus error address

    input logic [31:0] exu_div_result,  // final div result
    input logic        exu_div_wren,    // Divide write enable to GPR

    input logic [31:0] exu_csr_rs1_x,  // rs1 for csr instruction

    input logic [31:0] lsu_result_m,      // load result
    input logic [31:0] lsu_result_corr_r, // load result - corrected load data

    input logic lsu_load_stall_any,   // This is for blocking loads
    input logic lsu_store_stall_any,  // This is for blocking stores
    input logic dma_dccm_stall_any,   // stall any load/store at decode, pmu event
    input logic dma_iccm_stall_any,   // iccm stalled, pmu event

    input logic iccm_dma_sb_error,  // ICCM DMA single bit error

    input logic exu_flush_final,  // slot0 flush

    input logic [31:1] exu_npc_r,  // next PC

    input logic [31:0] exu_i0_result_x,  // alu result x


    input logic        ifu_i0_valid,  // fetch valids to instruction buffer
    input logic [31:0] ifu_i0_instr,  // fetch inst's to instruction buffer
    input logic [31:1] ifu_i0_pc,     // pc's for instruction buffer
    input logic        ifu_i0_pc4,    // indication of 4B or 2B for corresponding inst
    input logic [31:1] exu_i0_pc_x,   // pc's for e1 from the alu's

    input logic mexintpend,  // External interrupt pending
    input logic timer_int,   // Timer interrupt pending (from pin)
    input logic soft_int,    // Software interrupt pending (from pin)

    input logic [7:0] pic_claimid,  // PIC claimid
    input logic [3:0] pic_pl,       // PIC priv level
    input logic       mhwakeup,     // High priority wakeup

    output logic [3:0] dec_tlu_meicurpl,  // to PIC, Current priv level
    output logic [3:0] dec_tlu_meipt,     // to PIC

    input logic [70:0] ifu_ic_debug_rd_data,  // diagnostic icache read data
    input logic ifu_ic_debug_rd_data_valid,  // diagnostic icache read data valid
    output el2_cache_debug_pkt_t dec_tlu_ic_diag_pkt, // packet of DICAWICS, DICAD0/1, DICAGO info for icache diagnostics


    // Debug start
    input logic dbg_halt_req,        // DM requests a halt
    input logic dbg_resume_req,      // DM requests a resume
    input logic ifu_miss_state_idle, // I-side miss buffer empty

    output logic        dec_tlu_dbg_halted,        // Core is halted and ready for debug command
    output logic        dec_tlu_debug_mode,        // Core is in debug mode
    output logic        dec_tlu_resume_ack,        // Resume acknowledge
    output logic        dec_tlu_flush_noredir_r,   // Tell fetch to idle on this flush
    output logic        dec_tlu_mpc_halted_only,   // Core is halted only due to MPC
    output logic        dec_tlu_flush_leak_one_r,  // single step
    output logic        dec_tlu_flush_err_r,       // iside perr/ecc rfpc
    output logic [31:2] dec_tlu_meihap,            // Fast ext int base

    output logic dec_debug_wdata_rs1_d,  // insert debug write data into rs1 at decode

    output logic [31:0] dec_dbg_rddata,  // debug command read data

    output logic dec_dbg_cmd_done,  // abstract command is done
    output logic dec_dbg_cmd_fail,  // abstract command failed (illegal reg address)

    output el2_trigger_pkt_t [3:0] trigger_pkt_any,  // info needed by debug trigger blocks

    output logic       dec_tlu_force_halt,       // halt has been forced
    // Debug end
    // branch info from pipe0 for errors or counter updates
    input  logic [1:0] exu_i0_br_hist_r,         // history
    input  logic       exu_i0_br_error_r,        // error
    input  logic       exu_i0_br_start_error_r,  // start error
    input  logic       exu_i0_br_valid_r,        // valid
    input  logic       exu_i0_br_mp_r,           // mispredict
    input  logic       exu_i0_br_middle_r,       // middle of bank

    // branch info from pipe1 for errors or counter updates

    input logic exu_i0_br_way_r,  // way hit or repl

    output logic        dec_i0_rs1_en_d,  // Qualify GPR RS1 data
    output logic        dec_i0_rs2_en_d,  // Qualify GPR RS2 data
    output logic [31:0] gpr_i0_rs1_d,     // gpr rs1 data
    output logic [31:0] gpr_i0_rs2_d,     // gpr rs2 data

    output logic [31:0] dec_i0_immed_d,    // immediate data
    output logic [12:1] dec_i0_br_immed_d, // br immediate data

    output el2_alu_pkt_t i0_ap,  // alu packet

    output logic dec_i0_alu_decode_d,  // schedule on D-stage alu
    output logic dec_i0_branch_d,      // Branch in D-stage

    output logic dec_i0_select_pc_d,  // select pc onto rs1 for jal's

    output logic [31:1] dec_i0_pc_d,             // pc's at decode
    output logic [ 3:0] dec_i0_rs1_bypass_en_d,  // rs1 bypass enable
    output logic [ 3:0] dec_i0_rs2_bypass_en_d,  // rs2 bypass enable

    output logic [31:0] dec_i0_result_r,  // Result R-stage

    output el2_lsu_pkt_t lsu_p,           // lsu packet
    output logic         dec_qual_lsu_d,  // LSU instruction at D.  Use to quiet LSU operands
    output el2_mul_pkt_t mul_p,           // mul packet
    output el2_div_pkt_t div_p,           // div packet
    output logic         dec_div_cancel,  // cancel divide operation

    output logic [11:0] dec_lsu_offset_d,  // 12b offset for load/store addresses

    output logic        dec_csr_ren_d,    // CSR read enable
    output logic [31:0] dec_csr_rddata_d, // CSR read data

    output logic dec_tlu_flush_lower_r,  // tlu flush due to late mp, exception, rfpc, or int
    output logic dec_tlu_flush_lower_wb,
    output logic [31:1] dec_tlu_flush_path_r,  // tlu flush target
    output logic        dec_tlu_i0_kill_writeb_r,    // I0 is flushed, don't writeback any results to arch state
    output logic dec_tlu_fence_i_r,  // flush is a fence_i rfnpc, flush icache

    output logic [31:1] pred_correct_npc_x,  // npc if prediction is correct at e2 stage

    output el2_br_tlu_pkt_t dec_tlu_br0_r_pkt,  // slot 0 branch predictor update packet

    output logic dec_tlu_perfcnt0,  // toggles when slot0 perf counter 0 has an event inc
    output logic dec_tlu_perfcnt1,  // toggles when slot0 perf counter 1 has an event inc
    output logic dec_tlu_perfcnt2,  // toggles when slot0 perf counter 2 has an event inc
    output logic dec_tlu_perfcnt3,  // toggles when slot0 perf counter 3 has an event inc

    output el2_predict_pkt_t dec_i0_predict_p_d,  // prediction packet to alus
    output logic [pt.BHT_GHR_SIZE-1:0] i0_predict_fghr_d,  // DEC predict fghr
    output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] i0_predict_index_d,  // DEC predict index
    output logic [pt.BTB_BTAG_SIZE-1:0] i0_predict_btag_d,  // DEC predict branch tag

    output logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index,  // Fully associative btb error index

    output logic dec_lsu_valid_raw_d,

    output logic [31:0] dec_tlu_mrac_ff,  // CSR for memory region control

    output logic [1:0] dec_data_en,  // clock-gate control logic
    output logic [1:0] dec_ctl_en,

    input logic [15:0] ifu_i0_cinst,  // 16b compressed instruction

    output el2_trace_pkt_t trace_rv_trace_pkt,  // trace packet

    // PMP signals
    output el2_pmp_cfg_pkt_t        pmp_pmpcfg [pt.PMP_ENTRIES],
    output logic             [31:0] pmp_pmpaddr[pt.PMP_ENTRIES],

`ifdef RV_USER_MODE

    // Privilege mode
    output logic priv_mode,
    output logic priv_mode_eff,
    output logic priv_mode_ns,

    // mseccfg CSR content for PMP
    output el2_mseccfg_pkt_t mseccfg,

`endif

    // feature disable from mfdc
    output logic dec_tlu_external_ldfwd_disable,  // disable external load forwarding
    output logic dec_tlu_sideeffect_posted_disable,  // disable posted stores to side-effect address
    output logic dec_tlu_core_ecc_disable,  // disable core ECC
    output logic dec_tlu_dccm_wr_readback_disable,  // disable DCCM write-readback check
    output logic dec_tlu_bpred_disable,  // disable branch prediction
    output logic dec_tlu_wb_coalescing_disable,  // disable writebuffer coalescing
    output logic [2:0] dec_tlu_dma_qos_prty,  // DMA QoS priority coming from MFDC [18:16]

    // clock gating overrides from mcgc
    output logic dec_tlu_misc_clk_override,   // override misc clock domain gating
    output logic dec_tlu_ifu_clk_override,    // override fetch clock domain gating
    output logic dec_tlu_lsu_clk_override,    // override load/store clock domain gating
    output logic dec_tlu_bus_clk_override,    // override bus clock domain gating
    output logic dec_tlu_pic_clk_override,    // override PIC clock domain gating
    output logic dec_tlu_picio_clk_override,  // override PICIO clock domain gating
    output logic dec_tlu_dccm_clk_override,   // override DCCM clock domain gating
    output logic dec_tlu_icm_clk_override,    // override ICCM clock domain gating

`ifdef RV_LOCKSTEP_REGFILE_ENABLE
    el2_regfile_if.veer_rf_src regfile,
`endif

    output logic dec_tlu_i0_commit_cmt,  // committed i0 instruction
    // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
    /*pragma coverage off*/
    input  logic scan_mode               // Flop scan mode control
    /*pragma coverage on*/

);
```

## Parent instantiation

```verilog
   el2_dec #(.pt(pt)) dec (
                            .clk(active_l2clk),
                            .dbg_cmd_wrdata(dbg_cmd_wrdata[1:0]),
                            .rst_l(core_rst_l),
                            .*
                            );
```

## Dependency declarations

### design/include/el2_def.sv

```verilog
typedef struct packed {
                       logic  trace_rv_i_valid_ip;
                       logic [31:0] trace_rv_i_insn_ip;
                       logic [31:0] trace_rv_i_address_ip;
                       logic  trace_rv_i_exception_ip;
                       logic [4:0] trace_rv_i_ecause_ip;
                       logic  trace_rv_i_interrupt_ip;
                       logic [31:0] trace_rv_i_tval_ip;
                       } el2_trace_pkt_t;
```

### design/dec/el2_dec_decode_ctl.sv

```verilog
module el2_dec_decode_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic dec_tlu_trace_disable,
   input logic dec_debug_valid_d,

   input logic dec_tlu_flush_extint,         // Flush external interrupt

   input logic dec_tlu_force_halt,           // invalidate nonblock load cam on a force halt event

   output logic dec_extint_stall,            // Stall from external interrupt

   input  logic [15:0] ifu_i0_cinst,         // 16b compressed instruction
   output logic [31:0] dec_i0_inst_wb,       // 32b instruction at wb+1 for trace encoder
   output logic [31:1] dec_i0_pc_wb,         // 31b pc at wb+1 for trace encoder


   input logic                                lsu_nonblock_load_valid_m,       // valid nonblock load at m
   input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_tag_m,         // -> corresponding tag
   input logic                                lsu_nonblock_load_inv_r,         // invalidate request for nonblock load r
   input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_inv_tag_r,     // -> corresponding tag
   input logic                                lsu_nonblock_load_data_valid,    // valid nonblock load data back
   input logic                                lsu_nonblock_load_data_error,    // nonblock load bus error
   input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_data_tag,      // -> corresponding tag


   input logic [3:0] dec_i0_trigger_match_d,          // i0 decode trigger matches

   input logic dec_tlu_wr_pause_r,                    // pause instruction at r
   input logic dec_tlu_pipelining_disable,            // pipeline disable - presync, i0 decode only

   input logic [3:0]  lsu_trigger_match_m,            // lsu trigger matches

   input logic lsu_pmu_misaligned_m,                  // perf mon: load/store misalignment
   input logic dec_tlu_debug_stall,                   // debug stall decode
   input logic dec_tlu_flush_leak_one_r,              // leak1 instruction

   input logic dec_debug_fence_d,                     // debug fence instruction

   input logic [1:0] dbg_cmd_wrdata,                  // disambiguate fence, fence_i

   input logic dec_i0_icaf_d,                         // icache access fault
   input logic dec_i0_icaf_second_d,                  // i0 instruction access fault on second 2B of 4B inst
   input logic [1:0] dec_i0_icaf_type_d,              // i0 instruction access fault type

   input logic dec_i0_dbecc_d,                        // icache/iccm double-bit error

   input el2_br_pkt_t dec_i0_brp,                    // branch packet
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] dec_i0_bp_index,   // i0 branch index
   input logic [pt.BHT_GHR_SIZE-1:0] dec_i0_bp_fghr,  // BP FGHR
   input logic [pt.BTB_BTAG_SIZE-1:0] dec_i0_bp_btag, // BP tag
   input logic [$clog2(pt.BTB_SIZE)-1:0] dec_i0_bp_fa_index,          // Fully associative btb index

   input logic lsu_idle_any,                          // lsu idle: if fence instr & ~lsu_idle then stall decode

   input logic lsu_load_stall_any,                    // stall any load at decode
   input logic lsu_store_stall_any,                   // stall any store at decode
   input logic dma_dccm_stall_any,                    // stall any load/store at decode

   input logic exu_div_wren,                          // nonblocking divide write enable to GPR.

   input logic dec_tlu_i0_kill_writeb_wb,             // I0 is flushed, don't writeback any results to arch state
   input logic dec_tlu_flush_lower_wb,                // trap lower flush
   input logic dec_tlu_i0_kill_writeb_r,              // I0 is flushed, don't writeback any results to arch state
   input logic dec_tlu_flush_lower_r,                 // trap lower flush
   input logic dec_tlu_flush_pause_r,                 // don't clear pause state on initial lower flush
   input logic dec_tlu_presync_d,                     // CSR read needs to be presync'd
   input logic dec_tlu_postsync_d,                    // CSR ops that need to be postsync'd

   input logic dec_i0_pc4_d,                          // inst is 4B inst else 2B

   input logic [31:0] dec_csr_rddata_d,               // csr read data at wb
   input logic dec_csr_legal_d,                       // csr indicates legal operation

   input logic [31:0] exu_csr_rs1_x,                  // rs1 for csr instr

   input logic [31:0] lsu_result_m,                   // load result
   input logic [31:0] lsu_result_corr_r,              // load result - corrected data for writing gpr's, not for bypassing

   input logic exu_flush_final,                       // lower flush or i0 flush at X or D

   input logic [31:1] exu_i0_pc_x,                    // pcs at e1

   input logic [31:0] dec_i0_instr_d,                 // inst at decode

   input logic  dec_ib0_valid_d,                      // inst valid at decode

   input logic [31:0] exu_i0_result_x,                // from primary alu's

   input logic  clk,                                  // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic  active_clk,                           // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic  free_l2clk,                           // Clock always.                  Through one clock header.  For flops with    second header built in.

   input logic  clk_override,                         // Override non-functional clock gating
   input logic  rst_l,                                // Flop reset



   output logic        dec_i0_rs1_en_d,               // rs1 enable at decode
   output logic        dec_i0_rs2_en_d,               // rs2 enable at decode

   output logic [4:0]  dec_i0_rs1_d,                  // rs1 logical source
   output logic [4:0]  dec_i0_rs2_d,                  // rs2 logical source

   output logic [31:0] dec_i0_immed_d,                // 32b immediate data decode


   output logic [12:1] dec_i0_br_immed_d,             // 12b branch immediate

   output el2_alu_pkt_t i0_ap,                       // alu packets

   output logic        dec_i0_decode_d,               // i0 decode

   output logic        dec_i0_alu_decode_d,           // decode to D-stage alu
   output logic        dec_i0_branch_d,               // Branch in D-stage

   output logic [4:0]  dec_i0_waddr_r,                // i0 logical source to write to gpr's
   output logic        dec_i0_wen_r,                  // i0 write enable
   output logic [31:0] dec_i0_wdata_r,                // i0 write data

   output logic        dec_i0_select_pc_d,            // i0 select pc for rs1 - branches

   output logic [3:0]    dec_i0_rs1_bypass_en_d,      // i0 rs1 bypass enable
   output logic [3:0]    dec_i0_rs2_bypass_en_d,      // i0 rs2 bypass enable
   output logic [31:0]   dec_i0_result_r,             // Result R-stage

   output el2_lsu_pkt_t    lsu_p,                    // load/store packet
   output logic             dec_qual_lsu_d,           // LSU instruction at D.  Use to quiet LSU operands

   output el2_mul_pkt_t    mul_p,                    // multiply packet

   output el2_div_pkt_t    div_p,                    // divide packet
   output logic [4:0]       div_waddr_wb,             // DIV write address to GPR
   output logic             dec_div_cancel,           // cancel the divide operation

   output logic        dec_lsu_valid_raw_d,
   output logic [11:0] dec_lsu_offset_d,

   output logic        dec_csr_ren_d,                 // valid csr decode
   output logic        dec_csr_wen_unq_d,             // valid csr with write - for csr legal
   output logic        dec_csr_any_unq_d,             // valid csr - for csr legal
   output logic [11:0] dec_csr_rdaddr_d,              // read address for csr
   output logic        dec_csr_wen_r,                 // csr write enable at r
   output logic [11:0] dec_csr_rdaddr_r,              // read address for csr
   output logic [11:0] dec_csr_wraddr_r,              // write address for csr
   output logic [31:0] dec_csr_wrdata_r,              // csr write data at r
   output logic        dec_csr_stall_int_ff,          // csr is mie/mstatus

   output              dec_tlu_i0_valid_r,            // i0 valid inst at c

   output el2_trap_pkt_t   dec_tlu_packet_r,              // trap packet

   output logic [31:1] dec_tlu_i0_pc_r,               // i0 trap pc

   output logic [31:0] dec_illegal_inst,              // illegal inst
   output logic [31:1] pred_correct_npc_x,            // npc e2 if the prediction is correct

   output el2_predict_pkt_t dec_i0_predict_p_d,      // i0 predict packet decode
   output logic [pt.BHT_GHR_SIZE-1:0] i0_predict_fghr_d, // i0 predict fghr
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] i0_predict_index_d, // i0 predict index
   output logic [pt.BTB_BTAG_SIZE-1:0] i0_predict_btag_d, // i0_predict branch tag

   output logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index, // Fully associative btb error index

   output logic [1:0] dec_data_en,                    // clock-gating logic
   output logic [1:0] dec_ctl_en,

   output logic       dec_pmu_instr_decoded,          // number of instructions decode this cycle encoded
   output logic       dec_pmu_decode_stall,           // decode is stalled
   output logic       dec_pmu_presync_stall,          // decode has presync stall
   output logic       dec_pmu_postsync_stall,         // decode has postsync stall

   output logic       dec_nonblock_load_wen,          // write enable for nonblock load
   output logic [4:0] dec_nonblock_load_waddr,        // logical write addr for nonblock load
   output logic       dec_pause_state,                // core in pause state
   output logic       dec_pause_state_cg,             // pause state for clock-gating

   output logic       dec_div_active,                 // non-block divide is active

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic       scan_mode
   /*pragma coverage on*/
   );
```

### design/dec/el2_dec_gpr_ctl.sv

```verilog
module el2_dec_gpr_ctl
import el2_pkg::*;
#(
   `include "el2_param.vh"
 )  (
    input logic [4:0]  raddr0,       // logical read addresses
    input logic [4:0]  raddr1,

    input logic        wen0,         // write enable
    input logic [4:0]  waddr0,       // write address
    input logic [31:0] wd0,          // write data

    input logic        wen1,         // write enable
    input logic [4:0]  waddr1,       // write address
    input logic [31:0] wd1,          // write data

    input logic        wen2,         // write enable
    input logic [4:0]  waddr2,       // write address
    input logic [31:0] wd2,          // write data

    input logic        clk,
    input logic        rst_l,

    output logic [31:0] rd0,         // read data
    output logic [31:0] rd1,

`ifdef RV_LOCKSTEP_REGFILE_ENABLE
    el2_regfile_if.veer_gpr_rf regfile,
`endif

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
    input  logic        scan_mode
   /*pragma coverage on*/
);
```

### design/dec/el2_dec_ib_ctl.sv

```verilog
module el2_dec_ib_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic                 dbg_cmd_valid,                      // valid dbg cmd

   input logic                 dbg_cmd_write,                      // dbg cmd is write
   input logic [1:0]           dbg_cmd_type,                       // dbg type
   input logic [31:0]          dbg_cmd_addr,                       // expand to 31:0

   input el2_br_pkt_t i0_brp,                                     // i0 branch packet from aligner
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index,    // BP index
   input logic [pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr,               // BP FGHR
   input logic [pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag,              // BP tag
   input logic [$clog2(pt.BTB_SIZE)-1:0] ifu_i0_fa_index,          // Fully associative btb index

   input logic       ifu_i0_pc4,                                   // i0 is 4B inst else 2B
   input logic       ifu_i0_valid,                                 // i0 valid from ifu
   input logic       ifu_i0_icaf,                                  // i0 instruction access fault
   input logic [1:0] ifu_i0_icaf_type,                             // i0 instruction access fault type

   input logic   ifu_i0_icaf_second,                               // i0 has access fault on second 2B of 4B inst
   input logic   ifu_i0_dbecc,                                     // i0 double-bit error
   input logic [31:0]  ifu_i0_instr,                               // i0 instruction from the aligner
   input logic [31:1]  ifu_i0_pc,                                  // i0 pc from the aligner


   output logic dec_ib0_valid_d,                                   // ib0 valid
   output logic dec_debug_valid_d,                                 // Debug read or write at D-stage


   output logic [31:0] dec_i0_instr_d,                             // i0 inst at decode

   output logic [31:1] dec_i0_pc_d,                                // i0 pc at decode

   output logic dec_i0_pc4_d,                                      // i0 is 4B inst else 2B

   output el2_br_pkt_t dec_i0_brp,                                // i0 branch packet at decode
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] dec_i0_bp_index,   // i0 branch index
   output logic [pt.BHT_GHR_SIZE-1:0] dec_i0_bp_fghr,              // BP FGHR
   output logic [pt.BTB_BTAG_SIZE-1:0] dec_i0_bp_btag,             // BP tag
   output logic [$clog2(pt.BTB_SIZE)-1:0] dec_i0_bp_fa_index,          // Fully associative btb index

   output logic dec_i0_icaf_d,                                     // i0 instruction access fault at decode
   output logic dec_i0_icaf_second_d,                              // i0 instruction access fault on second 2B of 4B inst
   output logic [1:0] dec_i0_icaf_type_d,                          // i0 instruction access fault type
   output logic dec_i0_dbecc_d,                                    // i0 double-bit error at decode
   output logic dec_debug_wdata_rs1_d,                             // put debug write data onto rs1 source: machine is halted

   output logic dec_debug_fence_d                                  // debug fence inst

   );
```

### design/dec/el2_dec_tlu_ctl.sv

```verilog
module el2_dec_tlu_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic clk,
   input logic free_clk,
   input logic free_l2clk,
   input logic rst_l,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic scan_mode,
   /*pragma coverage on*/

   //rst_vec is supposed to be connected to constant in the top level
   /*pragma coverage off*/
   input logic [31:1] rst_vec, // reset vector, from core pins
   /*pragma coverage on*/
   input logic        nmi_int, // nmi pin
   //nmi_vec is supposed to be connected to constant in the top level
   /*pragma coverage off*/
   input logic [31:1] nmi_vec, // nmi vector
   /*pragma coverage on*/
   input logic  i_cpu_halt_req,    // Asynchronous Halt request to CPU
   input logic  i_cpu_run_req,     // Asynchronous Restart request to CPU

   input logic lsu_fastint_stall_any,   // needed by lsu for 2nd pass of dma with ecc correction, stall next cycle


   // perf counter inputs
   input logic       ifu_pmu_instr_aligned,   // aligned instructions
   input logic       ifu_pmu_fetch_stall, // fetch unit stalled
   input logic       ifu_pmu_ic_miss, // icache miss
   input logic       ifu_pmu_ic_hit, // icache hit
   input logic       ifu_pmu_bus_error, // Instruction side bus error
   input logic       ifu_pmu_bus_busy, // Instruction side bus busy
   input logic       ifu_pmu_bus_trxn, // Instruction side bus transaction
   input logic       dec_pmu_instr_decoded, // decoded instructions
   input logic       dec_pmu_decode_stall, // decode stall
   input logic       dec_pmu_presync_stall, // decode stall due to presync'd inst
   input logic       dec_pmu_postsync_stall,// decode stall due to postsync'd inst
   input logic       lsu_store_stall_any,    // SB or WB is full, stall decode
   input logic       dma_dccm_stall_any,     // DMA stall of lsu
   input logic       dma_iccm_stall_any,     // DMA stall of ifu
   input logic       exu_pmu_i0_br_misp,     // pipe 0 branch misp
   input logic       exu_pmu_i0_br_ataken,   // pipe 0 branch actual taken
   input logic       exu_pmu_i0_pc4,         // pipe 0 4 byte branch
   input logic       lsu_pmu_bus_trxn,       // D side bus transaction
   input logic       lsu_pmu_bus_misaligned, // D side bus misaligned
   input logic       lsu_pmu_bus_error,      // D side bus error
   input logic       lsu_pmu_bus_busy,       // D side bus busy
   input logic       lsu_pmu_load_external_m, // D side bus load
   input logic       lsu_pmu_store_external_m, // D side bus store
   input logic       dma_pmu_dccm_read,          // DMA DCCM read
   input logic       dma_pmu_dccm_write,         // DMA DCCM write
   input logic       dma_pmu_any_read,           // DMA read
   input logic       dma_pmu_any_write,          // DMA write

   input logic [31:1] lsu_fir_addr, // Fast int address
   input logic [1:0] lsu_fir_error, // Fast int lookup error

   input logic       iccm_dma_sb_error,      // I side dma single bit error

   input    el2_lsu_error_pkt_t lsu_error_pkt_r, // lsu precise exception/error packet
   input logic         lsu_single_ecc_error_incr, // LSU inc SB error counter

   input logic dec_pause_state, // Pause counter not zero
   input logic         lsu_imprecise_error_store_any,      // store bus error
   input logic         lsu_imprecise_error_load_any,      // store bus error
   input logic [31:0]  lsu_imprecise_error_addr_any, // store bus error address

   input logic        dec_csr_wen_unq_d,       // valid csr with write - for csr legal
   input logic        dec_csr_any_unq_d,       // valid csr - for csr legal
   input logic [11:0] dec_csr_rdaddr_d,      // read address for csr

   input logic        dec_csr_wen_r,      // csr write enable at wb
   input logic [11:0] dec_csr_rdaddr_r,      // read address for csr
   input logic [11:0] dec_csr_wraddr_r,      // write address for csr
   input logic [31:0] dec_csr_wrdata_r,   // csr write data at wb

   input logic        dec_csr_stall_int_ff, // csr is mie/mstatus

   input logic dec_tlu_i0_valid_r, // pipe 0 op at e4 is valid

   input logic [31:1] exu_npc_r, // for NPC tracking

   input logic [31:1] dec_tlu_i0_pc_r, // for PC/NPC tracking

   input el2_trap_pkt_t dec_tlu_packet_r, // exceptions known at decode

   input logic [31:0] dec_illegal_inst, // For mtval
   input logic        dec_i0_decode_d,  // decode valid, used for clean icache diagnostics

   // branch info from pipe0 for errors or counter updates
   input logic [1:0]  exu_i0_br_hist_r, // history
   input logic        exu_i0_br_error_r, // error
   input logic        exu_i0_br_start_error_r, // start error
   input logic        exu_i0_br_valid_r, // valid
   input logic        exu_i0_br_mp_r, // mispredict
   input logic        exu_i0_br_middle_r, // middle of bank

   // branch info from pipe1 for errors or counter updates

   input logic             exu_i0_br_way_r, // way hit or repl

   output logic dec_tlu_core_empty,  // core is empty
   // Debug start
   output logic dec_dbg_cmd_done, // abstract command done
   output logic dec_dbg_cmd_fail, // abstract command failed
   output logic dec_tlu_dbg_halted, // Core is halted and ready for debug command
   output logic dec_tlu_debug_mode, // Core is in debug mode
   output logic dec_tlu_resume_ack, // Resume acknowledge
   output logic dec_tlu_debug_stall, // stall decode while waiting on core to empty

   output logic dec_tlu_flush_noredir_r , // Tell fetch to idle on this flush
   output logic dec_tlu_mpc_halted_only, // Core is halted only due to MPC
   output logic dec_tlu_flush_leak_one_r, // single step
   output logic dec_tlu_flush_err_r, // iside perr/ecc rfpc. This is the D stage of the error

   output logic dec_tlu_flush_extint, // fast ext int started
   output logic [31:2] dec_tlu_meihap, // meihap for fast int

   input  logic dbg_halt_req, // DM requests a halt
   input  logic dbg_resume_req, // DM requests a resume
   input  logic ifu_miss_state_idle, // I-side miss buffer empty
   input  logic lsu_idle_any, // lsu is idle
   input  logic dec_div_active, // oop div is active
   output el2_trigger_pkt_t  [3:0] trigger_pkt_any, // trigger info for trigger blocks

   input logic  ifu_ic_error_start,     // IC single bit error
   input logic  ifu_iccm_rd_ecc_single_err, // ICCM single bit error


   input logic [70:0] ifu_ic_debug_rd_data, // diagnostic icache read data
   input logic ifu_ic_debug_rd_data_valid, // diagnostic icache read data valid
   output el2_cache_debug_pkt_t dec_tlu_ic_diag_pkt, // packet of DICAWICS, DICAD0/1, DICAGO info for icache diagnostics
   // Debug end

   input logic [7:0] pic_claimid, // pic claimid for csr
   input logic [3:0] pic_pl, // pic priv level for csr
   input logic       mhwakeup, // high priority external int, wakeup if halted

   input logic mexintpend, // external interrupt pending
   input logic timer_int, // timer interrupt pending
   input logic soft_int, // software interrupt pending

   output logic o_cpu_halt_status, // PMU interface, halted
   output logic o_cpu_halt_ack, // halt req ack
   output logic o_cpu_run_ack, // run req ack
   output logic o_debug_mode_status, // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request

   /*pragma coverage off*/
   input logic [31:4] core_id, // Core ID
   /*pragma coverage on*/

   // external MPC halt/run interface
   input logic mpc_debug_halt_req, // Async halt request
   input logic mpc_debug_run_req, // Async run request
   input logic mpc_reset_run_req, // Run/halt after reset
   output logic mpc_debug_halt_ack, // Halt ack
   output logic mpc_debug_run_ack, // Run ack
   output logic debug_brkpt_status, // debug breakpoint

   output logic [3:0] dec_tlu_meicurpl, // to PIC
   output logic [3:0] dec_tlu_meipt, // to PIC


   output logic [31:0] dec_csr_rddata_d,      // csr read data at wb
   output logic dec_csr_legal_d,              // csr indicates legal operation

   output el2_br_tlu_pkt_t dec_tlu_br0_r_pkt, // branch pkt to bp

   output logic dec_tlu_i0_kill_writeb_wb,    // I0 is flushed, don't writeback any results to arch state
   output logic dec_tlu_flush_lower_wb,       // commit has a flush (exception, int, mispredict at e4)
   output logic dec_tlu_i0_commit_cmt,        // committed an instruction

   output logic dec_tlu_i0_kill_writeb_r,    // I0 is flushed, don't writeback any results to arch state
   output logic dec_tlu_flush_lower_r,       // commit has a flush (exception, int)
   output logic [31:1] dec_tlu_flush_path_r, // flush pc
   output logic dec_tlu_fence_i_r,           // flush is a fence_i rfnpc, flush icache
   output logic dec_tlu_wr_pause_r,           // CSR write to pause reg is at R.
   output logic dec_tlu_flush_pause_r,        // Flush is due to pause

   output logic dec_tlu_presync_d,            // CSR read needs to be presync'd
   output logic dec_tlu_postsync_d,           // CSR needs to be presync'd


   output logic [31:0] dec_tlu_mrac_ff,        // CSR for memory region control

   output logic dec_tlu_force_halt, // halt has been forced

   output logic dec_tlu_perfcnt0, // toggles when pipe0 perf counter 0 has an event inc
   output logic dec_tlu_perfcnt1, // toggles when pipe0 perf counter 1 has an event inc
   output logic dec_tlu_perfcnt2, // toggles when pipe0 perf counter 2 has an event inc
   output logic dec_tlu_perfcnt3, // toggles when pipe0 perf counter 3 has an event inc

   output logic dec_tlu_i0_exc_valid_wb1, // pipe 0 exception valid
   output logic dec_tlu_i0_valid_wb1,  // pipe 0 valid
   output logic dec_tlu_int_valid_wb1, // pipe 2 int valid
   output logic [4:0] dec_tlu_exc_cause_wb1, // exception or int cause
   output logic [31:0] dec_tlu_mtval_wb1, // MTVAL value

   // feature disable from mfdc
   output logic  dec_tlu_external_ldfwd_disable,    // disable external load forwarding
   output logic  dec_tlu_sideeffect_posted_disable, // disable posted stores to side-effect address
   output logic  dec_tlu_core_ecc_disable,          // disable core ECC
   output logic  dec_tlu_dccm_wr_readback_disable,  // disable DCCM write-readback check
   output logic  dec_tlu_bpred_disable,             // disable branch prediction
   output logic  dec_tlu_wb_coalescing_disable,     // disable writebuffer coalescing
   output logic  dec_tlu_pipelining_disable,        // disable pipelining
   output logic  dec_tlu_trace_disable,             // disable trace
   output logic [2:0]  dec_tlu_dma_qos_prty,        // DMA QoS priority coming from MFDC [18:16]

   // clock gating overrides from mcgc
   output logic  dec_tlu_misc_clk_override, // override misc clock domain gating
   output logic  dec_tlu_dec_clk_override,  // override decode clock domain gating
   output logic  dec_tlu_ifu_clk_override,  // override fetch clock domain gating
   output logic  dec_tlu_lsu_clk_override,  // override load/store clock domain gating
   output logic  dec_tlu_bus_clk_override,  // override bus clock domain gating
   output logic  dec_tlu_pic_clk_override,  // override PIC clock domain gating
   output logic  dec_tlu_picio_clk_override,// override PICIO clock domain gating
   output logic  dec_tlu_dccm_clk_override, // override DCCM clock domain gating
   output logic  dec_tlu_icm_clk_override,  // override ICCM clock domain gating

`ifdef RV_LOCKSTEP_REGFILE_ENABLE
   el2_regfile_if.veer_tlu_rf regfile,
`endif

`ifdef RV_USER_MODE

   // Privilege mode
   // 0 - machine, 1 - user
   output logic  priv_mode,
   output logic  priv_mode_eff,
   output logic  priv_mode_ns,

   // mseccfg CSR content for PMP
   output logic [2:0] mseccfg,

`endif

   // pmp
   output el2_pmp_cfg_pkt_t pmp_pmpcfg  [pt.PMP_ENTRIES],
   output logic [31:0]      pmp_pmpaddr [pt.PMP_ENTRIES]
   );
```

### design/dec/el2_dec_trigger.sv

```verilog
module el2_dec_trigger
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(

   input el2_trigger_pkt_t [3:0] trigger_pkt_any,           // Packet from tlu. 'select':0-pc,1-Opcode  'Execute' needs to be set for dec triggers to fire. 'match'-1 do mask, 0: full match
   input logic [31:1]  dec_i0_pc_d,                          // i0 pc

   output logic [3:0] dec_i0_trigger_match_d                 // Trigger match
);
```

## Documentation

### docs/source/complex-ports.md

```markdown
* - **Trace Port** [^fn-complex-ports-2]
  -
  -
* - trace_rv_i_insn_ip[31:0]
  - out
  - Instruction opcode
* - trace_rv_i_address_ip[31:0]
  - out
  - Instruction address
* - trace_rv_i_valid_ip
  - out
  - Instruction trace valid
* - trace_rv_i_exception_ip
  - out
  - Exception
* - trace_rv_i_ecause_ip[4:0]
  - out
  - Exception cause
* - trace_rv_i_interrupt_ip
  - out
  - Interrupt exception
* - trace_rv_i_tval_ip[31:0]
  - out
  - Exception trap value

...

[^fn-complex-ports-2]: The core provides trace information for a maximum of one instruction and one interrupt/exception per clock cycle.
Note that the only information provided for interrupts/exceptions is the cause, the interrupt/exception flag, and the trap value.
The core’s trace port busses are minimally sized, but wide enough to deliver all trace information the core may produce in one clock cycle.
Not provided signals for the upper bits of the interface related to the interrupt slot might have to be tied off in the SoC.
```
