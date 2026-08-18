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
| **pack** | the rule text injected into the system prompt | **model and harness fixed** | **inconclusive — one pack at +26 pp on build rate (p = 0.0352) does not survive correction for four tests; the other four sit on baseline at p > 0.6** |

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
| Does the pack do anything at all? | superpowers writes no code in 49 of 50 valid unattended cells | detection |
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
- **No default ranking.** One pack of five shows an effect on build rate that is
  nominal only (ponytail, +26 pp, p = 0.0352, against a Bonferroni threshold of 0.0125
  for four comparisons); the other four sit on baseline at p > 0.6; and the one effect
  that appears is confined to a regime the dataset does not record as a field. A sorted
  leaderboard would assert a confidence the data does not support, so the landing view is
  a grid and shape summaries are small multiples with confidence bands, never six
  polygons stacked on one axis set. Derivation: D-001 in `bench/DERIVATIONS.md`.
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
| DEC-005 | The landing view is a cell grid, not a leaderboard | Four of five packs are indistinguishable from baseline (p > 0.6); the fifth is nominal only and does not survive correction for four comparisons; and that one effect is confined to a regime the records do not carry as a field. A ranking would order noise, on a condition the dataset cannot state. The reason first recorded here — "best Fisher p = 0.060" — was withdrawn as unreproducible; see D-001 in `bench/DERIVATIONS.md` |
| DEC-006 | Unmeasured packs are listed and labelled | A six-entry catalogue is not a catalogue, and the visible queue is the growth loop |
| DEC-007 | Workflow artifacts are tracked, not local-only | The port ignored all of `.docs/`, which made CLAUDE.md's "the ticket, plan, and report live in the same commit" unsatisfiable — PDX-001 landed with its own ticket untracked. A project whose pitch is that a claim is worth its receipt cannot hide its receipts. Only generated or staging directories stay ignored: `.docs/scratch/`, `.docs/state/`, `.docs/drafts/` |
| DEC-008 | Ticket slugs lead with their area | `gh-submit.sh` derives the area label from the slug prefix and yields no label when nothing matches — a quiet mislabelling rather than an error. `PDX-###_<area>-<rest>` makes the derivation total over `site` / `data` / `registry` / `harness` / `docs` |
| DEC-009 | The measurement project lives in `bench/`, imported with history | A trace that crosses a repository boundary goes stale on either side without anything noticing, which is precisely how instrument failures 15 and 16 happened. `git subtree add` without `--squash` keeps the commit ordering that is the preregistration's only evidence |
| DEC-010 | Prettier does not format Markdown | It pads every table cell to a common width, turning the decision log and the reference tables into 300-character source lines. These tables are read in source as often as rendered |
| DEC-011 | A pack's `plugin.json` is recorded here; its content is not | DEC-004 forbids vendoring, and PDX-003's plan contradicted itself by storing copies of upstream manifests under that rule. The line is between functionality and declaration: skills, hooks, and anything a user would execute stay in the author's repository, because copying them would make plugdex a mirror standing between the author and their users. A `plugin.json` is the author's statement about themselves — name, repository, license — and recording it verbatim with its source commit is what lets a reader audit our listing against their own words instead of trusting us |
| DEC-012 | `InstallSource` is a union of one member, not a `github | git` union | The CLI's marketplace context supports only the `github`/`repo` form. A union of one makes the unsupported form unrepresentable rather than merely discouraged, and the compile pair under `packages/registry/test/fixtures/` demonstrates the compiler refusing it — a negative check alone is green before the code exists |
| DEC-013 | Recorded upstream manifests are exempt from formatting | A pack's `plugin.json` is recorded here as the author's declaration about themselves (DEC-011), and our listing is auditable against it only while the bytes are theirs. Prettier reformatting one would make it our rendering of their words |
| DEC-014 | Attribution is derived per pack and tagged, never typed | An author name we type is our claim about a real person; one read from their manifest is their own. The tag is in the type so the two cannot be confused, and the case that forced it is real: the pack commonly called "Karpathy's skills" declares `forrestchang` and is distributed from a third repository owner again |
| DEC-015 | A fact that governs the analysis is a record field, never a filename | DATA-01 already said no figure is hand-typed. It did not say where the facts deciding *which records a figure is computed over* may live, and one of them lived in a filename: run `20260815-225842` was withdrawn by a string prefix compared inside `fisher.py`. The Python harness then answered 371 cells while the TypeScript loader answered 447, and neither could tell the other it was wrong. The withdrawal is now a field carrying its reason and its adjudication date, both loaders select on it, and DATA-02 gates the rule with a behavioural probe rather than a grep — a grep only ever catches the spelling of the last bug. The scope was deliberately narrow: `_regime` was filename-derived in the same function and got its own ticket rather than riding this diff, because folding it in would have meant adjudicating a regime for every record and would have destroyed the property that made the change reviewable — it moved one field and no cell. That second half landed as PDX-017 under DEC-019, and this decision is now enforced for both facts |
| DEC-016 | Verdict 4, "no detectable effect", is struck; a build rate is stated with both denominators and no comparison is drawn | The chip table's priority 4 needed a rule for when a difference counts, and every candidate was a statistical claim this corpus cannot support: a nominal p threshold is the leaderboard DEC-005 refuses, wearing a chip; a fixed percentage-point boundary is a number nobody could source. So the site states the pack's build rate and the baseline's, each with its denominator, and leaves the comparison to the reader. The consequence is deliberate and uncomfortable: there is no chip that says a pack did nothing, because saying so honestly needs power this corpus does not have. The finding survives in the record and in the derivations rather than in a badge |
| DEC-017 | The DATA-01 gate discriminates by destination, not by value | A gate that blocked every numeric literal in site source would be turned off within a week — `z-index: 10` is not a claim. So a number bound for the layout engine is legal and a number that can reach a reader's eyes is a BLOCK unless it arrived as an import. Two legal figure sources: `@plugdex/data` and `@plugdex/registry`, whose records carry their own receipts. The name-based half of the allowlist is spoofable in principle, and the rendered-position scanner was written to close that by blocking digits whatever identifier fed them. **That closure claim is false, and is withdrawn here under CLAIM-01 rather than patched again.** It has been falsified three times: `set:html` reached `dist/` unblocked (report review round 1); `aria-description`, `aria-valuetext` and a digit-free `data-rate` rendered by `content: attr()` did the same (round 2); and a goal audit then drove three more through the patched gate in half an hour — `content: var(--rate)` and `content: counter(rate)`, because the CSS scanner reads only `content:` lines, and a plain text node of fullwidth digits, because `/\d/` is ASCII-only. Two of those three reached built output. The uncovered set is not a list this gate is close to finishing: it is generative on three axes at once — CSS keeps adding indirection (`attr` → `var` → `counter` → …), HTML keeps adding rendering attributes, and a figure is strictly larger than an ASCII digit. Two channels no source scanner can ever close: a figure drawn as pixels, and a figure encoded as layout, where `width: 47%` is simultaneously legal layout vocabulary and a published claim. **So what this gate is, corrected: a developer-time lint that narrows the channel from source to a reader, catches the honest mistake, and points at the line.** It does not close the channel, and DATA-01's guarantee is owed to a destination-side check instead — PDX-021, which scans the rendered artifact rather than the source. Extending the allowlist still requires a golden case in the same change; three of its holes are now cases (46, 47, 50) and the audit's three are PDX-021's RED conditions |
| DEC-018 | Status hues never carry text or the load-bearing glyph | Measured, not asserted: the §5 `no code` value computes to 2.10:1 on paper and 2.51:1 on dark ground — below the 4.5:1 text floor of WCAG SC 1.4.3 and below the 3:1 non-text floor of SC 1.4.11. So a hue appears as a background tint and a border, everything a reader must read is ink, and the verdict's primary signal is a shape. This is an application constraint on the palette rather than a revision of it; the §5 values stand |
| DEC-019 | A run-level condition is settled from a document, and the document is named per record | DEC-015 said such a fact belongs on the record. It did not say how the value is decided, and ten records adjudicated from prose is where that question becomes real — a field looks more authoritative than a filename, so a wrong adjudication is worse than the heuristic it replaces. Every regime in this corpus is therefore settled from a source that is not the run's own name, and `bench/DERIVATIONS.md` D-004 names that source per run and grades its strength: one is machine-written (`20260817-162601`'s `results.json`), seven are named by a document, and two rest on inference — including one whose supporting table was itself plausibly computed through the heuristic under suspicion, which is written down rather than smoothed over. The check that the adjudication is right is not the prose: D-002's condition table re-derives from the recorded field, executed by the scenario |
| DEC-021 | A listing's install state is a generated record, and a blocked record must keep failing the same way | On 2026-08-18 an upstream pack added a manifest field the CLI rejects, and a listing this catalogue publishes stopped installing — inside a day of the measurement it advertises. The repository had no way to say so. Its options were a red gate forever or a green gate that lied, and it had them because "does it install" was asserted at test time and never recorded. It is now a record per listing, written only by a real install into a scratch config directory (`scripts/record-installability.sh`), and re-checked by INST-01 over **every** listing rather than the first one in the manifest — the old assertion installed `plugins[0]` and stopped, so its coverage depended on sort order and it caught this breakage only because `caveman` sorts first. The load-bearing rule is INST-01c: a pack recorded as blocked that starts installing is a FAILURE, not a pass. Without it, marking a pack broken would be a way to turn a red gate green permanently, and the honest record would be the one nobody could afford to write. Reproduction is judged by the classifier that wrote the record, not by a pattern the gate carries separately — plan review round 1 killed the first design by showing that `grep -wF agents` matches `custom-agents: Invalid input`, because `-w` treats a hyphen as a word boundary, so a different manifest defect read as the recorded one. The blocked pack keeps its card, its figures and its attribution (CLAIM-01): the measurement happened and stays published; what is added is that the reader is told the current upstream does not install. PDX-024 is the ticket that tells them — this one only makes the fact exist, and until it lands the repository knows something the site does not say. Numbered 021 rather than 020 because PDX-004's branch holds DEC-020 and lands after this ticket; the log is numbered by claim, not by merge order |
| DEC-022 | What the figures describe and what the button installs are two different artifacts, and the gap is disclosed rather than closed | `packages/registry/attribution/caveman/source.json` fixes the pack at commit `27d5a39`, read 2026-08-17; `.claude-plugin/marketplace.json` installs `JuliusBrussee/caveman` at HEAD. For one day those were the same object. Then they were not, and the second one stopped installing. Pinning the install to the measured commit is not available: the marketplace `github` source accepts a `ref`, but passes it to git as a **branch** — a full commit SHA fails with `fatal: Remote branch ... not found in upstream origin` (measured directly), and pinning to a tag would name a mutable pointer while claiming to name a measurement. So the gap stays open and is stated instead: the installability record carries `upstreamHead` at the moment of the attempt and, for a pack that installs, the `installedVersion` the CLI printed — the closest thing this catalogue can give a reader to "what you actually get". A hub that measured one artifact and shipped another without saying so would be doing the thing this project exists to object to |

