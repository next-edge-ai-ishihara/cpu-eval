# Third-party material

CPU-Eval problem statements, tests and patches contain material from the upstream projects below.
That material keeps the licenses and conditions given by its rights holders. Material written by
CPU-Eval uses the [Apache License 2.0](LICENSE).

## Finding the source of an excerpt

Each problem directory `cpus/<cpu>/<problem>/` contains the problem statement `SPEC.md` and
`SPEC_SOURCES.json`:

- `sources[i]` is one excerpt: the upstream `repo`, `commit` and `path`, and `lines`, the first and
  last line of the excerpt (inclusive). An excerpt of a CPU-Eval file has `repo` "CPU-Eval", no
  `commit`, and its `path` in this repository.
- Each entry of `segments` whose `kind` is `verbatim_source` has `source` = i and `prompt_bytes` =
  [start, end), the bytes of `SPEC.md` that hold excerpt i.

Source numbers on this page, such as S0148, identify the upstream file of each quoted excerpt.

## Upstream projects

<a id="github-com-chipsalliance-chisel"></a>
### github.com/chipsalliance/chisel

Project: https://github.com/chipsalliance/chisel.

Fixed revisions: `066fb4705472e07bde340810ee45eaf8c1ad9438`, `29df513e348cc809876893f650af8180f0190496`, `4da4f252c3d7c834e13bb8e91a69cfe772996452`.

`SPEC_SOURCES.json` of `cpus/boom/arbiter`, `cpus/boom/basic_dispatcher`, `cpus/boom/boom_core`, `cpus/boom/boom_duplicated_data_array`, `cpus/boom/boom_iomshr`, `cpus/boom/boom_mshr`, `cpus/boom/boom_mshr_file`, `cpus/boom/boom_non_blocking_d_cache_module`, `cpus/boom/boom_probe_unit`, `cpus/boom/boom_writeback_unit`, `cpus/boom/branch_killable_queue`, `cpus/boom/f_div_sqrt_unit`, `cpus/boom/max_period_fibonacci_lfsr`, `cpus/boom/ptw`, `cpus/boom/queue`, `cpus/boom/register_file_synthesizable`, `cpus/boom/register_read` records this repository as `github.com/chipsalliance/chisel3`; the recorded revisions and files are those of github.com/chipsalliance/chisel.

License of the quoted files: Apache-2.0.

Original license texts: [Chisel-Apache-2.0.txt](LICENSES/license-texts/Chisel-Apache-2.0.txt).

<a id="github-com-chipsalliance-cores-veer-el2"></a>
### github.com/chipsalliance/cores-veer-el2

Project: https://github.com/chipsalliance/cores-veer-el2.

