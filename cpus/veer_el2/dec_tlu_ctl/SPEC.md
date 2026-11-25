# Implement `el2_dec_tlu_ctl`

Implement the complete `el2_dec_tlu_ctl` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_dec_tlu_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

```text
my $ahb = 0;
my $axi = 1;

...

$icache_ecc=1;

```

## Package and imports

```verilog
typedef enum logic [3:0] {
                          NULL_OP  = 4'b0000,
                          MUL      = 4'b0001,
                          LOAD     = 4'b0010,
                          STORE    = 4'b0011,
                          ALU      = 4'b0100,
                          CSRREAD  = 4'b0101,
                          CSRWRITE = 4'b0110,
                          CSRRW    = 4'b0111,
                          EBREAK   = 4'b1000,
                          ECALL    = 4'b1001,
                          FENCE    = 4'b1010,
                          FENCEI   = 4'b1011,
                          MRET     = 4'b1100,
                          CONDBR   = 4'b1101,
                          JAL      = 4'b1110,
                          BITMANIPU = 4'b1111
                          } el2_inst_pkt_t;

// ...

typedef struct packed {
                       logic valid;
                       logic [1:0] hist;
                       logic br_error;
                       logic br_start_error;
                       logic way;
                       logic middle;
                       } el2_br_tlu_pkt_t;

// ...

typedef struct packed {
                       // unlikely to change
                       logic icaf;
                       logic icaf_second;
                       logic [1:0] icaf_type;
                       logic fence_i;
                       logic [3:0] i0trigger;
                       logic pmu_i0_br_unpred;     // pmu
                       logic pmu_divide;
                       // likely to change
                       logic legal;
                       logic pmu_lsu_misaligned;
                       el2_inst_pkt_t pmu_i0_itype;        // pmu - instruction type
                       } el2_trap_pkt_t;

// ...

typedef struct packed {
                      logic inst_type;   //0: Load, 1: Store
                      //logic dma_valid;
                      logic exc_type;    //0: MisAligned, 1: Access Fault
                      logic [3:0] mscause;
                      logic [31:0] addr;
                      logic single_ecc_error;
                      logic exc_valid;
                      } el2_lsu_error_pkt_t;

// ...

typedef struct packed {
                        logic        select;
                        logic        match;
                        logic        store;
                        logic        load;
                        logic        execute;
                        logic        m;
                        logic [31:0] tdata2;
            } el2_trigger_pkt_t;

// ...

typedef struct packed {
                        logic [70:0]  icache_wrdata; // {dicad1[1:0], dicad0h[31:0], dicad0[31:0]}
                        logic [16:0]  icache_dicawics; // Arraysel:24, Waysel:21:20, Index:16:3
                        logic         icache_rd_valid;
                        logic         icache_wr_valid;
            } el2_cache_debug_pkt_t;

// ...

  typedef enum logic [1:0] {
    OFF   = 2'b00,
    TOR   = 2'b01,
    NA4   = 2'b10,
    NAPOT = 2'b11
  } el2_pmp_mode_pkt_t;

// ...

  typedef struct packed {
    logic lock;
    logic [1:0] reserved;
    el2_pmp_mode_pkt_t mode;
    logic execute;
    logic write;
    logic read;
  } el2_pmp_cfg_pkt_t;

  typedef struct packed {
    logic RLB;
    logic MMWP;
    logic MML;
  } el2_mseccfg_pkt_t;

```

## Module declaration

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

## Parent instantiation

```verilog
  el2_dec_tlu_ctl #(.pt(pt)
  ) tlu (
`ifdef RV_LOCKSTEP_REGFILE_ENABLE
      .regfile(regfile_if.veer_tlu_rf),
`endif
      .*);

```

## Dependency declarations

### design/include/el2_dec_csr_equ_m.svh

