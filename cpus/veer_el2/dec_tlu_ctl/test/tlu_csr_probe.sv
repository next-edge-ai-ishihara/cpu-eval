module tlu_csr_probe
import el2_pkg::*;
#(
`include "el2_param.vh"
)(input logic clk, rst_l, halt_req, wen,
  input logic [11:0] addr, input logic [31:0] wdata,
  output logic [31:0] csr_read,
  output logic halted, legal,
  output logic diag_write,
  output logic [31:0] config_ways, config_tag_lo, config_ecc,
  output logic config_readback, config_fpga);
el2_cache_debug_pkt_t diag;
assign diag_write = diag.icache_wr_valid;
assign config_ways=pt.ICACHE_NUM_WAYS;
assign config_tag_lo=pt.ICACHE_TAG_LO;
assign config_ecc=pt.ICACHE_ECC;
`ifdef RV_DCCM_WR_READBACK
assign config_readback=1'b1;
`else
assign config_readback=1'b0;
`endif
`ifdef RV_FPGA_OPTIMIZE
assign config_fpga=1'b1;
`else
assign config_fpga=1'b0;
`endif
el2_dec_tlu_ctl #(.pt(pt)) dut (
    .clk(clk),
    .free_clk(clk),
    .free_l2clk(clk),
    .rst_l(rst_l),
    .scan_mode('0),
    .rst_vec('0),
    .nmi_int('0),
    .nmi_vec('0),
    .i_cpu_halt_req('0),
    .i_cpu_run_req('0),
    .lsu_fastint_stall_any('0),
    .ifu_pmu_instr_aligned('0),
    .ifu_pmu_fetch_stall('0),
    .ifu_pmu_ic_miss('0),
    .ifu_pmu_ic_hit('0),
    .ifu_pmu_bus_error('0),
    .ifu_pmu_bus_busy('0),
    .ifu_pmu_bus_trxn('0),
    .dec_pmu_instr_decoded('0),
    .dec_pmu_decode_stall('0),
    .dec_pmu_presync_stall('0),
    .dec_pmu_postsync_stall('0),
    .lsu_store_stall_any('0),
    .dma_dccm_stall_any('0),
    .dma_iccm_stall_any('0),
    .exu_pmu_i0_br_misp('0),
    .exu_pmu_i0_br_ataken('0),
    .exu_pmu_i0_pc4('0),
    .lsu_pmu_bus_trxn('0),
    .lsu_pmu_bus_misaligned('0),
    .lsu_pmu_bus_error('0),
    .lsu_pmu_bus_busy('0),
    .lsu_pmu_load_external_m('0),
    .lsu_pmu_store_external_m('0),
    .dma_pmu_dccm_read('0),
    .dma_pmu_dccm_write('0),
    .dma_pmu_any_read('0),
    .dma_pmu_any_write('0),
    .lsu_fir_addr('0),
    .lsu_fir_error('0),
    .iccm_dma_sb_error('0),
    .lsu_error_pkt_r('0),
    .lsu_single_ecc_error_incr('0),
    .dec_pause_state('0),
    .lsu_imprecise_error_store_any('0),
    .lsu_imprecise_error_load_any('0),
    .lsu_imprecise_error_addr_any('0),
    .dec_csr_wen_unq_d(wen),
    .dec_csr_any_unq_d(1'b1),
    .dec_csr_rdaddr_d(addr),
    .dec_csr_wen_r(wen),
    .dec_csr_rdaddr_r(addr),
    .dec_csr_wraddr_r(addr),
    .dec_csr_wrdata_r(wdata),
    .dec_csr_stall_int_ff('0),
    .dec_tlu_i0_valid_r('0),
    .exu_npc_r('0),
    .dec_tlu_i0_pc_r('0),
    .dec_tlu_packet_r('0),
    .dec_illegal_inst('0),
    .dec_i0_decode_d('0),
    .exu_i0_br_hist_r('0),
    .exu_i0_br_error_r('0),
    .exu_i0_br_start_error_r('0),
    .exu_i0_br_valid_r('0),
    .exu_i0_br_mp_r('0),
    .exu_i0_br_middle_r('0),
    .exu_i0_br_way_r('0),
    .dbg_halt_req(halt_req),
    .dbg_resume_req('0),
    .ifu_miss_state_idle(1'b1),
    .lsu_idle_any(1'b1),
    .dec_div_active('0),
    .ifu_ic_error_start('0),
    .ifu_iccm_rd_ecc_single_err('0),
    .ifu_ic_debug_rd_data('0),
    .ifu_ic_debug_rd_data_valid('0),
    .pic_claimid('0),
    .pic_pl('0),
    .mhwakeup('0),
    .mexintpend('0),
    .timer_int('0),
    .soft_int('0),
    .core_id('0),
    .mpc_debug_halt_req('0),
    .mpc_debug_run_req('0),
    .mpc_reset_run_req(1'b1),
    .dec_csr_rddata_d(csr_read),
    .dec_tlu_dbg_halted(halted),
    .dec_csr_legal_d(legal),
    .dec_tlu_ic_diag_pkt(diag));
endmodule
