# PDX-016 — Withdrawn runs are a record, not a filename

- Status: DONE
- Created: 2026-08-17

## 1. Goal

A run that was withdrawn is excluded from published figures by a string comparison on its
filename, in one of the two languages this project computes in. `bench/harness/fisher.py`
skips it; `@plugdex/data` does not. Every figure in `bench/README.md` and
`bench/DERIVATIONS.md` is computed on the excluded pool, and every figure the site would
compute includes 74 cells the project has already retracted — so the first card ever
rendered would contradict, in its denominator, the corrected table this repository
publishes under CLAIM-01.

This ticket moves the exclusion into the record. A withdrawal becomes a field an
acceptance record carries, with the reason it was withdrawn, and the loader honours it
instead of a filename. That is the same defect DEC-005 records as its second ground for
refusing a leaderboard — a fact that governs the analysis living in the filename rather
than in the data — and this is the second time the project has made it. It is caught here
only because a plan reviewer read the loader.

## 2. Scope

### Allowed
- `packages/data/src/schema.ts` — the withdrawal field on the run header
- `packages/data/src/load.ts` — honouring it, and the corpus's two views
- `packages/data/src/*.test.ts` — unit coverage
- `packages/data/src/index.ts` — the public surface the new type and error are exported through
- `docs/WORKFLOW.md`, `CLAUDE.md` — the new rule's row in the normative rules table and the
  `verify.sh` composition line, so a rule ID is not enforced by a gate while being absent
  from every table a reader consults. The same touch corrects the drift PDX-003 left
  behind: `check-src.sh` appears in no script table and the SRC-01 verify step is missing
  from the composition line
- `bench/data/runs/*.acceptance.json` — the withdrawal field written onto the affected run
- `bench/harness/fisher.py` — reading the field instead of the filename prefix
- `bench/DERIVATIONS.md` — the derivation entry this change produces
- `scripts/check-data-universe.sh`, `scripts/verify.sh` — the gate and its step
- `tests/meta/cases/` — golden cases
- `tests/e2e/PDX-016-*.sh` — the scenario
- `DESIGN.md` — the decision this ticket produces

### Not Allowed
- Changing any cell, any measured outcome, or any figure. This ticket moves *where the
  exclusion is recorded*; a number that moves as a result of it is a bug, not an outcome
- Withdrawing or un-withdrawing any run. The one withdrawal that exists is instrument
  failure 16, already adjudicated; this ticket records it rather than revisiting it
- Deleting the withdrawn record. A withdrawn run stays in the corpus, marked — that is the
  whole difference between a withdrawal and a disappearance
- Anything in `packages/site/`, `packages/registry/`, or the verdict function. PDX-004 owns
  those and resumes after this
- Deploying, announcing, or opening anything outward (CR-01)

## 3. Acceptance Criteria

- [x] AC-1: **the withdrawal is a field.** An acceptance record's run header carries an
      optional `withdrawn: { reason, recordedAt }`, typed and parsed. The affected run
      (`20260815-225842`) carries it, with instrument failure 16 named as the reason
- [x] AC-2: **the loader honours the field, never the filename.** `loadAcceptanceRecords`
      excludes withdrawn runs by default and exposes them explicitly on request. Asserted
      by a unit test on a synthetic corpus, so the assertion does not depend on which runs
      happen to exist
- [x] AC-3: **no figure moves.** The cell count, valid-cell count, and per-arm build counts
      computed by the TypeScript loader after this change equal the ones
      `bench/harness/fisher.py` computes today with `include_withdrawn=False`. Asserted by
      the scenario comparing both implementations on the live corpus — the disagreement
      this ticket exists to end is proven ended, not asserted
- [x] AC-4: **the Python side reads the field too.** `fisher.py` selects on the record's
      withdrawal field rather than a filename prefix, and its self-validation still passes.
      **No filename comparison may decide whether a live record enters an analysis pool.**
      Exempt: selections over a frozen historical corpus read through `git show <commit>:`,
      whose records can never carry the field — `derive_d001.py` reads the corpus as it
      stood at `63735e6` and excludes nothing from a live pool.
      (Corrected in place per CLAIM-01: this clause first read "a filename-prefix
      comparison surviving anywhere in `bench/harness/` is a BLOCK", which the plan review
      verified would block the forensic selections at `derive_d001.py:100/:101/:138` and
      even a task-name prefix at `:50`. The AC now states the property it was protecting —
      inclusion in a live pool — rather than a syntax it happened to notice.)
- [x] AC-5: **a gate makes the disagreement impossible to reintroduce.**
      `scripts/check-data-universe.sh` BLOCKs (a) a run whose filename says withdrawn
      while its record does not, or the reverse, and (b) a filename comparison in the
      harness that decides a live record's inclusion in an analysis pool — under AC-4's
      wording and its frozen-corpus exemption. Proven by golden cases on both sides,
      replayed by `check-gates.sh`
- [x] AC-6: **the change is derived, not asserted.** `bench/DERIVATIONS.md` gains an entry
      recording what the corpus contains before and after, with the command that
      reproduces both — including the fact that the published figures do not change,
      which is the claim this ticket most needs to be able to defend
- [x] AC-7: `verify.sh` runs the new gate and the golden set is unregressed

## 4. Edge Cases & Error Handling

- A record with `withdrawn` present but no reason → parse error, not a silent exclusion; a
  withdrawal with no stated cause is the thing this project refuses → unit test
- A corpus where every run is withdrawn → the loader returns an empty corpus rather than
  falling back to including them; an empty result is a result → unit test
- The filename still says `withdrawn` after the field is added → allowed and unchanged, but
  the gate asserts the two agree; the name is now a courtesy, not a mechanism → golden case
- A future run withdrawn by filename only → BLOCK → golden case (this is the regression
  this ticket exists to prevent)
- `include_withdrawn=True` still reachable in Python → yes: D-001's argument is *about* the
  pooled figures, so the ability to compute them deliberately must survive → AC-4

## 5. E2E Mapping

- `tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh` — AC-1..AC-7; the load-bearing
  assertion is AC-3, running both implementations over the live corpus and comparing the
  counts they produce

## 6. References

- `bench/DERIVATIONS.md` D-001 — what pooling the withdrawn run does to a p-value
  (0.0352 → 0.0055) and to a count (49/50 → 64/65)
- `bench/README.md` — instrument failure 16, the withdrawal being recorded here
- DESIGN.md DEC-005 — the second ground: a governing fact that lives in a filename
- CLAUDE.md — DATA-01, CLAIM-01, GATE-01, CR-01
- PDX-002 — the record universe this amends
- PDX-004 plan §9.1 — the review that found it, and the verification
