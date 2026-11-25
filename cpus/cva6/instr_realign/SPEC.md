# Implement `instr_realign`

Implement the complete `instr_realign` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module instr_realign` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
// ...
      RVC: bit'(1),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.FETCH_WIDTH = unsigned'(CVA6Cfg.SuperscalarEn ? 64 : 32);
    cfg.FETCH_ALIGN_BITS = $clog2(cfg.FETCH_WIDTH / 8);
    cfg.INSTR_PER_FETCH = cfg.FETCH_WIDTH / (CVA6Cfg.RVC ? 16 : 32);
    cfg.LOG2_INSTR_PER_FETCH = cfg.INSTR_PER_FETCH > 1 ? $clog2(cfg.INSTR_PER_FETCH) : 1;
```

## Module declaration

```systemverilog
module instr_realign
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // 32-bit block is valid - CACHE
    input logic valid_i,
    // Instruction is unaligned - FRONTEND
    output logic serving_unaligned_o,
    // 32-bit block address - CACHE
    input logic [CVA6Cfg.VLEN-1:0] address_i,
    // 32-bit block - CACHE
    input logic [CVA6Cfg.FETCH_WIDTH-1:0] data_i,
    // instruction is valid - FRONTEND
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0] valid_o,
    // Instruction address - FRONTEND
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0][CVA6Cfg.VLEN-1:0] addr_o,
    // Instruction - instr_scan&instr_queue
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0][31:0] instr_o
);
```

## Parent instantiation

### core/frontend/frontend.sv

```systemverilog
  logic [$clog2(CVA6Cfg.INSTR_PER_FETCH)-1:0] shamt;
  // address will always be 16 bit aligned, make this explicit here
  if (CVA6Cfg.RVC) begin : gen_shamt
    assign shamt = icache_dreq_i.vaddr[$clog2(CVA6Cfg.INSTR_PER_FETCH):1];
  end else begin
    assign shamt = 1'b0;
  end
// ...
  // Instruction FIFO
  logic [           CVA6Cfg.VLEN-1:0] predict_address;
  cf_t  [CVA6Cfg.INSTR_PER_FETCH-1:0] cf_type;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] taken_rvi_cf;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] taken_rvc_cf;

  logic                               serving_unaligned;
  // Re-align instructions
  instr_realign #(
      .CVA6Cfg(CVA6Cfg)
  ) i_instr_realign (
      .clk_i              (clk_i),
      .rst_ni             (rst_ni),
      .flush_i            (icache_dreq_o.kill_s2),
      .valid_i            (icache_valid_q),
      .serving_unaligned_o(serving_unaligned),
      .address_i          (icache_vaddr_q),
      .data_i             (icache_data_q),
      .valid_o            (instruction_valid),
      .addr_o             (addr),
      .instr_o            (instr)
  );
  // --------------------
  // Branch Prediction
  // --------------------
  // select the right branch prediction result
  // in case we are serving an unaligned instruction in instr[0] we need to take
  // the prediction we saved from the previous fetch
  if (CVA6Cfg.RVC) begin : gen_btb_prediction_shifted
    assign bht_prediction_shifted[0] = (serving_unaligned) ? bht_q : bht_prediction[addr[0][$clog2(
        CVA6Cfg.INSTR_PER_FETCH
    ):1]];
    assign btb_prediction_shifted[0] = (serving_unaligned) ? btb_q : btb_prediction[addr[0][$clog2(
        CVA6Cfg.INSTR_PER_FETCH
    ):1]];

    // for all other predictions we can use the generated address to index
    // into the branch prediction data structures
    for (genvar i = 1; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_prediction_address
      assign bht_prediction_shifted[i] = bht_prediction[addr[i][$clog2(CVA6Cfg.INSTR_PER_FETCH):1]];
      assign btb_prediction_shifted[i] = btb_prediction[addr[i][$clog2(CVA6Cfg.INSTR_PER_FETCH):1]];
    end
  end else begin
    assign bht_prediction_shifted[0] = (serving_unaligned) ? bht_q : bht_prediction[addr[0][1]];
    assign btb_prediction_shifted[0] = (serving_unaligned) ? btb_q : btb_prediction[addr[0][1]];
  end
// ...
  logic [CVA6Cfg.FETCH_WIDTH-1:0] icache_data;
  // re-align the cache line
  assign icache_data = icache_dreq_i.data >> {shamt, 4'b0};
// ...
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
// ...
    end else begin
// ...
      icache_valid_q <= icache_dreq_i.valid;
      if (icache_dreq_i.valid) begin
        icache_data_q  <= icache_data;
        icache_vaddr_q <= icache_dreq_i.vaddr;
// ...
      end
    end
  end
```

