# PDX-037 — bench: the analysis behind the corrected claims

- Status: TODO
- Created: 2026-08-20

## 1. Goal

PDX-033 corrected six published statements that the repository's own records contradicted. It
did not produce the **analysis** four of those corrections point at, and this ticket carries
it. The split is disclosed rather than quiet: PDX-033's report review round 1 found that
AC-3, AC-4, AC-5, AC-8 and AC-9 had produced no change while its §3 said every step landed.

The split line is the one that justified merging in the first place — shared surface. PDX-033's
corrections all edit the same four prose files. This work derives new figures and writes them
into `bench/DERIVATIONS.md` and the site, which is a different kind of work touching different
files, and reviewing it beside a set of sentence corrections helped neither.

What is carried here, each with what makes it non-trivial:

- **The matched comparison** (PDX-033 AC-4). Both regimes are graded; nothing publishes them
  side by side. It must be matched on task **and** arm, because the two conditions do not
  share their full task and arm sets and an unmatched comparison is a different confound.
- **The regime-conditionality of the pack effect** (AC-5). ponytail's advantage is significant
  under `blocked` (p=0.0414) and not under `as-shipped` (p=0.5865). The mechanism is that
  dependency installation is impossible under `blocked`, so an arm that avoids dependencies
  cannot lose that way — and the alternative reading, that ponytail is simply better and the
  effect is masked by as-shipped's smaller n, must be named rather than suppressed.
- **`as-shipped`'s own limits** (AC-6's remainder). Smaller n, no `mattpocock` arm, and a set
  of built-in skills blocked for every arm. **The count of those skills has no source in this
  tree** — PDX-033's plan review found "12" appears only in tickets — so this ticket either
  reads it from the runner and cites where, or states the fact without a number.
- **The `tmpl-fe-dropzone` denominator** (AC-8). Excluded by `PREREGISTRATION.md`, added back
  by `PREREGISTRATION-2.md`, 12/12, and it moves the frontend rate on its own. The plan change
  is disclosed; its effect is not.
- **The clustering caveat** (AC-9). The Fisher figures pool repetitions of one task as
  independent observations. The preregistration's task-unit rule was written for cost and
  duration, so this is a gap rather than a broken commitment — and it is stated as a
  limitation with the recomputation left to a ticket, not silently fixed in prose.
- **The condition named wherever a rate is** (AC-3). Every surface carrying a rate names its
  condition in the same element, the way every rate already names its population (PDX-005
  AC-2), swept over built output. `bench/README.md`'s headline at `:41-42` still names no
  regime — `grep -c as-shipped bench/README.md` returns 0.
- **The invalid-cell commitment** (PDX-033 claim 4, `bench/README.md:215`). Method commitment 5
  says invalid cells are counted in the denominator with their reasons. Counted: acceptance
  marks 88 invalid and results marks 7 over the same 93 `(task, arm, model)` keys, with
  execution failures on one side and parse failures on the other — one field name, two
  predicates. The sentence must say what is true of the records as they are; **the substance is
  PDX-026's** and this ticket does not reopen it.
- **The activation-versus-behaviour distinction** (PDX-033 claim 8). `grep -ci activation
  bench/README.md` returns 0. mattpocock invoked 0 skills across 69 cells while karpathy's text
  was in context in 78/78, so its null is an **activation** null and nothing currently says so.
  The derived field that would prove activation per arm stays in PDX-031 AC-1.

**These last three were nearly orphaned.** PDX-033 absorbed them from PDX-031 and PDX-032, then
produced no change for any of them; PDX-031's AC-3 is struck as "absorbed by PDX-033", PDX-032 is
superseded in whole, and the first draft of this ticket named none of the three. Report review
round 2 caught it. Work that three tickets each believe another one owns is work nobody does.

## 2. Scope

### Allowed
- `bench/DERIVATIONS.md`, `bench/README.md` — the derived figures and their caveats
- `packages/data/**`, `packages/site/**` — the matched comparison and the condition sweep
- `bench/harness/fisher.py` — read only, or extended if the recomputation needs it
- `tests/e2e/PDX-037-*.sh`

### Not Allowed
- Re-measurement or re-grading. Both regimes are already graded; this derives from records
  that exist
