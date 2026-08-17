# Preregistration — Off-the-shelf vs From-scratch × Domain

**Written 2026-08-16, before the matrix run it describes.**

This document is frozen before execution. If anything below changes, the change and its reason
are recorded in [Change log](#change-log) rather than silently edited.

## Why this design

An earlier 180-cell run was abandoned at 30 cells. One reason dominates: in that task suite,
"frontend" and "a native control already exists" were perfectly entangled, and so were "backend"
and "you have to write it." Any effect we measured could not be attributed to either.

Choosing **domain** as the axis never terminates — frontend, backend, mobile, CLI, data pipelines,
and so on. Choosing **whether the correct answer is already sitting on the shelf** does terminate,
and it carries to domains we never measured.

ponytail's own documentation says the same thing: *"On irreducible code the arms converge."*

Existing data supports the axis. ponytail's LOC reduction, ranked (medians, n=3 per cell,
run `20260815-225842`):

| Task | Native / framework substitute | baseline → ponytail | Reduction |
|---|---|--:|--:|
| colorpicker | `<input type="color">` exists | 491 → 48 | **−90%** |
| datepicker | `<input type="date">` exists | 241 → 24 | **−90%** |
| wizard | none | 1058 → 354 | −67% |
| dropzone | `<input type="file">`, partial | 709 → 274 | −61% |
| command palette | none | 445 → 226 | −49% |

The two tasks with a native substitute are ranked first and second.

## Classification rule (fixed before execution)

> **Off-the-shelf** — the correct minimal answer is *to use something that already exists*:
> a platform-native control, the standard library, or a framework feature.
> The over-building trap is open.
>
> **From-scratch** — the correct answer is *to actually write the code*.
> There is nothing to reach for. Pack effects are expected to converge.

Every classification must cite **the specific substitute by name**. "Looks easy" is not a reason.

## Task assignment

|  | **Off-the-shelf** | **From-scratch** |
|---|---|---|
| **Frontend** | `tmpl-fe-datepicker`<br>`tmpl-fe-colorpicker`<br>`tmpl-fe-rating` | `tmpl-fe-command`<br>`tmpl-fe-wizard` |
| **Backend** | `tmpl-be-count`<br>`tmpl-be-search`<br>`tmpl-be-csv` | `tmpl-be-archive`<br>`tmpl-be-uniquetitle` *(new)*<br>`tmpl-be-dailycount` *(new)* |

### Justification

| Task | Class | Substitute |
|---|---|---|
| `tmpl-fe-datepicker` | off-the-shelf | HTML `<input type="date">` |
| `tmpl-fe-colorpicker` | off-the-shelf | HTML `<input type="color">` |
| `tmpl-fe-rating` | off-the-shelf | radio group + CSS, or `<input type="range">` |
| `tmpl-fe-command` | from-scratch | no native command palette; filtering and keyboard navigation must be written |
| `tmpl-fe-wizard` | from-scratch | no native multi-step form; step state and validation must be written |
| `tmpl-be-count` | off-the-shelf | `select(func.count())` — **already present in `app/api/routes/items.py`** |
| `tmpl-be-search` | off-the-shelf | SQLModel `col(Item.title).ilike(...)`, one line |
| `tmpl-be-csv` | off-the-shelf | stdlib `csv` + FastAPI `StreamingResponse` |
| `tmpl-be-archive` | from-scratch | new column + alembic migration + routes; the framework provides none of it |
| `tmpl-be-uniquetitle` | from-scratch | constraint + migration + 409 handling; owner-scoped uniqueness has no off-the-shelf form |
| `tmpl-be-dailycount` | from-scratch | date bucketing plus **zero-filling absent days**; the zero-fill cannot be delegated |

### Excluded from analysis (not run)

`tmpl-fe-dropzone`, `tmpl-be-duplicate`, `tmpl-be-bulkdelete`. Their classification is genuinely
contested: `dropzone` has `<input type="file">` but drag-and-drop must be written, and `duplicate`
and `bulkdelete` sit between following a framework pattern and writing real logic.
**Ambiguous tasks are not forced into a quadrant.**

## Confounds that remain (to be stated on publication)

