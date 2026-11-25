# Implement `ibex_prefetch_buffer`

Implement the complete `ibex_prefetch_buffer` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_prefetch_buffer` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module ibex_prefetch_buffer #(
  parameter bit ResetAll        = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        req_i,

  input  logic        branch_i,
  input  logic [31:0] addr_i,

  input  logic        ready_i,
  output logic        valid_o,
  output logic [31:0] rdata_o,
  output logic [31:0] addr_o,
  output logic        err_o,
  output logic        err_plus2_o,

  input  logic        cheriot_force_uc_i,

  // goes to instruction memory / instruction cache
  output logic        instr_req_o,
  input  logic        instr_gnt_i,
  output logic [31:0] instr_addr_o,
  input  logic [31:0] instr_rdata_i,
  input  logic        instr_err_i,
  input  logic        instr_rvalid_i,

  // Prefetch Buffer Status
  output logic        busy_o
);
```

## Parent instantiation

### rtl/ibex_if_stage.sv

```verilog
    ibex_prefetch_buffer #(
      .ResetAll        (ResetAll)
    ) prefetch_buffer_i (
        .clk_i               ( clk_i                      ),
        .rst_ni              ( rst_ni                     ),

        .req_i               ( req_i                      ),

        .branch_i            ( prefetch_branch            ),
        .addr_i              ( prefetch_addr              ),

        .ready_i             ( fetch_ready                ),
        .valid_o             ( fetch_valid_raw            ),
        .rdata_o             ( fetch_rdata                ),
        .addr_o              ( fetch_addr                 ),
        .err_o               ( fetch_err                  ),
        .err_plus2_o         ( fetch_err_plus2            ),

        .cheriot_force_uc_i  ( cheriot_force_uc           ),

        .instr_req_o         ( instr_req_o                ),
        .instr_addr_o        ( instr_addr_o               ),
        .instr_gnt_i         ( instr_gnt_i                ),
        .instr_rvalid_i      ( instr_rvalid_i             ),
        .instr_rdata_i       ( instr_rdata_i[31:0]        ),
        .instr_err_i         ( instr_err                  ),

        .busy_o              ( prefetch_busy              )
    );
```

## Dependency declarations

### rtl/ibex_fetch_fifo.sv

```verilog
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

## Related source code

### rtl/ibex_fetch_fifo.sv

```systemverilog
  localparam int unsigned DEPTH = NUM_REQS+1;

  // index 0 is used for output
  logic [DEPTH-1:0] [31:0]  rdata_d,   rdata_q;
  logic [DEPTH-1:0]         err_d,     err_q;
  logic [DEPTH-1:0]         valid_d,   valid_q;

  // ...

  // Update the address on branches and every time an instruction is driven
  assign instr_addr_en = clear_i | (out_ready_i & out_valid_o);

  // Increment the address by two every time a compressed instruction is popped
  assign addr_incr_two = instr_addr_q[1] ? unaligned_is_compressed :
                                           aligned_is_compressed;

  assign instr_addr_next = (instr_addr_q[31:1] +
                            // Increment address by 4 or 2
                            {29'd0,~addr_incr_two,addr_incr_two});

  assign instr_addr_d = clear_i ? in_addr_i[31:1] :
                                  instr_addr_next;

  // ...

  // Output PC of current instruction
  assign out_addr_o      = {instr_addr_q, 1'b0};

  // ...

  // Indicate the fill level of fifo-entries. This is used to determine when a new request can be
  // made on the bus. The prefetch buffer only needs to know about the upper entries which overlap
  // with NUM_REQS.
  assign busy_o = valid_q[DEPTH-1:DEPTH-NUM_REQS];
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

Instruction-Side Memory Interface
---------------------------------

The following table describes the signals that are used to fetch instructions.
This interface is a simplified version of the interface used on the data interface as described in :ref:`load-store-unit`.
The main difference is that the instruction interface does not allow for write transactions and thus needs less signals.

.. tabularcolumns:: |p{4cm}|l|p{9cm}|

+-----------------------------+-----------+-----------------------------------------------+
| Signal                      | Direction | Description                                   |
+=============================+===========+===============================================+
| ``instr_req_o``             | output    | Request valid, must stay high until           |
|                             |           | ``instr_gnt_i`` is high for one cycle         |
+-----------------------------+-----------+-----------------------------------------------+
| ``instr_addr_o[31:0]``      | output    | Address, word aligned                         |
+-----------------------------+-----------+-----------------------------------------------+
| ``instr_gnt_i``             | input     | The other side accepted the request.          |
|                             |           | ``instr_req_o`` may be deasserted in the next |
|                             |           | cycle.                                        |
+-----------------------------+-----------+-----------------------------------------------+
| ``instr_rvalid_i``          | input     | ``instr_rdata_i`` holds valid data when       |
|                             |           | ``instr_rvalid_i`` is high. This signal will  |
|                             |           | be high for exactly one cycle per request.    |
+-----------------------------+-----------+-----------------------------------------------+
| ``instr_rdata_i[31:0]``     | input     | Data read from memory                         |
+-----------------------------+-----------+-----------------------------------------------+
| ``instr_rdata_intg_i[6:0]`` | input     | Data integrity bits from memory               |
+-----------------------------+-----------+-----------------------------------------------+
| ``instr_err_i``             | input     | Memory access error                           |
+-----------------------------+-----------+-----------------------------------------------+

...

Protocol
--------

The protocol used to communicate with the instruction cache or the instruction memory is very similar to the protocol used by the LSU on the data interface of Ibex.
See the description of the LSU in :ref:`LSU Protocol<lsu-protocol>` for details about this protocol.
```

### doc/03_reference/load_store_unit.rst

```text
Protocol
--------

The protocol that is used by the LSU to communicate with a memory works as follows:

1. The LSU provides a valid address in ``data_addr_o`` and sets ``data_req_o`` high. In the case of a store, the LSU also sets ``data_we_o`` high and configures ``data_be_o`` and ``data_wdata_o``. The memory then answers with a ``data_gnt_i`` set high as soon as it is ready to serve the request. This may happen in the same cycle as the request was sent or any number of cycles later.

2. After receiving a grant, the address may be changed in the next cycle by the LSU. In addition, the ``data_wdata_o``, ``data_we_o`` and ``data_be_o`` signals may be changed as it is assumed that the memory has already processed and stored that information.

3. The memory answers with a ``data_rvalid_i`` set high for exactly one cycle to signal the response from the bus or the memory using ``data_err_i`` and ``data_rdata_i`` (during the very same cycle). This may happen one or more cycles after the grant has been received. If ``data_err_i`` is low, the request could successfully be handled at the destination and in the case of a load, ``data_rdata_i`` contains valid data. If ``data_err_i`` is high, an error occurred in the memory system and the core will raise an exception.

4. When multiple granted requests are outstanding, it is assumed that the memory requests will be kept in-order and one ``data_rvalid_i`` will be signalled for each of them, in the order they were issued.
```
