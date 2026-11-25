# Implement `copro_alu`

Implement the complete `copro_alu` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module copro_alu` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      XLEN: unsigned'(CVA6ConfigXlen),
// ...
      SuperscalarEn: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
    // Can take 2 or 3 in single issue. 4 or 6 in dual issue.
    cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 4 : 2);
    // cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 6 : 3);
```

## Package and imports

### core/cvxif_example/include/cvxif_instr_pkg.sv

```systemverilog
package cvxif_instr_pkg;

  typedef enum logic [3:0] {
    ILLEGAL = 4'b0000,
    NOP = 4'b0001,
    ADD = 4'b0010,
    DOUBLE_RS1 = 4'b0011,
    DOUBLE_RS2 = 4'b0100,
    ADD_MULTI = 4'b0101,
    MADD_RS3_R4 = 4'b0110,
    MSUB_RS3_R4 = 4'b0111,
    NMADD_RS3_R4 = 4'b1000,
    NMSUB_RS3_R4 = 4'b1001,
    ADD_RS3_R = 4'b1111
  } opcode_t;
// ...
      '{
          // Custom Nop
          instr:
          32'b00000_00_00000_00000_0_00_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b0, register_read : {1'b0, 1'b0, 1'b0}},
          opcode : NOP
      // ...
```

## Module declaration

```systemverilog
module copro_alu
  import cvxif_instr_pkg::*;
#(
    parameter int unsigned NrRgprPorts = 2,
    parameter int unsigned XLEN = 32,
    parameter type hartid_t = logic,
    parameter type id_t = logic,
    parameter type registers_t = logic

) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  registers_t            registers_i,
    input  opcode_t               opcode_i,
    input  hartid_t               hartid_i,
    input  id_t                   id_i,
    input  logic       [     4:0] rd_i,
    output logic       [XLEN-1:0] result_o,
    output hartid_t               hartid_o,
    output id_t                   id_o,
    output logic       [     4:0] rd_o,
    output logic                  valid_o,
    output logic                  we_o
);
```

## Parent instantiation

### corev_apu/src/ariane.sv

```systemverilog
  if (CVA6Cfg.CvxifEn) begin: gen_cvxif
    if (CVA6Cfg.CoproType == config_pkg::COPRO_EXAMPLE) begin: gen_COPRO_EXAMPLE
      cvxif_example_coprocessor #(
        .NrRgprPorts (CVA6Cfg.NrRgprPorts),
        .XLEN (CVA6Cfg.XLEN),
        // ...
```

### core/cvxif_example/cvxif_example_coprocessor.sv

```systemverilog
module cvxif_example_coprocessor
  import cvxif_instr_pkg::*;
#(
    // CVXIF Types
    parameter  int unsigned NrRgprPorts         = 2,
    parameter  int unsigned XLEN                = 32,
    parameter  type         readregflags_t      = logic,
    parameter  type         writeregflags_t     = logic,
    parameter  type         id_t                = logic,
    parameter  type         hartid_t            = logic,
    parameter  type         x_compressed_req_t  = logic,
    parameter  type         x_compressed_resp_t = logic,
    parameter  type         x_issue_req_t       = logic,
    parameter  type         x_issue_resp_t      = logic,
    parameter  type         x_register_t        = logic,
    parameter  type         x_commit_t          = logic,
    parameter  type         x_result_t          = logic,
    parameter  type         cvxif_req_t         = logic,
    parameter  type         cvxif_resp_t        = logic,
    localparam type         registers_t         = logic [NrRgprPorts-1:0][XLEN-1:0]
) (
// ...
  logic alu_valid;
  // Result interface
  copro_alu #(
      .NrRgprPorts(NrRgprPorts),
      .XLEN(XLEN),
      .hartid_t(hartid_t),
      .id_t(id_t),
      .registers_t(registers_t)
  ) i_copro_alu (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .registers_i(registers),
      .opcode_i   (opcode),
      .hartid_i   (issue_hartid),
      .id_i       (issue_id),
      .rd_i       (issue_rd),
      .hartid_o   (hartid),
      .id_o       (id),
      .result_o   (result),
      .valid_o    (alu_valid),
      .rd_o       (rd),
      .we_o       (we)
  );

  always_comb begin
    cvxif_resp_o.result_valid  = alu_valid;  //TODO Should wait for ready from CPU
    cvxif_resp_o.result.hartid = hartid;
    cvxif_resp_o.result.id     = id;
    cvxif_resp_o.result.data   = result;
    cvxif_resp_o.result.rd     = rd;
    cvxif_resp_o.result.we     = we;
  end
```

## Related source code

### core/cvxif_example/instr_decoder.sv

```systemverilog
    opcode_o                   = opcode_t'(0);  // == ILLEGAL see cvxif_instr_pkg.sv
    hartid_o                   = '0;
    id_o                       = '0;
    rd_o                       = '0;
// ...
        opcode_o = CoproInstr[i].opcode;
        id_o     = issue_req_i.id;
        hartid_o = issue_req_i.hartid;
        rd_o     = issue_req_i.instr[11:7];
        for (int unsigned j = 0; j < NrRgprPorts; j++) begin
          registers_o[j] = issue_resp_o.register_read[j] ? register_i.rs[j] : '0;
        end
```

