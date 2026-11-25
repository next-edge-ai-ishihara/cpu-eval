# Implement `cva6_fifo_v3`

Implement the complete `cva6_fifo_v3` module for the uses shown below. Preserve the module name, parameters, and ports.

Return only the complete `module cva6_fifo_v3` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/ariane_pkg.sv

```systemverilog
  localparam int unsigned FETCH_FIFO_DEPTH = 4;
  localparam int unsigned FETCH_ADDR_FIFO_DEPTH = 2;
```

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
```

## Module declaration

```systemverilog
module cva6_fifo_v3 #(
    parameter bit FALL_THROUGH = 1'b0,  // fifo is in fall-through mode
    parameter bit FPGA_ALTERA = 1'b0,  // FPGA Altera optimizations enabled
    parameter int unsigned DATA_WIDTH = 32,  // default data width if the fifo is of type logic
    parameter int unsigned DEPTH = 8,  // depth can be arbitrary from 0 to 2**32
    parameter type dtype = logic [DATA_WIDTH-1:0],
    parameter bit FPGA_EN = 1'b0,
    // DO NOT OVERWRITE THIS PARAMETER
    parameter int unsigned ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input  logic                  clk_i,       // Clock
    input  logic                  rst_ni,      // Asynchronous reset active low
    input  logic                  flush_i,     // flush the queue
    input  logic                  testmode_i,  // test_mode to bypass clock gating
    // status flags
    output logic                  full_o,      // queue is full
    output logic                  empty_o,     // queue is empty
    output logic [ADDR_DEPTH-1:0] usage_o,     // fill pointer
    // as long as the queue is not full we can push new data
    input  dtype                  data_i,      // data to push into the queue
    input  logic                  push_i,      // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    output dtype                  data_o,      // output data
    input  logic                  pop_i        // pop head from queue
);
```

## Parent instantiation

### core/frontend/instr_queue.sv

```systemverilog
  typedef struct packed {
    logic [31:0]                     instr;      // instruction word
    ariane_pkg::cf_t                 cf;         // branch was taken
    ariane_pkg::frontend_exception_t ex;         // exception happened
    logic [CVA6Cfg.VLEN-1:0]         ex_vaddr;   // lower VLEN bits of tval for exception
    logic [CVA6Cfg.GPLEN-1:0]        ex_gpaddr;  // lower GPLEN bits of tval2 for exception
    logic [31:0]                     ex_tinst;   // tinst of exception
    logic                            ex_gva;
  } instr_data_t;
  // ...
    cva6_fifo_v3 #(
        .FPGA_ALTERA(CVA6Cfg.FpgaAlteraEn),
        .DEPTH(ariane_pkg::FETCH_FIFO_DEPTH),
        .dtype(instr_data_t),
        .FPGA_EN(CVA6Cfg.FpgaEn)
    ) i_fifo_instr_data (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   (flush_i),
        .testmode_i(1'b0),
        .full_o    (instr_queue_full[i]),
        .empty_o   (instr_queue_empty[i]),
        .usage_o   (),
        .data_i    (instr_data_in[i]),
        .push_i    (push_instr_fifo[i]),
        .data_o    (instr_data_out[i]),
        .pop_i     (pop_instr[i])
    );
  // ...
  cva6_fifo_v3 #(
      .FPGA_ALTERA(CVA6Cfg.FpgaAlteraEn),
      .DEPTH      (ariane_pkg::FETCH_ADDR_FIFO_DEPTH),
      .DATA_WIDTH (CVA6Cfg.VLEN),
      .FPGA_EN    (CVA6Cfg.FpgaEn)
  ) i_fifo_address (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .flush_i   (flush_i),
      .testmode_i(1'b0),
      .full_o    (full_address),
      .empty_o   (),
      .usage_o   (),
      .data_i    (predict_address_i),
      .push_i    (push_address & ~full_address),
      .data_o    (address_out),
      .pop_i     (pop_address)
  );
```

## Documentation

### docs/design/design-manual/source/cva6_frontend.adoc

```text
The instr_queue receives multiple instructions from instr_realign submodule to create a valid stream to be executed.
Frontend pushes instructions and all related information into the FIFO for storage, including details needed in case of a misprediction or exception: the instructions themselves, instruction control flow type, exception, exception address, and predicted address.
DECODE pops them when decode stage is ready and indicates to the FRONTEND the instruction has been consumed.


The instruction queue contains two FIFOs: one for instructions and one for addresses, which stores addresses in case of a prediction.
The instruction FIFO can hold up to 4×{instr-per-fetch} instructions, while the address FIFO can hold up to 2 addresses.
If the instruction FIFO is full, a replay request is sent to inform the fetch mechanism to replay the fetch.
...
The instruction queue can be flushed by the flush signal coming from the CONTROLLER.
```

## Additional requirement

While `empty_o` is low, `data_o` presents the oldest stored entry, and a rising `clk_i` edge with `flush_i` asserted empties the queue, discarding any push or pop in that cycle.
