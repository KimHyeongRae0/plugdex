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

**Three blockers found 2026-08-20 by executing the corpus, which reorder this ticket.** An
audit ran four oracles of increasing strength against all 102 valid backend cells, with the
23 GB of preserved workspaces, a real Postgres, and a pristine-fixture control through the
identical code path. What it found changes what this ticket must do first:

1. **`plugdex` cannot locate its own corpus.** `bench/harness/acceptance.py:41-43` defaults
   `FIXTURE_ROOT` to `ROOT/"arms/ponytail/…"`; `ls bench/arms` returns *No such file or
   directory*. The graded workspaces live in a **sibling repository**,
   `~/Desktop/project/pack-pilot/arms/ponytail/benchmarks/agentic/runs/`, and `run.py` — the
   runner that produced them — is not in this repository at all. Nothing in this ticket is
   runnable until the corpus root is resolvable and recorded.
2. **Wiring the 60-test suite in *first* miscalibrates it by two failures per cell.**
   `run.py:354` seeds each cell with
   `shutil.ignore_patterns("node_modules", ".git", "build", "dist", …)`. `ignore_patterns`
   matches **basenames at any depth**, so `"build"` — intended for the frontend — also strips
   `backend/app/email-templates/build/`, which the fixture ships with three templates
   (`new_account.html`, `reset_password.html`, `test_email.html`) and which the FastAPI
   mailer reads at runtime. **Every cell in the corpus therefore ships a backend that cannot
   send email, and 2 of the 60 tests can never pass in any cell** — a full sweep returned
   `2 failed, 58 passed` even on cells that changed nothing. This is invisible in every
   stored record; it surfaced only by re-running the suite. Adding PASS_TO_PASS before fixing
   the seed filter gives every cell two free failures and an uncalibrated gate.
3. **The oracle's weakness is real but did not fire on this corpus, and the honest headline
   is the opposite of what this ticket assumed.** Demonstrated functional false-positive rate
   among the 35 shipped-PASS backend cells: **0 of 35**, with no cell left unevaluated.
   All 35 survive `alembic upgrade head` and the pristine 60-test suite (PASS_TO_PASS);
   34 of 35 pass a functional test transcribed from the task prompt, and the single failure
   (`tmpl-be-uniquetitle__baseline__haiku__1`) returns 409 with the conflicting id in an
   `X-Conflicting-Item-ID` header rather than the body — an oracle-strictness artifact, not a
   broken feature. Adopting PASS_TO_PASS changes **no verdict** on the current corpus, so it
   costs zero retractions.

**The defect that does move the numbers is a different one.** 13 of the 35 passing cells ship
a repository whose **own** test suite is red. The gate cannot see it because `acceptance.py`
runs `mypy app` and `ruff check app` (lines 15–16, 379–381) — `backend/tests/` is never
linted, type-checked or executed — while **55 of the 102 cells wrote into
`backend/tests/api/routes/test_items.py`**. All 26 red cells across the 102 wrote their own
tests; all 47 that wrote no test are green. Read with care: on inspection the fault is
usually the agent's test rather than the product code (items seeded via
`create_random_item(db)` with a random owner, then queried as a different user;
order-dependent state between tests). The delivered workspace is internally inconsistent
either way, which is a real defect — but it is not evidence the feature is broken, and this
ticket must not report it as one.

**External comparison, primary sources read.** SWE-bench requires `FAIL_TO_PASS == 1.0` **and**
`PASS_TO_PASS == 1.0` (`swebench/harness/grading.py`). Commit0 — the closest analogue, since
it grades generated rather than patched code — ships ruff and type checking as *feedback to
the model* and then states performance is measured "only by the pass rate of these unit
tests". SecureAgentBench implements exactly this repo's new-diagnostic-delta shape and
deliberately demotes it: a new warning marks a patch *suspicious*, not failed. EvalPlus
dropped pass@1 by up to 19.3 points by strengthening test suites alone. The one precedent
that does accept this oracle is EnvBench (pyright `reportMissingImports == 0` + build exit 0)
— and it grades *environment setup*, where resolving imports **is** the goal, and calls
itself a "reasonable proxy". So: the field puts static analysis on the input side, not the
oracle side, and `imports + no new diagnostic` is below the floor for a correctness claim —
which is a disclosure obligation, not a reason to retract a number that measurement says was
right 35 times out of 35.

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
- [ ] AC-2a: **the corpus is locatable from this repository, and every run record says where
      it was graded from.** `bench/harness/acceptance.py:41-43` currently defaults
      `FIXTURE_ROOT` to `ROOT/"arms/ponytail/…"`, and `ls bench/arms` returns *No such file or
      directory*; the workspaces live in the sibling `pack-pilot` tree and `run.py` is not in
      this repository at all. Either the default resolves or it fails loudly at import with
      the path it wanted — it must not silently grade nothing. Each run record gains the
      absolute workspace root it was graded from. **Nothing else in this ticket is runnable
      until this holds**, which is why it is first.
