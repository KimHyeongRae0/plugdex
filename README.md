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

| Run | Domain | Cells with code | Strict | Lenient |
|---|---|--:|--:|--:|
| `20260815-225842` | frontend | 57 | **37%** | 56% |
| `20260816-020247` | frontend | 60 | **40%** | 65% |
| `20260816-010513` | backend | 69 | **42%** | — |

Three runs, two domains, two different gates, one number: **around 60% of the code these
packs deliver does not build.** Lenient ignores unused-variable diagnostics.

That is a level, not a ranking, so it needs no significance test. Rankings between packs
are a different claim and this repository does not make one — the best pairwise Fisher
exact result was p = 0.060.

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
correct. The 60% that fails is real. The 40% that passes is unproven.

## Method commitments

These are the reasons to trust a number here rather than elsewhere.

1. **Preregistration before execution.** Task classification and predictions are committed before
   the run, so they cannot be fitted to the result.
2. **Gates are negative-controlled.** Every acceptance gate must pass the pristine fixture, catch
   an injected type error, catch an injected undefined name, catch an injected unused import, and
   return to clean when the probe is removed. A gate that has not been shown to fail on broken
   code is not evidence that code works.
3. **Instrument failures are published, not hidden.** Eleven have been found in this project so
   far. Six of them produced a plausible "no difference between packs" conclusion. One was
   introduced by the author while trying to make an arm fairer. They are documented because in
   this field the hard part is not measuring — it is telling a real null from a broken instrument.
4. **Invalid cells are counted in the denominator**, with their reasons.
5. **Raw cell data and workspaces are published**, so a number can be checked without rerunning it.

## Scope and limits

Everything measured so far is conditional on one fixture repository, one model
(`claude-haiku-4-5`), and one agent (Claude Code CLI 2.1.233). Most packs under test ship as
Claude Code plugins, so the agent is a boundary condition rather than a variable.

No claim here extends past those conditions.

## License

MIT.
