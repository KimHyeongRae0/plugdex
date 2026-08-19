# PDX-026 — data: a cell is valid in one place

- Status: TODO
- Created: 2026-08-19

## 1. Goal

Two facts about this corpus were found by auditing the measurement engine, and both are
about the same question — *what makes a cell valid, and where is that written down?*

**First, the two record kinds disagree.** For run `20260816-010513` the acceptance record
marks 78 of its 165 cells invalid, each with a reason, while the results record for the same
run marks **zero** of the same 165 rows invalid, every one carrying `"valid": true` and an
empty `invalid_reason`. Two more runs disagree the same way, always in the same direction.
Counted over the whole corpus: **90 invalid cells by the acceptance records, 7 by the
results records** (88 and 7 excluding the withdrawn run). The site grades cells from the
acceptance record and pools economics from the results rows, so today a published mean is
taken over rows the same corpus calls invalid — a defensible policy that nothing states,
resting on a contradiction nothing detects.

**Corrected 2026-08-20 — the original diagnosis in this paragraph was wrong, and a plan
built on it would not have fixed anything.** It read the two runs that agree on the count
(`20260816-113302-as-shipped` 3 and 3, `20260817-162601-sonnet-three-questions` 4 and 4) as
evidence that "the harness was corrected at some point and the earlier records were never
regenerated", and the implied remedy is to regenerate the older records. Comparing the
*reasons* rather than the counts falsifies that:

| run | acceptance | results |
|---|---|---|
| `20260816-113302-as-shipped` | `killed-on-cell-timeout` ×3 | `unparseable result json` ×3 |
| `20260817-162601-sonnet-three-questions` | `killed-on-cell-timeout` ×4 | `unparseable result json` ×4 |
| `20260816-010513-backend-and-dead-frontend` | `api_error: session limit` ×74, `api_error: not logged in` ×1, `api_error: computer slept` ×2, `no-work` ×1 | none |
| `20260816-094958-as-shipped-partial` | `aborted_streaming` ×1, `aborted_tools` ×1 | none |
| `20260816-092732-caveman-blocked` | `no-work` ×1 | none |

The two "agreeing" runs never agreed on anything but the number. A cell killed on a timeout
writes no parseable result JSON, so the same event trips both fields for mechanically
different reasons — the counts coincide because one cause produces both, not because a fix
landed. And `results.valid` is not a weaker version of `acceptance.valid`; it is a different
predicate that **structurally cannot** see 74 of the 88. A cell that dies on a session-limit
API error still writes well-formed JSON, so nothing regeneration could do would make the
results record mark it invalid.

That changes what this ticket has to do. The remedy is not to re-run a generator until the
two fields match — they cannot match, because only one of them is asking about validity at
all. `results.valid` is a **parse-success flag wearing the name of a validity verdict**, and
the fix is to give it its own name and make one record the single source of the verdict.
Also unequal in two runs: row counts, not just invalid counts (76 vs 72 in the withdrawn
run, 20 vs 18 in `as-shipped-partial`), so a join that assumes parity is a second latent
defect.

**Second, the validity predicate discards a behaviour rather than a failure.**
`bench/harness/acceptance.py:313` reads
`if (d.get("total_cost_usd") or 0) <= 0 or (d.get("num_turns") or 0) <= 1: return "no-work
(cost=0 or turns<=1)"`. Two cells hit it — `tmpl-be-uniquetitle__superpowers__haiku__1` and
`tmpl-be-uniquetitle__caveman__haiku__0`. Neither failed. Both completed normally, in one
paid turn, and the superpowers one cost $0.0234 with 1,005 output tokens: the agent read the
ticket and asked a clarifying question instead of writing code. **A rule keyed on `turns<=1`
can only ever discard cells that answered in one turn, and answering in one turn is a
behaviour some packs have and others do not.** That makes the exclusion arm-asymmetric by
construction, which is the one property a validity rule may not have.

The direction is not self-serving and this ticket says so up front: counting them moves
superpowers to 50/51 and caveman's silent rate to 1/39, so nothing published moves the way
we would want it to. The defect is the label, not the leaderboard.

This ticket does not decide that the two cells are valid. It makes validity a single
recorded fact with a stated rule, re-grades the corpus under it, and publishes what moved.

## 2. Scope

### Allowed
- `bench/harness/acceptance.py` — the validity predicate and the writer that records it
- `bench/data/runs/**` — **re-grading only, from the preserved workspaces**; no new
  measurement, no new agent invocation, no edit to a raw `*.results.json` metric