| DEC-020 | The catalogue reports one named condition, never a pooled rate across conditions | Every run executed under `blocked` or `as-shipped`, and their baselines are 5/20 and 8/11, a gap of 21/44 — exactly as wide as the widest gap any pack opens on its own baseline (ponytail, 16/22 against 5/20, also 21/44; the tie is exact because 8/11 and 16/22 are the same rate). An earlier version of this row and of the site's masthead said "further apart than any pack", which is false by that arithmetic and was corrected under CLAIM-01 after the PDX-004 report review checked it. Pooling them gave 13/31 = 42%, which is what this site rendered until `regime` became a record field (PDX-017): a rate describing neither condition, printed as though it described the experiment. Two rates per card was rejected as the alternative, because `as-shipped` ran at a smaller sample and never ran the `mattpocock` arm at all, so a second column would invite a comparison across unequal designs and imply the two are variants of one measurement. The page reports `blocked` — every arm ran in it, the denominators are 20-22, and it is the pool D-001 and the preregistrations argue about — and says so in the masthead rather than in a footnote. DEC-005's refusal of a leaderboard rests on exactly this: an effect confined to a condition is not an effect of the pack |
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
| 5 | **unmeasured** | listed, not run | everything in the queue |

Two rules that keep this honest:

- **Priority 4 was struck (DEC-016), and the reason is not that the finding stopped
  mattering.** "We looked and could not find one" is still the finding, and it is still
  the answer to a README claiming a large effect. What could not be found was an honest
  rule for when a difference counts: every candidate boundary was a statistical claim this
  corpus cannot support. A chip asserting no effect would have been a leaderboard verdict
  with the arithmetic hidden. The null now lives in the derivations and in the two rates
  printed side by side, where a reader can see the denominators it rests on.
