# Implement `rvoclkhdr`

Implement the complete `rvoclkhdr` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvoclkhdr` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### tools/riscv-dv/Makefile

```make
VEER_TARGET     = default
VEER_CONF       = -set build_axi4 \
                  -set reset_vec=0x80000000 \
                  -set fpga_optimize=0 \
                  $(VEER_EXTRA_CONF)
```

### configs/veer.config

```text
     -fpga_optimize =   { 0, 1 }
          if 1, minimize clock-gating to facilitate FPGA builds
```

## Module declaration

```verilog
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

## Parent instantiation

### design/el2_dma_ctrl.sv

```verilog
   rvoclkhdr dma_buffer_c1cgc ( .en(dma_buffer_c1_clken), .l1clk(dma_buffer_c1_clk), .* );
   rvoclkhdr dma_free_cgc (.en(dma_free_clken), .l1clk(dma_free_clk), .*);
```

### design/dec/el2_dec_tlu_ctl.sv

```verilog
   rvoclkhdr csrwr_r_cgc   ( .en(dec_csr_wen_r_mod | clk_override), .l1clk(csr_wr_clk), .* );
```

## Dependency declarations

### design/lib/beh_lib.sv

```verilog
module `TEC_RV_ICG
  (
   input logic SE, EN, CK,
   output Q
   );

   logic  en_ff;
   logic  enable;

   assign      enable = EN | SE;

   always @(CK, enable) begin
      if(!CK)
        en_ff = enable;
   end
   assign Q = CK & en_ff;

endmodule
```
