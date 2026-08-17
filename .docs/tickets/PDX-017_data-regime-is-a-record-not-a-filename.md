# PDX-017 — regime is a record, not a filename

- Status: TODO
- Created: 2026-08-18

## 1. Goal

Every run in this corpus was executed under one of two regimes — `blocked` (Bash
disallowed, a "write, don't run" instruction appended) or `as-shipped` (Bash allowed,
ticket only). The regime moves the baseline build rate from 25% to 73%, so it decides
what almost every figure means. It lives in the filename: `load_cells` sets
`_regime = "as-shipped" if "as-shipped" in name else "blocked"`.

This ticket puts it on the record, the way PDX-016 put withdrawal there, and extends the
DATA-02 gate to cover it. That is the whole of DEC-015's other half.

**The heuristic is not currently wrong, and that is the argument, not against it.**
An earlier draft of this ticket claimed the sonnet probe was misclassified, on the strength
of `bench/PREREGISTRATION-2.md`'s coverage table counting those cells as `as-shipped`. That
claim was checked and withdrawn before the plan was written: D-002 withdrew that very table
as unreproducible, and the corrected table in `bench/README.md` classifies both sonnet runs
as `blocked` — which the filename derivation reproduces exactly, row for row (34/35, 9/9,
6/6, total 49/50, re-derived at drafting).

So the case for this ticket is not a live error. It is that ten filenames currently happen
to encode a fact correctly, and nothing checks that they do. The next run named without the
substring joins the wrong pool silently, no gate objects, and every figure computed after
that is wrong in a way no reader could detect — which is precisely the state PDX-016 found
one field over, where the two halves had already drifted apart before anyone looked.

The site is blocked on this. `@plugdex/data` has no regime, so `verdictFor` pools both
regimes and PDX-004's card currently renders a baseline of 42% — a rate that exists under
neither condition, merging two the preregistrations kept apart on purpose.

## 2. Scope

### Allowed
- `packages/data/src/{schema,load,index}.ts` — the `Regime` type, the optional field, the
  parse, the public surface
- `packages/data/src/load.test.ts` — unit coverage on synthetic corpora
- `bench/data/runs/*.acceptance.json` — one added key per record, no cell touched
- `bench/harness/fisher.py` — read the field instead of the filename
- `bench/harness/acceptance.py` — **added at plan review round 1.** It is what writes
  acceptance records, and a required field the writer does not stamp is a field the next
  graded run cannot produce. Making it required without touching the writer would ship a
  loader that refuses the very records this project's own grader emits
- `tests/e2e/PDX-002-*.sh`, `tests/e2e/PDX-016-*.sh` — **added at plan review round 1.**
  Both plant synthetic acceptance records, and a required field breaks them. Round 1 found
  that GREEN was unreachable without this: PDX-016's scenario plants regime-less records
  and requires them to load
- `tests/meta/cases/28..33-data-*.sh` — same reason; the six existing DATA-02 cases share a
  `plant_record` helper that writes no regime
- `scripts/check-data-universe.sh` — the DATA-02 sub-rules for regime
- `tests/meta/cases/` — golden cases, both sides of every new rule
- `tests/e2e/PDX-017-*.sh`
- `bench/DERIVATIONS.md` — the entry recording what the adjudication moved
- `docs/WORKFLOW.md`, `CLAUDE.md` — DATA-02's row gains the regime clause
- `DESIGN.md` — the decision, and the harness-debt row closed

### Not Allowed
- **Re-running anything, re-grading anything, or changing a single cell.** This relocates a
  fact that already exists; a diff that moves an outcome is a different ticket
- **Adjudicating a regime from a filename.** The name is the thing under suspicion. Every
  record's regime is settled from the preregistrations, the derivations, and the run's own
  documentation, and the evidence for each is written down where a reader can check it
- **Correcting any published figure.** If the adjudication moves one, that is a CLAIM-01
  correction with its own derivation entry, and the ticket reports it rather than
  quietly absorbing it
- **Touching `packages/site/` or the verdict function.** PDX-004 resumes after this and
  consumes the field; it is not extended here
- Any GitHub-external action beyond the standing delegation (CR-01)

## 3. Acceptance Criteria

