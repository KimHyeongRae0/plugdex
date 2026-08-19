# PDX-005 Report — site: the analysis page

- Ticket: `.docs/tickets/PDX-005_site-the-analysis-page.md`
- Plan: `.docs/analysis/PDX-005_plan.md`
- Author: Fable 5 (report) — implementation by Opus 5, plan and plan review by Fable 5
- Date: 2026-08-19

## 1. Summary

The analysis page exists: a leaderboard with Wilson intervals and per-cell economics, two
trade-off scatters with Pareto frontiers, the frontend/backend split, a radar and counts
table per ticket, token economics, and all 312 cells of the published `blocked` corpus as
a grid with a server-rendered drawer per mark. Every figure on it is computed and
formatted in `@plugdex/data` — five new modules, 31 new unit tests — and the page ships
with one 381-character inline script for the drawer and nothing else: no island, no
framework runtime, readable with JavaScript off.

The ticket's reason for existing is AC-2, and it landed: until this branch, every card
published a frontend-only rate silently — all 103 build-graded cells are `fe-*` tickets
and the 86 backend cells were absent from the number entirely. Now every rendered rate
names its population in the same element (`builds 40% n=20 (frontend)` beside
`passes 39% n=18 (backend)`, quoted from the built `dist/index.html`), the masthead says
why the two gates are not comparable, and a page-wide sweep of both built pages fails any
percentage that appears without its denominator or outside a declared, population-named
element.

Two corrections happened during implementation, and they are the most interesting things
in this report.

**The plan carried a measured figure that was wrong, it was the planner's own, and
chasing it found a defect in the loader.** The plan asserts the wall-clock Pareto frontier
degenerates because baseline and ponytail "sit on the same x to rendering precision (both
about 47s mean)". They do not. Over the rows that carry a duration, the means are 47.0345s
(baseline, 52 rows) and 46.9836s (ponytail, 54 rows) — distinct. The planner read a rounded
display and asserted identity.

The interesting part is what the disagreement exposed. Re-deriving the frontier under both
readings gave different answers, and the reason was `economics.ts` `numberAt`, whose
documented rule was "a numeric field, or zero when the harness did not write one". **An
absent measurement is not a measurement of zero.** Nine of the corpus's 441 result rows
carry no economics at all, two of them baseline rows in the published pool, and read as
zeros they dragged baseline's mean wall clock from 47.03s to 45.29s and its cost from
$0.0914-scale arithmetic into a number nothing measured — far enough to move which points
the chart drew. `numberAt` now returns `null` for an absent field, every mean is a
`Measured = { value, n }` carrying the denominator it was actually taken over, each arm
reports `econMissing`, and the site formats a null through `formatMeasured` rather than
printing a zero. The site-side fallback needed by the token bars lives in `@plugdex/data`
as `measuredOrZero`, because DATA-01 refuses a figure — including a fallback figure —
typed into site source.

With that fixed, the live charts are: **the wall-clock frontier is degenerate** — ponytail
at 46.98s / 73% is faster *and* better than baseline at 47.03s / 25%, so it is the sole
member and no line is drawn — while the cost frontier keeps two vertices (baseline
$0.0849 / 25% to ponytail $0.0914 / 73%). Verified in built output: one `path.pareto`
with `M241.24,199.5 L256.39,91.64`, and one `data-frontier-note="sole"` naming ponytail in
words. So **AC-4's no-frontier branch is not only implemented and unit tested
(`pareto.test.ts:40`) — it is what the live corpus renders**, which is the opposite of what
this report said before the loader was corrected. §8 records what remains sensitive.