Fixed revisions: `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

Licenses of the quoted files:

- Header granting Apache-2.0, or no license header (the repository `LICENSE`): Apache-2.0. Files: `configs/veer.config`, `design/dbg/el2_dbg.sv`, `design/dec/csrdecode_m`, `design/dec/decode`, `design/dec/el2_dec.sv`, `design/dec/el2_dec_decode_ctl.sv`, `design/dec/el2_dec_gpr_ctl.sv`, `design/dec/el2_dec_ib_ctl.sv`, `design/dec/el2_dec_pmp_ctl.sv`, `design/dec/el2_dec_tlu_ctl.sv`, `design/dec/el2_dec_trigger.sv`, `design/dmi/dmi_mux.v`, `design/dmi/dmi_wrapper.v`, `design/el2_dma_ctrl.sv`, `design/el2_mem.sv`, `design/el2_pic_ctrl.sv`, `design/el2_pmp.sv`, `design/el2_veer.sv`, `design/el2_veer_wrapper.sv`, `design/exu/el2_exu.sv`, `design/exu/el2_exu_alu_ctl.sv`, `design/exu/el2_exu_div_ctl.sv`, `design/exu/el2_exu_mul_ctl.sv`, `design/ifu/el2_ifu.sv`, `design/ifu/el2_ifu_aln_ctl.sv`, `design/ifu/el2_ifu_bp_ctl.sv`, `design/ifu/el2_ifu_compress_ctl.sv`, `design/ifu/el2_ifu_ic_mem.sv`, `design/ifu/el2_ifu_iccm_mem.sv`, `design/ifu/el2_ifu_ifc_ctl.sv`, `design/ifu/el2_ifu_mem_ctl.sv`, `design/include/el2_dec_csr_equ_m.svh`, `design/include/el2_def.sv`, `design/lib/ahb_to_axi4.sv`, `design/lib/beh_lib.sv`, `design/lib/el2_lib.sv`, `design/lib/el2_mem_if.sv`, `design/lib/mem_lib.sv`, `design/lsu/el2_lsu.sv`, `design/lsu/el2_lsu_addrcheck.sv`, `design/lsu/el2_lsu_bus_buffer.sv`, `design/lsu/el2_lsu_bus_intf.sv`, `design/lsu/el2_lsu_clkdomain.sv`, `design/lsu/el2_lsu_dccm_ctl.sv`, `design/lsu/el2_lsu_dccm_mem.sv`, `design/lsu/el2_lsu_ecc.sv`, `design/lsu/el2_lsu_lsc_ctl.sv`, `design/lsu/el2_lsu_stbuf.sv`, `design/lsu/el2_lsu_trigger.sv`, `docs/source/adaptations.md`, `docs/source/build-args.md`, `docs/source/cache.md`, `docs/source/clocks.md`, `docs/source/complex-ports.md`, `docs/source/core-control.md`, `docs/source/dual-core-lock-step.md`, `docs/source/error-protection.md`, `docs/source/interrupts.md`, `docs/source/memory-map.md`, `docs/source/overview.md`, `docs/source/performance.md`, `docs/source/physical-memory-protection.md`, `docs/source/power.md`, `docs/source/tests.md`, `docs/source/timers.md`, `testbench/ahb_sif.sv`, `testbench/icache_macros.svh`, `testbench/tb_top.sv`, `testbench/tests/icache_ecc/icache_ecc.c`, `tools/riscv-dv/Makefile`.
- VeeR documentation that copies descriptions from RISC-V External Debug Support 0.13.2: Apache-2.0 for the VeeR text, and CC BY 4.0 for the copied descriptions (see [Creative Commons Attribution material](#creative-commons-attribution-material)). Files: `docs/source/debugging.md`.

Copyright and author attribution:

- Copyright (c) 2023 Antmicro <www.antmicro.com>
- Copyright (c) 2024 Antmicro <www.antmicro.com>
- Copyright 2018 Western Digital Corporation or it's affiliates.
- Copyright 2019 Western Digital Corporation or its affiliates.
- Copyright 2020 Western Digital Corporation or it's affiliates.
- Copyright 2020 Western Digital Corporation or its affiliates.
- Copyright 2022 Microsoft Corporation
- Copyright 2023 Antmicro <www.antmicro.com>
- Copyright 2023 Antmicro, Ltd. <www.antmicro.com>
- Copyright 2024 Antmicro <www.antmicro.com>
- Copyright 2026 Google LLC
- Copyright Western Digital, 2018
- Copyright lowRISC contributors.
- Copyright © 2022 CHIPS Alliance.
- Owner: Anusha Narayanamoorthy

Original license texts: [RISC-V-Debug-Spec-CC-BY-4.0.txt](LICENSES/license-texts/RISC-V-Debug-Spec-CC-BY-4.0.txt), [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Test and patch directories: `cpus/veer_el2/_shared/patches`, `cpus/veer_el2/dbg/test`, `cpus/veer_el2/dec_gpr_ctl/test`, `cpus/veer_el2/dec_tlu_ctl/test`, `cpus/veer_el2/dec_trigger/test`, `cpus/veer_el2/dma_ctrl/test`, `cpus/veer_el2/ifu/test`, `cpus/veer_el2/ifu_ic_mem/harness`, `cpus/veer_el2/ifu_iccm_mem/test`, `cpus/veer_el2/ifu_mem_ctl/harness`, `cpus/veer_el2/lsu_addrcheck/test`, `cpus/veer_el2/lsu_bus_buffer/test`, `cpus/veer_el2/pic_ctrl/test`, `cpus/veer_el2/rvdff_fpga/test`, `cpus/veer_el2/rvdffppe/test`, `cpus/veer_el2/rvdffs/test`, `cpus/veer_el2/rvdffs_fpga/test`, `cpus/veer_el2/rvdffsc/test`, `cpus/veer_el2/rvdffsc_fpga/test`, `cpus/veer_el2/rvecc_decode/test`, `cpus/veer_el2/rvecc_decode_64/test`, `cpus/veer_el2/veer/harness`, `cpus/veer_el2/veer_wrapper/test`.

<a id="github-com-chipsalliance-riscv-dv"></a>
### github.com/chipsalliance/riscv-dv

Project: https://github.com/chipsalliance/riscv-dv.

Fixed revisions: `da33551ab102c7530d7dadb803abf4c245ba08e0`.

License: Apache-2.0.

Copyright and author attribution:

- Copyright 2020 Google LLC
- Copyright 2020 PerfectVIPs Inc.
- Copyright Google LLC

Original license texts: [LICENSE](LICENSE), [riscv-dv-da33551ab102-LICENSE.txt](LICENSES/license-texts/riscv-dv-da33551ab102-LICENSE.txt).

Test and patch directories: `cpus/cva6/compressed_decoder/harness`, `cpus/veer_el2/_shared/patches`, `cpus/veer_el2/dec_pmp_ctl/test`, `cpus/veer_el2/exu_alu_ctl/test`, `cpus/veer_el2/exu_div_ctl/test`, `cpus/veer_el2/exu_div_new_4bit_fullshortq/test`, `cpus/veer_el2/exu_mul_ctl/test`, `cpus/veer_el2/ifu_compress_ctl/patches`, `cpus/veer_el2/ifu_iccm_mem/patches`, `cpus/veer_el2/lsu/patches`, `cpus/veer_el2/lsu_addrcheck/test`, `cpus/veer_el2/lsu_bus_buffer/test`, `cpus/veer_el2/lsu_bus_intf/test`, `cpus/veer_el2/lsu_dccm_ctl/patches`, `cpus/veer_el2/lsu_dccm_mem/patches`, `cpus/veer_el2/lsu_lsc_ctl/test`, `cpus/veer_el2/lsu_stbuf/test`, `cpus/veer_el2/pmp/test`, `cpus/veer_el2/rvbradder/test`, `cpus/veer_el2/rvecc_encode/test`, `cpus/veer_el2/rvlsadder/test`.

<a id="github-com-chipsalliance-rocket-chip"></a>
### github.com/chipsalliance/rocket-chip

Project: https://github.com/chipsalliance/rocket-chip.

Fixed revisions: `114325b27cfe5312c86a8a325b187be9455a62af`, `aa183271e978d708d9c75617bd1e261b755b6726`.

Licenses of the quoted files:

- Header "See LICENSE.SiFive for license details.": Apache-2.0 (`LICENSE.SiFive`). Files: `src/main/scala/devices/debug/Debug.scala`, `src/main/scala/diplomacy/BundleBridge.scala`, `src/main/scala/diplomacy/LazyModule.scala`, `src/main/scala/diplomacy/Nodes.scala`, `src/main/scala/diplomacy/Parameters.scala`, `src/main/scala/interrupts/Nodes.scala`, `src/main/scala/interrupts/Parameters.scala`, `src/main/scala/interrupts/Xbar.scala`, `src/main/scala/interrupts/package.scala`, `src/main/scala/rocket/Breakpoint.scala`, `src/main/scala/rocket/DCache.scala`, `src/main/scala/rocket/PMP.scala`, `src/main/scala/rocket/RVC.scala`, `src/main/scala/rocket/TLBPermissions.scala`, `src/main/scala/subsystem/BankedL2Params.scala`, `src/main/scala/subsystem/HasTiles.scala`, `src/main/scala/subsystem/InterruptBus.scala`, `src/main/scala/tile/BaseTile.scala`, `src/main/scala/tile/Core.scala`, `src/main/scala/tile/CustomCSRs.scala`, `src/main/scala/tile/Interrupts.scala`, `src/main/scala/tile/L1Cache.scala`, `src/main/scala/tilelink/Arbiter.scala`, `src/main/scala/tilelink/Bundles.scala`, `src/main/scala/tilelink/Edges.scala`, `src/main/scala/tilelink/Nodes.scala`, `src/main/scala/tilelink/Parameters.scala`, `src/main/scala/tilelink/Xbar.scala`, `src/main/scala/tilelink/package.scala`, `src/main/scala/util/Annotations.scala`, `src/main/scala/util/BundleMap.scala`.
- Header "See LICENSE.Berkeley for license details.": BSD-3-Clause (`LICENSE.Berkeley`). Files: `build.sbt`, `src/main/scala/rocket/Consts.scala`, `src/main/scala/rocket/Decode.scala`, `src/main/scala/rocket/package.scala`.
- Headers naming both `LICENSE.Berkeley` and `LICENSE.SiFive`: BSD-3-Clause and Apache-2.0. Files: `src/main/scala/rocket/ALU.scala`, `src/main/scala/rocket/AMOALU.scala`, `src/main/scala/rocket/CSR.scala`, `src/main/scala/rocket/Frontend.scala`, `src/main/scala/rocket/HellaCache.scala`, `src/main/scala/rocket/HellaCacheArbiter.scala`, `src/main/scala/rocket/ICache.scala`, `src/main/scala/rocket/IDecode.scala`, `src/main/scala/rocket/Instructions.scala`, `src/main/scala/rocket/Multiplier.scala`, `src/main/scala/rocket/NBDcache.scala`, `src/main/scala/rocket/PTW.scala`, `src/main/scala/rocket/RocketCore.scala`, `src/main/scala/rocket/TLB.scala`, `src/main/scala/subsystem/Configs.scala`, `src/main/scala/tile/FPU.scala`, `src/main/scala/tile/LazyRoCC.scala`, `src/main/scala/tilelink/Metadata.scala`, `src/main/scala/util/CoreMonitor.scala`, `src/main/scala/util/DescribedSRAM.scala`, `src/main/scala/util/Replacement.scala`.
- No license header: both repository licenses, BSD-3-Clause (`LICENSE.Berkeley`) and Apache-2.0 (`LICENSE.SiFive`). Files: `docs/src/diplomacy/adder_tutorial.md`.

Commit messages quoted from this project: Apache-2.0; see [Commit messages](#commit-messages).

Copyright and author attribution:

- Copyright (c) 2012-2014, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright 2016-2017 SiFive, Inc.

Original license texts: [Rocket-Chip-LICENSE.Berkeley.txt](LICENSES/license-texts/Rocket-Chip-LICENSE.Berkeley.txt), [Rocket-Chip-LICENSE.jtag.txt](LICENSES/license-texts/Rocket-Chip-LICENSE.jtag.txt), [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

Test and patch directories: `cpus/boom/_shared/patches`, `cpus/rift2core/environment`.

<a id="github-com-chipsalliance-rocket-chip-inclusive-cache"></a>
### github.com/chipsalliance/rocket-chip-inclusive-cache

Project: https://github.com/chipsalliance/rocket-chip-inclusive-cache.

Fixed revisions: `51d400bd32131e8914c6713bfb71bef690f2fe70`, `e3a3000cc1fd4cdf3a4e638e4d081b8aae94ebf0`.

License of the quoted files: Apache-2.0.

Copyright and author attribution:

- Copyright 2019 SiFive, Inc.

Original license texts: [Rocket-Chip-Inclusive-Cache-Apache-2.0.txt](LICENSES/license-texts/Rocket-Chip-Inclusive-Cache-Apache-2.0.txt).

<a id="github-com-cnrv-rocket-chip-read"></a>
### github.com/cnrv/rocket-chip-read

Project: https://github.com/cnrv/rocket-chip-read.

Fixed revisions: `7701f1d2f882c1674813a0c8f697208a3fa339df`, `d8e109d5a774cf85e717f36035386e56eacd4a32`.

License of the quoted files: CC BY 3.0 for the quoted lines 65–70 and 72 of `rocket/HellaCache.md`; see [HellaCache](#hellacache).

Copyright and author attribution:

- © (2012-2014, 2016) The Regents of the University of California (Regents)
- © (2016-2017) SiFive, Inc
- © (2017) Wei Song

Original license texts: [CC-BY-3.0.txt](LICENSES/license-texts/CC-BY-3.0.txt), [Rocket-Chip-LICENSE.Berkeley.txt](LICENSES/license-texts/Rocket-Chip-LICENSE.Berkeley.txt), [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

<a id="github-com-lowrisc-ibex"></a>
### github.com/lowRISC/ibex

Project: https://github.com/lowRISC/ibex.

Fixed revisions: `405c6d1d8220a18b2f9196141167a5875422dee4`.

License of the quoted files: Apache-2.0.

Copyright and author attribution:

- Author: lowRISC contributors.
- Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2020. RISC-V International. All rights reserved.
- Copyright 2017 ETH Zurich and University of Bologna, see also CREDITS.md.
- Copyright 2017-2018, ETH Zurich and University of Bologna, 2018-present lowRISC.
- Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
- Copyright Microsoft Corporation
- Copyright lowRISC contributors (OpenTitan project).
- Copyright lowRISC contributors.

Original license texts: [LICENSE](LICENSE), [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt), [riscv-arch-test-a5a49fc9f244-COPYING.BSD](LICENSES/license-texts/riscv-arch-test-a5a49fc9f244-COPYING.BSD).

Original notices: [Ibex-CREDITS.md](LICENSES/source-notices/Ibex-CREDITS.md), [Ibex-NOTICE.txt](LICENSES/source-notices/Ibex-NOTICE.txt), [OpenTitan-NOTICE.txt](LICENSES/source-notices/OpenTitan-NOTICE.txt).

Test and patch directories: `cpus/ibex/_shared`, `cpus/ibex/alu/harness`, `cpus/ibex/cs_registers/test-patches`, `cpus/ibex/ex_block/harness`, `cpus/ibex/multdiv_fast/harness`, `cpus/ibex/register_file_ff`, `cpus/ibex/register_file_ff/harness`.

<a id="github-com-lowrisc-opentitan"></a>
### github.com/lowRISC/opentitan

Project: https://github.com/lowRISC/opentitan.

Fixed revisions: `3424e7fb4bc3ac92eb640d6af070055d293bc710`.

License: Apache-2.0. The OpenTitan `NOTICE` file accompanies the Ibex material in CPU-Eval.

Copyright and author attribution:

- Copyright 2024 lowRISC contributors (OpenTitan project).
- Copyright 2024 lowRISC contributors.

Original license texts: [LICENSE](LICENSE).

Original notices: [OpenTitan-NOTICE.txt](LICENSES/source-notices/OpenTitan-NOTICE.txt).

<a id="github-com-openhwgroup-core-v-verif"></a>
### github.com/openhwgroup/core-v-verif

Project: https://github.com/openhwgroup/core-v-verif.

Fixed revisions: `b3149ab0da3ac8bf2179e24595a4b7a860b668ff`.

License: Apache-2.0 WITH SHL-2.0.

Copyright and author attribution:

- Copyright (C) 2022 Thales DIS Design Services SAS
- Copyright (c) 2010-2017, The Regents of the University of California (Regents). All Rights Reserved.
- Original Author: Zbigniew CHAMSKI <zbigniew.chamski@thalesgroup.com>

Original license texts: [LICENSE](LICENSE), [RISC-V-ISA-Sim-LICENSE.txt](LICENSES/license-texts/RISC-V-ISA-Sim-LICENSE.txt), [core-v-verif-b3149ab0da3a-LICENSE.md](LICENSES/license-texts/core-v-verif-b3149ab0da3a-LICENSE.md).

Test and patch directories: `cpus/cva6/copro_alu/environment`, `cpus/cva6/popcount/harness`.

<a id="github-com-openhwgroup-core-v-xif"></a>
### github.com/openhwgroup/core-v-xif

Project: https://github.com/openhwgroup/core-v-xif.

Fixed revisions: `f08d951d52e3705b54767bbf13dbb4748383fe49`.

Each Solderpad Hardware License text (versions 0.51, 2.0 and 2.1) lets the recipient treat the work as licensed under Apache-2.0 instead.

License of the quoted files: No license header: Solderpad Hardware License, Version 2.1, the repository `LICENSE`.

Copyright and author attribution:

- Copyright 2021-2024 OpenHW Group and contributing members.

Original license texts: [LICENSE](LICENSE), [CORE-V-XIF-SHL-2.1.txt](LICENSES/license-texts/CORE-V-XIF-SHL-2.1.txt).

<a id="github-com-openhwgroup-cv-hpdcache"></a>
### github.com/openhwgroup/cv-hpdcache

Project: https://github.com/openhwgroup/cv-hpdcache.

Fixed revisions: `f404e7ebbda8baa4af3729535f520a6b12a06d03`.

Each Solderpad Hardware License text (versions 0.51, 2.0 and 2.1) lets the recipient treat the work as licensed under Apache-2.0 instead.

Licenses of the quoted files:

- SPDX header "Apache-2.0 WITH SHL-2.1": Apache-2.0 WITH SHL-2.1. Files: `docs/old/source/hpdcache_spec.tex`, `docs/source/cmo.rst`, `docs/source/interface.rst`, `docs/source/overview.rst`, `rtl/include/hpdcache_typedef.svh`, `rtl/lint/hpdcache_lint.sv`, `rtl/src/common/hpdcache_1hot_to_binary.sv`, `rtl/src/common/hpdcache_data_downsize.sv`, `rtl/src/common/hpdcache_data_resize.sv`, `rtl/src/common/hpdcache_data_upsize.sv`, `rtl/src/common/hpdcache_decoder.sv`, `rtl/src/common/hpdcache_demux.sv`, `rtl/src/common/hpdcache_fifo_reg.sv`, `rtl/src/common/hpdcache_fxarb.sv`, `rtl/src/common/hpdcache_lfsr.sv`, `rtl/src/common/hpdcache_mux.sv`, `rtl/src/common/hpdcache_prio_1hot_encoder.sv`, `rtl/src/common/hpdcache_regbank_wbyteenable_1rw.sv`, `rtl/src/common/hpdcache_rrarb.sv`, `rtl/src/common/hpdcache_sram.sv`, `rtl/src/common/hpdcache_sram_wbyteenable.sv`, `rtl/src/common/hpdcache_sync_buffer.sv`, `rtl/src/common/macros/behav/hpdcache_sram_1rw.sv`, `rtl/src/common/macros/behav/hpdcache_sram_ecc_1rw.sv`, `rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_1rw.sv`, `rtl/src/common/macros/behav/hpdcache_sram_wbyteenable_ecc_1rw.sv`, `rtl/src/hpdcache.sv`, `rtl/src/hpdcache_amo.sv`, `rtl/src/hpdcache_cmo.sv`, `rtl/src/hpdcache_core_arbiter.sv`, `rtl/src/hpdcache_ctrl.sv`, `rtl/src/hpdcache_ctrl_pe.sv`, `rtl/src/hpdcache_flush.sv`, `rtl/src/hpdcache_memctrl.sv`, `rtl/src/hpdcache_miss_handler.sv`, `rtl/src/hpdcache_mshr.sv`, `rtl/src/hpdcache_pkg.sv`, `rtl/src/hpdcache_rtab.sv`, `rtl/src/hpdcache_uncached.sv`, `rtl/src/hpdcache_victim_plru.sv`, `rtl/src/hpdcache_victim_random.sv`, `rtl/src/hpdcache_victim_sel.sv`, `rtl/src/hpdcache_wbuf.sv`, `rtl/src/hwpf_stride/hwpf_stride.sv`, `rtl/src/hwpf_stride/hwpf_stride_arb.sv`, `rtl/src/hwpf_stride/hwpf_stride_pkg.sv`, `rtl/src/hwpf_stride/hwpf_stride_wrapper.sv`, `rtl/src/utils/hpdcache_mem_req_read_arbiter.sv`, `rtl/src/utils/hpdcache_mem_req_write_arbiter.sv`, `rtl/src/utils/hpdcache_mem_resp_demux.sv`, `rtl/src/utils/hpdcache_mem_to_axi_read.sv`, `rtl/src/utils/hpdcache_mem_to_axi_write.sv`.
- SPDX header "Apache-2.0 WITH SHL-2.1", with text copied from the RISC-V unprivileged manual: Apache-2.0 WITH SHL-2.1, and CC BY 4.0 for the copied text (see [Creative Commons Attribution material](#creative-commons-attribution-material)). Files: `docs/source/amo.rst`, `docs/source/architecture.rst`.

Copyright and author attribution:

- Author(s): Cesar Fuguet
- Authors: Cesar Fuguet
- Authors: Riccardo Alidori, Cesar Fuguet
- Copyright 2023 CEA Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
- Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
- Copyright 2023,2024 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
- Copyright 2024 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
- Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
- Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory

Original license texts: [LICENSE](LICENSE), [CV-HPDcache-SHL-2.1.txt](LICENSES/license-texts/CV-HPDcache-SHL-2.1.txt), [CV-HPDcache-docs-SHL-2.1.txt](LICENSES/license-texts/CV-HPDcache-docs-SHL-2.1.txt).

Test and patch directories: `cpus/cva6/hpdcache_decoder/test-patches`, `cpus/cva6/hpdcache_fxarb/test-patches`, `cpus/cva6/hwpf_stride/test-patches`.

<a id="github-com-openhwgroup-cva6"></a>
### github.com/openhwgroup/cva6

Project: https://github.com/openhwgroup/cva6.

Fixed revisions: `6348e9e684678f83b40d0520028513d06b36e7b2`.

Each Solderpad Hardware License text (versions 0.51, 2.0 and 2.1) lets the recipient treat the work as licensed under Apache-2.0 instead.

Licenses of the quoted files:

- Header granting the Solderpad Hardware License, Version 0.51, or no license header (the repository `LICENSE`): SHL-0.51. Files: `common/local/util/sram_cache.sv`, `core/acc_dispatcher.sv`, `core/alu.sv`, `core/alu_wrapper.sv`, `core/ariane_regfile_ff.sv`, `core/ariane_regfile_fpga.sv`, `core/branch_unit.sv`, `core/cache_subsystem/axi_adapter.sv`, `core/cache_subsystem/cva6_icache.sv`, `core/cache_subsystem/cva6_icache_axi_wrapper.sv`, `core/cache_subsystem/wt_dcache_mem.sv`, `core/cache_subsystem/wt_dcache_missunit.sv`, `core/cache_subsystem/wt_dcache_wbuffer.sv`, `core/compressed_decoder.sv`, `core/controller.sv`, `core/csr_buffer.sv`, `core/csr_regfile.sv`, `core/cva6.sv`, `core/cva6_fifo_v3.sv`, `core/decoder.sv`, `core/ex_stage.sv`, `core/frontend/frontend.sv`, `core/frontend/instr_queue.sv`, `core/id_stage.sv`, `core/include/ariane_pkg.sv`, `core/include/build_config_pkg.sv`, `core/include/cvxif_types.svh`, `core/include/riscv_pkg.sv`, `core/include/wt_cache_pkg.sv`, `core/instr_realign.sv`, `core/issue_read_operands.sv`, `core/issue_stage.sv`, `core/load_store_unit.sv`, `core/load_unit.sv`, `core/lsu_bypass.sv`, `core/mult.sv`, `core/multiplier.sv`, `core/pmp/src/pmp.sv`, `core/pmp/src/pmp_data_if.sv`, `core/pmp/src/pmp_entry.sv`, `core/scoreboard.sv`, `core/serdiv.sv`, `core/store_buffer.sv`, `core/store_unit.sv`, `corev_apu/src/ariane.sv`, `corev_apu/tb/ariane_testharness.sv`, `corev_apu/tb/tb_cva6_icache/hdl/mem_emul.sv`, `corev_apu/tb/tb_cva6_icache/hdl/tb.sv`, `docs/03_cva6_design/commit_stage.rst`, `docs/03_cva6_design/ex_stage.md`, `docs/03_cva6_design/id_stage.md`, `docs/03_cva6_design/issue_stage.md`, `docs/03_cva6_design/pcgen_stage.md`, `docs/design/design-manual/source/CVX_Interface_Coprocessor.adoc`, `docs/design/design-manual/source/cva6_execute.adoc`, `docs/design/design-manual/source/mmu.adoc`, `vendor/pulp-platform/axi/include/axi/typedef.svh`, `vendor/pulp-platform/common_cells/README.md`, `vendor/pulp-platform/common_cells/src/fifo_v3.sv`, `vendor/pulp-platform/common_cells/src/lfsr.sv`, `vendor/pulp-platform/common_cells/src/popcount.sv`, `vendor/pulp-platform/common_cells/src/rr_arb_tree.sv`, `vendor/pulp-platform/common_cells/src/shift_reg.sv`, `vendor/pulp-platform/common_cells/src/stream_arbiter.sv`, `vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv`, `verif/docs/VerifPlans/FRONTEND/VP_IP007.yml`.
- SHL-0.51 header, with text copied from the RISC-V privileged manual: SHL-0.51, and CC BY 4.0 for the copied text (see [Creative Commons Attribution material](#creative-commons-attribution-material)). Files: `core/commit_stage.sv`.
- SHL-0.51 header of the vendored PULP AXI package: SHL-0.51, including its comments. The Arm AXI specification that the comments follow is not licensed by this file. Files: `vendor/pulp-platform/axi/src/axi_pkg.sv`.
- Vendored `lzc.sv` with a pre-release header: SHL-0.51; see the note on `lzc.sv` below. Files: `vendor/pulp-platform/common_cells/src/lzc.sv`.
- Header granting the Solderpad Hardware License, Version 2.0, or SPDX "Apache-2.0 WITH SHL-2.0": Apache-2.0 WITH SHL-2.0. Files: `common/local/util/tc_sram_wrapper_cache_techno.sv`, `core/cva6_rvfi.sv`, `core/cva6_rvfi_probes.sv`, `core/cvxif_compressed_if_driver.sv`, `core/cvxif_example/compressed_instr_decoder.sv`, `core/cvxif_example/copro_alu.sv`, `core/cvxif_example/cvxif_example_coprocessor.sv`, `core/cvxif_example/include/cvxif_instr_pkg.sv`, `core/cvxif_example/instr_decoder.sv`, `core/cvxif_fu.sv`, `core/cvxif_issue_register_commit_if_driver.sv`, `core/frontend/bht.sv`, `core/frontend/instr_scan.sv`, `core/frontend/ras.sv`, `core/include/config_pkg.sv`, `core/include/cv32a60x_config_pkg.sv`, `core/include/cv64a6_imafdc_sv39_config_pkg.sv`, `core/include/cv64a6_imafdc_sv39_hpdcache_wb_config_pkg.sv`, `docs/csr-from-ip-xact/cv32a60x/csr_list.rst`, `docs/design/design-manual/source/cva6_frontend.adoc`, `verif/env/corev-dv/custom/riscv_zcb_instr.sv`, `verif/env/uvme/cvxif_vseq/uvme_cvxif_vseq.sv`.
- SPDX header "Apache-2.0 WITH SHL-2.1": Apache-2.0 WITH SHL-2.1. Files: `config/gen_from_riscv_config/cv32a65x/csr/csr.rst`, `core/cache_subsystem/cva6_hpdcache_if_adapter.sv`, `core/cache_subsystem/cva6_hpdcache_subsystem.sv`, `core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv`, `core/cache_subsystem/cva6_hpdcache_wrapper.sv`, `docs/01_cva6_user/Introduction.rst`, `docs/01_cva6_user/Traps_Interrupts_Exceptions.rst`, `docs/design/design-manual/source/cva6_commit_stage.adoc`, `docs/design/design-manual/source/cva6_id_stage.adoc`, `docs/design/design-manual/source/cva6_issue_stage.adoc`, `verif/env/uvme/cvxif_vseq/custom_instructions_cvxif_1_0_0.rst`.
- SPDX header "Apache-2.0 WITH SHL-2.1", with text copied from the RISC-V manuals: Apache-2.0 WITH SHL-2.1, and CC BY 4.0 for the copied text (see [Creative Commons Attribution material](#creative-commons-attribution-material)). Files: `docs/01_cva6_user/RISCV_Instructions_RV32ZCb.rst`, `docs/01_cva6_user/RISCV_Instructions_RVZicsr.rst`, `docs/csr-from-ip-xact/cv32a60x/cv32a60mx_csr.md`.
- Headers naming both the Solderpad Hardware License, Version 0.51, and SPDX "Apache-2.0 WITH SHL-2.1": both licenses. Files: `core/cva6_mmu/cva6_mmu.sv`, `core/cva6_mmu/cva6_shared_tlb.sv`, `core/raw_checker.sv`.
- Header "See LICENSE for license details." in the boot ROM `encoding.h`: BSD-3-Clause; see the note on `encoding.h` below. Files: `corev_apu/bootrom/encoding.h`.
- Header "See LICENSE for license details." in `verif/tests/custom/env/encoding.h`: BSD-3-Clause, the `LICENSE` file in the same directory. Files: `verif/tests/custom/env/encoding.h`.

The four excerpts of the boot ROM `corev_apu/bootrom/encoding.h` used in `compressed_decoder` also appear unchanged in [RISC-V ISA simulator `riscv/encoding.h` at revision `12714e371e9b8ce2efcf0e77347ed1b33c8de27b`](https://github.com/riscv-software-src/riscv-isa-sim/blob/12714e371e9b8ce2efcf0e77347ed1b33c8de27b/riscv/encoding.h). CPU-Eval uses them under its BSD-3-Clause license.

The copyright line of `core/frontend/ras.sv`, "Copyright (C) 2018 to present,", names no holder; the author line of the file names Florian Zaruba, ETH Zurich.

The vendored `vendor/pulp-platform/common_cells/src/lzc.sv`, quoted in `cva6_icache`, `instr_queue`, `load_unit` and `lzc`, keeps a pre-release header: "Copyright (c) 2018 - 2019 ETH Zurich, University of Bologna. All rights reserved." and "Any reuse/redistribution is strictly forbidden without written permission from ETH Zurich." The quoted lines are identical in [common_cells `src/lzc.sv` at revision `9b7c7dfdec57bf589ea67e2d7958c98a4d532996`](https://github.com/pulp-platform/common_cells/blob/9b7c7dfdec57bf589ea67e2d7958c98a4d532996/src/lzc.sv), where the same holders replaced that header with "Copyright 2018 ETH Zurich and University of Bologna. Solderpad Hardware License, Version 0.51" (commit "lzc: Fix license header"). CPU-Eval uses these lines under SHL-0.51.

Copyright and author attribution:

- Additional contributions by: Angela Gonzalez - PlanV Technologies
- Additional contributions by: Markus Wegmann - markus.wegmann@technokrat.ch
- Author: <zarubaf@iis.ee.ethz.ch>
- Author: Abdessamii Oukalrazqou
- Author: Andreas Traber <atraber@student.ethz.ch>
- Author: Angela Gonzalez PlanV Technology
- Author: Angela Gonzalez, PlanV Technology
- Author: Cesar Fuguet - CEA
- Author: Florian Zaruba - zarubaf@iis.ee.ethz.ch
- Author: Florian Zaruba <zaruabf@iis.ee.ethz.ch>
- Author: Florian Zaruba <zarubaf@ethz.ch>
- Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
- Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>, ETH Zurich, Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
- Author: Florian Zaruba, ETH Zurich
- Author: Igor Loi <igor.loi@unibo.it>
- Author: Lukas Mueller <lukasmue@student.ethz.ch>
- Author: Manuel Eggimann <meggimann@iis.ee.ethz.ch>
- Author: Matthias Baer <baermatt@student.ethz.ch>
- Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
- Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich, Andreas Traber <traber@iis.ee.ethz.ch>, ETH Zurich
- Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich, Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>, ETH Zurich
- Author: Mohamed Aziz FRIKHA
- Author: Moritz Schneider, ETH Zurich
- Author: Nils Wistoff <nwistoff@iis.ee.ethz.ch>, ETH Zurich
- Author: Wolfgang Roenninger <wroennin@ethz.ch>
- Authors: Andreas Kurth <akurth@iis.ee.ethz.ch>, Florian Zaruba <zarubaf@iis.ee.ethz.ch>, Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
- Authors: Andreas Kurth <akurth@iis.ee.ethz.ch>, Florian Zaruba <zarubaf@iis.ee.ethz.ch>, Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>, Fabian Schuiki <fschuiki@iis.ee.ethz.ch>, Matheus Cavalcante <matheusd@iis.ee.ethz.ch>
- Authors: Cesar Fuguet
- Authors: Matheus Cavalcante, ETH Zurich, Nils Wistoff, ETH Zurich
- Copyright (C) 2013-2018 ETH Zurich, University of Bologna
- Copyright (C) 2017 ETH Zurich, University of Bologna All rights reserved.
- Copyright (C) 2018 to present,
- Copyright (c) 2010-2017, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2014-2020 ETH Zurich, University of Bologna
- Copyright (c) 2018 - 2019 ETH Zurich, University of Bologna All rights reserved.
- Copyright (c) 2018 ETH Zurich and University of Bologna.
- Copyright (c) 2019 ETH Zurich, University of Bologna
- Copyright (c) 2020 ETH Zurich and University of Bologna.
- Copyright (c) 2021 Thales.
- Copyright (c) 2022 Bruno Sá and Zero-Day Labs.
- Copyright (c) 2023 OpenHW Group
- Copyright (c) 2023 Thales
- Copyright (c) 2023 Thales DIS SAS
- Copyright (c) 2023 Thales DIS design services SAS
- Copyright (c) 2023 Thales Silicon Security
- Copyright (c) 2023 Thales.
- Copyright (c) 2024 OpenHW Group
- Copyright (c) 2024 PlanV Technology
- Copyright (c) 2024 Thales
- Copyright (c) 2024, PlanV Technology
- Copyright 2017-2019 ETH Zurich and University of Bologna.
- Copyright 2018 - 2019 ETH Zurich and University of Bologna.
- Copyright 2018 ETH Zurich and University of Bologna.
- Copyright 2019 ETH Zurich and University of Bologna.
- Copyright 2020 ETH Zurich and University of Bologna.
- Copyright 2021 Thales DIS design services SAS
- Copyright 2022 Thales DIS design services SAS
- Copyright 2023 - Thales for additional contribution.
- Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
- Copyright 2023 OpenHW Group
- Copyright 2023 OpenHW Group and Thales
- Copyright 2023 Thales DIS
- Copyright 2023 Thales DIS France SAS
- Copyright 2024 - PlanV Technologies for additional contribution.
- Copyright 2024 Robert Bosch GmbH
- Copyright 2024 Thales DIS France SAS
- Copyright 2025 ETH Zurich and University of Bologna.
- Engineer: Francesco Conti - f.conti@unibo.it
- Engineer: Sven Stucki - svstucki@student.ethz.ch
- Original Author: Ayoub JALALI (ayoub.jalali@external.thalesgroup.com)
- Original Author: Coralie Allioux - Robert Bosch France SAS
- Original Author: Guillaume Chauvon
- Original Author: Guillaume Chauvon (guillaume.chauvon@thalesgroup.com)
- Original Author: Jean-Roch COULON - Thales
- Original Author: Junheng Zheng - Thales
- Original Author: Yannick Casamatta - Thales
- Original Author: Zineb EL KACIMI (zineb.el-kacimi@external.thalesgroup.com)
- Original authors: Gianmarco Ottavi, University of Bologna, Riccardo Tedeschi, University of Bologna

Original license texts: [LICENSE](LICENSE), [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [CORE-V-XIF-SHL-2.1.txt](LICENSES/license-texts/CORE-V-XIF-SHL-2.1.txt), [CORE-V-XIF-src-SHL-2.0.txt](LICENSES/license-texts/CORE-V-XIF-src-SHL-2.0.txt), [CV-HPDcache-SHL-2.1.txt](LICENSES/license-texts/CV-HPDcache-SHL-2.1.txt), [CV-HPDcache-docs-SHL-2.1.txt](LICENSES/license-texts/CV-HPDcache-docs-SHL-2.1.txt), [CVA6-SHL-0.51.txt](LICENSES/license-texts/CVA6-SHL-0.51.txt), [Chipyard-CVA6-LICENSE.Berkeley.txt](LICENSES/license-texts/Chipyard-CVA6-LICENSE.Berkeley.txt), [PULP-common-cells-SHL-0.51.txt](LICENSES/license-texts/PULP-common-cells-SHL-0.51.txt), [RISC-V-ISA-Sim-LICENSE.txt](LICENSES/license-texts/RISC-V-ISA-Sim-LICENSE.txt), [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

Test and patch directories: `cpus/cva6/copro_alu/tests`, `cpus/cva6/csr_buffer/harness`, `cpus/cva6/cva6_hpdcache_if_adapter/harness`, `cpus/cva6/harness`, `cpus/cva6/hwpf_stride/test-patches`, `cpus/cva6/hwpf_stride_arb/test-patches`, `cpus/cva6/lsu_bypass/test-patches`, `cpus/cva6/pmp/test-patches`.

<a id="github-com-pulp-platform-common-cells"></a>
### github.com/pulp-platform/common_cells

Project: https://github.com/pulp-platform/common_cells.

Fixed revisions: `9b7c7dfdec57bf589ea67e2d7958c98a4d532996`, `dc555643226419b7a602f0aa39d449545ea4c1f2`.

Each Solderpad Hardware License text (versions 0.51, 2.0 and 2.1) lets the recipient treat the work as licensed under Apache-2.0 instead.

License of the quoted files: Solderpad Hardware License, Version 0.51, as the file header states.

Copyright and author attribution:

- Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
- Copyright 2019 ETH Zurich and University of Bologna.

Original license texts: [PULP-common-cells-SHL-0.51.txt](LICENSES/license-texts/PULP-common-cells-SHL-0.51.txt).

<a id="github-com-riscv-boom-riscv-boom"></a>
### github.com/riscv-boom/riscv-boom

Project: https://github.com/riscv-boom/riscv-boom.

Fixed revisions: `5223e44cfeb26f41380057a2eb4d651197475f69`, `efe2b35cc2224edf3a417381d437cfdcb37e02a8`.

Licenses of the quoted files:

- No license header: BSD-3-Clause, the repository `LICENSE`. Files: `docs/sections/branch-prediction/backing-predictor.rst`, `docs/sections/branch-prediction/nl-predictor.rst`, `docs/sections/decode-stage.rst`, `docs/sections/execution-stages.rst`, `docs/sections/instruction-fetch-stage.rst`, `docs/sections/intro-overview/boom-pipeline.rst`, `docs/sections/intro-overview/riscv-isa.rst`, `docs/sections/issue-units.rst`, `docs/sections/load-store-unit.rst`, `docs/sections/memory-system.rst`, `docs/sections/reg-file-bypass-network.rst`, `docs/sections/rename-stage.rst`, `docs/sections/reorder-buffer.rst`, `docs/sections/terminology.rst`, `src/main/scala/ifu/bpd/bim.scala`, `src/main/scala/ifu/bpd/btb.scala`, `src/main/scala/ifu/bpd/composer.scala`, `src/main/scala/ifu/bpd/faubtb.scala`, `src/main/scala/ifu/bpd/local.scala`, `src/main/scala/ifu/bpd/loop.scala`, `src/main/scala/ifu/bpd/predictor.scala`, `src/main/scala/ifu/bpd/tage.scala`, `src/main/scala/lsu/tlb.scala`.
- Header "See LICENSE and LICENSE.SiFive for license details.": BSD-3-Clause (`LICENSE`) and Apache-2.0 (`LICENSE.SiFive`). Files: `src/main/scala/common/config-mixins.scala`, `src/main/scala/common/consts.scala`, `src/main/scala/common/micro-op.scala`, `src/main/scala/common/package.scala`, `src/main/scala/common/parameters.scala`, `src/main/scala/common/tile.scala`, `src/main/scala/common/types.scala`, `src/main/scala/exu/core.scala`, `src/main/scala/exu/decode.scala`, `src/main/scala/exu/dispatch.scala`, `src/main/scala/exu/execution-units/execution-unit.scala`, `src/main/scala/exu/execution-units/execution-units.scala`, `src/main/scala/exu/execution-units/fdiv.scala`, `src/main/scala/exu/execution-units/fpu.scala`, `src/main/scala/exu/execution-units/functional-unit.scala`, `src/main/scala/exu/execution-units/rocc.scala`, `src/main/scala/exu/fp-pipeline.scala`, `src/main/scala/exu/issue-units/issue-slot.scala`, `src/main/scala/exu/issue-units/issue-unit-age-ordered.scala`, `src/main/scala/exu/issue-units/issue-unit.scala`, `src/main/scala/exu/register-read/func-unit-decode.scala`, `src/main/scala/exu/register-read/regfile.scala`, `src/main/scala/exu/register-read/register-read.scala`, `src/main/scala/exu/rename/rename-busytable.scala`, `src/main/scala/exu/rename/rename-freelist.scala`, `src/main/scala/exu/rename/rename-maptable.scala`, `src/main/scala/exu/rename/rename-stage.scala`, `src/main/scala/exu/rob.scala`, `src/main/scala/ifu/bpd/ras.scala`, `src/main/scala/ifu/fetch-buffer.scala`, `src/main/scala/ifu/fetch-target-queue.scala`, `src/main/scala/ifu/frontend.scala`, `src/main/scala/ifu/icache.scala`, `src/main/scala/lsu/lsu.scala`, `src/main/scala/util/util.scala`.
- Header "Ported from Rocket-Chip. See LICENSE.Berkeley and LICENSE.SiFive in Rocket-Chip for license details.": BSD-3-Clause and Apache-2.0 under the Rocket Chip `LICENSE.Berkeley` and `LICENSE.SiFive`. Files: `src/main/scala/lsu/dcache.scala`, `src/main/scala/lsu/mshrs.scala`.
- Header "See LICENSE.Berkeley for license details.": BSD-3-Clause under the Rocket Chip `LICENSE.Berkeley`. Files: `src/main/scala/lsu/prefetcher.scala`.

Commit messages quoted from this project: Apache-2.0; see [Commit messages](#commit-messages).

Copyright and author attribution:

- Copyright (c) 2011 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2012 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2012 - 2019, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2012-2014, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2012-2020, The Regents of the University of California (Regents) All rights reserved.
- Copyright (c) 2013 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2013 - 2019, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2015 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2015 - 2019, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2016 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2017 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2017 - 2019, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2018 - 2018, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2018 - 2019, The Regents of the University of California (Regents). All Rights Reserved.

Original license texts: [BOOM-BSD-3-Clause-2012-2020.txt](LICENSES/license-texts/BOOM-BSD-3-Clause-2012-2020.txt), [Rocket-Chip-LICENSE.Berkeley.txt](LICENSES/license-texts/Rocket-Chip-LICENSE.Berkeley.txt), [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

Test and patch directories: `cpus/boom/_shared/patches`, `cpus/boom/btb_branch_predictor_bank/patches`, `cpus/boom/fetch_target_queue/test`, `cpus/boom/nbdtlb/patches`, `cpus/boom/null_local_branch_predictor_bank/patches`, `cpus/boom/tage_table/patches`.

<a id="github-com-riscv-non-isa-riscv-arch-test"></a>
### github.com/riscv-non-isa/riscv-arch-test

Project: https://github.com/riscv-non-isa/riscv-arch-test.

Fixed revisions: `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

