# Example: run a batch job on Genkai

This example evaluates a batch job on the Genkai supercomputer of Kyushu
University. Prepare the environment as in the [Quick start](../../README.md#quick-start)
and the batch job as in [Evaluating many answers](../../README.md#evaluating-many-answers),
then copy the job script into the job directory:

```bash
cp examples/genkai/run_evaluation.pjm /path/to/cva6-job/run-genkai.pjm
```

Transfer the job directory to Genkai, and put the image from
`/path/to/environments/cva6/images/` (for example `cva6-eval.sif`) in
`$HOME/cpu-eval-grading-images/`. From the job directory on the login node,
submit one task per chunk, where `N` is the number of chunks that `prepare`
printed:

```bash
pjsub --bulk --sparam 1-N run-genkai.pjm
```

Each task uses the `a-batch` resource group with 32 CPU cores for up to six
hours. When the job ends, copy `archives/` back and show the results:

```bash
python3 tools/evaluate_submission.py show /path/to/chunk-001.tar.gz
```

To run a task on node-local storage, set `CPU_EVAL_STAGE_ROOT` or request
`PJM_SSD_DIR`. The script then copies the inputs there and copies the finished
archive back.
