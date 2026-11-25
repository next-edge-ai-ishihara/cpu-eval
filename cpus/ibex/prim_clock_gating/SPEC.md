# Implement `prim_clock_gating`

Implement the complete `prim_clock_gating` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module prim_clock_gating` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module prim_clock_gating #(
  parameter bit NoFpgaGate = 1'b0, // this parameter has no function in generic
  parameter bit FpgaBufGlobal = 1'b1 // this parameter has no function in generic
) (
  input        clk_i,
  input        en_i,
  input        test_en_i,
  output logic clk_o
);
```

## Parent instantiation

### rtl/ibex_top.sv

```verilog
  prim_clock_gating core_clock_gate_i (
    .clk_i    (clk_i),
    .en_i     (clock_en),
    .test_en_i(test_en_i),
    .clk_o    (clk)
  );
```

## Documentation

### doc/03_reference/register_file.rst

```text
In addition, a technology-specific clock gating cell must be provided to keep the clock inactive when the latches are not written.
This cell must be wrapped in a module called ``prim_clock_gating``.
For more information regarding the clock gating cell, checkout :ref:`getting-started`.

.. note:: The latch-based register file requires the gated clock to be enabled in the cycle after the write enable ``we_a_i`` signal was set high.
   This can be achieved by latching ``we_a_i`` in the clock gating cell during the low phase of ``clk_i``.
```

### doc/02_user/integration.rst

```text
+------------------------------+-------------------------+-----+----------------------------------------+
| Signal(s)                    | Width                   | Dir | Description                            |
+==============================+=========================+=====+========================================+
...
| ``test_en_i``                | 1                       | in  | Test input, enables clock and allows   |
|                              |                         |     | test control of reset.                 |
+------------------------------+-------------------------+-----+----------------------------------------+
```