License: BSD-3-Clause.

Copyright and author attribution:

- Copyright (c) 2020. RISC-V International. All rights reserved.

Original license texts: [LICENSE](LICENSE), [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt), [riscv-arch-test-a5a49fc9f244-COPYING.BSD](LICENSES/license-texts/riscv-arch-test-a5a49fc9f244-COPYING.BSD), [riscv-arch-test-a5a49fc9f244-COPYING.CC](LICENSES/license-texts/riscv-arch-test-a5a49fc9f244-COPYING.CC).

Test and patch directories: `cpus/cva6/ariane`, `cpus/cva6/ariane_regfile/harness`, `cpus/cva6/bht/harness`, `cpus/cva6/branch_unit/harness`, `cpus/cva6/commit_stage/harness`, `cpus/cva6/compressed_decoder/harness`, `cpus/cva6/compressed_instr_decoder/tests`, `cpus/cva6/controller/tests`, `cpus/cva6/copro_alu/tests`, `cpus/cva6/csr_buffer/tests`, `cpus/cva6/csr_regfile/tests`, `cpus/cva6/cva6/tests`, `cpus/cva6/cva6_hpdcache_if_adapter/harness`, `cpus/cva6/cva6_hpdcache_subsystem_axi_arbiter/harness`, `cpus/cva6/cvxif_compressed_if_driver/harness`, `cpus/cva6/cvxif_fu/tests`, `cpus/cva6/cvxif_issue_register_commit_if_driver/tests`, `cpus/cva6/harness`, `cpus/cva6/hpdcache_amo/harness`, `cpus/cva6/hpdcache_ctrl_pe/harness`, `cpus/cva6/hpdcache_mem_req_write_arbiter/harness`, `cpus/cva6/hpdcache_mem_to_axi_read/harness`, `cpus/cva6/hpdcache_mem_to_axi_write/harness`, `cpus/cva6/hpdcache_memctrl/harness`, `cpus/cva6/hpdcache_miss_handler/harness`, `cpus/cva6/hpdcache_regbank_wbyteenable_1rw/harness`, `cpus/cva6/hpdcache_rtab/harness`, `cpus/cva6/hpdcache_sram/harness`, `cpus/cva6/hpdcache_sram_1rw/harness`, `cpus/cva6/hpdcache_victim_random/harness`, `cpus/cva6/hpdcache_victim_sel/harness`, `cpus/cva6/hwpf_stride/harness`, `cpus/cva6/hwpf_stride_wrapper/test-patches`, `cpus/cva6/instr_queue/harness`, `cpus/cva6/instr_scan/harness`, `cpus/cva6/issue_read_operands/harness`, `cpus/cva6/lfsr/harness`, `cpus/cva6/popcount/harness`, `cpus/cva6/ras/harness`, `cpus/cva6/raw_checker/harness`, `cpus/cva6/serdiv/harness`, `cpus/cva6/sram_cache/harness`, `cpus/cva6/store_buffer/harness`, `cpus/cva6/store_buffer/tests/patches`.

<a id="github-com-riscv-software-src-riscv-tests"></a>
### github.com/riscv-software-src/riscv-tests

Project: https://github.com/riscv-software-src/riscv-tests.

Fixed revisions: `1ce128fa78c24bb0ed399c647e7139322b5353a7`, `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

The `encoding.h` header of riscv-test-env carries only `SPDX-License-Identifier: BSD-3-Clause` and `Copyright (c) 2023 RISC-V International`. Rift-ALU-encoding-BSD-3-Clause.txt is the BSD-3-Clause text with that copyright line, written out by CPU-Eval.

License: BSD-3-Clause.

Copyright and author attribution:

- Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright (c) 2023 RISC-V International

Original license texts: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

Test and patch directories: `cpus/boom/fp_to_fp/patches`, `cpus/rift2core/dividor/tests/word-zero/images`, `cpus/rift2core/mmu/tests/sv39-megapage/images`, `cpus/rift2core/ras/harness`, `cpus/rift2core/rename/tests/mstatus-load-order/images`, `cpus/rift2core/tlb/tests/sv39-megapage-reuse/images`.

<a id="github-com-riscv-riscv-debug-spec"></a>
### github.com/riscv/riscv-debug-spec

Project: https://github.com/riscv/riscv-debug-spec.

Fixed revisions: `b13891ce9848b4a673e05bcab50359495f830692`, `ceb5d66a7e0cb5cea0511b50849ee4acc7baaa01`.

`SPEC_SOURCES.json` of `cpus/boom/csr_file` records this repository as `github.com/riscv/riscv-debug-spec@ceb5d66`; the recorded revisions and files are those of github.com/riscv/riscv-debug-spec.

License of the quoted files: CC-BY-4.0.

Original license texts: [RISC-V-Debug-Spec-CC-BY-4.0.txt](LICENSES/license-texts/RISC-V-Debug-Spec-CC-BY-4.0.txt).

<a id="github-com-riscv-riscv-isa-manual"></a>
### github.com/riscv/riscv-isa-manual

Project: https://github.com/riscv/riscv-isa-manual.

Fixed revisions: `4f277ff8ea8c0fc9394dfccd1da0ace34b1aef68`, `f8614dc09c6ce1667cc70be7bdeda6cd7382e5f1`, `fa794b679cb50da3b68c49ffd5ae7559f4fa1422`, `fd3f34b7c56e08f83ea842d69bc66c1c054c9c45`.

License of the quoted files: CC-BY-4.0.

Original license texts: [RISC-V-ISA-Manual-CC-BY-4.0-4f277ff8ea8c.txt](LICENSES/license-texts/RISC-V-ISA-Manual-CC-BY-4.0-4f277ff8ea8c.txt), [RISC-V-ISA-Manual-CC-BY-4.0-fa794b679cb5.txt](LICENSES/license-texts/RISC-V-ISA-Manual-CC-BY-4.0-fa794b679cb5.txt), [RISC-V-ISA-Manual-license.adoc.txt](LICENSES/license-texts/RISC-V-ISA-Manual-license.adoc.txt).

<a id="github-com-spinalhdl-spinalhdl"></a>
### github.com/SpinalHDL/SpinalHDL

Project: https://github.com/SpinalHDL/SpinalHDL.

Fixed revisions: `95a5e6c65c54acfc4707c8fe6ef8b5d297cfcbde`.

Licenses of the quoted files:

- Files outside `core`: MIT, as the repository `LICENSE` and `README` state. Files: `lib/src/main/scala/spinal/lib/Stream.scala`, `tester/src/test/scala/spinal/lib/SpinalSimStreamFifoTester.scala`.
- Header granting LGPL-3.0-or-later: LGPL-3.0-or-later; see [LGPL material](#lgpl-material). Files: `core/src/main/scala/spinal/core/MaskedLiteral.scala`.

Copyright and author attribution:

- (c) Dolu, All rights reserved
- Copyright (c) 2016 Spinal HDL contributors

Original license texts: [GNU-GPL-3.0.txt](LICENSES/license-texts/GNU-GPL-3.0.txt), [GNU-LGPL-3.0.txt](LICENSES/license-texts/GNU-LGPL-3.0.txt), [SpinalHDL-VexRiscv-MIT.txt](LICENSES/license-texts/SpinalHDL-VexRiscv-MIT.txt).

Original notices: [SpinalHDL-LICENSE.txt](LICENSES/source-notices/SpinalHDL-LICENSE.txt).

<a id="github-com-spinalhdl-vexriscv"></a>
### github.com/SpinalHDL/VexRiscv

Project: https://github.com/SpinalHDL/VexRiscv.

Fixed revisions: `c4b2a55b22f46afb760446cd69f3ca7c36eef778`.

Licenses of the quoted files:

- No license header: MIT, the repository `LICENSE`. Files: `README.md`, `src/main/scala/vexriscv/Pipeline.scala`, `src/main/scala/vexriscv/Riscv.scala`, `src/main/scala/vexriscv/Services.scala`, `src/main/scala/vexriscv/Stage.scala`, `src/main/scala/vexriscv/VexRiscv.scala`, `src/main/scala/vexriscv/VexRiscvBmbGenerator.scala`, `src/main/scala/vexriscv/demo/GenFullWithTcm.scala`, `src/main/scala/vexriscv/demo/smp/VexRiscvSmpCluster.scala`, `src/main/scala/vexriscv/ip/DataCache.scala`, `src/main/scala/vexriscv/plugin/BranchPlugin.scala`, `src/main/scala/vexriscv/plugin/CsrPlugin.scala`, `src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala`, `src/main/scala/vexriscv/plugin/DebugPlugin.scala`, `src/main/scala/vexriscv/plugin/DecoderSimplePlugin.scala`, `src/main/scala/vexriscv/plugin/EmbeddedRiscvJtag.scala`, `src/main/scala/vexriscv/plugin/Fetcher.scala`, `src/main/scala/vexriscv/plugin/HazardSimplePlugin.scala`, `src/main/scala/vexriscv/plugin/IBusSimplePlugin.scala`, `src/main/scala/vexriscv/plugin/IntAluPlugin.scala`, `src/main/scala/vexriscv/plugin/MemoryTranslatorPlugin.scala`, `src/main/scala/vexriscv/plugin/MmuPlugin.scala`, `src/main/scala/vexriscv/plugin/MulDivIterativePlugin.scala`, `src/main/scala/vexriscv/plugin/Plugin.scala`, `src/main/scala/vexriscv/plugin/RegFilePlugin.scala`, `src/main/scala/vexriscv/plugin/ShiftPlugins.scala`, `src/main/scala/vexriscv/plugin/SrcPlugin.scala`, `src/test/cpp/regression/main.cpp`, `src/test/scala/vexriscv/TestIndividualFeatures.scala`.
- Header granting LGPL-3.0-or-later: LGPL-3.0-or-later; see [LGPL material](#lgpl-material). Files: `src/main/scala/vexriscv/TestsWorkspace.scala`.

Copyright and author attribution:

- Copyright (c) 2016 Spinal HDL contributors
- Copyright (c) Dolu, All rights reserved.

Original license texts: [GNU-GPL-3.0.txt](LICENSES/license-texts/GNU-GPL-3.0.txt), [GNU-LGPL-3.0.txt](LICENSES/license-texts/GNU-LGPL-3.0.txt), [SpinalHDL-VexRiscv-MIT.txt](LICENSES/license-texts/SpinalHDL-VexRiscv-MIT.txt).

Test and patch directories: `cpus/vexriscv/_shared/test-patches`.

<a id="github-com-ucb-bar-barstools"></a>
### github.com/ucb-bar/barstools

Project: https://github.com/ucb-bar/barstools.

Fixed revisions: `314d80729e7b32e3c10c0da6734bbdc9a867916f`.

License: BSD-3-Clause.

Copyright and author attribution:

- Copyright (c) 2016, The Regents of the University of California (Regents) All rights reserved.

Original license texts: [barstools-314d80729e7b-LICENSE.txt](LICENSES/license-texts/barstools-314d80729e7b-LICENSE.txt).

Test and patch directories: `cpus/boom/_shared/patches`.

<a id="github-com-ucb-bar-berkeley-hardfloat"></a>
### github.com/ucb-bar/berkeley-hardfloat

Project: https://github.com/ucb-bar/berkeley-hardfloat.

Fixed revisions: `70455e53f233a06cb5a342d125e22b7b1505c271`.

Licenses of the quoted files:

- HardFloat files: BSD-3-Clause, the repository `LICENSE`. Files: `README.md`, `doc/divSqrtRecFN_small.txt`, `doc/divSqrtRecodedFloat64_mulAddZ31.txt`, `src/main/scala/CompareRecFN.scala`, `src/main/scala/DivSqrtRecF64.scala`, `src/main/scala/DivSqrtRecF64_mulAddZ31.scala`, `src/main/scala/INToRecFN.scala`, `src/main/scala/MulAddRecFN.scala`, `src/main/scala/RecFNToIN.scala`, `src/main/scala/RecFNToRecFN.scala`, `src/main/scala/RoundAnyRawFNToRecFN.scala`, `src/main/scala/common.scala`, `src/main/scala/primitives.scala`, `src/main/scala/rawFloatFromRecFN.scala`.
- Berkeley SoftFloat Release 3e documentation in the `berkeley-softfloat-3` submodule: BSD-3-Clause, its `COPYING.txt`. Files: `berkeley-softfloat-3/doc/SoftFloat.html`.

Copyright and author attribution:

- Copyright (c) 2010-2015, The Regents of the University of California (Regents). All Rights Reserved.
- Copyright 2010, 2011, 2012, 2013, 2014, 2015, 2016 The Regents of the University of California. All rights reserved.
- Copyright 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the University of California. All rights reserved.
- Copyright 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018 The Regents of the University of California. All rights reserved.
- Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018 The Regents of the University of California. All rights reserved.

Original license texts: [Berkeley-HardFloat-LICENSE.txt](LICENSES/license-texts/Berkeley-HardFloat-LICENSE.txt), [Berkeley-SoftFloat-3e-COPYING.txt](LICENSES/license-texts/Berkeley-SoftFloat-3e-COPYING.txt).

Test and patch directories: `cpus/boom/_shared/patches`.

<a id="github-com-ucb-bar-chipyard"></a>
### github.com/ucb-bar/chipyard

Project: https://github.com/ucb-bar/chipyard.

Fixed revisions: `0e6080682b3dd0ce11cdfed1292ec20e70d75f80`.

Licenses of the quoted files:

- No license header: BSD-3-Clause, the repository `LICENSE`. Files: `build.sbt`, `docs/Customization/Custom-Core.rst`, `docs/TileLink-Diplomacy-Reference/NodeTypes.rst`, `docs/TileLink-Diplomacy-Reference/Widgets.rst`, `generators/chipyard/src/main/scala/config/BoomConfigs.scala`.
- Header "See LICENSE and LICENSE.SiFive for license details.": BSD-3-Clause (`LICENSE`) and Apache-2.0 (`LICENSE.SiFive`). Files: `generators/chipyard/src/main/scala/Subsystem.scala`.

Copyright and author attribution:

- Copyright (c) 2017-2020, The Regents of the University of California (Regents) All Rights Reserved.
- Copyright (c) 2019 - 2019, The Regents of the University of California (Regents). All Rights Reserved.

Original license texts: [Chipyard-CVA6-LICENSE.Berkeley.txt](LICENSES/license-texts/Chipyard-CVA6-LICENSE.Berkeley.txt), [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

Test and patch directories: `cpus/boom/_shared/patches`, `cpus/boom/null_local_branch_predictor_bank/patches`, `cpus/boom/pred_rename_stage/patches`, `cpus/boom/tage_branch_predictor_bank/patches`, `cpus/boom/tage_table/patches`.

<a id="github-com-ucb-bar-constellation"></a>
### github.com/ucb-bar/constellation

Project: https://github.com/ucb-bar/constellation.

Fixed revisions: `3632183fd1171d00c7f78b32c305841d231031b7`.

License: BSD-3-Clause.

Copyright and author attribution:

- Copyright (c) 2021-2022, The Regents of the University of California (Regents) All Rights Reserved.

Original license texts: [constellation-3632183fd117-LICENSE.txt](LICENSES/license-texts/constellation-3632183fd117-LICENSE.txt).

Test and patch directories: `cpus/rift2core/environment`.

<a id="github-com-ucb-bar-dsptools"></a>
### github.com/ucb-bar/dsptools

Project: https://github.com/ucb-bar/dsptools.

Fixed revisions: `a1809fbae9e49de7213116bbec79252645292e39`.

The `README` at this revision states "Copyright (c) 2015 - 2021 The Regents of the University of California. Released under the Modified (3-clause) BSD license." The `LICENSE` file at the same revision is the Apache License 2.0.

License: Apache-2.0.

Original license texts: [Chisel-Apache-2.0.txt](LICENSES/license-texts/Chisel-Apache-2.0.txt).

Test and patch directories: `cpus/boom/_shared/patches`.

<a id="github-com-ucb-bar-gemmini"></a>
### github.com/ucb-bar/gemmini

Project: https://github.com/ucb-bar/gemmini.

Fixed revisions: `c47cb7f3eb5c18390f176f3a53c43c8546d487d2`.

License: BSD-3-Clause.

Copyright and author attribution:

- Copyright (c) 2018-2019, The Regents of the University of California (Regents). All Rights Reserved.

Original license texts: [gemmini-c47cb7f3eb5c-LICENSE.txt](LICENSES/license-texts/gemmini-c47cb7f3eb5c-LICENSE.txt).

Test and patch directories: `cpus/boom/_shared/patches`.

<a id="github-com-ucb-bar-testchipip"></a>
### github.com/ucb-bar/testchipip

Project: https://github.com/ucb-bar/testchipip.

Fixed revisions: `aaf0cd18100a1b6b11f554b9acfcf2c01c0d40a4`.

License of the quoted files: BSD-3-Clause (repository default).

Copyright and author attribution:

- Copyright (c) 2016-2020, The Regents of the University of California (Regents) All Rights Reserved.

Original license texts: [TestChipIP-BSD-3-Clause.txt](LICENSES/license-texts/TestChipIP-BSD-3-Clause.txt).

<a id="github-com-whutddk-rift2core"></a>
### github.com/whutddk/Rift2Core

Project: https://github.com/whutddk/Rift2Core.

Fixed revisions: `64b660fb70e0cab491049bdeea87c27936dcbf1e`.

License of the quoted files: Apache-2.0. The header of each quoted file grants Apache-2.0, except `src/main/scala/Config.scala`, which has no header. For that file CPU-Eval uses Apache-2.0, one of the two licenses that the project lists in `build.sbt` (Apache 2.0 and Anti-996 1.0).

Copyright and author attribution:

- Copyright (c) 2020 - 2024 Huazhong University of Sci. & Tech. <m201772520@hust.edu.cn>
- Copyright (c) 2020 - 2024 Wuhan University of Technology <295054118@whut.edu.cn>

Original license texts: [Rift2Core-Anti-996.txt](LICENSES/license-texts/Rift2Core-Anti-996.txt), [Rift2Core-Apache-2.0.txt](LICENSES/license-texts/Rift2Core-Apache-2.0.txt).

Test and patch directories: `cpus/rift2core/arbiter/harness`, `cpus/rift2core/bim/harness`, `cpus/rift2core/btb/harness`, `cpus/rift2core/commit/harness`, `cpus/rift2core/csr_score_board/harness`, `cpus/rift2core/decode16/harness`, `cpus/rift2core/environment`, `cpus/rift2core/execute/harness`, `cpus/rift2core/fake_vec_pre_issue/harness`, `cpus/rift2core/fake_vec_pre_rename/harness`, `cpus/rift2core/if2/harness`, `cpus/rift2core/if3/harness`, `cpus/rift2core/if4/harness`, `cpus/rift2core/io_lsu/harness`, `cpus/rift2core/max_period_fibonacci_lfsr/harness`, `cpus/rift2core/miss_unit/harness`, `cpus/rift2core/mul_div/harness`, `cpus/rift2core/multi_port_fifo/harness`, `cpus/rift2core/probe_unit/harness`, `cpus/rift2core/queue/harness`, `cpus/rift2core/ras/harness`, `cpus/rift2core/re_direct/harness`, `cpus/rift2core/rename/harness`, `cpus/rift2core/srt4_divider/harness`, `cpus/rift2core/store_queue/harness`, `cpus/rift2core/tag_ram/harness`, `cpus/rift2core/tlb/patches`, `cpus/rift2core/write_back_unit/harness`, `cpus/rift2core/xarbiter/harness`, `cpus/rift2core/zip_port/harness`.

<a id="jhauser-us-arithmetic-hardfloat-1-doc-hardfloat-verilog-html"></a>
### jhauser.us/arithmetic/HardFloat-1/doc/HardFloat-Verilog.html

Project: http://jhauser.us/arithmetic/HardFloat-1/doc/HardFloat-Verilog.html.

Archived copy: https://web.archive.org/web/20190821012312id_/http://jhauser.us/arithmetic/HardFloat-1/doc/HardFloat-Verilog.html (captured 2019-08-21).

License of the quoted files: BSD-3-Clause.

Copyright and author attribution:

- Copyright 2019 The Regents of the University of California. All rights reserved.

Original license texts: [HardFloat-Verilog-documentation-notice.txt](LICENSES/license-texts/HardFloat-Verilog-documentation-notice.txt).

<a id="lgpl-material"></a>
## LGPL material

The headers of the upstream files below grant the GNU Lesser General Public License, version 3.0
or (at your option) any later version (LGPL-3.0-or-later). Two problem statements quote them:

- [cpus/vexriscv/debug_plugin/SPEC.md](cpus/vexriscv/debug_plugin/SPEC.md) quotes lines 200–209 of `src/main/scala/vexriscv/TestsWorkspace.scala` from github.com/SpinalHDL/VexRiscv at revision `c4b2a55b22f46afb760446cd69f3ca7c36eef778` (source S0180, 516 bytes). The copyright line of that file reads: Copyright (c) Dolu, All rights reserved. The terms of its other parts are MIT (the other excerpts from github.com/SpinalHDL/VexRiscv) and Apache-2.0 (the text written by CPU-Eval). CPU-Eval last modified this file on 2026-11-25.
- [cpus/vexriscv/decoder_simple_plugin/SPEC.md](cpus/vexriscv/decoder_simple_plugin/SPEC.md) quotes lines 24–35 and 52–75 of `core/src/main/scala/spinal/core/MaskedLiteral.scala` from github.com/SpinalHDL/SpinalHDL at revision `95a5e6c65c54acfc4707c8fe6ef8b5d297cfcbde` (source S0688, 1350 bytes). The copyright line of that file reads: (c) Dolu, All rights reserved. The terms of its other parts are MIT (the other excerpts from github.com/SpinalHDL/VexRiscv) and Apache-2.0 (the text written by CPU-Eval). CPU-Eval last modified this file on 2026-11-25.

The VexRiscv `LICENSE` at revision `c4b2a55` is MIT, and the SpinalHDL `README` at revision `95a5e6c` states that its core is under LGPL3 and its lib and other parts are under MIT. For these two excerpts CPU-Eval follows the LGPL-3.0-or-later file headers.

Each of these `SPEC.md` files is distributed as a whole under LGPL-3.0-or-later, and its other
parts can also be used under their own terms given above. CPU-Eval modified the LGPL material:
it selected the line ranges and combined them with other excerpts and task instructions.
The quoted text is unchanged.

This material is distributed WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
for more details.

License texts: [GNU LGPL 3.0](LICENSES/license-texts/GNU-LGPL-3.0.txt) and [GNU GPL 3.0](LICENSES/license-texts/GNU-GPL-3.0.txt). Each of the two problem directories has a `NOTICE` file with this information;
keep it with every copy of that `SPEC.md` that you give to others.

<a id="commit-messages"></a>
## Commit messages

Some problem statements quote upstream commit messages, unchanged. Every commit listed below contains `LICENSE.SiFive`, a copy of the Apache License 2.0 ([SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt)). Section 1 of that license defines a Contribution to include communication sent to the Licensor through source code control systems, and Section 5 places each Contribution submitted for inclusion in the work under that license. CPU-Eval uses these commit messages under Apache-2.0.

### github.com/chipsalliance/rocket-chip

| Commit | Author | Problem |
| --- | --- | --- |
| `069858a20ce101310c49900af0da211838931e92` | Andrew Waterman | `cpus/boom/ptw` |
| `3546c8d133f9a0b0dc615e1cc401a89145224bb3` | Andrew Waterman | `cpus/boom/csr_file` |
| `3b8674dde75e8ef76137faccab2679bb8c1f5a62` | Andrew Waterman | `cpus/boom/csr_file` |
| `7b352b6e132ab0ecb1bbc8f0ff304291071e852c` | Andrew Waterman | `cpus/boom/csr_file` |
| `7f6b4c65ba73e5b4a5e40b4c82773fcbd95e402f` | Andrew Waterman | `cpus/boom/csr_file` |
| `e88774140cdc3bce4ecfa61a0dddb4a6c8cc9869` | Andrew Waterman | `cpus/boom/csr_file` |
| `0b2826546779ddbeff886c70310610b1753e25e3` | Henry Cook | `cpus/boom/bundle_bridge_nexus` |
| `12ac9077d90f4b3ae89172485488eddf50ad949b` | Henry Cook | `cpus/boom/bundle_bridge_nexus` |
| `928dce6d19c9e45f6160fd171ba866282295ce94` | Henry Cook | `cpus/boom/bundle_bridge_nexus` |
| `bf02d8a2974b48716285eda048ac37799b688c41` | Henry Cook | `cpus/boom/bundle_bridge_nexus` |
| `1db05c5c0bd145584d601f49ec4c70a382fcb931` | John Ingalls | `cpus/boom/ptw` |
| `630600d860a0ff0ec1e290931d301cc6f2b96fe0` | John Ingalls | `cpus/boom/ptw` |
| `d056461b387f410d0a785f66373153de47d642b2` | John Ingalls | `cpus/boom/ptw` |

### github.com/riscv-boom/riscv-boom

| Commit | Author | Problem |
| --- | --- | --- |
| `01eed18de7543d973f7d2b45a589caf786f02848` | Jerry Zhao | `cpus/boom/boom_writeback_unit` |
| `031d4c6477d57b1401059d99a7da52d29fd16e47` | Jerry Zhao | `cpus/boom/branch_killable_queue` |
| `1cc0d133a5e1435932cbd1120e09dbd7701d5707` | Jerry Zhao | `cpus/boom/branch_predictor` |
| `1e79ca360884de9a90bf49ce8ca46beeeefa9669` | Jerry Zhao | `cpus/boom/branch_predictor` |
| `26bc84b54fcefbdb098a02290c2de3d38abe8bfa` | Jerry Zhao | `cpus/boom/branch_killable_queue` |
| `2faafb73d823e21c2b446ece539a725f59857d02` | Jerry Zhao | `cpus/boom/boom_writeback_unit` |
| `87c0a0c8617d981549e3dcc274b8cc080c36c593` | Jerry Zhao | `cpus/boom/boom_writeback_unit` |
| `89a15f586bd1c96237e0f931dad68e5e90075155` | Jerry Zhao | `cpus/boom/branch_killable_queue` |
| `93f5556da61cc89879b8176d51e0a0615c075d4c` | Jerry Zhao | `cpus/boom/tage_table` |
| `a9182a7e9d2812679448f7e7c46882f218c5b88b` | Jerry Zhao | `cpus/boom/branch_predictor` |
| `b8477443d130405c31b86c835a4f07b0c35e86ac` | Jerry Zhao | `cpus/boom/branch_predictor` |
| `cd9d969a172abc733455087a3705369f9da76377` | Jerry Zhao | `cpus/boom/tage_table` |
| `d182b07e6db1b38d5585628f882fb04310ee8368` | Jerry Zhao | `cpus/boom/boom_writeback_unit` |
| `e1aa96f820242f5e0fc1808be87de4ec4848bda7` | Jerry Zhao | `cpus/boom/branch_predictor` |
| `f0d490ad91646facc0dd13a291f7f26a683e6ae5` | Jerry Zhao | `cpus/boom/btb_branch_predictor_bank` |

## Creative Commons Attribution material

### The RISC-V Instruction Set Manual Volume I: Unprivileged Architecture (source S0148)

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-isa-manual/blob/4f277ff8ea8c0fc9394dfccd1da0ace34b1aef68/src/riscv-unprivileged.adoc.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0148, S0150, S0502, S0503, S0504, S0505, S0506, S0507, S0509, S0510, S0511, S0512, S0513, S0514, S0515, S0516, S0517, S0518, S0519, S0520, S0521, S0522, S0523, S0524, S0525, S0526, S0527, S0528, S0529, S0530, S0531, S0532, S0534, S0535, S0536, S0539, S0540, S0542, S0543, S0686.

### The RISC-V Instruction Set Manual: Volume II: Privileged Architecture

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, Rimas Avižienis, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-isa-manual/blob/4f277ff8ea8c0fc9394dfccd1da0ace34b1aef68/src/riscv-privileged.adoc.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0149, S0508, S0533, S0537, S0538, S0541.

### The RISC-V Instruction Set Manual

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.
- ©2010-2017 Andrew Waterman, Yunsup Lee, Rimas Avižienis, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-isa-manual/blob/fa794b679cb50da3b68c49ffd5ae7559f4fa1422/src/riscv-spec.adoc.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0544, S0545, S0546, S0547, S0548, S0549, S0550, S0552, S0553, S0650, S0651, S0652, S0653, S0654, S0655, S0656, S0657, S0658, S0659, S0660, S0661, S0662, S0663, S0664, S0665, S0666, S0667, S0668, S0669, S0670, S0676, S0701, S0702, S0703, S0704, S0705.

### The RISC-V Instruction Set Manual Volume I: Unprivileged Architecture (source S0554)

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-isa-manual/blob/fd3f34b7c56e08f83ea842d69bc66c1c054c9c45/src/riscv-unprivileged.adoc.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0554, S0555.

### The RISC-V Instruction Set Manual, Volume II: Privileged Architecture (source S0151)

Creators: Andrew Waterman; Krste Asanović; John Hauser.

- ©2010-2017 Andrew Waterman, Yunsup Lee, Rimas Avižienis, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-isa-manual/blob/f8614dc09c6ce1667cc70be7bdeda6cd7382e5f1/src/riscv-privileged.tex.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0151.

### The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA (source S0320)

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/openhwgroup/cv-hpdcache/blob/f404e7ebbda8baa4af3729535f520a6b12a06d03/docs/source/amo.rst, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L13, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L23, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L51.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate source extracts, reformats, simplifies or adapts the referenced manual passages. CPU-Eval selects the recorded immediate-source ranges without changing their text. Copyright names above are the notices displayed by the identified edition, not inferred authorship of later additions.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0320.

### The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA (source S0321)

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/openhwgroup/cv-hpdcache/blob/f404e7ebbda8baa4af3729535f520a6b12a06d03/docs/source/architecture.rst, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L13, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L23, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L51.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate source extracts, reformats, simplifies or adapts the referenced manual passages. CPU-Eval selects the recorded immediate-source ranges without changing their text. Copyright names above are the notices displayed by the identified edition, not inferred authorship of later additions.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0321.

### The RISC-V Instruction Set Manual, Volume II: Privileged Architecture (source S0399)

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, Rimas Avižienis, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/openhwgroup/cva6/blob/6348e9e684678f83b40d0520028513d06b36e7b2/core/commit_stage.sv, https://github.com/riscv/riscv-isa-manual/blob/eb86a900f418a5436b8e31abc0563be3cb402a16/src/riscv-privileged.tex#L9, https://github.com/riscv/riscv-isa-manual/blob/eb86a900f418a5436b8e31abc0563be3cb402a16/src/riscv-privileged.tex#L25, https://github.com/riscv/riscv-isa-manual/blob/eb86a900f418a5436b8e31abc0563be3cb402a16/src/riscv-privileged.tex#L46.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate source extracts, reformats, simplifies or adapts the referenced manual passages. CPU-Eval selects the recorded immediate-source ranges without changing their text. Copyright names above are the notices displayed by the identified edition, not inferred authorship of later additions.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0399.

### Zc* specification, incorporated into The RISC-V Instruction Set Manual

Manual editors: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/openhwgroup/cva6/blob/6348e9e684678f83b40d0520028513d06b36e7b2/docs/01_cva6_user/RISCV_Instructions_RV32ZCb.rst, https://github.com/riscv/riscv-isa-manual/blob/4f277ff8ea8c0fc9394dfccd1da0ace34b1aef68/src/riscv-unprivileged.adoc#L1, https://github.com/riscv/riscv-isa-manual/blob/4f277ff8ea8c0fc9394dfccd1da0ace34b1aef68/src/riscv-unprivileged.adoc#L147.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate source extracts, reformats, simplifies or adapts the referenced manual passages. CPU-Eval selects the recorded immediate-source ranges without changing their text. Copyright names above are the notices displayed by the identified edition, not inferred authorship of later additions.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0460.

### The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA; Zicsr v2.0

Creators: Andrew Waterman; Krste Asanović.

- ©2010-2017 Andrew Waterman, Yunsup Lee, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/openhwgroup/cva6/blob/6348e9e684678f83b40d0520028513d06b36e7b2/docs/01_cva6_user/RISCV_Instructions_RVZicsr.rst, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L13, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L23, https://github.com/riscv/riscv-isa-manual/blob/66bed2470f68520fadc4bf86c6c000d817fe73f2/src/riscv-spec.tex#L51.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate source extracts, reformats, simplifies or adapts the referenced manual passages. CPU-Eval selects the recorded immediate-source ranges without changing their text. Copyright names above are the notices displayed by the identified edition, not inferred authorship of later additions.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0461.

### The RISC-V Instruction Set Manual, Volume II: Privileged Architecture (source S0469)

Creators: Andrew Waterman; Krste Asanović; John Hauser.

- ©2010-2017 Andrew Waterman, Yunsup Lee, Rimas Avižienis, David Patterson, Krste Asanović.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/openhwgroup/cva6/blob/6348e9e684678f83b40d0520028513d06b36e7b2/docs/csr-from-ip-xact/cv32a60x/cv32a60mx_csr.md, https://github.com/riscv/riscv-isa-manual/blob/98964261c931d51884f733664b22efe43de93033/src/riscv-privileged.tex#L13, https://github.com/riscv/riscv-isa-manual/blob/98964261c931d51884f733664b22efe43de93033/src/riscv-privileged.tex#L26, https://github.com/riscv/riscv-isa-manual/blob/98964261c931d51884f733664b22efe43de93033/src/riscv-privileged.tex#L49.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate source extracts, reformats, simplifies or adapts the referenced manual passages. CPU-Eval selects the recorded immediate-source ranges without changing their text. Copyright names above are the notices displayed by the identified edition, not inferred authorship of later additions.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0469.

### RISC-V External Debug Support, Version 0.13

Creators: Tim Newsome.

- No copyright notice is supplied in the recorded source notices, title page, preface, or license text.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-debug-spec/blob/b13891ce9848b4a673e05bcab50359495f830692/core_debug.tex, https://github.com/riscv/riscv-debug-spec/blob/b13891ce9848b4a673e05bcab50359495f830692/trigger.tex, https://github.com/riscv/riscv-debug-spec/blob/b13891ce9848b4a673e05bcab50359495f830692/xml/core_registers.xml, https://github.com/riscv/riscv-debug-spec/blob/b13891ce9848b4a673e05bcab50359495f830692/xml/hwbp_registers.xml.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0143, S0144, S0145, S0146.

### RISC-V External Debug Support, Version 0.13; identical text in the licensed 2017 revision

Creators: Tim Newsome.

- No copyright notice is supplied in the recorded source notices, title page, or linked CC BY license text.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/riscv/riscv-debug-spec/blob/ceb5d66a7e0cb5cea0511b50849ee4acc7baaa01/core_registers.xml, https://github.com/riscv/riscv-debug-spec/blob/1e5c068f1ec92136f6c6900498440acfb88042c2/core_registers.xml.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

The original revision has no LICENSE file. The recorded excerpt is identical in revision 1e5c068f1ec92136f6c6900498440acfb88042c2, which supplies the CC BY 4.0 license.

Sources: S0147.

### RISC-V External Debug Support, Version 0.13.2, incorporated into the VeeR EL2 manual

Creators: Tim Newsome; Megan Wachs.

- No copyright notice is supplied for the underlying Debug specification in its title page or license text.
- Copyright © 2022 CHIPS Alliance.

License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

Original material: https://github.com/chipsalliance/cores-veer-el2/blob/aefefae20b77fa61ba306bff36a72f42ae4cc028/docs/source/debugging.md, https://github.com/riscv/riscv-debug-spec/blob/4e0bb0fc2d843473db2356623792c6b7603b94d4/riscv-debug-release.pdf.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/4.0/legalcode#s5).

The immediate VeeR source selects and reformats the RISC-V Debug 0.13.2 specification passages. CPU-Eval selects the recorded VeeR ranges without changing their text.

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged unless its source record explicitly specifies line-ending conversion.

Sources: S0262.

### HellaCache

Creators: Wei Song.

- © (2017) Wei Song
- © (2016-2017) SiFive, Inc
- © (2012-2014, 2016) The Regents of the University of California (Regents)

License: [Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/).

Original material: https://github.com/cnrv/rocket-chip-read/blob/7701f1d2f882c1674813a0c8f697208a3fa339df/rocket/HellaCache.md, https://github.com/cnrv/rocket-chip-read/blob/d8e109d5a774cf85e717f36035386e56eacd4a32/rocket/HellaCache.md.

Disclaimer: [the license's disclaimer](https://creativecommons.org/licenses/by/3.0/legalcode).

CPU-Eval selected source ranges and added surrounding instructions. The selected text is unchanged.

Revision `7701f1d` displays CC BY-NC-SA 4.0. The quoted lines 65–70 and 72 are identical in revision `d8e109d`, which displays CC BY 3.0; CPU-Eval uses these lines under CC BY 3.0.

Sources: S0079.

## Files derived from upstream material

The following test files contain upstream material. Each entry says what was copied or adapted
and which terms apply.

### cpus/veer_el2/rvdff_fpga/test/observe_storage.sv

[cpus/veer_el2/rvdff_fpga/test/observe_storage.sv](cpus/veer_el2/rvdff_fpga/test/observe_storage.sv).

CPU-Eval-authored flop storage observations. Port names and widths derive from design/lib/beh_lib.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/cva6/hpdcache_sram_1rw/harness/hpdcache_sram_1rw_conflict.S

[cpus/cva6/hpdcache_sram_1rw/harness/hpdcache_sram_1rw_conflict.S](cpus/cva6/hpdcache_sram_1rw/harness/hpdcache_sram_1rw_conflict.S).

The file contains RISC-V architectural-test boilerplate that matches the upstream file below. The exact file it was created from is not identified.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

Matching upstream file: `riscv-test-suite/rv32i_m/I/src/lb-align-01.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