```verilog
logic csr_misa;
logic csr_mvendorid;
logic csr_marchid;
logic csr_mimpid;
logic csr_mhartid;
logic csr_mstatus;
logic csr_mtvec;
logic csr_mip;
logic csr_mie;
logic csr_mcyclel;
logic csr_mcycleh;
logic csr_minstretl;
logic csr_minstreth;
logic csr_mscratch;
logic csr_mepc;
logic csr_mcause;
logic csr_mscause;
logic csr_mtval;
logic csr_mrac;
logic csr_dmst;
logic csr_mdseac;
logic csr_meihap;
logic csr_meivt;
logic csr_meipt;
logic csr_meicurpl;
logic csr_meicidpl;
logic csr_dcsr;
logic csr_mcgc;
logic csr_mfdc;
logic csr_dpc;
logic csr_mtsel;
logic csr_mtdata1;
logic csr_mtdata2;
logic csr_mhpmc3;
logic csr_mhpmc4;
logic csr_mhpmc5;
logic csr_mhpmc6;
logic csr_mhpmc3h;
logic csr_mhpmc4h;
logic csr_mhpmc5h;
logic csr_mhpmc6h;
logic csr_mhpme3;
logic csr_mhpme4;
logic csr_mhpme5;
logic csr_mhpme6;
logic csr_mcountinhibit;
logic csr_mitctl0;
logic csr_mitctl1;
logic csr_mitb0;
logic csr_mitb1;
logic csr_mitcnt0;
logic csr_mitcnt1;
/* exclude signals that are tied to constant value in this file */
/*pragma coverage off*/
logic csr_perfva;
logic csr_perfvb;
logic csr_perfvc;
logic csr_perfvd;
logic csr_perfve;
logic csr_perfvf;
logic csr_perfvg;
logic csr_perfvh;
logic csr_perfvi;
/*pragma coverage on*/
logic csr_mpmc;
logic csr_mcpc;
logic csr_meicpct;
logic csr_mdeau;
logic csr_micect;
logic csr_miccmect;
logic csr_mdccmect;
logic csr_mfdht;
logic csr_mfdhs;
logic csr_dicawics;
logic csr_dicad0h;
logic csr_dicad0;
logic csr_dicad1;
logic csr_dicago;
logic csr_pmpcfg;
logic csr_pmpaddr0;
logic csr_pmpaddr16;
logic csr_pmpaddr32;
logic csr_pmpaddr48;
logic valid_only;
logic presync;
logic postsync;
assign csr_misa = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]);

assign csr_mvendorid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_marchid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mimpid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_mhartid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[2]);

assign csr_mstatus = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]);

assign csr_mtvec = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]);

assign csr_mip = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[2]);

assign csr_mie = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]);

assign csr_mcyclel = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]);

assign csr_mcycleh = (dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]);

assign csr_minstretl = (!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_minstreth = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mscratch = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mepc = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mcause = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mscause = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[2]);

assign csr_mtval = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mrac = (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]);

assign csr_dmst = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]);

assign csr_mdseac = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]);

assign csr_meihap = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[3]);

assign csr_meivt = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_meipt = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_meicurpl = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[2]);

assign csr_meicidpl = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_dcsr = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[0]);

assign csr_mcgc = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[0]);

assign csr_mfdc = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_dpc = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[0]);

assign csr_mtsel = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mtdata1 = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[0]);

assign csr_mtdata2 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[1]);

assign csr_mhpmc3 = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc4 = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpmc5 = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc6 = (!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpmc3h = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc4h = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpmc5h = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc6h = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpme3 = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpme4 = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpme5 = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpme6 = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]);

assign csr_mcountinhibit = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[0]);

assign csr_mitctl0 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]);

assign csr_mitctl1 = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_mitb0 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_mitb1 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mitcnt0 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[0]);

assign csr_mitcnt1 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_perfva  = 1'b0;

assign csr_perfvb  = 1'b0;

assign csr_perfvc  = 1'b0;

assign csr_perfvd  = 1'b0;

assign csr_perfve  = 1'b0;

assign csr_perfvf  = 1'b0;

assign csr_perfvg  = 1'b0;

assign csr_perfvh  = 1'b0;

assign csr_perfvi  = 1'b0;

assign csr_mpmc = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]);

assign csr_mcpc = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]);

assign csr_meicpct = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mdeau = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[3]);

assign csr_micect = (dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_miccmect = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[0]);

assign csr_mdccmect = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mfdht = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mfdhs = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]);

assign csr_dicawics = (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_dicad0h = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]);

assign csr_dicad0 = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_dicad1 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_dicago = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_pmpcfg = (!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]);

assign csr_pmpaddr0 = (!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]);

assign csr_pmpaddr16 = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]);

assign csr_pmpaddr32 = (!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[4]);

assign csr_pmpaddr48 = (dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]);

assign valid_only = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]) | (
    !dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[4]) | (
    !dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[3]) | (
    !dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[3]);

assign presync = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[0]) | (
    dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign postsync = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]) | (
    dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

logic legal;
assign legal = (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]) | (
    !dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]) | (
    dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (
    dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]) | (
    !dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[3]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[3]) | (!dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]) | (
    dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]);


```

### design/dec/el2_dec_pmp_ctl.sv

```verilog
module el2_dec_pmp_ctl
  import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic clk,
   input logic free_l2clk,
   input logic csr_wr_clk,
   input logic rst_l,
   input logic        dec_csr_wen_r_mod,  // csr write enable at wb
   input logic [11:0] dec_csr_wraddr_r,   // write address for csr
   input logic [31:0] dec_csr_wrdata_r,   // csr write data at wb
   input logic [11:0] dec_csr_rdaddr_d,   // read address for csr

   input logic csr_pmpcfg,
   input logic csr_pmpaddr0,
   input logic csr_pmpaddr16,
   input logic csr_pmpaddr32,
   input logic csr_pmpaddr48,

   input logic dec_pause_state, // Paused
   input logic dec_tlu_pmu_fw_halted, // pmu/fw halted
   input logic internal_dbg_halt_timers, // debug halted

`ifdef RV_SMEPMP
   input el2_mseccfg_pkt_t mseccfg,
`endif

   output logic [31:0] dec_pmp_rddata_d,  // pmp CSR read data
   output logic        dec_pmp_read_d,    // pmp CSR address match

   output el2_pmp_cfg_pkt_t pmp_pmpcfg  [pt.PMP_ENTRIES],
   output logic [31:0]      pmp_pmpaddr [pt.PMP_ENTRIES],

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic        scan_mode
   /*pragma coverage on*/
   );

```

### design/dec/el2_dec_tlu_ctl.sv

