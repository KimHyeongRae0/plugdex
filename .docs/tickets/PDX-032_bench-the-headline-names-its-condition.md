# PDX-032 — bench: the headline names its condition

- Status: TODO
- Created: 2026-08-19

## 1. Goal

**The headline failure rate is substantially a measurement of the harness's tool policy, and
the headline does not say so.**

Every run behind the published number is `blocked`: Bash is disallowed and the agent is told
to write rather than run. An agent that reaches for `react-day-picker` or `cmdk` therefore
**cannot install it**, and fails `tsc` for a reason that has nothing to do with the quality of
what it wrote. Matched on task **and** arm — the 4 frontend tasks and 4 arms that exist under
both conditions, haiku, non-withdrawn, code-producing — reproduced independently for this
ticket:

| condition | builds |
|---|---|
| `blocked` | 15/50 = **30%** |
| `as-shipped` | 30/36 = **83%** |

| task | blocked | as-shipped |
|---|---|---|
| colorpicker | 8/12 | 2/3 |
| command | 3/12 | 10/11 |
| datepicker | 3/14 | 11/12 |
| wizard | 1/12 | 7/10 |

And the failure *causes* settle it. Under `blocked`: `{missing-dep: 13, type-error: 39}`.
Under `as-shipped`: `{type-error: 6}` — **zero missing-dep failures** once `npm install` is
available.

**The one pack effect in the corpus is regime-conditional too**, computed with the
repository's own `fisher.py` over the shared tasks:

| condition | ponytail | baseline | Fisher p |
|---|---|---|---|
| `blocked` | 8/13 | 2/13 | **0.0414** |
| `as-shipped` | 9/10 | 8/11 | **0.5865** |

ponytail's advantage lives only where dependency installation is impossible — which is
exactly the condition where "use what is already there" is a forced win rather than a virtue.
That is a finding, and a good one. It is not the finding the site currently implies.

**What this ticket does not say.** The `blocked` condition is a legitimate control and
DEC-020 argues well for reporting one named condition rather than a pooled rate that
describes neither. Nothing here says the number is wrong or the condition was a mistake. What
is indefensible is that `bench/README.md:42-43` publishes *"141 cells that produced code: 55%
of it fails its domain's gate"* and `README.md:19` says *"this repository measures what
happens when you check"* — with the word **blocked** appearing in neither, while the same
corpus reports 83% building in the condition an actual user is in.

## 2. Scope

### Allowed
- `bench/README.md`, `README.md`, `DESIGN.md`, `bench/DERIVATIONS.md` — the condition named
  wherever the headline appears, under CLAIM-01
- `packages/data/**`, `packages/site/**` — the paired comparison published, with tests
- `tests/e2e/PDX-032-*.sh`
- `bench/PREREGISTRATION-3.md` — its missing outcome section (see AC-5)

### Not Allowed
- Re-measurement. Both conditions are already graded; this is a denominator, a comparison and
  a set of sentences
- Pooling the two conditions into one rate. DEC-020 refuses it and this ticket does not
  reopen that — the two are reported side by side, matched, and never averaged
- Replacing the `blocked` headline with the `as-shipped` one. Swapping which number flatters
  us is the same defect in the other direction
- Any figure typed rather than derived (DATA-01)

## 3. Acceptance Criteria

- [ ] AC-1: **the condition is named wherever the headline rate is.** Every surface carrying
      a failure or build rate names the condition in the same element, the way every rate
      already names its population (PDX-005 AC-2). An e2e sweeps built output for a rate whose
      condition is not named and fails.
- [ ] AC-2: **the matched comparison is published**, derived: the shared tasks and arms, both
      rates, the per-task table, and the failure-cause breakdown with `missing-dep` going to
      zero. Matched on task *and* arm, because the two conditions do not share their full
      task and arm sets and an unmatched comparison would be a different confound.
- [ ] AC-3: **the regime-conditionality of the pack effect is stated**, with both Fisher
      results and the mechanism: dependency installation is impossible under `blocked`, so an
      arm that avoids dependencies cannot lose that way. Stated as the interpretation it is,
      with the alternative reading (ponytail is simply better and the effect is masked by
      as-shipped's smaller n) named rather than suppressed.
- [ ] AC-4: **the `as-shipped` condition's own limits ride with it** so it cannot be read as
      the true number either: smaller n, no mattpocock arm, and the runner blocks 12 built-in
      skills for every arm — including `simplify` and `code-review` — so "as-shipped" is not
      the shipped configuration either. That third fact is currently disclosed in three words
      in a preregistration and nowhere else.
- [ ] AC-5: **`PREREGISTRATION-3.md` gains the outcome section it never got.** Rounds 1 and 2
      report outcomes; round 3 stops at "Recorded before the run" while `README.md:165`
      commits that "Predictions that fail will be reported as failed". Its central
      prediction — sonnet build-failure rate below 40% — came out at 55% and **failed**, which
      is independent confirmation of this ticket's thesis: the document itself says that if a
      stronger model does not deliver more buildable code, "does it build" is a property of
      the task and the harness rather than the model.
- [ ] AC-6: **the `tmpl-fe-dropzone` denominator effect is stated.** The task was excluded by
      `PREREGISTRATION.md` and added back by `PREREGISTRATION-2.md`; it is 12/12 and moves the
      frontend rate from 37% to 47% on its own. The plan change is disclosed; its effect on
      the headline is not, and a prereg-excluded task worth 10 points belongs in the text.

## 4. Edge Cases & Error Handling

- A future run adds a third condition → every rate derives its condition label from the
  record, so it appears without an edit (the same shape as PDX-025's condition list).
- The matched set is empty for some domain → say so rather than falling back to an unmatched
  comparison. The backend tasks do not overlap the two conditions as cleanly as the frontend
  ones, and an unmatched backend claim would be worse than none.
- A reader takes 83% as "the real number" → AC-4 exists for exactly this. Both conditions are
  artificial in different directions and the page says how.
- `as-shipped`'s n is small enough that its null is uninformative → report the equivalence
  bound rather than "no difference", which is the commitment `bench/README.md` already makes
  in words and has no machinery for.

## 5. E2E Mapping

- `tests/e2e/PDX-032-a-rate-names-its-condition.sh` — AC-1, AC-6: page-wide sweep over both
  built pages, and the dropzone denominator effect derived and rendered
- `tests/e2e/PDX-032-the-conditions-are-paired.sh` — AC-2, AC-3, AC-4, AC-5: the matched
  comparison recomputed from records, both Fisher results reproduced through `fisher.py`, the
  as-shipped caveats present, and round 3's outcome table checked against its own predictions

## 6. References

- `bench/data/runs/*.acceptance.json` — every figure in §1 is derived from these and must be
  re-derived rather than trusted
- `bench/harness/fisher.py` — the test used for both p-values
- DEC-020 — one named condition, never pooled; this ticket extends it rather than reversing it
- `bench/PREREGISTRATION-3.md:55-57` — "the one worth being wrong about"
- `bench/PREREGISTRATION.md:67-72`, `bench/PREREGISTRATION-2.md:69-70` — the dropzone
  exclusion and its reversal
- PDX-031 — the activation ticket; land together
- PDX-029 — the failure-composition ticket; `missing-dep` is a severity class there and a
  regime artefact here, so the two must agree on one classification
