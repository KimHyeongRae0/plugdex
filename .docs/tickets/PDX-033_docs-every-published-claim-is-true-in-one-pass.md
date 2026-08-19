# PDX-033 — docs: every published claim is true, in one pass

- Status: TODO
- Created: 2026-08-20

## 1. Goal

This repository publishes eight statements that its own committed records contradict. They
are spread across `README.md`, `CLAUDE.md`, `DESIGN.md`, `bench/README.md` and
`bench/DERIVATIONS.md`, and four separate tickets were opened to correct four of them. This
ticket supersedes those four and corrects all eight in one pass, because they are one thing:
a reader who meets the repository between corrections sees a half-corrected story, which is
worse than either end state. Correcting them separately also means four 9-stage cycles over
the same four files, four plan reviews, four report reviews, and a merge conflict between
each pair — measured at 2–7 hours per cycle from the PDX-005 state stamps, for what is one
editing pass plus one derived comparison.

Superseded in whole: **PDX-030** (the premise), **PDX-032** (the headline's condition).
Superseded in part: **PDX-028 AC-2** (the gate-probe count), **PDX-031 AC-2 and AC-3** (the
activation disclosure). What is left in PDX-028 and PDX-031 is code and re-measurement, which
this ticket does not touch and which stays in those tickets.

The eight are not eight opinions. Each one is falsifiable in under five minutes by a reader
with a clone, and four of them were falsified that way while this ticket was being written.

## 2. Scope

### Allowed
- `README.md`, `CLAUDE.md`, `DESIGN.md`, `bench/README.md`, `bench/DERIVATIONS.md` — the
  eight claims, corrected in place under CLAIM-01
- `bench/PREREGISTRATION-3.md` — the outcome section it never got
- `.docs/references/` — the read-and-dated record of each cited work
- `packages/data/**`, `packages/site/**` — the paired comparison and the condition-naming
  sweep, derived and tested (this is the one part of this ticket that is not prose)
- `tests/e2e/PDX-033-*.sh`

### Not Allowed
- Deleting an original sentence. CLAIM-01: the previous wording, its date and its cause stay
  readable. A correction that erases what was wrong is a second wrong claim
- Re-measurement of any cell. Every number this ticket needs is already graded and committed;
  this ticket changes sentences and derives one comparison from records that exist
- Writing anything under `bench/data/runs/**`. That belongs to PDX-026, PDX-028, PDX-029
- Citing any work that has not been opened and dated by whoever writes the citation
- Pooling the two regimes into one rate (DEC-020), or replacing the `blocked` headline with
  the `as-shipped` one — swapping which number flatters us is the same defect reversed
- Weakening a claim into vagueness ("few benchmarks check", "some cells") to avoid naming
  what was wrong
- Any figure typed rather than derived (DATA-01)

## 3. Acceptance Criteria

- [ ] AC-1: **The eight claims are corrected, each with a CLAIM-01 record** carrying the
      previous wording, its date, its cause, and its replacement, all reachable by a reader
      from the surface that carried the claim. The eight, each with the evidence that
      falsifies it, verified 2026-08-20:
      1. `README.md:70` / `CLAUDE.md:18` — "`claude plugin marketplace add plugdex` makes
         every listed pack installable by name", while `.claude-plugin/marketplace.json:9`
         lists `caveman` and `packages/registry/installability/caveman.json` records
         `"outcome": "blocked"` with the verbatim manifest-validation error. The repository's
         own generated receipt contradicts its own pitch, and the existing "Does the listing
         still install?" section discloses breakage generically without naming caveman.
      2. `DESIGN.md:280` — PDX-007's headline stated as "one number (68/69)", a figure
         `README.md:105` formally withdraws and `bench/DERIVATIONS.md:153` proves
         underivable ("No pooling of the committed records produces 68 of 69"). A withdrawn
         number surviving in the normative spec is the exact CLAIM-01 failure DEC-017 exists
         to stop.
      3. `DESIGN.md:323` — the priority-1 chip's condition reads "≥ 80% of valid cells under
         the as-shipped regime", but `packages/site/src/pages/index.astro:28` sets
         `const REGIME = 'blocked'` and `packages/data/src/verdict.ts` contains no regime
         filter at all (`grep -n regime` returns nothing). Spec and code disagree about which
         condition the shipped chip means. Correct whichever is wrong — but say which, and
         say that they disagreed.
      4. `bench/README.md:186` — method commitment 5, "Invalid cells are counted in the
         denominator, with their reasons." Counted independently across `bench/data/runs/`:
         **90 invalid of 447 acceptance rows, 7 of 441 results rows**, and the results records
         carry no `valid` key at all. DEC-024 pools the *results* rows for economics. The
         commitment is true of one record kind and false of the other; PDX-026 fixes the
         substance, this AC fixes the sentence and says the substance is owed.
      5. `bench/README.md` — "The repository's own 60-test backend suite runs on every probe"
         and "Four of eight". `grep -n pytest bench/harness/acceptance.py` returns nothing;
         `bench/harness/gate_probes.py:91` lists pytest among its checks. Under the gate we
         ship the number is **three of eight**. (Absorbed from PDX-028 AC-2.)
      6. `bench/README.md` — the "every published benchmark" premise, false as written in
         four files. The narrow surviving claim — no published work measures behaviour-norm
         packs with an execution-based oracle — is defensible and is what replaces it.
         (Absorbed from PDX-030.)
      7. `bench/README.md` — the headline failure rate, published with no condition named.
         Blocked and as-shipped are two numbers, not two views of one: 30% against 83%, with
         `missing-dep` going 13 to 0. (Absorbed from PDX-032.)
      8. mattpocock's null is an **activation** null, not a behaviour null: it invoked zero
         skills across 69 cells while karpathy's text was in context in 78/78, and no arm
         currently proves its treatment was applied. The `bench/README.md` sentence lands
         here. (Absorbed from PDX-031 AC-3 only. PDX-031 AC-2 — labelling the arm on the site
         beside its rate — stays in PDX-031, because it renders the derived activation field
         that ticket's AC-1 produces and this ticket writes no derived field.)
- [ ] AC-2: **Every cited work is opened, dated and recorded** in `.docs/references/` with
      its title, identifier, what it grades with, what it measures, and one line on whether
      it covers behaviour-norm packs. A citation whose source could not be opened is dropped
      or labelled unverified in the text itself — never cited plainly.
- [ ] AC-3: **The condition is named wherever a rate is**, in the same element, the way every
      rate already names its population (PDX-005 AC-2). An e2e sweeps built output for a rate
      whose condition is not named and fails on finding one. The sweep must fail on an empty
      selection (ASSERT-01) — a zero-hit sweep is not a pass.
- [ ] AC-4: **The matched comparison is published**, derived rather than typed: shared tasks
      and arms, both rates, the per-task table, the failure-cause breakdown. Matched on task
      *and* arm, because the two conditions do not share their full task and arm sets and an
      unmatched comparison is a different confound.
- [ ] AC-5: **The regime-conditionality of the pack effect is stated** with both Fisher
      results (p=0.0414 blocked, p=0.5865 as-shipped) and the mechanism: dependency
      installation is impossible under `blocked`, so an arm that avoids dependencies cannot
      lose that way. Stated as the interpretation it is, with the alternative reading —
      ponytail is simply better and the effect is masked by as-shipped's smaller n — named
      rather than suppressed.
- [ ] AC-6: **`as-shipped`'s own limits ride with it** so it cannot be read as the true number
      either: smaller n, no mattpocock arm, and the runner blocks 12 built-in skills for every
      arm including `simplify` and `code-review`, so "as-shipped" is not the shipped
      configuration. That third fact is currently disclosed in three words in a
      preregistration and nowhere else.
- [ ] AC-7: **`PREREGISTRATION-3.md` gains its outcome section.** Rounds 1 and 2 report
      outcomes; round 3 stops at "Recorded before the run" while `README.md:165` commits that
      "Predictions that fail will be reported as failed". Its central prediction — sonnet
      build-failure rate below 40% — came out at 55% and **failed**.
- [ ] AC-8: **The `tmpl-fe-dropzone` denominator effect is stated.** Excluded by
      `PREREGISTRATION.md`, added back by `PREREGISTRATION-2.md`; it is 12/12 and moves the
      frontend rate from 37% to 47% on its own. The plan change is disclosed; its effect on
      the headline is not.
- [ ] AC-9: **The clustering caveat lands in `bench/DERIVATIONS.md`**: the Fisher figures pool
      repetitions of the same task as independent observations, the preregistration's
      task-unit rule was written for cost and duration so this is a gap rather than a broken
      commitment, and no site figure depends on either. A stated limitation, with the
      recomputation left to a ticket rather than silently fixed in prose.
- [ ] AC-10: **The superseded tickets say so.** PDX-030 and PDX-032 are marked superseded by
      this ticket; PDX-028 and PDX-031 have their absorbed ACs struck with a pointer here. A
      ticket queue that still lists work already done is how a queue stops being read.

## 4. Edge Cases & Error Handling

- A claim is corrected in one file and not another → AC-1's e2e asserts the old wording
  appears nowhere except inside a correction block, across all five files at once. Four files
  drifting apart is how the premise survived in three copies.
- The correction itself introduces a figure → DATA-01 blocks a typed figure; AC-4's
  comparison is derived, and the e2e re-derives it rather than reading it back.
- The condition sweep finds nothing because the selector is wrong → AC-3 requires the sweep to
  fail on an empty selection. This project has produced that failure shape seven times.
- `DESIGN.md:323` is corrected by changing the spec when the code was wrong, or vice versa,
  without anyone deciding which → AC-1.3 requires the resolution to name which side moved.
- A cited work cannot be opened → AC-2 forces drop-or-label; it must not be quietly cited.

## 5. E2E Mapping

- `tests/e2e/PDX-033-the-claims-are-true.sh` — asserts, over built output and committed
  text: each of the eight old wordings appears only inside a correction block; every rate on
  a built page names its condition in the same element, with the sweep failing on an empty
  selection; the matched comparison re-derives from `bench/data/runs/` to the published
  figures; `caveman`'s listing and its `blocked` record are stated together; and
  `.docs/references/` carries a dated entry per citation.

## 6. References

- CLAIM-01, DEC-017 (withdrawal record), DEC-020 (no pooling across regimes), DEC-024
  (economics pools results rows), DATA-01, ASSERT-01
- Superseded: `.docs/tickets/PDX-030_*`, `.docs/tickets/PDX-032_*`; partially superseded:
  `PDX-028` AC-2, `PDX-031` AC-2/AC-3
- Owes substance to: `PDX-026` (a cell is valid in one place) for AC-1.4