- **Difficulty is not controlled.** From-scratch tasks are generally larger. An observed difference
  may be difficulty rather than shelf-availability. LOC is reported as a covariate.
- **One fixture repository**: `tiangolo/full-stack-fastapi-template` @ `cd83fc1` (v0.10.0, MIT).
- **One model**: `claude-haiku-4-5-20251001`.
- **One agent**: Claude Code CLI 2.1.233. Most of the packs under test ship *as Claude Code plugins*
  (SessionStart hooks, `<SUBAGENT-STOP>`, plugin cache dirs), so the agent is a boundary condition
  rather than a free axis.
- **The frontend from-scratch quadrant holds 2 tasks** against 3 in the others.
- The two new backend tasks were **written for this experiment**, by the same author, with the
  classification already in mind.

## Execution conditions

- Arms: `baseline`, `ponytail`, `karpathy`, `superpowers`, `mattpocock`
- 11 tasks × 5 arms × 3 repetitions = **165 cells**
- **Bash stays blocked**, matching run `20260815-225842` so the frontend compile rate measured there
  (37%) is directly comparable. Opening Bash is a separate experiment. One change at a time.
- `run.py`'s `NO_RUN` is reverted to remove the sentence
  *"If the ticket is ambiguous, state your assumption in a comment and implement anyway…"*.
  Adding it was instrument failure #9: it did not fix what it targeted (superpowers still produced
  no code) and it moved ponytail's datepicker LOC from `8,21,24,24` to `24,169,172`.

## Acceptance gates

Each domain is graded with the repository's own configuration, so that strictness is comparable.

| Domain | Gate | Strictness comes from |
|---|---|---|
| Frontend | `tsc -p tsconfig.build.json --noEmit` + `vite build` | `strict: true`, `noUnusedLocals`, `noUnusedParameters` |
| Backend | `mypy app` + `ruff check app` + import smoke | `[tool.mypy] strict = true`; ruff `E,W,F,I,B,C4,UP,ARG001,T201` |

The backend gate is **delta-based**: the pristine fixture already emits one mypy error
(`app/utils.py`, `no-any-return`), so only diagnostics absent from the pristine baseline count.
Scoring it absolutely would have marked every backend cell as failing and produced the
false headline "the packs collapse on the backend."

Both gates passed a negative control before use — pristine passes, an injected type error is
caught, an injected undefined name is caught, an injected unused import is caught, an injected
unused argument is caught, and removing the probe restores a clean run.