```verilog
module el2_dec_timer_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic clk,
   input logic free_l2clk,
   input logic csr_wr_clk,
   input logic rst_l,
   input logic        dec_csr_wen_r_mod,      // csr write enable at wb
   input logic [11:0] dec_csr_wraddr_r,      // write address for csr
   input logic [31:0] dec_csr_wrdata_r,   // csr write data at wb

   input logic csr_mitctl0,
   input logic csr_mitctl1,
   input logic csr_mitb0,
   input logic csr_mitb1,
   input logic csr_mitcnt0,
   input logic csr_mitcnt1,


   input logic dec_pause_state, // Paused
   input logic dec_tlu_pmu_fw_halted, // pmu/fw halted
   input logic internal_dbg_halt_timers, // debug halted

   output logic [31:0] dec_timer_rddata_d, // timer CSR read data
   output logic        dec_timer_read_d, // timer CSR address match
   output logic        dec_timer_t0_pulse, // timer0 int
   output logic        dec_timer_t1_pulse, // timer1 int

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic        scan_mode
   /*pragma coverage on*/
   );

```

### design/lib/beh_lib.sv

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );

// ...

module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

// ...

module rvdffe #( parameter WIDTH=1, SHORT=0, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic           en,
     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
if (SHORT == 1) begin : genblock
   if (1) begin : genblock
      assign dout = din;
   end
end
else begin : genblock

`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffe must be WIDTH >= 8");
`endif
end // else: !if(SHORT == 1)

// ...

module rvdffpcie #( parameter WIDTH=31 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic             clk,
     input  logic             rst_l,
     input  logic             en,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
`ifndef RV_PHYSICAL
   if (WIDTH == 31) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffpcie width must be 31");
`endif

// ...

module rvdffie #( parameter WIDTH=1, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,

     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
     $error("%m: rvdffie must be WIDTH >= 8");
`endif

// ...

module rvsyncss #(parameter WIDTH = 251)
   (
     input  logic                 clk,
     input  logic                 rst_l,
     input  logic [WIDTH-1:0]     din,
     output logic [WIDTH-1:0]     dout
     );

// ...

module rvoclkhdr
  (
   input  logic en,
   input  logic clk,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic scan_mode,
   /*pragma coverage on*/
   output logic l1clk
   );

```

## Documentation

### docs/source/core-control.md

```markdown
## Control/Status Registers

A summary of platform-specific control/status registers in CSR space:

* Feature Disable Control Register (mfdc), see [](core-control.md#feature-disable-control-register-mfdc)
* Clock Gating Control Register (mcgc), see [](core-control.md#clock-gating-control-register-mcgc)

All reserved and unused bits in these control/status registers must be hardwired to '0'.
Unless otherwise noted, all read/write control/status registers must have WARL (Write Any value, Read Legal value) behavior.

### Feature Disable Control Register (mfdc)

The `mfdc` register hosts low-level core control bits to disable specific features.
This may be useful in case a feature intended to increase core performance should prove to have problems.

:::{note}
`fence.i` instructions are required before and after writes to the `mfdc` register.
:::

:::{note}
The default state of the controllable features is 'enabled'. Firmware may turn off a feature if needed.
:::

This register is mapped to the non-standard read/write CSR address space.

:::{list-table} Feature Disable Control Register (mfdc, at CSR 0x7F9). Field Bits Description
:name: tab-feature-disable-cr
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:19
  - Reserved
  - R
  - 0
* - dqc
  - 18:16
  - DMA QoS control, see [](memory-map.md#quality-of-service)
  - R/W
  - 7
* - Reserved
  - 15:13
  - Reserved
  - R
  - 0
* - td
  - 12
  - Trace disable:
    - 0: enable trace
    - 1: disable trace
  - R/W
  - 0
* - elfd
  - 11
  - External load-to-load forwarding disable:
    - 0: enable external load-to-load forwarding
    - 1: disable external load-to-load forwarding
  - R/W
  - 0
* - Reserved
  - 10:9
  - Reserved
  - R
  - 0
* - cecd
  - 8
  - Core ECC check disable:
    - 0: ICCM/DCCM ECC checking enabled
    - 1: ICCM/DCCM ECC checking disabled
  - R/W
  - 0
* - dwrd
  - 7
  - DCCM write-readback check disable (only meaningful when built with `RV_DCCM_WR_READBACK`; reads 0 otherwise, see [](error-protection.md#dccm-write-readback-check)):
    - 0: DCCM write-readback check enabled
    - 1: DCCM write-readback check disabled
  - R/W
  - 0
* - sepd
  - 6
  - Side effect pipelining disable:
    - 0: side effect loads/stores are pipelined
    - 1: side effect loads/stores block all subsequent bus transactions until load/store response with default value received.

      **Note**: Reset value depends on selected bus core build argument
  - R/W
  - 0 (*AHB-Lite*) / 1 (*AXI4*)
* - Reserved
  - 5:4
  - Reserved
  - R
  - 0
* - bpd
  - 3
  - Branch prediction disable:
    - 0: enable branch prediction and return address stack
    - 1: disable branch prediction and return address stack
  - R/W
  - 0
* - wbcd
  - 2
  - Write Buffer (WB) coalescing disable:
    - 0: enable Write Buffer coalescing
    - 1: disable Write Buffer coalescing
  - R/W
  - 0
* - Reserved
  - 1
  - Reserved
  - R
  - 0
* - pd
  - 0
  - Pipelining disable:
    - 0: pipelined execution
    - 1: single instruction execution
  - R/W
  - 0
:::

```

