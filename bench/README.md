# does-it-compile

**Agent skill packs promise less code. This measures whether it builds.**

A growing category of "behavior norm packs" for coding agents — ponytail, superpowers, caveman,
Karpathy's `CLAUDE.md`, Matt Pocock's skills — advertise headline numbers: less code, fewer tokens,
lower cost. Those numbers are real measurements, measured against tools that report tokens, cost and diff size — not against a build. We found no published work that grades behaviour-norm packs by whether the code they deliver compiles — what we read is recorded in [`../.docs/references/`](../.docs/references/README.md).

ponytail's own harness scores a task as correct like this:

```python
sc = {"correct": 1 if stats.get("total_loc", 0) > 0 else 0}
```
<sub>`benchmarks/agentic/run.py:303`</sub>

"Correct" means a diff line exists.

This repository measures what happens when you check.

## The measurement

Each cell is one headless Claude Code session in an isolated copy of a real repository
(`tiangolo/full-stack-fastapi-template` @ `cd83fc1`), running one pack against one ticket.
Delivered code is then graded with **the repository's own build configuration** — nothing
invented for the benchmark.

| Domain | Gate | Strictness comes from |
|---|---|---|
| Frontend | `tsc -p tsconfig.build.json --noEmit` + `vite build` | `strict`, `noUnusedLocals`, `noUnusedParameters` |
| Backend | `mypy app` + `ruff check app` + import smoke | `[tool.mypy] strict = true` |

Every run below was graded in one environment, fingerprinted in the result files
(`npm_fingerprint: 4b140e75d7dc1828`, 256 packages, no extraneous ones), from the same plain
ticket with no extra instruction:

| Run | Domain | Tasks | Cells with code | Strict | Lenient |
|---|---|--:|--:|--:|--:|
| `20260816-020247` + `20260816-094325` | frontend | 6 | 72 | **47%** | 64% |
| `20260816-010513` | backend | 6 | 69 | **42%** | — |

Two domains, two different gate stacks, 141 cells that produced code: **55% of it fails its
domain's gate.** Lenient ignores unused-variable diagnostics.

**Corrected 2026-08-19 (CLAIM-01).** This sentence used to read "55% of it does not build",
and for part of the pool that verb is false. The backend gate is not a build: it is
`bool(be_files and ok_import and not new_diags)` — the code imports and introduces no new
lint or type diagnostic. Over the published `blocked` pool, 11 of 51 backend failures fail
on exactly one diagnostic, ruff `I001`, an unsorted import block. That code builds, imports
and runs. Read strictly as "did not build or did not import", the figure over the 189
code-producing cells of that pool is **52%**, not 58%; read as "failed its gate" it is 58%.
Both are stated because they answer different questions, and the original sentence answered
neither. Also undisclosed here until now: this 141-cell pool is the four arms common to both
frontend runs and silently drops caveman's cells; including them the pool is larger and the
rate moves. The per-domain figures the site publishes carry their own denominators and are
unaffected.

That is a level, not a ranking, so it needs no significance test. Rankings between packs
are a different claim and this repository does not make one.

This paragraph used to give a reason: "the best pairwise Fisher exact result was
p = 0.060." **That claim is withdrawn.** It does not reproduce anywhere in the corpus it
was computed on — 424 arm pairs were swept and none of them lands on it — and the best
pairwise result there was in fact p = 0.0009, which is significant rather than not. The
search, the likely origin of the number, and what the corpus says instead are written up
as D-001 in [`DERIVATIONS.md`](DERIVATIONS.md) and reproducible with
`python3 bench/harness/derive_d001.py`. We still do not rank packs, for the reasons
recorded there.

The level is a property of this task set, not a constant. It ranges from 12/12 passing on
"add a file upload dropzone" to 2/12 on "add a date picker" and 2/12 on "add a form wizard."
A benchmark that picks easy tickets will report a much better number, honestly.

A third frontend run, `20260815-225842`, is **excluded from this table**. It was reported here
as a replication at 37%; it was not one. It was given an extra instruction the other runs were
not, and the two runs were also graded against different sets of installed packages. Both
mistakes, and what they did to the numbers, are written up as instrument failures 15 and 16
in [`PREREGISTRATION.md`](PREREGISTRATION.md).

## The pack that never writes any code