- Pooling the two regimes into one rate. DEC-020 refuses it and this ticket does not reopen it
- Publishing the blocked-skills count without a source. PDX-033 removed an unsourced "12";
  reintroducing it is the defect that ticket existed to remove
- Any figure typed rather than derived (DATA-01)
- Silently recomputing the clustered figures. AC-5 states the limitation; changing the numbers
  is a separate decision with its own withdrawal record

## 3. Acceptance Criteria

- [ ] AC-1: **The matched comparison is published, derived**: shared tasks and arms, both
      rates, the per-task table, and the failure-cause breakdown with `missing-dep` going to
      zero. Matched on task **and** arm, and the e2e re-derives the matching rather than
      reading it back.
- [ ] AC-2: **The regime-conditionality is stated with both Fisher results and the mechanism**,
      and the alternative reading is present as text. An e2e re-derives both p-values from the
      records; a figure that does not re-derive is a figure this ticket did not compute.
- [ ] AC-3: **`as-shipped`'s three limits ride with it** — smaller n re-derived, the absent
      `mattpocock` arm re-derived from the cells, and the blocked built-in skills stated. The
      count appears only if it is read from the runner and cited on the same line; otherwise
      the sentence says the count is unrecorded.
- [ ] AC-4: **The dropzone effect is derived and stated**: the frontend rate with and without
      `tmpl-fe-dropzone`, both computed by the e2e, and the preregistration change that
      readmitted it named.
- [ ] AC-5: **The clustering caveat lands in `bench/DERIVATIONS.md`**, stating that repetitions
      are pooled as independent, that the task-unit rule was written for cost and duration, and
      that no site figure depends on the Fisher path — the last asserted by checking no
      rendered figure calls it.
- [ ] AC-6: **Every rate on a built page names its condition in the same element**, swept the
      way PDX-005's population sweep works, and the sweep FAILs on an empty selection.
- [ ] AC-7: **The invalid-cell commitment says what is true of the records as they are.**
      `bench/README.md:215` commits that invalid cells are counted in the denominator with
      their reasons; acceptance marks 88 invalid and results marks 7 over the same 93 keys,
      one field name over two predicates. The sentence is corrected under CLAIM-01 and states
      that the substance is PDX-026's.
- [ ] AC-8: **The activation-versus-behaviour distinction is published.** `grep -ci activation
      bench/README.md` returns 0. mattpocock invoked 0 skills across 69 cells while karpathy's
      text was in context in 78/78, so its null is an activation null; the sentence says so and
      the derived per-arm field stays in PDX-031 AC-1.
- [ ] AC-9: **Nothing here changes a published rate without a withdrawal record.** If the
      matched comparison or the dropzone disclosure moves a number a reader has already seen,
      it lands as a CLAIM-01 record with the previous value.

## 4. Edge Cases & Error Handling

- The two regimes share no task for an arm → the matched comparison reports the arm as
  unmatched rather than dropping it silently; an arm that vanishes from a comparison is a
  denominator change nobody sees.
- `fisher.py` produces a different p-value than the one published → that is a finding, and it
  lands as a withdrawal rather than a quiet update.
- The blocked-skills count cannot be found in the runner → AC-3's second branch, which is the
  expected outcome given PDX-033's search found nothing.
- The condition sweep finds no rate → FAILs. This project has produced ten instances of an
  assertion satisfied by empty output.

## 5. E2E Mapping

- `tests/e2e/PDX-037-the-analysis-is-derived.sh` — re-derives the matched comparison, both
  Fisher results, the dropzone deltas and the as-shipped limits from `bench/data/runs/`, and
  compares each against what the documents publish; sweeps built output for a rate whose
  condition is unnamed; and FAILs on any empty selection.

## 6. References

- `.docs/analysis/PDX-033_report.md` §3 and §8 — the disclosed split and why
- `PDX-032` — the ticket these ACs originally came from, superseded by PDX-033
- `DEC-020` (one named condition, never pooled), CLAIM-01, DATA-01, ASSERT-01
- `bench/PREREGISTRATION.md`, `PREREGISTRATION-2.md` — the dropzone exclusion and readmission
