# Implement `el2_dec_timer_ctl`

Implement the complete `el2_dec_timer_ctl` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_dec_timer_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Parent instantiation

```verilog
   // CSR address decoder

// files "csrdecode_m" (machine mode only) and "csrdecode_mu" (machine mode plus
// user mode) are human readable that have all of the CSR decodes defined and
// are part of the git repo. Modify these files as needed.

// to generate all the equations below from "csrdecode" except legal equation:

// 1) coredecode -in csrdecode > corecsrdecode.e

// 2) espresso -Dso -oeqntott < corecsrdecode.e | addassign > csrequations

// to generate the legal CSR equation below:

// 1) coredecode -in csrdecode -legal > csrlegal.e

// 2) espresso -Dso -oeqntott < csrlegal.e | addassign > csrlegal_equation

// coredecode -in csrdecode > corecsrdecode.e; espresso -Dso -oeqntott < corecsrdecode.e | addassign > csrequations; coredecode -in csrdecode -legal > csrlegal.e; espresso -Dso -oeqntott csrlegal.e | addassign > csrlegal_equation

`ifdef RV_USER_MODE

   `include "el2_dec_csr_equ_mu.svh"

   logic  csr_acc_r;    // CSR access error
   logic  csr_wr_usr_r; // Write to an unprivileged/user-level CSR
   logic  csr_rd_usr_r; // REad from an unprivileged/user-level CSR

`else

   `include "el2_dec_csr_equ_m.svh"

`endif

   el2_dec_timer_ctl  #(.pt(pt)) int_timers(.*);
   // end of internal timers

   el2_dec_pmp_ctl  #(.pt(pt)) pmp(.*);
   // end of pmp

   assign clk_override = dec_tlu_dec_clk_override;

   // Async inputs to the core have to be sync'd to the core clock.
   rvsyncss #(7) syncro_ff(.*,
                           .clk(free_clk),
                           .din ({nmi_int,      timer_int,      soft_int,      i_cpu_halt_req,      i_cpu_run_req,      mpc_debug_halt_req,          mpc_debug_run_req}),
                           .dout({nmi_int_sync, timer_int_sync, soft_int_sync, i_cpu_halt_req_sync, i_cpu_run_req_sync, mpc_debug_halt_req_sync_raw, mpc_debug_run_req_sync}));

   // for CSRs that have inpipe writes only

   rvoclkhdr csrwr_r_cgc   ( .en(dec_csr_wen_r_mod | clk_override), .l1clk(csr_wr_clk), .* );

   // ...

   //When executing a MRET instruction, supposing MPP holds the value 3, MIE
   //is set to MPIE; the privilege mode is changed to 3; MPIE is set to 1; and MPP is set to 3
`ifdef RV_USER_MODE
   assign dec_csr_wen_r_mod = dec_csr_wen_r & ~i0_trigger_hit_r & ~rfpc_i0_r & ~csr_acc_r;
`else
   assign dec_csr_wen_r_mod = dec_csr_wen_r & ~i0_trigger_hit_r & ~rfpc_i0_r;
`endif

   assign wr_mstatus_r = dec_csr_wen_r_mod & (dec_csr_wraddr_r[11:0] == MSTATUS);

```

## Dependency declarations

```verilog
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

```

## Related source code

### design/dec/csrdecode_m

```text
csr_mitctl0 =       [011111010100]
csr_mitctl1 =       [011111010111]
csr_mitb0 =         [011111010011]
csr_mitb1 =         [011111010110]
csr_mitcnt0 =       [011111010010]
csr_mitcnt1 =       [011111010101]

...

.input

csr = {
        dec_csr_rdaddr_d[11]
        dec_csr_rdaddr_d[10]
        dec_csr_rdaddr_d[9]
        dec_csr_rdaddr_d[8]
        dec_csr_rdaddr_d[7]
        dec_csr_rdaddr_d[6]
        dec_csr_rdaddr_d[5]
        dec_csr_rdaddr_d[4]
        dec_csr_rdaddr_d[3]
        dec_csr_rdaddr_d[2]
        dec_csr_rdaddr_d[1]
        dec_csr_rdaddr_d[0]
}

```

## Documentation

### docs/source/timers.md

