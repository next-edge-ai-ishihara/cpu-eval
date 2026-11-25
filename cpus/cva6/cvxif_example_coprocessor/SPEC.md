# Implement `cvxif_example_coprocessor`

Implement the complete `cvxif_example_coprocessor` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cvxif_example_coprocessor` definition in a single SystemVerilog code block, with no text outside the block.

## Package and imports

### `core/cvxif_example/include/cvxif_instr_pkg.sv`

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


  typedef struct packed {
    logic accept;
    logic writeback;  // TODO depends on dualwrite
    logic [2:0] register_read;  // TODO Nr read ports
  } issue_resp_t;

  typedef struct packed {
    logic        accept;
    logic [31:0] instr;
  } compressed_resp_t;

  typedef struct packed {
    logic [31:0] instr;
    logic [31:0] mask;
    issue_resp_t resp;
    opcode_t     opcode;
  } copro_issue_resp_t;


  typedef struct packed {
    logic [15:0]      instr;
    logic [15:0]      mask;
    compressed_resp_t resp;
  } copro_compressed_resp_t;

  // 4 Possible RISCV instructions for Coprocessor
  parameter int unsigned NbInstr = 10;
  parameter copro_issue_resp_t CoproInstr[NbInstr] = '{
      '{
          // Custom Nop
          instr:
          32'b00000_00_00000_00000_0_00_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b0, register_read : {1'b0, 1'b0, 1'b0}},
          opcode : NOP
      },
      '{
          // Custom Add : cus_add rd, rs1, rs2
          instr:
          32'b00000_00_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode : ADD
      },
      '{
          // Custom Add rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_01_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b0, 1'b1}},
          opcode : DOUBLE_RS1
      },
      '{
          // Custom Add rs2 : cus_add rd, rs2, rs2
          instr:
          32'b00000_10_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b0}},
          opcode : DOUBLE_RS2
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_11_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode : ADD_MULTI
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00001_00_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : ADD_RS3_R
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1000011,  // MADD opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : MADD_RS3_R4
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1000111,  // MSUB opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : MSUB_RS3_R4
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1001011,  // NMSUB opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : NMSUB_RS3_R4
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1001111,  // NMADD opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : NMADD_RS3_R4
      }
  };

  parameter int unsigned NbCompInstr = 2;
  parameter copro_compressed_resp_t CoproCompInstr[NbCompInstr] = '{
      // C_NOP
      '{
          instr : 16'b111_0_00000_00000_00,
          mask : 16'b111_1_00000_00000_11,
          resp : '{accept : 1'b1, instr : 32'b00000_00_00000_00000_0_00_00000_1111011}
      },
      '{
          instr : 16'b111_1_00000_00000_00,
          mask : 16'b111_1_00000_00000_11,
          resp : '{accept : 1'b1, instr : 32'b00000_00_00000_00000_0_01_01010_1111011}
      }
  };

```

## Module declaration

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
    input  logic        clk_i,        // Clock
    input  logic        rst_ni,       // Asynchronous reset active low
    input  cvxif_req_t  cvxif_req_i,
    output cvxif_resp_t cvxif_resp_o
);

```

## Parent instantiation

### `corev_apu/src/ariane.sv`

```systemverilog
      cvxif_example_coprocessor #(
        .NrRgprPorts (CVA6Cfg.NrRgprPorts),
        .XLEN (CVA6Cfg.XLEN),
        .readregflags_t (readregflags_t),
        .writeregflags_t (writeregflags_t),
        .id_t (id_t),
        .hartid_t (hartid_t),
        .x_compressed_req_t (x_compressed_req_t),
        .x_compressed_resp_t (x_compressed_resp_t),
        .x_issue_req_t (x_issue_req_t),
        .x_issue_resp_t (x_issue_resp_t),
        .x_register_t (x_register_t),
        .x_commit_t (x_commit_t),
        .x_result_t (x_result_t),
        .cvxif_req_t (cvxif_req_t),
        .cvxif_resp_t (cvxif_resp_t)
      ) i_cvxif_coprocessor (
        .clk_i                ( clk_i                          ),
        .rst_ni               ( rst_ni                         ),
        .cvxif_req_i          ( cvxif_req                      ),
        .cvxif_resp_o         ( cvxif_resp                     )
      );