**The page shipped a label claiming a check that does not happen, and no gate caught it —
it was caught by reading the harness.** The backend column and the hero prose said the
backend gate is "whether the delivered tests pass". `bench/harness/acceptance.py:390`
computes `"passes": bool(be_files and ok_import and not new_diags)` — the delivered code
imports and introduces no new mypy/ruff diagnostic. **No test suite runs for a backend
cell at all.** Six sites were corrected to say what the gate does: `DomainSplit.astro`
("imports, and adds no new diagnostic"), `index.astro`, `analysis.astro` ("No test suite"
stated outright), `PackCard.astro`, `verdict.ts`, and `schema.ts`, whose comment now also
records why the mistake was available to make: the field is named `passes`, and a reader
supplies the stronger meaning. A test name in `grade.test.ts` was corrected to match ("a
backend cell is graded by import plus a clean diagnostic count, not by import alone").
DATA-01 checks that figures come from records; nothing checks that a label describes the
computation it names, which is why a reading pass caught this and no gate did.

**And the sweep missed a seventh site — found while verifying this report, and now
fixed.** `packages/data/src/grade.ts:68` (`graderLabel`) returned
`'the backend gate: the delivered tests'`, its doc comment repeated the claim, and
`CellGrid.astro:83` rendered it into the drawer of every backend-domain mark — **102
occurrences in the built `dist/analysis.html`, verified by grep before the fix.** The
six-site correction had centralised the grader's words next to the grader and then not
corrected the one function built to be that single source, which concentrated the error
instead of removing it. `graderLabel` now returns
`'the backend gate: imports, and adds no new diagnostic'`; the doc comment states the
computation, names `acceptance.py:390`, says outright that no test suite runs, and records
that an earlier version claimed otherwise and how far it travelled. A grep of `packages/`,
`docs/` and `README.md` for "delivered tests" now returns only those two deliberate
historical mentions in `grade.ts` and `schema.ts`. It remains the sharpest available
evidence for the §8 question of whether prose-matches-computation deserves a rule.

**Report review round 1 returned NEEDS_REVISION with four blockers, and every one of them
was real.** They are listed here rather than buried in §10, because two of them are the same
defect as the two above — a corrected computation shipping beside prose that still describes
the version it replaced.

1. **The page did not print `econN`.** §5 and §8 of the first draft both asserted a per-arm
   pool size on the page as the mitigation for the absent-measurement problem, and `econN`
   appears in no site source at all. An unrendered mitigation described as a partial one is
   worse than admitting the gap. Fixed by rendering it — see below, because the fix is not
   the obvious one.
2. **`README.md` and `docs/images/**` rode this commit outside Scope.** §9 had split
   `bench/**` and `CLAUDE.md` out on exactly that reasoning and then not applied it to these.
   The ticket's Scope.Allowed now names them, with the boundary stated: an unnamed file is a
   gap in a scope section and may be closed; `bench/**` is named `Not Allowed` in as many
   words and a ticket may not widen an explicit refusal after the fact.
3. **The corrected rule was contradicted by prose shipped beside it, in four places.**
   `economics.ts:137` still carried `A numeric field, or zero when the harness did not write
   one` — the exact retracted sentence — two lines above a body returning `null`;
   `loadEconomics`'s doc still said means pool every joined row without saying what a mean is
   taken over; `pareto.ts` still carried the retracted same-x premise; and `analysis.astro`
   told the reader the means were "over every cell of the run" while baseline's cost mean was
   over 52 of 54. All four corrected.
4. **A rate was computed in site source.** `Leaderboard.astro` divided `summary.hits /
   summary.n` because `RateSummary` exported no fraction, and the product became a bar width
   a reader compares. `rateFraction` now lives in `@plugdex/data`; the component keeps one
   multiplication by a named layout scale, which is the idiom `TokenBars.astro` already used.

**Report review round 2 returned NEEDS_REVISION with five more blockers, and they were
right about something the first round had let through.** Recorded in full because three of
them are the same failure mode a third and fourth time.

5. **The README's screenshots published withdrawn numbers.** `docs/images/analysis-*.png`
   were re-rendered at 19:24, *before* the loader fix at ~21:00. `analysis-leaderboard.png`
   printed baseline at `$0.0818` / `45s` — the diluted figures — under the retracted sentence
   "means over every cell of the run", and `analysis-tradeoffs.png` drew the two-vertex
   wall-clock frontier with baseline left of ponytail, which is precisely the trade-off §1
   says the absent-as-zero fold invented. §2 asserted they were "re-rendered from the built
   page". So the ticket that corrected a figure shipped a picture of the uncorrected one, in
   the README, in the same commit. All six are re-captured from the current build.
6. **Blocker 4's fix went to the file the reviewer named rather than the construct.**
   `rateFraction` closed `Leaderboard.astro` and left five other divisions on the figure
   path: `DomainSplit.astro:46` (the point-estimate tick a reader compares against the
   Wilson band drawn beside it), `analysis.astro:85` (the leaderboard's sort order), `:127`
   (the scatter height the Pareto frontier is drawn through), `:170` (the radar radius) and
   `TicketBreakdown.astro:105` (the tint). All five now go through `rateFraction`. The
   reviewer's failure scenario is the reason it matters: PDX-026 changes what `armSummary.n`
   counts, after which a bar routed through the package would track the new definition while
   a tick computed in the component would not — and the AC-1 probe recomputes the
   leaderboard's *strings*, not the split's *positions*.
7. **§4.1's evidence was produced by a run predating the code it certified**, §4.0 omitted
   four GREEN stamps, the unit count was stale by exactly the test the round had added, and
   Files Changed omitted two tickets in the tree. All corrected below; the round log now
   reconciles against every stamp in the state file rather than against memory.

**Two things the fix itself broke, both found by measuring rather than by reading.** The
`n=52/54` form began life as `over 52 of 54`, which was wide enough to push the leaderboard
table 75px past its container — so the README capture clipped the Seconds column, and no
viewport width fixed it because the container's width is the page measure. The compact form
fits. And the new `.shortfall` span was outside the browser scenario's contrast selection
entirely, so its passing said nothing about the new element; it is now in the sweep,
measured at 7.89:1 light and 8.98:1 dark against a 4.5:1 floor, and the sweep was
negative-controlled by dimming the rule to `opacity: 0.06` and confirming it FAILs at
1.13:1 naming each field.

**The `econN` fix is worth its own paragraph, because the obvious version would have been
wrong.** One pool size per row reads as one denominator for the row, and the denominators
differ *per metric within an arm*: baseline's cost mean is over 52 rows while its
lines-of-code mean is over all 54, because the two rows that recorded no money still recorded
their diff. So the disclosure is per figure — `formatShortfall` returns `over 52 of 54` for a
mean that fell short and `null` for one that did not, and the cell prints nothing when there
is nothing to say. Twelve shortfall markers render on the live page across three arms, and
`loc` correctly carries none. A single `econN` column would have told the reader something
false about four of the five economics columns.

Built from `git status --short` and `git diff`, re-checked row by row against the diff rather
than against memory. The tree holds **56 files** — `git status --short` on the unstaged tree
prints 50 lines, but one of them is the untracked directory
`packages/site/src/components/analysis/`, which is six files; §9 records how many passes that
unit ambiguity survived. **Eleven of the 56 are outside this ticket's scope and do not ride
its commit** — three files, the `PDX-025` draft, and seven new tickets; the split is stated
in §9, and the rows below cover the tree entry by entry including this document itself.

| File | Change |
|---|---|
| `packages/data/src/stats.ts` + `stats.test.ts` | **New.** `wilson` (z pinned with its derivation), `axisTicks`, `formatMeasured` (which renders an unmeasured mean as an absence rather than as a zero), `formatShortfall` (review blocker 1), and every formatter the page renders through — `formatRate` now lives here (deviation, §3 step 6) and requires a `population` baked into the returned string. 10 tests pin 5/20 to [0.1119, 0.4687], the n=0 refusal, the asymmetric 0/n and n/n bounds, and that an unmeasured mean never reaches its formatter |
| `packages/data/src/aggregate.ts` | `rateFraction` added (review blocker 4): the rate as a fraction, so no component divides to size a bar |
| `packages/data/src/grade.ts` + `grade.test.ts` | **New.** `gradeCell` closed union (invalid / no-code / built / failed / ungraded), domain read off the cell; `import_ok` rejected as the backend gate because it is 100% for every arm. 6 tests cover every branch, including `importOk: true, passes: false` = failed. `graderLabel` **corrected** to name what the backend gate computes, with the history of the wrong label recorded at the source (§1) |
| `packages/data/src/aggregate.ts` + `aggregate.test.ts` | **New.** `armSummary`, `domainSummary`, `taskSummary`, `cellGrid` (one mark per repetition, corpus totals), `invalidByTask`, orders read off the records. 9 tests; n=0 yields counts with no rate, so superpowers can only render `no graded cell` |
| `packages/data/src/economics.ts` + `economics.test.ts` | **New.** `loadEconomics` joins each `*.results.json` to the acceptance record whose `run` equals the record's own `date`; regime and withdrawal are inherited; an orphan is refused by name. Every mean is a `Measured = { value, n }` and `numberAt` returns `null` rather than zero for an absent field, with `econMissing` per arm and `measuredOrZero` for the one place a fold needs a number (§1). 5 tests, including the AC-3 fixture whose filenames contradict its records and the absent-metric row that must not average in as zero |
| `packages/data/src/pareto.ts` + `pareto.test.ts` | **New.** `paretoFrontier`: sort by x, collapse x-ties to best y, keep strictly increasing y. 4 tests: normal frontier, x-tie, the single-dominating-point degenerate, empty-input refusal |
| `packages/data/src/verdict.ts` | `BuildRateVerdict` gains `backendPasses`/`backendN` + baselines via `backendCounts` (delegating to `domainSummary` — domain-scoped because `passes` is recorded on frontend cells too, 12/35 vs the honest 7/15); `buildCounts` documented as deliberately unchanged; `formatRate` moved out |
| `packages/data/src/verdict.test.ts` | 3 new tests (19 total): rate never without denominator+population; both populations or neither; backend rate counts backend cells only |
| `packages/data/src/schema.ts` | The corrected `passes` doc comment: names `acceptance.py:390`'s computation, states no test suite runs, and records that an earlier version claimed a stronger check |
| `packages/data/src/index.ts` | Export surface for the five modules; `formatRate` re-exported from `stats.js` so the package contract is unchanged |
| `packages/site/src/pages/analysis.astro` | **New.** Loads corpus + economics at build time, names the condition and the withdrawn count, composes the six sections, carries the AC-8 refusal element and the "No test suite" gate prose |
| `packages/site/src/components/analysis/{Leaderboard,DomainSplit,TradeoffScatter,TicketBreakdown,TokenBars,CellGrid}.astro` | **New, six components.** All static SVG/CSS; every text token imported, geometry from layout-named constants; grid marks shape-primary (DEC-018); drawer per mark as native `<dialog>` |
| `packages/site/src/components/PackCard.astro` | Four rates in two named populations, side by side, one shared style, no comparison drawn (AC-2 on the existing card) |
| `packages/site/src/components/VerdictChip.astro` | Build-rate chip label becomes `builds N% n=M (frontend)` via `formatRate`; `percentOf` stays for the no-code chip's non-domain share |
| `packages/site/src/pages/index.astro` | Nav (catalogue / analysis), masthead paragraph naming the headline as the frontend build rate and the backend gate as import + no new diagnostic |
| `packages/site/src/styles/global.css` | +611 lines: analysis-page rules under the existing token system, both schemes |
| `scripts/check-data.sh` | Walk regex gains `tsx`; dispatch routes `.tsx` to `scanCode` (the mis-route into the Astro scanner the plan review found, closed with a comment saying why); `JsxText` branch BLOCKs digits in rendered JSX text; `JsxAttribute` branch exempts machine-facing attributes and BLOCKs reader-facing ones |
| `tests/meta/cases/{69,70,71}-site-tsx-*.sh` | **New.** JSX-text BLOCK, reader-facing-attribute BLOCK, clean pass — each planting the clean `.astro` companion and pinning the specific rule id, because a tsx-only sandbox exits non-zero for an unrelated reason |
| `tests/e2e/PDX-005-the-analysis-reads.sh` | **New.** AC-1/2/3-surface/4/5/6/8/9 over built output, node probes re-deriving every figure, the extended `read_html.py` reader proven against six planted fragments before it is trusted — and the dangling-tag fix, §8 |
| `tests/e2e/PDX-005-the-analysis-looks-right.sh` | **New.** Chromium over `astro preview`, {360x740, 1280x800} x {light, dark}: computed-style state distinctness, 3:1 / 4.5:1 floors, no body-level horizontal scroll, 4 screenshots to `.docs/scratch/pdx-005-browser/` |
| `DESIGN.md` | DEC-023 (population naming + zero client JS), DEC-024 (economics join + `passes` over `import_ok`), DEC-025 (sorted-with-intervals is disclosure, boundary vs DEC-005), DEC-026 (the radar ships, band unclipped); PDX-005 roadmap paragraph rewritten; PDX-021 scope note corrected (`.tsx` scanned; `public/`, `.md`/`.mdx`, substituted template literals remain) |
| `README.md` | The two-gates paragraph ("No test suite runs for a backend ticket"), the heat image and its reference removed, status paragraph updated to "rendered from the analysis page as it is built today". **Named in Scope.Allowed by review blocker 2**, having ridden the first draft unnamed |
| `docs/images/analysis-{cells,domains,leaderboard,radar,tradeoffs,tokens}.png` | **Re-captured from the current build**, at 1440px with a real browser over `astro preview`. The previous set was re-rendered *before* the loader fix and published withdrawn figures in the README — report review round 2's first blocker, and the sharpest one in this cycle: a receipt that disagreed with its own claim, riding the commit that corrected it |
| `docs/images/analysis-heat.png` | **Deleted** with its README reference — the counts table beside the radars is the shipped rendering of those numbers |
| `docs/images/analysis-tokens.png` | **New** screenshot of the token-economics section; referenced by no document yet (§8) |
| `.docs/tickets/PDX-005_site-the-analysis-page.md`, `.docs/analysis/PDX-005_plan.md`, `.docs/receipts/PDX-005-plan-review.json` | The rewritten ticket, the approved plan (two review rounds), and the review receipt |
| `.docs/tickets/PDX-025_site-the-methodology-page.md` | **New ticket**, drafted during this cycle: publish the environment facts and reproduction story the repository already holds. Not this ticket's scope; listed because it is in the tree, and it rides the second commit (§9) |
| `.docs/analysis/PDX-005_report.md` | **This document.** Listed because report review round 3 found it was the one tree entry with no row here — a Files Changed table that omits itself is the same defect as a rate that omits its denominator, and it went three rounds unnoticed |
| `.docs/tickets/PDX-026..032` | **Seven new tickets, out of scope**, written from the engine audit and the methodology research that ran alongside this cycle: validity as one recorded fact, gate-stack scoping, the gate-set alignment defect, the composition of a failure, the premise correction, the arm-activation defect, and the condition-naming defect. They ride the second commit |
| `CLAUDE.md`, `bench/README.md`, `bench/PREREGISTRATION-2.md` | **Out of scope — these do not ride this ticket's commit (§9).** `CLAUDE.md` is the user's 2026-08-19 model-policy instruction; the two `bench/` files are CLAIM-01 corrections that came out of an engine audit run in the same session. The ticket's Not Allowed list names `bench/**` explicitly, and the right answer to a scope boundary is a second commit, not a quiet exception |

## 3. Plan Compliance

| Plan step | Done | Deviation (if any) |
|---|---|---|
| 1 — Wilson + formatters | ✅ | **Extended:** formatters beyond the plan's enumeration (`formatTurns`, `formatLoc`, `formatTaskLabel`, `formatGradedCells`, `formatDomainLabel`, `formatDenominator`, `formatAbsent`, per-axis tick formatters). Disclosed reason holds up: the page-wide sweep requires every reader-visible token to arrive imported, so every string the page prints needs a formatter, not only the ones the plan happened to list |
| 2 — per-domain grader | ✅ | None structurally. `graderLabel`'s backend wording was the seventh site of the label defect; found while verifying this report and corrected before commit (§1) |
| 3 — aggregates | ✅ | None |
| 4 — economics join | ✅ | **Interpretation the plan did not name, and the first reading of it was wrong.** Rows whose `cost`/`turns`/`duration_ms` are null (9 across the corpus, 2 of them baseline rows in the `blocked` pool) first entered the means as zeros. The plan said "means pool every joined row, invalid cells included", which is about *which rows*, not about what an absent field means — and reading the second question through the first put four arms' means below anything measured. Corrected: a mean is taken over the rows that carry the field, and carries that denominator (§1) |
| 5 — Pareto frontier | ✅ | None in the code. The plan's *premise* was a wrong figure (baseline and ponytail are not tied at 47s), and the conclusion it drew from it — that the wall-clock frontier degenerates — turns out to hold for the opposite reason: ponytail dominates on both axes, §1 |
| 6 — `formatRate` spine | ✅ | **Deviation:** `formatRate` lives in `stats.ts` with the other formatters rather than staying in `verdict.ts`. The contract is what the plan specified — required `population`, baked into the string, every call site forced by typecheck — and `@plugdex/data`'s export surface is unchanged; only the file moved. `percentOf` stays exported, as planned |
| 7 — the card names its population | ✅ | None. Nav ships with two routes only, as planned |
| 8 — page + leaderboard + split | ✅ | **Deviation, found by report review across two rounds and disclosed here rather than left for PDX-021.** The plan's D4(d) says fractions that become widths arrive from the package so no site expression divides. Six sites divided `hits / n` because `RateSummary` exported no fraction — a bar width, a point-estimate tick, a sort key, a scatter height, a radar radius and a tint. Round 1 named one, round 2 named the other five, and all six now go through `rateFraction`; `grep -rn 'hits / .*\.n' packages/site/src` returns nothing. AC-8 element `data-composite-index="refused"` present with the derived clears-the-interval sentence (live corpus: one arm) |
| 9 — scatters, radar, token bars | ✅ | None. The cost chart draws a two-vertex frontier; the wall-clock chart draws none and says in words which single member the frontier holds (§1) |
| 10 — cell grid + drawer | ✅ | Per-mark dialogs shipped; the built page is 275,536 bytes (275 KB, measured), so the plan's shared-dialog fallback was not needed — recorded in DEC-023 as the plan asked |
| 11 — the `.tsx` walk | ✅ | Includes plan-review comment 5's dispatch routing (`endsWith('.ts') || endsWith('.tsx')`), which the plan text named only in the review |
| 12 — decisions + roadmap | ✅ | DEC-023..026 landed at the expected numbers; PDX-021 scope note corrected; the Reference Map machine copy left alone, as §5 of the plan said |

**Two amendments to the ticket, both made by report review round 1 and both recorded in the
ticket itself with their date and cause.** Scope.Allowed now names `README.md` and
`docs/images/**`, and AC-1 now requires every economics mean to carry the denominator it was
taken over whenever that is fewer than its arm's pool. Amending a ticket after the work is a
move that can hide a scope violation, so the boundary is written into the ticket beside the
amendment: an unnamed file is a gap and may be closed; a file named `Not Allowed` may not.

The plan review's four report-stage carries were all closed in the shipped scenario rather
than ridden further: the percent-word bypass (`PERCENT` matches `\d+\s*percent\b`), the
attribute-borne rate (the sweep reads `READER_FACING_ATTRIBUTES` values), the split-rate
markup caveat (a planted fragment), and each is proven against a planted known-bad input
before the reader is trusted on the live pages.

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

From `.docs/state/PDX-005.state` and the OBS-01 gate log, which record the loops but not
which correction rode which loop; the corrections named below are ordered by the log's
timestamps where the log says so, and disclosed without per-loop attribution where it
does not.

| Round | Command | Result |
|---|---|---|
| 1 | `./scripts/test-loop.sh PDX-005 --red` | **RED OK** (18:24:34) — verify PASS on the untouched tree, both PDX-005 scenarios FAIL (e2e FAIL, 5s). The AC-9 probe's clean-companion design mattered here: a tsx-only sandbox fails before the walk change for the wrong reason, so a bare `DATA-01` match would have been a fake RED |
| 2 | `./scripts/test-loop.sh PDX-005` | **GREEN** (18:56:38) — first full pass: verify, both scenarios, regression |
| 3–6 | `./scripts/test-loop.sh PDX-005` (four re-runs) | **GREEN** at 19:03:01, 19:08:39, 19:15:13, 19:23:56 — each following a correction in the window this report discloses: the backend-label sweep across six sites, the frontier premise correction, the reads scenario's dangling-tag fix, and the README/DESIGN text. The log proves each landed behind a fresh full loop; it does not say which rode which |
| 7 | `./scripts/test-loop.sh PDX-005` (report drafted) | **GREEN** (20:46:14, exit 0) — verify PASS, e2e 10/10 |
| 8–14 | `./scripts/test-loop.sh PDX-005` (report verification and two review rounds) | **GREEN at every one.** `.docs/state/PDX-005.state` records 15 `green` stamps in total. Rounds 1–7 above account for the first six, not seven — round 1 is the RED loop and stamps no green — and these seven are the next seven, leaving the two the final row covers. Report review round 3 found this line off by one in both numbers, which is the third consecutive round to find the round log stale: the log is written before the loops that fix the round's findings, so it is wrong by construction until it is re-derived last. They carry, in order: `graderLabel`'s wrong backend label; `numberAt` reading an absent measurement as zero; the `formatMeasured` unit test this report's own coverage check found missing; then report review round 1's four fixes (`formatShortfall` and its rendering, the ticket amendments, the four prose corrections, `rateFraction`); then round 2's (the five remaining divisions, the compact shortfall form, the contrast sweep extension, the re-captured screenshots). Two of these loops went RED first and are recorded as such rather than smoothed over: DATA-01 BLOCKed the `?? 0` fallbacks the `rateFraction` refactor introduced — correctly, a fallback is a figure — and `pnpm lint` BLOCKed the formatting of the same change. Both were fixed and re-run |
| 15–16 | `./scripts/test-loop.sh PDX-005` (round-2 fixes, then final) | **GREEN** at 23:52:35 and 23:59:37 (exit 0) — verify PASS 40s, gate self-test 71/71, ticket e2e 2/2, regression 10/10. Two loops, not one: the first closed round 2's fixes, the second is the tree this report describes. Every §4.1 figure below was produced by the second or re-derived beside it |
| review 3 | `./scripts/verify.sh`, `check-gates.sh`, both scenarios, unit suites | Re-run by the round-3 reviewer against this tree rather than by `test-loop.sh`, so they stamp no state: verify PASS 42s, 71/71, e2e 2/2, regression 10/10, units 78/78, LANG-01 PASS. The state file therefore still holds 15 `green` stamps across 16 rounds — the difference is round 1, which is RED by design |

### 4.1 Final GREEN evidence

All re-run while writing this report, not quoted from the implementation session:

- check-test-case: **PASS** (both PDX-005 scenarios named)
- verify (language + structure + gates + no-llm + templates + data-universe + typecheck +
  lint + test + build + SRC-01): **PASS** (inside round 7's test-loop, exit 0)
- ticket e2e: **PASS 2/2** — reads: AC-1 six leaderboard rows recomputed from
  `@plugdex/data`; AC-2 reader rejects all five planted bypasses, passes the declared
  shape, sweeps both built pages, every card shows both populations; AC-3 surface six
  arms with denominators (econN floor 39) and shares summing to one; AC-4 quoted verbatim
  from the run — "2 scatters rendered; 1 draw a frontier with the derived vertex count and
  1 state in words which single member the frontier is"; AC-5 five radars, 60 band
  vertices within 0.5 viewBox units of the Wilson `hi` radii, 72 counts cells printing
  `k/n`; AC-6 312 marks over 72 squares, 229 valid, per-state counts matching the grader;
  AC-8 refusal element plus the negative sweep it gates; AC-9 gate BLOCKs `DATA-01b` at
  the `.tsx` path beside a clean companion. looks-right: 4 viewport/scheme combinations
  over 312 marks, non-colour state distinctness on computed style, 3:1 and 4.5:1 floors,
  no body-level horizontal scroll at 360px
- regression (`e2e.sh` all): **PASS 10/10**
- gate self-test (`./scripts/check-gates.sh`): **71/71**, cases 69/70/71 among them
- data units (`pnpm --filter @plugdex/data test`): **78/78**, counted per file for this
  line rather than carried forward — stats 10, grade 6, aggregate 9, economics 5, pareto 4
  (34 in the five new modules), verdict 19 (3 new), load 25. The count moved three times
  during verification, each time because a check found an exported function with no test:
  `economics.test.ts` gained the absent-metric test pinning the loader fix; `stats.test.ts`
  gained one for `formatMeasured`, which shipped exported and untested until this report
  checked; and `stats.test.ts` gained one for `formatShortfall`, which would otherwise have
  repeated that exact defect one round later. Report review round 2 caught this line still
  reading 77 — stale by precisely the test the round had added, which is the failure it was
  reporting, in the sentence reporting it
- `./scripts/check-language.sh`: **PASS**

## 5. Non-Scriptable Verification (DEV-01)

| Item | Result | Notes |
|---|---|---|
| CI workflow executes this ticket's scenarios on the runner | **Checked, no change needed — checked rather than defaulted, because "no workflow file changed" is the reasoning that once let a browser scenario reach CI with no browser** | `.github/workflows/ci.yml` read end to end: the e2e job runs `pnpm build`, then `pnpm --filter @plugdex/site exec playwright install --with-deps chromium` (added by PDX-004's follow-up `943009c` after exactly that failure), then `./scripts/e2e.sh` with no argument — which now includes both PDX-005 scenarios; both scenarios build the site themselves before reading it, so they do not depend on a leftover `dist/`; the reads scenario's python3 reader is the same interpreter PDX-004's reader already exercises on this runner; and the `changed` job's skip allowlist is only `docs/*.md` and `.docs/*`, so this diff (packages, scripts, tests) always runs the suite |
| Analysis page visual quality, 360px and 1280px, both schemes | **PASS (judged)** | The four screenshots the scenario writes to `.docs/scratch/pdx-005-browser/` were opened and reviewed for this report: single column at 360px with every chart inside its container, the grid scrolling in its own box, counts legible on the tints, the dark scheme holding the same structure. Judged, not measured — the measurable half (contrast, scroll, distinctness) lives in §4's scenario |
| The cell drawer on the keyboard | **PASS (driven)** | Driven in a real Chromium over the built page for this report: focus a mark, Enter opens the dialog, Escape closes it, focus returns to the triggering mark — `{"open":true,"closed":true,"focusRestored":true}` |
| Radar band readable as an interval, not decoration | **PASS (judged)** | On both screenshots the pale band sits visibly behind the solid estimate polygon and swallows most of several axes — which is the honest rendering the ticket demands; the caption under each radar says what the band is. The geometric half (vertices at Wilson `hi` within tolerance) is §4's assertion |
| Token bars readable in grayscale | **PASS (judged)** | Segments are ordered identically per row and every row prints its total and per-kind counts in ink; the screenshot reads without hue. The page states the segments keep a fixed order |
| Whether the backend drawer text reads as true | **PASS, after a FAIL this row caused** | This row exists because reading the rendered drawer is how the seventh site surfaced: the drawer named its gate as "the delivered tests" 102 times (§1). A DEV-01 pass that only checked layout would have called this page done. Re-read after the fix in the built page: the backend drawers now say "the backend gate: imports, and adds no new diagnostic", and a grep of `dist/analysis.html` for "delivered tests" returns nothing |
| Whether a printed mean reads as true | **PASS, after a FAIL this row caused** | Added while verifying the row above, on the same reasoning. Reading the leaderboard's baseline row against the records is what exposed the absent-as-zero fold: the page printed 45s and $0.08 for an arm whose measured rows say 47s, and no gate can tell a plausible mean from a diluted one. Re-derived after the fix — every printed mean equals a mean over the rows that carry the field. **This row asserted a rendered `econN` that did not exist**, which report review round 1 caught: the mitigation was described before it was built. It is now built — three arms print `n=52/54` or `n=53/54` under the four figures that fell short, and `loc` prints none because its mean used every row |

## 6. Regression Check

`./scripts/e2e.sh` full run inside round 7: **10/10** — PDX-001, PDX-002, PDX-003,
PDX-004 (both), PDX-005 (both), PDX-016, PDX-017, PDX-023. Nothing flaky, nothing
skipped.

PDX-004's two scenarios are the load-bearing regression: `formatRate`'s signature change
rippled through every card call site, and the chip and rate strings they assert changed
shape (`builds 40% n=20 (frontend)` where `40% n=20` used to stand alone). Both scenarios
pass over the new strings, so their contract — every rate carries its denominator — held
while being strengthened, which is what the plan's risk row said must be true.

`check-gates.sh` 71/71: the three new cases replay on every verify, which is what keeps
the `.tsx` walk non-vacuous while the live tree ships zero `.tsx` by choice (DEC-023).

## 7. Rules Verification

- LANG-01: `./scripts/check-language.sh` PASS (re-run for this report). One thing worth a
  sentence given a plan review in this repository was once blocked by the gate for
  quoting a character range: this report describes the language rule without reproducing
  any non-Latin character, and everything it quotes is English.
- DATA-01 / DEC-017: no figure is typed in the site — every rate, interval, mean, count,
  tick label, share and frontier membership arrives formatted from `@plugdex/data`, tick
  labels included (`axisTicks`), fractions exported as fractions so no site expression
  multiplies by 100. The source gate widened to `.tsx` with both-direction golden cases
  in the same change (GATE-01). Enforcement is still source-side; the destination check
  stays owed to PDX-021, and this page's discipline is what keeps its derivable set
  constructible.
  **What this bullet does not claim, disclosed by report review round 3:** DATA-01 does
  not enforce the part of the rule that took two review rounds to satisfy. It BLOCKs a
  typed literal, which is why it correctly caught the `?? 0` fallbacks; it does not BLOCK
  a *division* in site source, because its layout-vocabulary exemption lets `a / b` past.
  So the six sites now routed through `rateFraction` are held there by review and by a
  grep, not by a gate, and a seventh division added tomorrow would pass silently. That is
  a standing exposure, not a fixed defect, and it belongs to PDX-026 — the ticket that
  changes what a rate's denominator counts is exactly the change this exposure would let
  diverge unnoticed.
- DATA-02 / DEC-024: the economics join is decided by record fields (`date` = `run`),
  regime and withdrawal inherited, filenames consulted nowhere — the unit fixture's
  filenames lie and the join follows the records; an orphan results record is refused by
  name.
- DEC-005 / DEC-025 / DEC-016: no composite index (stated on the page with its reason,
  swept by AC-8); sorted-with-intervals confined to the evidence page; the four card
  rates share one style and draw no comparison.
- DEC-018: grid marks are ink shapes with hue as tint only; asserted on computed style in
  both schemes (§4).
- DEC-020: one condition, named in both mastheads with the withdrawn count.
- DEC-021 / DEC-022: the card edits touch the rate block and masthead only — install
  state untouched.
- ASSERT-01: every probe prints a sentinel; the AC-2 reader is proven on six planted
  fragments before the live pages; floors are derived (a zero-rate sweep FAILs); the AC-8
  negative sweep runs only after the positive element is found.
- PLAN-01 / REV-02: the plan review ran exactly two rounds; its four carries are closed
  in the scenario (§3). The frontier figure is the counterexample to note: the ticket
  designated the plan as the record of the prototype's measured figures, one of those
  figures was wrong, and the tests caught the consequence (a frontier the plan said would
  not exist) rather than the prose. That is PLAN-01 working — the number the page renders
  was re-derived, the number in prose was not — and §8 says what it cost.

## 8. Risks / Notes

**The drawer claimed a check that does not happen; fixed, and worth recording why it
survived a six-site sweep.** `graderLabel` exists so the legend and drawer type no words of
their own, and centralising the words next to the computation is exactly right — but it
concentrated the error too, and the sweep corrected every site except the one built to be
the single source. The lesson generalises past this string: a correction pass that greps
for the wrong words finds the copies and misses the original, because the original is the
one place the words were supposed to live.

**Nothing checks that a label describes the computation it names — is that worth a
rule?** DATA-01 checks figure provenance; the label defect and its 102-fold residue both
sailed through every gate, and were caught by reading `acceptance.py` and by reading the
rendered drawer. Honestly assessed: a general prose-matches-computation gate is not
buildable — the falsifiable core (a named gate claim near a grader label) is a narrow
grep away, but the misleading set is generative, and DEC-017's own argument warns against
a gate that blocks prose it cannot understand. What is cheap and real: the schema comment
now names the computation at its source with a file:line, and a golden-style assertion
could pin the one string `graderLabel` returns against a wordlist ("tests" not among
them). **Decided, after two review rounds re-asked it in the same words:** it does not ride this
commit and it does not get a ticket of its own. It folds into PDX-028, which already changes
`graderLabel`'s subject — that ticket adds the fixture's test suite to the backend gate, so
the label's wording changes there anyway, and pinning the string against a wordlist in the
same change is where the assertion is cheapest and least likely to rot. Recorded here so the
next reader sees a decision rather than a third instance of the same open question.

**The wall-clock frontier's membership was one pooling decision away from flipping, and
that decision is now the one the records support.** Nine rows carry null metrics, two of
them baseline rows in the published pool. Read as zeros they put baseline's mean at
45.2925s where its measured rows say 47.0345s, and moved it left of ponytail — inventing a
trade-off between an arm that is slower and worse and one that is faster and better. The
loader now takes each mean over the rows that carry the field and reports how many those
were. **And the disclosure is now on the page**, which the first draft of this section wrongly
implied was already half-done. `formatShortfall` prints the denominator under any figure
taken over fewer rows than its arm's pool, and prints nothing under the rest — because the
shortfall is per figure, not per arm: baseline's cost mean is over 52 rows while its
lines-of-code mean is over all 54, so a single per-row denominator would have been false of
four of the five economics columns.

**AC-4's degenerate branch is now exercised live, which is not the same as being safe.**
The wall-clock chart draws no line and names ponytail in words (§1). The scenario derives
its expectation from the data at run time, so the assertion follows the corpus rather than
pinning today's answer — meaning the two-vertex path is now the one no live chart on this
page exercises, on the wall-clock axis at least; the cost chart still draws it. Both
branches are unit tested either way (`pareto.test.ts`).

**The `.tsx` walk's live coverage is vacuous by choice.** Zero `.tsx` ships (DEC-023);
cases 69–71 are what keep the walk honest, replayed 71/71 on every verify. The
substituted-template-literal residue is recorded in the PDX-021 roadmap row, not closed.

**The scenario author found PDX-004's reader returning fragments with a dangling closing
tag, and fixed it in the extension rather than in PDX-004's reader.** `read_html.py`'s
`_inner` stops at the closing tag's *name*, so every fragment ends in a dangling `</td`
or `</span`; PDX-004 never noticed because its assertions are substring matches, but this
ticket compares fragment text for emptiness, and a permanent half-tag makes "this cell
renders no count" false of every cell forever — an assertion unable to fire, reporting a
checkmark. The fix (`DANGLING` trim) sits at this scenario's boundary
(`PDX-005-the-analysis-reads.sh:253`, `:286`, `:325`) with the reason in a comment:
editing a shared reader out from under the scenario that owns it is how a green PDX-004
would have stopped meaning what it meant. The reader defect itself still exists in
PDX-004's copy and is harmless there today; worth a line in whichever ticket next touches
that scenario.

**Small loose end:** `docs/images/analysis-tokens.png` is committed-to-be but referenced
by no document (`analysis-domains.png` was already in that state before this branch).
Either the README gains the section or the file should not ride this commit.

**Follow-up ticket in the tree:** PDX-025 (methodology page) was drafted during this
cycle and rides the second commit (§9) rather than this ticket's.

**Two loops of this ticket's own defects were found by reading, not by gates.** The label
and the absent-as-zero fold both produced output that was well-formed, plausible, and
wrong; verify, the gate self-test, both scenarios and the regression were green across
every one of them. That is not an argument for more gates — §8's first note explains why
the general version is not buildable — but it is the measured reason this report's
Non-Scriptable section grew a second row, and it belongs in the record for whoever next
argues that a green loop is a finished ticket.

## 9. CR-01 Compliance

- No commit / push / issue / PR / merge / release performed without explicit user
  instruction during this ticket: **YES.** HEAD is `f707945` throughout the writing of this
  report, all PDX-005 work uncommitted on `feat/pdx-005-the-cell-grid`. This report's
  verification ran gates, scenarios, unit suites, node probes and a local Chromium over
  `file://` and a scenario-owned localhost preview; nothing contacted a remote in write
  mode. The user's standing instruction in this session delegates commit, push, issue, PR
  and merge for the ticket cycle; that delegation is what authorises the commits described
  next, and it is the only thing that does.

- **The commit is split, and the split is the point.** The working tree holds **56 files**;
  **eleven** stay off this ticket's commit — `CLAUDE.md`, `bench/README.md`,
  `bench/PREREGISTRATION-2.md`, the `PDX-025` ticket draft, and the seven tickets `PDX-026`
  through `PDX-032`. **45 ride it** (`git diff --cached --name-only | wc -l` → 45,
  `45 + 11 = 56`). The unit is named because it changed the number: every earlier draft of
  this paragraph said "50 entries", which is `git status --porcelain` on an unstaged tree,
  where the six new files under `packages/site/src/components/analysis/` collapse to one
  untracked-directory line. Fifty was never a file count. Round 2 found this paragraph short
  by two; round 3 found it still short by one, because that fix counted the three files it
  had just added and left `PDX-025` in the prose without putting it in the count; and staging
  the commit found the unit itself wrong. Four passes over one sentence whose entire job is
  to be arithmetically right — which is the strongest evidence in this report for §8's
  argument that a figure only becomes trustworthy when something derives it, and that prose
  restating a count will go stale however many times it is corrected by hand. `bench/README.md` and
  `bench/PREREGISTRATION-2.md` are named `Not Allowed` by the ticket in as many words,
  `CLAUDE.md` is a standing instruction rather than this ticket's work, and `PDX-025` is a
  ticket this cycle drafted but did not execute. A ticket whose report says "also, we edited
  the thing the ticket forbade" is how a scope section stops meaning anything, and the corpus
  files are exactly the ones where that matters most.

## 10. Agent Review

### Reviewer
- Model: Opus 5
- Reviewed at: 2026-08-20 00:43

### Verdict
- [ ] APPROVED
- [x] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

Every row must be scored PASS / FAIL / N/A with one line of concrete evidence.
Any FAIL row requires verdict NEEDS_REVISION (the gate rejects APPROVED + FAIL).

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | PASS | Re-ran both scenarios on this tree: `PDX-005-the-analysis-reads.sh` PASS (AC-1/2/3/4/5/6/8/9, incl. "3 arm(s) print the denominator their means fell short by"), `PDX-005-the-analysis-looks-right.sh` PASS (AC-7/AC-10, 4 combinations over 312 marks); §5 carries 7 DEV-01 rows, none skipped, and I re-drove the keyboard row myself in Chromium over `astro preview` — `{"focusedTag":"BUTTON","open":true,"closed":true,"focusRestored":true}`, identical to the reported string |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | PASS | `.docs/state/PDX-005.state` holds exactly one `red` stamp at `2026-08-19T18:24:34`, ahead of every `green` (first at `18:56:38`), and the RED row records the non-vacuity trap it had to avoid (a tsx-only sandbox exits non-zero for an unrelated reason, so a bare `DATA-01` match would have been a fake RED) — see Comment 1 for a stamp-count drift that does not touch this row |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | PASS | The plan's §3 holds 12 steps and §3 of this report scores all 12, disclosing deviations at steps 1, 4, 5, 6, 8, 10 and 11 with cause (notably step 4's absent-as-zero correction and step 8's six-site `rateFraction` fix); the plan review ran exactly two rounds ending APPROVED_WITH_NOTES with receipt `.docs/receipts/PDX-005-plan-review.json` (`gate_run_sha f707945…`), so REV-02 holds |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | PASS | `git status --porcelain \| wc -l` = 50, matching §1/§2/§9, and 49 of the 50 entries carry a row (see Comment 3); every load-bearing claim checked in the tree — `grep -rn 'hits / .*\.n' packages/site/src` returns nothing (exit 1) and all six sites route through `rateFraction` (`aggregate.ts:28`; `DomainSplit.astro:52`, `Leaderboard.astro:79`, `TicketBreakdown.astro:111`, `analysis.astro:88-89`, `:131`, `:174`), `grade.ts:74` returns the corrected backend label and `dist/analysis.html` greps 0 for "delivered tests", the built page carries one `path.pareto d="M241.24,199.5 L256.39,91.64"` and one `data-frontier-note="sole"` exactly as §1 quotes, and `./scripts/verify.sh` PASS (42s) + `check-gates.sh` 71/71 + `e2e.sh` 10/10 + `@plugdex/data` 78/78 |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | PASS | `git rev-parse --short HEAD` = `f707945` on `feat/pdx-005-the-cell-grid` with all 50 entries uncommitted, matching §9's claim verbatim; `git reflog -3` shows only the pre-existing rebase onto `main`, no commit/push during this cycle, and this review performed no git mutation of any kind |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` PASS, plus an independent Hangul-range sweep over the whole working tree including the untracked new files (`grep -rlP '[\x{AC00}-\x{D7A3}\x{1100}-\x{11FF}\x{3130}-\x{318F}]'`, excluding `node_modules`/`dist`/`.git`) returning zero files — negative-controlled against a planted Hangul canary the same pattern caught, so the empty result is an absence rather than a broken pattern (ASSERT-01) |

### Comments

1. **Round-2 fix 1 (the screenshots) verified the hard way, and it holds completely.** I did
   not take §2's word for the re-capture: I rebuilt the site, served it over `astro preview`,
   captured every `<section>` at 1440px / DPR 2 with Chromium, and compared SHA-256 against the
   committed files. All six are **byte-identical** — `analysis-leaderboard` `c7d2af46b124`,
   `tradeoffs` `d20cf7a53eb6`, `domains` `28f435b54f55`, `radar` `d2b2fa18b133`, `tokens`
   `5f86d7566776`, `cells` `7acea4450ea1`, each matching its fresh capture bit for bit at
   identical pixel dimensions. Reading the PNGs confirms the content too: baseline prints
   `$0.0849` / `47s` (not the withdrawn `$0.0818` / `45s`), the wall-clock panel draws **no**
   frontier and states ponytail as its sole member, and the compact `n=52/54` / `n=53/54`
   markers are present. This was worth checking independently: the images' mtimes (23:44:52)
   *precede* the last edits to `stats.ts` (23:47:06) and `analysis.astro` /
   `TicketBreakdown.astro` (23:46:05), so mtime alone would have suggested staleness. The byte
   comparison settles it — those later edits were output-neutral.
2. **Round-2 fix 3 (`.shortfall` contrast) is real and its negative control reproduces.**
   `[data-shortfall]` reaches all 12 spans (`querySelectorAll` in
   `PDX-005-the-analysis-looks-right.sh:366`), and the scenario is non-vacuous by construction:
   `:461` pushes a finding when the selection is *empty*, so a corpus that rendered no marker
   FAILs rather than passing silently — the exact ASSERT-01 shape this repository has produced
   six times, closed here. I re-measured with an independent probe using the scenario's own
   formula: **7.89:1 light / 8.98:1 dark**, matching §1 to the digit. The negative control also
   reproduces — injecting `.shortfall { opacity: 0.06 }` drops every span to **1.13:1 light /
   1.14:1 dark** and yields 12 sub-floor findings. Critically, the same probe reports
   `noOpacityRatio: 17.23` for the dimmed element, i.e. a check reading `color` alone would
   have called the dimmed rule a pass — so the `opacity` fold at `:475-479` is load-bearing,
   not decoration.
3. **Round-2 fix 2 (`n=52/54`) does not overflow, at the capture width or anywhere.** Measured
   in Chromium at 360 / 1280 / 1440: at 1440 and 1280 the leaderboard table is 1216px inside a
   1216px container with `scrollWidth == clientWidth` (no overflow, Seconds column intact); at
   360 the table overflows only into its own scroll container while
   `document.documentElement.scrollWidth == window.innerWidth == 360`. The shortfall renders
   where §5 says it does — 12 `<span class="shortfall" data-shortfall="…">` in
   `dist/analysis.html`, four each under cost/turns/outputTokens/seconds for three arms, and
   **none under `loc`**, which is the per-figure claim §1 makes.
4. **The `as number` casts and `noTintOpacity` are honest, not laundering.** Each cast sits
   behind a guard that makes the null branch unreachable: `analysis.astro:88-89` after three
   `n === 0` early returns, `:131` inside `measured = ranked.filter(row => row.summary.n > 0)`,
   `DomainSplit.astro:52` inside the `summary.wilson === null` early return. They are type
   assertions over an already-narrowed value, and they change no figure.
   `noTintOpacity = 0` / `emptyRadiusFraction = 0` are genuine rendering decisions for the
   ungraded case — where the old `hits / n` produced `NaN` — and the absence still reads as an
   absence because the text is `formatAbsent()` (`——`), not `0/n`; the counts table screenshot
   shows superpowers' row untinted with dashes.
5. **Caveat on what actually enforces the six-site fix: nothing does.** DATA-01 does not catch
   `summary.hits / summary.n` — the report says so itself (`aggregate.ts:19-26`), and
   `check-data.sh:122` exempts any identifier matching
   `/(width|height|size|gap|column|row|radius|index|duration|delay|breakpoint|margin|padding|opacity|weight|scale)/i`.
   So the grep in §3 step 8 is true today (I re-ran it: no output, exit 1) but a seventh
   division added next week fails no gate. This is DEC-017's disclosed residue rather than a
   new defect, and the report does not claim otherwise — but after two rounds spent on this one
   construct it deserves naming as a standing exposure, most cheaply alongside PDX-021's
   destination check. For the record, the divisions that remain in site source are coordinate
   mappings, not restated statistics: `TokenBars.astro:39` (`total / widest`, a bar
   normalisation whose counts print in ink beside it) and `TradeoffScatter.astro:55`
   (`value / xMax`, the axis transform); everything else is pure geometry.
6. **Round-2 fix 5 is two-thirds re-derived clean and one-third drifted again.** From ground
   truth: `git status --porcelain | wc -l` = **50** ✓ matching §1/§2/§9; `pnpm --filter
   @plugdex/data test` = **78/78** ✓ with the per-file split in §4.1 exact (stats 10, grade 6,
   aggregate 9, economics 5, pareto 4, verdict 19, load 25 = 78). But `grep -c '^green'
   .docs/state/PDX-005.state` = **15**, where §4.0 says "records 14 `green` stamps in total";
   and the same sentence's "rounds 1–7 above account for the first seven" is off by one on its
   own arithmetic — rounds 2–7 are six greens, not seven. The 15th stamp (`23:59:37`) postdates
   the report's last save (`23:54:08`), so this is drift from re-running the gate after writing
   rather than a fabrication — and I confirmed independently that nothing bad rode it (verify
   PASS, 71/71, 10/10, 78/78, images byte-identical). Correct in place; it does not warrant
   another review round.
7. **A second small count disagreement, same family.** §9 says "ten are outside the ticket's
   Scope" and enumerates `CLAUDE.md`, `bench/README.md`, `bench/PREREGISTRATION-2.md` and
   PDX-026..032, then adds that they land in a second commit "alongside the PDX-025 ticket
   draft" — while §2's own row calls PDX-025 "Not this ticket's scope". Eleven entries, not
   ten, therefore stay off this commit. The enumeration is complete and no reader is misled
   about what lands where, so this is a label, not a scope violation. The root cause is worth a
   line in whichever ticket next writes a Scope section: PDX-005's `Scope.Allowed` never names
   `.docs/tickets/**` or `.docs/analysis/**` at all, which is why every count over ticket files
   has needed a prose exception in all three rounds.
8. **`.docs/analysis/PDX-005_report.md` is the one working-tree entry with no §2 row.** 49 of
   50 are covered. Self-evident, and the same omission class round 2 blocked on — add the row
   while fixing Comments 6 and 7.
9. **Ticket quality: sound, no revision needed.** AC-1..AC-10 are objectively verifiable and
   each maps to a named scenario, golden case or unit test in §5 of the ticket; the two
   post-hoc amendments (Scope.Allowed gaining `README.md` / `docs/images/**`, AC-1 gaining the
   per-figure denominator) both carry their date, their cause and the boundary that makes them
   legitimate — an unnamed file is a gap, a file named `Not Allowed` is a decision — and
   `bench/**` was in fact respected: `bench/README.md` and `bench/PREREGISTRATION-2.md` are
   modified in the tree but explicitly held out of this commit.
10. **What I could not verify, stated rather than assumed.** (a) The user's standing delegation
    of commit/push/issue/PR named in §9 is a conversation fact outside the tree; the tree-side
    half — no commits, HEAD unmoved — I did verify. (b) The historical RED and the 14 earlier
    loops are attested only by state stamps and the OBS-01 log, which §4.0 itself says do not
    record which correction rode which loop. (c) The six screenshots have no committed capture
    script, so their reproducibility rests on my ad-hoc re-capture matching byte for byte
    rather than on a scenario anyone can re-run; if the README images are meant to stay true
    across future figure changes, that script is the cheapest thing that would make it so.

### Blockers (only if NEEDS_REVISION)
- None. All nine blockers from rounds 1 and 2 were checked against the tree rather than
  against the report's prose, and all nine hold. Comments 6, 7 and 8 are prose counts whose
  underlying enumerations are complete and independently re-derivable; per REV-02's recorded
  lesson they should be corrected in place without spending a fourth review cycle.

## 11. Final Report Status

- Agent: **APPROVED_WITH_NOTES** — Opus 5, 2026-08-20 00:43, 0 blockers (10 comments)
- Human: _(pending)_
