# PDX-004 Report — site: catalogue cards, verdict chips, install, DATA-01

- Ticket: `.docs/tickets/PDX-004_site-catalogue-cards-verdicts-and-install.md`
- Plan: `.docs/analysis/PDX-004_plan.md`
- Author: Opus 5 (implementation) — plan and plan review by Fable 5
- Date: 2026-08-18

## 1. Summary

The catalogue exists: five cards, each with a measured verdict chip, both rates with their
denominators, and an install dialog naming the repository it will pull from. It is static
Astro, and the figures are in the emitted HTML — the page needs no JavaScript to be read.

Two things in this ticket are worth more than the page itself.

**The card was rendering a number that describes nothing.** The baseline read 42%, which
is `blocked` 5/20 and `as-shipped` 8/11 pooled — a rate that exists under neither
condition. It was there because `@plugdex/data` had no regime to select on; PDX-017 gave
it one, and the page now loads a single condition and names it in the masthead. DEC-020
records why two rates per card was refused: `as-shipped` ran at a smaller sample and never
ran the `mattpocock` arm, so a second column would invite a comparison across unequal
designs.

**The DATA-01 gate's first catch was our own code.** `PackCard` and `VerdictChip` each
computed their own percentage, which needs the literal `100` — a typed figure in the one
place the rule is absolute. Widening the allowlist to admit `percent` would have admitted
`const buildRate = 47` with it, so the conversion moved into `@plugdex/data` instead. The
site's figure path now holds no numeric literal at all.

## 2. Files Changed

| File | Change |
|---|---|
| `packages/data/src/verdict.ts` | `verdictFor` and the four verdict types; `formatRate` / `percentOf`, which throw on `n <= 0` rather than returning a rate for a denominator of zero |
| `packages/data/src/verdict.test.ts` | 14 tests: priority order, the interval arriving as a record, build counted over code-producing cells only, and the formatter's refusals |
| `packages/data/src/index.ts` | The verdict surface |
| `packages/site/**` | Astro static site: theme from DESIGN.md §5, `PackCard`, `VerdictChip`, `InstallDialog`, `index.astro` |
| `scripts/check-data.sh` | **New.** The DATA-01 gate: three scanners (TypeScript AST, `@astrojs/compiler`, CSS `content`), discriminating by destination |
| `scripts/verify.sh` | DATA-01 composed as step 7 of 12 |
| `scripts/check-gates.sh` | Exports `PLUGDEX_REAL_ROOT` so a case can link the workspace modules the gate's parsers live in |
| `tests/meta/cases/39..43-site-*.sh` | Five golden cases, both sides of the gate |
| `tests/e2e/PDX-004-the-catalogue-reads.sh` | AC-1..AC-6 (markup), AC-8, over built output |
| `tests/e2e/PDX-004-the-catalogue-looks-right.sh` | The browser matrix: {360x740, 1280x800} x {light, dark} |
| `DESIGN.md` | DEC-016, DEC-017, DEC-018, and **DEC-020** (one named condition, never a pooled rate) |

## 3. Plan Compliance

| Plan step | Done | Deviation (if any) |
|---|---|---|
| 1 — verdict types and the pure function | ✅ | Extended: `formatRate` / `percentOf` were added when the DATA-01 gate blocked the site's own percentage arithmetic. The plan did not foresee that the gate it specified would forbid the components it specified |
| 2-7 — the site, theme, chip, card, dialog, page | ✅ | None structurally. `index.astro` gained the regime selection and the masthead paragraph that names the condition — a deviation, justified in §8 |
| 8 — the DATA-01 gate | ✅ | Two spec items were missing from the first implementation and the scenario found both: `<style>` bodies were being read as rendered text (so `z-index: 10` was blocked), and the slice-class exemption the plan specified had not been written at all |
| 9-10 — golden cases | ✅ | Five cases (numbers derived at implementation per PLAN-01) |
| 11-12 — the two scenarios | ✅ | Both rewritten in place; see §4 for what they were doing before |
| 13 — decision log | ✅ | DEC-016, 017, 018 as planned, plus DEC-020 (§8) |

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

