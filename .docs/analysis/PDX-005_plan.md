# PDX-005 Plan — site: the analysis page

- Ticket: `.docs/tickets/PDX-005_site-the-analysis-page.md`
- Author: Fable 5 (Claude Code subagent)
- Date: 2026-08-19 (revised after review round 1 — see §9.0)

## 1. Goal & Context

PDX-004 shipped the decision surface: one card per pack, a verdict chip, two rates with
their denominators. This ticket ships the evidence surface — the page that shows what
those rates are made of, in the shapes a benchmark reader already knows: a leaderboard
with intervals, two trade-off scatters with Pareto frontiers, a frontend/backend split, a
per-ticket breakdown (radar + counts table), token economics, and the full cell grid.

A working prototype was rendered against the live corpus before the ticket was written
(`docs/images/analysis-*.png`, committed on `main` and shown in the README). It is the
design contract for layout and visual language, and building it surfaced the defect this
ticket fixes rather than sequels: **the catalogue's headline rate is a frontend rate that
does not say so.** The current `buildCounts` grader in `packages/data/src/verdict.ts`
counts `valid + wroteCode + build-graded` cells, and every build-graded cell in the
corpus is an `fe-*` ticket; the backend cells carry `import_ok` and `passes` and are
absent from the headline entirely. Fixing the disclosure — on the analysis page and on
the existing card — is AC-2.

### Measured figures, recorded here per the ticket's §6

The ticket's own References section names this plan as the record of the prototype's
measured figures. They were measured against the live corpus during the prototype build
and are cited as given, not re-derived; every one that a page renders is re-derived by a
scenario or a unit test at run time (PLAN-01 — the numbers below are the claims the tests
assert, not facts a reviewer must trust).

- **Site rule today** (`buildCounts`, all-domain in name, frontend in fact): baseline
  5/20, caveman 6/21, karpathy 8/20, mattpocock 10/20, ponytail 16/22; superpowers 0
  graded with 40/41 silent. All 103 build-graded cells are `fe-*`; the 86 backend cells
  carry `import_ok` and `passes` instead.
- **Honest per-domain grader** (frontend: `build`; backend: `passes` — imports and
  introduces no new diagnostic): frontend baseline 5/20 25% [11-47], caveman 6/21 29%
  [14-50], karpathy 8/20 40% [22-61], mattpocock 10/20 50% [30-70], ponytail 16/22 73%
  [52-87]; backend baseline 7/15 47% [25-70], caveman 6/17 35% [17-59], karpathy 7/18
  39% [20-61], mattpocock 7/18 39% [20-61], ponytail 8/17 47% [26-69]. Backend
  `import_ok` alone is 100% for every arm — a ceiling that grades nothing, which is why
  `passes` is the backend grader. Intervals are 95% Wilson (verified: the prototype's
  [11.19, 46.87] for 5/20 is the Wilson score interval at z = 1.96).
