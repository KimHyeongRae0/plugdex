# PDX-035 — implementation plan

- Ticket: `.docs/tickets/PDX-035_docs-the-corpus-says-what-it-actually-covers.md`
- Date: 2026-08-20
- Branch: `feat/pdx-035-the-corpus-says-what-it-covers`

## 1. What this closes, stated as it is today

The landing page says every pack "was installed and run against real tickets in a real
repository". True, and read as far wider than what happened. Derived from
`bench/data/runs/` for the published pool (blocked regime, valid cells only):

- **12 distinct tasks**, all against one fixture — `tiangolo/full-stack-fastapi-template @
  cd83fc1` (v0.10.0, MIT), named with its commit at `bench/REPRODUCE.md:27` and
  `bench/README.md:24`.
- **Two shapes.** `tmpl-fe-*` — 6 tasks, 127 cells: colour picker, command palette, date
  picker, dropzone, star rating, form wizard, each *"Add a `<X>` component to the frontend"*.
  `tmpl-be-*` — 6 tasks, 102 cells: archive, count, CSV export, daily count, search, unique
  title, each *"Add an endpoint that `<Y>`"* or a constraint on one.
- **Nothing else.** No mobile or client-app task, no design task, no refactor, no debugging,
  no test authoring, no task in a second repository.

An outside review of the live site on 2026-08-20 scored it 6.5/10 and named this the single
thing most likely to lose a skeptical reader: the scope is discoverable but only after the
reader has formed a wider impression, and a reader who finds it late stops trusting the rest.

## 2. Approach

**Counts are derived; the fixture is cited.** A cell carries `task` and `domain`, both real
fields, and `domain` is total over the published pool — so the task count, the per-shape task
and cell counts, and the domain split all derive from the records with no parsing.

The fixture does **not**. An earlier revision of this section derived "one fixture" by counting
distinct `tmpl-` prefixes across task ids, and plan review round 1 killed it with the failure
it produces: rename `tmpl-fe-datepicker` to `template-fe-datepicker` inside the *same* fixture
and the derived family count becomes 2, so the page states "two repositories" — a claim about
provenance invented by a string convention. Worse, §4's direction assertion as first written
required exactly that behaviour, so the test would have locked the defect in. DEC-019 records
this lesson already: a filename is not the fact.

The fixture is therefore **stated from its named source** — `bench/REPRODUCE.md:27` carries
the repository, the commit and the licence — and the prefix scan is demoted to a **consistency
check**: if task ids ever disagree with the cited fixture count, the scenario fails and says
so, rather than silently republishing whatever the strings imply.

**What cannot be derived is stated as a claim with its source, not smuggled in as a figure.**
"No mobile task" is an absence, and an absence is not a count. The page states it as a
sentence and the scenario asserts the *complement*: that every task in the corpus falls into
the shapes the sentence names. If a task ever appears outside them, the sentence becomes false
and the scenario fails — which is the only honest way to test a claim about what is missing.

**AC-8 and AC-9 are the outside review's other two points and they change the figure itself.**
AC-9 groups arms whose intervals overlap the baseline's, membership derived from the intervals
rather than assigned; AC-8 states the decision those groups support. Both are consequences of
records the page already loads, so neither introduces a new number.

## 3. Steps

| # | Step | Files | What it does |
|---|---|---|---|
| 1 | The inventory, derived | `packages/data/src/aggregate.ts` | `corpusInventory({ cells })` → distinct tasks, distinct families, and per-shape `{ prefix, domain, tasks, cells }`. Parsing lives with the records; the site receives finished counts |
| 2 | The coverage sentence | `packages/data/src/stats.ts` | The formatter, so no count is typed in site source (DATA-01). One string carrying tasks, shapes and families the way `formatRate` carries a denominator |
| 3 | The statement, beside the rate | `packages/site/src/pages/index.astro` | Rendered in the build-rate panel, not in a footnote and not on a page one click away (AC-2). Carries the absences (AC-4) and the external-validity limit (AC-7) |
| 4 | The withdrawal record | `README.md` | CLAIM-01: the previous wording, its date, its cause, its replacement (AC-5) |
| 5 | The grouping | `packages/data/src/aggregate.ts`, `packages/site/src/components/RankedBars.astro` | `separationTier({ summary, baseline })` → `clears` \| `overlaps` \| `unmeasured`, derived from the Wilson bounds, with `null` its own outcome rather than a falsy "does not overlap" (AC-9) |
| 5b | The decision row | `DESIGN.md` | The row AC-10 owes: what changed in DEC-027's ground, the evidence that changed it, and which of its conditions still hold |
| 6 | The decision sentence | `packages/site/src/pages/index.astro` | Derived: which arm clears the baseline outright, that no pack is distinguishable on backend work, and what the clearing arm costs (AC-8) |
| 7 | The scenario | `tests/e2e/PDX-035-*.sh` | §4 |

