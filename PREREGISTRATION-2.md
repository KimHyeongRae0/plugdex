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