- `packages/data/**` — reading validity from one place, with tests
- `bench/DERIVATIONS.md`, `bench/README.md` — the CLAIM-01 record of what moved
- `tests/e2e/PDX-026-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision, and the rule if one is added

### Not Allowed
- Re-running any cell against a live model. Every figure here comes from the preserved
  workspaces and the recorded fields, or it does not come at all
- Deleting an invalid cell's record. A cell that leaves a pool stays in the corpus with
  its reason (CLAIM-01)
- Changing which cells are valid *and* changing a published rate in the same commit
  without the before/after table AC-5 requires
- Any rule that discards cells by a threshold on `num_turns` alone — that is the defect

## 3. Acceptance Criteria

- [ ] AC-1: **validity has one home.** Exactly one record kind carries `valid` and
      `invalid_reason` as normative, and the other either omits them or is derived from the
      first at write time. The choice is written down with its reason. A loader that reads
      the non-normative copy fails a test that plants a contradiction between the two.
- [ ] AC-2: the disagreement is **gone by derivation, not by editing and not by re-running
      the original generator**. Rewritten 2026-08-20: the previous wording said "gone by
      regeneration", which §1's correction shows would reproduce it exactly — `results.valid`
      is a parse-success flag and cannot see the 74 session-limit cells however many times it
      is regenerated. What must hold instead: the normative record chosen in AC-1 is the only
      thing that computes a verdict, the other kind's field is written from it or dropped, and
      the script that does so is in the repository and re-runnable offline against the
      preserved workspaces. Verified by re-deriving the comparison this ticket's §1 table
      shows: **acceptance 88 invalid against results 7, differing on 30 of 93
      `(task, arm, model)` keys**, must come out equal, with the reasons equal too — equal
      counts are not agreement, which is the trap §1 fell into.
- [ ] AC-2b: **the row counts are reconciled as well as the verdicts.** Two runs hold
      different numbers of rows in the two kinds (76 vs 72 in the withdrawn run, 20 vs 18 in
      `20260816-094958-as-shipped-partial`), so any join assuming parity is a second latent
      defect. Either the counts match after this ticket, or the join names the asymmetry and
      a test plants a row present in one kind and absent in the other.
- [ ] AC-3: **the validity rule is stated as a predicate over recorded fields**, each clause
      justified by a failure it catches, and `turns<=1` is not among them. A cell with
      `terminal_reason: completed`, a positive cost and no error is valid whatever its turn
      count. What replaces the no-work clause must catch what it was aimed at — a cell that
      truly did nothing — using a field that means that (`cost <= 0` alone, or an explicit
      empty-result marker), and a unit test pins each clause against a real recorded cell.
- [ ] AC-4: **arm-asymmetry is measured, not argued.** The e2e derives, per arm, the share
      of that arm's cells the predicate discards, and reports the spread. Any clause whose
      removal changes that spread by more than it changes the total discard count is named
      in the output. This is the assertion that would have caught `turns<=1` before it
      shipped, and it is written so it keeps working on rules nobody has written yet.
- [ ] AC-5: **a before/after table ships with the re-grade**, per arm and per domain: cells
      valid before, valid after, and every published rate that moves, with its old value, its
      new value and the cause. It lives in `bench/DERIVATIONS.md` and the site's methodology
      surface reaches it (PDX-025). CLAIM-01 means the old numbers stay readable.
- [ ] AC-6: DATA-02 — no filename and no analysis script decides validity. The gate
      `check-data-universe.sh` gains a case: two records of the same run disagreeing about
      any cell's validity is a BLOCK, with the run and cell named.
- [ ] AC-7: every figure the site renders is re-derived after the re-grade and the analysis
      page's existing scenarios still pass, or the ones that change are updated in the same
      commit with the change named in the report.

## 4. Edge Cases & Error Handling

- A preserved workspace is missing for a cell being re-graded → the cell keeps its recorded
  grade and is listed as not-re-graded in the AC-5 table. Silently carrying it forward as
  confirmed is the failure mode; 63 cells were re-graded from workspaces during the audit,
  which is not all of them.
- The re-grade changes a cell's *grade* and not only its validity → reported separately in
  AC-5. The audit found zero field differences over its 63 cells, so a difference here is
  news and must not be averaged into a total.
- A run's results record has fewer rows than its acceptance record has cells (`20260816-094958`:
  18 rows, 20 cells; `20260815-225842`: 0 rows, 76 cells) → the join must say so by name
  rather than pairing by position. **Position-pairing is how this ticket's own investigation
  first mis-measured the disagreement**, and it is recorded here so the implementation does
  not repeat it: results rows carry no `rep`, so any per-cell comparison needs a key the
  records actually contain.
- The corrected predicate revalidates a cell whose workspace shows no delivered code → it is
  valid and graded as no-code, which is a measurement, not an exclusion. The distinction
  between "the harness failed" and "the agent chose not to write code" is the whole point.

## 5. E2E Mapping

- `tests/e2e/PDX-026-validity-has-one-home.sh` — AC-1, AC-2, AC-6 over the live corpus,
  with a planted contradicting pair proving the gate fires and naming the cell
- `tests/e2e/PDX-026-the-rule-is-symmetric.sh` — AC-3, AC-4, AC-5: each clause pinned to a
  recorded cell, the per-arm discard spread derived and printed, the before/after table
  checked against the records it claims to summarise

## 6. References

- `bench/harness/acceptance.py:313` (the predicate), `:390` (the backend gate)
- DEC-019 / PDX-017 — regime as a record field; the same defect one field over
- DEC-024 — the economics join, which is what pools results rows the acceptance record
  calls invalid
- CLAIM-01, DATA-02 in `CLAUDE.md`
- PDX-025 — the methodology page, which is where AC-5's table becomes readable