```

## Dependency declarations

### `core/include/cvxif_types.svh`

```systemverilog
`define READREGFLAGS_T(Cfg) logic [Cfg.X_NUM_RS+Cfg.X_DUALREAD-1:0]
`define WRITEREGFLAGS_T(Cfg) logic [Cfg.X_DUALWRITE:0]
`define ID_T(Cfg) logic [Cfg.X_ID_WIDTH-1:0]
`define HARTID_T(Cfg) logic [Cfg.X_HARTID_WIDTH-1:0]

`define X_COMPRESSED_REQ_T(Cfg, hartid_t) struct packed { \
    logic [15:0] instr; /*Offloaded compressed instruction*/ \
    hartid_t     hartid;  /*Identification of the hart offloading the instruction*/ \
}
`define X_COMPRESSED_RESP_T(Cfg) struct packed { \
    logic [31:0] instr; /*Uncompressed instruction*/ \
    logic accept; /*Is the offloaded compressed instruction (id) accepted by the coprocessor?*/ \
}

`define X_ISSUE_REQ_T(Cfg, hartid_t, id_t) struct packed { \
    logic [31:0] instr; /*Offloaded instruction*/ \
    hartid_t hartid; /*Identification of the hart offloading the instruction*/ \
    id_t id; /*Identification of the offloaded instruction*/ \
}
`define X_ISSUE_RESP_T(Cfg, writeregflags_t, readregflags_t) struct packed { \
    logic accept; /*Is the offloaded instruction (id) accepted by the coprocessor?*/ \
    writeregflags_t writeback; /*Will the coprocessor perform a writeback in the core to rd?*/ \
    readregflags_t register_read; /*Will the coprocessor perform require specific registers to be read?*/ \
}

`define X_REGISTER_T(Cfg, hartid_t, id_t, readregflags_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic [Cfg.X_NUM_RS-1:0][Cfg.X_RFR_WIDTH-1:0] rs;  /*Register file source operands for the offloaded instruction.*/ \
    readregflags_t rs_valid; /*Validity of the register file source operand(s).*/ \
}

`define X_COMMIT_T(Cfg, hartid_t, id_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic commit_kill;  /*Shall an offloaded instruction be killed?*/ \
}

`define X_RESULT_T(Cfg, hartid_t, id_t, writeregflags_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic [Cfg.X_RFW_WIDTH-1:0] data;  /*Register file write data value(s)*/ \
    logic [4:0] rd;  /*Register file destination address(es)*/ \
    writeregflags_t we;  /*Register file write enable(s)*/ \
}

`define CVXIF_REQ_T(Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t) struct packed { \
    logic              compressed_valid; \
    x_compressed_req_t compressed_req; \
    logic              issue_valid; \
    x_issue_req_t      issue_req; \
    logic              register_valid; \
    x_register_t       register; \
    logic              commit_valid; \
    x_commit_t         commit; \
    logic              result_ready; \
}

`define CVXIF_RESP_T(Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t) struct packed { \
    logic               compressed_ready; \
    x_compressed_resp_t compressed_resp; \
    logic               issue_ready; \
    x_issue_resp_t      issue_resp; \
    logic               register_ready; \
    logic               result_valid; \
    x_result_t          result; \
}

```

### `core/cvxif_example/compressed_instr_decoder.sv`