## Documentation

### src/intro.adoc

```text
=== Base Instruction-Length Encoding

The base RISC-V ISA has fixed-length 32-bit instructions that must be
naturally aligned on 32-bit boundaries. However, the standard RISC-V
encoding scheme is designed to support ISA extensions with
variable-length instructions, where each instruction can be any number
of 16-bit instruction _parcels_ in length and parcels are naturally
aligned on 16-bit boundaries. The standard compressed ISA extension
described in <<compressed>> reduces code size by
providing compressed 16-bit instructions and relaxes the alignment
constraints to allow all instructions (16 bit and 32 bit) to be aligned
on any 16-bit boundary to improve code density.

We use the term IALIGN (measured in bits) to refer to the
instruction-address alignment constraint the implementation enforces.
IALIGN is 32 bits in the base ISA, but some ISA extensions, including
the compressed ISA extension, relax IALIGN to 16 bits. IALIGN may not
take on any value other than 16 or 32.
(((ILEN)))

We use the term ILEN (measured in bits) to refer to the maximum
instruction length supported by an implementation, and which is always a
multiple of IALIGN. For implementations supporting only a base
instruction set, ILEN is 32 bits. Implementations supporting longer
instructions have larger values of ILEN.

<<instlengthcode>> illustrates the standard
RISC-V instruction-length encoding convention. All the 32-bit
instructions in the base ISA have their lowest two bits set to `11`. The
optional compressed 16-bit instruction-set extensions have their lowest
two bits equal to `00`, `01`, or `10`.
```

### docs/design/design-manual/source/cva6_frontend.adoc

```text
[[instr_realign-submodule]]
Instr_realign submodule
+++++++++++++++++++++++

The {ifetch-len}-bit aligned block coming from the CACHE module enters the instr_realign submodule.
This submodule extracts the instructions from the {ifetch-len}-bit blocks.
Based on the fetch address and the fetched data, the instr_realign module extracts the valid instructions to be sent to the queue.
It is possible to fetch up to {instr-per-fetch} instructions per cycle when C extension is used.
A not-compressed instruction can be misaligned on the block size, interleaved with two cache blocks.
In that case, two cache accesses are needed to get the whole instruction.
The instr_realign submodule provides up to {instr-per-fetch} instructions per cycle when compressed extension is enabled, else one instruction per cycle.
Incomplete instruction is stored in instr_realign submodule until its second half is fetched.

Below is a table that explains how the instr_realign works:

* _C : compressed instruction_
* _I : not compressed instruction_
* _UI: Incomplete instruction stored in the instr_realign_
...
ifeval::[{Superscalar} == false]

|==========================================================
|*Address[2:1]*	|*Incomplete Access* |*32-16*	|*16-0*
.5+^.^|0

.3+^.^|0
2.+^.^|I
|C
|C
|UI
|C

.2+^.^|1
|UI
|UI
|C
|UI

.2+^.^|1
.2+^.^|__
|* |C
|* |UI

|==========================================================

endif::[]

The Instr_realign can be flushed when the frontend requests the cache to kill the incoming instruction, in this case the incomplete instruction is deleted.
```

### verif/docs/VerifPlans/FRONTEND/VP_IP007.yml

```text
        description: In case of mispredict, flush, replay or branch predict, the instr_realign
          is re-initialized, the internal register storing the instruction alignment
          state is reset.
```
