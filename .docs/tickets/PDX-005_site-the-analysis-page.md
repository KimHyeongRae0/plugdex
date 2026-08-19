# PDX-005 — site: the analysis page

- Status: TODO
- Created: 2026-08-19

## 1. Goal

The catalogue asserts one rate per pack. This ticket builds the page that shows what the
rate is made of, in the shape a benchmark reader already knows how to read: a leaderboard
with intervals, trade-off scatters against cost and wall clock, a frontend/backend split, a
per-ticket breakdown, token economics, and the full cell grid.

A working prototype was rendered against the live corpus before this ticket was written, so
the layout, the figures and the visual language are measured rather than imagined. Building
it surfaced a disclosure defect the catalogue currently ships, and fixing that is part of
this ticket rather than a sequel: **the card's headline rate counts frontend tickets only.**
All 103 build-graded cells are `fe-*`; the 86 backend cells are graded by whether the code
imports without new diagnostics, and are absent from the number entirely. The page says
nothing about this today.

## 2. Scope

### Allowed
- `packages/data/**` — the per-domain grader, Wilson intervals, per-task and per-arm
  aggregates, and the economics join, each with unit tests
- `packages/site/**` — the analysis page and its components
- `scripts/check-data.sh` — the `.tsx` walk, and the JSX text-node hole the plan found
- `tests/e2e/PDX-005-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decisions this ticket takes; `docs/WORKFLOW.md` if a gate row changes
- `README.md` and `docs/images/**` — **added 2026-08-19, after the report review found them
  riding this ticket's commit unnamed.** They belong here because they are downstream of the
  page rather than adjacent to it: the images are screenshots of the page this ticket
  builds, and the README paragraph they sit under states the two graders, which is the same
  correction as AC-2. The boundary that stays hard is the one below — `bench/**` is named
  Not Allowed in as many words, and a ticket may not widen an explicit refusal after the
  fact. An unnamed file is a gap in a scope section; a named refusal is a decision

### Not Allowed
- `bench/**` — no re-measurement; this ticket publishes the corpus it was given
- A composite index or any single ranking score across unlike metrics
- Blending the two conditions, or the two domains, into one number
- Any figure computed in the site rather than read from `@plugdex/data`

## 3. Acceptance Criteria

- [ ] AC-1: the leaderboard renders one row per listed pack with build rate, its 95% Wilson
      interval, the no-code count, and the per-cell economics — cost, turns, output tokens,
      lines of code, seconds. Every figure comes from `@plugdex/data`; the site computes
      none of them. **Every mean carries the number of rows it was taken over whenever that
      is fewer than its arm's pool** — added 2026-08-19 by report review, which found the
      page printing a mean over 52 rows under a note claiming a mean over all 54. The
      criterion is per figure and not per row, because the shortfall is not uniform across
      an arm's metrics: the rows that recorded no cost still recorded their diff.
- [ ] AC-2: **the headline rate names its population.** Wherever a build rate appears — on
      the analysis page and on the existing catalogue card — the page states that it is the
      frontend build rate, and the backend result is shown beside it rather than folded in
      or omitted. An assertion fails if a rate is rendered without its domain named.
- [ ] AC-3: the economics are per condition. `results.json` rows join to their run through
      the record's own `date` field, which equals the acceptance record's `run`; no filename
      decides which condition a cost belongs to (DATA-02). A test plants a corpus whose
      filenames contradict its records and asserts the join follows the records.
- [ ] AC-4: two trade-off scatters — build rate against cost per cell, and against wall
      clock — each drawing a Pareto frontier. A frontier of fewer than two distinct
      x-positions is drawn as nothing rather than as a degenerate line, and the page says so
      instead of showing an empty chart with no explanation.
- [ ] AC-5: per-ticket breakdown: a radar per pack over the twelve tickets, with the 95%
      interval drawn behind the point estimate, and a table of the same counts. Both carry
      denominators; a colour without its count is a violation of this criterion.
- [ ] AC-6: the cell grid renders every square of the published `blocked` corpus — 6 arms x
      12 tickets, 72 squares, none empty, 312 cells summing to 229 valid — with one mark per
      repetition and four distinguishable states. The counts are asserted against the loader.
- [ ] AC-7: three states are distinguishable without colour and the contrast floors hold in
      both schemes (DEC-018), asserted on computed style in a real browser.
- [ ] AC-8: the page carries no composite index, states that it does not, and states why.
      An assertion greps the built output for a single-score element and fails if one exists.
- [ ] AC-9: DATA-01's source walk covers `.tsx`, with golden cases both directions — a
      hardcoded figure in a `.tsx` BLOCKs, a clean one passes. **This criterion no longer
      rests on this ticket shipping islands, and the correction is the plan's:** every chart
      in the prototype draws server-side, and shipping a React runtime for one dialog would
      contradict the site's static-first rule and PDX-004's assertion that the page needs no
      server entrypoint. The walk is extended anyway, because the gap is real the moment
      anyone adds the first `.tsx` and a gate nobody can see failing is a gate nobody fixes.
      The golden cases are what make it non-vacuous today.
- [ ] AC-10: DEV-01 — real browser, 360px reflow, dark mode, and every chart readable at
      360px without horizontal scroll on the page body.

## 4. Edge Cases & Error Handling

- An arm with no graded cell (`superpowers` under `blocked`) → rendered as "no graded cell",
  never as 0%. A pack that wrote no code has no build rate, and printing zero would report a
  measurement that was never taken.
- A square whose repetitions disagree → the marks show the disagreement; no majority verdict.
- An invalid cell → drawn as invalid with its reason available. 83 of 312 are invalid and 74
  of those are one instrument failure clustered on the frontend tickets, so this is the
  common case, not the corner.
- A radar spoke resting on one repetition → the interval band covers nearly the whole axis,
  which is the honest rendering and must not be clipped to look tidier.
- JavaScript disabled → the whole page still works. Every chart, the grid and the tables are
  server-rendered, and the one interactive element reuses the native dialog PDX-004 already
  ships. There is no "what is unavailable" notice to write, because nothing is.

## 5. E2E Mapping

- `tests/e2e/PDX-005-the-analysis-reads.sh` — AC-1, AC-2, AC-4, AC-5, AC-6, AC-8 over built
  output
- `tests/e2e/PDX-005-the-analysis-looks-right.sh` — AC-7, AC-10 in a real browser
- `tests/meta/cases/<n>-site-tsx-*.sh` — AC-9, both directions, including a figure in a JSX
  text node: the plan found that the TypeScript scanner tests `ts.isStringLiteral`, which
  does not match JSXText, so a `.tsx` walk alone would have shipped a hole rather than closed
  one
- Unit tests in `packages/data` carry AC-3's join and every interval computation

## 6. References

- DESIGN.md Phase B, §4 reference study, §5 visual rules, DEC-018, DEC-020, DEC-021, DEC-022
- `bench/DERIVATIONS.md` D-001, D-002
- The rendered prototype and its measured figures, recorded in this ticket's plan