## 4. Test Plan

**RED condition**: `./scripts/test-loop.sh PDX-035 --red` — `verify.sh` PASS on the untouched
tree **and** the PDX-035 scenario FAIL. The scenario builds the site first, so a FAIL from a
broken build is distinguishable from a FAIL from a missing statement.

**GREEN condition**: `./scripts/test-loop.sh PDX-035` — verify PASS, PDX-035 PASS, regression
PASS, unit suites PASS.

Assertions, all over built output or the records, never over site source:

| AC | Assertion | Fails when |
|---|---|---|
| 1 | The rendered counts re-derive from `bench/data/runs/`: 12 tasks, 2 shapes, and the per-shape task and cell counts (fe 6/127, be 6/102), computed independently in the scenario | a count is typed or stale |
| 1 | **Direction**: a planted cell in a scratch corpus moves the task and cell counts, and the rendered sentence follows | the derivation ignores what it is handed |
| 1 | The fixture is quoted from `bench/REPRODUCE.md` — repository, commit, licence — and the scenario re-reads that file rather than matching a string the page typed | the fixture is asserted by the page about itself |
| 1 | **Consistency, not derivation**: task-id prefixes are scanned and must agree with the cited fixture; a disagreement FAILs and names both sides | a rename silently republishes a provenance claim (plan review round 1's B1) |
| 2 | The statement's element and the headline rate's element share a section container in the built HTML | the scope note drifts into a footnote |
| 3 | The two shapes are named with their task counts, and the words come from `@plugdex/data` | the shapes are described in prose a component typed |
| 4 | Each absence named in the ticket appears as text: mobile/client, design, second repository | an absence is left for the reader to infer |
| 5 | The correction is reachable **from the built page**: the corrected sentence links a withdrawal record rendered on the site, and the scenario follows the link in `dist/` rather than trusting that one exists | the record lives only in `README.md`, which no site reader can reach from the landing page |
| 8 | The decision sentence names the arm that clears the baseline, re-derived from the Wilson bounds in the scenario, and states that no backend arm does | the recommendation is prose rather than a consequence |
| 9 | **Three tiers, all re-derived**: an arm with `wilson === null` renders `unmeasured`; an arm whose `lo` exceeds the baseline's `hi` renders `clears`; every other measured arm renders `overlaps`. All three directions asserted | the grouping is assigned rather than derived |
| 9 | **The live trap, pinned by name**: `superpowers` (n=0, `wilson === null`) must NOT render in the same tier as `ponytail` (`[0.518, 0.868]`, the only arm clearing baseline's `[0.112, 0.469]`). Asserted on the arms by id, because this is what the two-way version did today | the pack that writes no code is shown beside the one that beats the baseline |
| 9 | **ASSERT-01**: the scenario FAILs if any tier is empty of the arms the records put in it, and if every arm lands in one tier | a corpus change makes the grouping prove nothing |
| 7 | The external-validity sentence is present in the built page and names both halves: that these results describe this fixture's kind of work, and that nothing has measured whether they transfer | the limit is implied by the scope note rather than stated |
| 10 | `DESIGN.md` carries a decision row referencing DEC-027 that names what changed, the evidence, and which of DEC-027's conditions still hold; the scenario greps the log for the row and for a DEC-027 back-reference, and FAILs if either is absent | the decision moves in a commit message, which is where a decision stops being auditable |
| — | **ASSERT-01**: the task selection is asserted non-empty before any per-task check | a selector typo passes vacuously — nine instances in this project |

**Unit tests, decided rather than left open** (plan review round 2 asked). `corpusInventory`
and `separationTier` get tests in `packages/data`, because both have branches the scenario
reaches only by accident of the current corpus. `separationTier` in particular must be pinned
on a `null` interval directly: `stats.ts:68` throws `RangeError` when `n <= 0`, so the
`unmeasured` branch exists precisely where the interval cannot be computed, and a scenario
that happens to have one such arm today is not a test of that branch. Three cases each — a
clearing arm, an overlapping arm, and an arm with no interval; an empty corpus, a
single-shape corpus, and the live shape.

**Positive controls, run before the real assertions are believed**: a planted page whose
coverage sentence states the wrong task count must be reported; a planted summary whose
interval clears the baseline must move an arm out of the group.

## 8. Feature Tags

- `data` — the inventory, the overlap test, and the formatters
- `site` — the coverage statement, the grouping, the decision sentence
- `docs` — the CLAIM-01 withdrawal in `README.md`

## 5. Risks

| Risk | Mitigation |
|---|---|
| The statement reads as an apology and undercuts the measurement | AC-7 fixes the register: the corpus is small and says what it covers, which is the opposite of a weakness to hedge. The report records the exact wording |
| AC-9's grouping is read as the composite index this project refuses | Membership is derived from the intervals and asserted in both directions; the refusal element stays on the page. A group is what an interval *means*, not a score |
| AC-8's recommendation outlives the records | Every clause is derived, and the scenario re-derives it. A corpus change rewrites the sentence |
| DEC-027 is six hours old and AC-9 revisits its figure | It is not overturned: the interval stays drawn. DEC-027 said the drawn interval makes overlap visible; an outside reader says the ranked form still wins. The grouping is the same claim made structurally rather than argued |
| ~~The family-prefix derivation breaks if a task id is renamed~~ | **Withdrawn.** This row named the risk and then described a mitigation that *required* the broken behaviour. The derivation is gone: the fixture is cited from `bench/REPRODUCE.md` and prefixes are only a consistency check (§2) |
| AC-10's `DESIGN.md` row is skipped because the code works without it | The ticket's Scope.Allowed now names `DESIGN.md` and AC-10 is an acceptance criterion, not a note. DEC-027 is six hours old; changing its ground silently is how a decision log stops being one |
| The three-tier grouping is read as a ranking with extra steps | Tier membership is a statement about intervals, asserted in all three directions and re-derived by the scenario, and the refusal element stays on the page. **An earlier version of this row also claimed "no tier is ordered within itself", which is false**: `RankedBars.astro:55-59` sorts measured arms by point estimate and DEC-027 permitted that. Plan review round 2 caught it. The order inside `overlaps` stays — dropping it would be a second change to DEC-027's figure — and what the tiers add is that no arm is ranked *against an arm in another tier*. AC-10's decision row records exactly this boundary |

## 6. Out of scope

Adding, removing or re-running any task (PDX-036 owns coverage). Re-grading (PDX-026,
PDX-028). The methodology page (PDX-025). Any subjective quality judgement. Adding a
`fixture` field to the records — the fixture is cited from where it is already documented,
and a corpus write to publish a fact that is already written down is not a fix.

## 7. References Consulted

- `.docs/tickets/PDX-035_*` — Y, the ticket including AC-8 and AC-9 added from the outside review
- `DESIGN.md` DEC-005, DEC-020, DEC-025, DEC-027 — Y, read in full; DEC-027 is what AC-9 revisits and its conditions are preserved
- `bench/data/runs/` — Y, **derived directly**: 12 distinct tasks, `tmpl-fe` 6 tasks/127 cells and `tmpl-be` 6 tasks/102 cells in the blocked valid pool. The 181-frontend figure an earlier draft quoted is the both-regimes total and is withdrawn
- `bench/REPRODUCE.md:27`, `bench/README.md:24` — Y, the fixture with its commit and licence: `tiangolo/full-stack-fastapi-template @ cd83fc1` (v0.10.0, MIT). This is the source AC-1 cites instead of parsing ids
- `DEC-019` — Y, "a filename is not the fact", which is the rule the withdrawn prefix derivation broke
- `packages/data/src/aggregate.ts` — Y, `taskOrder`/`domainSummary` are the shape step 1 follows
- `packages/site/src/pages/index.astro`, `components/RankedBars.astro` — Y, read as they are after DEC-027
- The 2026-08-20 outside review of the live site — Y, 6.5/10; its three lost points are AC-4/AC-7 (scope), AC-9 (the figure), AC-8 (the decision)

## 9. Agent Review

### Reviewer
- Model: Opus 5
- Reviewed at: 2026-08-20 18:05

### Verdict
- [ ] APPROVED
- [x] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | Every file in §3 (`packages/data/src/aggregate.ts`, `stats.ts`, `packages/site/src/pages/index.astro`, `components/RankedBars.astro`, `README.md`, `DESIGN.md`, `tests/e2e/PDX-035-*.sh`) is named in the ticket's Scope.Allowed, and each of AC-1..AC-10 now has both a step and an assertion row — AC-7 → step 3 + §4 row 7, AC-10 → step 5b + §4 row 10. Nothing in the plan adds, removes or re-runs a task (Not Allowed), and no figure is typed: steps 1-2 put every count behind `@plugdex/data`. Step 4 still lists `README.md` alone — see Comment 4 |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | §3's eight rows touch 1, 1, 1, 1, 2, 1, 1, 1 files; the only two-file row is step 5, whose pair is the derivation (`aggregate.ts`) and its single consumer (`RankedBars.astro`), and each row states an observable outcome rather than an intention |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | PASS | DEC-027 (`DESIGN.md:182`) declines to license exactly four things — a rank-ordered chip, a composite score, a landing figure without its interval, and an ordering on an unmeasured axis — and the three-tier grouping is none of them: it is one predicate over the interval the figure already draws, membership derived. DEC-027's own derived sentence "how many arms clear the baseline's interval outright — one" still reproduces on the live records: recomputing the repo's Wilson over `bench/data/runs/` (blocked, non-withdrawn, valid, `wroteCode` graded) gives ponytail 16/22 [0.518, 0.868] as the only frontend arm whose `lo` exceeds baseline's `hi` of 0.469. Step 5b + AC-10 put the amendment on the log, which is what DEC-027 itself demands of a moved boundary |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | Round 2's FAIL is closed. §4 now carries 16 rows including the two that were missing: row `7` asserts the external-validity sentence in built output and names **both** halves (describes this fixture's kind of work; nothing has measured whether they transfer), and row `10` greps `DESIGN.md` for the decision row **and** for a DEC-027 back-reference, FAILing if either is absent. The unit-test decision is now stated rather than left open: `corpusInventory` and `separationTier` get tests in `packages/data` with three named cases each, and `separationTier` is pinned on a `null` interval directly because `wilson` at `packages/data/src/stats.ts:68` throws `RangeError` on `n <= 0` (`stats.ts:70`) — so the `unmeasured` branch exists precisely where no e2e can reach it by computation. RED (`test-loop.sh PDX-035 --red`, verify PASS + scenario FAIL, build failure distinguishable) and GREEN (verify, scenario, regression and unit suites all PASS) are both concrete, and the AC-9 numbers the scenario pins are live-correct: superpowers frontend 0 graded of 24 no-code cells → `wilson === null`, ponytail [0.518, 0.868], baseline [0.112, 0.469] |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | §5 carries seven rows including the struck family-prefix row (kept readable, not deleted) and a row each for AC-9-read-as-an-index, AC-10 being skipped, and the three-tier-as-ranking reading. Round 2's Comment 3 is closed honestly: the last row now states outright that "no tier is ordered within itself" was false, cites `packages/site/src/components/RankedBars.astro:55-59` (verified — `[...measured].sort` by `rateFraction`, exactly those lines), keeps the sort rather than making a second change to DEC-027's figure, and narrows the claim to "no arm is ranked against an arm in another tier" with AC-10's row recording the boundary. §6 names PDX-036, PDX-026, PDX-028, PDX-025 and the rejected `fixture` field |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` exits 0 over the whole tree, and re-run against the three reviewed artifacts by path (`.docs/analysis/PDX-035_plan.md`, the PDX-035 ticket, `DESIGN.md`) exits 0 with the PASS line. The gate is not a silent no-op: pointed at a scratchpad control file holding one Hangul line it exits 1 and prints the offending file and line, so the zero above is a measurement. Round 2's own P6 evidence cell — which reproduced a Hangul character class and tripped the gate on this very file — is gone; this review describes the control instead of quoting it |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `./scripts/check-references.sh .docs/analysis/PDX-035_plan.md` exits 0 on the "PDX-035 has no mapped references (§6.5.1)" path; §7's eight rows are each marked Y with a note, and its figures reproduce exactly against the records — 12 distinct tasks, `tmpl-fe` 6 tasks / 127 cells, `tmpl-be` 6 tasks / 102 cells in the blocked non-withdrawn valid pool, and the withdrawn 181 is 127 blocked + 54 as-shipped frontend cells |

### Comments

1. **Round 1 (13:40, NEEDS_REVISION, 5 blockers) and round 2 (16:20, NEEDS_REVISION, 2 blockers) — where the history stands.** Round 1's **B1** (fixture count derived from `tmpl-` prefixes, with a mitigation that required the broken behaviour) was closed in round 2: the fixture is cited from `bench/REPRODUCE.md:27` and the prefix scan survives only as a consistency check that FAILs and names both sides. **B2** (the binary overlap predicate that would have put a null-interval arm beside the only arm clearing baseline) was closed: the predicate tests `wilson === null` first and the scenario pins `superpowers`/`ponytail` by id. **B3** (the CLAIM-01 record reachable only in `README.md`) was closed in the assertion, which follows the link inside `dist/`. **B4** was closed: `DESIGN.md` is in Scope.Allowed and AC-10 is an acceptance criterion. Round 2 then raised **B6** and **B7** and classified both as unclosed round-1 findings rather than new defects, which is why REV-02 permitted this third round as a confirmation pass.

2. **B6 is closed — all three outstanding parts, verified against the records rather than read.** (a) The ticket's "two shapes" bullet now names six and six with the noun restored: `tmpl-fe-*` colour picker, command palette, date picker, dropzone, star rating, form wizard; `tmpl-be-*` archive, count, CSV export, daily count, search, unique title. Deriving the same sets from `bench/data/runs/` gives exactly `tmpl-fe-{colorpicker, command, datepicker, dropzone, rating, wizard}` and `tmpl-be-{archive, count, csv, dailycount, search, uniquetitle}` — six each, matching item for item, and `bulkdelete`/`duplicate` appear in **no** record under any regime or withdrawal state, so the bullet no longer enumerates tasks the bullet above it says were never run and no longer lists eight items under the word "Six". (b) AC-8's missing lost point is filled in: the sentence now reads "named this as one of three lost points: the site is honest but weak at supporting a decision, because a visitor came to decide and leaves with a distribution", so the AC's reason clause is readable. (c) §6 now reads "127 frontend and 102 backend cells in the published pool", with the withdrawal recorded under CLAIM-01 and the arithmetic stated — and the arithmetic checks: frontend valid non-withdrawn cells split 127 blocked + 54 as-shipped = 181 exactly. The stated root cause is consistent with what was found: the surviving damage was uniformly emphasis-adjacent text in one file, which is what an over-broad strip of `*"…"*` produces.

3. **B7 is closed, and the unit-test sentence earns its place rather than filling a slot.** The two missing assertion rows are present and both are checkable as written — AC-7's row names the two halves the AC requires, so a page stating only the first half fails it; AC-10's row FAILs if *either* the row or the DEC-027 back-reference is absent, which is the failure mode that matters, since a `DESIGN.md` row that never names DEC-027 is not an amendment to DEC-027. The `separationTier` justification is not decorative: `stats.ts:68`'s `wilson` throws at `stats.ts:70` on `n <= 0`, so the `unmeasured` branch is unreachable by computation and a scenario that happens to include one null-interval arm today tests the corpus, not the branch.

4. **The risks-row reformulation is honest, and AC-10 is the right home for the boundary.** The row does not quietly drop the false clause — it states that it was false, names what falsified it, and credits round 2. Keeping the within-tier sort is the correct call: `RankedBars.astro:55-59` is the ordering DEC-027 explicitly licensed, and removing it inside tiers would be a second, unargued change to the same figure in a ticket whose AC-10 exists to stop unargued changes. And the boundary belongs in AC-10's row specifically because AC-10 asks which of DEC-027's conditions **still hold** — "the point-estimate order inside a tier survives; what the tiers add is that no arm is ranked against an arm in another tier" is exactly that clause. One refinement for the implementer, not a blocker: §4's AC-10 row asserts the row names "what changed, the evidence, and which of DEC-027's conditions still hold" generically, so the within-tier sort is covered only by implication; naming it in the row's text would make the boundary greppable.

5. **Open notes that ride to the report under REV-02** (none of these blocks the plan). §3 step 4 still lists `README.md` alone while AC-5 and §4's row 5 both require the withdrawal record on the site and linked from the corrected sentence — the e2e will FAIL until it is there, so no wrong page can ship, but the step table under-provisions its own test and `index.astro` (or a withdrawal partial) should be folded in during implementation. §4's ASSERT-01 row now says "nine instances in this project" where `CLAUDE.md:114-122` says six; PLAN-01 (`CLAUDE.md:108`) asks plans to reference volatile facts rather than restate them, so the count should point at the rule instead of carrying a number that disagrees with its source — round 2 raised this at "eight", and it has moved without converging. Step 6 still does not say that AC-8 is partly rendered already, which decides which half of the sentence produces the RED. DEC-016 is cited by neither document.

6. **One consequence the plan should name in the report.** `superpowers` **backend** is 0/1 with interval [0.000, 0.793], so it lands in `overlaps`, not `unmeasured` — the third tier means n=0, not "too little to say", and a one-cell arm will sit in the same tier as an eighteen-cell one. That is defensible (the tier is a statement about the interval, and a one-cell arm does have one), but it is the kind of thing a reader will notice first, and AC-8's backend clause holds on the records regardless: recomputed, every backend arm's interval overlaps baseline's [0.248, 0.699].

7. **REV-02 bookkeeping.** This was a confirmation pass, not a new design round: both round-2 blockers were pre-recorded as incompletely applied round-1 fixes, the edits are now present and correct, and no new defect surfaced. P1-P3 and P5-P7 were re-confirmed rather than re-litigated, with P5 and P6 re-derived because both had a specific claimed change. The plan is approved with the notes in Comment 5 carried to the report.

### Blockers (only if NEEDS_REVISION)

- None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (round 3, 2026-08-20 18:05 — Opus 5; 0 blockers. Round 2's B6 and B7 are both closed and were verified against the records rather than read: the ticket's two-shapes bullet now names six and six matching `bench/data/runs/` item for item with `bulkdelete`/`duplicate` absent from every record, AC-8's lost point is filled in, and §6 reads 127/102 with the withdrawal recorded and 127 + 54 = 181 checked; §4 gains the AC-7 row naming both halves of the external-validity limit and the AC-10 row that FAILs if either the DESIGN.md row or its DEC-027 back-reference is absent, and the unit-test decision is stated for `corpusInventory` and `separationTier` with the `null` interval pinned directly because `stats.ts:68` throws at :70 on `n <= 0`. Round 2's Comment 3 is closed honestly — the risks row states the "no tier is ordered within itself" claim was false against `RankedBars.astro:55-59`, keeps the within-tier sort rather than making a second change to DEC-027's figure, and narrows to "no arm is ranked against an arm in another tier". `check-language.sh` exits 0 with a Hangul control file proving the gate is not a no-op. Notes riding to the report: step 4 under-provisions `index.astro` for AC-5, §4's ASSERT-01 count disagrees with CLAUDE.md against PLAN-01, step 6 omits that AC-8 is partly rendered, and `superpowers` backend 0/1 lands in `overlaps` rather than `unmeasured`)
- Human: pending