### cpus/cva6/sram_cache/harness/icache_sram_reuse.S

[cpus/cva6/sram_cache/harness/icache_sram_reuse.S](cpus/cva6/sram_cache/harness/icache_sram_reuse.S).

The file contains RISC-V architectural-test boilerplate that matches the upstream file below. The exact file it was created from is not identified.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

Matching upstream file: `riscv-test-suite/rv32i_m/I/src/lb-align-01.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

### cpus/cva6/commit_stage/harness/commit_stage_ecall.S

[cpus/cva6/commit_stage/harness/commit_stage_ecall.S](cpus/cva6/commit_stage/harness/commit_stage_ecall.S).

CPU-Eval adapted the matching upstream file below. The adapted architectural-test material keeps BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

Matching upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

### cpus/cva6/commit_stage/harness/commit_stage_csr.S

[cpus/cva6/commit_stage/harness/commit_stage_csr.S](cpus/cva6/commit_stage/harness/commit_stage_csr.S).

RISC-V Architectural Tests boilerplate matches the listed reference. Its exact creation source is unidentified. The successful and faulting CSR instruction sequences are CPU-Eval-authored.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

Matching upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

### cpus/cva6/popcount/harness/popcount_weight_range.S

[cpus/cva6/popcount/harness/popcount_weight_range.S](cpus/cva6/popcount/harness/popcount_weight_range.S).

CPU-Eval-authored instruction sequence at lines 10–17; retained architectural-test boilerplate and expanded inputs have the separate upstream terms below.

Original terms: [LICENSE](LICENSE), [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt), [RISC-V-ISA-Sim-LICENSE.txt](LICENSES/license-texts/RISC-V-ISA-Sim-LICENSE.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

Upstream: github.com/openhwgroup/core-v-verif, revision `b3149ab0da3ac8bf2179e24595a4b7a860b668ff`.

Upstream: github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Upstream material: `riscv-test-suite/rv32i_m/B/src/cpop-01.S` at revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Retained trap and GPR-save boilerplate; original RISC-V International copyright (2020), SPDX BSD-3-Clause.

Upstream material: `riscv-test-suite/env/arch_test.h` at revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Expanded header; RISC-V International copyright (2020–2023), SPDX BSD-3-Clause.

Upstream material: `riscv-test-suite/env/test_macros.h` at revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Expanded definitions; no individual SPDX notice. Repository README Licensing states code is BSD-3-Clause or Apache-2.0; both full texts are retained without assigning this unmarked file a more specific license.

Upstream material: `riscv-test-suite/env/encoding.h` at revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Expanded encoding header; Regents copyright (2012–2015), source and binary redistribution terms retained.

Upstream material: `vendor/riscv/riscv-isa-sim/arch_test_target/spike/model_test.h` at revision `b3149ab0da3ac8bf2179e24595a4b7a860b668ff`.

Expanded model macros or linker input; vendor/riscv/riscv-isa-sim/LICENSE, Regents copyright (2010–2017).

Upstream material: `vendor/riscv/riscv-isa-sim/arch_test_target/spike/link.ld` at revision `b3149ab0da3ac8bf2179e24595a4b7a860b668ff`.

Expanded model macros or linker input; vendor/riscv/riscv-isa-sim/LICENSE, Regents copyright (2010–2017).

### cpus/rift2core/queue/harness/chisel_5.1.0_Decoupled.scala

[cpus/rift2core/queue/harness/chisel_5.1.0_Decoupled.scala](cpus/rift2core/queue/harness/chisel_5.1.0_Decoupled.scala).

Chisel 5.1.0 source template used by the Queue evaluator, with the body of class Queue removed; the original SPDX notice is retained.

Original terms: [Chisel-Apache-2.0.txt](LICENSES/license-texts/Chisel-Apache-2.0.txt).

### cpus/veer_el2/dma_ctrl/test/dma_axi_probe.sv

[cpus/veer_el2/dma_ctrl/test/dma_axi_probe.sv](cpus/veer_el2/dma_ctrl/test/dma_axi_probe.sv).

CPU-Eval-authored port-level DMA transactions and assertions. Port declarations reproduce the interface of design/el2_dma_ctrl.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028; Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0. The upstream parameter generator and support libraries are compiled from the recipient checkout and retain their original terms.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/pic_ctrl/test/pic_port_probe.sv

[cpus/veer_el2/pic_ctrl/test/pic_port_probe.sv](cpus/veer_el2/pic_ctrl/test/pic_port_probe.sv).

CPU-Eval-authored port-level register-mask and wakeup checks. Port names, widths and parameter interface derive from design/el2_pic_ctrl.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028; Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0. Upstream support modules and configuration are compiled from the pinned recipient checkout.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/dbg/test/dbg_port_probe.sv

[cpus/veer_el2/dbg/test/dbg_port_probe.sv](cpus/veer_el2/dbg/test/dbg_port_probe.sv).

CPU-Eval-authored finite reset, DMI abstract command and AXI checks. Port names, widths and parameter interface derive from design/dbg/el2_dbg.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028; Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0. Upstream support modules and configuration are compiled from the pinned recipient checkout.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/boom/fetch_target_queue/test/FTQPublicContractTest.scala

[cpus/boom/fetch_target_queue/test/FTQPublicContractTest.scala](cpus/boom/fetch_target_queue/test/FTQPublicContractTest.scala).

CPU-Eval-authored stimulus and assertions. The FTQ interface declarations adapt src/main/scala/ifu/fetch-target-queue.scala at efe2b35cc2224edf3a417381d437cfdcb37e02a8 by binding test-fixture widths; Copyright (c) 2015 - 2019, The Regents of the University of California (Regents). BSD-3-Clause and Apache-2.0 upstream terms remain applicable to that adapted material.

The header copied from BOOM refers to `LICENSE` and `LICENSE.SiFive`; in this repository they are [BOOM-BSD-3-Clause-2012-2020.txt](LICENSES/license-texts/BOOM-BSD-3-Clause-2012-2020.txt) and [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

Original terms: [BOOM-BSD-3-Clause-2012-2020.txt](LICENSES/license-texts/BOOM-BSD-3-Clause-2012-2020.txt), [SiFive-Apache-2.0.txt](LICENSES/license-texts/SiFive-Apache-2.0.txt).

Upstream: github.com/riscv-boom/riscv-boom, revision `efe2b35cc2224edf3a417381d437cfdcb37e02a8`.

### cpus/cva6/issue_read_operands/harness/branch_operands.S

[cpus/cva6/issue_read_operands/harness/branch_operands.S](cpus/cva6/issue_read_operands/harness/branch_operands.S).

The architectural-test boilerplate was retained from the distributed ID transport test. Its matching upstream boilerplate is listed separately. The conditional branches and data values are CPU-Eval authored.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

Matching upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

### cpus/veer_el2/dec_gpr_ctl/test/gpr_port_probe.sv

[cpus/veer_el2/dec_gpr_ctl/test/gpr_port_probe.sv](cpus/veer_el2/dec_gpr_ctl/test/gpr_port_probe.sv).

CPU-Eval-authored GPR port observations. Port names and widths derive from design/dec/el2_dec_gpr_ctl.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/dec_trigger/test/dec_trigger_ports.sv

[cpus/veer_el2/dec_trigger/test/dec_trigger_ports.sv](cpus/veer_el2/dec_trigger/test/dec_trigger_ports.sv).

CPU-Eval-authored decode-trigger port observations. Port names and widths derive from design/dec/el2_dec_trigger.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/dec_tlu_ctl/test/tlu_csr_probe.sv

[cpus/veer_el2/dec_tlu_ctl/test/tlu_csr_probe.sv](cpus/veer_el2/dec_tlu_ctl/test/tlu_csr_probe.sv).

CPU-Eval-authored TLU port observations. Port names and widths derive from design/dec/el2_dec_tlu_ctl.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/ifu/test/observe_fetch_redirect.sv

[cpus/veer_el2/ifu/test/observe_fetch_redirect.sv](cpus/veer_el2/ifu/test/observe_fetch_redirect.sv).

CPU-Eval-authored IFU redirect observations. Port names and widths derive from design/ifu/el2_ifu.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/ifu_ic_mem/harness/cache_bank_enable_monitor.sv

[cpus/veer_el2/ifu_ic_mem/harness/cache_bank_enable_monitor.sv](cpus/veer_el2/ifu_ic_mem/harness/cache_bank_enable_monitor.sv).

CPU-Eval-authored instruction-cache wrapper port observations. Port names and widths derive from design/ifu/el2_ifu_ic_mem.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/ifu_iccm_mem/test/iccm_correction_probe.sv

[cpus/veer_el2/ifu_iccm_mem/test/iccm_correction_probe.sv](cpus/veer_el2/ifu_iccm_mem/test/iccm_correction_probe.sv).

CPU-Eval-authored ICCM correction checks. Interface ports and fixed SRAM and ECC connections derive from design/ifu/el2_ifu_iccm_mem.sv, design/lib/el2_mem_if.sv, design/lib/mem_lib.sv, design/lib/beh_lib.sv and testbench/tb_top.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Apache-2.0. The upstream copyright notices are preserved in the corresponding source records.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/lsu_addrcheck/test/addrcheck_port_probe.sv

[cpus/veer_el2/lsu_addrcheck/test/addrcheck_port_probe.sv](cpus/veer_el2/lsu_addrcheck/test/addrcheck_port_probe.sv).

CPU-Eval-authored address-check PIC observations. Port names and widths derive from design/lsu/el2_lsu_addrcheck.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/veer/harness/reg_probe.cfg

[cpus/veer_el2/veer/harness/reg_probe.cfg](cpus/veer_el2/veer/harness/reg_probe.cfg).

Adapted from .github/scripts/openocd/sim-jtagdpi.cfg (Copyright lowRISC contributors) and .github/scripts/openocd/veer-el2-rst.cfg at the same pinned VeeR EL2 revision. CPU-Eval combines the adapter and target configuration and uses normal OpenOCD target examination.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Matching upstream file: `.github/scripts/openocd/sim-jtagdpi.cfg` in github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/rvdffppe/test/rvdffppe_ports.sv

[cpus/veer_el2/rvdffppe/test/rvdffppe_ports.sv](cpus/veer_el2/rvdffppe/test/rvdffppe_ports.sv).

CPU-Eval-authored FPGA prediction-packet register port observations. Port names and widths derive from design/lib/beh_lib.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/rvdffs/test/rvdffs_reset_probe.sv

[cpus/veer_el2/rvdffs/test/rvdffs_reset_probe.sv](cpus/veer_el2/rvdffs/test/rvdffs_reset_probe.sv).

CPU-Eval-authored enabled-register reset observations. The rvdffs ports derive from design/lib/beh_lib.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/rvdffsc_fpga/test/clock_gate_probe.sv

[cpus/veer_el2/rvdffsc_fpga/test/clock_gate_probe.sv](cpus/veer_el2/rvdffsc_fpga/test/clock_gate_probe.sv).

CPU-Eval-authored DMA clock-enable observations. Port names and widths derive from design/lib/beh_lib.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028, Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/veer_el2/rvecc_decode/test/cache_tag_probe.sv

[cpus/veer_el2/rvecc_decode/test/cache_tag_probe.sv](cpus/veer_el2/rvecc_decode/test/cache_tag_probe.sv).

CPU-Eval-authored finite cache tag port checks. The target interface derives from design/lib/beh_lib.sv at aefefae20b77fa61ba306bff36a72f42ae4cc028; Copyright 2020 Western Digital Corporation or its affiliates, Apache-2.0.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

### cpus/rift2core/mmu/tests/sv39-megapage/images/sv39_megapage_offset

[cpus/rift2core/mmu/tests/sv39-megapage/images/sv39_megapage_offset](cpus/rift2core/mmu/tests/sv39-megapage/images/sv39_megapage_offset).

Distributed ELF built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/mmu/tests/sv39-megapage/images/sv39_megapage_offset.verilog

[cpus/rift2core/mmu/tests/sv39-megapage/images/sv39_megapage_offset.verilog](cpus/rift2core/mmu/tests/sv39-megapage/images/sv39_megapage_offset.verilog).

Distributed memory initialization file derived from the CPU-Eval test ELF.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/cva6/branch_unit/harness/return_target_mismatch.S

[cpus/cva6/branch_unit/harness/return_target_mismatch.S](cpus/cva6/branch_unit/harness/return_target_mismatch.S).

CPU-Eval-authored return-target test under Apache-2.0 using RISC-V architectural-test signature and trap boilerplate under BSD-3-Clause.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/ariane/ariane_cvxif_add.S

[cpus/cva6/ariane/ariane_cvxif_add.S](cpus/cva6/ariane/ariane_cvxif_add.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/bht/harness/bht_cycles.S

[cpus/cva6/bht/harness/bht_cycles.S](cpus/cva6/bht/harness/bht_cycles.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/cva6_hpdcache_subsystem_axi_arbiter/harness/uncached_read_id.S

[cpus/cva6/cva6_hpdcache_subsystem_axi_arbiter/harness/uncached_read_id.S](cpus/cva6/cva6_hpdcache_subsystem_axi_arbiter/harness/uncached_read_id.S).

CPU-Eval-authored uncached-read test under Apache-2.0 using RISC-V architectural-test signature and trap boilerplate under BSD-3-Clause.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/cvxif_compressed_if_driver/harness/rejected_compressed.S

[cpus/cva6/cvxif_compressed_if_driver/harness/rejected_compressed.S](cpus/cva6/cvxif_compressed_if_driver/harness/rejected_compressed.S).

CPU-Eval-authored compressed-rejection test under Apache-2.0 using RISC-V architectural-test signature and trap boilerplate under BSD-3-Clause.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/cvxif_fu/tests/cvxif_fu_rejection.S

[cpus/cva6/cvxif_fu/tests/cvxif_fu_rejection.S](cpus/cva6/cvxif_fu/tests/cvxif_fu_rejection.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/cvxif_issue_register_commit_if_driver/tests/commit_notifications.S

[cpus/cva6/cvxif_issue_register_commit_if_driver/tests/commit_notifications.S](cpus/cva6/cvxif_issue_register_commit_if_driver/tests/commit_notifications.S).

CPU-Eval-authored directed test reconstructed by applying the three copro_alu patches and tests/0001-add-commit-notifications.patch in the order recorded in TEST_RECIPE.json. Matching architectural-test boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0. The match identifies the boilerplate, and its exact creation source is unknown.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [riscv-arch-test-a5a49fc9f244-COPYING.BSD](LICENSES/license-texts/riscv-arch-test-a5a49fc9f244-COPYING.BSD).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_amo/harness/hpdcache_amo_cached_reload.S

[cpus/cva6/hpdcache_amo/harness/hpdcache_amo_cached_reload.S](cpus/cva6/hpdcache_amo/harness/hpdcache_amo_cached_reload.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_ctrl_pe/harness/hpdcache_ctrl_pe_store_reload.S

[cpus/cva6/hpdcache_ctrl_pe/harness/hpdcache_ctrl_pe_store_reload.S](cpus/cva6/hpdcache_ctrl_pe/harness/hpdcache_ctrl_pe_store_reload.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_mem_req_write_arbiter/harness/hpdcache_write_arbiter_writeback.S

[cpus/cva6/hpdcache_mem_req_write_arbiter/harness/hpdcache_write_arbiter_writeback.S](cpus/cva6/hpdcache_mem_req_write_arbiter/harness/hpdcache_write_arbiter_writeback.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_mem_to_axi_read/harness/hpdcache_axi_read.S

[cpus/cva6/hpdcache_mem_to_axi_read/harness/hpdcache_axi_read.S](cpus/cva6/hpdcache_mem_to_axi_read/harness/hpdcache_axi_read.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_mem_to_axi_write/harness/hpdcache_axi_write_atomic.S

[cpus/cva6/hpdcache_mem_to_axi_write/harness/hpdcache_axi_write_atomic.S](cpus/cva6/hpdcache_mem_to_axi_write/harness/hpdcache_axi_write_atomic.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_memctrl/harness/hpdcache_memctrl_cached_store.S

[cpus/cva6/hpdcache_memctrl/harness/hpdcache_memctrl_cached_store.S](cpus/cva6/hpdcache_memctrl/harness/hpdcache_memctrl_cached_store.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_miss_handler/harness/hpdcache_miss_refill.S

[cpus/cva6/hpdcache_miss_handler/harness/hpdcache_miss_refill.S](cpus/cva6/hpdcache_miss_handler/harness/hpdcache_miss_refill.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_regbank_wbyteenable_1rw/harness/hpdcache_regbank_mshr_word.S

[cpus/cva6/hpdcache_regbank_wbyteenable_1rw/harness/hpdcache_regbank_mshr_word.S](cpus/cva6/hpdcache_regbank_wbyteenable_1rw/harness/hpdcache_regbank_mshr_word.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_rtab/harness/hpdcache_rtab_conflict.S

[cpus/cva6/hpdcache_rtab/harness/hpdcache_rtab_conflict.S](cpus/cva6/hpdcache_rtab/harness/hpdcache_rtab_conflict.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_sram/harness/hpdcache_sram_repeated_hit.S

[cpus/cva6/hpdcache_sram/harness/hpdcache_sram_repeated_hit.S](cpus/cva6/hpdcache_sram/harness/hpdcache_sram_repeated_hit.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_victim_random/harness/hpdcache_victim_concurrent_misses.S

[cpus/cva6/hpdcache_victim_random/harness/hpdcache_victim_concurrent_misses.S](cpus/cva6/hpdcache_victim_random/harness/hpdcache_victim_concurrent_misses.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hpdcache_victim_sel/harness/hpdcache_victim_sel_concurrent_misses.S

[cpus/cva6/hpdcache_victim_sel/harness/hpdcache_victim_sel_concurrent_misses.S](cpus/cva6/hpdcache_victim_sel/harness/hpdcache_victim_sel_concurrent_misses.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/hwpf_stride/harness/hwpf_stride_store_effect.S

[cpus/cva6/hwpf_stride/harness/hwpf_stride_store_effect.S](cpus/cva6/hwpf_stride/harness/hwpf_stride_store_effect.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/instr_queue/harness/id_transport.S

[cpus/cva6/instr_queue/harness/id_transport.S](cpus/cva6/instr_queue/harness/id_transport.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/instr_scan/harness/instr_scan_cycles.S

[cpus/cva6/instr_scan/harness/instr_scan_cycles.S](cpus/cva6/instr_scan/harness/instr_scan_cycles.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/lfsr/harness/lfsr_icache_cycles.S

[cpus/cva6/lfsr/harness/lfsr_icache_cycles.S](cpus/cva6/lfsr/harness/lfsr_icache_cycles.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/ras/harness/ras_cycles.S

[cpus/cva6/ras/harness/ras_cycles.S](cpus/cva6/ras/harness/ras_cycles.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/raw_checker/harness/raw_checker_wrap.S

[cpus/cva6/raw_checker/harness/raw_checker_wrap.S](cpus/cva6/raw_checker/harness/raw_checker_wrap.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/serdiv/harness/serdiv_independent_sequence.S

[cpus/cva6/serdiv/harness/serdiv_independent_sequence.S](cpus/cva6/serdiv/harness/serdiv_independent_sequence.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0. The Apache-2.0 SPDX line at the top of the file covers only the CPU-Eval additions.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/serdiv/harness/serdiv_overflow.S

[cpus/cva6/serdiv/harness/serdiv_overflow.S](cpus/cva6/serdiv/harness/serdiv_overflow.S).

CPU-Eval-authored test with matching RISC-V architectural-test boilerplate. The exact creation source is not identified. Matching boilerplate retains BSD-3-Clause; CPU-Eval additions use Apache-2.0. The Apache-2.0 SPDX line at the top of the file covers only the CPU-Eval additions.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/store_buffer/harness/sw-align-01.S

[cpus/cva6/store_buffer/harness/sw-align-01.S](cpus/cva6/store_buffer/harness/sw-align-01.S).

CPU-Eval modified the fixed architectural test with tests/patches/0001-read-back-first-word-store.patch, as recorded in this problem's TEST_RECIPE.json. Original test material retains BSD-3-Clause.

Upstream file: `riscv-test-suite/rv32i_m/I/src/sw-align-01.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/ibex/alu/harness/alu_test.S

