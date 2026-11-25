#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

repository = Path(sys.argv[1])
target = repository / "corev_apu/tb/ariane_testharness.sv"
pinned = subprocess.check_output(["git", "-C", str(repository), "show",
    "6348e9e684678f83b40d0520028513d06b36e7b2:corev_apu/tb/ariane_testharness.sv"])
if sys.argv[2] == "restore":
    target.write_bytes(pinned)
else:
    if target.read_bytes() != pinned:
        raise SystemExit("test harness differs from the pinned source")
    anchor = b"  `AXI_ASSIGN_FROM_REQ(slave[0], axi_ariane_req)"
    observer = b'''  if (CVA6Cfg.CvxifEn) begin : gen_cpu_eval_cvxif_observer
    logic request_active = 1'b0;
    logic [$bits(i_ariane.cvxif_req.issue_req.hartid)-1:0] request_hart;
    logic [$bits(i_ariane.cvxif_req.issue_req.id)-1:0] request_id;
    initial $display("CPU_EVAL_CVXIF FORMAT version=3");
    always @(posedge clk_i) begin
      if (!ndmreset_n) begin
        request_active <= 1'b0;
        $display("CPU_EVAL_CVXIF RESET");
      end else begin
        if (i_ariane.i_cva6.issue_stage_i.i_scoreboard.issue_instr_valid_o[0])
          $display("CPU_EVAL_CVXIF PRESENT hart=%0d id=%0d",
            i_ariane.hart_id_i,
            i_ariane.i_cva6.issue_stage_i.i_scoreboard.issue_instr_o[0].trans_id);
        if (request_active && (!i_ariane.cvxif_req.issue_valid ||
            request_hart != i_ariane.cvxif_req.issue_req.hartid ||
            request_id != i_ariane.cvxif_req.issue_req.id))
          $display("CPU_EVAL_CVXIF CANCEL hart=%0d id=%0d", request_hart, request_id);
        if (i_ariane.cvxif_req.issue_valid && (!request_active ||
            request_hart != i_ariane.cvxif_req.issue_req.hartid ||
            request_id != i_ariane.cvxif_req.issue_req.id))
          $display("CPU_EVAL_CVXIF START hart=%0d id=%0d",
            i_ariane.cvxif_req.issue_req.hartid, i_ariane.cvxif_req.issue_req.id);
        if (i_ariane.cvxif_req.issue_valid && i_ariane.cvxif_resp.issue_ready)
          $display("CPU_EVAL_CVXIF ISSUE hart=%0d id=%0d accept=%0d",
            i_ariane.cvxif_req.issue_req.hartid, i_ariane.cvxif_req.issue_req.id,
            i_ariane.cvxif_resp.issue_resp.accept);
        if (i_ariane.cvxif_req.commit_valid)
          $display("CPU_EVAL_CVXIF COMMIT hart=%0d id=%0d kill=%0d",
            i_ariane.cvxif_req.commit.hartid, i_ariane.cvxif_req.commit.id,
            i_ariane.cvxif_req.commit.commit_kill);
        if (i_ariane.i_cva6.issue_stage_i.i_scoreboard.issue_ack_i[0] ||
            i_ariane.i_cva6.issue_stage_i.i_scoreboard.flush_unissued_instr_i ||
            i_ariane.i_cva6.issue_stage_i.i_scoreboard.flush_i ||
            !i_ariane.i_cva6.issue_stage_i.i_scoreboard.issue_instr_valid_o[0])
          $display("CPU_EVAL_CVXIF END_PRESENT");
        request_active <= i_ariane.cvxif_req.issue_valid && !i_ariane.cvxif_resp.issue_ready;
        if (i_ariane.cvxif_req.issue_valid) begin
          request_hart <= i_ariane.cvxif_req.issue_req.hartid;
          request_id <= i_ariane.cvxif_req.issue_req.id;
        end
      end
    end
  end

'''
    if pinned.count(anchor) != 1:
        raise SystemExit("test harness insertion point is ambiguous")
    target.write_bytes(pinned.replace(anchor, observer + anchor))
