# Preregistration 2 — As-shipped regime, combinations, and coverage

**Written 2026-08-16, before the runs it describes.** Frozen on the same terms as
[`PREREGISTRATION.md`](PREREGISTRATION.md): predictions are not edited after the fact, and
failures are reported as failures.

## What the first round could not answer

| Gap | Why it matters |
|---|---|
| **superpowers was never validly measured** | It produced no code in 15 of 15 frontend cells and 16 of 17 backend cells. Bash was blocked for every arm, and superpowers' own README calls shell execution "Essential" (`README.md:261`). Those zeros are an artefact of the harness, not a property of the pack. It is the largest pack in the comparison. |
| **caveman was not measured at all** | A well-known pack with a published headline (−65% tokens) that JetBrains independently re-measured at −8.5%. |
| **Combination effects were text-only** | Six packs were compared by reading their rules against each other. Textual contradiction is not evidence of a behavioural effect. |
| **Frontend runs covered different task sets** | Run 1 included `dropzone` and not `rating`; run 2 the reverse. The two compile rates (37%, 40%) are therefore *similar levels on overlapping sets*, not a repeat of the same measurement. |

## Experiment A — as-shipped regime

Two regimes are measured and **never merged into one ranking**.

| Regime | Tool policy | Prompt | Question it answers |
|---|---|---|---|
| `blocked` (round 1) | Bash disallowed, all arms | ticket + a "write, don't run" instruction | What does the rule text do to code production? |
| `as-shipped` (this round) | Bash allowed, all arms | ticket only | What happens when a user actually installs this? |

Under `as-shipped`, an agent that asks a clarifying question and stops has produced a
**result**, not a failure. It is reported through `wrote_code`, never silently dropped.

The regime is selected by `PONYTAIL_REGIME=as-shipped`, which drops `--disallowedTools Bash`
and sends no appended system prompt. Everything else — model, fixture, plugin dirs, blocked
built-in skills, repetition count — is unchanged.

## Experiment B — combinations

Users do not install one pack. Whether the textual contradictions between packs produce a
measurable difference requires a 2×2 factorial on the same tasks:

```
baseline   |   A only   |   B only   |   A + B
```

The interesting quantity is the **interaction**: whether `A+B` differs from what the
individual effects predict.

Activation of two packs at once was verified before designing this, by asking the agent
whether specific injected strings were present in its system prompt:

| Loaded | contains `Fewest files possible` (ponytail) | contains `SUBAGENT-STOP` (superpowers) |
|---|:-:|:-:|
| nothing | no | no |
| ponytail | **yes** | no |
| superpowers | no | **yes** |
| both | **yes** | **yes** |

First pair: **ponytail × superpowers**, chosen because a mechanism is already documented.
superpowers withdraws itself from subagents with `<SUBAGENT-STOP>` while ponytail injects its
full ruleset into every subagent, so inside a superpowers-spawned implementation subagent only
ponytail survives and the TDD requirement quietly disappears — while the user believes both
are installed.

This is **not** claimed as the first work on skill interaction. Security-oriented studies of
skill composition exist (arXiv 2606.00448 executed 211,575 skill pairs). Those concern
permission and safety risk in functional skills. The claim here is narrower: behavioural norm
packs, measured on output quality, cost, and completion.

## Experiment C — coverage

- Add **caveman** as an arm across the round-1 task set, in the `blocked` regime, so it is
  directly comparable to the existing numbers.
- Add **dropzone** to the round-2 frontend task set so both frontend runs cover the same six
  tasks and the two compile rates become comparable measurements rather than similar levels.

**ECC is deliberately excluded from the shared table.** It operates at a different layer: it is
the only pack that blocks tool calls outright via `permissionDecision: 'deny'`
(`scripts/hooks/gateguard-fact-force.js:1153`), gating the first Edit/Write per file and the
first Bash per session behind a four-fact requirement. Its relationship to the other packs is
not contention but one-sided override, and averaging it into a comparison table would be
misleading. If measured, it is reported separately.

## Analysis committed to in advance

