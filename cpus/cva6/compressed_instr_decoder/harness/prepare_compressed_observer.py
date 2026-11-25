#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys

repository = Path(sys.argv[1])
target = repository / 'corev_apu/tb/ariane_testharness.sv'
pinned = subprocess.check_output(['git', '-C', str(repository), 'show',
    '6348e9e684678f83b40d0520028513d06b36e7b2:corev_apu/tb/ariane_testharness.sv'])
if sys.argv[2] == 'restore':
    target.write_bytes(pinned)
else:
    if target.read_bytes() != pinned:
        raise SystemExit('test harness differs from the pinned source')
    anchor = b'  `AXI_ASSIGN_FROM_REQ(slave[0], axi_ariane_req)'
    observer = b'''  if (CVA6Cfg.CvxifEn) begin : gen_cpu_eval_compressed_observer
    always @(posedge clk_i) begin
      if (ndmreset_n && i_ariane.cvxif_req.compressed_valid &&
          i_ariane.cvxif_resp.compressed_ready)
        $display("CPU_EVAL_COMPRESSED req=%04x accept=%0d instr=%08x",
          i_ariane.cvxif_req.compressed_req.instr,
          i_ariane.cvxif_resp.compressed_resp.accept,
          i_ariane.cvxif_resp.compressed_resp.instr);
    end
  end

'''
    if pinned.count(anchor) != 1:
        raise SystemExit('test harness insertion point is ambiguous')
    target.write_bytes(pinned.replace(anchor, observer + anchor))
