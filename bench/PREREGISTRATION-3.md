# Preregistration — Round 3: does any of this survive a model people actually use?

Written and committed **before** the runs it predicts. That ordering is the only thing
that makes a prediction a prediction, and it is checkable in this repository's history.

## Why this round exists

Every fingerprinted cell in `data/runs/` is `claude-haiku-4-5` — 426 of them. Haiku is the
cheapest model in the family, and the obvious objection to every finding so far is that a
stronger model would behave differently: that packs are scaffolding a weak model needs and
a strong one ignores, or the reverse.

There is one exception already on record. A 3-cell probe
(`20260816-222615-superpowers-sonnet-probe`) ran superpowers on `claude-sonnet-4-6` and
produced no code in all three. It was graded into an acceptance record on 2026-08-17, so
it carries the same environment fingerprint as everything else.

This round is the same three questions on a model people pay for.

## Design

- **Model**: `claude-sonnet-4-6`. Deliberately the same string the probe used. Changing
  the model between a probe and its follow-up would make them incomparable, which is the
  drift this project measures against.
- **Tasks**: `tmpl-fe-datepicker`, `tmpl-fe-command`, `tmpl-fe-wizard` — the three the
  probe used.
- **Arms**: `baseline`, `ponytail`, `caveman`, `karpathy`, `mattpocock`, `superpowers`.
- **Reps**: 1. 18 cells.
- **Regime**: blocked (Bash disallowed, NO_RUN prompt appended) — the same regime as the
  majority of the round-one and round-two corpus.
- **Environment**: fingerprint `4b140e75d7dc1828` must be unchanged. If it moves, the run
  is not comparable to the existing corpus and this document says so before the fact.
- Claude Code `2.1.233`, the version the probe ran under.

18 cells at one repetition cannot rank packs and is not intended to. It is powered for the
binary questions — does the pack produce code, does the code build — which is where every
finding in this project has come from.

## Predictions

Written before any cell runs. Each is falsifiable and each has a stated way to fail.

1. **superpowers produces no code in all 3 sonnet cells**, reproducing the probe.
   *Fails if* any superpowers cell writes a source file.
   Confidence: high. It held in 68 of 69 valid haiku cells and 3 of 3 sonnet probe cells.

2. **mattpocock produces code in at least 2 of 3 cells.** The haiku corpus shows it
   producing code, and nothing about it is a workflow-gate pack.
   *Fails if* it produces code in 0 or 1.

3. **The build-failure rate on sonnet is lower than the 55% measured on haiku, and the
   difference is visible without statistics** — that is, sonnet's rate is below 40%.
   *Fails if* sonnet's rate is 40% or above.
   This is the prediction most likely to be wrong, and it is the one worth being wrong
   about: if a stronger model does not deliver more buildable code, "does it build" is a
   property of the task and the harness rather than the model.

4. **No pack beats baseline on build rate by a margin that would survive 3 cells.**
   *Fails if* any pack's build rate exceeds baseline's by 2 or more cells out of 3.
   This is a restatement of the round-one and round-two null at a new model. Predicting
   the null again is cheap; publishing it when it holds is the point.

5. **The caveman token headline still does not reproduce.** Its published claim is −65%
   output tokens. *Fails if* caveman's mean output tokens per cell are 65% below
   baseline's, or anywhere near it.

## What this round explicitly does not do

- **It does not test GPT.** Codex CLI 0.147.0 is installed and authenticated, but three of
  the seven arms — superpowers, mattpocock, and the ponytail+superpowers combination — are
  Claude Code *plugins* loaded through a SessionStart hook. They have no representation
  outside Claude Code. A GPT comparison can only carry the four text-injected arms
  (baseline, ponytail, caveman, karpathy), and that asymmetry has to be stated in the
  design rather than discovered in the results. It is its own preregistration.
- **It does not add repetitions.** Three cells per condition detects "produces nothing at
  all"; it does not estimate a rate. Any percentage reported from this round carries n=3
  next to it or it does not get reported.
- **It does not re-measure haiku.** The existing corpus stands.

## Recorded before the run

- Written: 2026-08-17
- Committed: see this file's commit in `git log` — it is the claim
- The runs it predicts appear afterwards in `data/runs/`, and the gap is checkable the
  same way `PREREGISTRATION-2.md`'s is.

## Outcome

Recorded 2026-08-20, after the run. `PREREGISTRATION.md:127` commits that *"Predictions that
fail will be reported as failed"*, and rounds 1 and 2 report outcomes; this round stopped at
"Recorded before the run" for three days. Every figure below is re-derived from
`data/runs/` rather than quoted, and the scenario `tests/e2e/PDX-033-*.sh` re-derives them
again.

All five predictions are reported. An earlier draft reported four and called one of those
undecidable; both omissions are corrected below and named in the notes.

| # | Prediction | Measured | Verdict |
|---|---|---|---|
| 1 | superpowers produces no code in all sonnet cells | 0 of 6 valid cells wrote a source file | **held** |
| 2 | mattpocock produces code in at least 2 of 3 | 2 of 2 valid cells wrote code, and both built | **held** |
| 3 | sonnet's build-failure rate is **below 40%** | **55%** — 6 of 11 code-producing cells failed their gate | **FAILED** |
| 4 | no pack beats baseline by 2 or more cells out of 3 | baseline built 0; ponytail built 2, mattpocock built 2 | **FAILED** — the trigger fired |
| 5 | caveman's −65% token headline does not reproduce | caveman mean out_tokens 6595 (n=3) against baseline 9902 (n=1) = **−33%** | **held** — a real reduction, and not the published one |

**Prediction 3 failed, and it is the one this round said was worth being wrong about.** Its own
text: *"if a stronger model does not deliver more buildable code, 'does it build' is a property
of the task and the harness rather than the model."* The measured rate on sonnet is 55%, which
is the same rate measured on haiku — the difference the prediction expected to be visible
without statistics is not visible at all.

**Prediction 4 failed, and an earlier version of this section said it was undecidable.** The
condition is written as *"Fails if any pack's build rate exceeds baseline's by 2 or more cells
out of 3."* Baseline built 0; ponytail built 2. The trigger fired, in the terms the
preregistration itself set, and the first draft of this table reported it as "not decidable"
on the ground that baseline contributed one valid sonnet cell. Report review round 1 caught
that. **Softening a preregistered failure because the sample is thin is the exact move a
preregistration exists to prevent** — the thinness was knowable when the condition was
written, and rewriting the condition after seeing the result is what makes a prediction not a
prediction.

The caveat stands beside the verdict rather than replacing it: baseline's single valid sonnet
cell makes this a weak observation, and it is one cell from being unmeasurable. That is a
reason to distrust the margin, not a reason to withhold the failure. Round 4 should give
baseline more cells before restating this null.

**Prediction 5 was missing entirely from the first draft of this section**, which reported
four of five. It is decidable and it held: caveman's output tokens are 33% below baseline on
sonnet — a real reduction, and less than half the −65% its published headline claims.

**What this round does not establish.** Eleven code-producing cells across five arms is a
sample that supports one comparison — prediction 3's rate against haiku's — and not the
per-arm ones. Nothing here re-opens the question of which pack is better; it closes the
question of whether the model was the reason the build rate was low. It was not.
