# does-it-compile

**Agent skill packs promise less code. Almost nobody checks whether it builds.**

A growing category of "behavior norm packs" for coding agents — ponytail, superpowers, caveman,
Karpathy's `CLAUDE.md`, Matt Pocock's skills — advertise headline numbers: less code, fewer tokens,
lower cost. Those numbers are real measurements. They are also, in every published benchmark we
could find, measured **without checking that the delivered code compiles**.

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

Two domains, two different gate stacks, 141 cells that produced code: **55% of it does not
build.** Lenient ignores unused-variable diagnostics.

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
gates fire. The repository's own 60-test backend suite runs on every probe.

Four of eight injected defects passed **every** gate:

| Injected defect | Caught by |
|---|---|
| type mismatch | mypy |
| syntax error | mypy, ruff, import, pytest |
| missing item returns `None` instead of 404 | pytest |
| frontend type mismatch | tsc, vite |
| **owner filter dropped — other users' rows leak** | **nothing** |
| **sort direction reversed** | **nothing** |
| **page size off by one** | **nothing** |
| **component renders nothing** | **nothing** |

So the honest scope is: this measures whether delivered code is alive, not whether it is
correct. The 55% that fails is real. The 45% that passes is unproven.

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