### verif/env/uvme/cvxif_vseq/uvme_cvxif_vseq.sv

```systemverilog
task uvme_cvxif_vseq_c::do_result_resp();

   if (req_item.commit_valid && !req_item.commit_req.commit_kill) begin
      resp_item.result_valid  = 1;
      resp_item.result.id     = req_item.commit_req.id;
      resp_item.result.hartid = req_item.commit_req.hartid;
      resp_item.result.we     = resp_item.issue_resp.writeback;
      `uvm_info(info_tag, $sformatf("Request ID : %1d", req_item.commit_req.id), UVM_HIGH);
      do_instr_result();
   end
   else begin
      resp_item.result_valid = 0;
      resp_item.result.id = 0;
      resp_item.result.hartid = 0;
      resp_item.result.data = 0;
      resp_item.result.rd = 0;
      resp_item.result.we = 0;
   end
// ...
      "CUS_ADD": begin
         if (req_item.register.rs_valid inside {2'b11, 3'b111}) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[1];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_DOUBLE_RS1": begin
         if (req_item.register.rs_valid inside {2'b11, 3'b111}) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[0];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_DOUBLE_RS2": begin
         if (req_item.register.rs_valid inside {2'b11, 3'b111}) begin
            resp_item.result.data = req_item.register.rs[1] + req_item.register.rs[1];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_ADD_MULTI": begin
         if (req_item.register.rs_valid inside {2'b11, 3'b111}) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[1];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_ADD_RS3_MADD": begin
         if (req_item.register.rs_valid == 3'b111) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[1] + req_item.register.rs[2];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
         else if (req_item.register.rs_valid == 2'b11) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[1];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_ADD_RS3_MSUB": begin
         if (req_item.register.rs_valid == 3'b111) begin
            resp_item.result.data = req_item.register.rs[0] - req_item.register.rs[1] - req_item.register.rs[2];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
         else if (req_item.register.rs_valid == 2'b11) begin
            resp_item.result.data = req_item.register.rs[0] - req_item.register.rs[1];
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_ADD_RS3_NMADD": begin
         if (req_item.register.rs_valid == 3'b111) begin
            resp_item.result.data = ~(req_item.register.rs[0] + req_item.register.rs[1] + req_item.register.rs[2]);
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
         else if (req_item.register.rs_valid == 2'b11) begin
            resp_item.result.data = ~(req_item.register.rs[0] + req_item.register.rs[1]);
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_ADD_RS3_NMSUB": begin
         if (req_item.register.rs_valid == 3'b111) begin
            resp_item.result.data = ~(req_item.register.rs[0] - req_item.register.rs[1] - req_item.register.rs[2]);
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
         else if (req_item.register.rs_valid == 2'b11) begin
            resp_item.result.data = ~(req_item.register.rs[0] - req_item.register.rs[1]);
            resp_item.result.rd   = req_item.issue_req.instr[11:7];
         end
      end
      "CUS_ADD_RS3_RTYPE": begin
         if (req_item.register.rs_valid == 3'b111) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[1] + req_item.register.rs[2];
            resp_item.result.rd   = 5'hA;
         end
         else if (req_item.register.rs_valid == 2'b11) begin
            resp_item.result.data = req_item.register.rs[0] + req_item.register.rs[1];
            resp_item.result.rd   = 5'hA;
         end
      end
      "ILLEGAL": begin
            resp_item.result.data = '0;
            resp_item.result.rd   = '0;
      end
```

## Documentation

### docs/source/x_ext.rst

```rst
  | ``result_valid``          | logic           | input           | Result request valid. Indicates that the |coprocessor| has a valid result (write data or exception) for an offloaded         |
  |                           |                 |                 | instruction.                                                                                                                 |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``result_ready``          | logic           | output          | Result request ready. The result signaled via ``result`` is accepted by the |processor| when                                 |
  |                           |                 |                 | ``result_valid`` and  ``result_ready`` are both 1.                                                                           |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``result``                | x_result_t      | input           | Result packet.                                                                                                               |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

The |coprocessor| shall provide results to the |processor| via the result interface. A |coprocessor| is allowed to provide results to the |processor| in an out of order fashion. A |coprocessor| is only
allowed to provide a result for an instruction once the |processor| has indicated (via the commit interface) that this instruction is allowed to be committed. Each accepted offloaded (committed and not killed) instruction shall
have exactly one result transaction (even if no data needs to be written back to the |processor|'s register file). No result transaction shall be performed for instructions which have not been accepted for offload or
for instructions that have been killed.
...
A |coprocessor| is allowed (and expected) to have combinatorial paths from its eXtension interface input signals to its eXtension interface output signals. In order to prevent combinatorial loops the following combinatorial paths are not allowed in a |coprocessor|:

* paths from ``register_valid``, ``rs``, ``rs_valid`` to ``result_valid``, ``result``.
...
.. note::

   The above implies that a |coprocessor| has a pipeline stage separating the register file operands from its result generating circuit (similar to
   the separation between decode stage and execute stage found in many :term:`CPUs<CPU>`).
```
