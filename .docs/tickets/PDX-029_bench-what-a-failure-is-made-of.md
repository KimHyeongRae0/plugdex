# PDX-029 — bench: what a failure is made of

- Status: TODO
- Created: 2026-08-19

## 1. Goal

The catalogue publishes a failure rate and never says what the failures are made of. Both
halves of the gate turn out to contain a large minority of lint-grade failures, and neither
is disclosed.

**Frontend.** Of 58 graded frontend failures in the published `blocked` pool, **16 fail on
unused-declaration errors alone** — `TS6133`, "declared but its value is never read", almost
all of them an unused `import React`. Spread across arms: baseline 4, caveman 4, mattpocock
3, ponytail 3, karpathy 2. Excusing them moves the headline frontend rate from **44%
(45/103) to 59% (61/103)** — a 15-point swing in the level, with the arm ordering unchanged
(ponytail 73→86, mattpocock 50→65, karpathy 40→50, caveman 29→48, baseline 25→45).

**Backend.** The same shape, already measured: 11 of 51 backend failures fail on ruff `I001`
alone — import-block ordering.

So **27 of 109 gate failures across both domains are lint-grade**, and the site says nothing
about it.

**What this ticket is not.** It is not a claim that the grade is wrong. The gate runs the
fixture's own `tsconfig.build.json` with the fixture's own `noUnusedLocals` and
`noUnusedParameters`, disclosed at `bench/README.md:30`, and under the repository's own
build command a `TS6133` is a failure. That framing is defensible and stays. What is
indefensible is publishing "55% of it fails" to a reader who pictures broken code, when for
a quarter of those cells the defect is an unused import.

**One thing the record genuinely cannot support.** `acceptance.py:431` short-circuits: when
typecheck fails, the bundler is never run and the record stores
`build_reason: "skipped-typecheck-failed"`. So for those 16 cells the field named `build` is
a typecheck result, and the corpus **cannot distinguish "would not bundle" from "failed a
lint-grade type rule"**. Measured directly for this ticket, in a minimal project with the
same compiler settings: `tsc --noEmit` exits 1 on `TS6133` while `vite build` succeeds and
emits a bundle. The two gates disagree on exactly this input, and the corpus recorded only
one of them.

## 2. Scope

### Allowed
- `bench/harness/acceptance.py` — recording the bundler outcome even when typecheck fails,
  and a severity classification of what failed
- `bench/data/runs/**` — re-grading from preserved workspaces only; no new measurement
- `bench/README.md`, `bench/DERIVATIONS.md` — the composition, under CLAIM-01
- `packages/data/**`, `packages/site/**` — publishing the composition, with tests
- `tests/e2e/PDX-029-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision

### Not Allowed
- Reclassifying a lint-grade failure as a pass. The grade does not move; only what a reader
  is told about it does
- Changing the gate's strictness, or replacing the fixture's `tsconfig.build.json` settings.
  The repository's own build is the standard, and softening it to raise our numbers is the
  worst available outcome
- Publishing the "if excused" rate as a headline, or beside the real one without saying which
  is which
- Any composition figure typed into the site rather than derived from the records (DATA-01)

## 3. Acceptance Criteria

- [ ] AC-1: **every failure carries a derived severity**, computed from the recorded
      diagnostics rather than typed: `lint-grade` (the failure's entire diagnostic set is
      unused-declaration or import-ordering codes), `type-error`, `missing-module`,
      `syntax`, `bundler`. The code lists live in one place with the reason each code is
      where it is, and a diagnostic code no list claims makes the cell `unclassified` and
      says so — never silently `type-error`.
- [ ] AC-2: **the site publishes the composition beside the rate.** A reader who sees a
      failure rate can see, in the same view, what the failures were: the counts per
      severity, per domain. The number that is published as the headline does not change.
- [ ] AC-3: **the bundler outcome is recorded even when typecheck fails.** `acceptance.py`
      runs `vite build` regardless and stores both results, so a future reader can tell
      "would not bundle" from "failed the repository's type rules". The grade stays
      `typecheck AND build`, unchanged — this adds a field, it does not move a threshold.
- [ ] AC-4: **the 16 cells are re-graded under AC-3 and the answer is published**, whichever
      way it comes out. If they bundle, the corpus says so and the composition claim is
      exact; if some do not, that is a stronger result for the original grade and is
      published just as plainly. A cell whose workspace is gone is listed as unre-gradable
      rather than assumed.
- [ ] AC-5: **`bench/README.md`'s failure claim is corrected under CLAIM-01** to state the
      composition, keeping the previous wording, its date and its cause visible.
- [ ] AC-6: **the classification is negative-controlled.** A planted failure whose diagnostic
      set mixes `TS6133` with a real type error must classify as `type-error`, not
      `lint-grade` — the whole set decides, never the first code. Golden cases pin both
      directions.

## 4. Edge Cases & Error Handling

- A cell fails typecheck with no parseable diagnostic output (a timeout, a crash) → severity
  `unclassified` with the reason. The existing `typecheck_reason` field already carries
  values like `skipped-typecheck-failed`, which are process facts rather than diagnostics.
- The bundler now runs on a cell whose code does not compile and takes a long time or hangs
  → the existing `BUILD_TIMEOUT` applies and a timeout is recorded as a timeout, not as a
  bundler failure. A check that could not run must never be recorded as a check that failed.
- Excusing lint-grade failures would change the arm ordering → it does not on this corpus,
  and the e2e asserts that rather than trusting this sentence, so the day it stops being
  true the assertion says so.
- The `as-shipped` pool has a different composition from `blocked` → derived per condition;
  the two are never pooled (DEC-020).

## 5. E2E Mapping

- `tests/e2e/PDX-029-a-failure-has-a-shape.sh` — AC-1, AC-2, AC-6: severities derived from
  the live records, rendered on the page, planted mixed-diagnostic and unknown-code cases
  classifying correctly, and the ordering-invariance check
- `tests/e2e/PDX-029-the-bundler-is-asked.sh` — AC-3, AC-4, AC-5: both outcomes recorded per
  cell, the re-graded 16 published with their answer, and the corrected claim carrying its
  previous reading

## 6. References

- `bench/harness/acceptance.py:12` (the gate pair), `:424-436` (the short-circuit)
- `bench/README.md:30` — the gate table naming `noUnusedLocals` / `noUnusedParameters` as
  the fixture's own settings, which is why this ticket does not touch the grade
- The `blocked` acceptance records — every figure in §1 is derived from
  `bench/data/runs/*.acceptance.json` and must be re-derived rather than trusted
- PDX-028 — the gate-set alignment ticket; both re-grade, so they must not run concurrently
- CLAIM-01, DATA-01 in `CLAUDE.md`
