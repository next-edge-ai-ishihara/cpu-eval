# Implement `ibex_fetch_fifo`

Implement the complete `ibex_fetch_fifo` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_fetch_fifo` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
/**
 * Fetch Fifo for 32 bit memory interface
 *
 * input port: send address and data to the FIFO
 * clear_i clears the FIFO for the following cycle, including any new request
 */

`include "prim_assert.sv"

module ibex_fetch_fifo #(
  parameter int unsigned NUM_REQS = 2,
  parameter bit          ResetAll = 1'b0
) (
  input  logic                clk_i,
  input  logic                rst_ni,

  // control signals
  input  logic                clear_i,   // clears the contents of the FIFO
  output logic [NUM_REQS-1:0] busy_o,

  // input port
  input  logic                in_valid_i,
  input  logic [31:0]         in_addr_i,
  input  logic [31:0]         in_rdata_i,
  input  logic                in_err_i,

  // force unaligned compressed based on CHERIoT bounds check
  input  logic                cheriot_force_uc_i,

  // output port
  output logic                out_valid_o,
  input  logic                out_ready_i,
  output logic [31:0]         out_addr_o,
  output logic [31:0]         out_rdata_o,
  output logic                out_err_o,
  output logic                out_err_plus2_o
);
```

## Parent instantiation

### rtl/ibex_prefetch_buffer.sv

```verilog
  localparam int unsigned NUM_REQS  = 2;

  // ...

  // A branch will invalidate any previously fetched instructions.
  // Note that the FENCE.I instruction relies on this flushing behaviour on branch. If it is
  // altered the FENCE.I implementation may require changes.
  assign fifo_clear = branch_i;

  // Reversed version of rdata_outstanding_q which can be overlaid with fifo fill state
  for (genvar i = 0; i < NUM_REQS; i++) begin : gen_rd_rev
    assign rdata_outstanding_rev[i] = rdata_outstanding_q[NUM_REQS-1-i];
  end

  // The fifo is ready to accept a new request if it is not full - including space reserved for
  // requests already outstanding.
  // Overlay the fifo fill state with the outstanding requests to see if there is space.
  assign fifo_ready = ~&(fifo_busy | rdata_outstanding_rev);

  ibex_fetch_fifo #(
    .NUM_REQS (NUM_REQS),
    .ResetAll (ResetAll)
  ) fifo_i (
      .clk_i                 ( clk_i              ),
      .rst_ni                ( rst_ni             ),

      .clear_i               ( fifo_clear         ),
      .busy_o                ( fifo_busy          ),

      .in_valid_i            ( fifo_valid         ),
      .in_addr_i             ( fifo_addr          ),
      .in_rdata_i            ( instr_rdata_i      ),
      .in_err_i              ( instr_err_i        ),
      .cheriot_force_uc_i    ( cheriot_force_uc_i ),

      .out_valid_o           ( valid_o            ),
      .out_ready_i           ( ready_i            ),
      .out_rdata_o           ( rdata_o            ),
      .out_addr_o            ( addr_o             ),
      .out_err_o             ( err_o              ),
      .out_err_plus2_o       ( err_plus2_o        )
  );

  // ...

  // Two addresses are tracked in the prefetch buffer:
  // 1. stored_addr_q - This is the address issued on the bus. It stays stable until
  //                    the request is granted.
  // 2. fetch_addr_q  - This is our next address to fetch from. It is updated on branches to
  //                    capture the new address, and then for each new request issued.
  // A third address is tracked in the fetch FIFO itself:
  // 3. instr_addr_q  - This is the address at the head of the FIFO, effectively our oldest fetched
  //                    address. This address is updated on branches, and does its own increment
  //                    each time the FIFO is popped.

  // ...

      // A request becomes outstanding once granted, and is cleared once the rvalid is received.
      // Outstanding requests shift down the queue towards entry 0.

  // ...

  assign fifo_addr = addr_i;