| Round | Command | Result |
|---|---|---|
| 1 (RED) | both scenarios at `cb00a06` | FAIL for the reasons they name — the plan's RED condition |
| 2 | scenario 1 after the verdict function and the site | AC-1, AC-2, AC-3, AC-5 pass; AC-4, AC-6, AC-8 fail |
| 3 | after the regime fix (`c3ecd2f`) | unchanged pass/fail set; the baseline moves 42% → 25% n=20 |
| 4 | after the DATA-01 gate (`f47e190`) | AC-4 and AC-8 pass; the gate blocks two real defects in itself first |
| 5 | after the browser fixes (`e81242f`) | **both scenarios PASS** |
| 6 | `./scripts/test-loop.sh PDX-004` | **GREEN — ALL GATES PASS**, `e2e.sh` 7/7 |

**The browser scenario had never run, and that is the finding of this ticket.** DEV-01
says a claim about how something looks that was never rendered is a violation, and this
scenario was that violation with a green-looking preflight. Three defects, each failing in
the direction of looking fine:

- The probes import `playwright` by bare name from a scratch directory. Node resolves a
  bare specifier from the module file's location, not the working directory, so the
  scenario's `cd packages/site && node "$SB/probe.mjs"` never helped.
- The preflight guarded with `if (chromium)`. Playwright's entry is CommonJS, so
  `await import()` leaves the top-level binding undefined and the guard skipped the launch
  — then printed "chromium launches". **A green preflight for a browser that never
  opened.** It now fails on the undefined binding.
- With it running, contrast came back at 1.15:1 against a 4.5:1 floor. That was the probe,
  not the page: `getComputedStyle` does not promise `rgb()`, and this stylesheet's
  `color-mix` reports as `color(srgb 0.086 0.082 0.059 / 0.12)` — channels in 0..1, read
  as bytes — and a semi-transparent background was treated as opaque rather than
  composited. Colours are now resolved by painting them on a 1x1 canvas. Every contrast
  failure was arithmetic.

### 4.1 Final GREEN evidence

- `./scripts/test-loop.sh PDX-004`: **GREEN — ALL GATES PASS**
- verify (12 steps, DATA-01 at 7): **PASS (25s)**
- ticket e2e: both scenarios PASS
- regression `e2e.sh`: **7/7**
- golden set: **43/43**
- unit: `@plugdex/data` 42/42
- screenshots: `.docs/scratch/pdx-004-browser/{360x740,1280x800}-{light,dark}.png`

## 5. Non-Scriptable Verification (DEV-01)

| Item | Result | Notes |
|---|---|---|
| Real browser, both viewports, both schemes | **PASS** | Chromium via Playwright, four combinations, asserted mechanically rather than reviewed by eye: no horizontal scroll at 360px, distinct glyphs per verdict, every text pair at or above 4.5:1 (SC 1.4.3), the focus ring above 3:1 (SC 1.4.11), the two rates identical in computed style, keyboard open/close round trip |
| Screenshots written and non-empty | **PASS** | Four files, each asserted non-empty by the scenario |
| The chip legible without colour | **PASS** | Glyph distinctness asserted per verdict; DEC-018 keeps every hue to background and border |
| Whether the page reads as honest to a human | **Declared, not scriptable** | No gate can check that the masthead's account of the two conditions lands. It is stated in the page rather than in a footnote, and this is recorded as a judgement rather than a measurement |
| CI workflow on the runner | N/A | No workflow file changed |

## 6. Regression Check

`./scripts/e2e.sh` with no argument: **7/7**, including PDX-002, PDX-003, PDX-016 and
PDX-017. `check-gates.sh` 43/43. Nothing flaky, nothing skipped.

This branch was rebuilt from `main` after PDX-016 (`19bdbfc`) and PDX-017 (`62d76dd`)
merged, so it carries neither ticket's commits and the mid-cycle RED commits that used to
sit under it are gone. The old stacked tip is kept as the tag `pdx-004-preserved-red` so
the round log's early entries keep a reachable SHA.