### docs/source/adaptations.md

```markdown
## Machine Cause Register (mcause)

The standard RISC-V mcause register indicates the cause for a trap as shown in {numref}`tab-machine-cause-register`, including standard exceptions/interrupts, platform-specific local interrupts (with light gray background), and NMI causes (with dark gray background).

Additional trap information is provided in the mscause register, see [](memory-map.md#machine-secondary-cause-register-mscause) which allows the determination of the exact cause of a trap for cases where multiple, different conditions share a single trap code.

The `mcause` register has WLRL (Write Legal value, Read Legal value) behavior.

This register is a standard read/write CSR.

:::{list-table} Machine Cause Register (mcause, at CSR 0x342)
:name: tab-machine-cause-register
:header-rows: 1

* - **Type**
  - **Trap Code**
  - **Value mcause[31:0]**
  - **Description**
  - **Section(s)**
* - **NMI**
  - N/A
  - 0x0000_0000
  - NMI pin assertion
  - [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)
* - **Exception**
  - 1
  - 0x0000_0001
  - Instruction access fault
  - [](memory-map.md#unmapped-addresses), [](memory-map.md#uncorrectable-ecc-errors), and [](error-protection.md#error-detection-and-handling)
* -
  - 2
  - 0x0000_0002
  - Illegal instruction
  - \-
* -
  - 3
  - 0x0000_0003
  - Breakpoint
  - \-
* -
  - 4
  - 0x0000_0004
  - Load address misaligned
  - [](memory-map.md#misaligned-accesses)
* -
  - 5
  - 0x0000_0005
  - Load access fault
  - [](memory-map.md#unmapped-addresses), [](memory-map.md#uncorrectable-ecc-errors), and [](error-protection.md#error-detection-and-handling)
* -
  - 6
  - 0x0000_0006
  - Store/AMO address misaligned
  - [](memory-map.md#misaligned-accesses)
* -
  - 7
  - 0x0000_0007
  - Store/AMO access fault
  - [](memory-map.md#unmapped-addresses), [](memory-map.md#uncorrectable-ecc-errors), and [](error-protection.md#error-detection-and-handling)
* -
  - 11
  - 0x0000_000B
  - Environment call from M-mode
  - \-
* - **Interrupt**
  - 3
  - 0x8000_0003
  - Machine software interrupt
  - [](memory-map.md#software-interrupts)
* -
  - 7
  - 0x8000_0007
  - Machine timer [^fn-adaptations-1] interrupt
  - \-
* -
  - 11
  - 0x8000_000B
  - Machine external interrupt
  - [](interrupts.md)
* -
  - 28
  - 0x8000_001C
  - Machine internal timer 1 local interrupt
  - [](timers.md#internal-timer-local-interrupts)
* -
  - 29
  - 0x8000_001D
  - Machine internal timer 0 local interrupt
  - [](timers.md#internal-timer-local-interrupts)
* -
  - 30
  - 0x8000_001E
  - Machine correctable error local interrupt
  - [](memory-map.md#correctable-error-local-interrupt)
* - **NMI**
  - N/A
  - 0xF000_0000
  - Machine D-bus store error NMI
  - [](memory-map.md#imprecise-bus-error-non-maskable-interrupt) and [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)
* -
  - N/A
  - 0xF000_0001
  - Machine D-bus non-blocking load error NMI
  - [](memory-map.md#imprecise-bus-error-non-maskable-interrupt) and [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)
* -
  - N/A
  - 0xF000_1000
  - Machine Fast Interrupt double-bit ECC error NMI
  - [](interrupts.md#fast-interrupt-redirect) and [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)
* -
  - N/A
  - 0xF000_1001
  - Machine Fast Interrupt DCCM region access error NMI
  - [](interrupts.md#fast-interrupt-redirect) and [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)
* -
  - N/A
  - 0xF000_1002
  - Machine Fast Interrupt non-DCCM region NMI
  - [](interrupts.md#fast-interrupt-redirect) and [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)
:::

[^fn-adaptations-1]: Core external timer

:::{note}
All other values are reserved.
:::

## Machine Hardware Thread ID Register (mhartid)

The standard RISC-V `mhartid` register provides the integer ID of the hardware thread running the code.
Hart IDs must be unique.
Hart IDs might not necessarily be numbered contiguously in a multiprocessor system, but at least one hart must have a hart ID of zero.

:::{note}
In certain cases, it must be ensured that exactly one hart runs some code (e.g., at reset), hence the requirement for one hart to have a known hart ID of zero.
:::

The `mhartid` register is split into two fixed-sized fields.
The SoC must provide a hardwired core ID on the `core_id[31:4]` bus.
The value provided on that bus sources the `mhartid` register's *coreid* field.
If the SoC hosts more than one RISC-V core, each core must have its own unique `core_id` value.
Each hardware thread of the core has a unique, hardwired thread ID which is reflected in the `mhartid` register's *hartid* field starting at 0x0 up to 0xF.

VeeR EL2 implements a single hardware thread with thread ID 0x0.

This register is a standard read-only CSR.

:::{list-table} Machine Hardware Thread ID Register (mhartid, at CSR 0xF14)
:name: tab-machine-hw-thread-id-register
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - coreid
  - 31:4
  - Core ID of this VeeR EL2
  - R
  - `core_id[31:4]` bus value  (see {numref}`tab-core-complex-signals`)
* - hartid
  - 3:0
  - Hardwired per-core hart ID:  0x0: thread 0 (master thread)
  - R
  - 0x0
:::

```