Results are reported in two tiers: **strict** (the repo's build configuration as-is) and
**lenient** (unused-variable diagnostics ignored).

## Predictions, recorded before seeing results

1. ponytail's LOC reduction is **larger** in off-the-shelf cells than in from-scratch cells.
2. In from-scratch cells, LOC differences between arms **converge**.
3. Compile pass rate is driven more by **task difficulty** than by arm.
4. Under a blocked Bash, superpowers produces **no code in every cell** — an invalid measurement
   for that arm, not a finding about the pack.

Predictions that fail will be reported as failed.

## Change log

- 2026-08-16 — initial version, written before execution.

## Outcome of the predictions

Recorded after the runs. The predictions above are left exactly as written.

| # | Prediction | Outcome |
|---|---|---|
| 1 | ponytail's LOC reduction is larger in off-the-shelf cells | **Partly held.** Frontend −76% vs −31%. Backend −21% vs −18%, no difference. |
| 2 | LOC differences between arms converge in from-scratch cells | **Held on the backend** (all arms within ±5% of baseline except ponytail at −18%). Frontend from-scratch still showed a −27% to −34% ponytail effect, so convergence is partial. |
| 3 | Compile pass rate is driven more by task difficulty than by arm | **Not supported.** Pass rate varied more by arm (ponytail 89% vs baseline 22% on off-the-shelf frontend) than by zone. |
| 4 | superpowers produces no code in every cell under a blocked Bash | **Held, with one exception.** 15 of 15 frontend cells and 16 of 17 backend cells produced no code. The wording "every cell" was too strong. |

A post-hoc refinement the preregistration did not anticipate: the effect follows a
**gradient** in how complete the existing substitute is, not a binary off-the-shelf split.
This is an observation made after seeing the data and is labelled as such wherever it appears.

## Instrument failures found during this work

Fourteen so far, of which nine pointed at a plausible "no difference" or "total collapse"
conclusion. Four were found during the runs described here:

| # | Failure | The false conclusion it would have produced |
|---|---|---|
| 10 | The pristine backend already fails mypy; grading absolutely rather than by delta | "The packs collapse on the backend" (every cell 0%) |
| 11 | Modern ruff's default output does not match a `file:line:col: CODE msg` parser | "The backend is cleaner than the frontend" (unused imports counted as zero) |
| 12 | Session-limit deaths are reported as `is_error`, not through the key the harness checks | "Every pack wrote no code on wizard, rating, and command" (72 of 165 cells) |
| 13 | Change detection compared paths against a manifest with no hashes, so edits were invisible | "Half the backend cells wrote no code" (43 of 85) |

Failure 14 was found by the gate probes themselves: on a parse error mypy stops after one
diagnostic, which matched the baseline count and let syntax errors through the backend gate.
Comparing diagnostic sets instead of counts fixed it, and `be-syntax-error` is now a probe.

### Two more, found while preparing round two

| # | Failure | The false conclusion it would have produced |
|---|---|---|
| 15 | Four packages (`cmdk`, `@radix-ui/react-popover`, `react-day-picker`, `date-fns`) were installed into the shared `node_modules` mid-experiment and declared by no `package.json` | "The frontend compile rate reproduced at 37% and 40%" — the two runs were graded against different dependency sets |
| 16 | The runner recorded the model, the date, and the Claude Code version, but **not the prompt it sent** | The same "reproduced twice" claim; the two runs also differed in the appended system prompt, and nothing in the output said so |

Failure 15 was found by an impossible result: the same task, same arm, same model, same regime
went from 4/12 passing to 12/12. `npm ls` labelled the four packages `extraneous` — installed,
required by nothing. Removing them (`npm prune`) left the pristine fixture passing every gate.
`acceptance.py` now records an environment fingerprint (`npm_fingerprint`, the hash of every
installed package at its installed version) in every result file, lists any extraneous package,
and records per cell whether it was graded against the shared dependency set or one the agent
installed itself. Results with different fingerprints are not compared.

Pruning did not close the gap, which is how failure 16 surfaced. Recovering the two runs'
configurations from the session history showed they had been given different instructions: run
`20260815-225842` carried an appended sentence —

> If the ticket is ambiguous, state your assumption in a comment and implement anyway — do not
> stop to ask clarifying questions. This is a ticket, not a conversation.

— that was removed before every later run, as the correction for failure 9. Regraded in one
environment on the five tasks they share, the two runs are 29.3% and 43.3% (Fisher exact
p = 0.129, inconclusive at this sample size). **They are not a replication of each other.** The
earlier claim that the frontend rate reproduced across two runs is withdrawn.

The mechanism is visible in the cells: told to implement anyway, agents delivered more —
5 to 7 files including tests and example components, against 1 to 2 files without the
instruction — and more code failed to typecheck. Whether that instruction genuinely lowers
compile rates is a separate question this data cannot settle at n = 58 versus 60.

Both failures share one cause: **the experiment was edited while it was running.** The fixture
gained packages, and the harness gained and lost a sentence, with no record of either in the
output. Both halves are now closed: the fingerprint covers the environment, and the runner writes
`_invocation.json` next to every cell — the full resolved argv, the ticket, the appended system
prompt, and the regime — plus the regime, the `NO_RUN` text, and a hash of the runner itself into
each run's `results.json`. Any two runs can now be checked for comparability before their numbers
are put in the same table.

Both fixes postdate the runs published here, and the data shows it. Every
`*.acceptance.json` in `data/runs/` carries a fingerprint because grading was redone
afterwards in one environment; no `*.results.json` does, because those were written by the
runner as it stood at the time. `_invocation.json` likewise exists only for cells run after
the change. The published corpus is therefore fingerprinted at the grading layer and not at
the execution layer — a reader checking a `results.json` for `npm_fingerprint` will not find
one, and that is a fact about when the instrument was fixed rather than a gap in it.