- [ ] AC-1: **the regime is a field, and every record carries it.** Each acceptance record
      declares `regime` as `blocked` or `as-shipped`, with the evidence for that
      adjudication recorded in `bench/DERIVATIONS.md` — per run, naming the document that
      settles it. A record with no regime is a BLOCK, not a default: defaulting to
      `blocked` would restore the current misclassification with a field to hide behind
- [ ] AC-2: **the loader exposes it and refuses what it cannot read.** `@plugdex/data`
      parses `regime` into a typed value, `loadAcceptanceRecords` accepts an optional
      regime filter, and a record whose `regime` is absent or is not one of the two known
      values throws rather than being guessed at. Unit-tested on synthetic corpora, so no
      assertion depends on which runs happen to exist
- [ ] AC-3: **the two implementations agree, per regime.** For each regime, the TypeScript
      loader and `bench/harness/fisher.py` report identical cell counts, valid-cell counts,
      and per-arm build counts. Asserted by running both over the live corpus and
      comparing view against matching view — the PDX-016 shape, one field over
- [ ] AC-4: **no filename decides a regime, proven behaviourally.** No filename comparison
      determines any record's regime anywhere under `bench/harness/`, asserted against a
      planted corpus whose names contradict its records rather than by grep — a grep only
      catches the spelling of the last mechanism. And because the relocation is supposed to
      change nothing, D-002's corrected per-condition table (34/35 blocked haiku, 9/9
      as-shipped haiku, 6/6 blocked sonnet, 49/50 total) must re-derive identically from
      the recorded field, executed by the scenario rather than quoted
- [ ] AC-5: **DATA-02 covers regime.** `scripts/check-data-universe.sh` BLOCKs a record
      with no regime, a record whose regime is not a known value, and a filename
      comparison deciding a record's regime — the last proven behaviourally against a
      planted corpus whose names contradict its records, not by grep. Golden cases on both
      sides of every rule, replayed by `check-gates.sh`
- [ ] AC-6: **no published figure moves without a correction.** Every figure in
      `bench/README.md` and `bench/DERIVATIONS.md` is re-derived by its own existing
      reproduce command; any that moves is corrected in place under CLAIM-01 with its
      cause stated. The scenario executes the anchors rather than trusting this sentence
- [ ] AC-7: `verify.sh` runs the extended gate and the golden set is unregressed

## 4. Edge Cases & Error Handling

- A record with no `regime` → unit test + golden case → BLOCK, never a default
- A record whose `regime` is `"blocked "` or `"Blocked"` or `"as shipped"` → unit test →
  BLOCK; a near-miss value is a typo that would silently move a run between conditions
- A filename saying `as-shipped` over a record saying `blocked` → golden case + the
  behavioural probe → the record wins, and the disagreement is itself blocked
- A corpus filtered to a regime that no record carries → unit test → an empty result, not
  a fallback to everything. An empty pool is a result
- The withdrawn run → it carries a regime like any other record; withdrawal and regime are
  independent facts and neither exempts the other
- `ponytail+superpowers`, the combination arm → its run is as-shipped by the same evidence
  as the rest of round two; the arm is not a pack and this ticket does not change that

## 5. E2E Mapping

- `tests/e2e/PDX-017-the-corpus-knows-its-conditions.sh` — AC-1 through AC-7. The
  load-bearing assertion is AC-3: both implementations, per regime, compared over the live
  corpus, with floors that fail if the field was never written or if both sides pool

## 6. References

- DESIGN.md DEC-015 (a fact that governs the analysis is a record field, never a filename)
  and its harness-debt row for this ticket; DEC-005 (the effect confined to a regime the
  records do not carry as a field)
- `bench/PREREGISTRATION-2.md` §Experiment A — the regime definitions (`blocked`: Bash
  disallowed with a write-don't-run instruction; `as-shipped`: Bash allowed, ticket only;
  selected by `PONYTAIL_REGIME`). Its coverage table is **not** evidence for any
  adjudication: D-002 withdrew it as unreproducible
- `bench/README.md` D-002's corrected condition table — the classification that does
  reproduce, and the anchor AC-4 re-derives
- `bench/PREREGISTRATION-3.md` §Design — round three's regime, stated before the run
- PDX-016 — the same mechanism for withdrawal; this extends its gate rather than adding one
- PDX-004 — blocked on this ticket for its rate figures