- **Economics per condition**, joined through the results record's own `date` field
  (equal to the acceptance record's `run`): `blocked` costs about $0.085-0.133 per cell
  at 6-14 mean turns; `as-shipped` about $0.20-0.35 at 28-47 turns. Pooling the two was
  the prototype's first attempt and it hid a 3-4x difference — the reason AC-3 exists.
- **Published `blocked` corpus**: 312 cells, 229 valid, 6 arms x 12 tickets, all 72
  squares filled, at most 8 repetitions in a square; 83 invalid cells of which 74 are one
  session-limit instrument failure clustered on the frontend tickets.
- **The wall-clock frontier degenerates on the live corpus**: baseline and ponytail sit
  on the same x to rendering precision (both about 47s mean), and ponytail dominates the
  chart, so the frontier is a single point and the prototype draws no line — AC-4's case
  is the live case, not a hypothetical.

### What the prototype is and is not

The prototype (`aa.html` + `aa-data.json` + `aa-tasks.json`) draws every chart in
client-side JS over two baked JSON blobs. That JS is a rendering convenience, not a
requirement: every chart is a pure function of already-aggregated records, so every one
of them is drawable at build time as inline SVG or CSS boxes. §6.5 D1 takes the position
that **nothing on this page needs a client-side island at all** — including the cell
drawer, which follows PDX-004's native `<dialog>` + inline-script pattern. The
prototype's ad hoc palette is replaced by the site's §5 tokens in `global.css`, and its
colour-only grid squares are replaced by shape-primary marks (DEC-018).

## 2. Scope Check

- **Ticket Scope.Allowed respected**: steps touch `packages/data/src/*` (grader,
  Wilson, aggregates, economics join, frontier — each with unit tests),
  `packages/site/src/*` (the analysis page, its components, `global.css`, and the AC-2
  edits to `index.astro` / `PackCard.astro` / `VerdictChip.astro`), `scripts/check-data.sh`
  (the `.tsx` walk), `tests/e2e/PDX-005-*.sh`, `tests/meta/cases/` (expected 69-71,
  derived at write time), and `DESIGN.md` (the decision rows in step 10 plus the Phase B
  PDX-005 roadmap paragraph and the PDX-021 scope note this ticket makes stale).
  `docs/WORKFLOW.md` is **not** touched: no gate row changes — DATA-01's row does not
  enumerate file extensions, so widening the walk changes no documented contract.
- **Ticket Scope.NotAllowed respected**:
  - `bench/**` untouched; nothing is re-measured. The economics loader **reads**
    `bench/data/runs/*.results.json`; it writes nothing there.
  - No composite index and no single ranking score: the page states the refusal and its
    reason (AC-8), and §6.5 D3 records why the sorted leaderboard is disclosure rather
    than the ranking DEC-005 refuses.
  - No blending: every figure is computed per condition (`blocked`, named in the
    masthead, DEC-020) and per domain (frontend `build` / backend `passes`, never
    folded — the two-population discipline is the ticket's own AC-2).
  - No figure computed in the site: every count, rate, interval, mean, share, tick
    label, and frontier membership is computed and formatted in `@plugdex/data`; the
    site's only arithmetic maps imported values onto layout-vocabulary constants
    (coordinates and widths — §6.5 D4 draws the exact line against `check-data.sh`'s
    scanners).
- CR-01: nothing in this cycle commits, pushes, or opens anything; the plan is a file.

## 3. Steps

Keep steps small (1-3 files per step).

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | Wilson intervals and figure formatters | `packages/data/src/stats.ts`, `packages/data/src/stats.test.ts` | `wilson({ hits, n })` returning `{ lo, hi }` (95% score interval; z pinned as a named constant with its derivation in the doc comment — a constant in `packages/data` is legal, the gate scans site source). Formatters the site will need so no literal ever appears on its figure path: `formatIntervalPercent({ lo, hi })` ("11% - 47%"), `formatMoney({ usd })`, `formatSeconds({ seconds })`, `formatTokens({ count })`, `formatCountOverCount({ hits, n })` ("5/20"), and `axisTicks({ max, count, format })` returning `{ fraction, label }[]` — tick labels are reader-visible figures, so they are produced here, never by a site loop; percent-axis ticks are bare numbers (the axis title names the unit) so the page-wide same-element rule of §6.5 D2 needs no exemption. Unit tests pin 5/20 to [0.1119, 0.4687] (tolerance 1e-3), the n=0 refusal, and the 0/n and n/n asymmetric bounds |
| 2 | The per-domain grader and the four-state mark | `packages/data/src/grade.ts`, `packages/data/src/grade.test.ts` | `gradeCell({ cell })` returning a closed union: `invalid` (valid false), `no-code` (valid, wroteCode false), `built` / `failed` by domain — frontend graded by `build`, backend by `passes` — and `ungraded` for a valid code-writing cell whose grading field is absent (skipped from rates, exactly the `buildCounts` / `rate_table` rule, kept identical on purpose). The doc comment records why `import_ok` is not the backend grader: it is 100% for every arm on this corpus — a ceiling that cannot distinguish anything. Tests cover every branch, including a backend cell with `importOk: true, passes: false` (failed, not built) and a null-domain cell |
| 3 | Aggregates: arm, domain, task, grid | `packages/data/src/aggregate.ts`, `packages/data/src/aggregate.test.ts` | Pure functions over `Cell[]`, all built on steps 1-2: `armSummary({ cells, arm })` (graded hits/n + wilson + silent/valid + cell count — the leaderboard row minus economics), `domainSummary({ cells, arm, domain })` (AC-2's beside-numbers and the split section), `taskSummary({ cells, arm, task })` (hits/n + wilson + the task's domain — radar and counts table), and `cellGrid({ cells })` (per arm x task, one mark per repetition via `gradeCell`, each mark carrying its cell id and `invalidReason` for the drawer; plus the corpus totals AC-6 asserts: cells, valid, squares, arms, tasks). n=0 yields no rate anywhere — the summary carries counts only and formatting throws (the existing `formatRate` contract), so "no graded cell" is the only possible rendering for superpowers |
| 4 | The economics join (AC-3) | `packages/data/src/economics.ts`, `packages/data/src/economics.test.ts` | `loadEconomics({ dir, corpus })`: parses `*.results.json`, joins every file to an acceptance record by the **record fields alone** — the results record's own top-level `date` equals the acceptance record's `run` (verified across all ten run pairs) — and inherits regime and withdrawal from the joined record, so the withdrawn run's rows leave the default pool automatically and no filename is ever consulted (DATA-02's discipline extended to a second record type; results records still carry no fingerprint of their own, which is why they enter `@plugdex/data` only through this join — §6.5 D5). A results record whose `date` matches no acceptance record is refused loudly, never skipped. Output: per-arm means for the requested regime — cost, turns, out/in/cache tokens, LOC (`total_loc`), seconds (`duration_ms`/1000) — plus `econN`, and token **shares** as fractions so the site multiplies nothing by 100. Means pool every joined row of the condition, invalid cells included: the money was spent whether or not the cell was later invalidated, and the page says so. The AC-3 test plants a fixture corpus whose filenames contradict the records (an acceptance file named `...-as-shipped...` whose record says `regime: "blocked"`, plus its results file) and asserts the rows land in the blocked pool |
| 5 | Pareto frontier (AC-4) | `packages/data/src/pareto.ts`, `packages/data/src/pareto.test.ts` | `paretoFrontier({ points })` over `{ id, x, y }[]`: sort by x ascending, collapse ties on x to the best y, keep strictly increasing y. Returns the frontier members; a frontier with fewer than two **distinct x positions** is returned as what it is (length < 2) and the consumer draws no line. Tests: the degenerate live shape (one dominating point — no line), an x-tie that would have produced a vertical segment, a normal 3-point frontier, and the empty input refusal |
| 6 | AC-2's mechanical spine: the rate string carries its population | `packages/data/src/verdict.ts`, `packages/data/src/verdict.test.ts` (extend) | `formatRate` gains a **required** `population` parameter and bakes it into the returned string — `formatRate({ hits: 5, n: 20, population: 'frontend' })` renders as `25% n=20 (frontend)`. Typecheck then forces every call site, including the existing card, to name the population, and dropping the name means not rendering the rate at all — enforcement by totality, not by prose discipline (§6.5 D2). `verdictFor`'s `BuildRateVerdict` gains the backend counts (`backendPasses`/`backendN` + baselines, from the step-2 grader) so a chip consumer holds both domains the moment it holds either; the frontend counts keep their fields and their `buildCounts` semantics (the numbers do not move — AC-2 renames the population, it does not re-grade it). `percentOf` stays exported unchanged: `VerdictChip` legitimately renders non-domain percentages with it and case 43 pins the pattern; the route it leaves open is closed by the extended PDX-004 assertion, not by the type system (§6.5 D2) |
| 7 | The catalogue card names its population (AC-2, existing page) | `packages/site/src/pages/index.astro`, `packages/site/src/components/PackCard.astro`, `packages/site/src/components/VerdictChip.astro` | The chip label becomes `N% builds n=M (frontend)` via the new `formatRate`; the card's rate block shows the frontend build rate and the backend pass rate **beside** it (both via `formatRate`, both with baseline, one shared style per DEC-016 — four rates, two populations, zero comparisons drawn), every rate element keeping its `data-rate` attribute and gaining `data-population` per §6.5 D2's declared-element contract; the masthead paragraph states that the headline is the frontend build rate and why the backend is graded differently; both pages link each other (nav: catalogue / analysis — only routes that exist; the prototype's five-item nav is aspirational and is not shipped). No collision with PDX-024's pending card work: this step touches the rate block and masthead only, not install state |
| 8 | The analysis page and the paper sections | `packages/site/src/pages/analysis.astro`, `packages/site/src/components/analysis/Leaderboard.astro`, `packages/site/src/components/analysis/DomainSplit.astro` | `analysis.astro` loads the `blocked` corpus + economics at build time, names the condition and the withdrawn count in its masthead (the `index.astro` pattern), and composes the sections. `Leaderboard.astro` (AC-1): one row per listed pack plus the baseline row, columns = frontend build rate (minibar + counts + rate string, in a `data-rate` element with `data-population` per §6.5 D2), Wilson interval, no-code count, cost/cell, turns, output tokens, LOC, seconds — every cell a formatted string from `@plugdex/data`; sorted by point estimate with §6.5 D3's disclosure framing, superpowers rendering `no graded cell` and never 0%. Below it, the AC-8 statement in a `data-composite-index="refused"` element: no composite index, because a single score needs weights across unlike metrics this corpus gives no basis for choosing, plus the derived none-clears/one-clears baseline sentence. `DomainSplit.astro`: per arm, two interval tracks (band = Wilson interval, tick = point estimate, label = counts + rate string) under headers naming the two graders |
| 9 | The charts: scatters, radar + table, token bars | `packages/site/src/components/analysis/TradeoffScatter.astro`, `packages/site/src/components/analysis/TicketBreakdown.astro`, `packages/site/src/components/analysis/TokenBars.astro` | All static inline SVG / CSS boxes, geometry per §6.5 D4. `TradeoffScatter` (AC-4, rendered twice: x = cost/cell, x = seconds; y = frontend build rate, axes labelled with their populations): dots + text labels per arm, ticks from `axisTicks` (bare numbers; the axis title carries the unit), frontier from `paretoFrontier` — drawn only when it has two or more members, otherwise the chart carries a visible sentence naming the single frontier member and saying why no line is drawn (AC-4's "the page says so"). `TicketBreakdown` (AC-5): one radar per pack (small multiples, never stacked — §4.3), twelve spokes in the loader's task order, the Wilson-`hi` band polygon drawn **behind** the point-estimate polygon and never clipped, subtitle carrying the graded-cell count, caption stating that area is an artefact of axis order — and beside it the counts table: per pack x ticket, `k/n` printed in every cell in ink with the rate as a background tint only (DEC-018; a colour without its count is an AC-5 violation, so the count is the cell's text, not a tooltip), plus a `fe`/`be` domain row. `TokenBars`: per-arm stacked bars from the economics shares, widths = share x a width-named constant, each row printing its total; segments distinguished by shade **and** order with the counts printed, so the bar is readable in grayscale |
| 10 | The cell grid and the drawer (AC-6, AC-7) | `packages/site/src/components/analysis/CellGrid.astro`, `packages/site/src/styles/global.css` | The grid: 6 arms x 12 tickets from `cellGrid`, one mark per repetition, sorted built/failed/no-code/invalid within a square. Four states, shape-primary (DEC-018): built = solid ink-filled square, failed = open square with a diagonal stroke, no-code = dotted/hatched fill, invalid = hollow ghost outline — hue rides as tint on top, never alone; the legend shows shape + hue + name. Each mark is a `<button>` opening a server-rendered `<dialog>` carrying the cell's identity (task, arm, model, rep), its state, its domain and grader, and its `invalidReason` — content in the HTML, opened by a few lines of inline script exactly like `InstallDialog` (no island, no framework — §6.5 D1); a `<noscript>` line says the drawer needs JavaScript and that everything else on the page does not. Gate-output blobs (`buildOut` etc.) stay out of the drawer (size; they are PDX-007 exhibit material). Below the grid, the invalid callout: derived counts naming the session-limit clustering. The grid scrolls inside its own `overflow-x: auto` container at narrow widths; the page body never scrolls horizontally (AC-10). `global.css` gains the analysis-page rules under the existing token system, both schemes |
| 11 | The `.tsx` walk (AC-9) | `scripts/check-data.sh`, `tests/meta/cases/` (3 cases, expected 69-71) | The walk regex becomes `/\.(ts|tsx|astro|css)$/`, and scanner 1 learns the two JSX positions its TS AST walk misses today, each closed with its own golden case per DEC-017's extend-with-a-case rule. First, `JsxText` nodes carrying a digit: `ts.isJsxText` is not `ts.isStringLiteral`, so today's visitor walks past rendered JSX text entirely (reported as DATA-01b). Second, `JsxAttribute` context handling — and the defect here is the opposite polarity, verified by review round 1: attribute string initializers ARE `StringLiteral`s and already hit scanner 1's generic rule with no `JsxAttribute` context, so `contextName` returns an unnamed expression and a machine-facing `style="width: 12px"` in a `.tsx` would false-positive today. Scanner 1 gains a `JsxAttribute` branch: non-reader-facing attributes are `__exempt__` (machine-facing, like scanner 2's rule for `.astro`), the `READER_FACING_ATTRIBUTES` set BLOCKs, and the clean golden case carries realistic machine-facing attributes so the exemption is pinned, not assumed. `ts.createSourceFile` infers `ScriptKind.TSX` from the filename, verified in the case rather than assumed. **Named residue, not closed here**: template literals **with substitutions** — scanner 1 tests `NoSubstitutionTemplateLiteral` only, so the digit-bearing head/middle/tail spans of a substituted template are unscanned in `.ts` and `.astro` frontmatter today and stay unscanned in `.tsx`; that gap predates and exceeds this ticket's walk change, so it is recorded in step 12's PDX-021 scope-note correction beside `public/` and `.md`/`.mdx` rather than half-closed here. Golden cases: 69 — a `.tsx` rendering a typed figure in JSX text BLOCKs with `DATA-01b`; 70 — a `.tsx` with a digit in a reader-facing JSX attribute BLOCKs; 71 — a clean `.tsx` (imported figures, layout-vocabulary literals) beside a clean `.astro` passes. **Every BLOCK case plants a clean companion `.astro` as well**, because a tsx-only sandbox already exits non-zero printing `DATA-01` for an unrelated reason (the scanned-file floor — verified by review round 1), and a case that matched bare `DATA-01` would prove nothing; `EXPECT_PATTERN` pins the specific rule id. The cases land **with** this step; the reads scenario carries the RED-visible half (§7, AC-9 row). The live tree still ships zero `.tsx` (D1), so the walk's live coverage stays vacuous by choice while the golden cases keep it non-vacuous forever |
| 12 | Decisions and the roadmap | `DESIGN.md` | Decision log gains the rows §6.5 decides (expected DEC-023 through DEC-026; numbers verified against the log at write time — it currently ends at DEC-022 with DEC-020 landed out of order, the numbered-by-claim precedent). Phase B's PDX-005 roadmap paragraph is rewritten to the ticket as rewritten (analysis page; the receipt-drawer-with-`_invocation.json` description belongs to the superseded ticket; the cell grid and drawer survive in their shipped form). PDX-021's scope note is corrected: `.tsx` is scanned as of this ticket; `packages/site/public/`, `.md`/`.mdx`, and the digit-bearing spans of template literals with substitutions (unscanned in every extension scanner 1 reads — step 11's named residue) remain the open classes. The Reference Map row itself is **not** edited — its machine copy lives in `scripts/check-references.sh`, which is outside this ticket's Allowed scope, and editing one copy of a two-copy table is how tables lie (§5 Out of Scope) |

Steps 1-6 are `packages/data` and land before any site step (the site can only import
what exists); 7-10 are the site; 11 is the gate; 12 is docs. The two e2e scenarios are
written at stage 4, before all of this, per the workflow.

## 4. Risks

- **`formatRate`'s signature change ripples into PDX-004's green scenarios** → the
  change is compile-checked (typecheck breaks every call site until it names a
  population), and the PDX-004 scenarios assert denominators (`n=`) and rate presence,
  which the new string keeps; the regression run at GREEN is the proof. If a PDX-004
  assertion pins the exact old string shape, the assertion is updated in the same step
  with the reason in the commit body — the scenario's contract ("every rate carries its
  denominator") is preserved and strengthened, never weakened.
- **DATA-01a false positives on chart geometry** → the site's chart literals are
  restricted to layout-vocabulary names (`chartWidth`, `plotPadding`, `markSize`,
  `fullWidthScale`...), all reader-visible values arrive formatted from `@plugdex/data`,
  and the gate runs inside `verify.sh` on every loop — a violation is caught at stage 5,
  not at review. §6.5 D4 is the rule the implementer follows; where a needed name falls
  outside `LAYOUT_VOCABULARY`, the fix is a better name, never an allowlist extension
  without its golden case.
- **312 server-rendered dialogs bloat the page** → drawer content is identity + state +
  reason only (no gate-output blobs); if the built page still lands heavy, the drawer
  falls back to one shared `<dialog>` filled from per-mark `data-*` attributes by the
  same inline script — still no island, decided by the measured `dist/` size at stage 6
  and recorded in the report.
- **The radar misleads at three repetitions per spoke** → the band is the mitigation and
  is asserted, not decorative: the reads scenario checks the band polygon reaches the
  Wilson `hi` radii (AC-5), the caption states the repetition count per spoke, and the
  counts table beside it is the same data with no angular artefact (§6.5 D6).
- **The heat-table tint fails contrast in one scheme** → cell text is ink on a bounded
  tint (alpha-capped), checked on computed style in both schemes by the looks-right
  scenario (AC-7's floors applied to the table as well as the grid); if a tint range
  cannot hold 4.5:1, the range is narrowed — counts are the signal, tint is redundant.
- **The economics join meets a future results record with no acceptance partner** → the
  loader refuses loudly by design (the AC-3 test's second fixture); the failure names
  the orphan `date`, so the fix is a data fix, not a site mystery.

## 5. Out of Scope

- **The Reference Map's machine copy** (`scripts/check-references.sh`) still names the
  superseded receipt-drawer references for PDX-005. Correcting both copies together is a
  one-line harness follow-up outside this ticket's Allowed scope; this plan satisfies
  the gate as it stands (§8.5) and flags the staleness rather than half-fixing it.
- **Extending `check-data-universe.sh`'s behavioural probe to the economics loader.**
  DATA-02's gate probes the acceptance loader; the results join gets the same discipline
  from unit tests here (AC-3), and giving the gate a second probe target is its own
  small harness ticket — the gate script is not in Allowed.
- **Gate-output receipts in the drawer** (`buildOut`, `importOut`, diff, invocation) —
  PDX-007's exhibit territory; the drawer here carries identity, state, grader, reason.
- **Interactive axis reordering on the radar** — PDX-006's shape-summary ticket owns
  interactivity there; here the order is fixed and the counts table is the order-free
  rendering (§6.5 D6).
- **The as-shipped condition's own analysis page.** It is named, counted, and linked in
  the masthead per DEC-020; rendering its (smaller, arm-incomplete) corpus as a page of
  its own is future work if ever.
- **A DATA-01 destination-side check for the new charts** — PDX-021 as roadmapped; the
  tick labels and formatted strings this ticket routes through `@plugdex/data` are
  exactly what keeps its derivable set constructible.

## 6. Rules / Decisions Applied

- **LANG-01** — this plan and every commissioned artifact are English-only; no
  non-Latin character appears anywhere in them, including inside test fixtures.
- **DATA-01 / DEC-017** — no figure is typed in the site: rates, intervals, means,
  shares, counts, tick labels, and frontier membership are all computed and formatted in
  `@plugdex/data`; site literals are layout vocabulary only (§6.5 D4). The gate widens
  to `.tsx` with golden cases in the same change, per DEC-017's standing rule.
- **DATA-02 / DEC-015 / DEC-019 / DEC-020** — the economics join is decided by record
  fields (`date` = `run`), regime and withdrawal are inherited from the joined
  acceptance record, no filename is consulted, and the page reports one named condition.
- **DEC-005 / DEC-016 / D-001** — no composite index, no verdict-grade comparison
  drawn anywhere; the sorted leaderboard is bounded as disclosure by §6.5 D3; the two
  rates on the card stay identically styled, now four rates in two named populations.
- **DEC-018** — every status hue is tint/border only; grid marks and chip glyphs are
  ink shapes; contrast floors asserted on computed style in both schemes (AC-7).
- **DEC-021 / DEC-022** — the card edits in step 7 stay clear of install-state
  rendering (PDX-024's seam) and follow DEC-022's posture: a gap a page cannot close is
  stated on the page, which is exactly what AC-2 and AC-4's degenerate-frontier sentence
  do.
- **ASSERT-01** — every scenario probe prints a sentinel and every count carries a
  floor; the AC-8 negative sweep runs only after the positive statement assertion has
  found its element (a negative grep over a missing page proves nothing).
- **PLAN-01** — the measured figures in §1 are the ticket-mandated record and each one
  a page renders is re-derived by a test; golden-case and DEC numbers are expected
  values verified at write time.
- **GATE-01** — the walk change ships with both-direction golden cases in the same
  step.
- **DEV-01** — the report carries the Non-Scriptable Verification checklist: grid
  legibility at 360px, the drawer on keyboard, dark-mode charts, radar band readability,
  token bars in grayscale — each row checked in a real browser or explicitly N/A.
- **REV-02** — this plan expects at most two review rounds; non-blocking findings ride
  to the report.
- **Produced by this ticket**: DEC rows for §6.5 D1-D6 (expected DEC-023..026 — D2+D5
  may share a row with D3 if the reviewer prefers a denser log; the claims, not the
  count, are the deliverable).

## 6.5 Design Decisions

**D1 — no island ships; the ticket's `.tsx` premise is corrected rather than obeyed.**
Every chart on the prototype is a pure function of records available at build time, so
every chart is static markup; the only interaction on the page is the cell drawer, and
PDX-004 already established the pattern for exactly this shape — a native `<dialog>`
with a few lines of inline script and no framework runtime (`astro.config.mjs` documents
it; PDX-004's AC-1 asserts no server entrypoint in `dist/`). A React island for a drawer
would add a framework integration, a client bundle, and a hydration boundary to serve
one `showModal()` call — the opposite of "an island must earn its JavaScript" (§5).
Consequence for AC-9: the `.tsx` walk and its golden cases ship in full (the gate must
be ready **before** any island lands, which is the AC's own wording), while the live
tree keeps zero `.tsx`. The golden set is what makes the walk non-vacuous — every
`check-gates.sh` run exercises it against planted `.tsx` files — so AC-9 is satisfied
without shipping an island nobody needs. With JavaScript disabled, the whole page reads;
the `<noscript>` line names the drawer as the one thing that does not (the ticket's own
edge case).

**D2 — AC-2 is two properties, each guarded by one mechanism — and `percentOf` is the
reason the first draft's design was wrong.** Review round 1 proved the bypass by
execution: `{percentOf({ hits, n })}% of deliveries build` passes `check-data.sh`
(imported figure, no literal), renders a bare unlabeled rate, carries no `% n=` token
for the first draft's string sweep to match, and compiles unchanged because the draft
added `population` only to `formatRate`. Unexporting `percentOf` is not the fix:
`VerdictChip.astro` calls it twice for non-domain percentages (the no-code chip's share
of silent cells has no frontend/backend to name) and golden case 43 pins it as the
legitimate imported-figure pattern. So the export stays, and the guarantees move to
where they already exist or where the shape of the markup makes them checkable:

- **Property 1 — a percentage never appears without its denominator in the same
  element.** Not invented here: this is PDX-004's proven AC-3 assertion
  (`tests/e2e/PDX-004-the-catalogue-reads.sh`, the `read_html.py` reader whose `rates()`
  requires percent and `n=` off one element and whose chip rule rejects `%` without
  `n=`). This ticket **extends that one reader** — shared, not duplicated — to sweep
  every element of both `dist/index.html` and `dist/analysis.html`, with derived floors;
  the first draft's separate `% n=` string sweep is dropped, because two mechanisms
  guarding one property is how they drift. To keep the page-wide rule exemption-free,
  axis tick labels render as bare numbers and the axis title names the unit ("frontend
  build rate, %") — a scale mark is not a rate, so it does not get to look like one.
  This is the half that defeats the demonstrated bypass: `percentOf`'s bare `%` with no
  `n=` in its element fails the extended assertion wherever it lands.
- **Property 2 — a domain-scoped rate names its domain.** A rate can carry its
  denominator and still be silent about its population: `16/22 = 73%` is honest
  arithmetic over 22 cells that are all frontend tickets. The mechanism is a declared-
  element contract riding the attribute PDX-004 already pins: rate-shaped text (percent
  plus `n=` in one element) may appear **only** inside `data-rate` or `data-verdict`
  elements (asserted page-wide by the same extended reader — a rate the page did not
  declare is a violation, which is what closes the hand-rolled-span route); every
  `data-rate` element carries `data-population="frontend"|"backend"` **and** the
  population word in its own visible text; and a `data-verdict="build-rate"` chip's text
  must contain `frontend`. On the type side, `formatRate` still gains the required
  `population` parameter baked into the returned string (`25% n=20 (frontend)`), which
  makes the honest path total — every existing call site is forced by typecheck to name
  its population — while the assertion, not the type system, is what catches the
  `percentOf` route, and the plan says so rather than claiming totality it does not
  have.

**D3 — the analysis lives at `/analysis`; the catalogue keeps `/`; the leaderboard is
disclosure, not the refused ranking.** DEC-005's ground is specific: a *landing* view
sorted by verdict asserts a confidence the corpus lacks. The catalogue therefore stays
the landing surface, alphabetical, decision-first — and gains only AC-2's population
naming plus a link. The analysis page is one click deep, exists to show composition
rather than to rank, and its leaderboard prints the interval beside every point estimate
with the derived sentence stating how many arms clear the baseline's interval (on the
live corpus: one). That is the Aider row of §4's reference table — a plain table with
exact counts — not the Artificial Analysis league table §4.1 rejects. Sorting by point
estimate with the intervals printed is how a benchmark reader audits a claim; hiding the
sort while publishing the numbers would be coyness, not caution. The DEC row records the
boundary: sorted-with-intervals on the evidence page, never on the landing page, never
as a chip, never as a single score.

**D4 — the DATA-01 line through an SVG chart, exactly.** DEC-017's rule is destination:
a value a reader can read must arrive as an import; a value that becomes position or
size is layout. Applied here: (a) every rendered **text** token — tick labels, dot
labels, counts, rates, intervals, totals, the frontier sentence's pack name — is a
formatted string imported from `@plugdex/data`; (b) **geometry** — `cx`, `cy`, `points`,
`d`, `viewBox`, percentage widths — is computed in component frontmatter as arithmetic
over imported values and layout-named constants (`chartWidth`, `plotPadding`,
`markSize`, `fullWidthScale`), which is precisely what scanner 1's `LAYOUT_VOCABULARY`
admits and what scanner 2 ignores (geometry attributes are not in
`READER_FACING_ATTRIBUTES`); (c) scale **breakpoints that produce readable values** —
tick positions and their labels — are computed in `@plugdex/data` (`axisTicks`), because
a tick label is a figure a reader reads; (d) fractions that become widths (token shares,
interval bands) are exported as fractions from the data package so no site expression
contains `* 100`. This keeps every reader-visible numeric token a member of PDX-021's
derivable set by construction, and keeps the source gate green without touching its
allowlist.

**D5 — `results.json` enters `@plugdex/data` through the join, and only through it.**
The package's own doc comment has said since PDX-002 that results records sit outside
DATA-01 because they carry no fingerprint. The join is what changes: a results record
adopted by the acceptance record whose `run` equals its `date` inherits that record's
fingerprint, regime, and withdrawal state — the traceability it lacks alone. A results
record no acceptance record claims stays outside and is refused loudly. This is DEC-015
applied to a second record type before the defect ships rather than after: the
condition a cost belongs to is decided by fields on two records, and the filenames
(which happen to encode regimes today) are checked by nothing because they decide
nothing — the AC-3 fixture proves it by contradicting them.

**D6 — the radar ships.** The case against is real: every spoke rests on about three
repetitions, the `hi` band swallows most of the axis, and radar area is an axis-order
artefact (§4.3). The case for wins on the ticket's own ground: the enormous band **is
the finding** — it is the page's most legible argument for why there is no ranking, and
AC-5's edge case explicitly forbids clipping it to look tidier. Shipping the table
without the radar would state the noise; the radar makes a reader feel it. Discipline
that keeps it honest: small multiples only (one pack per axis set, §4.3's own
prescription), band behind point estimate and asserted to reach the Wilson `hi` radii,
denominators on every rendering, a caption stating that area is not a metric and that
each spoke carries about three repetitions, and the counts table beside it as the
order-free rendering of the same numbers. §4.3's "axis order is adjustable" clause is
satisfied on this static page by that table — a table has no angular order to bias —
with interactive reordering deferred to PDX-006, whose ticket owns shape-summary
interactivity; the DEC row says exactly this so the deferral cannot silently expire.

## 7. Test Plan (mandatory — TDD)

- **E2E scenario files** (stage 4, before implementation):
  `tests/e2e/PDX-005-the-analysis-reads.sh` (AC-1, AC-2, AC-3-surface, AC-4, AC-5,
  AC-6, AC-8, AC-9's gate probe — over built output and the built packages, node probes
  with `SENTINEL` verdicts, the PDX-004-reads pattern) and
  `tests/e2e/PDX-005-the-analysis-looks-right.sh` (AC-7, AC-10 — Playwright over
  `astro preview`, {360x740, 1280x800} x {light, dark}, the PDX-004-looks-right
  pattern). Golden cases `tests/meta/cases/<n>-site-tsx-*.sh` (AC-9, both directions,
  expected 69-71) land with step 11 and are replayed by `check-gates.sh` inside
  `verify.sh` thereafter.
- **RED condition** (stage 5): `./scripts/verify.sh` PASSes on the untouched tree
  (nothing this ticket adds is required by any existing gate) while both PDX-005
  scenarios FAIL, each on a distinct loud branch: `dist/analysis.html` does not exist;
  the `@plugdex/data` probe import finds none of `wilson` / `gradeCell` /
  `loadEconomics` / `paretoFrontier` and prints no sentinel; the AC-9 probe runs
  `check-data.sh` over a sandbox planting a digit-bearing `.tsx` **beside a clean
  `.astro` companion** and requires a BLOCK naming `DATA-01b` at the `.tsx` file — today
  the gate scans only the companion, passes it clean, and exits 0, so the probe FAILs.
  The companion and the rule-id pin are load-bearing: a tsx-only sandbox already exits
  non-zero printing `DATA-01` for an unrelated reason (the scanned-file floor, verified
  by review round 1), so a probe matching bare `DATA-01` over a tsx-only sandbox would
  be green before the fix — a fake RED. A scenario that passed here would be a fake
  cycle.
- **GREEN condition** (stage 7): `./scripts/verify.sh` PASSes (now including the new
  unit tests via `pnpm test`, the widened walk, and cases 69-71 via `check-gates.sh`),
  both PDX-005 scenarios PASS, and the full regression `./scripts/e2e.sh` PASSes —
  PDX-004's two scenarios prove the card edits broke nothing they assert.
- **Unit tests**: added in every data step (1-6), enumerated per step in §3; they are
  where AC-3 and every interval computation live, per the ticket's §5.

**Per AC: the assertion and the command that produces it.**

| AC | Where | The assertion (GREEN) | Command |
|---|---|---|---|
| AC-1 | reads scenario | `dist/analysis.html` exists; the leaderboard renders one row per pack in the built registry plus baseline (count equality, floor >= 2, both sides derived at run time); every row carries a rate string (`% n=`) or the literal `no graded cell`, an interval, a no-code count, and five economics cells; a node probe recomputes each row from `DATA_PKG` exports and string-matches the rendered cells — the site computed none of them or the match fails | `./tests/e2e/PDX-005-the-analysis-reads.sh` |
| AC-2 | reads scenario + typecheck | PDX-004's AC-3 reader (`read_html.py` — percent and `n=` read off one element), extended rather than duplicated, sweeps every element of `dist/index.html` + `dist/analysis.html`: (1) any element whose own text carries `%` carries `n=` in the same element — this is what defeats the demonstrated `percentOf` bypass, and it holds exemption-free because axis ticks render bare numbers; (2) rate-shaped text appears only inside `data-rate` / `data-verdict` elements; (3) every `data-rate` element carries `data-population` and the population word in its visible text, and every `data-verdict="build-rate"` chip's text contains `frontend`; floors derived from the built registry (ASSERT-01: zero rates found is a FAIL); the card block contains both populations' rates side by side; the extended reader is additionally proven against a planted fragment of the round-1 bypass (`percentOf`-shaped bare rate) which must FAIL — the PDX-004 AC-4 planted-fixture pattern, so the assertion is tested on a known-bad input rather than only on the live tree; `pnpm typecheck` forces every `formatRate` call site to name a population (step 6 — the honest path is total; the bypass route is the assertion's job, per §6.5 D2) | `./tests/e2e/PDX-005-the-analysis-reads.sh`; `./scripts/verify.sh` (typecheck step) |
| AC-3 | unit tests | The planted fixture whose filenames contradict its records joins by `date` = `run`: rows land in the record-stated regime, the orphan results record is refused by name, the withdrawn run's rows are absent from the default pool | `pnpm --filter @plugdex/data test` (inside `./scripts/verify.sh`) |
| AC-4 | reads scenario | Both scatter SVGs exist in built output; per chart, a node probe derives the frontier from `DATA_PKG`: where it has >= 2 members the `path.pareto` element exists with the derived vertex count; where it has < 2 (the live wall-clock chart) **no** frontier path exists AND the chart's explanatory sentence element exists naming the single member — the negative half only counts after the positive half found the chart (ASSERT-01) | `./tests/e2e/PDX-005-the-analysis-reads.sh` |
| AC-5 | reads scenario | One radar per measured pack (count derived); per radar, the band polygon's vertex radii match the Wilson `hi` values derived from `DATA_PKG` within a named tolerance (0.5 viewBox units, stated in the scenario) and the estimate polygon sits on `p` — the band is behind and unclipped by construction; the subtitle carries the graded-cell count; the counts table renders `k/n` text in every pack x ticket cell (144 cells derived, zero empty-text cells — a colour without its count fails here) | `./tests/e2e/PDX-005-the-analysis-reads.sh` |
| AC-6 | reads scenario | A node probe loads the blocked corpus via `DATA_PKG` and derives totals (the ticket's 312 / 229 / 72 / 6 x 12 are claims this derivation asserts); the DOM grid then matches: mark count = cell count, arm rows x ticket columns = derived squares, zero empty squares, per-state mark counts = `gradeCell` tallies, and a mark-per-repetition check on a maximal square (8 marks) | `./tests/e2e/PDX-005-the-analysis-reads.sh` |
| AC-7 | looks-right scenario | On computed style, both schemes: built / failed / no-code marks are pairwise distinct on at least one non-colour channel (glyph content, border-style, background-image) — asserted by reading the computed channels, not the class names; mark-versus-ground non-text contrast >= 3:1 and all grid/heat/legend text >= 4.5:1, computed from resolved colours; floors on element counts throughout | `./tests/e2e/PDX-005-the-analysis-looks-right.sh` |
| AC-8 | reads scenario | The `data-composite-index="refused"` element exists with non-empty text containing the stated reason (positive, sentinel); only then the sweep: no other element's text matches a composite/overall-score/index-score pattern and no leaderboard header is `score` or `index` — the honest proxy for "no single-score element", named as a proxy in the scenario comment | `./tests/e2e/PDX-005-the-analysis-reads.sh` |
| AC-9 | reads scenario + golden set | RED-visible half: the gate, run over a sandbox planting a digit-bearing `.tsx` beside a clean `.astro` companion, BLOCKs naming `DATA-01b` at the `.tsx` file — FAILs today (the gate scans only the companion and exits 0; a tsx-only sandbox is not usable as the probe, because it already exits non-zero on the scanned-file floor printing bare `DATA-01`). Permanent half: cases 69 (JSX text BLOCK), 70 (reader-facing JSX attribute BLOCK), 71 (clean `.tsx` passes) replayed by the golden set, each BLOCK case planting the same clean companion and pinning its specific rule id | `./tests/e2e/PDX-005-the-analysis-reads.sh`; `./scripts/check-gates.sh` |
| AC-10 | looks-right scenario | At 360x740 in both schemes: `document.documentElement.scrollWidth <= innerWidth` (no body horizontal scroll) while the grid's own container may scroll (`scrollWidth > clientWidth` allowed there only); every chart SVG's rendered width fits its container; dark-mode screenshots written to `.docs/scratch/pdx-005-browser/` for the DEV-01 checklist | `./tests/e2e/PDX-005-the-analysis-looks-right.sh` |

Ticket edge cases mapped: superpowers renders `no graded cell` and no `%` in its rate
cell (AC-1 row, derived by finding the zero-graded arm at run time, never by name);
disagreeing repetitions are structural — one mark per rep, no majority (AC-6 row);
invalid cells drawn with reason available (AC-6 mark counts + a drawer-content spot
check on a derived invalid cell); the radar band unclipped (AC-5 row); JavaScript
disabled (static markup asserted by the reads scenario existing at all, plus the
`<noscript>` element's presence).

## 8. Feature Tags

- `site` — the analysis page, its components, the catalogue card's population naming
- `data` — grader, intervals, aggregates, economics join, frontier
- `harness` — the `.tsx` walk and its golden cases

## 8.5 References Consulted (REF-01)

The Reference Map's PDX-005 row predates today's ticket rewrite and names the
receipt-drawer references. Both are recorded below as consulted — honestly, including
what the consultation found — and the ticket's own §6 references follow. The map's
machine copy is out of Allowed scope; §5 flags the follow-up.

| Reference | Consulted | Note |
|---|---|---|
| `_invocation.json` | Y (2026-08-19) | Searched the whole tree: no file of this name exists anywhere (`find` over the repository, node_modules excluded); the two mentions are DESIGN.md's Reference Map row and the superseded Phase B drawer description. The mapped reference belongs to the old receipt-drawer ticket; the drawer this ticket ships reads cell fields instead, and step 12 corrects the roadmap text |
| acceptance cells | Y (2026-08-19) | `bench/data/runs/*.acceptance.json` via `packages/data/src/load.ts` and `schema.ts`: per-cell gate fields are domain-split (`build`/`typecheck` frontend, `import_ok`/`passes` backend), `valid`/`invalidReason` always present, regime and withdrawal are record fields — the shapes steps 2-4 consume |
| `.docs/tickets/PDX-005_site-the-analysis-page.md` (rewritten 2026-08-19) | Y (2026-08-19) | AC-1..10, the per-domain disclosure defect, the e2e mapping this §7 follows, golden cases from 69, and §6 designating this plan as the record of the prototype's measured figures |
| The rendered prototype (`aa.html`, `aa-data.json`, `aa-tasks.json`; `docs/images/analysis-*.png`) | Y (2026-08-19) | The design contract: section order, chart inventory, data shapes (rows/grid/perTask/domains), the degenerate wall-clock frontier, the intervals verified Wilson; its JS is rendering convenience (D1), its palette yields to §5 tokens, its colour-only squares yield to DEC-018 shapes |
| DESIGN.md Phase B, §4 + §4.1-4.3, §5, DEC-018, DEC-020, DEC-021, DEC-022 | Y (2026-08-19) | Aider-table and caniuse-grid rows ground D3 and the grid; §4.3 grounds D6's small-multiples + area caption; §5 palette and shape-primary rules; DEC-020 fixes the one-condition masthead; DEC-021/022 fix the card seam and the disclosure posture |
| `bench/DERIVATIONS.md` D-001, D-002 | Y (2026-08-19) | D-001: the withdrawn Fisher p and the no-ranking ground the AC-8 statement cites; D-002: superpowers 49/50 silent on the published pool — the arm the leaderboard renders as `no graded cell`, never 0% |
| `packages/data/src/verdict.ts` / `schema.ts` / `load.ts` | Y (2026-08-19) | `buildCounts`'s exact rule (the frontend-only headline, kept as the frontend grader), `formatRate`'s DATA-01 rationale (the AC-2 spine extends it), loader refusals and the `regime` narrowing steps 3-4 build on |
| `bench/data/runs/*.results.json` (all ten) | Y (2026-08-19) | Every record's top-level `date` equals its acceptance partner's `run` (verified across all ten pairs); rows carry cost/turns/tokens/LOC/duration and no fingerprint — the join of D5 |
| `packages/site/src/pages/index.astro` + `PackCard.astro` / `VerdictChip.astro` / `InstallDialog.astro` + `global.css` + `astro.config.mjs` | Y (2026-08-19) | The build-time loading pattern, the masthead's DEC-020 prose step 7 extends, the dialog + inline-script pattern D1 reuses, the token system step 10 extends, and the no-framework-integration stance D1 preserves |
| `scripts/check-data.sh` | Y (2026-08-19) | The walk regex (`.ts|.astro|.css`), `LAYOUT_VOCABULARY`, `READER_FACING_ATTRIBUTES`, scanner 1's context-name rule and scanner 2's expression/text rules — D4's line is drawn against these exact mechanisms, and step 11's JSX gap (`JsxText` is not a string literal) was read off scanner 1 |
| `.docs/analysis/PDX-023_plan.md` | Y (2026-08-19) | Shape and depth template; the expected-number convention for DEC and case ids; the voluntary-references precedent this section extends to a stale mapped row |
| `tests/e2e/PDX-004-*.sh`, `tests/meta/cases/39/43`, `scripts/check-references.sh` | Y (2026-08-19) | Sentinel/judge probe anatomy and the browser matrix §7 reuses; the `read_html.py` AC-3 reader (percent + `n=` off one element) that §6.5 D2 extends to both pages; the plant-site golden-case anatomy cases 69-71 follow; the gate's token-grep mechanics this section satisfies |

### 9.0 What round 1 of this review found

One blocker, verified by execution, and the verified side findings folded in rather
than argued with. (Round 1's full rubric scored P4 FAIL, all other rows PASS; the round-2
review below replaces it, per the PDX-023 precedent.)

- **The blocker (P4): `percentOf` defeated both teeth of the first draft's D2.** The
  reviewer ran the bypass: a component rendering
  `{percentOf({ hits, n })}% of deliveries build` passes `check-data.sh` (exit 0),
  renders a bare rate with no population and no denominator, contains no `% n=` token
  for the draft's string sweep, and compiles unchanged because step 6 gave `population`
  to `formatRate` only. Fixed structurally, not by unexporting (`VerdictChip` uses
  `percentOf` legitimately for non-domain percentages and golden case 43 pins the
  imported-figure pattern): AC-2 is split into its two properties and each gets one
  mechanism — denominator-in-same-element is PDX-004's proven AC-3 reader extended
  page-wide to both pages (the draft's parallel string sweep is dropped; two mechanisms
  guarding one property is how they drift), and population naming is a declared-element
  contract (rate-shaped text only inside `data-rate`/`data-verdict` elements; every
  `data-rate` element carries `data-population` plus the visible population word;
  build-rate chips contain `frontend`), with `formatRate`'s required `population`
  keeping the honest path total. Axis ticks render bare numbers so the page-wide rule
  needs no exemption. The revised D2 and the AC-2 row carry the mechanism; the reads
  scenario is where the planted `percentOf` bypass must FAIL.
- **AC-9 probe precision (comment 3, verified):** a tsx-only sandbox already exits
  non-zero printing `DATA-01` (the scanned-file floor), so the probe and every BLOCK
  golden case plant a clean `.astro` companion and pin `DATA-01b` (or the specific rule
  id) rather than bare `DATA-01`. Folded into §7's RED condition, the AC-9 row, and
  step 11.
- **JSX attribute polarity (comment 2a, verified against the TypeScript API):**
  attribute string initializers are already scanned as generic literals with no
  `JsxAttribute` context, so the `.tsx` defect there is a false positive on
  machine-facing attributes, not a gap. Step 11 now adds the `JsxAttribute` branch
  (non-reader-facing exempt, reader-facing BLOCK) and the clean case pins the exemption
  with realistic attributes. Template literals **with substitutions** (comment 2b) are
  named residue — pre-existing in every extension scanner 1 reads — recorded in step
  12's PDX-021 scope-note correction, not claimed closed.
- **Ridden, per REV-02:** comment 1 (geometry-as-figure is DEC-017's recorded residue,
  owed to PDX-021 — the plan does not overclaim against it and §5 names it), comment 7's
  tolerance nit (now named: 0.5 viewBox units), comments 4-6 (D1, D6, and the staleness
  facts confirmed as sound).

## 9. Agent Review (round 2)

### Reviewer
- Model: Fable 5 (Claude Code subagent)
- Reviewed at: 2026-08-19 18:05

### Verdict
- [x] APPROVED_WITH_NOTES

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | Unchanged from round 1: §3 touches only ticket-Allowed paths, `bench/**` stays read-only, §7 maps AC-1..AC-10; the rebuild altered mechanisms, not scope |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | Steps 1-6 two files, 7-9 three, 10 two, 11 two plus three golden cases, 12 one — the rebuild added case 71 but no step exceeds 3 files |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | PASS | Revised D2 reuses PDX-004's AC-3 reader rather than adding a parallel mechanism, consistent with DEC-017's one-place-per-rule posture; D1/D3-D6 unchanged from round 1's PASS |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | Round 1's bypass re-run against the revised contract: a sweep implementing D2's three rules exactly (built on the extracted `read_html.py` contract) FAILs `<p>40% of deliveries build</p>` on rule 1 — the demonstrated bypass is caught, and the AC-2 row plants that fragment as a known-bad input |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | §4 and §5 unchanged in structure; the template-substitution residue is now named in step 11/12 rather than left implicit |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | Hangul-range scan over the revised plan and ticket: zero matches (re-run 2026-08-19) |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `./scripts/check-references.sh .docs/analysis/PDX-005_plan.md` re-run on the revised plan: "REF-01 PASS — all 2 required reference(s) consulted" (exit 0) |

### Comments

All four round-2 questions were answered by running, not reading. Items 2-5 are
**carried to the report stage as named findings**, per REV-02 — none is a new blocker:
each requires site code to deliberately assemble a rate through an odd channel from
imported numbers, while the honest path stays total under `formatRate`.

1. **The round-1 bypass is dead under the revised contract — verified by execution.**
   I extracted PDX-004's `read_html.py` verbatim from the scenario heredoc and
   implemented D2's three rules exactly as specified, then fed it fragments:
   `<p>40% of deliveries build</p>` (the `percentOf` bypass) FAILs rule 1 (% with no
   `n=` in the element); a hand-rolled `<span>73% n=22</span>` outside declared elements
   FAILs rule 2; a rate split across sibling spans FAILs rule 1 on the `%`-only child;
   the plan's legitimate `data-rate`/`data-population` shape passes clean. The blocker
   is closed by the mechanism as written, and the AC-2 row's planted-fragment assertion
   makes the closure permanent.
2. **Carry to report — the sweep is `%`-glyph-keyed.** `<p>40 percent of deliveries
   build</p>` (same `percentOf` route, the word instead of the glyph) PASSes all three
   rules as specified. DEC-017 names spelled-out figures as residue for digit scanners,
   but this one still carries the digit `40`, so it is cheap to close: the reader's
   rate/percent pattern should also match `\d+\s*percent\b`. One regex alternation when
   the scenario is written.
3. **Carry to report — attribute-borne rates escape the element-text sweep.**
   `<div aria-label="73% n=22"></div>` PASSes: the rules read element text, and an
   imported rate string bound into `aria-label`/`title` never becomes element text.
   Source-side, scanner 2 blocks only *typed* digits in reader-facing attributes, not
   imported values. Recommend the extended reader also sweep `READER_FACING_ATTRIBUTES`
   values for rate shapes — a screen reader is a reader, by the gate's own argument.
4. **The JSX attribute polarity claim is correct, and the check strengthened it.**
   Running scanner 1's logic verbatim over `.tsx` probes: machine-facing
   `className="grid-2"` / `data-mark-size="8"` / `data-columns="3"` are all flagged
   today (the context climb reaches the component's own declaration and returns `Card`),
   reader-facing `title="47% ..."` is flagged for the same accidental reason, and
   digit-bearing JSX text yields zero violations. So the revised step 11 has the right
   polarity: exemption branch for machine-facing, explicit BLOCK for reader-facing —
   and the explicit BLOCK is load-bearing, not message polish, because the generic
   rule's coverage is spoofable by component naming: inside
   `const LeaderboardRow = () => <td title="47% of deliveries build">`, the context is
   `LeaderboardRow`, `/row/i` matches layout vocabulary, and the generic rule PASSES it
   (verified). The `JsxAttribute` branch fires on the attribute itself and closes that.
5. **New finding, note-level — the walk regex alone mis-routes `.tsx` into the Astro
   scanner.** Verified in a sandbox copy of the gate: widening only the regex sends
   `.tsx` down the template branch (the dispatch tests `endsWith('.ts')`, which `.tsx`
   fails), where the Astro compiler parsed a planted component and reported its JSX text
   as DATA-01b — the right verdict from the wrong scanner, with real code lines exposed
   as pseudo-text. Step 11 must also route `.tsx` to `scanCode` and keep it out of
   `scanTemplate`/`scanStyles`; it currently names only the regex and the scanner-1
   branches. Case 71 as specified (layout-vocabulary literals like `const markSize = 8`
   in code) would FAIL under the mis-route (that line becomes a digit-bearing text node
   to the Astro parser), so the golden trio forces the correct routing at GREEN — but
   naming the dispatch in the step saves a stage-5 loop.
6. **Markup caveat for the implementer.** Rule 1 applies per element, so `%` and `n=`
   must share one element's text: splitting the rate string across child spans inside a
   `data-rate` element flags the `%`-only child (verified, fragment D). Keep the
   formatted rate string as one text node.
7. **Nothing round 1 approved was broken by the rebuild.** REF-01 re-run PASS; Hangul
   scan clean; step granularity intact; D1/D3/D4/D5/D6 substantively unchanged; §9.0
   records round 1 accurately; the AC-5 tolerance is now named (0.5 viewBox units); the
   AC-9 probe and BLOCK cases plant the clean companion and pin `DATA-01b` exactly as
   the round-1 finding required; step 1's bare-number ticks are consistent with D2's
   exemption-free page-wide rule and step 9's axis-title wording.

### Blockers (only if NEEDS_REVISION)

None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES — round 2, 2026-08-19 (REV-02 cap). Round 1's blocker is
  verified closed by execution (§9 comment 1); comments 2-6 are named report-stage
  carries, not blockers. Round 1 record: §9.0.
- Human: _(pending)_
