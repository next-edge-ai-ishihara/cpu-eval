# Implement `lfsr`

Implement the complete `lfsr` module for the uses shown below. Preserve the module name, parameters, and ports shown below.

Return only the complete `module lfsr` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module lfsr #(
  parameter int unsigned          LfsrWidth     = 64,   // [4,64]
  parameter int unsigned          OutWidth      = 8,    // [1,LfsrWidth]
  parameter logic [LfsrWidth-1:0] RstVal        = '1,   // [1,2^LfsrWidth-1]
  // 0: disabled, the present cipher uses 31, but just a few layers (1-3) are enough
  // to break linear shifting patterns
  parameter int unsigned          CipherLayers  = 0,
  parameter bit                   CipherReg     = 1'b1  // additional output reg after cipher
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic                 en_i,
  output logic [OutWidth-1:0]  out_o
);
```

## Parent instantiation

### core/cache_subsystem/cva6_icache.sv

```systemverilog
  // generate random cacheline index
  lfsr #(
      .LfsrWidth(8),
      .OutWidth (CVA6Cfg.ICACHE_SET_ASSOC_WIDTH)
  ) i_lfsr (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .en_i  (update_lfsr),
      .out_o (rnd_way)
  );
```

### core/cache_subsystem/wt_dcache_missunit.sv

```systemverilog
  // generate random cacheline index
  lfsr #(
      .LfsrWidth(8),
      .OutWidth (CVA6Cfg.DCACHE_SET_ASSOC_WIDTH)
  ) i_lfsr_inv (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .en_i  (update_lfsr),
      .out_o (rnd_way)
  );
```

### core/cva6_mmu/cva6_shared_tlb.sv

```systemverilog
  lfsr #(
      .LfsrWidth(8),
      .OutWidth ($clog2(SHARED_TLB_WAYS))
  ) i_lfsr (
      .clk_i (clk_i),
      .rst_ni(rst_ni),
      .en_i  (update_lfsr),
      .out_o (rnd_way)
  );
```

## Additional requirement

With `CipherLayers` = 0, `out_o` equals the low `OutWidth` bits of an `LfsrWidth`-bit state that takes the value `RstVal` asynchronously while `rst_ni` is 0 and otherwise, at each rising edge of `clk_i` with `en_i` = 1, is replaced by `(state >> 1) ^ ({LfsrWidth{state[0]}} & mask)`, where `mask` is `8'hFA` for `LfsrWidth` = 8.
