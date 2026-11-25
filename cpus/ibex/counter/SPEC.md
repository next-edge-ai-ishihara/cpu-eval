# Implement `ibex_counter`

Implement the complete `ibex_counter` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_counter` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module ibex_counter #(
  parameter int CounterWidth = 32,
  // When set `counter_val_upd_o` provides an incremented version of the counter value, otherwise
  // the output is hard-wired to 0. This is required to allow Xilinx DSP inference to work
  // correctly. When `ProvideValUpd` is set no DSPs are inferred.
  parameter bit ProvideValUpd = 0
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        counter_inc_i,
  input  logic        counterh_we_i,
  input  logic        counter_we_i,
  input  logic [31:0] counter_val_i,
  output logic [63:0] counter_val_o,
  output logic [63:0] counter_val_upd_o
);
```

## Parent instantiation

### rtl/ibex_cs_registers.sv

```verilog
  // mcycle
  ibex_counter #(
    .CounterWidth(64)
  ) mcycle_counter_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .counter_inc_i(mhpmcounter_incr[0] & ~mcountinhibit[0]),
    .counterh_we_i(mhpmcounterh_we[0]),
    .counter_we_i(mhpmcounter_we[0]),
    .counter_val_i(csr_wdata_int),
    .counter_val_o(mhpmcounter[0]),
    .counter_val_upd_o()
  );


  // minstret
  ibex_counter #(
    .CounterWidth(64),
    .ProvideValUpd(1)
  ) minstret_counter_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .counter_inc_i(mhpmcounter_incr[2] & ~mcountinhibit[2]),
    .counterh_we_i(mhpmcounterh_we[2]),
    .counter_we_i(mhpmcounter_we[2]),
    .counter_val_i(csr_wdata_int),
    .counter_val_o(minstret_raw),
    .counter_val_upd_o(minstret_next)
  );

  // Where the writeback stage is present instruction in ID observing value of minstret must take
  // into account any instruction in the writeback stage. If one is present the incremented value of
  // minstret is used. A speculative version of the signal is used to aid timing. When the writeback
  // stage sees an exception (so the speculative signal is incorrect) the ID stage will be flushed
  // so the incorrect value doesn't matter. A similar behaviour is required for the compressed
  // instruction retired counter below. When the writeback stage isn't present the speculative
  // signals are always 0.
  assign mhpmcounter[2] = instr_ret_spec_i & ~mcountinhibit[2] ? minstret_next : minstret_raw;

  // ...

      ibex_counter #(
        .CounterWidth(MHPMCounterWidth),
        .ProvideValUpd(Cnt == 10)
      ) mcounters_variable_i (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .counter_inc_i(mhpmcounter_incr[Cnt] & ~mcountinhibit[Cnt]),
        .counterh_we_i(mhpmcounterh_we[Cnt]),
        .counter_we_i(mhpmcounter_we[Cnt]),
        .counter_val_i(csr_wdata_int),
        .counter_val_o(mhpmcounter_raw),
        .counter_val_upd_o(mhpmcounter_next)
      );
```

## Documentation

### doc/03_reference/performance_counters.rst

```text
Performance Counters
====================

Ibex implements performance counters according to the RISC-V Privileged Specification, version 1.11 (see Hardware Performance Monitor, Section 3.1.11) and supports the **Zihpm** (Hardware Performance Counters) extension.
The performance counters are placed inside the Control and Status Registers (CSRs) and can be accessed with the ``CSRRW(I)`` and ``CSRRS/C(I)`` instructions.

Ibex implements the machine-mode clock cycle counter ``mcycle(h)``, the retired instruction counter ``minstret(h)``, as well as the 29 event counters ``mhpmcounter3(h)`` - ``mhpmcounter31(h)`` and the corresponding event selector CSRs ``mhpmevent3`` - ``mhpmevent31``, and the ``mcountinhibit`` CSR to individually enable/disable the counters.

Additionally, Ibex implements the Zicntr and Zihpm extensions which provide User-mode (U-mode) aliases for these performance counters: ``cycle(h)``, ``instret(h)``, and ``hpmcounter3(h)`` - ``hpmcounter31(h)``. These aliases provide read-only access to the exact same underlying hardware counters configured in M-mode.

``mcycle(h)`` and ``minstret(h)`` are always available and 64 bit wide.
The ``mhpmcounter`` performance counters are optional (unavailable by default) and parametrizable in width.

...

Controlling the counters from software
--------------------------------------

By default, all available counters are enabled after reset.
They can be individually enabled/disabled by overwriting the corresponding bit in the ``mcountinhibit`` CSR at address ``0x320`` as described in the RISC-V Privileged Specification, version 1.11 (see Machine Counter-Inhibit CSR, Section 3.1.13).
In particular, to enable/disable ``mcycle(h)``, bit 0 must be written. For ``minstret(h)``, it is bit 2. For event counter ``mhpmcounterX(h)``, it is bit X.

The lower 32 bits of all counters can be accessed through the base register, whereas the upper 32 bits are accessed through the ``h``-register.
Reads to all these registers are non-destructive.
```

### src/zicsr.adoc

```text
Some CSRs, such as the instructions-retired counter, `instret`, may be
modified as side effects of instruction execution. In these cases, if a
CSR access instruction reads a CSR, it reads the value prior to the
execution of the instruction. If a CSR access instruction writes such a
CSR, the explicit write is done instead of the update from the side effect.
In particular, a value
written to `instret` by one instruction will be the value read by the
following instruction.
```
