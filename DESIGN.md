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
