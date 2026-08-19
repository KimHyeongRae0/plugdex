# PDX-034 — harness: the test step counts what it ran

- Status: TODO
- Created: 2026-08-20

## 1. Goal

`pnpm test` reports PASS over an empty set, inside `verify.sh`, in the package that renders
every published figure. The selector that produced the empty set also cannot reach the
directory PDX-005 just added, so a unit test written there tomorrow would not be collected
and the step would still say PASS. Make a test step that ran nothing fail, and make the
selector reach the whole source tree. CLAUDE.md's ASSERT-01 names six prior instances of an
assertion satisfied by empty output; this is the seventh, and the first one located inside the
script every other gate's credibility rests on.

## 2. Scope

### Allowed
- `packages/site/package.json`, and the `test` script of any other package with the same shape
- `scripts/verify.sh`
- `tests/meta/cases/**` — a golden case pinning the failure
- `CLAUDE.md` — the ASSERT-01 instance ledger

### Not Allowed
- Writing site unit tests to make the count non-zero. That closes the symptom by satisfying
  the vacuous check, which is the defect. Site coverage is a separate question and this ticket
  does not answer it
- Changing what any existing test asserts
- Touching `packages/data` or `packages/registry` test selectors beyond the shape fix — they
  use `src/*.test.ts`, are non-empty, and do not exhibit this

## 3. Acceptance Criteria

- [ ] AC-1: **A package whose test selector matches no file fails rather than passes.**
      Measured now, and the baseline this AC moves: `packages/site` prints `# tests 0` /
      `# pass 0` and `echo $?` returns `0`; `scripts/verify.sh:114` is
      `pnpm test || fail "pnpm test"`, so step 11/12 reports PASS on the empty set, and root
      `package.json:11` is `pnpm -r run test`, which puts the vacuous package inside every
      verify run.
- [ ] AC-2: **The selector reaches every depth of `src`.** `sh` has no `globstar`, so
      `src/**/*` expands as `src/*/*`. Verified 2026-08-20: `sh -c 'echo src/**/*.astro'`
      returns the five files at `src/components/*.astro` and `src/pages/*.astro` and omits
      `src/components/analysis/*.astro`, the six-file directory PDX-005 added. Assert on the
      **collected count**, not on the exit code — AC-1 is the demonstration that an exit code
      can lie here.
- [ ] AC-3: **A golden case in `tests/meta/cases/` pins AC-1**, so the gate self-test catches
      a regression of the vacuous pass. Both directions: a package with tests passes, a
      package whose selector matches nothing fails.
- [ ] AC-4: **`CLAUDE.md` records this as ASSERT-01 instance seven** with its file:line, so
      the count the rule states matches the ledger it keeps.

## 4. Edge Cases & Error Handling

- A package legitimately has no tests → decide explicitly: either it declares
  `"test": "exit 0"` with a comment saying why, or it carries no `test` script and `pnpm -r`
  skips it. A silent empty glob is the one shape not allowed. Covered by AC-3's golden case.
- `tsx --test` with a *quoted* glob delegates expansion to the runner rather than the shell,
  and the two have different depth semantics → the fix must state which one it relies on, and
  AC-2's assertion must exercise that one.
- The fix makes a currently-green package red → that is the ticket working. Any package it
  reddens is a package whose green was vacuous, and the report names each one.

## 5. E2E Mapping

- `tests/e2e/PDX-034-the-test-step-counts.sh` — plants a package whose selector matches
  nothing and asserts the step exits non-zero naming the package; plants a test file two
  directories deep and asserts it appears in the collected count; asserts the real
  `packages/*` selectors collect a non-zero count each.
- `tests/meta/cases/<n>-verify-vacuous-test-step.sh` — the golden case for AC-3.

## 6. References

- ASSERT-01 (CLAUDE.md), GATE-01 (gates are themselves tested)
- Found by the goal audit of 2026-08-20, alongside PDX-033's eight claims