[cpus/ibex/alu/harness/alu_test.S](cpus/ibex/alu/harness/alu_test.S).

CPU-Eval adapted operand pairs from the Ibex-vendored RISC-V architectural tests rv32i_m/I/src/{add,sub,and,or,xor,sll,srl,sra,slt,sltu,addi,andi,ori,xori,slli,srli,srai,slti,sltiu}-01.S, as listed in the source comments. Upstream material retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `vendor/riscv-arch-tests/riscv-test-suite/rv32i_m/I/src/add-01.S` in github.com/lowRISC/ibex, revision `405c6d1d8220a18b2f9196141167a5875422dee4`.

Original terms: [riscv-arch-test-a5a49fc9f244-COPYING.BSD](LICENSES/license-texts/riscv-arch-test-a5a49fc9f244-COPYING.BSD).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/ibex/alu/harness/div_zero_test.S

[cpus/ibex/alu/harness/div_zero_test.S](cpus/ibex/alu/harness/div_zero_test.S).

CPU-Eval adapted operand pairs from Ibex-vendored rv32i_m/M/src/{div,divu,rem,remu}-01.S, as identified in the source comments. The original architectural-test material retains BSD-3-Clause.

Upstream file: `vendor/riscv-arch-tests/riscv-test-suite/rv32i_m/M/src/div-01.S` in github.com/lowRISC/ibex, revision `405c6d1d8220a18b2f9196141167a5875422dee4`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/ibex/ex_block/harness/div_zero_test.S

[cpus/ibex/ex_block/harness/div_zero_test.S](cpus/ibex/ex_block/harness/div_zero_test.S).

CPU-Eval adapted operand pairs from Ibex-vendored rv32i_m/M/src/{div,divu,rem,remu}-01.S, as identified in the source comments. The original architectural-test material retains BSD-3-Clause. The independently authored MULHSU case is covered by the CPU-Eval Apache-2.0 license.

Upstream file: `vendor/riscv-arch-tests/riscv-test-suite/rv32i_m/M/src/div-01.S` in github.com/lowRISC/ibex, revision `405c6d1d8220a18b2f9196141167a5875422dee4`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/ibex/multdiv_fast/harness/mulhsu_sign_test.S

[cpus/ibex/multdiv_fast/harness/mulhsu_sign_test.S](cpus/ibex/multdiv_fast/harness/mulhsu_sign_test.S).

CPU-Eval adapted the operand pair and expected result of test 7 from the Ibex-vendored riscv-tests mulhsu.S. Upstream material retains BSD-3-Clause; CPU-Eval additions use Apache-2.0.

Upstream file: `vendor/riscv-tests/isa/rv32um/mulhsu.S` in github.com/lowRISC/ibex, revision `405c6d1d8220a18b2f9196141167a5875422dee4`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt).

Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.

### cpus/veer_el2/lsu_bus_buffer/test/order_probe.sv

[cpus/veer_el2/lsu_bus_buffer/test/order_probe.sv](cpus/veer_el2/lsu_bus_buffer/test/order_probe.sv).

CPU-Eval-authored transactions and assertions; port declarations reproduce design/lsu/el2_lsu_bus_buffer.sv. CPU-Eval modified the original interface for a test fixture.

Upstream file: `design/lsu/el2_lsu_bus_buffer.sv` in github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Copyright 2020 Western Digital Corporation or its affiliates.

### cpus/cva6/compressed_decoder/harness/testlist_compressed_decoder.yaml

[cpus/cva6/compressed_decoder/harness/testlist_compressed_decoder.yaml](cpus/cva6/compressed_decoder/harness/testlist_compressed_decoder.yaml).

The retained Google LLC header and regression-list documentation identify Apache-2.0 material. The exact originating file is not identified.

Upstream: github.com/chipsalliance/riscv-dv, revision `da33551ab102c7530d7dadb803abf4c245ba08e0`.

Original terms: [LICENSE](LICENSE).

Copyright Google LLC

### cpus/rift2core/ras/harness/ras-cycle.S

[cpus/rift2core/ras/harness/ras-cycle.S](cpus/rift2core/ras/harness/ras-cycle.S).

CPU-Eval-authored RAS test built with riscv-tests scalar macros and the Rift2Core environment header recorded in TEST_RECIPE.json. Source, ELF and memory initialization files retain the Regents BSD conditions of their compiled upstream inputs.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.

### cpus/rift2core/ras/harness/ras-cycle

[cpus/rift2core/ras/harness/ras-cycle](cpus/rift2core/ras/harness/ras-cycle).

CPU-Eval-authored RAS test built with riscv-tests scalar macros and the Rift2Core environment header recorded in TEST_RECIPE.json. Source, ELF and memory initialization files retain the Regents BSD conditions of their compiled upstream inputs.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.

### cpus/rift2core/ras/harness/ras-depth-cycle

[cpus/rift2core/ras/harness/ras-depth-cycle](cpus/rift2core/ras/harness/ras-depth-cycle).

CPU-Eval-authored RAS test built with riscv-tests scalar macros and the Rift2Core environment header recorded in TEST_RECIPE.json. Source, ELF and memory initialization files retain the Regents BSD conditions of their compiled upstream inputs.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.

### cpus/rift2core/ras/harness/ras-cycle.verilog

[cpus/rift2core/ras/harness/ras-cycle.verilog](cpus/rift2core/ras/harness/ras-cycle.verilog).

CPU-Eval-authored RAS test built with riscv-tests scalar macros and the Rift2Core environment header recorded in TEST_RECIPE.json. Source, ELF and memory initialization files retain the Regents BSD conditions of their compiled upstream inputs.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.

### cpus/rift2core/ras/harness/ras-depth-cycle.verilog

[cpus/rift2core/ras/harness/ras-depth-cycle.verilog](cpus/rift2core/ras/harness/ras-depth-cycle.verilog).

CPU-Eval-authored RAS test built with riscv-tests scalar macros and the Rift2Core environment header recorded in TEST_RECIPE.json. Source, ELF and memory initialization files retain the Regents BSD conditions of their compiled upstream inputs.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

Copyright (c) 2012-2015, The Regents of the University of California (Regents). All Rights Reserved.

### cpus/rift2core/dividor/tests/word-zero/images/divuw_control

[cpus/rift2core/dividor/tests/word-zero/images/divuw_control](cpus/rift2core/dividor/tests/word-zero/images/divuw_control).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/divuw_zero.verilog

[cpus/rift2core/dividor/tests/word-zero/images/divuw_zero.verilog](cpus/rift2core/dividor/tests/word-zero/images/divuw_zero.verilog).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/divuw_zero

[cpus/rift2core/dividor/tests/word-zero/images/divuw_zero](cpus/rift2core/dividor/tests/word-zero/images/divuw_zero).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/remuw_control

[cpus/rift2core/dividor/tests/word-zero/images/remuw_control](cpus/rift2core/dividor/tests/word-zero/images/remuw_control).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/remuw_zero

[cpus/rift2core/dividor/tests/word-zero/images/remuw_zero](cpus/rift2core/dividor/tests/word-zero/images/remuw_zero).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/remuw_control.verilog

[cpus/rift2core/dividor/tests/word-zero/images/remuw_control.verilog](cpus/rift2core/dividor/tests/word-zero/images/remuw_control.verilog).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/remuw_zero.verilog

[cpus/rift2core/dividor/tests/word-zero/images/remuw_zero.verilog](cpus/rift2core/dividor/tests/word-zero/images/remuw_zero.verilog).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/dividor/tests/word-zero/images/divuw_control.verilog

[cpus/rift2core/dividor/tests/word-zero/images/divuw_control.verilog](cpus/rift2core/dividor/tests/word-zero/images/divuw_control.verilog).

Distributed ELF or memory initialization file built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json; the corresponding BSD notices accompany this binary distribution.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/cva6/csr_buffer/harness/flush_ports_tb.sv

[cpus/cva6/csr_buffer/harness/flush_ports_tb.sv](cpus/cva6/csr_buffer/harness/flush_ports_tb.sv).

CPU-Eval-authored flush stimulus and output checks use the functional-unit data fields declared in CVA6 core/cva6.sv. The interface follows Solderpad Hardware License 0.51. The test logic uses Apache-2.0.

Upstream file: `core/cva6.sv` in github.com/openhwgroup/cva6, revision `6348e9e684678f83b40d0520028513d06b36e7b2`.

Original terms: [CVA6-SHL-0.51.txt](LICENSES/license-texts/CVA6-SHL-0.51.txt).

Copyright 2018 ETH Zurich and University of Bologna.

### cpus/cva6/cva6_hpdcache_if_adapter/harness/distinct_loads.S

[cpus/cva6/cva6_hpdcache_if_adapter/harness/distinct_loads.S](cpus/cva6/cva6_hpdcache_if_adapter/harness/distinct_loads.S).

Adapted from CPU-Eval's hpdcache_victim_concurrent_misses.S. Its matching RISC-V architectural-test boilerplate retains BSD-3-Clause. CPU-Eval's sequence of distinct-address loads and other additions use Apache-2.0.

Upstream file: `riscv-test-suite/rv32i_m/privilege/src/ecall.S` in github.com/riscv-non-isa/riscv-arch-test, revision `a5a49fc9f244192649e57fe61b4513d9bc39b1e3`.

Original terms: [Ibex-directed-riscv-arch-tests.txt](LICENSES/license-texts/Ibex-directed-riscv-arch-tests.txt).

Copyright (c) 2020. RISC-V International. All rights reserved.

### cpus/cva6/cva6_hpdcache_if_adapter/harness/load_cancel_tb.sv

[cpus/cva6/cva6_hpdcache_if_adapter/harness/load_cancel_tb.sv](cpus/cva6/cva6_hpdcache_if_adapter/harness/load_cancel_tb.sv).

CPU-Eval-authored cancellation stimulus and assertions use Apache-2.0. The runner reconstructs the port and cache configuration declarations from the pinned CVA6 checkout during simulation. The CVA6 declarations retain Solderpad Hardware License 0.51 and the HPDcache subsystem and macros retain Solderpad Hardware License 2.1.

Upstream file: `core/cva6.sv` in github.com/openhwgroup/cva6, revision `6348e9e684678f83b40d0520028513d06b36e7b2`.