For cost and duration — reported in round 1 only as counts ("ponytail cost more on 4 of 6
backend tasks") — the analysis is fixed here before the numbers are seen:

- The unit of inference is the **task**, not the cell. Repetitions within a task are collapsed
  to a median first.
- Arms are compared **paired by task**, using the Wilcoxon signed-rank test.
- Effect sizes are reported with bootstrap confidence intervals over tasks.
- With 5–6 tasks per domain the test cannot reach significance for small effects. Where it
  cannot, the result is reported as **inconclusive**, never as "no difference".

## Predictions, recorded before seeing results

1. Under `as-shipped`, superpowers produces code in a **majority** of cells — that is, the
   round-1 zeros were a harness artefact.
2. Under `as-shipped`, cost and duration rise for **every** arm relative to `blocked`, because
   agents can now run builds and tests.
3. Compile pass rate rises under `as-shipped` for every arm, because agents can see their own
   errors. It rises **most** for the arms that mandate running tests (superpowers).
4. `ponytail+superpowers` produces **more** code than ponytail alone, because superpowers' TDD
   requirement adds test files that ponytail alone does not write.
5. The interaction is **not** simply additive: `A+B` will not equal `A + B` on delivered lines.
6. caveman shows a **smaller** LOC reduction than ponytail, since its published claim concerns
   output verbosity rather than code volume.

## Change log

- 2026-08-16 — initial version, written before execution.

## Outcome of the predictions

Recorded after the runs. The predictions above are left exactly as written. Two of the six
failed, and both failures were mine in the same direction: I assumed superpowers' zeros were
an artefact of my harness, and they were not.

| # | Prediction | Outcome |
|---|---|---|
| 1 | Under `as-shipped`, superpowers produces code in a majority of cells | **Failed.** 0 of 9. The round-1 zeros were not a harness artefact. |
| 2 | Cost and duration rise for every arm under `as-shipped` | **Held.** Median cost ×3.0 baseline, ×2.6 ponytail, ×2.0 karpathy, ×1.4 superpowers; duration ×2.4, ×2.5, ×2.0, ×1.3. |
| 3 | Compile pass rate rises under `as-shipped`, most for superpowers | **Not evaluable for superpowers** (no code to grade). Reported for the other arms in the results table. |
| 4 | `ponytail+superpowers` produces more code than ponytail alone | **Failed.** Median delivered lines 198 → 0. |
| 5 | The interaction is not simply additive | **Held, but not by the anticipated mechanism.** It is not that the effects combine unevenly; one arm zeroes the other out. |
| 6 | caveman shows a smaller LOC reduction than ponytail | **Held.** caveman −3.6% (p = 0.125, inconclusive) against ponytail −17.9% (p = 0.031, significant), paired across 7 tasks. |

### What superpowers actually does

The reason predictions 1, 4, and 5 came out the way they did is a single behaviour, and it is
the pack working as designed rather than failing:

> **Classification: Bounded.** This is a new component that builds on the existing React Hook
> Form + Zod + Radix UI infrastructure already in the codebase. […] Now let me ask a few
> clarifying questions to refine the design:
> **First question:** What's the primary use case for this wizard?
>
> <sub>`runs/20260816-113302/tmpl-fe-wizard__superpowers__haiku__0`, verbatim final output</sub>

Every valid superpowers cell was checked, not a sample:

| Condition | Cells ending in a clarifying question |
|---|--:|
| `blocked`, 12 tasks, both domains, haiku | 47 / 48 |
| `as-shipped`, 3 tasks, haiku | 18 / 18 |
| `as-shipped`, 3 tasks, **sonnet** | 3 / 3 |
| **Total** | **68 / 69** |

**Withdrawn 2026-08-19 (CLAIM-01): this table is superseded and is kept for the record.**
D-002 re-derived the same finding over the corrected corpus and reports **49 / 50**, and
that is the figure every published surface uses. Two things moved it. The withdrawn run
`20260815-225842` was excluded once withdrawal became a field on the record rather than a
prefix in a filename (PDX-016), and the regime of two sonnet runs was re-adjudicated from
documents rather than from filenames (PDX-017, DEC-019) — `20260816-222615` is adjudicated
`blocked` in `bench/DERIVATIONS.md` D-004, which is the opposite of the condition this
table files it under, and D-004 grades its own evidence for that as inference rather than
as machine-written. The finding itself is unchanged in direction and strength; only the
denominator and the per-condition rows moved.

The 18 as-shipped cells include the 9 `ponytail+superpowers` cells: loading ponytail alongside
it does not suppress the behaviour.

In an interactive session this is good behaviour — arguably better than guessing. In a headless
run, a CI job, or any unattended agent, it means **zero delivered code**, and the session ends
with a question nobody will answer. That is the finding, and it is a statement about the
deployment context, not about the quality of the pack's rules.

The sonnet row exists because the obvious objection to a haiku-only result is that a stronger
model would push through the ambiguity. It does not.

### Limits of this round

- One model family, two models. Nothing here speaks to other agent runtimes.
- Experiment A was cut from five frontend tasks to three (`datepicker`, `command`, `wizard`)
  once the as-shipped regime turned out to cost roughly three times as much per cell. The
  three retained tasks are the ones Experiment B also uses, which is why A and B share one
  factorial grid rather than being two separate runs.
- `colorpicker` appears in the as-shipped data with 3 cells from an interrupted run. It is
  excluded from the paired tests, because pairing one arm on more tasks than another is not a
  paired test. `analyze.py --tasks` does the exclusion; no cells were deleted.