### docs/source/cache.md

```markdown
## I-Cache Control/Status Registers

A summary of the I-cache control/status registers in CSR address space:
* [](cache.md#i-cache-arraywayindex-selection-register-dicawics)
* [](cache.md#i-cache-array-data-0-register-dicad0)
* [](cache.md#i-cache-array-data-0-high-register-dicad0h)
* [](cache.md#i-cache-array-data-1-register-dicad1)
* [](cache.md#i-cache-array-go-register-dicago)

All reserved and unused bits in these control/status registers must be hardwired to '0'.
Unless otherwise noted, all read/write control/status registers must have WARL (Write Any value, Read Legal value) behavior.

### I-Cache Array/Way/Index Selection Register (dicawics)

The `dicawics` register is used to select a specific location in either the data array or the tag array / status of the Icache.
In addition to selecting the array, the location in the array must be specified by providing the way, and index.
Once selected, the `dicad0/0h/1` registers (see [](cache.md#i-cache-array-data-0-register-dicad0), [](cache.md#i-cache-array-data-0-high-register-dicad0h), and [](cache.md#i-cache-array-data-1-register-dicad1)) hold the information read from or to be written to the specified location, and the dicago register (see [](cache.md#i-cache-array-go-register-dicago)) is used to control the read/write access to the specified I-cache array.

The cache line size of the I-cache is either 64 or 32 bytes.
The `dicawics` register addresses a 64-bit chunk of instruction data or a cache line tag with its associated status.
Each 64-bit instruction data chunk is protected either with four parity bits (each covering 16 consecutive instruction data bits) or with 7-bit ECC (covering all 64 instruction data bits).
There are 8 such chunks in a 64-byte or 4 such chunks in a 32-byte cache line.
Each cache line tag is protected either with a single parity bit or with 5-bit ECC.

:::{note}
This register is accessible in **Debug Mode only**. Attempting to access this register in machine mode raises an illegal instruction exception.
:::

This register is mapped to the non-standard read-write CSR address space.

:::{list-table} I-Cache Array/Way/Index Selection Register (dicawics, at CSR 0x7C8)
:name: tab-cache-array-dicawics
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:25
  - Reserved
  - R
  - 0
* - array
  - 24
  - Array select:

    0: I-cache data array (incl. parity/ECC bits)

    1: I-cache tag array (incl. parity/ECC bits) and status (incl. valid and  LRU bits)
  - R/W
  - 0
* - Reserved
  - 23:22
  - Reserved
  - R
  - 0
* - way
  - 21:20
  - Way select:

    Four-way set-associative cache: *way[21:20]*

    Two-way set-associative cache: *way[20]* (*way[21]* reserved, must be 0)
  - R/W
  - 0
* - Reserved
  - 19:17
  - Reserved
  - R
  - 0
* - index [^fn-cache-1]
  - 16:3
  - Index address bits select

    **Notes:**

    - Index bits are right-justified:

    	- For 4-way set-associative cache, *index[16]* and other unused upper  bits (for I-cache sizes smaller than 256KB) must be 0

    	- For 2-way set-associative cache, unused upper bits (for I-cache  sizes smaller than 256KB) must be 0

    - For tag array and status access:

    	- For 64-byte cache line size, bits 5..3 are ignored by hardware

    	- For 32-byte cache line size, bits 4..3 are ignored by hardware

    - This field does not have WARL behavior
  - R/W
  - 0
* - Reserved
  - 2:0
  - Reserved
  - R
  - 0
:::

[^fn-cache-1]: VeeR EL2’s I-cache supports four- or two-way set-associativity and cache line sizes of 64 or 32 bytes. Each way is subdivided into 2 banks, and each bank is 8 bytes wide. A bank is selected by index[3], and index[2:0] address a byte of the 8-byte wide bank.

### I-Cache Array Data 0 Register (dicad0)

The `dicad0` register, in combination with the `dicad0h/1` registers (see [](cache.md#i-cache-array-data-0-high-register-dicad0h) and [](cache.md#i-cache-array-data-1-register-dicad1)), is used to store information read from or to be written to the I-cache array location specified with the `dicawics` register (see [](cache.md#i-cache-arraywayindex-selection-register-dicawics)).
Triggering a read or write access of the I-cache array is controlled by the `dicago` register (see [](cache.md#i-cache-array-go-register-dicago)).

The layout of the dicad0 register is different for the data array and the tag array / status, as described in {numref}`tab-cache-array-dicad0` below.

:::{note}
During normal operation, the parity/ECC bits over the 64-bit instruction data as well as the tag are generated and checked by hardware.
However, to enable error injection, the parity/ECC bits must be computed by software for I-cache data and tag array diagnostic writes.
:::

:::{note}
This register is accessible in **Debug Mode only**.
Attempting to access this register in machine mode raises an illegal instruction exception.
:::

This register is mapped to the non-standard read-write CSR address space.

:::{list-table} I-Cache Array Data 0 Register (dicad0, at CSR 0x7C9)
:name: tab-cache-array-dicad0
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset|**
* - **I-cache data array**
  -
  -
  -
  -
* - instr
  - 31:0
  - Instruction data

    31:16: instruction data bytes 3/2 (protected by *parity1* / *ecc*)

    15:0: instruction data bytes 1/0 (protected by *parity0* / *ecc*)
  - R/W
  - 0
* - **I-cache tag array and status bits**
  -
  -
  -
  -
* - tag
  - 31:11
  - Tag

    **Note:**

    Tag bits are right-justified; unused higher bits (for I-cache sizes larger than 8KB) must be 0
  - R/W
  - 0
* - Unused
  - 10:7
  - Unused
  - R/W
  - 0
* - lru
  - 6:4
  - Pseudo LRU bits (same bits are accessed independent of selected way):

    Four-way set-associative cache:

      - *lru[4]*: way0/1 / way2/3 selection

    	  - 0: way0/1

    	  - 1: way2/3

      - *lru[5]*: way0 / way1 selection

    	  - 0: way0

    	  - 1: way1

  	  - *lru[6]*: way2 / way3 selection

    	  - 0: way2

    	  - 1: way3

    Two-way set-associative cache:

      - *lru[4]*: way0 / way1 selection

    	  - 0: way0

    	  - 1: way1

	    - *lru[6:5]*: Reserved (must be 0)
  - R/W
  - 0
* - Unused
  - 3:1
  - Unused
  - R/W
  - 0
* - valid
  - 0
  - Cache line valid/invalid:

  	  - 0: cache line invalid

      - 1: cache line valid
  - R/W
  - 0
:::


...

### I-Cache Array Data 1 Register (dicad1)

The `dicad1` register, in combination with the `dicad0/0h` registers (see [](cache.md#i-cache-array-data-0-register-dicad0) and [](cache.md#i-cache-array-data-0-high-register-dicad0h)), is used to store information read from or to be written to the I-cache array location specified with the `dicawics` register (see [](cache.md#i-cache-arraywayindex-selection-register-dicawics)).
Triggering a read or write access of the I-cache array is controlled by the `dicago` register (see [](cache.md#i-cache-array-go-register-dicago)).

The layout of the `dicad1` register is described in {numref}`tab-cache-array-dicad1` below.

:::{note}
During normal operation, the parity/ECC bits over the 64-bit instruction data as well as the tag are generated and checked by hardware.
However, to enable error injection, the parity/ECC bits must be computed by software for I-cache data and tag array diagnostic writes.
:::

:::{note}
This register is accessible in **Debug Mode only**.
Attempting to access this register in machine mode raises an illegal instruction exception.
:::

This register is mapped to the non-standard read-write CSR address space.

:::{list-table} I-Cache Array Data 1 Register (dicad1, at CSR 0x7CA).
:name: tab-cache-array-dicad1
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - **Parity**
  -
  -
  -
  -
* - **Instruction data**
  -
  -
  -
  -
* - Reserved
  - 31:4
  - Reserved
  - R
  - 0
* - parity3
  - 3
  - Even parity for I-cache data bytes 7/6 (*instr[31:16]* in `dicad0h`)
  - R/W
  - 0
* - parity2
  - 2
  - Even parity for I-cache data bytes 5/4 (*instr[15:0]* in `dicad0h`)
  - R/W
  - 0
* - parity1
  - 1
  - Even parity for I-cache data bytes 3/2 (*instr[31:16]* in `dicad0`)
  - R/W
  - 0
* - parity0
  - 0
  - Even parity for I-cache data bytes 1/0 (*instr[15:0]* in `dicad0`)
  - R/W
  - 0
* - **Tag**
  -
  -
  -
  -
* - Reserved
  - 31:1
  - Reserved
  - R
  - 0
* - parity0
  - 0
  - Even parity for I-cache tag (tag)
  - R/W
  - 0
* - **ECC**
  -
  -
  -
  -
* - **Instruction data**
  -
  -
  -
  -
* - Reserved
  - 31:7
  - Reserved
  - R
  - 0
* - ecc
  - 6:0
  - ECC for I-cache data bytes 7/6/5/4/3/2/1/0 (*instr[31:0]* in `dicad0h` and *instr[31:0]* in `dicad0`)
  - R/W
  - 0
* - **Tag**
  -
  -
  -
  -
* - Reserved
  - 31:5
  - Reserved
  - R
  - 0
* - ecc
  - 4:0
  - ECC for I-cache tag (tag)
  - R/W
  - 0
:::

### I-Cache Array Go Register (dicago)

The `dicago` register is used to trigger a read from or write to the I-cache array location specified with the `dicawics` register (see [](cache.md#i-cache-arraywayindex-selection-register-dicawics)).
Reading the `dicago` register populates the `dicad0/dicad0h/dicad1` registers (see [](cache.md#i-cache-array-data-0-register-dicad0), [](cache.md#i-cache-array-data-0-high-register-dicad0h), and [](cache.md#i-cache-array-data-1-register-dicad1)) with the information read from the I-cache array.
Writing a '1' to the go field of the dicago register copies the information stored in the dicad0/dicad0h /dicad1 registers to the I-cache array.
The layout of the dicago register is described in {numref}`tab-cache-array-dicago` below.

:::{note}
This register is accessible in **Debug Mode only**. Attempting to access this register in machine mode raises an illegal instruction exception.
:::

The *go* field of the `dicago` register has W1R0 (Write 1, Read 0) behavior, as also indicated in the 'Access' column.

This register is mapped to the non-standard read-write CSR address space.

:::{list-table} I-Cache Array Go Register (dicago, at CSR 0x7CB)
:name: tab-cache-array-dicago
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:1
  - Reserved
  - R
  - 0
* - go
  - 0
  - Read triggers an I-cache read, write-1 triggers an I-cache write
  - R0/W1
  - 0
:::

```