```

## Documentation

### doc/03_reference/instruction_fetch.rst

```text
Instruction Fetch
=================
:file:`rtl/ibex_if_stage.sv.`

.. figure:: images/if_stage.svg
   :name: if_stage
   :align: center

   Instruction Fetch (IF) stage

The Instruction Fetch (IF) stage of the core is able to supply one instruction to the Instruction-Decode (ID) stage per cycle if the instruction cache or the instruction memory is able to serve one instruction per cycle.

Instructions are fetched into a prefetch buffer (:file:`rtl/ibex_prefetch_buffer.sv`) for optimal performance and timing closure reasons.
This buffer simply fetches instructions linearly until it is full.
The instructions themselves are stored along with the Program Counter (PC) they came from in the fetch FIFO (:file:`rtl/ibex_fetch_fifo.sv`).
The fetch FIFO has a feedthrough path so when empty a new instruction entering the FIFO is immediately made available on the FIFO output.
A localparam ``DEPTH`` gives a configurable depth which is set to 3 by default.

The top-level of the instruction fetch controls the prefetch buffer (in particular flushing it on branches/jumps/exception and beginning prefetching from the appropriate new PC) and supplies new instructions to the ID/EX stage along with their PC.
Compressed instructions are expanded by the IF stage so the decoder can always deal with uncompressed instructions (the ID stage still receives the compressed instruction for placing into ``mtval`` on an illegal instruction exception).

If Ibex has been configured with an instruction cache (parameter ICache == 1), then the prefetch buffer is replaced by the icache module (:ref:`icache`).
The interfaces of the icache module are the same as the prefetch buffer with two additions.
Firstly, a signal to enable the cache which is driven from a custom CSR.
Secondly a signal to the flush the cache which is set every time a ``fence.i`` instruction is executed.

...

Misaligned Accesses
-------------------

Externally, the IF interface performs word-aligned instruction fetches only.
Misaligned instruction fetches are handled by performing two separate word-aligned instruction fetches.
Internally, the core can deal with both word- and half-word-aligned instruction addresses to support compressed instructions.
The LSB of the instruction address is ignored internally.
```

### doc/03_reference/icache.rst

```text
Fetched instructions are returned to the core using ports ``ready_i``, ``valid_o``, ``rdata_o``, ``addr_o``, ``err_o`` and ``err_plus2_o``.
This interface uses a form of ready/valid handshaking.
A transaction is signalled by ready and valid being high.
If valid goes high, it will remain high and the other output signals will remain stable until the transaction goes through or is cancelled by ``branch_i`` being asserted.
The only exception is after an error is passed to the core. Once that has happened, there is no constraint on the values of ``valid_o``, ``rdata_o``, ``addr_o``, ``err_o`` and ``err_plus2_o`` until the next time ``branch_i`` is asserted.
There is no constraint on the behaviour of ``ready_i``.

The 32-bit wide ``rdata_o`` signal contains instruction data fetched from ``addr_o``.
An instruction is either 16 or 32 bits wide (called *compressed* or *uncompressed*, respectively).
The width of an instruction can be calculated from its bottom two bits: an instruction is uncompressed if they equal ``2'b11`` and compressed otherwise.
If there is a compressed instruction in the lower 16 bits, the upper 16 bits are unconstrained (and may change even after valid has been asserted).
The ``err_o`` signal will be high if the instruction fetch failed (either with ``instr_pmp_err_i`` or ``instr_err_i``); in this case ``rdata_o`` is not specified.

...

Because a single instruction can span two 32bit memory addresses, an extra signal (``err_plus2_o``) indicates when an error is caused by the second half of an unaligned uncompressed instruction.
This signal is only valid when ``valid_o`` and ``err_o`` are set, and will only be set for uncompressed instructions.
The core uses this signal to record the correct address in the ``mtval`` CSR upon an error.
```

## Additional requirement

In the cycle after `clear_i` is asserted, `out_addr_o` equals the `in_addr_i` value present with `clear_i`, even while `out_valid_o` is low.