## 7. Rules Verification

- **LANG-01**: PASS, in verify and at pre-commit on every commit.
- **DATA-01**: the rule this ticket makes real. Its own gate passes, and the first thing
  it blocked was this ticket's components.
- **DATA-02 / CLAIM-01**: no published figure moved by this ticket; the baseline changed
  because PDX-017 made a wrong one correctable, and DEC-020 records that.
- **GATE-01**: five new cases, both sides.
- **ASSERT-01**: the AC-6 assertion that refused to pass on an empty search is what
  surfaced the unsatisfiable criterion. It behaved exactly as the rule intends.
- **DEV-01**: §5, and the browser scenario that now runs.
- **REV-02 — the third plan-review round, justified here as the rule requires.** The cap
  is two rounds and the plan took three. The justification the plan gave, and which this
  report is obliged to carry: round 3's finding was not a new defect but an incomplete
  propagation of the fix round 1 demanded — the verdict-4 strike had been applied to the
  argument and not to the Steps table or the Test Plan — and it could not ride to the
  report stage, because the report would have been written about artifacts that still
  specified a verdict the plan had struck. The round was scoped to a diff-scoped re-check
  of the cited lines rather than a fresh review. Round 3 returned APPROVED_WITH_NOTES with
  0 blockers.

## 8. Risks / Notes

- **DEC-020 is a deviation from the approved plan, taken deliberately.** The plan was
  written when no regime field existed, so it specified a single pooled rate. PDX-017
  landing made the pooled rate visibly wrong rather than merely unavoidable, and shipping
  it would have published a condition that never ran. The alternative — holding the site
  until a new plan round — would have kept the wrong number on screen for longer.
- **AC-6 was corrected in place under CLAIM-01, and the correction matters beyond this
  ticket.** It required a card whose pack rate is at or below baseline's. No pack in this
  corpus is, in either condition. An assertion that needs the measurement to come out a
  particular way puts pressure on the measurement, which for this project is the one thing
  that must never happen. It now proves the property where it is a property of the code: a
  planted fixture page renders the card above and below baseline, a real Astro build runs,
  and the markup skeletons must match — identical skeletons mean no selector can key on
  the difference. The browser half pins what that cannot see.
- **The DATA-01 gate's allowlist is the thing most likely to rot.** Two exemptions are
  syntactic and safe (a comparison operand is a boolean; a slice-class argument is a
  position). The name-based layout vocabulary is spoofable in principle, and the standing
  procedure is that extending it requires a golden case in the same change — never a skip.
- **Site test files would currently trip the gate.** A dead `*.test.ts` under
  `packages/site/src` was blocked during this ticket, correctly by the letter of the rule
  and pointlessly in substance, since a test is never rendered. It was deleted rather than
  exempted, because an exemption needs a golden case and this ticket had no live test file
  to justify one. The next ticket that adds a site test must add the exemption and its
  case together.
- **`pdx-004-preserved-red` is a tag on a commit that is not on any branch.** It exists so
  the round log's RED entries resolve. It should be deleted when the report review is
  closed and the PR merged.

## 9. CR-01 Compliance

- Commits, branch rebuilds, the two merges, and the issue/PR submissions were made under
  the standing delegation the user gave for this project — an explicit instruction to
  commit and to keep working through the 9-stage design without stopping.
- No PR has been opened for this ticket yet. Nothing outside the repository was contacted
  beyond `gh` calls against this repository.

## 10. Agent Review

_(placeholder — review not yet written)_

### Reviewer
- Model:
- Reviewed at:

### Verdict
- [ ] APPROVED
- [ ] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

Every row must be scored PASS / FAIL / N/A with one line of concrete evidence.
Any FAIL row requires verdict NEEDS_REVISION (the gate rejects APPROVED + FAIL).

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | | |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | | |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | | |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | | |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | | |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | | |

### Comments
1.

### Blockers (only if NEEDS_REVISION)
-

## 11. Final Report Status

- Agent: _(pending)_
- Human: _(pending)_