- [ ] AC-2b: **the seed filter is fixed and the pristine baseline is proven clean before any
      suite is wired in.** `run.py:354` passes `"build"` to `shutil.ignore_patterns`, which
      matches basenames at any depth and strips `backend/app/email-templates/build/` from
      every cell — three templates the FastAPI mailer reads at runtime, so **2 of the 60
      tests can never pass in any cell** (`2 failed, 58 passed` even on cells that changed
      nothing). The fix belongs in the runner, which lives in another repository, so this AC
      is satisfied either by landing it there and re-seeding, or by the gate compensating with
      an explicit, named, tested exclusion of exactly those two tests. **A silent 58/60
      baseline is not acceptable**: it makes every PASS_TO_PASS delta below carry two phantom
      failures. An e2e asserts the pristine fixture returns 60/60 through the gate's own code
      path before AC-3 may be marked done.
- [ ] AC-3: **the backend gate runs the fixture's test suite as PASS_TO_PASS**, compared as
      a delta against the pristine baseline exactly as the diagnostics already are — a test
      failing before the agent touched anything is not the agent's failure. Each cell records
      which gates ran, so a cell graded without the suite is distinguishable from one graded
      with it, forever. **Blocked by AC-2a and AC-2b**; measured cost is 13.6s per cell for
      both suites serially, ~7s for PASS_TO_PASS alone, zero API cost, and the whole 109-cell
      sweep completed in under ten minutes on four workers with four scratch databases.
- [ ] AC-3a: **the false-positive measurement is published, including that it found nothing.**
      Among the 35 shipped-PASS backend cells the demonstrated functional false-positive rate
      is **0 of 35**, with no cell unevaluated, under four oracles: import, `alembic upgrade
      head`, the pristine 60-test suite, and a functional test transcribed from each task
      prompt (34/35, the one failure returning 409 with the conflicting id in an
      `X-Conflicting-Item-ID` header rather than the body). Adopting PASS_TO_PASS therefore
      changes no verdict on this corpus. Publish the number rather than the hedge — "0 of 35
      passes was functionally wrong, measured" is a stronger and more falsifiable statement
      than "the gate is weak", and it must ride with the reason it is not a general result:
      the six backend tasks are framework-shaped, so this task set does not exercise the
      oracle's known weakness.
- [ ] AC-3b: **`backend/tests/` stops being an ungraded directory, or the report says it is
      one.** `acceptance.py` runs `mypy app` and `ruff check app`, so the tests directory is
      never linted, type-checked or executed — while **55 of the 102 cells wrote into
      `backend/tests/api/routes/test_items.py`**, and **13 of the 35 passing cells ship a
      repository whose own suite is red**. That verdict is reported **separately** from the
      PASS_TO_PASS verdict and never folded into it, because on inspection the fault is
      usually the agent's own test (items seeded with a random owner then queried as a
      different user; order-dependent state between tests) rather than the product code. An
      internally inconsistent delivery is a real defect; a broken feature is a different
      claim, and this AC forbids reporting the first as the second.
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
- [ ] AC-6a: **the records retain what makes this question answerable next time.** This
      audit only succeeded because a 23 GB sibling tree happened to survive; nothing in this
      repository guaranteed it. Each cell record gains: the gate set that actually ran
      (`gates: ["mypy","ruff","import"]` — `python_gate_versions()` records tool *versions*
      but not which gates *executed*, which is the exact confusion this ticket exists to
      fix), the absolute workspace root, the seed filter's exclusion list for the run, the
      bodies of any `backend/tests/` files the cell wrote (not just their paths in
      `new_files`), and a per-cell OpenAPI path+schema fingerprint. The fingerprint is a few
      KB and makes "did the API surface change" answerable without retaining 23 GB of
      workspaces at all.
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
