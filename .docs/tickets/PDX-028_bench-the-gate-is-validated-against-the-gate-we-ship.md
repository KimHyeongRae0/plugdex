# PDX-028 — bench: the gate is validated against the gate we ship

- Status: TODO
- Created: 2026-08-19

## 1. Goal

This project validated its measurement gate properly and then published the validation of a
**different gate**.

`bench/harness/gate_probes.py` injects eight known defects into the pristine fixture,
records which gates fire, and writes each `expect_caught` prediction before the run. Four of
the eight passed every gate, and `bench/README.md` publishes that table under the heading
*What this gate cannot see*. One prediction failed and is recorded as failed. That is real
construct-validity work and it stays.

The defect is in the alignment. `gate_probes.py:backend_gates()` runs **four** gates — mypy,
ruff, import, **pytest**. `bench/harness/acceptance.py:379-390`, which produced every
published number, runs **three**: `grep -n pytest bench/harness/acceptance.py` returns
nothing. The probe `be-swallow-404` (a missing item returns `None` instead of raising 404)
has `caught_by: ["pytest"]` and nothing else, so **under the gate this benchmark actually
uses, it is a miss**. The published table credits a catch to a gate that is not part of the
measurement, and the sentence beside it — "The repository's own 60-test backend suite runs
on every probe" — reads as though the suite is part of the instrument. It is not.

Corrected count under the shipped gate: **3 of 8 caught, 5 of 8 missed.**

The same asymmetry points at the fix. The fixture ships a 60-test suite, `gate_probes.py`
already runs it successfully, and the probe data already proves it catches a semantic defect
the shipped gate misses. Adding it to `acceptance.py` as a PASS_TO_PASS regression check is
the standard practice the harness's own docstring cites (arXiv 2503.15223: 7.8% of patches
judged to solve an issue were functionally incorrect, and half of those were regressions
breaking unrelated functionality). The cost is a Postgres container in the grading path.

## 2. Scope

### Allowed
- `bench/harness/acceptance.py` — the backend gate, and the field that records what ran
- `bench/harness/gate_probes.py` — reporting per gate-set rather than per gate
- `bench/data/gate-limits.json` — regenerated, not edited
- `bench/README.md`, `bench/REPRODUCE.md` — the corrected table and how to reproduce it
- `packages/data/**`, `packages/site/**` — reading and publishing which gates a cell was
  graded by, with tests
- `tests/e2e/PDX-028-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision

### Not Allowed
- Re-running any cell against a live model. Re-grading uses the preserved workspaces
- Silently re-grading the corpus under a stronger gate and reporting the new rates as
  though they were the old ones. AC-4 governs how a gate change is published
- Deleting or rewriting the existing gate-limits table. It is corrected in place with the
  previous reading kept (CLAIM-01)
- Claiming a gate catches something the probe run did not show it catching

## 3. Acceptance Criteria

- [ ] AC-1: **the probe harness reports per gate-set, not per gate.** Every probe's result
      names which gate set caught it — `shipped` (what `acceptance.py` runs) and
      `shipped+tests` — so a catch by a gate the benchmark does not use can never again be
      counted as a catch. The two sets are read from one shared definition that
      `acceptance.py` also uses, so they cannot drift apart again.
- [x] ~~AC-2: the published table is corrected under CLAIM-01.~~ **Absorbed by PDX-033
      AC-1.5.** It is a sentence edit over `bench/README.md`, which PDX-033 rewrites in one
      pass with seven other claims; running it here would conflict with that pass over the
      same file. The substance is unchanged: 3 of 8 under the shipped gate, the previous
      4-of-8 reading kept visible with its date and cause, and no implication that the
      60-test suite is part of the measurement.
- [ ] AC-3: **the backend gate runs the fixture's test suite as PASS_TO_PASS**, compared as
      a delta against the pristine baseline exactly as the diagnostics already are — a test
      failing before the agent touched anything is not the agent's failure. Each cell records
      which gates ran, so a cell graded without the suite is distinguishable from one graded
      with it, forever.
- [ ] AC-4: **the re-grade is published as a re-grade.** Every cell re-graded under the
      stronger gate keeps its old grade and its new one; `bench/DERIVATIONS.md` carries the
      per-arm before/after; and no published rate silently changes meaning. If the suite
      cannot run for a cell (no preserved workspace, no database), that cell says so rather
      than defaulting to either answer.
- [ ] AC-5: **the new gate is negative-controlled before it is trusted.** `be-swallow-404`
      must flip from missed to caught under `shipped+tests`, and the pristine fixture must
      pass the suite, and a planted always-failing test must make the gate fail. A gate that
      has not been shown to fail on broken code is not evidence that code works — this is
      the repository's own method commitment 2, applied to its newest gate.
- [ ] AC-6: **the site says which gate graded each cell.** The drawer and the methodology
      surface name the gate set, so a reader comparing a cell graded before this ticket with
      one graded after can see that they were graded differently.
- [ ] AC-7: **what is still unvalidated is stated, not implied.** The page says that nothing
      checks whether the ticket's own requirement was met (there is no FAIL_TO_PASS in this
      benchmark), that the four semantic defects still pass every gate including the suite
      where the probe shows they do, and that a passing cell is therefore alive rather than
      correct.

## 4. Edge Cases & Error Handling

- No database available at grading time → the cell records `tests: not-run` with the reason
  and is graded by the shipped gate, which is a weaker claim and must print as one. Grading
  it as a pass because the check could not run is the exact ASSERT-01 failure shape this
  repository has produced six times.
- The suite is flaky on a cell → a flake read as a regression would attribute the harness's
  instability to the agent. Repeat the suite on failure and record both outcomes; a cell
  whose two runs disagree is recorded as disagreeing rather than resolved by one of them.
- The agent deleted or edited a fixture test → PASS_TO_PASS over a suite the agent rewrote
  proves nothing. The suite is restored from the pristine fixture before it runs, and a cell
  that modified it is flagged, because *editing the tests* is itself a finding about a pack.
- The stronger gate lowers every arm's rate including the baseline's → expected, and not a
  reason to suppress it. AC-4's before/after is what makes the drop readable as a change of
  instrument rather than a change of packs.

## 5. E2E Mapping

- `tests/e2e/PDX-028-the-probe-names-its-gate-set.sh` — AC-1, AC-2, AC-5: the gate-set
  definition is shared with `acceptance.py` (planting a change in one and asserting the
  other sees it), `be-swallow-404` flips between the two sets, and the corrected table
  matches the regenerated record
- `tests/e2e/PDX-028-the-regrade-is-published.sh` — AC-3, AC-4, AC-6, AC-7: per-cell gate
  provenance in the records and on the page, the before/after table checked against the
  records it summarises, and the not-run path proven to render as a weaker claim

## 6. References

- `bench/harness/gate_probes.py` — the probe harness and its pre-written predictions
- `bench/harness/acceptance.py:379-390` — the shipped backend gate; note the absence
- `bench/data/gate-limits.json` — `summary: {probes: 8, caught: 4, missed: 4}`, the count
  this ticket corrects for the shipped gate
- `bench/README.md`, "What this gate cannot see" — the table, and method commitment 2
- `bench/REPRODUCE.md` — the Postgres setup the suite needs, already written down
- arXiv 2503.15223, cited by `gate_probes.py`'s own docstring — why PASS_TO_PASS is the
  standard this ticket adopts
- PDX-026 — the other engine ticket; it changes validity, this one changes grading, and
  both re-grade the corpus, so they must not run concurrently
