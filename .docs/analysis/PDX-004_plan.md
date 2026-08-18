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
  DEC-017 below commit to the discrimination mechanism concretely rather than promising
  one.

Two facts found while planning shape the design and are recorded here so the review can
check them rather than discover them:

- **DESIGN.md fixes the verdict priority order but not the 3-vs-4 boundary.** The chip
  table ("The one design decision still open") carries an explicit Priority column, so
  the ordering 1→5 is given. But conditions 3 ("produces code; the pass rate over its
  code-producing cells") and 4 ("produces code, but no metric differs significantly from
  baseline") are both true of every code-producing pack as written, and their example
  columns contradict each other ("ponytail and the rest" vs "the honest default for most
  packs"). As written, priority 4 is unreachable. This ticket must settle it — and DEC-016
  below settles it by striking verdict 4 rather than by inventing the boundary, because
  every boundary that makes 4 reachable is an inferential claim this corpus cannot support
  per pack. The chip table sits under DESIGN.md's own "one design decision still open"
  heading, so answering it is what this ticket was for; answering it with a strike is the
  part round 1 forced.
- **The palette's `no code` colour fails WCAG in both schemes.** Computed against the
  DESIGN.md §5 values: `#B3ADA0` on `#FAF8F3` is 2.10:1 and `#5A554C` on `#141311` is
  2.51:1 — below the 4.5:1 text floor (SC 1.4.3) and below the 3:1 non-text floor
  (SC 1.4.11, which is explicitly unrounded). So status hues cannot carry text or the
  load-bearing glyph anywhere on this site. DEC-018 below rules the application: chip
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
    tested synthetically, because the function must be total over every verdict it can
    return, but
    PDX-012 owns putting a queue on the page.
  - Nothing deployed, purchased, or announced (CR-01). The site builds and is served
    locally by the e2e; that is all.

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | Verdict types and the pure function | `packages/data/src/verdict.ts`, `packages/data/src/verdict.test.ts`, `packages/data/src/index.ts` | `verdictFor = ({ packId, cells, claims })` folding the surviving conditions in priority order, first match wins. **No statistic is computed here** — DEC-016 retires the 3-vs-4 boundary, so there is no p, no threshold, and no second Fisher implementation in TypeScript. Verdict 3 carries the pack's numerator and denominator *and* baseline's, both read off the same corpus; there is no precomputed percentage field anywhere in the union, so a chip cannot render a rate without also holding its n (AC-3 by construction). The one threshold that remains is the 0.8 no-code fraction from the DESIGN.md chip table, with its cited rationale comment. Unit tests run against synthetic cells: each surviving verdict, the two-condition pack (verdict 1 wins), n=3 preserved, an arm at or below baseline and one above it both returning verdict 3 with the two pairs of counts intact, and the empty arm returning verdict 5. The `index.ts` docstring is corrected as described in §1 |
| 2 | Scaffold the site package | `packages/site/package.json`, `packages/site/tsconfig.json`, `packages/site/astro.config.mjs` | `@plugdex/site`: Astro, static output, no adapter, workspace deps on `@plugdex/data` and `@plugdex/registry`; the script set `verify.sh`'s recursive pnpm steps expect (`typecheck` via `astro check`, `lint` covered by root config, `test`, `build`). `playwright`, `@astrojs/check`, and `@astrojs/compiler` as devDependencies — Playwright is not currently anywhere in the workspace (no hit in the root manifest or `pnpm-lock.yaml`), so AC-7 requires adding it here, scoped to the site package. `@astrojs/compiler` is pinned exactly (no range): the DATA-01 gate parses with it, and an AST shape that shifts under a caret is a gate that changes verdict without a diff |
| 3 | Theme | `packages/site/src/styles/global.css` | DESIGN.md §5 as custom properties: light palette on `:root`, dark under `prefers-color-scheme: dark`; `font-variant-numeric: tabular-nums` wherever a digit can appear; 66–72ch body measure; the paper/terminal split. Status hues defined as tint/border tokens only, per DEC-018 |
| 4 | The verdict chip | `packages/site/src/components/VerdictChip.astro` | Renders a verdict object: shape glyph + label + `n=` from the object's own fields. Glyph and text in ink; hue as background tint and border (DEC-018), so the null-result chip has identical computed weight to every other (AC-6). Static caption strings are digit-free — any figure in a chip is a rendered field of the verdict object |
| 5 | The pack card | `packages/site/src/components/PackCard.astro` | Name, author (the tagged `Attributed` value — rendering what DEC-014 stores, with the `curated` tag surfaced, not flattened to a bare string), stars with their `readAt`, one line, chip, install button |
| 6 | The install dialog | `packages/site/src/components/InstallDialog.astro` | Native `<dialog>` plus a few lines of inline vanilla script for open/copy — a copy button does not earn a React island, so this ticket ships zero framework runtime (static-first rule applied, not a new decision). Contents: the two commands (`claude plugin marketplace add …`, `claude plugin install <packId>@plugdex`), a copy control per command, and a line naming the upstream repository the install will actually clone from — SRC-01 rendered (AC-5). `<dialog>` gives keyboard reachability, focus containment, and Escape natively (AC-7) |
| 7 | The page | `packages/site/src/pages/index.astro` | Frontmatter loads the corpus, iterates the built registry's entries, calls `verdictFor` per pack, renders the grid alphabetically. Every name and every chip is in the emitted HTML — no client JS on the read path (AC-1) |
| 8 | The DATA-01 gate | `scripts/check-data.sh`, `scripts/verify.sh` | The mechanism of DEC-017 (below), on the `check-src.sh` model: bash wrapper, inline node scanner, `SENTINEL` line carrying `{files, literals, bad}`, and a scan of zero files is a FAIL — closing in advance the PDX-003 finding-1 class where a well-formed report of zero work reads as a pass. One new verify step; the e2e asserts the step by a positive grep of verify output, not by its number (PLAN-01) |
| 9 | Golden cases — the blocked side | `tests/meta/cases/` (6 files) | One planted violation per stated rule, so §6 stops claiming GATE-01 coverage this plan does not deliver. Round 1 found four rules landing with neither a violation nor a clean pass; all four are here. (a) `const buildRate = 47` in a planted component's frontmatter — code position, numeric literal; (b) `47% builds` as template text — rendered position, text node; (c) `content: "47%"` in CSS — the one path by which a stylesheet can state a claim; (d) `alt="47% builds"` — **reader-facing attribute**, the case that separates scanner 2's attribute allowlist from its blocklist; (e) `const caption = 'builds 47% of the time'` in frontmatter — **digit-bearing string literal in a code position**, which scanner 1 blocks and which a numeric-literal-only scanner would miss; (f) `<p>{'47% builds'}</p>` — **an expression literal in the template body**, the shape that routes a digit through markup without a text node. Each asserts the DATA-01 pattern, numbered after the current highest case |
| 10 | Golden cases — the clean-pass side and the empty scan | `tests/meta/cases/` (2 files) | Clean-pass (`EXPECT_PASS=1`), one planted legal use per allowance so the exemptions are proven rather than assumed: `gridColumns = 3` (layout-vocabulary name), `z-index: 10` in a style block, `viewBox="0 0 24 24"` and `tabindex="0"` (machine-facing attributes), `content: "→"` (a digit-free `content`, so the CSS rule is shown to block on the digit rather than on the property), and **`cells[3]` plus `slice(0, 2)` — the element-access allowance**, the fourth rule round 1 found uncovered. The gate must flag none of them, because false positives are how this gate dies. And an empty-scan case: a tree with no site sources must FAIL the gate ("scanned nothing"), not pass it (ASSERT-01) |
| 11 | Scenario 1 | `tests/e2e/PDX-004-the-catalogue-reads.sh` | AC-1..AC-6 (markup half of AC-6), AC-8, over built output — assertions in §7 |
| 12 | Scenario 2 | `tests/e2e/PDX-004-the-catalogue-looks-right.sh` | AC-7 and the computed-style half of AC-6: real Chromium via Playwright, both viewports, both schemes, keyboard walk, contrast computed from `getComputedStyle`, screenshots to `.docs/scratch/pdx-004-browser/` |
| 13 | Decision log and the chip table | `DESIGN.md` | DEC-016, DEC-017, DEC-018 rows; the "still open" chip section gains a pointer to DEC-016 so the document stops carrying an open question it has answered; and **verdict 4's row is struck from the chip table** with DEC-016 named as the reason, so the table and the code agree about what the site can say |

### The verdict function (AC-2)

The verdicts and their priority order come from DESIGN.md's chip table: 1 `produces no
code unattended`, 2 `published claim not reproduced`, 3 `N% builds`, 5 `unmeasured`.
Conditions are evaluated in that order and the first match wins. **Verdict 4
(`no detectable effect`) is struck** — the boundary bullet below is the argument, and
DEC-016 is where the strike is recorded. The remaining numbers keep their original
values rather than being closed up, so a reader comparing this plan against the design
document sees a gap where a chip was removed instead of a silent renumbering.

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
  records hold, and DEC-016 records that narrowing rather than letting the chip imply a
  field that does not exist.
- **Condition 2 takes its inputs as data, and no live pack can currently trigger it.**
  The claimed figure and the metric it is about (tokens, for the known case) live only in
  `results.json`, which carries no fingerprint and is outside `@plugdex/data` — the
  contradiction PDX-002 §5 named and deferred. `verdictFor` therefore accepts an optional
  `claims` input and implements the branch fully, unit-tested against synthetic claims;
  on the live corpus the parameter is empty and the pack in question falls through to 3. Hand-typing the CI to make the chip appear would be the exact violation this
  ticket exists to gate, so the branch waits for the ticket that brings the claims record
  under DATA-01 (phase C). Stated as a limit, inherited explicitly.
  **The condition round 1 attached to approving this dead branch, carried here so the
  phase-C ticket inherits it:** the `claims` input's confidence interval must arrive as a
  fingerprinted record, never as a value a caller computed and passed in. Without that,
  verdict 2 is a laundering path for exactly the statistic class this revision just
  removed from verdict 3 — a caller could compute an interval by any method, hand it to
  `verdictFor`, and have the site publish "published claim not reproduced" with no
  derivation behind it. The phase-C ticket's AC must state it; this plan records it so the
  requirement does not depend on someone remembering the review.
- **The 3-vs-4 boundary is retired, not moved (DEC-016, produced by this ticket).**
  Round 1 killed the nominal-p boundary and asked for a descriptive one. There is no
  descriptive boundary between "N% builds" and "no detectable effect", because the second
  chip is not a description — it is an inference, and it is the one inference this corpus
  cannot support per pack. So the boundary goes away with the chip.

  **What renders instead:** every arm with at least one valid code-producing cell gets
  chip 3, and chip 3 carries **two** rates — the pack's build rate with its denominator
  and baseline's rate with its denominator, side by side. No comparison is asserted, no
  ordering is implied, and `verdictFor` computes no statistic.

  **Why moving the threshold does not work either.** Keeping chip 4 and firing it at the
  corrected threshold rather than the nominal one looks like the conservative fix and is
  worse. DESIGN.md computes the Bonferroni threshold for four pack-vs-baseline tests at
  0.0125 and records ponytail at p = 0.0352 on the published pool — so at the corrected
  threshold *every* card reads "no detectable effect", which is a far stronger negative
  claim than four tests at n ≈ 35 can carry. Absence of evidence rendered as a chip is
  still a claim. And either threshold needs a second Fisher implementation in TypeScript
  that can drift from the self-validating one in `bench/harness/fisher.py`, with no
  `bench/DERIVATIONS.md` entry behind it and no preregistration covering it.

  **What the reader loses and gains.** They lose a chip that told them whether a
  difference was real; they were never entitled to it, and DESIGN.md says so in its own
  Bonferroni line. They gain both denominators on the card, which is what lets a reader
  see for themselves that 22/36 against 12/34 is worth a second look while 11/35 against
  12/34 is not. The card publishes counts. Counts are what the records hold.

  **Consequences this revision carries, rather than leaves for implementation:**
  - DESIGN.md's chip table loses verdict 4. The row is struck in the decision log with its
    reason, not silently deleted — the same treatment a withdrawn figure gets under
    CLAIM-01, because a chip the design once specified is a claim about what the site
    would say.
  - **AC-6 loses its subject and is retargeted.** Its intent — a bad result is styled as a
    result, not as a greyed-out absence — survives intact; only the way the scenario finds
    the chip changes. AC-6 now targets the chip whose measured rate is **at or below
    baseline's**, located at runtime by comparing the two rendered rates, with the
    scenario failing loudly if no such chip exists rather than assuming a pack-to-verdict
    table that would go stale (PLAN-01). On the corpus DESIGN.md records, caveman at
    11/35 against baseline 12/34 is such a chip; the scenario derives it rather than
    naming it. The ticket amendment is in §9.2.
- **Condition 5** is the empty case: no cells for the packId. It renders a chip with a
  label and no rate — the edge case list's "must not render `0%`" falls out of the union
  shape, because the unmeasured member simply has no numerator/denominator fields to
  render.

### The DATA-01 discrimination mechanism (AC-4, DEC-017)

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
   `parse`. **Declared and pinned as a devDependency of `packages/site`, not inherited.**
   Round 1 caught this: `@astrojs/compiler` reaches the tree only as a transitive
   dependency of Astro, and this repository has no `.npmrc`, so pnpm's default isolated
   linker leaves it unresolvable from `scripts/`. A gate that imports a package nobody
   declared is a gate that stops working on the next `pnpm install`, silently, in the
   direction of passing. The version is pinned exactly rather than ranged, because the
   parser's AST shape is the gate's contract. A digit in a text node, in an expression's
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

Two legal figure sources, recorded in DEC-017: values imported from `@plugdex/data`
(measurement figures) and from `@plugdex/registry` (star counts and provenance fields,
each carrying its SRC-01g retrieval receipt and `readAt`). The card renders stars, which
are numbers, and they are legal for the same reason the measurement figures are: they
arrive as imports from a package whose records carry receipts, and no literal for them
exists in site source. The gate needs no special case for this — it blocks literals, and
imports are not literals — but the rule text of DATA-01 says "a record in
`packages/data`", so DEC-017 states the interpretation rather than leaving the gate and
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
- **Rendering two rates side by side could be read as reintroducing a ranking** → no
  view sorts by verdict, the landing order is alphabetical, and no cross-pack ordering is
  computed anywhere: each card compares one arm against baseline, which is the comparison
  the experiment was designed to support. What the card states is two counts with two
  denominators. **The live risk is stylistic, not structural, and it rides to the report
  under DEV-01**: the two rates must carry identical, non-comparative styling. A hue, a
  weight, or an arrow keyed to which rate is larger would put the significance claim back
  on the card through the stylesheet, having just removed it from the code. Scenario 2
  asserts the two rates' computed `font-weight` and `color` are equal, not an order. DEC-005 is cited in the DEC-016 rationale so the tension is ruled,
  not latent.
- **Verdict 2 is dead code on live data** → deliberate, stated in §3, and inherited from
  PDX-002 §5's record-universe contradiction rather than created here. The branch is
  fully unit-tested against synthetic claims; the alternative — hand-typing the one known
  CI — is the violation the ticket gates.
- **The palette's `no code` value fails both WCAG floors** → measured during planning
  (2.10:1 light, 2.51:1 dark), so the design never puts text or the load-bearing glyph
  in a status hue (DEC-018), and scenario 2 asserts computed contrast in the real
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
  cited in DEC-016's rationale), DEC-006 (unmeasured listing deferred to PDX-012),
  DEC-012 (the install command pair renders the only supported source form), DEC-014
  (the card renders the tagged attribution, surfacing `curated` rather than flattening
  it).
- **Produced by this ticket**: DEC-016 (verdict conditions made computable: the priority
  order adopted from the chip table; verdict 4 retired and the card rendering both rates
  with both denominators instead; condition 1 narrowed to what the records carry),
  DEC-017 (the DATA-01 gate discriminates by destination; the two legal figure sources),
  DEC-018 (status hues never carry text or glyphs; ink on tint, forced by measured
  contrast). The numbers moved up one from round 1's draft: DEC-015 was allocated by
  PDX-016 at landing, because the log allocates when a decision lands and a plan proposes
  rather than reserves.

## 7. Test Plan (mandatory — TDD)

- **E2E scenario files** (the ticket's §5 mapping, names verbatim):
  - `tests/e2e/PDX-004-the-catalogue-reads.sh` — AC-1..AC-6 (markup half of AC-6), AC-8
  - `tests/e2e/PDX-004-the-catalogue-looks-right.sh` — AC-7 and the computed-style half
    of AC-6
  - One stated deviation from the ticket's grouping, **approved at round 1 and now
    carried into the ticket** (§9.2): AC-6 demands assertion "on computed style, not on
    the class name", and computed style does not exist outside a rendering engine — so
    AC-6 splits: scenario 1 asserts the at-or-below-baseline chip exists in markup with a
    non-empty label (not a dash, not an absence), scenario 2 asserts its computed weight.
    Both halves locate the chip by comparing the two rendered rates at runtime, never by
    a pack name (PLAN-01), and both fail loudly if no such chip exists.

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
  - AC-6 RED: zero chips whose rendered pack rate is at or below their rendered baseline
    rate (≥ 1 floor) → FAIL. Nothing renders at all before implementation, so the search
    comes back empty and the floor is what turns that into a failure rather than a
    vacuous pass (ASSERT-01).
  - AC-7 RED: scenario 2's preflight — Playwright importable from the site package —
    fails because the package does not exist → FAIL loudly at preflight, before any
    browser claim is made.
  - AC-8 RED: a positive grep of `verify.sh` for the DATA-01 step finds nothing → FAIL;
    and `check-gates.sh` scoped to the new case numbers reports no such cases.
- **GREEN condition**: `verify.sh` PASSes with the DATA-01 step executed;
  `check-gates.sh` catches every planted DATA-01 violation from step 9 (one per stated
  rule), passes the clean-pass
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
    verdict, the two-condition pack (asserting verdict 1 wins), an arm at or below
    baseline and one above it both returning verdict 3 with both pairs of counts, both
    sides of the threshold, and the unmeasured empty set (asserting no rate fields
    exist to render). This duplicates the unit tests' spine deliberately: the unit tests
    prove the reasons, the scenario proves the built export a consumer sees.
  - AC-3 — every chip in the HTML whose text contains `%` also contains `n=` within the
    same chip element; chips found ≥ 1; and a synthetic-denominator unit test pins that
    n=3 renders as `n=3` rather than being rounded or dropped.
  - AC-5 — for every entry the built registry exports: both commands present, the
    install string carries `<packId>@plugdex`, and the entry's upstream repository value
    appears in the dialog markup (SRC-01 in the DOM, per the ticket).
  - AC-6 (markup half) — the chip whose rendered pack rate is at or below its rendered
    baseline rate exists and carries a non-empty label (not a dash, not an absence). The
    chip is located by comparing the two rates the card renders, derived at runtime; the
    assertion fails loudly if no such chip exists, rather than passing on an empty search
    (ASSERT-01) or naming a pack that could move (PLAN-01).
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
  - The two rates within a card are styled identically (DEC-016's live risk, raised at
    plan review round 2): for every card, the pack rate element and the baseline rate
    element have equal computed `font-weight`, `color`, and `font-size`, and neither
    carries a hue or a glyph the other does not. A comparison removed from the code and
    reintroduced through the stylesheet is the same claim by another route, so this is
    asserted rather than trusted, on computed values.
  - AC-6 (computed-style half): the at-or-below-baseline chip's computed `opacity` is 1
    and its `font-size`/`font-weight` equal those of a chip whose rate is above baseline —
    the same visual weight, asserted on computed values, not class names. A result that
    disappoints is still a result, and the styling is what says so.
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
- `harness` — a new verify step and the step 9-10 golden cases affect every later ticket

## 8.5 References Consulted (REF-01)

Per DESIGN.md, Reference Map: PDX-004 requires `site-design` and `WCAG contrast`.

| Reference | Consulted | Note |
|---|---|---|
| site-design — cursor.directory | Y (2026-08-17) | WebFetch was bot-blocked (HTTP 429 / Vercel challenge, twice), so the page was opened in a real headless browser instead and read from the accessibility tree — stated because an unverified citation is the defect class this gate blocks. Observed: the card is rank + icon + name + one-line description + a single popularity count; the author, tags, full rule text, and the install action ("Add to Cursor" deep link + copyable rule block) all live behind the click, and no card anywhere carries any quality signal beyond popularity. Taken: the card grid and the per-entry copyable install pattern — and the confirmation of DESIGN.md §3/§4: the verdict and the author must be ON the card, which is exactly the surface cursor.directory leaves empty |
| site-design — Aider leaderboards | Y (2026-08-17) | Fetched. The main table is model / percent correct / cost / command; the test-case count (225) appears only inside per-row expandable detail panels, and no confidence information is shown. Taken by inversion: DESIGN.md credits Aider with "sample sizes printed next to every number", but the current page buries n behind a disclosure — so plugdex puts n on the chip itself (AC-3), taking the principle further than the reference now practices it |
| WCAG contrast | Y (2026-08-17) | Fetched all three Understanding pages. SC 1.4.3: ≥ 4.5:1 for normal text, ≥ 3:1 for large text (≥ 18pt, or 14pt bold). SC 1.4.11: ≥ 3:1 for UI components and graphical objects, explicitly unrounded (2.999:1 fails); inactive components exempt. SC 1.4.1: colour never the sole visual means; a 3:1 hue-plus-lightness difference is not a substitute where the user must identify which colour — which is why the glyphs are shapes, not tints. Held against the DESIGN.md §5 palette by computation: ink 17.23:1 / 15.44:1, pass 5.80 / 7.02, fail 5.75 / 5.73, accent 7.90 / 7.51 (light / dark, on their papers) all clear 4.5:1 — but `no code` at 2.10 / 2.51 fails both floors, which forced DEC-018 (hues as tint/border only; text and glyphs in ink) and the scenario-2 computed-contrast assertions |

## 9. Agent Review

Round 1 (Fable 5, 2026-08-17 19:30) returned **NEEDS_REVISION** with four blockers. Two
of them are findings about the project rather than about this plan, and both were verified
first-hand before being acted on.

Round 1's review is kept verbatim below as the historical record, followed by rounds 2
and 3. The three verdicts in order: **NEEDS_REVISION** (four blockers, all design),
**NEEDS_REVISION** (no new defect — round 1's B1 fix propagated to the argument but not to
the instructions), **APPROVED_WITH_NOTES** (the sweep confirmed, 0 blockers, three notes,
two applied here and one owed to the report).

### Reviewer
- Model: Fable 5
- Reviewed at: 2026-08-18 00:04 (round 3; round 2 at 2026-08-17 23:50, round 1 earlier)

### Verdict
- [x] APPROVED_WITH_NOTES

### Rubric
| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Goal and scope | PASS | Outside round 3's sweep except the B4 residue — carried from round 2; the residue itself is closed: ticket AC-2 now reads "one of the verdicts the chip table defines" with the CLAIM-01 correction record naming the old "five" text |
| P2 | Steps | PASS | Both cited spots closed: step 1 now states "No statistic is computed here — DEC-016 retires the 3-vs-4 boundary, so there is no p, no threshold, and no second Fisher implementation", its only surviving threshold is the 0.8 no-code fraction, and its unit list tests at/below- and above-baseline arms "both returning verdict 3"; step 13 strikes verdict 4's row from the chip table |
| P3 | Design soundness | PASS | All three cited contradictions closed: step 1, the DEC-016 bullet arguing the retirement, and the risk row rewritten around two counts with identical styling — no "caption states nominal-only" argument survives; DEC-016/017/018 mutually consistent; one inert prose residue found and carried as note 3 |
| P4 | Test plan | PASS | All four cited spots closed: AC-6 RED targets the at-or-below-baseline chip with the ≥ 1 floor and states why an empty search fails; scenario-1 AC-2 asserts both arms returning verdict 3, no 3-vs-4 language; GREEN counts are phrased against the producing steps — "every planted DATA-01 violation from step 9 (one per stated rule)" — and no "five new golden cases" or "all three planted violations" text survives anywhere |
| P5 | Risks | PASS | Carried from round 2 (B2 closed by PDX-016, §9.1); the one risk row in the sweep is rewritten and now carries round-2 comment 2's residual styling risk with an enforcement mechanism, not just a statement |
| P6 | Rules/decisions applied | PASS | Carried from round 2 — §6 is outside the sweep and unchanged in substance; DEC-016's §6 entry now matches the strike ("verdict 4 retired and the card rendering both rates with both denominators"), so §6 agrees with §3 |
| P7 | REF-01 | PASS | `./scripts/check-references.sh .docs/analysis/PDX-004_plan.md` re-run at round 3 → "REF-01 PASS — all 2 required reference(s) consulted for PDX-004"; §8.5 notes unchanged since round 1 verification |

### Comments
1. CR-01 complied with: read-only review — no file edited, no git mutation, no commit or push recommended. LANG-01 complied with: review in English; `./scripts/check-language.sh` passes and a direct Hangul grep over the plan and ticket found none.
2. **Round-2 comment 2's residual risk is carried and enforced, with one placement gap.** The risk row states the requirement — identical, non-comparative styling for the two rates, no hue/weight/arrow keyed to which is larger — and specifies an assertion. That is enforcement, not mere statement. However, §7's scenario-2 assertion list did not enumerate it — its AC-6 half compares chip against chip, not the two rates within a card. Since §7 is what stage 4 builds the scenario from, the test-case-first stage must include the two-rates equality assertion; the report's review should confirm it landed. **Applied** — §7's scenario-2 list now carries the assertion explicitly.
3. **One sweep survivor, inert.** The condition-2 bullet read "the pack in question falls through to 3 **or 4**" — a phrase assuming verdict 4 is reachable. Not a blocker by round 2's own corruption test: no condition for verdict 4 exists anywhere an implementer builds from, so nothing in `verdict.ts` or the RED gate can inherit it. The fix is deleting two words, a prose correction of exactly the class REV-02 routes to the report stage; a fourth review round over two words would be the PDX-002 rounds-3/4 failure mode the rule exists to prevent. **Applied here rather than deferred**, since the sweep was open anyway.
4. Scenario-1's "both sides of the threshold" is closed as cited — the "3-vs-4 boundary" language is gone, and with step 1 declaring the 0.8 no-code fraction "the one threshold that remains", the phrase can only refer to that boundary, which is a legitimate and useful test. Minor: step 1's unit list does not name a matching both-sides case even though the scenario claims to duplicate the unit spine; worth mirroring when the tests are written, no plan change needed.
5. **§9.3's account is honest.** It reproduces round 2's findings without minimizing and calls the state "the worst possible half-state" in its own voice. Its REV-02 justification is the strongest available reading and correctly scoped. One obligation remains open by the rule's own text ("the report must say why"): **the PDX-004 report must carry this third-round justification, not only the plan.**
6. Beyond the survivor in comment 3, the grep sweep for verdict-4 / p-threshold assumptions across the plan and the ticket hit only the permitted passages, including the historical round-1 review text in §9, which is correctly left unedited. The ticket's two CLAIM-01 corrections (AC-2 and AC-6) both preserve the old wording with the reason — corrections in place, not rewrites, as B4 required. No genuinely new blocker was found.

### Blockers (only if NEEDS_REVISION)
- None at round 3. Round 1's four and round 2's four are all closed; three notes, two applied above, one owed to the report.

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

**Status at round 2: the mechanism exists.** PDX-016 has landed — the withdrawal is a
field on the record, `loadAcceptanceRecords` excludes it by default and lists it under
`withdrawnRecords`, and the DATA-02 gate blocks its reintroduction. Both implementations
now report the same corpus, which is what this plan needed and did not have: the loader
`verdictFor` reads answers 371 cells and 283 valid, matching every published figure,
where at round 1 it answered 447 and 357. The counts are not restated here as prose to be
trusted — `bench/DERIVATIONS.md` D-003 records them with the command that reproduces both,
and PDX-016's scenario asserts the agreement on every run.

### 9.2 What round 2 changed

Four blockers, each closed in the plan rather than deferred to implementation.

- **B1 — the verdict boundary.** Round 1 asked for a descriptive boundary; round 2
  concluded there is no descriptive boundary to be had, because verdict 4 is not a
  description. The chip is struck and the card renders both rates with both denominators
  instead. This is a larger change than "replace the threshold", and it is deliberately
  larger: moving the threshold to the corrected value would have made every card assert a
  negative result, which is a stronger claim than the corpus supports, not a weaker one.
  The consequences — DESIGN.md's chip table, AC-6's target, the ticket's §5 mapping — are
  carried in this revision rather than discovered during implementation.
- **B2 — the contaminated corpus.** Closed outside this plan by PDX-016, as round 1
  directed. See the paragraph above.
- **B3 — the scanner's substrate and its coverage.** `@astrojs/compiler` is now a declared,
  exactly-pinned devDependency of `packages/site` rather than a transitive package the
  gate hoped to reach. And the four rules round 1 found landing with neither a planted
  violation nor a clean pass — reader-facing attributes, digit-bearing string literals in
  code positions, expression literals in the template body, and the element-access
  allowance — now have cases on the side each needs, which is what §6's GATE-01 claim
  requires to be true.
- **B4 — ticket revision.** `.docs/tickets/PDX-004_site-catalogue-cards-verdicts-and-install.md`
  is amended in the same change, per the precedent PDX-003 round 3 set: AC-6 is retargeted
  at the at-or-below-baseline chip (its intent unchanged — a bad result is styled as a
  result), and §5's e2e mapping reflects the approved AC-6 split across the two scenarios.
  Both amendments are corrections in place with the reason stated, not rewrites.

One thing round 1 approved is carried rather than changed: verdict 2's dead branch stays,
with the condition attached to its approval now written into the plan (§3, condition 2) so
the phase-C ticket inherits it instead of depending on someone remembering the review.

### 9.3 What round 2's review caught, and the scoped third round

Round 2 returned NEEDS_REVISION. It approved every design answer — B1's strike on the
merits, B2 closed and verified first-hand against the shipped loader, B3's declared
compiler and discriminating cases, B4's amendments as honest corrections — and then found
that **the strike had been applied to the argument and not to the instructions**. The
Steps table still told an implementer to put a 0.05 nominal p into `verdict.ts` and to
unit-test the boundary either side of it; the Test Plan still red-tested "chips with the
null verdict"; a risk row still argued from a caption stating nominal-only status; and two
golden-case counts still said three and five against steps 9-10's six and eight. The
ticket's AC-2 still said "one of the five verdicts".

That is the worst possible half-state, and the review named why: a plan that strikes a chip
in one section and renders it in another is worse than one that kept it, because the Steps
table and §7 are what the implementation and the RED gate are built *from*. By report time
either `verdict.ts` would carry the retracted statistic or the scenario would assert a
boundary that does not exist.

Every cited line is now swept — §1's framing, step 1, the risk row, the RED and GREEN
conditions, the unit assertions, both counts, and the ticket's AC-2. Two things were
strengthened rather than merely corrected while sweeping: the AC-6 RED now states why an
empty search fails instead of passing (ASSERT-01), and the counts are phrased against the
steps that produce them rather than restated as numbers that can drift (PLAN-01).

**On REV-02.** The cap is two rounds, and this is a third. It is taken under the exception
the rule states, and the reason is the one round 2 gave: the finding is not a new defect but
an incomplete propagation of the fix round 1 demanded, and it cannot ride to the report
stage because it would corrupt the artifacts the report is written about. The round is
scoped to confirming the sweep — a diff-scoped re-check of the cited lines, not a fresh
review of a plan already reviewed twice.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (Fable 5, round 3, 2026-08-18 00:04) — 0 blockers; rounds 1 and 2 both NEEDS_REVISION, all eight findings closed. The third round is taken under REV-02's exception and §9.3 states why; the report owes that justification too
- Human: _(pending)_