superpowers is the largest pack in this comparison by a wide margin. Given a ticket, it
classifies the work and then asks the user a clarifying question — and stops:

> **Classification: Bounded.** This is a new component that builds on the existing React Hook
> Form + Zod + Radix UI infrastructure already in the codebase. […] Now let me ask a few
> clarifying questions to refine the design:
> **First question:** What's the primary use case for this wizard?

In an interactive session that is defensible behaviour, probably better than guessing. Run
headless — a CI job, a batch, any unattended agent — it means the session ends with a question
nobody will answer and **no code at all**.

Every valid superpowers cell was checked, not a sample:

| Condition | Cells ending in a clarifying question |
|---|--:|
| Bash blocked, 12 tasks, both domains, haiku | 34 / 35 |
| Installed as shipped, Bash allowed, haiku | 9 / 9 |
| Bash blocked, **sonnet** | 6 / 6 |
| **Total** | **49 / 50** |

This table previously read 47/48, 18/18, 3/3 and **68 / 69**. Those denominators do not
reconcile with the committed records under any pooling, and the corrected counts are
derived from them per run in [`DERIVATIONS.md`](DERIVATIONS.md) as D-002. The result is
unchanged — 98% either way, and the single exception is the same cell — but a count nobody
can reproduce is not evidence, whichever direction it points.

Installing ponytail alongside it does not change this: 9 of 9 `ponytail+superpowers` cells also
stop to ask. Median delivered lines on the shared tasks: baseline 378, ponytail 198,
superpowers 0, ponytail+superpowers 0.

This was predicted to go the other way. [`PREREGISTRATION-2.md`](PREREGISTRATION-2.md) recorded,
before the run, that the earlier zeros were probably an artefact of blocking Bash and that
superpowers would produce code in a majority of cells once it could run a shell. It produced
none, and that prediction is marked failed.

## Where the packs did differ

Reduction in delivered lines versus no pack, by how complete a substitute already existed
for the thing being asked for:

| The correct answer is… | Tasks | Lines vs baseline |
|---|---|--:|
| a native single-element control (`<input type="date">`, `type="color"`) | datepicker, colorpicker | **−92%, −93%** |
| assembled from primitives (radio group + CSS) | rating | −42% |
| written from scratch | command palette, form wizard | −27%, −34% |
| a framework helper (`func.count()`, `ilike`) | 6 backend tickets | −18% to −21% |

The gradient, not the binary split, is the finding — and it was visible only after the run.
The preregistration predicted a binary off-the-shelf/from-scratch difference; that held on
the frontend (−76% vs −31% averaged) and did not hold on the backend (−21% vs −18%).

Two packs with very large followings showed no measurable reduction at all. Median delivered
lines across all frontend tasks: baseline 304, karpathy 303, mattpocock 271, ponytail 89.

## What this gate cannot see

Reporting "it compiles" as "it works" would be false. [`data/gate-limits.json`](data/gate-limits.json)
records how false, by injecting known defects into the pristine fixture and checking which
gates fire.

**Five of eight** injected defects pass every gate this benchmark actually runs — three are
caught. With `pytest` in the set it is four and four; the probe marked `pytest`-only below is
the one that moves:

<!-- withdrawal: probe-gate-set -->
> **Corrected 2026-08-20 (CLAIM-01).** This section said *"The repository's own 60-test
> backend suite runs on every probe"* and published *"Four of eight injected defects passed
> every gate"*. The probe harness does run that suite — `bench/harness/gate_probes.py:82` —
> but the grader that produced every published number does not: `grep -c pytest
> bench/harness/acceptance.py` returns **0**. So the table credited a catch to a gate the
> benchmark does not use. Under the shipped gate **three of eight are caught and five pass**.
> Caught: `be-type-error` (mypy), `be-syntax-error` (mypy/ruff/import), `fe-type-error`
> (typecheck/build). Passing: `be-owner-filter`, `be-sort-flip`, `be-off-by-one`,
> `fe-render-nothing`, and `be-swallow-404` — the last is the probe that moves, because its
> only catcher is `pytest`.
>
> **Corrected a second time, same day, before this shipped.** The first version of this
> correction said *"the honest count under the shipped gate is three of eight"* in a sentence
> about what **passed** — putting the caught count where the passed count goes, which
> understates how much slips through and does so in the direction that flatters the
> instrument. Report review round 1 found it by reading `data/gate-limits.json` rather than
> the sentence; report review round 2 found it still standing in this record after the live
> sentence above had been fixed. The assertion that let the first version through was a
> string match for "three of eight"; it now derives both counts from the probe records and
> checks that the published sentence states the passed one. The cause was a validation harness stricter than the thing it
> validates, which overstates the instrument in exactly the direction that flatters it.
> Adding the suite to the grader is PDX-028, and PDX-028's own AC-2b records why it cannot
> land first.
<!-- /withdrawal: probe-gate-set -->

