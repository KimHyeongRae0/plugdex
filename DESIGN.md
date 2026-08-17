# plugdex — Design

Normative spec and decision log. Read this before writing a plan. English only
(LANG-01, no allowlist).

## 1. What plugdex is

A hub for agent behaviour packs where every listing carries a measured verdict.

Two faces over one dataset:

| Face | Artifact | What it answers |
|---|---|---|
| the site | static catalogue | "which pack should I install, and what happens if I do?" |
| the registry | `marketplace.json` | "make it installable from inside my agent" |

The packs advertise less code, fewer tokens, lower cost. Those are real measurements
taken without checking that the delivered code compiles. plugdex is the catalogue that
checks.

## 2. What the visitor takes away, in order

1. **A decision.** Install this or not. A verdict chip on the card, legible before any
   chart loads.
2. **A receipt.** The ticket sent, the resolved invocation, the diff the agent produced,
   the gate output verbatim. One click from the verdict.
3. **A method.** Preregistration, delta gates, negative controls, and a public record of
   every withdrawn claim — reusable by anyone evaluating an agent.

## 3. Positioning: a register, not a report

Packs ship continuously; a one-off report is dead in two weeks. plugdex is the standing
place where a new pack gets checked. Unmeasured packs are listed as **unmeasured** —
a catalogue with six entries is not a catalogue, and a visible queue is what makes an
author come to us.

**The hub alone is not defensible.** `cursor.directory` is the proof: a rules directory
built in three hours, 250k visits a month, 3.6k stars. Listing is a solved problem. The
verdict and the receipt are the only part a competitor cannot copy in an afternoon,
which is why DATA-01, CLAIM-01, and SRC-01 are gates rather than intentions.

## 4. Reference designs

Studied before building. Each row names the one thing being taken.

| Reference | What it does | What plugdex takes |
|---|---|---|
| Artificial Analysis, coding agents | Scatter of index vs cost / tokens / wall-clock, colour by provider, Pareto line, an isolated "harness comparison" that fixes the model and varies the harness | The **harness comparison** framing — fix everything, vary one thing, say so. Also the layered "what this metric means" disclosure |
| cursor.directory | Cards for agent rule packs, search, trending, per-entry setup instructions | The card grid and per-entry install instructions. It is the closest thing to a competitor and the reason the verdict has to be on the card, not on a sub-page |
| caniuse | A support matrix: features by browser, colour-coded, dense, readable at a glance without a legend lecture | The **cell grid** — packs by ticket, one square per repetition. It shows distribution instead of asserting a ranking |
| Our World in Data | Uncertainty drawn rather than described; every chart downloadable with its source | Confidence bands on the shape summaries, and every figure traceable to its record (DATA-01) |
| Aider leaderboards | Plain table, exact task counts, methodology inline | Sample sizes printed next to every number rather than in a footnote |

### 4.1 What plugdex measures is one layer below Artificial Analysis

Artificial Analysis already runs two layers. plugdex runs a third, and the effect size
shrinks at every step down:

| Layer | What varies | Everything else | Observed effect size |
|---|---|---|--:|
| model | GPT-5.6 vs Opus 5 | — | 10–40 pp on public benchmarks |
| harness | Cursor vs Claude Code vs OpenCode | model fixed | 10–20 pp (AA's Harness Comparison) |
| **pack** | the rule text injected into the system prompt | **model and harness fixed** | **not significant — best pairwise Fisher p = 0.060** |

AA's Harness Comparison is structurally the same experiment as ours, one level up. We
hold the harness fixed too and change only the text. That is a smaller intervention, and
the measurement is correspondingly weaker.

This is the single most important fact about the product. AA can publish a league table
because their differences clear the noise floor; ours do not. Positioning plugdex as
"Artificial Analysis for packs" would implicitly promise a ranking the data cannot
deliver, and that mismatch is what would destroy credibility rather than build it.

### 4.2 The claim structure: three questions, not a score

Every finding the source data produced was one of these, and none of them was a ranking:

| Question | Example finding | Form |
|---|---|---|
| Does the pack do anything at all? | best pairwise difference p = 0.060 | detection |
| Does it do what it says? | a published −65% token headline whose measured CI excludes it | claim verification |
| Does the delivered code build? | ~55% of code-producing cells fail the repository's own gates | delivery integrity |

A "we could not detect a difference" answer to question 1 is a **result, not a gap** —
the pack's own README claims a large one. Publishing the null is the point.

This also sets measurement priorities. Raising the power to rank packs means going from
6 tasks to ~30, at roughly five times the cost, for an answer that stays near the noise
floor. The binary findings are cheap and decisive by comparison: the strongest result in
the source data (a pack that produces no code at all in an unattended session) was
confirmed across a second model with three cells. New packs get the three questions;
they do not get entered into a race.

### 4.3 Deliberate departures

- **No composite index.** Artificial Analysis averages three benchmarks into one score.
  We measured six frontend and six backend tickets and the spread by ticket is larger
  than the spread by pack; a single number would hide the only honest finding.
- **No default ranking.** The best pairwise result in the source data was p = 0.060.
  A sorted leaderboard would assert a confidence the data does not support, so the
  landing view is a grid and shape summaries are small multiples with confidence bands,
  never six polygons stacked on one axis set.
- **Area is not a metric.** Radar area is an artefact of axis order. Where a shape
  summary appears it is captioned as such and the axis order is adjustable.

## 5. Visual direction

**Claims look like a paper; evidence looks like a terminal.**

The site's only job is to be believed. A neon dashboard undercuts that. The chrome is a
lab notebook — paper ground, serif headings, numbered figures with captions, margin
notes carrying the caveats. The data is a terminal — black blocks, monospace, gate
output pasted unmodified. The contrast is the identity.

| Role | Light | Dark |
|---|---|---|
| paper | `#FAF8F3` | `#141311` |
| ink | `#16150F` | `#EDEAE1` |
| pass | `#3F6B4A` | `#7FA98A` |
| fail | `#9C4A32` | `#C97B5F` |
| no code | `#B3ADA0` | `#5A554C` |
| accent | `#1D4E89` | `#7FA8D8` |

Constraints:

- Numbers are monospace with tabular figures. A table whose digits shift is a table
  nobody trusts.
- Pass / fail is never colour alone — shape (`▪` `▫` `░`) is the primary signal.
- Motion is one hero count-up, a drawer slide, and grid hover. No scrollytelling.
- Body text 66–72 characters. Only tables and the grid exceed it.
- Static first. An interactive island must earn its JavaScript.

## 6. Reference Map (REF-01)

A plan for a mapped ticket must record these as consulted, with a note, in its
"References Consulted" section. `scripts/check-references.sh` holds the machine-readable
copy; this table is the source it was transcribed from.

| Ticket | Area | Required references |
|---|---|---|
| PDX-001 | harness bootstrap | *exempt* — the port source is itself the reference |
| PDX-002 | data package | `acceptance.json` · `PREREGISTRATION` · `gate-limits` |
| PDX-003 | registry package | `marketplace.schema.json` · `plugin.json` · `plugin marketplace add` |
| PDX-004 | site catalogue | `site-design` · `WCAG contrast` |
| PDX-005 | receipt drawer | `_invocation.json` · `acceptance cells` |
| PDX-006 | shape summaries | `bootstrap CI` · `radar chart critique` |

## 7. Decision log

| ID | Decision | Rationale |
|---|---|---|
| DEC-001 | The 9-stage gate harness is ported from orangerail rather than reinvented | It is battle-tested across two prior projects, and the gate self-test means the port can be proven rather than assumed |
| DEC-002 | LANG-01 carries no allowlist | The lineage exempted a Korean spec. plugdex publishes to a global audience; an English-only rule with an exception is an English-mostly rule |
| DEC-003 | Three packages: `data`, `registry`, `site` | The dataset is the product; the site and the marketplace are two renderings of it. Keeping them separate is what makes DATA-01 checkable |
| DEC-004 | The registry points at upstream repositories, never vendors them | `{"source": "github", "repo": "owner/repo"}` was verified to resolve against a curated marketplace. Pointing keeps us a catalogue and keeps licensing trivial |
| DEC-005 | The landing view is a cell grid, not a leaderboard | Pairwise pack differences were not significant in the source data (best Fisher p = 0.060). A ranking would assert what the numbers do not support |
| DEC-006 | Unmeasured packs are listed and labelled | A six-entry catalogue is not a catalogue, and the visible queue is the growth loop |
| DEC-007 | Workflow artifacts are tracked, not local-only | The port ignored all of `.docs/`, which made CLAUDE.md's "the ticket, plan, and report live in the same commit" unsatisfiable — PDX-001 landed with its own ticket untracked. A project whose pitch is that a claim is worth its receipt cannot hide its receipts. Only generated or staging directories stay ignored: `.docs/scratch/`, `.docs/state/`, `.docs/drafts/` |
| DEC-008 | Ticket slugs lead with their area | `gh-submit.sh` derives the area label from the slug prefix and yields no label when nothing matches — a quiet mislabelling rather than an error. `PDX-###_<area>-<rest>` makes the derivation total over `site` / `data` / `registry` / `harness` / `docs` |
| DEC-009 | The measurement project lives in `bench/`, imported with history | A trace that crosses a repository boundary goes stale on either side without anything noticing, which is precisely how instrument failures 15 and 16 happened. `git subtree add` without `--squash` keeps the commit ordering that is the preregistration's only evidence |
| DEC-010 | Prettier does not format Markdown | It pads every table cell to a common width, turning the decision log and the reference tables into 300-character source lines. These tables are read in source as often as rendered |
| DEC-011 | A pack's `plugin.json` is recorded here; its content is not | DEC-004 forbids vendoring, and PDX-003's plan contradicted itself by storing copies of upstream manifests under that rule. The line is between functionality and declaration: skills, hooks, and anything a user would execute stay in the author's repository, because copying them would make plugdex a mirror standing between the author and their users. A `plugin.json` is the author's statement about themselves — name, repository, license — and recording it verbatim with its source commit is what lets a reader audit our listing against their own words instead of trusting us |

## 8. Ticket roadmap

### The spine

Five tickets already have entries in the Reference Map, so the numbering is fixed for
PDX-002 through PDX-006. Everything after that is new.

```
A. dataset + machine face     PDX-002  PDX-003
B. the catalogue  ── SHIP ──  PDX-004  PDX-005
C. the arguments              PDX-006  PDX-007  PDX-008  PDX-009  PDX-010
D. becoming a register        PDX-011  PDX-012  PDX-013  PDX-014
```

Every gate lands **inside the ticket it guards**, never in a later cleanup pass:
SRC-01 with PDX-003, DATA-01 with PDX-004, CLAIM-01 with PDX-009.

---

### Phase A — the dataset and its machine face

#### PDX-002 · data — absorb the measurement project and bake its records
*Landed.* `bench/` by subtree with history intact, `packages/data` with the
fingerprint invariant enforced at the type level. Ends empty-workspace mode.

#### PDX-003 · registry — pack entries, marketplace generation, SRC-01
The hub's machine face and the source of the catalogue's list.

- A `PackEntry`: id, display name, author, upstream repo, license, stars-at-record-time,
  install source (`{source: "github", repo: "owner/repo"}` — the form verified to
  resolve; `{source: "git", url}` is **not supported** by Claude Code 2.1.233), listing
  provenance, opt-out contact.
- Generates `.claude-plugin/marketplace.json` from those entries. One command,
  deterministic, diffable.
- **SRC-01 gate**: an entry without an upstream link, a named author, and a recorded
  listing provenance is a BLOCK.
- **The acceptance criterion that actually matters**: a clean machine runs
  `claude plugin marketplace add <ours>` then `claude plugin install <pack>@plugdex` and
  gets a working pack. If the hub function does not work end to end, the positioning is
  dead, so this is proven at PDX-003 and not assumed until launch.

#### Design this ticket needs first — the record shapes

Two records, one join key (`packId`):

```
PackEntry     identity, provenance, how to install     (hand-curated, reviewed)
PackVerdict   what measurement says                    (derived, never hand-typed)
```

`PackVerdict` is derived from `packages/data` cells by a pure function. DATA-01 means it
can never be authored by hand.

---

### Phase B — the catalogue (minimum publishable)

#### PDX-004 · site — skeleton, pack cards, verdict chips, install, DATA-01
Astro, static, React islands only where interaction is real. Paper-and-terminal palette,
light/dark, tabular numerals.

- Card = name, author, stars, one line, **verdict chip**, `Install`.
- `Install` opens a modal: the two commands with a copy button, and a line naming whose
  repository it will actually pull from (SRC-01 in the UI, not just in the data).
- **DATA-01 gate**: a numeric literal in a component that is not sourced from
  `@plugdex/data` is a BLOCK. This is the gate that makes "no hand-typed numbers" real.

#### PDX-005 · site — receipt drawer and the cell grid
The evidence layer, and the only thing on this site a competitor cannot clone in an
afternoon.

- Cell grid: packs × tickets, three squares per cell, `▪` pass / `▫` fail / `░` no code.
- Drawer per cell: ticket text → resolved invocation (`_invocation.json`) → what already
  existed in the repo → the diff → gate output verbatim → cost/tokens/turns.
- DEV-01 checklist: real browser, 360px reflow, dark mode, keyboard reachability of the
  drawer, and the chip legible without colour.

**→ Ship after PDX-005.** Cards + install + receipts is the whole argument. Everything
after this strengthens it; nothing after it is required to be useful.

---

### Phase C — the arguments

| # | Ticket | What it adds | Why it is not in the MVP |
|---|---|---|---|
| PDX-006 | site — shape summaries | Hexagon small multiples, baseline ghosted, bootstrap CI bands, axis order adjustable, "area is not a metric" caption | It is the prettiest thing on the site and the least load-bearing. Shipping it first would advertise a ranking we do not have |
| PDX-007 | site — the exhibit | One pack, one number (68/69), the verbatim final message, toggles for model / tool policy / combination that all return the same result | Needs the drawer to link into |
| PDX-008 | site — gate blind spots | The 8 probes as before/after diffs; 4 caught, 4 pass everything. The owner-filter leak leads | Self-limiting content; only credible once the gate results themselves are on the site |
| PDX-009 | site — the withdrawal register + CLAIM-01 | Every retracted claim with its original value, cause, replacement. Two entries on day one. **CLAIM-01 gate**: a verdict whose value changed without a withdrawal record is a BLOCK | Needs at least one verdict to have changed |
| PDX-010 | site — method and reproduce | Preregistration, delta gates, negative controls, the exact commands | Reference material, not a landing surface |

---

### Phase D — becoming a register rather than a report

| # | Ticket | Why it exists |
|---|---|---|
| PDX-011 | ops — the three-question runbook | Measuring a new pack must be a documented, repeatable operation, not a research project. Proven by running it end to end on a pack nobody has measured yet. If this is not repeatable, plugdex is a report with a nice UI |
| PDX-012 | data+site — top-N listing and a request-driven queue | **Not "list everything".** A GitHub code search for `.claude-plugin/marketplace.json` returns 30,656 repositories; completeness is not available and pretending otherwise is the fastest way to look abandoned. Hand-list the top ~30 by adoption, all labelled `unmeasured`, and take measurement requests through one issue template. Discovery automation waits until volume justifies it |
| PDX-013 | ops — author notification | Before anything is public: open an issue on each measured pack's repo with the finding, offer a correction window, and publish their response beside ours. The superpowers result especially. This makes the result unarguable rather than weakening it |
| PDX-014 | infra — deploy | Domain, static hosting, SEO basics. A directory that search cannot index does not exist |

### Why the queue is not a promise

A register creates an obligation: 30 entries labelled `unmeasured` that never get measured
is a graveyard, and worse than listing 6. The fix is not "drain faster" but a value
structure where **an unmeasured entry is already useful on its own** — it browses,
it installs, it links upstream, it names the author. The verdict is additive. That makes
the label an "not yet" on something that already works, rather than an IOU.

What makes the loop turn is that measurement is cheap: three questions is 9 cells at
roughly $3 and half an hour, a price that exists only because this project gave up on
ranking. At that price the queue can be **request-driven** — an author opens an issue and
gets third-party verification for free, and the queue prioritises itself. That pulls
harder than a submission form nobody fills in.

PDX-013 is a launch blocker, not a nicety. PDX-014 has a decision attached: `plugdex.dev`
is free; `plugdex.com` belongs to a DeFi white-label product, which is a known and
accepted collision.

---

### The one design decision still open: how a verdict becomes a chip

A pack can be true of several of these at once. The card shows the most
decision-relevant one; the rest live in the card body.

| Priority | Chip | Condition | Example |
|--:|---|---|---|
| 1 | **produces no code unattended** | no code in ≥ 80% of valid cells under the as-shipped regime | superpowers, 0/9 |
| 2 | **published claim not reproduced** | the measured 95% CI for the claimed metric excludes the published figure | caveman, −65% claimed, CI [−17.2, +55.2] |
| 3 | **N% builds** | produces code; the pass rate over its code-producing cells | ponytail and the rest |
| 4 | **no detectable effect** | produces code, but no metric differs significantly from baseline | the honest default for most packs |
| 5 | **unmeasured** | listed, not run | everything in the queue |

Two rules that keep this honest:

- **Priority 4 is a result, not a blank.** The pack's own README claims a large effect;
  "we looked and could not find one" is the finding. It must not be styled as an absence.
- **Every chip carries its n.** `47% builds` with no denominator is the kind of number
  this project exists to object to.

### What is deliberately not on this roadmap

- A leaderboard, a composite index, or a default sort by score (DESIGN.md §4.1–4.3).
- Raising task count from 6 to ~30 to reach ranking power: five times the cost for an
  answer that stays near the noise floor. The three questions are cheap and decisive.
- A CLI. Rejected earlier and still rejected — nobody wants to run this themselves.

### Harness debt found while running the cycle

| # | Ticket | Why it exists |
|---|---|---|
| PDX-015 | harness — gate issue drafts under TMPL-01 | `check-templates.sh` states that issue-draft validation is deferred "until the repo is public and issue drafts actually exist". Both became true with PDX-002, so the rule now claims a coverage it does not have. Validate `.docs/drafts/issue-pdx-###.md` against the required fields of `.github/ISSUE_TEMPLATE/*.yml`, with a golden case, like every other gate |
