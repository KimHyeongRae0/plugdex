# PDX-004 — The catalogue: cards, verdict chips, install, and DATA-01

- Status: TODO
- Created: 2026-08-17

## 1. Goal

The first thing a visitor sees. A static Astro site with one card per pack, each carrying
a verdict chip legible before any chart loads, and an install action that hands over the
two commands that actually work. This is where plugdex stops being a dataset and becomes
a thing someone uses.

It is also where DATA-01 becomes a gate rather than an intention: a numeric literal in a
component that did not come from `@plugdex/data` is a BLOCK. Every published benchmark
this project objects to could pass its own review; the difference here is that a
hand-typed number cannot survive `verify.sh`.

## 2. Scope

### Allowed
- `packages/site/` — Astro, static output, React islands only where interaction is real
- `packages/data/src/verdict.ts` — the pure function from cells to a verdict; it belongs
  with the data, not the view, so the site cannot compute a different answer
- `scripts/check-data.sh` — the DATA-01 gate
- `scripts/verify.sh` — one new step
- `tests/meta/cases/` — golden cases for DATA-01
- `tests/e2e/PDX-004-*.sh` — including real-browser assertions
- `DESIGN.md` — decisions this ticket produces
- root `package.json` — only if the workspace needs the site's scripts wired

### Not Allowed
- A leaderboard, a composite score, or a default sort by any verdict (DEC-005). The
  landing view is a grid; ranking is the thing the data does not support
- Hand-typed numbers anywhere in a component, including in prose ("about half"). If a
  figure appears, it is read from `@plugdex/data`
- The receipt drawer and the cell grid. Those are PDX-005 and this ticket must not
  half-build them
- Shape summaries, the exhibit, the withdrawal register, the method page — PDX-006 onward
- Listing unmeasured packs. PDX-012 owns the queue; putting placeholders in now would
  ship the graveyard before the value structure that prevents it
- Deploying, buying a domain, or announcing anything (CR-01)

## 3. Acceptance Criteria

- [ ] AC-1: the site builds to static output with no server runtime, and the built HTML
      for the index contains every listed pack's name in the markup — not injected by
      client JavaScript. A catalogue that needs a bundle to be read is a catalogue search
      cannot index
- [ ] AC-2: **the verdict is derived, never authored.** `verdictFor({packId})` in
      `@plugdex/data` returns one of the five verdicts, and the priority order resolves a
      pack matching several. Unit-tested against synthetic cells, including a pack that
      matches two conditions at once
- [ ] AC-3: **every chip carries its n.** A chip rendering a percentage with no
      denominator fails the scenario. `47% builds` without `n=` is the class of number
      this project exists to object to
- [ ] AC-4: **DATA-01 gate.** `scripts/check-data.sh` BLOCKs a numeric literal in
      `packages/site/**` that is not sourced from `@plugdex/data`. Proven by golden cases:
      a hardcoded percentage in a component is caught; a `z-index: 10` in a style is not.
      The gate must distinguish a claim from a layout constant or it will be disabled
      within a week
- [ ] AC-5: the install action shows both commands, a copy control, and **the repository
      the pack will actually be pulled from** — SRC-01 rendered, not merely stored. The
      scenario asserts the upstream URL is in the DOM
- [ ] AC-6: **the null result is styled as a result.** A pack whose measurement found no
      detectable effect renders a chip with the same visual weight as any other, not a
      greyed-out absence. Asserted on computed style, not on the class name
- [ ] AC-7: real-browser verification at 360px and at desktop, in both colour schemes:
      no horizontal page scroll, every chip legible without colour alone (shape carries
      the signal), and the install control reachable by keyboard. Screenshots attached to
      the report (DEV-01)
- [ ] AC-8: `verify.sh` runs DATA-01 and the golden set is unregressed

## 4. Edge Cases & Error Handling

- A pack with no measurement yet → `unmeasured` chip; must not render `0%` or an empty
  chip → e2e AC-2/AC-3
- A pack matching both "produces no code" and "published claim not reproduced" → priority
  order decides; unit test asserts which and why
- A percentage whose denominator is 3 → the chip shows `n=3`; the scenario asserts small
  n is visible rather than rounded away → e2e AC-3
- A component with a legitimate numeric literal (`gridColumns = 3`, `z-index: 10`) → must
  NOT be blocked → golden case, clean-pass side
- A component with `const buildRate = 47` → must be blocked → golden case
- Colour-blind reading and dark mode → AC-7, real browser, both schemes
- 360px viewport → AC-7; the cell grid is the usual offender and it is not in this ticket,
  so the card grid has no excuse

## 5. E2E Mapping

- `tests/e2e/PDX-004-the-catalogue-reads.sh` — AC-1..AC-6, AC-8 over built output
- `tests/e2e/PDX-004-the-catalogue-looks-right.sh` — AC-7, real browser, both viewports
  and both schemes, screenshots written to the run directory

## 6. References

- DESIGN.md §2 (what the visitor takes away, in order), §4 (reference designs — the card
  grid from cursor.directory, sample sizes from Aider), §4.2 (three questions, not a
  score), §4.3 (deliberate departures), §5 (visual direction and palette), Reference Map
  row PDX-004
- DEC-005 — the landing view is a cell grid, not a leaderboard
- DEC-006 — unmeasured packs are listed and labelled
- CLAUDE.md — DATA-01, GATE-01, DEV-01, CR-01
- PDX-002 — `@plugdex/data`, the only source of a figure
- PDX-003 — `@plugdex/registry`, the source of the list and of SRC-01 fields