```markdown
## Description

The VeeR EL2 core implements two internal timers.
The `mitcnt0` and `mitcnt1` registers (see [Internal Timer Counter 0 / 1 Register (mitcnt0/1)](timers.md#internal-timer-counter-0-1-register-mitcnt0-1)) are 32-bit unsigned counters.
Each counter also has a corresponding 32-bit unsigned bound register (i.e., `mitb0` and `mitb1`, see [Internal Timer Bound 0 / 1 Register (mitb0/1)](timers.md#internal-timer-bound-0-1-register-mitb0-1)) and control register (i.e., `mitctl0` and `mitctl1`, see [Internal Timer Control 0 / 1 Register (mitctl0/1)](timers.md#internal-timer-control-0-1-register-mitctl0-1)).

All registers are cleared at reset unless otherwise noted.
After reset, the counters start incrementing the next clock cycle if the increment conditions are met.
All registers can be read as well as written at any time.
The `mitcnt0/1` and `mitb0/1` registers may be written to any 32-bit value.
If the conditions to increment are met, the corresponding counter `mitcnt0/1` increments every clock cycle.

Cascade mode (see [Internal Timer Control 0 / 1 Register (mitctl0/1)](timers.md#internal-timer-control-0-1-register-mitctl0-1)) links the two counters together.
The `mitcnt1` register is only incremented when the conditions to increment `mitcnt1` are met and the `mitcnt0` register is greater than or equal to the bound in its `mitb0` register.

For each timer, a local interrupt (see [](timers.md#internal-timer-local-interrupts)) is triggered when that counter is at or above its bound.
When a counter is at or above its bound, it gets cleared the next clock cycle (i.e., the interrupt condition is not sticky).

:::{note}
If the core is in Debug Mode and being single-stepped, it may take multiple clock cycles to execute a single instruction. If the conditions to increment are met, the counter increments for every clock cycle it takes to execute a single instruction. Therefore, every executed single-stepped instruction in Debug Mode may result in multiple counter increments.
:::

:::{note}
If the core is in the Debug Mode's Halted (i.e., db-halt) state, an internal timer interrupt does not transition the core back to the Active (i.e., Running) state.
:::

...

## Control/Status Registers

A summary of platform-specific internal timer control/status registers in CSR space:

- [Internal Timer Counter 0 / 1 Register (mitcnt0/1)](timers.md#internal-timer-counter-0-1-register-mitcnt0-1)
- [Internal Timer Bound 0 / 1 Register (mitb0/1)](timers.md#internal-timer-bound-0-1-register-mitb0-1)
- [Internal Timer Control 0 / 1 Register (mitctl0/1)](timers.md#internal-timer-control-0-1-register-mitctl0-1)

All reserved and unused bits in these control/status registers must be hardwired to '0'.
Unless otherwise noted, all read/write control/status registers must have WARL (Write Any value, Read Legal value) behavior.

### Internal Timer Counter 0 / 1 Register (mitcnt0/1)

The `mitcnt0` and `mitcnt1` registers are the counters of the internal timer 0 and 1, respectively.

The conditions to increment a counter are:

- The *enable* bit in the corresponding mitctl0/1 register is '1',
- if the core is in Sleep (i.e., pmu/fw-halt) state, the *halt_en* bit in the corresponding `mitctl0/1` register is '1',
- if the core is paused, the *pause_en* bit in the corresponding `mitctl0/1` register is '1', and
- the core is not in Debug Mode, except while executing a single-stepped instruction.

A counter is cleared if its value is greater than or equal to its corresponding mitb0/1 register.

:::{note}
If a write to the `mitcnt0/1` register is committed in the same clock cycle as the timer interrupt condition is met, the internal timer local interrupt is triggered, if enabled, but the counter is not cleared in this case. Instead, the counter is set to the written value.
:::

These registers are mapped to the non-standard read/write CSR address space.

:::{list-table} Internal Timer Counter 0 / 1 Register (mitcnt0/1, at CSR 0x7D2 / 0x7D5)
:name: tab-internal-timer-counter-register
:header-rows: 1
:align: left

* - Field
  - Bits
  - Description
  - Access
  - Reset
* - count
  - 31:0
  - Counter
  - R/W
  - 0
:::

### Internal Timer Bound 0 / 1 Register (mitb0/1)

The `mitb0` and `mitb1` registers hold the upper bounds of the internal timer 0 and 1, respectively.

These registers are mapped to the non-standard read/write CSR address space.

:::{list-table} Internal Timer Bound 0 / 1 Register (mitb0/1, at CSR 0x7D3 / 0x7D6)
:name: tab-internal-timer-bound-register
:header-rows: 1
:align: left

* - Field
  - Bits
  - Description
  - Access
  - Reset
* - bound
  - 31:0
  - Bound
  - R/W
  - 0xFFFF_FFFF
:::

### Internal Timer Control 0 / 1 Register (mitctl0/1)

The `mitctl0` and `mitctl1` registers provide the control bits of the internal timer 0 and 1, respectively.

:::{note}
When in cascade mode, it is highly recommended to program the enable, *halt_en*, and *pause_en* control bits of the `mitctl1` register the same as the `mitctl0` register.
:::

These registers are mapped to the non-standard read/write CSR address space.

:::{list-table} Internal Timer Control 0 / 1 Register (mitctl0/1, at CSR 0x7D4 / 0x7D7)
:name: tab-internal-timer-control-register
:header-rows: 1
:align: left

* - Field
  - Bits
  - Description
  - Access
  - Reset
* - Reserved
  - 31:4
  - Reserved
  - R
  - 0
* - cascade **(mitctl1 only)**
  - 3
  - Cascade mode:
    - 0: Disable cascading (i.e., both internal timers operate independently) (default)
    - 1: Enable cascading (i.e., internal timer 0 and 1 are combined into a single 64-bit timer)
  - R/W
  - 0
* - pause_en
  - 2
  - Enable/disable incrementing timer counter while executing PAUSE:
    - 0: Disable incrementing (default)
    - 1: Enable incrementing 
      
    **Note:** If ‘1’ and the core is pausing (see [](power.md#core-pause-control-register-mcpc)), an internal timer interrupt terminates PAUSE and regular execution is resumed.
  - R/W
  - 0
* - halt_en
  - 1
  - Enable/disable incrementing timer counter while in Sleep (i.e., pmu/fw- halt) state:
    - 0: Disable incrementing (default)
    - 1: Enable incrementing 
    
    **Note:** If ‘1’ and the core is in Sleep (i.e., pmu/fw-halt) state, an internal timer interrupt transitions the core back to the Active (i.e., Running) state and regular execution is resumed.
  - R/W
  - 0
* - enable
  - 0
  - Enable/disable incrementing timer counter:
    - 0: Disable incrementing
    - 1: Enable incrementing (default)
  - R/W
  - 1
:::

```
