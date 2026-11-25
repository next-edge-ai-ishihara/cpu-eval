# CPU-Eval

[![arXiv](https://img.shields.io/badge/arXiv-2611.32405-b31b1b.svg)](https://arxiv.org/abs/2611.32405)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

CPU-Eval is a benchmark of 339 HDL-generation problems for evaluating large
language models on CPU hardware design. Each problem asks an LLM to generate
one submodule of one of six practical RISC-V CPUs, ranging from small
embedded cores to Linux-capable out-of-order cores, in SystemVerilog, Chisel
or SpinalHDL.
CPU-Eval is described in our paper "[CPU-Eval: Evaluating Large Language
Models for CPU Hardware Code Generation](https://arxiv.org/abs/2611.32405),"
accepted as a regular paper at the 2027 Design, Automation and Test in Europe
Conference (DATE 2027).

CPU-Eval integrates the generated submodule into its CPU, executes test
programs that the CPU developers run in their regression testing, and compares
the CPU's execution trace with a reference ISA model. When execution diverges,
comparison logs identify the instruction and architectural-state update at the
divergence. CPU-Eval extends these tests to detect errors that the original
tests miss.

## Problems

| CPU | Description | HDL | Problems |
| --- | --- | --- | ---: |
| [BOOM](cpus/boom/PROBLEMS.tsv) | 64-bit out-of-order, Linux-capable | Chisel | 91 |
| [CVA6](cpus/cva6/PROBLEMS.tsv) | 32/64-bit in-order, Linux-capable | SystemVerilog | 93 |
| [Rift2Core](cpus/rift2core/PROBLEMS.tsv) | 64-bit out-of-order, M/S/U modes | Chisel | 48 |
| [VeeR EL2](cpus/veer_el2/PROBLEMS.tsv) | 32-bit in-order, 4-stage pipeline | SystemVerilog | 71 |
| [VexRiscv](cpus/vexriscv/PROBLEMS.tsv) | 32-bit in-order, FPGA-oriented | SpinalHDL | 16 |
| [Ibex](cpus/ibex/PROBLEMS.tsv) | 32-bit in-order, embedded | SystemVerilog | 20 |

## Quick start

Run the commands from the repository root on x86_64 Linux with network access.
The host needs Git, Bash, Python 3.12.3 with venv and pip, SingularityCE or
Apptainer with `build --fakeroot` support, riscv64-unknown-elf GCC 13.2.0 and
binutils 2.42.

Prepare an environment for each CPU once. The command builds the container
image and test programs in the new directory given by `--output` and keeps
temporary build files in `--work-root`:

```bash
python3 tools/prepare_environment.py \
  --cpu cva6 --output /path/to/environments/cva6 \
  --work-root /path/to/image-build-work
```

Set `--cpu` to `boom`, `cva6`, `ibex`, `rift2core`, `veer_el2` or `vexriscv`. Pass
`--runtime apptainer` when preparing with Apptainer, or
`--image /path/to/cva6-eval.sif` to reuse an image built from the same release.

Give [cpus/cva6/alu/SPEC.md](cpus/cva6/alu/SPEC.md) to your LLM as the user
prompt, with no system prompt. Save the response as a UTF-8 text file without
any reasoning that the API returns in a separate field. The evaluator extracts
the code from the response.

Evaluate the answer in the prepared environment:

```bash
python3 tools/evaluate_submission.py run \
  --problem cva6/alu \
  --candidate /path/to/alu-response.txt \
  --environment /path/to/environments/cva6 \
  --output /path/to/alu-result
```

Evaluation compiles and runs the LLM-generated code on your machine. Run it in
an isolated environment, such as a dedicated virtual machine.

The command prints the result and, for a failing answer, excerpts from the
compiler or comparison logs. It saves the evaluation records in the output
directory. To print the result again later, run:

```bash
python3 tools/evaluate_submission.py show /path/to/alu-result
```

## Evaluating many answers

Repeat `--candidate FILE` with `run --problem CPU/PROBLEM` to evaluate several
answers to one problem. Each occurrence counts as one trial.

The [Ollama Cloud example](examples/ollama-cloud/README.md) generates ten
answers for every problem of one CPU. A batch job evaluates many answers for
the one CPU given by `--cpu`. Pass each answer as `--candidate PROBLEM=FILE`,
where `PROBLEM` is a problem name in that CPU's `PROBLEMS.tsv` and `FILE` is
the saved response:

```bash
python3 tools/evaluate_submission.py prepare --cpu cva6 \
  --candidate alu=/path/to/alu-response.txt \
  --candidate serdiv=/path/to/serdiv-response.txt \
  --environment /path/to/environments/cva6 \
  --output /path/to/cva6-job
```

The [Genkai example](examples/genkai/README.md) shows how to submit a prepared
batch job and run its problems in parallel. For local evaluation, use `run`
once per problem and give each invocation its own output directory.

Each answer receives `PASS` or a `FAIL_*` verdict that names the error in the
answer, such as `FAIL_CANDIDATE_COMPILE` or `FAIL_TRACE_MISMATCH`. Only `PASS`
counts as correct; for pass@k, count every answer in the sample size.
`INVALID_*` means that the evaluation stopped before reaching a verdict, for
example because memory ran out, and names the cause.

## Reconstructing problem statements

The repository includes all 339 problem statements. With Git and network
access, reconstruct them from the recorded upstream sources and verify them
against the included copies:

```bash
python3 tools/reconstruct_problem_statements.py --cache /path/to/source-cache
```

## Repository layout

| Location | Contents |
| --- | --- |
| `cpus/` | Problem lists, statements, source and test recipes, and CPU grading tests. |
| `tools/` | Commands that users run. Their subdirectories hold the programs and container image definitions that these commands and the evaluation jobs use. |
| `examples/` | Ollama Cloud generation and Genkai job examples. |
| `LICENSES/` | License texts and upstream notices of the third-party material. |

## Citation

If you use CPU-Eval, please cite our paper:

```bibtex
@inproceedings{iwata2027cpueval,
  title     = {{CPU-Eval}: Evaluating Large Language Models for {CPU} Hardware Code Generation},
  author    = {Iwata, Yuisei and Masuda, Yutaka and Ishihara, Tohru},
  booktitle = {2027 Design, Automation \& Test in Europe Conference (DATE)},
  year      = {2027},
  note      = {in press}
}
```

The page numbers and DOI will be added when the DATE 2027 proceedings are published.

The preprint is available on arXiv:

```bibtex
@misc{iwata2026cpueval,
  title         = {{CPU-Eval}: Evaluating Large Language Models for {CPU} Hardware Code Generation},
  author        = {Iwata, Yuisei and Masuda, Yutaka and Ishihara, Tohru},
  year          = {2026},
  eprint        = {2611.32405},
  archivePrefix = {arXiv},
  primaryClass  = {cs.AR}
}
```

## License

Copyright (c) 2026 Ishihara-Masuda-Lab. CPU-Eval's original code and
documentation are licensed under [Apache License 2.0](LICENSE).
Third-party source excerpts, tests and derived material retain their original
terms. [Third-party notices](THIRD_PARTY_NOTICES.md) identify the applicable
attribution and licenses.

## Acknowledgment

This work is partly supported by JST Research and Development Program for
Next-generation Edge AI Semiconductors, Grant Number JPMJES2511.
