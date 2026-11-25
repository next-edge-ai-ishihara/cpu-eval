# Implement `prim_buf`

Implement the complete `prim_buf` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module prim_buf` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module prim_buf #(
  parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);
```

## Parent instantiation

### rtl/ibex_core.sv

```verilog
    prim_buf #(
      .Width(NumBusyBits)
    ) u_fetch_enable_buf (
      .in_i ({$bits(ibex_mubi_t){ctrl_busy, if_busy, lsu_busy}}),
      .out_o(busy_bits_buf)
    );
```

### rtl/ibex_if_stage.sv

```verilog
    prim_buf #(.Width(MemDataWidth)) u_prim_buf_instr_rdata (
      .in_i (instr_rdata_i),
      .out_o(instr_rdata_buf)
    );

// ...

    prim_buf #(.Width(32)) u_prev_instr_addr_incr_buf (
      .in_i (prev_instr_addr_incr),
      .out_o(prev_instr_addr_incr_buf)
    );
```

### rtl/ibex_load_store_unit.sv

```verilog
    prim_buf #(.Width(MemDataWidth)) u_prim_buf_instr_rdata (
      .in_i (data_rdata_i),
      .out_o(data_rdata_buf)
    );
```

### rtl/ibex_top.sv

```verilog
  prim_buf #(.Width($bits(ibex_mubi_t))) u_fetch_enable_buf (
    .in_i (fetch_enable_i),
    .out_o(fetch_enable_buf)
  );

  prim_buf #(.Width($bits(ibex_mubi_t))) u_mcounteren_writable_buf (
    .in_i (mcounteren_writable_i),
    .out_o(mcounteren_writable_buf)
  );

// ...

    prim_buf #(.Width(7)) u_prim_buf_data_wdata_intg (
      .in_i (data_wdata_core[MemDataWidth-1:32]),
      .out_o(trvk_wdata_intg)
    );

// ...

    prim_buf #(.Width(NumBufferBits)) u_signals_prim_buf (
      .in_i(buf_in),
      .out_o(buf_out)
    );

// ...

      prim_buf #(.Width(TagSizeECC)) u_tag_prim_buf (
        .in_i(ic_tag_rdata[k]),
        .out_o(ic_tag_rdata_local[k])
      );
      prim_buf #(.Width(LineSizeECC)) u_data_prim_buf (
        .in_i(ic_data_rdata[k]),
        .out_o(ic_data_rdata_local[k])
      );

// ...

    prim_buf u_prim_buf_alert_minor (
      .in_i (lockstep_alert_minor_local),
      .out_o(lockstep_alert_minor)
    );

    prim_buf u_prim_buf_alert_major_internal (
      .in_i (lockstep_alert_major_internal_local),
      .out_o(lockstep_alert_major_internal)
    );

    prim_buf u_prim_buf_alert_major_bus (
      .in_i (lockstep_alert_major_bus_local),
      .out_o(lockstep_alert_major_bus)
    );
```

## Documentation

### doc/02_user/integration.rst

```text
Ibex uses a number of primitive modules (that are held outside the :file:`rtl/` which contains the Ibex RTL).
Full implementations of these primitives are provided in the Ibex repository but implementers may wish to provide their own implementations.
Some of the primitives are only used for specific Ibex configurations so can be ignored/removed if you're not using one of those configurations.

The mandatory primitives (used by all configurations) are:
 * ``prim_buf`` - A buffer, used to ensure security critical logic isn't optimized out in synthesis (by applying suitable constraints to prim_buf).
   In configurations where ``SecureIbex == 0`` it must exist but can be implemented as a straight passthrough.
```