### docs/source/power.md

```markdown
## Power States

From a system's perspective, the core may be placed in one of three power states: Active (C0), Sleep (C3), and Power Off (C6).
Active and Sleep states require hardware support from the core, but in the Power Off state the core is power-gated so no special hardware support is needed.

{numref}`fig-activity-states` depicts and {numref}`tab-core-activity-states` describes the core activity states as well as the events to transition between them.

:::{figure-md} fig-activity-states
![Activity states](img/activity_states.png)

VeeR EL2 Core Activity States
:::

:::{note}
'Core Quiesced' implies that no new instructions are executed and all outstanding core-initiated bus transactions are completed (i.e., the unified buffer is empty, and all outstanding I-cache misses are finished).
Note that the store queue and the DMA FIFO might not be empty due to on-going DMA transactions.
:::

:::{list-table} Debug Resume Requests
:name: tab-debug-resume-requests
:header-rows: 1

* - Core-Internal State
  -
  -
  -
  -
  -
  - **Comments**
* - **Debug Resume**
  - **Debug Halt**
  - **MPC Halt**
  - **MPC Run**
  - **Halted (This Cycle)**
  - **Halted (Next Cycle)**
  -
* - 0
  - 0
  - 0
  - 0
  - 0
  - 0
  - No request for Debug Mode entry
* - 0
  - 0
  - 0
  - 1
  -
  -
  - No action required from core (requires coordination outside of core)
* - 0
  - 0
  - 1
  - 0
  - 1
  - 1
  - Waiting for MPC Run (core remains in ‘db-halt’ state)
* - 0
  - 0
  - 1
  - 1
  - 1
  - 0
  - MPC Run Ack
* - 0
  - 1
  - 0
  - 0
  - 1
  - 1
  - Waiting for Debug Resume (core remains in ‘db-halt’ state)
* - 0
  - 1
  - 0
  - 1
  -
  -
  - No action required from core (requires coordination outside of core)
* - 0
  - 1
  - 1
  - 0
  - 1
  - 1
  - Waiting for both MPC Run and Debug Resume (core remains in ‘db-halt’ state)
* - 0
  - 1
  - 1
  - 1
  - 1
  - 1
  - Waiting for Debug Resume (core remains in ‘db-halt’ state)
* - 1
  - 0
  - 0
  - 0
  -
  -
  - No action required from core (requires coordination outside of core)
* - 1
  - 0
  - 0
  - 1
  -
  -
  - No action required from core (requires coordination outside of core)
* - 1
  - 0
  - 1
  - 0
  -
  -
  - No action required from core (requires coordination outside of core)
* - 1
  - 0
  - 1
  - 1
  -
  -
  - No action required from core (requires coordination outside of core)
* - 1
  - 1
  - 0
  - 0
  - 1
  - 0
  - Debug Resume Ack
* - 1
  - 1
  - 0
  - 1
  -
  -
  - No action required from core (requires coordination outside of core)
* - 1
  - 1
  - 1
  - 0
  - 1
  - 1
  - Waiting for MPC Run (core remains in ‘db-halt’ state)
* - 1
  - 1
  - 1
  - 1
  - 1
  - 0
  - Debug Resume Ack and MPC Run Ack
:::

:::{note}
While in 'db-halt' state, hardware ignores Debug Resume requests if the corresponding 'Debug Halt' state is not '1'.
Likewise, hardware ignores MPC Debug Run requests if the corresponding 'MPC Halt' state is not '1'.
:::

:::{note}
The core-internal state bits are cleared upon exiting Debug Mode.
:::

:::{note}
In the time period between an MPC Debug Halt request and an MPC Debug Run request, a core debug singlestep action is stalled but stays pending.
:::

:::{note}
Even if the core is already in Debug Mode due to a previous MPC Debug Halt request, a core debugger must initiate a debug halt (i.e., Core Debug Halt request) before it may start issuing other debug commands. However, if Debug Mode was entered due to a core debug breakpoint, a Core Debug Halt request is not required.
:::

:::{note}
An MPC Debug Halt request may only be signaled when the core is either not in Debug Mode or is already in Debug Mode due to a previous Core Debug Halt request or a debug breakpoint or trigger. Also, an MPC Debug Run request may only be signaled when the core is in Debug Mode due to either a previous MPC Debug Halt request, a previous Core Debug Halt request, or a debug breakpoint or trigger. Issuing more than one MPC Debug Halt requests in succession or more than one MPC Debug Run requests in succession is a protocol violation.
:::

:::{list-table} Core Activity States
:name: tab-core-activity-states
:header-rows: 1

* -
  - **Active (C0)**
  - **Active (C0)**
  - **Sleep (C3)**
* -
  - **Running**
  - **Halted**
  - **Halted**
* -
  -
  - **db-halt**
  - **pmu/fw-halt**
* - **State Description**
  - Core operating normally
  - Core halted in Debug Mode
  - Core halted by PMU halt request or by core firmware-initiated halt
* - **Power Savings**
  - Fine-grain clock gating integrated in core minimizes power consumption during regular operation
  - Fine-grain clock gating
  - Enhanced clock gating in addition to fine-grain clock gating
* - **DMA Access**
  - DMA accesses allowed
  - DMA accesses allowed
  - DMA accesses allowed
* - **State Indication**
  -
    - `cpu_halt_status` is low
    - `debug_mode_status` is low (except for Core Debug Resume request with Single Step action)
  -
    - `cpu_halt_status` is low
    - `debug_mode_status` is high
  -
    - `cpu_halt_status` is high
    - `debug_mode_status` is low
* - **Internal Timer Counters**
  - `mitcnt0/1` incremented every core clock cycle (also during execution of instructions while single-stepping in Debug Mode)
  - `mitcnt0/1` not incremented
  - Depends on *halt_en* bit in `mitctl0/1` registers:
    - 0: `mitcnt0/1` not incremented
    - 1: `mitcnt0/1` incremented every core clock cycle
* - **Machine Cycle Performance- Monitoring Counter**
  - `mcycle` incremented every core clock cycle
  - Depends on *stopcount* bit of `dcsr` register (see [](debugging.md#debug-control-and-status-register-dcsr)):
    - 0: `mcycle` incremented every core clock cycle
    - 1: `mcycle` not incremented
  - `mcycle` not incremented
:::

## Power Control

The priority order of simultaneous halt requests is as follows:
1. Any core debug halt action:
    * Core debug halt request
    * Core debug single step
    * Core debug breakpoint
    * Core debug trigger
- or MPC debug halt request
2. PMU halt request or core firmware-initiated halt

If the PMU sends a halt request while the core is in Debug Mode, the core disregards the halt request.
If the PMU's halt request is still pending when the core exits Debug Mode, the request is honored at that time.
Similarly, core firmware can't initiate a halt while in Debug Mode.
However, it is not possible for a core firmware-initiated halt request to be pending when the core exits Debug Mode.

:::{important}
There are two separate sources of debug operations: the core itself which conforms to the standard RISC-V Debug specification [[3]](intro.md#ref-3), and the Multi-Processor Controller (MPC) IP block which provides multi-core debug capabilities.
These two sources may interfere with each other and need to be carefully coordinated on a higher level outside the core.
Unintended behavior might occur if simultaneous debug operations from these two sources are not synchronized (e.g., MPC requesting a resume during the execution of an abstract command initiated by the debugger attached to the JTAG port).
:::

### Debug Mode

Debug Mode must be able to seize control of the core.
Therefore, debug has higher priority than power control.

Debug Mode is entered under any of the following conditions:
* Core debug halt request
* Core debug single step
* Core debug breakpoint with halt action
* Core debug trigger with halt action
* Multi-core debug halt request (from MPC)

Debug Mode is exited with:
* Core debug resume request with no single step action
* Multi-core debug run request (from MPC)

The state 'db-halt' is the only halt state allowed while in Debug Mode.

#### Single Stepping

A few notes about executing single-stepped instructions:
* Executing instructions which attempt to exit Debug Mode are ignored (e.g., writing to the `mpmc` register requesting to halt the core does not transition the core to the pmu/fw-halt state).
* Accesses to D-mode registers are illegal, even though the core is in Debug Mode.
* A core debug single-step action initiated in the time period between an MPC Debug Halt request and an MPC Debug Run request is stalled but stays pending until an MPC Debug Run request is issued.

#### Forced Debug Halt

Upon receiving a debug halt request (i.e., either a Core Debug or MPC Debug Halt request, or a breakpoint or trigger to Debug Mode), the core is typically quiesced before the Debug Halt (db-halt) state is entered.
However, LSU or IFU bus transactions may not complete due to SoC or other issues outside the core which may stop the core from executing.
This may prevent the core from entering the Debug Halt state after a debug halt request has been received.
To enable a debugger taking control of the core, ongoing LSU and IFU bus transactions may be terminated after a programmable timeout period (see [](power.md#forced-debug-halt-threshold-register-mfdht)) has passed, forcing the core into the Debug Halt state.
Once the debugger has control of the core, it may read a status register (see [](power.md#forced-debug-halt-status-register-mfdhs)) to inquire if LSU or IFU bus transactions have been terminated and data might have been lost.

:::{note}
 This feature is targeted at allowing a debugger to take control of a hung core. Therefore, the timeout period should be set high enough to cover any reasonable delay incurred by any access to SoC memory locations and devices. This should include potential additional delays due to congestion in the interconnect and other possible temporary conditions. If the timeout period is long enough for all outstanding transactions to gracefully finish, program execution may be resumed after debugging has been performed. However, if any outstanding transactions are prematurely forced to terminate, successfully resuming program execution after debug should not be expected because the data of terminated transactions may have been lost and possibly even a reset of the SoC might be necessary to bring the system back into a consistent state.
:::

```
