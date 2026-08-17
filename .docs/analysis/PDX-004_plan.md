# PDX-004 Plan — The catalogue: cards, verdict chips, install, and DATA-01

- Ticket: `.docs/tickets/PDX-004_site-catalogue-cards-verdicts-and-install.md`
- Author: Fable 5 (planning agent)
- Date: 2026-08-17

## 1. Goal & Context

plugdex today is a dataset with a machine face. `@plugdex/data` loads the acceptance
records and refuses what it cannot trace; `@plugdex/registry` lists the packs, generates
the marketplace, and a real `claude plugin install` has been proven end to end. What does
not exist is the thing a visitor sees. This ticket builds it: a static Astro catalogue,
one card per listed pack, a verdict chip legible before any chart loads, and an install
action that hands over the two commands that actually work.

Two design moves carry the ticket:

- **The verdict is computed where the data lives.** `verdictFor` goes into
  `packages/data/src/verdict.ts`, not into the site, so the site cannot compute a
  different answer than the dataset gives. The site renders a verdict object; it never
  derives one. This also changes `@plugdex/data`'s self-description — the package
  docstring currently says it "computes no statistic that is not already in a record",
  which was true for PDX-002's scope and stops being true here. The docstring is updated
  to say what becomes true instead: the package derives verdicts by one pure, unit-tested
  function, and still contains no hand-typed figure.
- **DATA-01 becomes a gate.** `scripts/check-data.sh` blocks a numeric literal in
  `packages/site/**` that did not flow in through an import. The hard problem, which the
  ticket names outright, is telling `const buildRate = 47` from `gridColumns = 3` — a
  gate that cannot make that distinction gets disabled within a week. §3 step 8 and
  DEC-016 below commit to the discrimination mechanism concretely rather than promising
  one.

Two facts found while planning shape the design and are recorded here so the review can
check them rather than discover them:

- **DESIGN.md fixes the verdict priority order but not the 3-vs-4 boundary.** The chip
  table ("The one design decision still open") carries an explicit Priority column, so
  the ordering 1→5 is given. But conditions 3 ("produces code; the pass rate over its
  code-producing cells") and 4 ("produces code, but no metric differs significantly from
  baseline") are both true of every code-producing pack as written, and their example
  columns contradict each other ("ponytail and the rest" vs "the honest default for most
  packs"). As written, priority 4 is unreachable. This ticket must produce the missing
  boundary; DEC-015 below proposes it.
- **The palette's `no code` colour fails WCAG in both schemes.** Computed against the
  DESIGN.md §5 values: `#B3ADA0` on `#FAF8F3` is 2.10:1 and `#5A554C` on `#141311` is
  2.51:1 — below the 4.5:1 text floor (SC 1.4.3) and below the 3:1 non-text floor
  (SC 1.4.11, which is explicitly unrounded). So status hues cannot carry text or the
  load-bearing glyph anywhere on this site. DEC-017 below rules the application: chip
  text and shape glyphs render in ink; the status hue appears only as background tint
  and border. This is an application constraint, not a palette change — the §5 values
  stand.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: work is confined to `packages/site/`,
  `packages/data/src/verdict.ts` (plus its test and the `index.ts` export line, which the
  ticket's placement of the function implies), `scripts/check-data.sh`, one new step in
  `scripts/verify.sh`, golden cases under `tests/meta/cases/`, `tests/e2e/PDX-004-*.sh`,
  and `DESIGN.md` for the decisions this ticket produces. The root `package.json` is not
  expected to change — `pnpm -r` picks the new package up from the workspace glob — and
  is touched only if wiring proves necessary, which the ticket permits. `site` is already
  a registered package name (ST-02).
- **Ticket Scope.NotAllowed respected**:
  - No leaderboard, composite score, or default sort by any verdict (DEC-005). The
    landing grid orders cards alphabetically by display name — an order that encodes no
    measurement and cannot be mistaken for one.
  - No hand-typed numbers in components, including prose quantities. The gate enforces
    the digit half deterministically; the "about half" half is not gate-enforceable
    without unbounded false positives ("one card per pack", "two commands"), so it is
    enforced where the ticket puts it — in scope review — and §5 records that split
    explicitly rather than letting the gate imply coverage it does not have.
  - No receipt drawer, no cell grid. The card links nowhere yet; the chip is the whole
    evidence surface this ticket ships. PDX-005 owns the rest and nothing here
    half-builds it.
  - No shape summaries, exhibit, withdrawal register, or method page (PDX-006 onward).
  - No unmeasured listings. Every entry the built registry exports is a measured arm, so
    the live page renders no `unmeasured` chip; the verdict and its styling exist and are
    tested synthetically, because the function must be total over the five verdicts, but
    PDX-012 owns putting a queue on the page.
  - Nothing deployed, purchased, or announced (CR-01). The site builds and is served
    locally by the e2e; that is all.

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | Verdict types and the pure function | `packages/data/src/verdict.ts`, `packages/data/src/verdict.test.ts`, `packages/data/src/index.ts` | `verdictFor = ({ packId, cells, claims })` folding the five conditions in priority order, first match wins. Every union member carries its numerator and denominator — there is no precomputed percentage field, so a chip cannot render a rate without also holding its n (AC-3 by construction). Thresholds (the 0.8 no-code fraction from the DESIGN.md chip table, the 0.05 nominal p for the DEC-015 boundary) live here with cited rationale comments. Unit tests run against synthetic cells: each verdict, the two-condition pack, n=3 preserved, the 3-vs-4 boundary either side of the threshold. The `index.ts` docstring is corrected as described in §1 |
| 2 | Scaffold the site package | `packages/site/package.json`, `packages/site/tsconfig.json`, `packages/site/astro.config.mjs` | `@plugdex/site`: Astro, static output, no adapter, workspace deps on `@plugdex/data` and `@plugdex/registry`; the script set `verify.sh`'s recursive pnpm steps expect (`typecheck` via `astro check`, `lint` covered by root config, `test`, `build`). `playwright` and `@astrojs/check` as devDependencies — Playwright is not currently anywhere in the workspace (no hit in the root manifest or `pnpm-lock.yaml`), so AC-7 requires adding it here, scoped to the site package |
| 3 | Theme | `packages/site/src/styles/global.css` | DESIGN.md §5 as custom properties: light palette on `:root`, dark under `prefers-color-scheme: dark`; `font-variant-numeric: tabular-nums` wherever a digit can appear; 66–72ch body measure; the paper/terminal split. Status hues defined as tint/border tokens only, per DEC-017 |
| 4 | The verdict chip | `packages/site/src/components/VerdictChip.astro` | Renders a verdict object: shape glyph + label + `n=` from the object's own fields. Glyph and text in ink; hue as background tint and border (DEC-017), so the null-result chip has identical computed weight to every other (AC-6). Static caption strings are digit-free — any figure in a chip is a rendered field of the verdict object |
| 5 | The pack card | `packages/site/src/components/PackCard.astro` | Name, author (the tagged `Attributed` value — rendering what DEC-014 stores, with the `curated` tag surfaced, not flattened to a bare string), stars with their `readAt`, one line, chip, install button |
| 6 | The install dialog | `packages/site/src/components/InstallDialog.astro` | Native `<dialog>` plus a few lines of inline vanilla script for open/copy — a copy button does not earn a React island, so this ticket ships zero framework runtime (static-first rule applied, not a new decision). Contents: the two commands (`claude plugin marketplace add …`, `claude plugin install <packId>@plugdex`), a copy control per command, and a line naming the upstream repository the install will actually clone from — SRC-01 rendered (AC-5). `<dialog>` gives keyboard reachability, focus containment, and Escape natively (AC-7) |
| 7 | The page | `packages/site/src/pages/index.astro` | Frontmatter loads the corpus, iterates the built registry's entries, calls `verdictFor` per pack, renders the grid alphabetically. Every name and every chip is in the emitted HTML — no client JS on the read path (AC-1) |
| 8 | The DATA-01 gate | `scripts/check-data.sh`, `scripts/verify.sh` | The mechanism of DEC-016 (below), on the `check-src.sh` model: bash wrapper, inline node scanner, `SENTINEL` line carrying `{files, literals, bad}`, and a scan of zero files is a FAIL — closing in advance the PDX-003 finding-1 class where a well-formed report of zero work reads as a pass. One new verify step; the e2e asserts the step by a positive grep of verify output, not by its number (PLAN-01) |
| 9 | Golden cases — the blocked side | `tests/meta/cases/` (3 files) | `const buildRate = 47` in a planted component's frontmatter; `47% builds` as template text; `content: "47%"` in CSS (the one path by which a stylesheet can state a claim). Each asserts the DATA-01 pattern, numbered after the current highest case |
| 10 | Golden cases — the clean-pass side and the empty scan | `tests/meta/cases/` (2 files) | Clean-pass (`EXPECT_PASS=1`): `gridColumns = 3`, `z-index: 10` in a style block, `viewBox="0 0 24 24"`, `tabindex="0"` — the gate must not flag any of them, because false positives are how this gate dies. And an empty-scan case: a tree with no site sources must FAIL the gate ("scanned nothing"), not pass it (ASSERT-01) |
| 11 | Scenario 1 | `tests/e2e/PDX-004-the-catalogue-reads.sh` | AC-1..AC-6 (markup half of AC-6), AC-8, over built output — assertions in §7 |
| 12 | Scenario 2 | `tests/e2e/PDX-004-the-catalogue-looks-right.sh` | AC-7 and the computed-style half of AC-6: real Chromium via Playwright, both viewports, both schemes, keyboard walk, contrast computed from `getComputedStyle`, screenshots to `.docs/scratch/pdx-004-browser/` |
| 13 | Decision log | `DESIGN.md` | DEC-015, DEC-016, DEC-017 rows; the "still open" chip section gains a pointer to DEC-015 so the document stops carrying an open question it has answered |

### The verdict function (AC-2)

The five verdicts and their priority order come from DESIGN.md's chip table, adopted
verbatim: 1 `produces no code unattended`, 2 `published claim not reproduced`,
3 `N% builds`, 4 `no detectable effect`, 5 `unmeasured`. Conditions are evaluated in
that order and the first match wins.

- **A pack matching 1 and 2 at once shows 1.** The unit test asserts it against a
  synthetic pack whose cells write no code and whose claim's CI excludes the published
  figure. Why 1 wins: §4.2's three questions are ordered by decision relevance, and
  detection precedes claim verification — "it does nothing unattended" is the fact that
  makes an install decision on its own, while a claim verdict on a pack that ships no
  code grades the advertising of work that does not exist.
- **Condition 1 is computed over all valid cells of the arm** (fraction with
  `wroteCode === false` at or above the 0.8 threshold from the chip table). The table's
  "as-shipped regime" qualifier is not a field the records carry — DEC-005 itself records
  that the dataset cannot state regimes — so the computable condition is over what the
  records hold, and DEC-015 records that narrowing rather than letting the chip imply a
  field that does not exist.
- **Condition 2 takes its inputs as data, and no live pack can currently trigger it.**
  The claimed figure and the metric it is about (tokens, for the known case) live only in
  `results.json`, which carries no fingerprint and is outside `@plugdex/data` — the
  contradiction PDX-002 §5 named and deferred. `verdictFor` therefore accepts an optional
  `claims` input and implements the branch fully, unit-tested against synthetic claims;
  on the live corpus the parameter is empty and the pack in question falls through to 3
  or 4. Hand-typing the CI to make the chip appear would be the exact violation this
  ticket exists to gate, so the branch waits for the ticket that brings the claims record
  under DATA-01 (phase C). Stated as a limit, inherited explicitly.
- **The 3-vs-4 boundary (DEC-015, produced by this ticket):** chip 3 fires when the
  pack's build outcome over code-producing cells differs from baseline's at the nominal
  two-sided Fisher exact p < 0.05, computed inside `verdictFor`; otherwise chip 4. The
  chip for 3 remains descriptive — a rate with its n, never a rank — and its digit-free
  caption notes the nominal-only status, which keeps DEC-015 consistent with DEC-005: no
  ordering is asserted, one measured rate is stated with its denominator. Under this
  boundary the corpus is expected to yield at least one null-effect chip on the live page
  (DESIGN.md records four of five packs at baseline), which is what gives AC-6 a real
  target; the scenario locates the null chip by rendered verdict, derived at runtime, and
  fails loudly if none exists rather than assuming a pack-to-verdict table that would go
  stale (PLAN-01).
- **Condition 5** is the empty case: no cells for the packId. It renders a chip with a
  label and no rate — the edge case list's "must not render `0%`" falls out of the union
  shape, because the unmeasured member simply has no numerator/denominator fields to
  render.

### The DATA-01 discrimination mechanism (AC-4, DEC-016)

The gate distinguishes by **destination, not by value**: a number bound for the layout
engine is legal; a number that can reach the reader's eyes is a BLOCK unless it flowed in
through an import. Three scanners, all driven from one inline node script:

1. **Code positions** — TypeScript AST (the `typescript` package, already a root
   devDependency; no new tooling) over `packages/site/src/**/*.ts` and the frontmatter of
   every `.astro` file (the fence-delimited block, which is TypeScript by Astro's
   definition). Every numeric literal and every digit-bearing string literal is a
   violation unless its context is on the allowlist: a declaration or property whose
   name matches the layout vocabulary pattern held at the top of the script (width,
   height, size, gap, column, row, radius, z/index, duration, delay, breakpoint, margin,
   padding, opacity, weight, scale — the single source of truth, on the NOLLM-01 model),
   an element-access index or slice-class argument, or a type position. This is what
   admits `gridColumns = 3` while blocking `const buildRate = 47`.
2. **Rendered positions** — the Astro template body parsed with `@astrojs/compiler`'s
   `parse` (shipped as a dependency of Astro itself, imported from the workspace's
   node_modules; deterministic and offline). A digit in a text node, in an expression's
   literal, or in a reader-facing attribute (`alt`, `title`, `aria-label`,
   `placeholder`) is a BLOCK regardless of any identifier name; digits in machine-facing
   attributes (`class`, `style`, `width`, `height`, `viewBox`, `tabindex`) are exempt.
3. **CSS** — `.css` files and `<style>` blocks are exempt wholesale, except a `content`
   declaration containing a digit, which is blocked: `content` is the one property
   through which a stylesheet can put a claim in front of a reader.

Why this closes rather than merely narrows the hole: scanner 1's name allowlist is
spoofable in principle (`const gridColumns = 47`), but scanner 2 blocks literal digits at
every rendered position regardless of what identifier fed them — a spoofed constant still
cannot be *typed into markup*, and routing it through markup as `{gridColumns}` is an act
a diff reviewer sees on a one-page site. The gate's job is the honest mistake; the ticket
is explicit that false positives, not adversarial completeness, are what kill a gate like
this, which is why the allowlist is of contexts, is short, lives at the top of the
script, and can only be extended together with a golden case.

Two legal figure sources, recorded in DEC-016: values imported from `@plugdex/data`
(measurement figures) and from `@plugdex/registry` (star counts and provenance fields,
each carrying its SRC-01g retrieval receipt and `readAt`). The card renders stars, which
are numbers, and they are legal for the same reason the measurement figures are: they
arrive as imports from a package whose records carry receipts, and no literal for them
exists in site source. The gate needs no special case for this — it blocks literals, and
imports are not literals — but the rule text of DATA-01 says "a record in
`packages/data`", so DEC-016 states the interpretation rather than leaving the gate and
the rule to disagree quietly.

## 4. Risks

- **The gate false-positives and gets disabled** → the failure mode the ticket predicts.
  Mitigation is structural: the allowlist is of syntactic contexts rather than values,
  the clean-pass golden case pins the legitimate literals the ticket names, and the
  stated procedure for a false positive is to extend the allowlist *with* a new
  clean-pass case in the same change — never to skip the gate. `check-gates.sh` replays
  both sides on every verify.
- **The identifier allowlist is spoofable** → accepted and stated. Scanner 2 blocks the
  rendered position regardless of naming; what remains (laundering a claim through a
  layout-named constant into an expression) is visible in any diff of a small site and
  is a review matter. Pretending the gate stops a determined liar would be a claim the
  gate cannot cash.
- **`@astrojs/compiler`'s parse API drifts under an Astro upgrade** → the golden cases
  break loudly on the same verify run that upgrades the dependency (GATE-01), so drift
  cannot be silent. A regex fallback over template source was considered and rejected:
  regex over markup is precisely the false-positive machine the first risk describes.
- **Playwright needs a browser binary and, on first run, the network** → scenario 2 runs
  `playwright install chromium` idempotently before driving it (cached thereafter), and
  a missing browser after that step FAILs loudly. There is no skip path: AC-7 *is* the
  browser, so a skip would be the fake cycle the RED stage exists to prevent. This
  mirrors PDX-003's stance on network-requiring assertions, and differs from its
  missing-`claude` skip because there the binary was outside the ticket's control and
  here the dependency is installed by this ticket.
- **The DEC-015 boundary could be read as reintroducing a ranking** → the chip is a
  rate with a denominator, the caption states nominal-only, no view sorts by verdict,
  and the landing order is alphabetical. The p-threshold decides which *description* is
  shown, not an order. DEC-005 is cited in the DEC-015 rationale so the tension is ruled,
  not latent.
- **Verdict 2 is dead code on live data** → deliberate, stated in §3, and inherited from
  PDX-002 §5's record-universe contradiction rather than created here. The branch is
  fully unit-tested against synthetic claims; the alternative — hand-typing the one known
  CI — is the violation the ticket gates.
- **The palette's `no code` value fails both WCAG floors** → measured during planning
  (2.10:1 light, 2.51:1 dark), so the design never puts text or the load-bearing glyph
  in a status hue (DEC-017), and scenario 2 asserts computed contrast in the real
  browser so a future style change that regresses this fails mechanically rather than
  aesthetically.
- **Astro brings a large transitive tree into `packages/`** → NOLLM-01's gate scans
  manifests and source on every verify; Astro depends on no blocklisted inference SDK.
  The golden set's existing NOLLM cases keep the check honest.
- **The browser scenario makes every TDD loop slower** → bounded: one Chromium launch,
  four viewport/scheme combinations, a cached binary. Accepted as the price of DEV-01
  meaning something; a UI ticket verified without a browser would be the cheaper and
  worthless alternative.

## 5. Out of Scope

- The receipt drawer and the cell grid — PDX-005. The chip links to nothing yet.
- Shape summaries (PDX-006), the exhibit (PDX-007), gate blind spots (PDX-008), the
  withdrawal register and CLAIM-01 (PDX-009), method page (PDX-010).
- Listing unmeasured packs and the request queue — PDX-012 (DEC-006 honoured by
  deferral, not by placeholders).
- Bringing `results.json` (cost/token figures) under DATA-01 — the inherited PDX-002 §5
  contradiction, which is what keeps verdict 2 synthetic-only; it rides to phase C with
  this second explicit hand-off.
- Deploying, domains, SEO — PDX-014, and CR-01 until instructed.
- A leaderboard, composite index, or verdict sort — not deferred, rejected (DEC-005,
  DESIGN.md §4.3).
- Gate-enforcing prose quantities ("about half") — review-enforced NotAllowed; a
  deterministic scan for quantity words has unbounded false positives and would kill the
  gate's credibility in the way the ticket warns about.

## 6. Rules / Decisions Applied

- LANG-01 — English-only, no allowlist; applies to every artifact this ticket writes.
- DATA-01 — the rule this ticket makes enforceable; the gate, the golden cases, and the
  verify step are its teeth.
- GATE-01 — every new gate condition lands with a planted violation and a clean-pass
  case; a missed case is fixed in the gate, never deleted.
- ASSERT-01 — every scenario subprocess prints a sentinel; empty captures fail; and the
  sentinels carry counts (files scanned, chips found, entries listed) with a ≥ 1 floor,
  which also closes the PDX-003 ride-along finding that a well-formed report of zero
  checks reads as a pass.
- DEV-01 — the ticket's own AC-7; scenario 2 is the checklist's mechanical half and the
  report's Non-Scriptable Verification section covers what remains (whether the chip
  *reads* as a warning, screenshots attached).
- CR-01 — build and serve are local; nothing is deployed or announced.
- PLAN-01 — this plan names where volatile facts live (the built registry's entries, the
  corpus's arms, the current highest golden-case number) and lets scenarios derive them;
  the palette ratios quoted in §1 are computed from DESIGN.md constants, not from state
  that drifts.
- NOLLM-01 — new dependencies (astro, playwright, @astrojs/check) contain no blocklisted
  SDK; the gate re-checks on every verify.
- ST-02 — `site` is a registered package name.
- DEC-003 (the site is one of three renderings of the dataset), DEC-005 (no leaderboard;
  cited in DEC-015's rationale), DEC-006 (unmeasured listing deferred to PDX-012),
  DEC-012 (the install command pair renders the only supported source form), DEC-014
  (the card renders the tagged attribution, surfacing `curated` rather than flattening
  it).
- **Produced by this ticket**: DEC-015 (verdict conditions made computable: the priority
  order adopted from the chip table; the 3-vs-4 nominal-p boundary; condition 1 narrowed
  to what the records carry), DEC-016 (the DATA-01 gate discriminates by destination;
  the two legal figure sources), DEC-017 (status hues never carry text or glyphs; ink on
  tint, forced by measured contrast).

## 7. Test Plan (mandatory — TDD)

- **E2E scenario files** (the ticket's §5 mapping, names verbatim):
  - `tests/e2e/PDX-004-the-catalogue-reads.sh` — AC-1..AC-6 (markup half of AC-6), AC-8
  - `tests/e2e/PDX-004-the-catalogue-looks-right.sh` — AC-7 and the computed-style half
    of AC-6
  - One stated deviation from the ticket's grouping: AC-6 demands assertion "on computed
    style, not on the class name", and computed style does not exist outside a rendering
    engine — so AC-6 splits: scenario 1 asserts the null chip exists in markup with a
    non-empty label (not a dash, not an absence), scenario 2 asserts its computed weight.
    The review should confirm this split or demand the ticket's grouping amended.

- **RED condition** (before implementation; `./scripts/test-loop.sh PDX-004 --red` must
  show every assertion failing for the reason it names). On today's tree `@plugdex/data`
  exports no `verdictFor`, `packages/site` does not exist, `scripts/check-data.sh` does
  not exist, and Playwright is nowhere in the workspace — but `@plugdex/registry` builds
  and lists entries, so no assertion may treat "registry present" as proof of anything.
  Per AC:
  - AC-1 RED: `packages/site/dist/index.html` does not exist → FAIL "site not built".
    The name check reads pack names from the built registry first (sentinel, non-empty
    list required — that half is green-capable today, which is why it is a precondition
    read, not an assertion) and then requires each name in HTML that is not there.
  - AC-2 RED: the node block importing `verdictFor` from the built `@plugdex/data` gets
    no sentinel (export absent) → FAIL "verdictFor is not exported", not a silent pass on
    empty output.
  - AC-3 RED: the chip extraction over `dist/` finds zero chips, and the assertion
    requires ≥ 1 chip before it checks any of them → FAIL "no chips found". Phrasing it
    as "no chip lacks an n" alone would be vacuously green, which is the ASSERT-01 shape.
  - AC-4 RED: the scenario invokes `scripts/check-data.sh` against a planted fixture; the
    script does not exist, the invocation exits 127, and the failure message names
    "gate script missing or not executable" as the cause — failing for the true reason,
    per the standard PDX-003's round-3 ride-along set.
  - AC-5 RED: no `dist/` → the command-pair and upstream-URL greps have nothing to match
    → FAIL (positive-match assertions only).
  - AC-6 RED: zero chips with the null verdict found (≥ 1 floor) → FAIL.
  - AC-7 RED: scenario 2's preflight — Playwright importable from the site package —
    fails because the package does not exist → FAIL loudly at preflight, before any
    browser claim is made.
  - AC-8 RED: a positive grep of `verify.sh` for the DATA-01 step finds nothing → FAIL;
    and `check-gates.sh` scoped to the new case numbers reports no such cases.
- **GREEN condition**: `verify.sh` PASSes with the DATA-01 step executed;
  `check-gates.sh` catches all three planted DATA-01 violations, passes the clean-pass
  case, and fails the empty-scan tree; both scenarios PASS every assertion including the
  browser matrix; the full regression (`e2e.sh` with no argument) PASSes so PDX-001,
  PDX-002, and PDX-003 still hold.

- **Scenario 1 assertions** (each subprocess prints a sentinel; every count has a ≥ 1
  floor):
  - AC-1 — `dist/index.html` exists; every display name the built registry exports
    appears in the raw HTML (derived at runtime, never a hard-coded pack list); the dist
    tree contains no server directory or adapter entrypoint, so the output is static by
    inspection, not by configuration claim.
  - AC-2 — direct node calls to the built `verdictFor` with synthetic cell sets: one per
    verdict, the two-condition pack (asserting verdict 1 wins), the 3-vs-4 boundary both
    sides of the threshold, and the unmeasured empty set (asserting no rate fields
    exist to render). This duplicates the unit tests' spine deliberately: the unit tests
    prove the reasons, the scenario proves the built export a consumer sees.
  - AC-3 — every chip in the HTML whose text contains `%` also contains `n=` within the
    same chip element; chips found ≥ 1; and a synthetic-denominator unit test pins that
    n=3 renders as `n=3` rather than being rounded or dropped.
  - AC-5 — for every entry the built registry exports: both commands present, the
    install string carries `<packId>@plugdex`, and the entry's upstream repository value
    appears in the dialog markup (SRC-01 in the DOM, per the ticket).
  - AC-6 (markup half) — at least one chip carries the null-effect verdict, with a
    non-empty label.
  - AC-8 — positive grep: verify output (or a scoped run) shows the DATA-01 step
    executed and passing; `check-gates.sh` scoped to the new cases reports each caught /
    clean-passed as expected.

- **Scenario 2 assertions** (Chromium via Playwright; `astro preview` serves `dist/` on
  a scenario-owned port, killed on trap; matrix = {360×740, 1280×800} × {light, dark}
  via `colorScheme` emulation; every `page.evaluate` returns a JSON report printed with
  a sentinel):
  - No horizontal page scroll at 360px and desktop, both schemes:
    `document.documentElement.scrollWidth <= innerWidth`.
  - Shape carries the signal (SC 1.4.1): each rendered verdict class exhibits a distinct
    glyph in its chip's text content; the set of glyphs across chips has more than one
    member when more than one verdict renders.
  - Contrast (SC 1.4.3 / 1.4.11): for every chip and for body text, foreground vs
    effective background from `getComputedStyle` computes to ≥ 4.5:1; the install
    control's `:focus-visible` outline vs its adjacent background computes to ≥ 3:1
    (non-text, unrounded). Both floors are the fetched WCAG numbers, held in the
    scenario as named constants with the SC citation.
  - AC-6 (computed-style half): the null-effect chip's computed `opacity` is 1 and its
    `font-size`/`font-weight` equal a non-null chip's — the same visual weight, asserted
    on computed values, not class names.
  - Keyboard (AC-7): Tab from the document body reaches an install control within a
    bounded number of steps; Enter opens the dialog; the focused element is then inside
    the dialog; Escape closes it and focus returns to the trigger.
  - Screenshots: one per matrix combination written to
    `.docs/scratch/pdx-004-browser/`, asserted to exist with non-zero size, and
    referenced from the report's DEV-01 checklist.

- **Unit tests**: yes, two packages. `packages/data/src/verdict.test.ts` as in step 1 —
  the priority fold and the boundary are reasons-level properties the e2e can only
  observe, not explain. A small formatter test in `packages/site` pins the chip label
  shape (rate with n, digit-free captions), because that is the AC-3 contract the
  component owns.

## 8. Feature Tags

- `site` — cards, chips, install dialog; regression scenarios `PDX-004-*`
- `data` — `verdictFor` extends `@plugdex/data`'s public surface; a shape change there
  breaks this ticket's scenarios
- `harness` — a new verify step and five new golden cases affect every later ticket

## 8.5 References Consulted (REF-01)

Per DESIGN.md, Reference Map: PDX-004 requires `site-design` and `WCAG contrast`.

| Reference | Consulted | Note |
|---|---|---|
| site-design — cursor.directory | Y (2026-08-17) | WebFetch was bot-blocked (HTTP 429 / Vercel challenge, twice), so the page was opened in a real headless browser instead and read from the accessibility tree — stated because an unverified citation is the defect class this gate blocks. Observed: the card is rank + icon + name + one-line description + a single popularity count; the author, tags, full rule text, and the install action ("Add to Cursor" deep link + copyable rule block) all live behind the click, and no card anywhere carries any quality signal beyond popularity. Taken: the card grid and the per-entry copyable install pattern — and the confirmation of DESIGN.md §3/§4: the verdict and the author must be ON the card, which is exactly the surface cursor.directory leaves empty |
| site-design — Aider leaderboards | Y (2026-08-17) | Fetched. The main table is model / percent correct / cost / command; the test-case count (225) appears only inside per-row expandable detail panels, and no confidence information is shown. Taken by inversion: DESIGN.md credits Aider with "sample sizes printed next to every number", but the current page buries n behind a disclosure — so plugdex puts n on the chip itself (AC-3), taking the principle further than the reference now practices it |
| WCAG contrast | Y (2026-08-17) | Fetched all three Understanding pages. SC 1.4.3: ≥ 4.5:1 for normal text, ≥ 3:1 for large text (≥ 18pt, or 14pt bold). SC 1.4.11: ≥ 3:1 for UI components and graphical objects, explicitly unrounded (2.999:1 fails); inactive components exempt. SC 1.4.1: colour never the sole visual means; a 3:1 hue-plus-lightness difference is not a substitute where the user must identify which colour — which is why the glyphs are shapes, not tints. Held against the DESIGN.md §5 palette by computation: ink 17.23:1 / 15.44:1, pass 5.80 / 7.02, fail 5.75 / 5.73, accent 7.90 / 7.51 (light / dark, on their papers) all clear 4.5:1 — but `no code` at 2.10 / 2.51 fails both floors, which forced DEC-017 (hues as tint/border only; text and glyphs in ink) and the scenario-2 computed-contrast assertions |

## 9. Agent Review

Round 1 (Fable 5, 2026-08-17 19:30) returned **NEEDS_REVISION** with four blockers. Two
of them are findings about the project rather than about this plan, and both were verified
first-hand before being acted on.

### Reviewer
- Model: Fable 5 (claude-fable-5)
- Reviewed at: 2026-08-17 19:30

### Verdict
- [ ] APPROVED
- [ ] APPROVED_WITH_NOTES
- [x] NEEDS_REVISION

### Rubric

Every row must be scored PASS / FAIL / N/A with one line of concrete evidence.
Any FAIL row requires verdict NEEDS_REVISION (the gate rejects APPROVED + FAIL).

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | §2 confines work to the Allowed list; §3 steps and §7 cover AC-1..AC-8 individually; no leaderboard, drawer, cell grid, unmeasured listing or deploy appears in §3 |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | Counted per §3: steps 1, 2, 9 touch 3 files; 8 and 10 touch 2; the rest touch 1; each has its own gate or scenario assertion |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | FAIL | DEC-015 fires chip 3 at nominal uncorrected Fisher p < 0.05, while DEC-005's recorded ground is that the one nominal effect does not survive correction for four comparisons, and that the effect is regime-confined while regime is not a recorded field — DEC-015 pools regimes and publishes the uncorrected result per card |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | §7 names both scenario files verbatim from the ticket's §5 and gives a per-AC RED condition with its failure reason, plus a global GREEN including the both-sides golden replay and full regression |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | FAIL | §4 has no row for withdrawn-run contamination: `loadAcceptanceRecords` reads every `*.acceptance.json` (`packages/data/src/load.ts:206`), the withdrawn run contributes 74 valid cells, and no `withdrawn` marker exists in the schema or the loader |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | Hangul scan over the plan and ticket found none; `./scripts/check-language.sh` passes |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `./scripts/check-references.sh .docs/analysis/PDX-004_plan.md` → "REF-01 PASS — all 2 required reference(s) consulted"; the §8.5 notes carry specifics that cannot be summarised without opening the material, and every WCAG ratio quoted was independently recomputed and matched |

### Comments
1. CR-01 acknowledged and complied with: the review was read-only — no file edited, no git
   mutation, nothing created, and no commit or push recommended. LANG-01 acknowledged: the
   review is in English and the artifacts carry no Korean.
2. **DEC-017 is verified and approved.** Every contrast ratio was recomputed from the
   DESIGN.md §5 hex values with the WCAG relative-luminance formula: `#B3ADA0` on `#FAF8F3`
   = 2.1045 and `#5A554C` on `#141311` = 2.5097, matching the plan's 2.10 and 2.51, as do
   the other eight ratios. The conclusion — status hues never carry text or the load-bearing
   glyph — is forced by the arithmetic rather than asserted, and scenario 2's computed-contrast
   assertion makes it regression-proof.
3. **Verdict 2's dead branch is acceptable as disclosed, with one condition:** the phase-C
   hand-off must state that the `claims` input's confidence interval has to arrive as a
   fingerprinted record rather than a caller-computed value, or verdict 2 becomes a
   laundering path for the statistic class B1 objects to.
4. **The AC-6 split is approved as a disclosed deviation, not scope drift** — AC-6 demands
   an assertion on computed style, which cannot exist outside a rendering engine, so the
   split covers the AC more completely than the ticket's grouping. The ticket's §5 mapping
   must be amended in the same change, per the precedent PDX-003 round 3 set.
5. DEC-016's threat model is right in principle — the gate's job is the honest mistake, and
   false positives are what kill a gate like this. The blockers against it are about its
   substrate and its golden-case coverage, not the design stance.
6. PLAN-01 and ASSERT-01 hygiene is genuinely good: no golden-case numbers hard-coded, pack
   lists derived at runtime, every count with a ≥ 1 floor, and the empty scan fails.

### Blockers (only if NEEDS_REVISION)
- **B1 (P3 FAIL) — DEC-015's uncorrected-p boundary republishes, per card, the claim the
  project retracted.** On the corpus DESIGN.md records, a nominal p < 0.05 trigger fires for
  exactly one pack, so the landing page renders one rate chip and four "no detectable effect"
  chips — a binary significance ranking driven by the number DESIGN.md itself says does not
  survive correction for four tests. It is also an un-derived statistic (`bench/DERIVATIONS.md`
  requires an entry for every published statistical claim, and a p computed inside `verdictFor`
  has none), it is outside every preregistration (which fixes the analysis in advance and rules
  that the two regimes are never merged), and it needs a second Fisher implementation in
  TypeScript that can drift from the self-validating one in `bench/harness/fisher.py`.
  **Replacement:** make the 3-vs-4 boundary descriptive rather than inferential.
- **B2 (P5 FAIL) — every live number `verdictFor` would compute is contaminated by the
  withdrawn run, and the plan never mentions it.** See §9.1 below: verified, and escalated
  out of this ticket.
- **B3 (DEC-016) — the rendered-position scanner's substrate does not resolve, and the golden
  set does not cover both sides of every stated rule.** `@astrojs/compiler` is a transitive
  dependency and this repository has no `.npmrc`, so pnpm's default isolated linker leaves it
  unresolvable from `scripts/`; it must be declared and pinned. And four stated rules land with
  neither a planted violation nor a clean pass: reader-facing attributes, digit-bearing string
  literals in code positions, expression literals in the template body, and the element-access
  allowance. §6 claims GATE-01 coverage the plan does not deliver.
- **B4 — ticket revision needed**, regardless of the plan verdict: §5's e2e mapping must
  reflect the approved AC-6 split, and the scope question B2 raises must be settled.

### 9.1 What round 1 found that is not about this plan

Two blockers were verified against the artifacts before any action was taken.

**B2 is a defect in the shipped data package, not a gap in this plan.** Confirmed
first-hand: `packages/data/src/load.ts:206` reads every `*.acceptance.json` in the runs
directory; `bench/data/runs/20260815-225842-frontend-withdrawn-different-prompt.acceptance.json`
holds 76 cells of which 74 are valid; and `grep -rn withdrawn packages/data/src/` returns
nothing — no schema field, no loader branch. The withdrawal exists only in the filename.

The two halves of the project therefore disagree. `bench/harness/fisher.py:74` excludes the
run by filename prefix, and every figure in `bench/README.md` and `bench/DERIVATIONS.md` is
computed on the excluded pool; the TypeScript loader that would feed the site includes it.
D-001 records what that difference is worth — ponytail's p moves from 0.0352 to 0.0055 when
the withdrawn run is pooled, and D-002's superpowers count moves from 49/50 to 64/65 — so
the card would print a denominator contradicting the corrected table the repository
publishes under CLAIM-01.

It is also the same shape as DEC-005's second ground: a fact that governs the analysis
living in a filename rather than in the record. The project has now made that mistake twice,
and caught it the second time only because a reviewer read the loader.

This is out of PDX-004's Scope.Allowed and is not a site problem, so it is **escalated to its
own ticket rather than folded in**. PDX-004 resumes against a corpus whose exclusions are
recorded, and this plan's revision (round 2) assumes that mechanism exists rather than
inventing one inside a UI ticket.

## 10. Final Plan Status

- Agent: _(pending)_
- Human: _(pending)_