- **A disappointing rate is still styled as a result.** The below-baseline case does not
  occur in this corpus, so it is proven at the level where it is a property of the code:
  the card builds to the same markup whether the rate is above or below baseline, which
  leaves no selector able to tell them apart.
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
| PDX-015 | harness — gate issue drafts under TMPL-01 | `check-templates.sh` states that issue-draft validation is deferred "until the repo is public and issue drafts actually exist". **Only the second became true** — issue drafts exist and are submitted (issue #5), but `gh repo view` reports the repository is still PRIVATE, so an earlier version of this row claiming both conditions had been met was wrong and is corrected here. The deferral condition is therefore only half spent, and the rule still claims a coverage it does not have: drafts exist and go unvalidated regardless of visibility. Validate `.docs/drafts/issue-pdx-###.md` against the required fields of `.github/ISSUE_TEMPLATE/*.yml`, with a golden case, like every other gate |
| PDX-016 | data — withdrawn runs are a record, not a filename | The one withdrawn run is excluded by a filename comparison in `bench/harness/fisher.py` and by nothing at all in `@plugdex/data`, so the published figures and the figures the site would compute disagree by 74 cells. Found by the PDX-004 plan review reading the loader. It is DEC-005's own second ground — a fact that governs the analysis living in the filename — made a second time, which is why it gets a field and a gate rather than a fix |
| PDX-021 | harness+site — DATA-01 is checked on the rendered artifact, not on the source | The source scanner has been tunnelled three times by channels it cannot see, twice into built output, and the uncovered set is generative rather than enumerable (see DEC-017). Checking the destination is channel-agnostic and closes all of them in one move: at build time, emit the set of figures legally derivable from the `@plugdex/data` and `@plugdex/registry` records; render every page in `dist/` with the Playwright harness this repository already runs for AC-7; extract the DOM's `innerText`, the accessibility tree's names and descriptions, and computed `::before`/`::after` content; NFKC-normalise and fold Unicode numeric values so fullwidth and non-ASCII digits collapse to the same tokens; then require every numeric token to be a member of the derivable set, and BLOCK otherwise. The three tunnels the goal audit demonstrated — `content: var(--rate)`, `content: counter(rate)`, and a fullwidth-digit text node — are its RED cases, and each must fail before it is written. Two residues stay open and must be named on the site rather than gated: a figure drawn as pixels, and a figure encoded as layout. Scope note: the source scanner's file walk is `.ts|.astro|.css`, so `.tsx` and `packages/site/public/` are unscanned classes the moment PDX-005's islands or any static asset arrive — that gap is this ticket's, not a later discovery |
| PDX-020 | harness — the fresh-clone gate has only its refusal path under GATE-01 | `scripts/check-fresh-clone.sh` clones a committed ref, installs with `--frozen-lockfile`, and runs verify there. Its passing path cannot be replayed inside `tests/meta/cases/`: the golden-set sandbox copies `scripts/` and plants files, and hosting a full pnpm workspace install per case would make the self-test cost minutes and depend on the network. Case 51 covers the refusal path — a directory that is not a repository must FAIL rather than report a clean verify. **The "cannot be hosted" claim was overstated and is corrected here: report review round 3 built the passing case.** A 23-file planted repository with a dependency-free lockfile and a trivial committed `verify.sh` gives `FRESH-CLONE PASS` in under a second with no network, because the gate reports what that verify says rather than what the developer's tree says. The only detail it needs is the gate's ≥20-tracked-file floor. So this row is small work, not a structural limit, and it stays open only because it was found while PDX-004 was closing |
| PDX-018 | harness — `test-loop.sh` GREEN cannot pass on a stacked branch | Stage 4 runs the full `e2e.sh` and reports any failure as "your change broke an existing scenario". On a branch stacked over a ticket that is deliberately at the `red` stage, that sentence is false and the gate is unpassable by construction — PDX-017 sat on PDX-004's RED and could not get a green `test-loop` however correct it was. The consequence is worse than the inconvenience: the stage gets run by hand, stage by stage, and the OBS-01 log loses the one record that proves TDD happened. Found by the PDX-017 report review, which noticed the missing log entries rather than the missing run. The gate should read each ticket's stage stamp and require green only from scenarios whose ticket is past `red`, reporting the rest as known-red rather than as breakage. **Scope corrected after measuring it**: extracting PDX-017 onto PDX-016 in a scratch worktree gives `verify` PASS, `e2e` 5/5, and `test-loop` GREEN, so the gate is not broken for stacked work in general — it is unpassable only while the stack is *worked on in place*, which is a branch-hygiene problem (CLAUDE.md: mid-cycle RED states are never committed) as much as a gate one. Both halves are worth fixing and the gate half is the cheaper |
| PDX-019 | harness — `gh-submit.sh pr` derives the PR title from HEAD, not from the ticket | The issue path derives its title from the ticket's H1; the PR path takes the HEAD commit title instead. Those agree only when the last commit of a ticket happens to describe the whole ticket. PDX-017's did not — its final commit was branch housekeeping, so PR #8 opened as "cut the ticket branch from main, and the scope violation went away", which names an operation rather than the change. The title was corrected with `gh pr edit`, which is the first hand-typed title in this repository and the thing the wrapper exists to prevent. Derive the PR title from the ticket H1 exactly as the issue path does, and keep the HEAD-commit title only as a fallback when no ticket file is found |
| ~~PDX-017~~ | ~~data — regime is a record, not a filename~~ | **Closed** — merged to `main` as `62d76dd` (PR #8), which is when a debt item is actually paid. `load_cells` read `_regime` off the filename (`"as-shipped" in name`), and the regime moves the baseline build rate from 25% to 73% (corrected under CLAIM-01: 35% is the *passes* baseline in the blocked-haiku pool, D-001's figure, and this sentence says build — caught by the PDX-017 report review). Every record now carries it as a required field, both loaders select on it, DATA-02 gained rules e, f and g with four golden cases, and `acceptance.py` refuses to grade a run whose condition it cannot establish. No published figure moved: D-002's condition table and D-001's anchors re-derive unchanged, which is what makes the relocation reviewable. See DEC-019 and D-004 |