```systemverilog
module compressed_instr_decoder #(
    parameter type                    copro_compressed_resp_t          = logic,
    parameter int                     NbInstr                          = 1,
    parameter copro_compressed_resp_t CoproInstr             [NbInstr] = {0},
    parameter type                    x_compressed_req_t               = logic,
    parameter type                    x_compressed_resp_t              = logic
) (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               compressed_valid_i,
    input  x_compressed_req_t  compressed_req_i,
    output logic               compressed_ready_o,
    output x_compressed_resp_t compressed_resp_o
);

  logic [NbInstr-1:0] sel;

  for (genvar i = 0; i < NbInstr; i++) begin : gen_predecoder_selector
    assign sel[i] = ((CoproInstr[i].mask & compressed_req_i.instr) == CoproInstr[i].instr);
  end

  always_comb begin
    compressed_ready_o       = '1;
    compressed_resp_o.accept = '0;
    compressed_resp_o.instr  = '0;
    for (int unsigned i = 0; i < NbInstr; i++) begin
      if (sel[i] && compressed_valid_i) begin
        compressed_resp_o.accept       = CoproInstr[i].resp.accept;
        compressed_resp_o.instr        = CoproInstr[i].resp.instr;
        // Remap rs1 and rs2
        compressed_resp_o.instr[19:15] = compressed_req_i.instr[11:7];
        compressed_resp_o.instr[24:20] = compressed_req_i.instr[6:2];
      end
    end
  end

```

### `core/cvxif_example/instr_decoder.sv`

```systemverilog
module instr_decoder #(
    parameter type               copro_issue_resp_t          = logic,
    parameter type               opcode_t                    = logic,
    parameter int                NbInstr                     = 1,
    parameter copro_issue_resp_t CoproInstr        [NbInstr] = {0},
    parameter int unsigned       NrRgprPorts                 = 2,
    parameter type               hartid_t                    = logic,
    parameter type               id_t                        = logic,
    parameter type               x_issue_req_t               = logic,
    parameter type               x_issue_resp_t              = logic,
    parameter type               x_register_t                = logic,
    parameter type               registers_t                 = logic
) (
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                issue_valid_i,
    input  x_issue_req_t        issue_req_i,
    output logic                issue_ready_o,
    output x_issue_resp_t       issue_resp_o,
    input  logic                register_valid_i,
    input  x_register_t         register_i,
    output registers_t          registers_o,
    output opcode_t             opcode_o,
    output hartid_t             hartid_o,
    output id_t                 id_o,
    output logic          [4:0] rd_o
);

  logic [NbInstr-1:0] sel;
  logic rs1_ready;
  logic rs2_ready;
  logic rs3_ready;

  for (genvar i = 0; i < NbInstr; i++) begin : gen_predecoder_selector
    assign sel[i] = ((CoproInstr[i].mask & issue_req_i.instr) == CoproInstr[i].instr);
  end

  always_comb begin
    rs1_ready                  = '0;
    rs2_ready                  = '0;
    rs3_ready                  = '0;
    issue_ready_o              = '0;
    issue_resp_o.accept        = '0;
    issue_resp_o.writeback     = '0;
    issue_resp_o.register_read = '0;
    registers_o                = '0;
    opcode_o                   = opcode_t'(0);  // == ILLEGAL see cvxif_instr_pkg.sv
    hartid_o                   = '0;
    id_o                       = '0;
    rd_o                       = '0;
    for (int unsigned i = 0; i < NbInstr; i++) begin
      if (sel[i] && issue_valid_i) begin
        issue_resp_o.accept = CoproInstr[i].resp.accept;
        issue_resp_o.writeback = CoproInstr[i].resp.writeback;
        issue_resp_o.register_read = CoproInstr[i].resp.register_read; // Warning :  potential 3 bits vector into 2 bits one
        if (issue_resp_o.accept) begin
          rs1_ready = (~CoproInstr[i].resp.register_read[0] || register_i.rs_valid[0]);
          rs2_ready = (~CoproInstr[i].resp.register_read[1] || register_i.rs_valid[1]);
          rs3_ready = NrRgprPorts == 3 ? (~CoproInstr[i].resp.register_read[2] || register_i.rs_valid[2]) : 1'b1;
          issue_ready_o = rs1_ready && rs2_ready && rs3_ready;
        end
        opcode_o = CoproInstr[i].opcode;
        id_o     = issue_req_i.id;
        hartid_o = issue_req_i.hartid;
        rd_o     = issue_req_i.instr[11:7];
        for (int unsigned j = 0; j < NrRgprPorts; j++) begin
          registers_o[j] = issue_resp_o.register_read[j] ? register_i.rs[j] : '0;
        end
      end
    end
    // Coprocessor could not decode offloaded instruction -> instruction is not accepted
    if (issue_valid_i && ~(|sel)) begin
      issue_ready_o = 1'b1;
    end
  end

```

