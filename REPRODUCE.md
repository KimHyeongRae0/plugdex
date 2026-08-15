# Reproducing these numbers

Nothing here needs to be re-run to be checked. Every cell's raw result is in
[`data/runs/`](data/runs), and the scoring code that turned those cells into pass/fail
is in [`harness/`](harness). Re-running is for people who want to verify the cells
themselves rather than the grading.

## What a cell is

One cell is one headless Claude Code session in an isolated copy of a seeded repository:

```
claude -p "<task prompt>" \
       --model claude-haiku-4-5-20251001 \
       --plugin-dir <pack> \
       --output-format json
```

The workspace is preserved afterwards, which is what makes offline re-grading possible.

## Environment these numbers came from

| | |
|---|---|
| Agent | Claude Code CLI 2.1.233 |
| Model | `claude-haiku-4-5-20251001` |
| Fixture | `tiangolo/full-stack-fastapi-template` @ `cd83fc1` (v0.10.0, MIT) |
| Arms | `baseline`, `ponytail`, `karpathy`, `superpowers`, `mattpocock` |
| Runner | `benchmarks/agentic/run.py` from `DietrichGebert/ponytail`, with external arms added |

The pack arms load as Claude Code plugins, which is why the agent is a boundary
condition of these results and not a variable.

## Re-grading preserved cells (no API usage)

This is the cheap path and it exercises everything in `harness/`.

```bash
# 1. Point at the seeded fixture
export DIC_FIXTURE=/path/to/full-stack-fastapi-template

# 2. Frontend gate deps — the fixture is an npm workspace, so this hoists to the root
cd "$DIC_FIXTURE" && npm install

# 3. Backend gate deps
cd "$DIC_FIXTURE/backend"
python3 -m venv .venv-gate
./.venv-gate/bin/pip install -e .
./.venv-gate/bin/pip install pytest mypy ruff coverage

# 4. Re-grade a run
python3 harness/acceptance.py /path/to/runs/20260816-020247 --workers 4
```

The output should match the corresponding `*.acceptance.json` in `data/runs/`.

## Re-running the gate limitation probes

These need a Postgres instance because the backend suite is integration-level. Any
throwaway database works; do not point this at something you care about, since the
suite truncates its tables.

```bash
initdb -D /tmp/dic-pg/data -U postgres --auth=trust
pg_ctl -D /tmp/dic-pg/data -o "-p 55432 -k /tmp/dic-pg" start
createdb -h 127.0.0.1 -p 55432 -U postgres app

cd "$DIC_FIXTURE/backend"
POSTGRES_SERVER=127.0.0.1 POSTGRES_PORT=55432 POSTGRES_USER=postgres \
POSTGRES_PASSWORD=changethis POSTGRES_DB=app \
  ./.venv-gate/bin/python -m alembic upgrade head

cd -
PGPORT_NUM=55432 python3 harness/gate_probes.py --out data/gate-limits.json
```

The pristine fixture must pass every gate before any probe runs; the script exits if it
does not. It also re-checks that the fixture is clean after the last probe, and marks
the output `restored_clean: false` if it is not.

## Re-running cells (consumes API usage)

The runner is not vendored here — it is a fork of ponytail's own
`benchmarks/agentic/run.py` with external pack arms added. Two changes to it matter for
anyone reproducing:

1. **`NO_RUN` must not tell the agent how to handle ambiguity.** An earlier version
   added *"If the ticket is ambiguous, state your assumption in a comment and implement
   anyway"*. It did not fix what it targeted and it changed ponytail's datepicker output
   from `8, 21, 24, 24` lines to `24, 169, 172`. Adjusting one arm's fairness changed
   another arm's behaviour.

2. **Cells killed by a session limit must be marked invalid.** The CLI reports these as
   `is_error` with `terminal_reason: "api_error"`, not through the `error` key the
   harness checks, so they land as `valid=True, cost=0, turns=1, LOC=0`. In one 165-cell
   run this affected 72 cells and produced the reading "every pack wrote no code".
   `harness/acceptance.py` re-derives validity from `_claude.json` directly, so
   re-grading is safe even against a run recorded without the guard.

## What the raw data contains

`data/runs/<stamp>-<label>.results.json`
: One record per cell from the runner: arm, task, model, repetition, cost, duration,
turn count, token counts, permission denials, and the diff statistics.

`data/runs/<stamp>-<label>.acceptance.json`
: One record per cell from `harness/acceptance.py`: validity and its reason, which files
the agent created or modified, whether each gate passed, and the truncated compiler
output for every failure.

`data/gate-limits.json`
: Every injected defect, which gates fired, and whether the prediction written before
the run held.