Original terms: [CVA6-SHL-0.51.txt](LICENSES/license-texts/CVA6-SHL-0.51.txt), [CV-HPDcache-SHL-2.1.txt](LICENSES/license-texts/CV-HPDcache-SHL-2.1.txt).

Copyright 2017-2019 ETH Zurich and University of Bologna.

Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)

### cpus/ibex/register_file_ff/evaluate_ports.sh

[cpus/ibex/register_file_ff/evaluate_ports.sh](cpus/ibex/register_file_ff/evaluate_ports.sh).

CPU-Eval-authored test logic uses Apache-2.0. It exercises the public register-file interface declared by the pinned Ibex source, which retains Apache-2.0.

Upstream file: `rtl/ibex_register_file_ff.sv` in github.com/lowRISC/ibex, revision `405c6d1d8220a18b2f9196141167a5875422dee4`.

Original terms: [LICENSE](LICENSE).

Copyright lowRISC contributors.

Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.

### cpus/ibex/register_file_ff/harness/register_file_ff_tb.sv

[cpus/ibex/register_file_ff/harness/register_file_ff_tb.sv](cpus/ibex/register_file_ff/harness/register_file_ff_tb.sv).

CPU-Eval-authored test logic uses Apache-2.0. It exercises the public register-file interface declared by the pinned Ibex source, which retains Apache-2.0.

Upstream file: `rtl/ibex_register_file_ff.sv` in github.com/lowRISC/ibex, revision `405c6d1d8220a18b2f9196141167a5875422dee4`.

Original terms: [LICENSE](LICENSE).

Copyright lowRISC contributors.

Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.

### cpus/rift2core/rename/tests/mstatus-load-order/images/rename_mstatus_load_order

[cpus/rift2core/rename/tests/mstatus-load-order/images/rename_mstatus_load_order](cpus/rift2core/rename/tests/mstatus-load-order/images/rename_mstatus_load_order).

Distributed test ELF built with the upstream headers in BUILD_INPUTS.json.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/rename/tests/mstatus-load-order/images/rename_mstatus_load_order.verilog

[cpus/rift2core/rename/tests/mstatus-load-order/images/rename_mstatus_load_order.verilog](cpus/rift2core/rename/tests/mstatus-load-order/images/rename_mstatus_load_order.verilog).

Distributed memory initialization file derived from the test ELF.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/tlb/tests/sv39-megapage-reuse/images/sv39_megapage_reuse

[cpus/rift2core/tlb/tests/sv39-megapage-reuse/images/sv39_megapage_reuse](cpus/rift2core/tlb/tests/sv39-megapage-reuse/images/sv39_megapage_reuse).

Distributed ELF built from the CPU-Eval test and upstream macros and environment recorded in BUILD_INPUTS.json.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/rift2core/tlb/tests/sv39-megapage-reuse/images/sv39_megapage_reuse.verilog

[cpus/rift2core/tlb/tests/sv39-megapage-reuse/images/sv39_megapage_reuse.verilog](cpus/rift2core/tlb/tests/sv39-megapage-reuse/images/sv39_megapage_reuse.verilog).

Distributed memory initialization file derived from the CPU-Eval test ELF.

Upstream: github.com/riscv-software-src/riscv-tests, revision `2ebecad997fa58cd9e5724340ba75aa4b59bd1d0`.

Original terms: [Berkeley-BSD-3-Clause-2012-2015.txt](LICENSES/license-texts/Berkeley-BSD-3-Clause-2012-2015.txt), [Rift-ALU-encoding-BSD-3-Clause.txt](LICENSES/license-texts/Rift-ALU-encoding-BSD-3-Clause.txt).

### cpus/veer_el2/dma_ctrl/test/dma_probe.cfg

[cpus/veer_el2/dma_ctrl/test/dma_probe.cfg](cpus/veer_el2/dma_ctrl/test/dma_probe.cfg).

CPU-Eval probe adapted from the adapter configuration at `.github/scripts/openocd/sim-jtagdpi.cfg` and RISC-V target configuration at `.github/scripts/openocd/veer-el2-rst.cfg`. Memory access and stimulus commands were changed for the specified CPU-Eval test.

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Copyright lowRISC contributors.

### cpus/veer_el2/rvdffs_fpga/test/dccm_probe.cfg

[cpus/veer_el2/rvdffs_fpga/test/dccm_probe.cfg](cpus/veer_el2/rvdffs_fpga/test/dccm_probe.cfg).

CPU-Eval probe adapted from the adapter configuration at `.github/scripts/openocd/sim-jtagdpi.cfg` and RISC-V target configuration at `.github/scripts/openocd/veer-el2-rst.cfg`. Memory access and stimulus commands were changed for the specified CPU-Eval test.

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Copyright lowRISC contributors.

### cpus/veer_el2/rvdffsc/test/stbuf_probe.cfg

[cpus/veer_el2/rvdffsc/test/stbuf_probe.cfg](cpus/veer_el2/rvdffsc/test/stbuf_probe.cfg).

CPU-Eval probe adapted from the adapter configuration at `.github/scripts/openocd/sim-jtagdpi.cfg` and RISC-V target configuration at `.github/scripts/openocd/veer-el2-rst.cfg`. Memory access and stimulus commands were changed for the specified CPU-Eval test.

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Copyright lowRISC contributors.

### cpus/veer_el2/veer_wrapper/test/dmi_probe.cfg

[cpus/veer_el2/veer_wrapper/test/dmi_probe.cfg](cpus/veer_el2/veer_wrapper/test/dmi_probe.cfg).

CPU-Eval probe adapted from the adapter configuration at `.github/scripts/openocd/sim-jtagdpi.cfg` and RISC-V target configuration at `.github/scripts/openocd/veer-el2-rst.cfg`. Memory access and stimulus commands were changed for the specified CPU-Eval test.

Upstream: github.com/chipsalliance/cores-veer-el2, revision `aefefae20b77fa61ba306bff36a72f42ae4cc028`.

Original terms: [VeeR-EL2-Apache-2.0.txt](LICENSES/license-texts/VeeR-EL2-Apache-2.0.txt).

Copyright lowRISC contributors.

### Patches

The terms column gives the license of the upstream files that each patch changes.
Lines that CPU-Eval adds use the terms in [CPU-Eval original material](#cpu-eval-original-material).

#### chipsalliance/cores-veer-el2

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [veer_el2/_shared/default-bitmanip-test.patch](cpus/veer_el2/_shared/patches/default-bitmanip-test.patch) | `aefefae20b77` | Apache-2.0 |
| [veer_el2/_shared/remove-replaceable-module-hierarchy.patch](cpus/veer_el2/_shared/patches/remove-replaceable-module-hierarchy.patch) | `aefefae20b77` | Apache-2.0 |
| [veer_el2/_shared/veer-el2-riscv-dv-verilator.patch](cpus/veer_el2/_shared/patches/veer-el2-riscv-dv-verilator.patch) | `aefefae20b77` | Apache-2.0 |
| [veer_el2/ifu_mem_ctl/ifu-fence-i-shared-memory.patch](cpus/veer_el2/ifu_mem_ctl/harness/ifu-fence-i-shared-memory.patch) | `aefefae20b77` | Apache-2.0 |
| [veer_el2/rvecc_decode/dccm-single-bit-injection.patch](cpus/veer_el2/rvecc_decode/test/dccm-single-bit-injection.patch) | `aefefae20b77` | Apache-2.0 |
| [veer_el2/rvecc_decode_64/icache-ecc-bit-sweep.patch](cpus/veer_el2/rvecc_decode_64/test/icache-ecc-bit-sweep.patch) | `aefefae20b77` | Apache-2.0 |
| [veer_el2/rvecc_decode_64/icache-ecc-detection-window.patch](cpus/veer_el2/rvecc_decode_64/test/icache-ecc-detection-window.patch) | `aefefae20b77` | Apache-2.0 |

#### chipsalliance/riscv-dv

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [veer_el2/_shared/riscv-dv-bitmanip-target.patch](cpus/veer_el2/_shared/patches/riscv-dv-bitmanip-target.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/_shared/riscv-dv-python-3.12.patch](cpus/veer_el2/_shared/patches/riscv-dv-python-3.12.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/dec_pmp_ctl/pmp-csr-coverage.patch](cpus/veer_el2/dec_pmp_ctl/test/pmp-csr-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/exu_alu_ctl/add-cpop-coverage.patch](cpus/veer_el2/exu_alu_ctl/test/add-cpop-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/exu_div_ctl/add-remu-coverage.patch](cpus/veer_el2/exu_div_ctl/test/add-remu-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/exu_div_new_4bit_fullshortq/add-remu-coverage.patch](cpus/veer_el2/exu_div_new_4bit_fullshortq/test/add-remu-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/exu_div_new_4bit_fullshortq/check-nontrivial-remu.patch](cpus/veer_el2/exu_div_new_4bit_fullshortq/test/check-nontrivial-remu.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/exu_div_new_4bit_fullshortq/observe-division-results.patch](cpus/veer_el2/exu_div_new_4bit_fullshortq/test/observe-division-results.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/exu_mul_ctl/add-zbc-coverage.patch](cpus/veer_el2/exu_mul_ctl/test/add-zbc-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/ifu_compress_ctl/compressed-control-flow-and-memory.patch](cpus/veer_el2/ifu_compress_ctl/patches/compressed-control-flow-and-memory.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/ifu_iccm_mem/iccm-read-coverage.patch](cpus/veer_el2/ifu_iccm_mem/patches/iccm-read-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu/lsu-store-load-coverage.patch](cpus/veer_el2/lsu/patches/lsu-store-load-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_addrcheck/load-store-coverage.patch](cpus/veer_el2/lsu_addrcheck/test/load-store-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_bus_buffer/read-data-coverage.patch](cpus/veer_el2/lsu_bus_buffer/test/read-data-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_bus_intf/read-data-coverage.patch](cpus/veer_el2/lsu_bus_intf/test/read-data-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_dccm_ctl/dccm-ctl-read-coverage.patch](cpus/veer_el2/lsu_dccm_ctl/patches/dccm-ctl-read-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_dccm_mem/dccm-read-coverage.patch](cpus/veer_el2/lsu_dccm_mem/patches/dccm-read-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_lsc_ctl/dccm-word-boundary.patch](cpus/veer_el2/lsu_lsc_ctl/test/dccm-word-boundary.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_lsc_ctl/signed-load-coverage.patch](cpus/veer_el2/lsu_lsc_ctl/test/signed-load-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/lsu_stbuf/stbuf-drain-coverage.patch](cpus/veer_el2/lsu_stbuf/test/stbuf-drain-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/pmp/pmp-fault-coverage.patch](cpus/veer_el2/pmp/test/pmp-fault-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/rvbradder/backward-branch-coverage.patch](cpus/veer_el2/rvbradder/test/backward-branch-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/rvecc_encode/dccm-ecc-coverage.patch](cpus/veer_el2/rvecc_encode/test/dccm-ecc-coverage.patch) | `da33551ab102` | Apache-2.0 |
| [veer_el2/rvlsadder/effective-address-coverage.patch](cpus/veer_el2/rvlsadder/test/effective-address-coverage.patch) | `da33551ab102` | Apache-2.0 |

#### chipsalliance/rocket-chip

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0009-use-local-chisel-in-rocket-chip.patch](cpus/boom/_shared/patches/0009-use-local-chisel-in-rocket-chip.patch) | `114325b27cfe` | BSD-3-Clause; Apache-2.0 |
| [rift2core/environment/rift2core-chisel5-compatibility.patch](cpus/rift2core/environment/rift2core-chisel5-compatibility.patch) | `aa183271e978` | BSD-3-Clause; Apache-2.0 |

#### lowRISC/ibex

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [ibex/_shared/if-pmp-observation.patch](cpus/ibex/_shared/if-pmp-observation.patch) | `405c6d1d8220` | Apache-2.0 |
| [ibex/cs_registers/0001-remove-private-pmp-fcov-reference.patch](cpus/ibex/cs_registers/test-patches/0001-remove-private-pmp-fcov-reference.patch) | `405c6d1d8220` | Apache-2.0 |

#### openhwgroup/core-v-verif

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [cva6/copro_alu/0001-model-example-compressed-cvxif.patch](cpus/cva6/copro_alu/environment/0001-model-example-compressed-cvxif.patch) | `b3149ab0da3a` | Apache-2.0 WITH SHL-2.0 |
| [cva6/copro_alu/0002-model-example-r4-cvxif.patch](cpus/cva6/copro_alu/environment/0002-model-example-r4-cvxif.patch) | `b3149ab0da3a` | Apache-2.0 WITH SHL-2.0 |

#### openhwgroup/cv-hpdcache

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [cva6/hpdcache_decoder/route_data_bits_through_decoder.patch](cpus/cva6/hpdcache_decoder/test-patches/route_data_bits_through_decoder.patch) | `f404e7ebbda8` | Apache-2.0 WITH SHL-2.1 |
| [cva6/hpdcache_fxarb/route_data_bits_through_fxarb.patch](cpus/cva6/hpdcache_fxarb/test-patches/route_data_bits_through_fxarb.patch) | `f404e7ebbda8` | Apache-2.0 WITH SHL-2.1 |
| [cva6/hwpf_stride/fix_stride_snoop_line.patch](cpus/cva6/hwpf_stride/test-patches/fix_stride_snoop_line.patch) | `f404e7ebbda8` | Apache-2.0 WITH SHL-2.1 |
| [cva6/hwpf_stride/forward_stride_request_tag.patch](cpus/cva6/hwpf_stride/test-patches/forward_stride_request_tag.patch) | `f404e7ebbda8` | Apache-2.0 WITH SHL-2.1 |

#### openhwgroup/cva6

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [cva6/copro_alu/0000-adapt-cvxif-add-nop-to-arch-test.patch](cpus/cva6/copro_alu/tests/0000-adapt-cvxif-add-nop-to-arch-test.patch) | `6348e9e68467` | Apache-2.0 WITH SHL-2.0 |
| [cva6/harness/0001-log-dram-writes.patch](cpus/cva6/harness/0001-log-dram-writes.patch) | `6348e9e68467` | SHL-0.51 |
| [cva6/hwpf_stride/enable_hwpf_stride.patch](cpus/cva6/hwpf_stride/test-patches/enable_hwpf_stride.patch) | `6348e9e68467` | Apache-2.0 WITH SHL-2.1; SHL-0.51 |
| [cva6/hwpf_stride_arb/activate_two_stride_engines.patch](cpus/cva6/hwpf_stride_arb/test-patches/activate_two_stride_engines.patch) | `6348e9e68467` | SHL-0.51 |
| [cva6/lsu_bypass/force_fifo_residency.patch](cpus/cva6/lsu_bypass/test-patches/force_fifo_residency.patch) | `6348e9e68467` | SHL-0.51 |
| [cva6/pmp/adapt_custom_runtime_to_arch_linker.patch](cpus/cva6/pmp/test-patches/adapt_custom_runtime_to_arch_linker.patch) | `6348e9e68467` | Apache-2.0; SHL-0.51; BSD-3-Clause |

#### riscv-boom/riscv-boom

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0005-add-boom-memory-trace-config.patch](cpus/boom/_shared/patches/0005-add-boom-memory-trace-config.patch) | `efe2b35cc222` | BSD-3-Clause; Apache-2.0 |
| [boom/btb_branch_predictor_bank/0001-flush-jal-correction-mask.patch](cpus/boom/btb_branch_predictor_bank/patches/0001-flush-jal-correction-mask.patch) | `efe2b35cc222` | BSD-3-Clause; Apache-2.0 |
| [boom/nbdtlb/0001-discard-invalidated-refills.patch](cpus/boom/nbdtlb/patches/0001-discard-invalidated-refills.patch) | `efe2b35cc222` | BSD-3-Clause; Apache-2.0 |
| [boom/null_local_branch_predictor_bank/0002-select-null-local-provider.patch](cpus/boom/null_local_branch_predictor_bank/patches/0002-select-null-local-provider.patch) | `efe2b35cc222` | BSD-3-Clause; Apache-2.0 |
| [boom/tage_table/0002-preserve-masked-training-counters.patch](cpus/boom/tage_table/patches/0002-preserve-masked-training-counters.patch) | `efe2b35cc222` | BSD-3-Clause; Apache-2.0 |

#### riscv-non-isa/riscv-arch-test

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [cva6/ariane_regfile/0001-observe-delayed-register-read.patch](cpus/cva6/ariane_regfile/harness/0001-observe-delayed-register-read.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/compressed_decoder/cebreak-normalize-mtvec.patch](cpus/cva6/compressed_decoder/harness/cebreak-normalize-mtvec.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/compressed_instr_decoder/0001-add-compressed-cvxif-table-test.patch](cpus/cva6/compressed_instr_decoder/tests/0001-add-compressed-cvxif-table-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/controller/0001-add-controller-tests.patch](cpus/cva6/controller/tests/0001-add-controller-tests.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/copro_alu/0000-adapt-cvxif-add-nop-to-arch-test.patch](cpus/cva6/copro_alu/tests/0000-adapt-cvxif-add-nop-to-arch-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/copro_alu/0001-expand-custom3-operations.patch](cpus/cva6/copro_alu/tests/0001-expand-custom3-operations.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/copro_alu/0002-add-r4-operations.patch](cpus/cva6/copro_alu/tests/0002-add-r4-operations.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/csr_buffer/0001-add-csr-buffer-sequence.patch](cpus/cva6/csr_buffer/tests/0001-add-csr-buffer-sequence.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/csr_regfile/0001-add-csr-regfile-sequence.patch](cpus/cva6/csr_regfile/tests/0001-add-csr-regfile-sequence.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/csr_regfile/0005-add-illegal-csr-test.patch](cpus/cva6/csr_regfile/tests/0005-add-illegal-csr-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/csr_regfile/0006-add-ecall-test.patch](cpus/cva6/csr_regfile/tests/0006-add-ecall-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/csr_regfile/0007-add-timer-interrupt-test.patch](cpus/cva6/csr_regfile/tests/0007-add-timer-interrupt-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cva6/0001-add-cvxif-add-test.patch](cpus/cva6/cva6/tests/0001-add-cvxif-add-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cva6/0002-add-csr-sequence.patch](cpus/cva6/cva6/tests/0002-add-csr-sequence.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cva6/0006-add-illegal-csr-test.patch](cpus/cva6/cva6/tests/0006-add-illegal-csr-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cva6/0007-add-ecall-test.patch](cpus/cva6/cva6/tests/0007-add-ecall-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cva6/0008-add-timer-interrupt-test.patch](cpus/cva6/cva6/tests/0008-add-timer-interrupt-test.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cvxif_fu/0001-add-rejected-custom-instruction.patch](cpus/cva6/cvxif_fu/tests/0001-add-rejected-custom-instruction.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/cvxif_issue_register_commit_if_driver/0001-add-commit-notifications.patch](cpus/cva6/cvxif_issue_register_commit_if_driver/tests/0001-add-commit-notifications.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/harness/normalize-initial-mtvec.patch](cpus/cva6/harness/normalize-initial-mtvec.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/hwpf_stride_wrapper/add_wrapper_store_effect.patch](cpus/cva6/hwpf_stride_wrapper/test-patches/add_wrapper_store_effect.patch) | `a5a49fc9f244` | BSD-3-Clause |
| [cva6/store_buffer/0001-read-back-first-word-store.patch](cpus/cva6/store_buffer/tests/patches/0001-read-back-first-word-store.patch) | `a5a49fc9f244` | BSD-3-Clause |

#### riscv-software-src/riscv-tests

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/fp_to_fp/0001-exercise-floating-point-sign-injection.patch](cpus/boom/fp_to_fp/patches/0001-exercise-floating-point-sign-injection.patch) | `1ce128fa78c2` | BSD-3-Clause |

#### SpinalHDL/VexRiscv

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [vexriscv/_shared/0001-enable-selected-csr-tests.patch](cpus/vexriscv/_shared/test-patches/0001-enable-selected-csr-tests.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0002-enable-debug-plugin-test.patch](cpus/vexriscv/_shared/test-patches/0002-enable-debug-plugin-test.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0003-report-debug-trace-mismatch.patch](cpus/vexriscv/_shared/test-patches/0003-report-debug-trace-mismatch.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0005-synchronize-debug-client-startup.patch](cpus/vexriscv/_shared/test-patches/0005-synchronize-debug-client-startup.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0006-add-public-csr-observation.patch](cpus/vexriscv/_shared/test-patches/0006-add-public-csr-observation.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0007-stabilize-fixed-fetch-pc-name.patch](cpus/vexriscv/_shared/test-patches/0007-stabilize-fixed-fetch-pc-name.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0008-zero-unmapped-pmp-read.patch](cpus/vexriscv/_shared/test-patches/0008-zero-unmapped-pmp-read.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0009-establish-debug-first-use-through-bus.patch](cpus/vexriscv/_shared/test-patches/0009-establish-debug-first-use-through-bus.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0010-extend-cycle-budgets.patch](cpus/vexriscv/_shared/test-patches/0010-extend-cycle-budgets.patch) | `c4b2a55b22f4` | MIT |
| [vexriscv/_shared/0011-bind-debug-server-to-free-port.patch](cpus/vexriscv/_shared/test-patches/0011-bind-debug-server-to-free-port.patch) | `c4b2a55b22f4` | MIT |

#### ucb-bar/barstools

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0003-use-published-barstools-dependencies.patch](cpus/boom/_shared/patches/0003-use-published-barstools-dependencies.patch) | `314d80729e7b` | BSD-3-Clause |

#### ucb-bar/berkeley-hardfloat

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0008-use-local-chisel-in-hardfloat.patch](cpus/boom/_shared/patches/0008-use-local-chisel-in-hardfloat.patch) | `70455e53f233` | BSD-3-Clause |

#### ucb-bar/chipyard

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0001-add-large-boom-commit-trace-config.patch](cpus/boom/_shared/patches/0001-add-large-boom-commit-trace-config.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/_shared/0002-use-published-chipyard-dependencies.patch](cpus/boom/_shared/patches/0002-use-published-chipyard-dependencies.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/_shared/0006-enable-boom-memory-trace.patch](cpus/boom/_shared/patches/0006-enable-boom-memory-trace.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/_shared/0007-use-local-chisel-snapshot.patch](cpus/boom/_shared/patches/0007-use-local-chisel-snapshot.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/null_local_branch_predictor_bank/0001-add-null-local-observable-config.patch](cpus/boom/null_local_branch_predictor_bank/patches/0001-add-null-local-observable-config.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/pred_rename_stage/0001-add-sfb-test-config.patch](cpus/boom/pred_rename_stage/patches/0001-add-sfb-test-config.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/tage_branch_predictor_bank/0001-add-tage-observable-config.patch](cpus/boom/tage_branch_predictor_bank/patches/0001-add-tage-observable-config.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |
| [boom/tage_table/0001-add-tage-observable-config.patch](cpus/boom/tage_table/patches/0001-add-tage-observable-config.patch) | `0e6080682b3d` | BSD-3-Clause; Apache-2.0 |

#### ucb-bar/constellation

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [rift2core/environment/rift2core-chisel5-compatibility.patch](cpus/rift2core/environment/rift2core-chisel5-compatibility.patch) | `3632183fd117` | BSD-3-Clause |

#### ucb-bar/dsptools

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0004-use-published-dsptools-dependencies.patch](cpus/boom/_shared/patches/0004-use-published-dsptools-dependencies.patch) | `a1809fbae9e4` | Apache-2.0 |