### `core/cvxif_example/copro_alu.sv`

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

  logic [XLEN-1:0] result_n, result_q;
  hartid_t hartid_n, hartid_q;
  id_t id_n, id_q;
  logic valid_n, valid_q;
  logic [4:0] rd_n, rd_q;
  logic we_n, we_q;

  assign result_o = result_q;
  assign hartid_o = hartid_q;
  assign id_o     = id_q;
  assign valid_o  = valid_q;
  assign rd_o     = rd_q;
  assign we_o     = we_q;

  always_comb begin
    case (opcode_i)
      cvxif_instr_pkg::NOP: begin
        result_n = '0;
        hartid_n = hartid_i;
        id_n     = id_i;
        valid_n  = 1'b1;
        rd_n     = '0;
        we_n     = '0;
      end
      cvxif_instr_pkg::ADD: begin
        result_n = registers_i[1] + registers_i[0];
        hartid_n = hartid_i;
        id_n     = id_i;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::DOUBLE_RS1: begin
        result_n = registers_i[0] + registers_i[0];
        hartid_n = hartid_i;
        id_n     = id_i;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::DOUBLE_RS2: begin
        result_n = registers_i[1] + registers_i[1];
        hartid_n = hartid_i;
        id_n     = id_i;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::ADD_MULTI: begin
        result_n = registers_i[1] + registers_i[0];
        hartid_n = hartid_i;
        id_n     = id_i;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::MADD_RS3_R4: begin
        result_n = NrRgprPorts == 3 ? (registers_i[0] + registers_i[1] + registers_i[2]) : (registers_i[0] + registers_i[1]);
        hartid_n = hartid_i;
        id_n = id_i;
        valid_n = 1'b1;
        rd_n = rd_i;
        we_n = 1'b1;
      end
      cvxif_instr_pkg::MSUB_RS3_R4: begin
        result_n = NrRgprPorts == 3 ? (registers_i[0] - registers_i[1] - registers_i[2]) : (registers_i[0] - registers_i[1]);
        hartid_n = hartid_i;
        id_n = id_i;
        valid_n = 1'b1;
        rd_n = rd_i;
        we_n = 1'b1;
      end
      cvxif_instr_pkg::NMADD_RS3_R4: begin
        result_n = NrRgprPorts == 3 ? ~(registers_i[0] + registers_i[1] + registers_i[2]) : ~(registers_i[0] + registers_i[1]);
        hartid_n = hartid_i;
        id_n = id_i;
        valid_n = 1'b1;
        rd_n = rd_i;
        we_n = 1'b1;
      end
      cvxif_instr_pkg::NMSUB_RS3_R4: begin
        result_n = NrRgprPorts == 3 ? ~(registers_i[0] - registers_i[1] - registers_i[2]) : ~(registers_i[0] - registers_i[1]);
        hartid_n = hartid_i;
        id_n = id_i;
        valid_n = 1'b1;
        rd_n = rd_i;
        we_n = 1'b1;
      end
      cvxif_instr_pkg::ADD_RS3_R: begin
        result_n = NrRgprPorts == 3 ? registers_i[2] + registers_i[1] + registers_i[0] : registers_i[1] + registers_i[0];
        hartid_n = hartid_i;
        id_n = id_i;
        valid_n = 1'b1;
        rd_n = 5'b01010;
        we_n = 1'b1;
      end
      default: begin
        result_n = '0;
        hartid_n = '0;
        id_n     = '0;
        valid_n  = '0;
        rd_n     = '0;
        we_n     = '0;
      end
    endcase
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      result_q <= '0;
      hartid_q <= '0;
      id_q     <= '0;
      valid_q  <= '0;
      rd_q     <= '0;
      we_q     <= '0;
    end else begin
      result_q <= result_n;
      hartid_q <= hartid_n;
      id_q     <= id_n;
      valid_q  <= valid_n;
      rd_q     <= rd_n;
      we_q     <= we_n;
    end
  end

```