The eight, with the gate set each was caught by:

| Injected defect | Caught by |
|---|---|
| type mismatch | mypy |
| syntax error | mypy, ruff, import, pytest |
| missing item returns `None` instead of 404 | pytest **only — a miss under the shipped gate** |
| frontend type mismatch | tsc, vite |
| **owner filter dropped — other users' rows leak** | **nothing** |
| **sort direction reversed** | **nothing** |
| **page size off by one** | **nothing** |
| **component renders nothing** | **nothing** |

So the honest scope is: this measures whether delivered code is alive, not whether it is
correct. The share that fails its gate is real. The share that passes is unproven — and for
the backend half, "passes" means it imported cleanly and added no diagnostic, which is a
weaker statement than "it builds" and a much weaker one than "it works".

One probe prediction failed and is recorded as failed: `be-swallow-404` (a missing item returns
`None` instead of raising 404) was predicted to slip through, and the repository's own test suite
caught it. Seven of eight predictions held.

## Method commitments

These are the reasons to trust a number here rather than elsewhere.

1. **Preregistration before execution.** Task classification and predictions are committed before
   the run, so they cannot be fitted to the result.
2. **Gates are negative-controlled.** Every acceptance gate must pass the pristine fixture, catch
   an injected type error, catch an injected undefined name, catch an injected unused import, and
   return to clean when the probe is removed. A gate that has not been shown to fail on broken
   code is not evidence that code works.
3. **Instrument failures are published, not hidden.** Nineteen have been found in this project
   so far. Nine of them produced a plausible "no difference between packs" or "total collapse"
   conclusion. One was introduced by the author while trying to make an arm fairer, and two
   invalidated a headline that had already been written here. The three most recent share a
   different shape: a check that never ran reporting the same thing as a check that passed —
   a timeout recorded as corrupt output, a missing gate recorded as zero diagnostics, and a
   missing environment audit read as a clean environment. They are documented because in this
   field the hard part is not measuring — it is telling a real null from a broken instrument.
4. **Results that turn out not to mean what was claimed are withdrawn in place**, with the
   number, the cause, and what replaced it. The "reproduced across two runs" claim above was
   the first to go; the derivations behind the rest are in [`DERIVATIONS.md`](DERIVATIONS.md).
5. **Invalid cells are counted in the denominator**, with their reasons.
6. **Raw cell data and workspaces are published**, so a number can be checked without rerunning it.

## Scope and limits

Everything measured so far is conditional on one fixture repository, two models
(`claude-haiku-4-5` throughout, and `claude-sonnet-4-6` across all six arms on three frontend
tasks in round three), and one agent (Claude Code CLI 2.1.233). Most packs under test ship as Claude Code
plugins, so the agent is a boundary condition rather than a variable.

Six frontend and six backend tickets is a small task set, and the per-task spread is larger than
any difference between packs. Paired arm comparisons at this size reach significance only for
large effects; where they do not, this repository says *inconclusive* and not *no difference*.

No claim here extends past those conditions.

## License

MIT.

## Withdrawn claims

<!-- withdrawal: premise -->
> **Withdrawn 2026-08-20 (CLAIM-01).** This paragraph used to say the packs' numbers were
> measured *"in every published benchmark we could find, without checking that the delivered
> code compiles"*, and `bench/README.md` opened with *"Almost nobody checks whether it
> builds."* Both are universal claims about a literature nobody had surveyed. A research pass
> on 2026-08-19 opened the cited works and found execution-based grading in more than one of
> them, so the claim is false as written. What survives is narrower and is what the paragraph
> now says: no published work grades **behaviour-norm packs** by whether the delivered code
> builds. The cause was a pitch written before the survey; the replacement is above.
<!-- /withdrawal: premise -->