#### ucb-bar/gemmini

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [boom/_shared/0010-use-local-chisel-in-gemmini.patch](cpus/boom/_shared/patches/0010-use-local-chisel-in-gemmini.patch) | `c47cb7f3eb5c` | BSD-3-Clause |

#### whutddk/Rift2Core

| Patch | Fixed upstream revision | Original terms |
| --- | --- | --- |
| [rift2core/arbiter/observe_arbiter.patch](cpus/rift2core/arbiter/harness/observe_arbiter.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/bim/observe_initialization.patch](cpus/rift2core/bim/harness/observe_initialization.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/btb/observe_initialization.patch](cpus/rift2core/btb/harness/observe_initialization.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/commit/observe_abort_ready.patch](cpus/rift2core/commit/harness/observe_abort_ready.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/csr_score_board/observe_xpu_abort.patch](cpus/rift2core/csr_score_board/harness/observe_xpu_abort.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/decode16/observe_configured_operations.patch](cpus/rift2core/decode16/harness/observe_configured_operations.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/environment/rift2core-chisel5-compatibility.patch](cpus/rift2core/environment/rift2core-chisel5-compatibility.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/execute/observe_alu_writeback.patch](cpus/rift2core/execute/harness/observe_alu_writeback.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/fake_vec_pre_issue/observe_molloc_valid.patch](cpus/rift2core/fake_vec_pre_issue/harness/observe_molloc_valid.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/fake_vec_pre_rename/observe_molloc_valid.patch](cpus/rift2core/fake_vec_pre_rename/harness/observe_molloc_valid.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/if2/observe_fetch_faults.patch](cpus/rift2core/if2/harness/observe_fetch_faults.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/if3/observe_prediction_queues.patch](cpus/rift2core/if3/harness/observe_prediction_queues.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/if4/observe_fault_transport.patch](cpus/rift2core/if4/harness/observe_fault_transport.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/io_lsu/io-lsu-aclint-readback.patch](cpus/rift2core/io_lsu/harness/io-lsu-aclint-readback.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/max_period_fibonacci_lfsr/emit_lfsr16_probe.patch](cpus/rift2core/max_period_fibonacci_lfsr/harness/emit_lfsr16_probe.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/max_period_fibonacci_lfsr/observe_max_period_sequence.patch](cpus/rift2core/max_period_fibonacci_lfsr/harness/observe_max_period_sequence.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/miss_unit/observe_miss_channels.patch](cpus/rift2core/miss_unit/harness/observe_miss_channels.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/mul_div/observe_mul_div.patch](cpus/rift2core/mul_div/harness/observe_mul_div.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/multi_port_fifo/observe_empty_flow.patch](cpus/rift2core/multi_port_fifo/harness/observe_empty_flow.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/probe_unit/observe_banned_handoff.patch](cpus/rift2core/probe_unit/harness/observe_banned_handoff.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/queue/emit_queue3_probe.patch](cpus/rift2core/queue/harness/emit_queue3_probe.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/queue/observe_alu_queue.patch](cpus/rift2core/queue/harness/observe_alu_queue.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/ras/observe_return_stack.patch](cpus/rift2core/ras/harness/observe_return_stack.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/re_direct/observe_redirect_bits.patch](cpus/rift2core/re_direct/harness/observe_redirect_bits.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/rename/observe_rename_memory_order.patch](cpus/rift2core/rename/harness/observe_rename_memory_order.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/srt4_divider/observe_divider_handoffs.patch](cpus/rift2core/srt4_divider/harness/observe_divider_handoffs.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/store_queue/observe_prefetch_disabled.patch](cpus/rift2core/store_queue/harness/observe_prefetch_disabled.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/tag_ram/observe_distinct_access.patch](cpus/rift2core/tag_ram/harness/observe_distinct_access.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/tlb/observe_tlb_reuse.patch](cpus/rift2core/tlb/patches/observe_tlb_reuse.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/write_back_unit/observe_release_payload.patch](cpus/rift2core/write_back_unit/harness/observe_release_payload.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/write_back_unit/observe_release_permission.patch](cpus/rift2core/write_back_unit/harness/observe_release_permission.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/xarbiter/observe_writeback_priority.patch](cpus/rift2core/xarbiter/harness/observe_writeback_priority.patch) | `64b660fb70e0` | Apache-2.0 |
| [rift2core/zip_port/observe_zip_port_bits.patch](cpus/rift2core/zip_port/harness/observe_zip_port_bits.patch) | `64b660fb70e0` | Apache-2.0 |

<a id="cpu-eval-original-material"></a>
## CPU-Eval original material

CPU-Eval-authored problem instructions, tests and additions in patches use
[Apache License 2.0](LICENSE). Original upstream material retains its separate terms.

CPU-Eval-authored patches (including patches to files that earlier CPU-Eval patches add):

- [cpus/cva6/csr_buffer/tests/0002-delay-csr-retirement-with-cache-miss.patch](cpus/cva6/csr_buffer/tests/0002-delay-csr-retirement-with-cache-miss.patch)
- [cpus/cva6/csr_buffer/tests/0003-exercise-csr-triggered-flush.patch](cpus/cva6/csr_buffer/tests/0003-exercise-csr-triggered-flush.patch)
- [cpus/cva6/csr_regfile/tests/0002-delay-csr-retirement-with-cache-miss.patch](cpus/cva6/csr_regfile/tests/0002-delay-csr-retirement-with-cache-miss.patch)
- [cpus/cva6/csr_regfile/tests/0003-exercise-csr-triggered-flush.patch](cpus/cva6/csr_regfile/tests/0003-exercise-csr-triggered-flush.patch)
- [cpus/cva6/csr_regfile/tests/0004-exercise-custom-icache-csr.patch](cpus/cva6/csr_regfile/tests/0004-exercise-custom-icache-csr.patch)
- [cpus/cva6/cva6/tests/0003-delay-csr-retirement-with-cache-miss.patch](cpus/cva6/cva6/tests/0003-delay-csr-retirement-with-cache-miss.patch)
- [cpus/cva6/cva6/tests/0004-exercise-csr-triggered-flush.patch](cpus/cva6/cva6/tests/0004-exercise-csr-triggered-flush.patch)
- [cpus/cva6/cva6/tests/0005-exercise-custom-icache-csr.patch](cpus/cva6/cva6/tests/0005-exercise-custom-icache-csr.patch)
- [cpus/cva6/pmp/test-patches/add_pmp_load_permissions_test.patch](cpus/cva6/pmp/test-patches/add_pmp_load_permissions_test.patch)

CPU-Eval-authored tests:

- [cpus/veer_el2/rvdffie/evaluate_all.sh](cpus/veer_el2/rvdffie/evaluate_all.sh)
- [cpus/veer_el2/rvdffie/test/rvdffie_reset.sv](cpus/veer_el2/rvdffie/test/rvdffie_reset.sv)
- [cpus/veer_el2/rvdff_fpga/evaluate_all.sh](cpus/veer_el2/rvdff_fpga/evaluate_all.sh)
- [cpus/veer_el2/rvdff_fpga/test/verilate_with_storage_observer.sh](cpus/veer_el2/rvdff_fpga/test/verilate_with_storage_observer.sh)
- [cpus/veer_el2/rvdff/test/test_rvdff_ports.sv](cpus/veer_el2/rvdff/test/test_rvdff_ports.sv)
- [cpus/veer_el2/ifu_compress_ctl/evaluate_all.sh](cpus/veer_el2/ifu_compress_ctl/evaluate_all.sh)
- [cpus/veer_el2/ifu_compress_ctl/test/illegal_zero.s](cpus/veer_el2/ifu_compress_ctl/test/illegal_zero.s)
- [cpus/cva6/csr_regfile/harness/check_wfi_ports.py](cpus/cva6/csr_regfile/harness/check_wfi_ports.py)
- [cpus/cva6/csr_regfile/harness/csr_wfi_ports_tb.sv.in](cpus/cva6/csr_regfile/harness/csr_wfi_ports_tb.sv.in)
- [cpus/boom/fp_to_int/tests/fp_to_int_rounding.S](cpus/boom/fp_to_int/tests/fp_to_int_rounding.S)
- [cpus/boom/fetch_buffer/test/FetchBufferPortsTest.scala](cpus/boom/fetch_buffer/test/FetchBufferPortsTest.scala)
- [cpus/boom/div_sqrt_rec_f64/test/DivSqrtRecF64PortsTest.scala](cpus/boom/div_sqrt_rec_f64/test/DivSqrtRecF64PortsTest.scala)
- [cpus/boom/btb_branch_predictor_bank/test/BTBPublicContractTest.scala](cpus/boom/btb_branch_predictor_bank/test/BTBPublicContractTest.scala)
- [cpus/boom/branch_decode/test/BranchDecodePortsTest.scala](cpus/boom/branch_decode/test/BranchDecodePortsTest.scala)
- [cpus/boom/boom_tile_module_imp/hartid_check.py](cpus/boom/boom_tile_module_imp/hartid_check.py)
- [cpus/boom/boom_probe_unit/test/BoomProbeUnitTest.scala](cpus/boom/boom_probe_unit/test/BoomProbeUnitTest.scala)
- [cpus/boom/boom_iomshr/store_response_check.py](cpus/boom/boom_iomshr/store_response_check.py)
- [cpus/boom/boom_iomshr/test/uncached_msip.S](cpus/boom/boom_iomshr/test/uncached_msip.S)
- [cpus/boom/boom_iomshr/test/link.ld](cpus/boom/boom_iomshr/test/link.ld)
- [cpus/veer_el2/configurable_gw/test/gateway_edges.sv](cpus/veer_el2/configurable_gw/test/gateway_edges.sv)
- [cpus/boom/amoalu/tests/amoadd_w_upper.S](cpus/boom/amoalu/tests/amoadd_w_upper.S)
- [cpus/boom/boom_mshr/tests/dirty_eviction.S](cpus/boom/boom_mshr/tests/dirty_eviction.S)
- [cpus/boom/alu/tests/srl_and_64bit_boundary.S](cpus/boom/alu/tests/srl_and_64bit_boundary.S)
- [cpus/boom/alu/tests/sra_64bit_shift_amount.S](cpus/boom/alu/tests/sra_64bit_shift_amount.S)
- [cpus/boom/branch_decode/tests/branch_decode_jalr_calls.S](cpus/boom/branch_decode/tests/branch_decode_jalr_calls.S)
- [cpus/boom/branch_decode/tests/branch_decode_x5_returns.S](cpus/boom/branch_decode/tests/branch_decode_x5_returns.S)
- [cpus/boom/_shared/tests/pmp_modes_priority.S](cpus/boom/_shared/tests/pmp_modes_priority.S)
- [cpus/cva6/hpdcache_sync_buffer/harness/evaluate_ports.py](cpus/cva6/hpdcache_sync_buffer/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_sync_buffer/harness/sync_ports_tb.sv](cpus/cva6/hpdcache_sync_buffer/harness/sync_ports_tb.sv)
- [cpus/ibex/csr/evaluate_ports.sh](cpus/ibex/csr/evaluate_ports.sh)
- [cpus/ibex/csr/harness/csr_tb.cpp](cpus/ibex/csr/harness/csr_tb.cpp)
- [cpus/cva6/hpdcache_mem_req_write_arbiter/harness/evaluate_ports.py](cpus/cva6/hpdcache_mem_req_write_arbiter/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_mem_req_write_arbiter/harness/write_arbiter_ports_tb.sv](cpus/cva6/hpdcache_mem_req_write_arbiter/harness/write_arbiter_ports_tb.sv)
- [cpus/cva6/hwpf_stride_arb/harness/evaluate_ports.py](cpus/cva6/hwpf_stride_arb/harness/evaluate_ports.py)
- [cpus/cva6/hwpf_stride_arb/harness/stride_arb_ports_tb.sv](cpus/cva6/hwpf_stride_arb/harness/stride_arb_ports_tb.sv)
- [cpus/cva6/hwpf_stride_arb/harness/compare_directed_traces.py](cpus/cva6/hwpf_stride_arb/harness/compare_directed_traces.py)
- [cpus/cva6/copro_alu/harness/copro_alu_destination_test.sv](cpus/cva6/copro_alu/harness/copro_alu_destination_test.sv)
- [cpus/cva6/cvxif_fu/harness/cvxif_fu_result_ready_test.sv](cpus/cva6/cvxif_fu/harness/cvxif_fu_result_ready_test.sv)
- [cpus/cva6/cva6_icache/harness/icache_fence_i.S](cpus/cva6/cva6_icache/harness/icache_fence_i.S)
- [cpus/cva6/bht/harness/bht_ports_tb.sv](cpus/cva6/bht/harness/bht_ports_tb.sv)
- [cpus/cva6/lfsr/harness/lfsr_ports_tb.sv](cpus/cva6/lfsr/harness/lfsr_ports_tb.sv)
- [cpus/cva6/ras/harness/ras_ports_tb.sv](cpus/cva6/ras/harness/ras_ports_tb.sv)
- [cpus/cva6/harness/compare_cycle_measurement.py](cpus/cva6/harness/compare_cycle_measurement.py)
- [cpus/boom/fma_decoder/tests/fmul_negative_zero.S](cpus/boom/fma_decoder/tests/fmul_negative_zero.S)
- [cpus/boom/fp_to_fp/tests/fp_to_fp_rounding_and_nan.S](cpus/boom/fp_to_fp/tests/fp_to_fp_rounding_and_nan.S)
- [cpus/boom/int_to_fp/tests/int_to_fp_direct_rounding.S](cpus/boom/int_to_fp/tests/int_to_fp_direct_rounding.S)
- [cpus/boom/round_raw_fn_to_rec_fn/tests/rounding_mode_rup.S](cpus/boom/round_raw_fn_to_rec_fn/tests/rounding_mode_rup.S)
- [cpus/ibex/counter/evaluate_ports.sh](cpus/ibex/counter/evaluate_ports.sh)
- [cpus/ibex/counter/harness/counter_tb.cpp](cpus/ibex/counter/harness/counter_tb.cpp)
- [cpus/ibex/decoder/harness/mulhsu_signed_test.S](cpus/ibex/decoder/harness/mulhsu_signed_test.S)
- [cpus/ibex/decoder/harness/csr_operand_test.S](cpus/ibex/decoder/harness/csr_operand_test.S)
- [cpus/rift2core/dividor/tests/word-zero/source/divuw_zero.S](cpus/rift2core/dividor/tests/word-zero/source/divuw_zero.S)
- [cpus/rift2core/dividor/tests/word-zero/source/remuw_zero.S](cpus/rift2core/dividor/tests/word-zero/source/remuw_zero.S)
- [cpus/rift2core/dividor/tests/word-zero/source/divuw_control.S](cpus/rift2core/dividor/tests/word-zero/source/divuw_control.S)
- [cpus/rift2core/dividor/tests/word-zero/source/remuw_control.S](cpus/rift2core/dividor/tests/word-zero/source/remuw_control.S)
- [cpus/boom/nbdtlb/test/NBDTLBFenceTest.scala](cpus/boom/nbdtlb/test/NBDTLBFenceTest.scala)
- [cpus/boom/fa_micro_btb_branch_predictor_bank/test/MicroBTBPublicContractTest.scala](cpus/boom/fa_micro_btb_branch_predictor_bank/test/MicroBTBPublicContractTest.scala)
- [cpus/boom/issue_unit_collapsing/test/IssuePublicContractTest.scala](cpus/boom/issue_unit_collapsing/test/IssuePublicContractTest.scala)
- [cpus/boom/rename_free_list/test/FreeListPublicContractTest.scala](cpus/boom/rename_free_list/test/FreeListPublicContractTest.scala)
- [cpus/boom/pred_rename_stage/test/PredPublicContractTest.scala](cpus/boom/pred_rename_stage/test/PredPublicContractTest.scala)
- [cpus/boom/tage_branch_predictor_bank/test/TageBankPublicContractTest.scala](cpus/boom/tage_branch_predictor_bank/test/TageBankPublicContractTest.scala)
- [cpus/boom/tage_table/test/TageTablePublicContractTest.scala](cpus/boom/tage_table/test/TageTablePublicContractTest.scala)
- [cpus/boom/i_cache_module/test/ICachePublicContractTest.scala](cpus/boom/i_cache_module/test/ICachePublicContractTest.scala)
- [cpus/boom/lsu/compare_lsu_traces.py](cpus/boom/lsu/compare_lsu_traces.py)
- [cpus/boom/rob/test/RobPublicContractTest.scala](cpus/boom/rob/test/RobPublicContractTest.scala)
- [cpus/boom/f_div_sqrt_unit/test/FDivSqrtWritebackTest.scala](cpus/boom/f_div_sqrt_unit/test/FDivSqrtWritebackTest.scala)
- [cpus/boom/fpu_exe_unit/test/FPUExeUnitWritebackTest.scala](cpus/boom/fpu_exe_unit/test/FPUExeUnitWritebackTest.scala)
- [cpus/boom/issue_slot/test/IssueSlotSpeculationTest.scala](cpus/boom/issue_slot/test/IssueSlotSpeculationTest.scala)
- [cpus/boom/issue_slot/tests/issue_slot_split_store.S](cpus/boom/issue_slot/tests/issue_slot_split_store.S)
- [cpus/boom/f_div_sqrt_unit/tests/f_div_sqrt_static_rounding.S](cpus/boom/f_div_sqrt_unit/tests/f_div_sqrt_static_rounding.S)
- [cpus/boom/div_sqrt_rec_f64_mul_add_z31/test/DivSqrtMultiplyReservationsTest.scala](cpus/boom/div_sqrt_rec_f64_mul_add_z31/test/DivSqrtMultiplyReservationsTest.scala)
- [cpus/boom/l1_metadata_array/test/MetadataPublicContractTest.scala](cpus/boom/l1_metadata_array/test/MetadataPublicContractTest.scala)
- [cpus/boom/forwarding_age_logic/tests/ForwardingAgeLogicTest.scala](cpus/boom/forwarding_age_logic/tests/ForwardingAgeLogicTest.scala)
- [cpus/boom/forwarding_age_logic/tests/youngest_store_forwarding.S](cpus/boom/forwarding_age_logic/tests/youngest_store_forwarding.S)
- [cpus/boom/lsu/tests/store_forwarding_pending.S](cpus/boom/lsu/tests/store_forwarding_pending.S)
- [cpus/boom/mul_add_rec_fn_to_raw_pre_mul/tests/fmadd_signaling_addend.S](cpus/boom/mul_add_rec_fn_to_raw_pre_mul/tests/fmadd_signaling_addend.S)
- [cpus/boom/div_unit/test/DivUnitPortsTest.scala](cpus/boom/div_unit/test/DivUnitPortsTest.scala)
- [cpus/boom/hella_cache_arbiter/test/HellaCacheArbiterPortsTest.scala](cpus/boom/hella_cache_arbiter/test/HellaCacheArbiterPortsTest.scala)
- [cpus/boom/int_to_fp_unit/tests/integer_conversion_flags.S](cpus/boom/int_to_fp_unit/tests/integer_conversion_flags.S)
- [cpus/boom/int_xbar/test/IntXbarPortsTest.scala](cpus/boom/int_xbar/test/IntXbarPortsTest.scala)
- [cpus/boom/int_xbar/tests/timer_pending.S](cpus/boom/int_xbar/tests/timer_pending.S)
- [cpus/boom/loop_branch_predictor_column/test/LoopColumnRepairTest.scala](cpus/boom/loop_branch_predictor_column/test/LoopColumnRepairTest.scala)
- [cpus/boom/_shared/tests/loop_branch_cycles.S](cpus/boom/_shared/tests/loop_branch_cycles.S)
- [cpus/boom/max_period_fibonacci_lfsr/test/MaxPeriodFibonacciLFSRPortsTest.scala](cpus/boom/max_period_fibonacci_lfsr/test/MaxPeriodFibonacciLFSRPortsTest.scala)
- [cpus/boom/mem_addr_calc_unit/test/MemAddrFenceTest.scala](cpus/boom/mem_addr_calc_unit/test/MemAddrFenceTest.scala)
- [cpus/boom/mul54/test/Mul54TimingTest.scala](cpus/boom/mul54/test/Mul54TimingTest.scala)
- [cpus/boom/mul_add_rec_fn_to_raw_post_mul/test/PostMulInvalidTest.scala](cpus/boom/mul_add_rec_fn_to_raw_post_mul/test/PostMulInvalidTest.scala)
- [cpus/boom/mul_add_rec_fn_pipe/tests/fmadd_single_rounding.S](cpus/boom/mul_add_rec_fn_pipe/tests/fmadd_single_rounding.S)
- [cpus/boom/mul_div/test/MulDivPortsTest.scala](cpus/boom/mul_div/test/MulDivPortsTest.scala)
- [cpus/boom/null_local_branch_predictor_bank/tests/NullLocalBranchPredictorBankPortTest.scala](cpus/boom/null_local_branch_predictor_bank/tests/NullLocalBranchPredictorBankPortTest.scala)
- [cpus/boom/null_prefetcher/test/NullPrefetcherPortsTest.scala](cpus/boom/null_prefetcher/test/NullPrefetcherPortsTest.scala)
- [cpus/boom/register_file_synthesizable/test/RegisterFileWriteTimingTest.scala](cpus/boom/register_file_synthesizable/test/RegisterFileWriteTimingTest.scala)
- [cpus/boom/round_raw_fn_to_rec_fn/test/RoundRawDivideByZeroTest.scala](cpus/boom/round_raw_fn_to_rec_fn/test/RoundRawDivideByZeroTest.scala)
- [cpus/boom/pipelined_multiplier/tests/PipelinedMultiplierTimingTest.scala](cpus/boom/pipelined_multiplier/tests/PipelinedMultiplierTimingTest.scala)
- [cpus/boom/pipelined_mul_unit/test/PipelinedMulUnitPortsTest.scala](cpus/boom/pipelined_mul_unit/test/PipelinedMulUnitPortsTest.scala)
- [cpus/boom/pmp_checker/tests/PMPCheckerPermissionsTest.scala](cpus/boom/pmp_checker/tests/PMPCheckerPermissionsTest.scala)
- [cpus/boom/queue/test/QueueSyncReadPortsTest.scala](cpus/boom/queue/test/QueueSyncReadPortsTest.scala)
- [cpus/boom/queue/test/run_ports.sh](cpus/boom/queue/test/run_ports.sh)
- [cpus/boom/rec_fn_to_rec_fn/tests/RecFNToRecFNNaNTest.scala](cpus/boom/rec_fn_to_rec_fn/tests/RecFNToRecFNNaNTest.scala)
- [cpus/boom/register_read/test/RegisterReadFlushTest.scala](cpus/boom/register_read/test/RegisterReadFlushTest.scala)
- [cpus/boom/rename_busy_table/tests/RenameBusyTableStateTest.scala](cpus/boom/rename_busy_table/tests/RenameBusyTableStateTest.scala)
- [cpus/boom/rename_busy_table/evaluate_candidate.sh](cpus/boom/rename_busy_table/evaluate_candidate.sh)
- [cpus/boom/register_read_decode/test/RegisterReadDecodePortsTest.scala](cpus/boom/register_read_decode/test/RegisterReadDecodePortsTest.scala)
- [cpus/boom/round_any_raw_fn_to_rec_fn/tests/RoundAnyRawFNToRecFNModesTest.scala](cpus/boom/round_any_raw_fn_to_rec_fn/tests/RoundAnyRawFNToRecFNModesTest.scala)
- [cpus/boom/rvc_expander/test/RVCExpanderDoubleMemoryTest.scala](cpus/boom/rvc_expander/test/RVCExpanderDoubleMemoryTest.scala)
- [cpus/boom/tlb/test/InstructionTLBTranslationTest.scala](cpus/boom/tlb/test/InstructionTLBTranslationTest.scala)
- [cpus/boom/tlb/evaluate_candidate.sh](cpus/boom/tlb/evaluate_candidate.sh)
- [cpus/cva6/compressed_decoder/harness/compressed_zcb_ports_tb.sv](cpus/cva6/compressed_decoder/harness/compressed_zcb_ports_tb.sv)
- [cpus/cva6/hpdcache_1hot_to_binary/harness/onehot_ports_tb.sv](cpus/cva6/hpdcache_1hot_to_binary/harness/onehot_ports_tb.sv)
- [cpus/cva6/hpdcache_cmo/harness/cmo_flush_ports_tb.sv](cpus/cva6/hpdcache_cmo/harness/cmo_flush_ports_tb.sv)
- [cpus/cva6/hpdcache_core_arbiter/harness/core_arbiter_ports_tb.sv](cpus/cva6/hpdcache_core_arbiter/harness/core_arbiter_ports_tb.sv)
- [cpus/cva6/hpdcache_lfsr/harness/lfsr_ports_tb.sv](cpus/cva6/hpdcache_lfsr/harness/lfsr_ports_tb.sv)
- [cpus/cva6/hpdcache_mem_req_read_arbiter/harness/evaluate_ports.sh](cpus/cva6/hpdcache_mem_req_read_arbiter/harness/evaluate_ports.sh)
- [cpus/cva6/hpdcache_mem_req_read_arbiter/harness/read_arbiter_ports_tb.sv](cpus/cva6/hpdcache_mem_req_read_arbiter/harness/read_arbiter_ports_tb.sv)
- [cpus/cva6/hpdcache_mem_resp_demux/harness/response_ports_tb.sv](cpus/cva6/hpdcache_mem_resp_demux/harness/response_ports_tb.sv)
- [cpus/cva6/hpdcache_mem_to_axi_read/harness/axi_read_ports_tb.sv](cpus/cva6/hpdcache_mem_to_axi_read/harness/axi_read_ports_tb.sv)
- [cpus/cva6/hpdcache_mem_to_axi_write/harness/axi_write_ports_tb.sv](cpus/cva6/hpdcache_mem_to_axi_write/harness/axi_write_ports_tb.sv)
- [cpus/cva6/hpdcache_mshr/harness/evaluate_ports.py](cpus/cva6/hpdcache_mshr/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_mshr/harness/mshr_ports_tb.sv](cpus/cva6/hpdcache_mshr/harness/mshr_ports_tb.sv)
- [cpus/cva6/hpdcache_mux/harness/evaluate_ports.py](cpus/cva6/hpdcache_mux/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_mux/harness/mux_ports_tb.sv](cpus/cva6/hpdcache_mux/harness/mux_ports_tb.sv)
- [cpus/cva6/hpdcache_prio_1hot_encoder/harness/priority_ports_tb.sv](cpus/cva6/hpdcache_prio_1hot_encoder/harness/priority_ports_tb.sv)
- [cpus/cva6/hpdcache_regbank_wbyteenable_1rw/harness/regbank_ports_tb.sv](cpus/cva6/hpdcache_regbank_wbyteenable_1rw/harness/regbank_ports_tb.sv)
- [cpus/cva6/hpdcache_rtab/harness/evaluate_ports.py](cpus/cva6/hpdcache_rtab/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_rtab/harness/rtab_ports_tb.sv](cpus/cva6/hpdcache_rtab/harness/rtab_ports_tb.sv)
- [cpus/cva6/hpdcache_sram_1rw/harness/sram_ports_tb.sv](cpus/cva6/hpdcache_sram_1rw/harness/sram_ports_tb.sv)
- [cpus/cva6/hpdcache_sram_wbyteenable/harness/sram_ports_tb.sv](cpus/cva6/hpdcache_sram_wbyteenable/harness/sram_ports_tb.sv)
- [cpus/cva6/hpdcache_sram_wbyteenable/harness/evaluate_ports.py](cpus/cva6/hpdcache_sram_wbyteenable/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_sram_wbyteenable_1rw/harness/sram_byte_ports_tb.sv](cpus/cva6/hpdcache_sram_wbyteenable_1rw/harness/sram_byte_ports_tb.sv)
- [cpus/cva6/hpdcache_sram_wbyteenable_1rw/harness/evaluate_ports.py](cpus/cva6/hpdcache_sram_wbyteenable_1rw/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_uncached/harness/evaluate_with_diagnostics.py](cpus/cva6/hpdcache_uncached/harness/evaluate_with_diagnostics.py)
- [cpus/cva6/hpdcache_uncached/harness/hpdcache_amo_cached_reload.S](cpus/cva6/hpdcache_uncached/harness/hpdcache_amo_cached_reload.S)
- [cpus/cva6/hpdcache_wbuf/harness/wbuf_ports_tb.sv](cpus/cva6/hpdcache_wbuf/harness/wbuf_ports_tb.sv)
- [cpus/cva6/hpdcache_wbuf/harness/evaluate_ports.py](cpus/cva6/hpdcache_wbuf/harness/evaluate_ports.py)
- [cpus/cva6/hwpf_stride/harness/stride_ports_tb.sv](cpus/cva6/hwpf_stride/harness/stride_ports_tb.sv)
- [cpus/cva6/hwpf_stride_wrapper/harness/record_port_compile_error.py](cpus/cva6/hwpf_stride_wrapper/harness/record_port_compile_error.py)
- [cpus/cva6/id_stage/harness/check_id_ports.py](cpus/cva6/id_stage/harness/check_id_ports.py)
- [cpus/cva6/id_stage/harness/id_stage_ports_tb.sv](cpus/cva6/id_stage/harness/id_stage_ports_tb.sv)
- [cpus/cva6/instr_decoder/harness/instr_decoder_ports_tb.sv](cpus/cva6/instr_decoder/harness/instr_decoder_ports_tb.sv)
- [cpus/cva6/instr_queue/harness/evaluate_queue_ports.py](cpus/cva6/instr_queue/harness/evaluate_queue_ports.py)
- [cpus/cva6/instr_queue/harness/queue_ports_tb.sv](cpus/cva6/instr_queue/harness/queue_ports_tb.sv)
- [cpus/cva6/instr_realign/harness/evaluate_ports.py](cpus/cva6/instr_realign/harness/evaluate_ports.py)
- [cpus/cva6/instr_realign/harness/realign_ports_tb.sv](cpus/cva6/instr_realign/harness/realign_ports_tb.sv)
- [cpus/cva6/issue_stage/harness/check_issue_ports.py](cpus/cva6/issue_stage/harness/check_issue_ports.py)
- [cpus/cva6/issue_stage/harness/issue_stage_ports_tb.sv](cpus/cva6/issue_stage/harness/issue_stage_ports_tb.sv)
- [cpus/cva6/load_store_unit/harness/testlist_load_store_unit.yaml](cpus/cva6/load_store_unit/harness/testlist_load_store_unit.yaml)
- [cpus/cva6/load_unit/harness/evaluate_load_ports.py](cpus/cva6/load_unit/harness/evaluate_load_ports.py)
- [cpus/cva6/load_unit/harness/load_ports_tb.sv](cpus/cva6/load_unit/harness/load_ports_tb.sv)
- [cpus/cva6/lsu_bypass/harness/evaluate_ports.py](cpus/cva6/lsu_bypass/harness/evaluate_ports.py)
- [cpus/cva6/lsu_bypass/harness/bypass_ports_tb.sv](cpus/cva6/lsu_bypass/harness/bypass_ports_tb.sv)
- [cpus/cva6/lzc/harness/check_ports.py](cpus/cva6/lzc/harness/check_ports.py)
- [cpus/cva6/lzc/harness/evaluate.sh](cpus/cva6/lzc/harness/evaluate.sh)
- [cpus/cva6/lzc/harness/lzc_ports_tb.sv](cpus/cva6/lzc/harness/lzc_ports_tb.sv)
- [cpus/cva6/mult/harness/mult_flush_tb.sv](cpus/cva6/mult/harness/mult_flush_tb.sv)
- [cpus/cva6/mult/harness/evaluate_ports.py](cpus/cva6/mult/harness/evaluate_ports.py)
- [cpus/cva6/multiplier/harness/evaluate_ports.py](cpus/cva6/multiplier/harness/evaluate_ports.py)
- [cpus/cva6/multiplier/harness/multiplier_ports_tb.sv](cpus/cva6/multiplier/harness/multiplier_ports_tb.sv)
- [cpus/cva6/pmp/harness/check_write_ports.py](cpus/cva6/pmp/harness/check_write_ports.py)
- [cpus/cva6/pmp/harness/pmp_write_ports_tb.sv](cpus/cva6/pmp/harness/pmp_write_ports_tb.sv)
- [cpus/cva6/popcount/harness/evaluate_ports.py](cpus/cva6/popcount/harness/evaluate_ports.py)
- [cpus/cva6/popcount/harness/popcount_ports_tb.sv](cpus/cva6/popcount/harness/popcount_ports_tb.sv)
- [cpus/cva6/scoreboard/harness/scoreboard_cvxif_ports_tb.sv](cpus/cva6/scoreboard/harness/scoreboard_cvxif_ports_tb.sv)
- [cpus/cva6/scoreboard/harness/evaluate_cvxif_ports.py](cpus/cva6/scoreboard/harness/evaluate_cvxif_ports.py)
- [cpus/cva6/serdiv/harness/evaluate_ports.py](cpus/cva6/serdiv/harness/evaluate_ports.py)
- [cpus/cva6/serdiv/harness/serdiv_ports_tb.sv](cpus/cva6/serdiv/harness/serdiv_ports_tb.sv)
- [cpus/cva6/shift_reg/harness/evaluate_shift_reg_ports.py](cpus/cva6/shift_reg/harness/evaluate_shift_reg_ports.py)
- [cpus/cva6/shift_reg/harness/shift_reg_ports_tb.sv](cpus/cva6/shift_reg/harness/shift_reg_ports_tb.sv)
- [cpus/cva6/sram_cache/harness/test_user.py](cpus/cva6/sram_cache/harness/test_user.py)
- [cpus/cva6/sram_cache/harness/user_tb.sv](cpus/cva6/sram_cache/harness/user_tb.sv)
- [cpus/cva6/store_buffer/harness/store_buffer_flush_tb.sv](cpus/cva6/store_buffer/harness/store_buffer_flush_tb.sv)
- [cpus/cva6/store_buffer/harness/evaluate_flush_ports.py](cpus/cva6/store_buffer/harness/evaluate_flush_ports.py)
- [cpus/cva6/tc_sram/harness/evaluate_tc_sram_ports.py](cpus/cva6/tc_sram/harness/evaluate_tc_sram_ports.py)
- [cpus/cva6/tc_sram/harness/tc_sram_ports_tb.sv](cpus/cva6/tc_sram/harness/tc_sram_ports_tb.sv)
- [cpus/cva6/tc_sram_wrapper_cache_techno/harness/evaluate_word_ports.py](cpus/cva6/tc_sram_wrapper_cache_techno/harness/evaluate_word_ports.py)
- [cpus/cva6/tc_sram_wrapper_cache_techno/harness/word_ports_tb.sv](cpus/cva6/tc_sram_wrapper_cache_techno/harness/word_ports_tb.sv)
- [cpus/ibex/compressed_decoder/harness/negative_lui_test.S](cpus/ibex/compressed_decoder/harness/negative_lui_test.S)
- [cpus/cva6/store_unit/harness/testlist_store_unit_with_trap.yaml](cpus/cva6/store_unit/harness/testlist_store_unit_with_trap.yaml)
- [cpus/cva6/store_unit/harness/store-misaligned.S](cpus/cva6/store_unit/harness/store-misaligned.S)
- [cpus/ibex/controller/harness/wfi_timer_test.S](cpus/ibex/controller/harness/wfi_timer_test.S)
- [cpus/ibex/cs_registers/harness/csr_test.S](cpus/ibex/cs_registers/harness/csr_test.S)
- [cpus/ibex/fetch_fifo/evaluate_ports.sh](cpus/ibex/fetch_fifo/evaluate_ports.sh)
- [cpus/ibex/fetch_fifo/harness/fetch_fifo_error_tb.cpp](cpus/ibex/fetch_fifo/harness/fetch_fifo_error_tb.cpp)
- [cpus/ibex/load_store_unit/harness/misaligned_test.S](cpus/ibex/load_store_unit/harness/misaligned_test.S)
- [cpus/ibex/multdiv_fast/harness/division_result_test.S](cpus/ibex/multdiv_fast/harness/division_result_test.S)
- [cpus/ibex/prefetch_buffer/evaluate_ports.sh](cpus/ibex/prefetch_buffer/evaluate_ports.sh)
- [cpus/ibex/prefetch_buffer/harness/prefetch_grant_tb.cpp](cpus/ibex/prefetch_buffer/harness/prefetch_grant_tb.cpp)
- [cpus/ibex/wb_stage/harness/fault_retirement_test.S](cpus/ibex/wb_stage/harness/fault_retirement_test.S)
- [cpus/ibex/_shared/evaluate_primitive.sh](cpus/ibex/_shared/evaluate_primitive.sh)
- [cpus/ibex/prim_buf/harness/primitive_tb.cpp](cpus/ibex/prim_buf/harness/primitive_tb.cpp)
- [cpus/rift2core/max_period_fibonacci_lfsr/harness/test_lfsr16.cpp](cpus/rift2core/max_period_fibonacci_lfsr/harness/test_lfsr16.cpp)
- [cpus/rift2core/mmu/tests/sv39-megapage/source/sv39_megapage_offset.S](cpus/rift2core/mmu/tests/sv39-megapage/source/sv39_megapage_offset.S)
- [cpus/rift2core/queue/harness/test_queue3.cpp](cpus/rift2core/queue/harness/test_queue3.cpp)
- [cpus/rift2core/rename/tests/mstatus-load-order/source/rename_mstatus_load_order.S](cpus/rift2core/rename/tests/mstatus-load-order/source/rename_mstatus_load_order.S)
- [cpus/rift2core/tlb/tests/sv39-megapage-reuse/source/sv39_megapage_reuse.S](cpus/rift2core/tlb/tests/sv39-megapage-reuse/source/sv39_megapage_reuse.S)
- [cpus/veer_el2/dec_pmp_ctl/test/check_pmp_csr.sv](cpus/veer_el2/dec_pmp_ctl/test/check_pmp_csr.sv)
- [cpus/veer_el2/dec_pmp_ctl/test/run_with_pmp_csr.sh](cpus/veer_el2/dec_pmp_ctl/test/run_with_pmp_csr.sh)
- [cpus/veer_el2/dec_gpr_ctl/evaluate_all.sh](cpus/veer_el2/dec_gpr_ctl/evaluate_all.sh)
- [cpus/veer_el2/dec_gpr_ctl/test/run_gpr_port_probe.py](cpus/veer_el2/dec_gpr_ctl/test/run_gpr_port_probe.py)
- [cpus/veer_el2/dec_timer_ctl/harness/dec_timer_ctl_selfcheck.s](cpus/veer_el2/dec_timer_ctl/harness/dec_timer_ctl_selfcheck.s)
- [cpus/veer_el2/dec_trigger/test/evaluate_dec_trigger.sh](cpus/veer_el2/dec_trigger/test/evaluate_dec_trigger.sh)
- [cpus/veer_el2/dec_tlu_ctl/evaluate_all.sh](cpus/veer_el2/dec_tlu_ctl/evaluate_all.sh)
- [cpus/veer_el2/dec_tlu_ctl/test/run_tlu_csr_probe.py](cpus/veer_el2/dec_tlu_ctl/test/run_tlu_csr_probe.py)
- [cpus/veer_el2/dec_tlu_ctl/test/tlu_csr_probe.cpp](cpus/veer_el2/dec_tlu_ctl/test/tlu_csr_probe.cpp)
- [cpus/veer_el2/exu/evaluate_all.sh](cpus/veer_el2/exu/evaluate_all.sh)
- [cpus/veer_el2/exu/harness/exu_branch_count.s](cpus/veer_el2/exu/harness/exu_branch_count.s)
- [cpus/veer_el2/ifu/evaluate_all.sh](cpus/veer_el2/ifu/evaluate_all.sh)
- [cpus/veer_el2/ifu/test/verilate_with_redirect_observer.sh](cpus/veer_el2/ifu/test/verilate_with_redirect_observer.sh)
- [cpus/veer_el2/ifu_aln_ctl/harness/test_alignment_ports.sv](cpus/veer_el2/ifu_aln_ctl/harness/test_alignment_ports.sv)
- [cpus/veer_el2/ifu_ic_mem/harness/evaluate_icache_dccm_selfcheck.sh](cpus/veer_el2/ifu_ic_mem/harness/evaluate_icache_dccm_selfcheck.sh)
- [cpus/veer_el2/ifu_iccm_mem/evaluate_all.sh](cpus/veer_el2/ifu_iccm_mem/evaluate_all.sh)
- [cpus/veer_el2/ifu_mem_ctl/evaluate_all.sh](cpus/veer_el2/ifu_mem_ctl/evaluate_all.sh)
- [cpus/veer_el2/ifu_mem_ctl/harness/ifu_fence_i.s](cpus/veer_el2/ifu_mem_ctl/harness/ifu_fence_i.s)
- [cpus/veer_el2/lsu_addrcheck/evaluate_all.sh](cpus/veer_el2/lsu_addrcheck/evaluate_all.sh)
- [cpus/veer_el2/lsu_addrcheck/test/run_addrcheck_port_probe.py](cpus/veer_el2/lsu_addrcheck/test/run_addrcheck_port_probe.py)
- [cpus/veer_el2/rvdffpcie/evaluate_all.sh](cpus/veer_el2/rvdffpcie/evaluate_all.sh)
- [cpus/veer_el2/rvdffpcie/test/pc_register_probe.sv](cpus/veer_el2/rvdffpcie/test/pc_register_probe.sv)
- [cpus/veer_el2/rvdffppe/test/evaluate_rvdffppe.sh](cpus/veer_el2/rvdffppe/test/evaluate_rvdffppe.sh)
- [cpus/veer_el2/rvdffs/evaluate_all.sh](cpus/veer_el2/rvdffs/evaluate_all.sh)
- [cpus/veer_el2/rvdffsc_fpga/evaluate_all.sh](cpus/veer_el2/rvdffsc_fpga/evaluate_all.sh)
- [cpus/veer_el2/rvdffsc_fpga/test/run_clock_gate_probe.py](cpus/veer_el2/rvdffsc_fpga/test/run_clock_gate_probe.py)
- [cpus/veer_el2/rvecc_decode/evaluate_all.sh](cpus/veer_el2/rvecc_decode/evaluate_all.sh)
- [cpus/veer_el2/rvecc_decode_64/evaluate_all.sh](cpus/veer_el2/rvecc_decode_64/evaluate_all.sh)
- [cpus/cva6/hpdcache_data_upsize/harness/evaluate_ports.py](cpus/cva6/hpdcache_data_upsize/harness/evaluate_ports.py)
- [cpus/cva6/hpdcache_data_upsize/harness/upsize_ports_tb.sv](cpus/cva6/hpdcache_data_upsize/harness/upsize_ports_tb.sv)
- [cpus/veer_el2/exu_alu_ctl/evaluate_all.sh](cpus/veer_el2/exu_alu_ctl/evaluate_all.sh)
- [cpus/veer_el2/exu_alu_ctl/test/evaluate_alu_directed.sh](cpus/veer_el2/exu_alu_ctl/test/evaluate_alu_directed.sh)
- [cpus/veer_el2/exu_alu_ctl/test/exu_alu_directed.s](cpus/veer_el2/exu_alu_ctl/test/exu_alu_directed.s)
- [cpus/veer_el2/rvsyncss_fpga/test/rvsyncss_fpga_port_probe.sv](cpus/veer_el2/rvsyncss_fpga/test/rvsyncss_fpga_port_probe.sv)
- [cpus/vexriscv/REGRESSION_CONFIGURATION.txt](cpus/vexriscv/REGRESSION_CONFIGURATION.txt)
- [cpus/vexriscv/harness/regression_configuration.py](cpus/vexriscv/harness/regression_configuration.py)
- [cpus/boom/_shared/tests/loop_exit_cycles.S](cpus/boom/_shared/tests/loop_exit_cycles.S)

[cpus/veer_el2/configurable_gw/test/gateway_edges.sv](cpus/veer_el2/configurable_gw/test/gateway_edges.sv): CPU-Eval-authored VeeR EL2 gateway port test for pending requests and clear strobes.

[cpus/ibex/decoder/harness/mulhsu_signed_test.S](cpus/ibex/decoder/harness/mulhsu_signed_test.S): The header "Copyright CPU-Eval contributors" refers to the holder named in [NOTICE](NOTICE): Copyright 2026 Ishihara-Masuda-Lab.

[cpus/boom/fa_micro_btb_branch_predictor_bank/test/MicroBTBPublicContractTest.scala](cpus/boom/fa_micro_btb_branch_predictor_bank/test/MicroBTBPublicContractTest.scala): CPU-Eval-authored stimulus and assertions. The harness uses published interfaces without copying the target implementation.

[cpus/boom/issue_unit_collapsing/test/IssuePublicContractTest.scala](cpus/boom/issue_unit_collapsing/test/IssuePublicContractTest.scala): CPU-Eval-authored stimulus and assertions using published interfaces. The fixture binds the inherited branch-offset input to its producer width and checks public issue outputs.

[cpus/cva6/load_store_unit/harness/testlist_load_store_unit.yaml](cpus/cva6/load_store_unit/harness/testlist_load_store_unit.yaml): CPU-Eval test selection under Apache-2.0, assembled from the existing store_unit and load_unit test lists. The ten assembly programs are fetched from the pinned RISC-V Architectural Tests checkout and retain their BSD-3-Clause terms. See [riscv-arch-test-a5a49fc9f244-COPYING.BSD](LICENSES/license-texts/riscv-arch-test-a5a49fc9f244-COPYING.BSD).

[cpus/veer_el2/dec_timer_ctl/harness/dec_timer_ctl_selfcheck.s](cpus/veer_el2/dec_timer_ctl/harness/dec_timer_ctl_selfcheck.s): CPU-Eval-authored VeeR EL2 timer assembly for increment, interrupt and cascade observations.

Container base images and tools obtained by `environments/*.def` are fetched at build time,
retain their own licenses, and are not redistributed in this repository.
