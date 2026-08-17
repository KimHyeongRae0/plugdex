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
