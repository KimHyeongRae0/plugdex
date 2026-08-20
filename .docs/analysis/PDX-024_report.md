# PDX-024 — implementation report

- Ticket: `.docs/tickets/PDX-024_site-a-listing-says-whether-it-installs.md`
- Plan: `.docs/analysis/PDX-024_plan.md` (APPROVED_WITH_NOTES, review round 3)
- Date: 2026-08-20
- Branch: `feat/pdx-024-a-listing-says-whether-it-installs`

## 1. Summary

The repository knew something the site did not say. `packages/registry/installability/caveman.json`
records `"outcome": "blocked"` with the verbatim CLI error, and the deployed page rendered an
`Install caveman` button and a **copy control** for `claude plugin install caveman@plugdex`.
That is not an omission — it is an affordance. The page handed a reader a command its own
receipt says fails.

It now says so in three places, each derived from the record rather than typed:

- **The card** carries `data-install-state` and a marker reading *does not install right now*.
- **The dialog** carries the recorded `verbatim` CLI error, and the copy control is withdrawn
  while the command stays visible.
- **The counts line** states how many listings install, how many do not, and the date of the
  oldest attempt behind that summary.

DEC-022's gap is disclosed in the same dialog: the button installs upstream **HEAD**, the
figures describe the commit plugdex measured, and both are printed with the installed version
where the CLI reported one.

Re-measured for this report with `./scripts/check-installability.sh`: **5 of 5 listings
reproduced their recorded state**, caveman still blocked (`kind=manifest-validation
keys=agents`) against upstream head `99a9aa2` — which is *newer* than the head the record
names (`6c5eea6`). The gap this ticket closes was live, not a stale record.

## 2. Files Changed

Built from `git status --porcelain` (**16 entries**) and `git diff`, checked row by row against
the diff rather than against memory. Two earlier revisions of this line were wrong — it said 11
when the tree held 12, and report review round 1 caught it; the count then moved again when the
round-1 fixes added `README.md` and `CLAUDE.md`. It is re-derived rather than adjusted.

| File | Change |
|---|---|
| `packages/registry/src/installability.ts` | **New**: `InstallState` (a three-way discriminated union), `installStateFor`, `shortCommit`, `InstallabilitySummary`, `summariseInstallability({ records })`, `installabilitySummary()`. The narrowing lives where the record lives so no component re-derives it, and `undefined` — which is what `installabilityFor` returns for an unmeasured pack — cannot be read as a boolean and render the flattering answer |
| `packages/registry/src/index.ts` | The six new exports and two new types |
| `packages/registry/src/installability.test.ts` | Four tests for the new exports, added after report review round 2 (§4.1) |
| `packages/site/src/components/PackCard.astro` | `data-install-state` on the card, and the marker. In delivery language, not quality language: DEC-021 keeps a blocked pack's card, figures and attribution, so this must not read as a verdict on the pack |
| `packages/site/src/components/InstallDialog.astro` | The blocked notice with the recorded `verbatim` in a `<pre>`; the copy control conditional on the state; DEC-022's HEAD-vs-measured paragraph carrying the measured commit, the recorded head and `installedVersion` |
| `packages/site/src/pages/index.astro` | Joins the two records per pack — `installStateFor` and `readSource` — and renders the counts line |
| `packages/site/src/styles/global.css` | The install-state marker, the blocked notice, the withdrawn-affordance label, the gap paragraph and the counts line. §5 records why this was not skippable |
| `tests/e2e/PDX-024-a-listing-says-whether-it-installs.sh` | **New.** §4 |
| `tests/e2e/PDX-004-the-catalogue-reads.sh` | The AC-6 fixture gains the two new `PackCard` props. §6 |
| `README.md` | The registry row corrected under CLAIM-01: it now states that not every listed pack installs and gives the count, and the Withdrawals section records the previous wording and its cause (AC-5) |
| `CLAUDE.md` | The same sentence, corrected the same way and naming `caveman` (AC-5) |
| `.docs/tickets/PDX-024_*.md` | Scope widened for the registry derivation; three corrections recorded under CLAIM-01 (§8) |
| `.docs/analysis/PDX-024_plan.md`, `.docs/receipts/PDX-024-plan-review.json` | The plan across three review rounds, and the receipt |
| `.docs/analysis/PDX-024_report.md` | This document |

## 3. Plan Compliance

Steps 1–8 landed as planned.

**Step 7 was deferred in an earlier revision of this report and the stated reason was false.**
That revision said `README.md` and `CLAUDE.md` were "outside this ticket's Scope.Allowed" and
belonged to PDX-033. The ticket's §2 Allowed names both files verbatim, the plan's §8 Feature
Tags tags them `docs`, and PDX-033 has no plan, no scenario and no implementation branch — so
nothing was landing first and AC-5 would have shipped unmet behind a scope claim the ticket
contradicts. (Precisely, corrected after report review round 2: a remote branch
`origin/docs/pdx-033-validity-claim-corrected` does exist. It is the merged branch of PR #17,
which corrected a wrong claim *inside* the PDX-033 ticket text; it is not an implementation
of PDX-033. An earlier revision of this paragraph said "no branch", which was false as
written.) Report review round 1 raised it as a blocker and it was right. Both
sentences are corrected here, and the README's Withdrawals section carries the CLAIM-01
record: the previous wording, that the records contradicted it from 2026-08-18, and that it
survived two days on the front door after that.

One addition beyond the plan: `packages/site/src/styles/global.css`. The plan's step list did
not name it, and after steps 3–6 the new elements rendered unstyled on a page that had just
been redesigned. §5 records how that was found.

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

From `.docs/state/PDX-024.state`, re-derived **last** rather than written first: **fourteen
stamps** — one `preflight`, one `plan-reviewed`, seven `test-case`, one `red`, four `green`.
Verified with `grep -c`, re-derived after the round-2 fixes rather than carried forward.

This line has now been wrong twice, and the cause is structural rather than careless. A round
log is written while the report is drafted, and the loops that fix the round's own findings
run *after* that — so it is stale by construction until it is re-derived at the end. Report
review round 1 caught the first miss (four `test-case` where there were five, with a
breakdown summing to nine rather than ten); the round-1 fixes then added two more stamps.
The same defect appeared three times on PDX-005. The remedy that would actually work is a
derived round log rather than a prose one, which is a harness change and not this ticket's.

| Round | Command | Result |
|---|---|---|
| 1 | `./scripts/check-test-case.sh PDX-024` | PASS (07:49:51) — the scenario exists and is executable before any implementation |
| 2 | `./scripts/test-loop.sh PDX-024 --red` | **RED OK** (07:50:39) — verify PASS on the untouched tree, PDX-024 FAIL. The failures were the right ones: 5 of 5 cards carried no state, no `installabilitySummary` export, no dialog carried a commit. **Both positive controls PASSED in the same run**, so the failing assertions were failing because the feature was absent rather than because the probes were broken |
| 3–5 | `./scripts/check-test-case.sh PDX-024` (07:52:47, 07:53:35, 08:01:46) | Two probe defects and one regression fix, each re-gated. The probe defects are recorded in §8; neither was an implementation defect |
| 6 | `./scripts/test-loop.sh PDX-024` | **GREEN** (08:07:37) — verify PASS, PDX-024 PASS, regression 11/11 |
| 7 | `./scripts/check-test-case.sh PDX-024` (08:53:20) | After the stylesheet work found in §5 |
| 8 | `./scripts/test-loop.sh PDX-024` | **GREEN** (08:58:43) |
| 9 | `./scripts/check-test-case.sh PDX-024` (09:20:07) | After report review round 1's two blockers: the AC-5 corrections to `README.md` / `CLAUDE.md`, and the agreement assertion plus its mutation control |
| 10 | `./scripts/test-loop.sh PDX-024` | **GREEN** (09:25:36) — between rounds 9 and 10 the round-1 mutation was reproduced deliberately: `karpathy.json` hidden and `installStateFor`'s `undefined` branch returning `installs`, which the new assertion **fails by name**; the tree was then restored and checked |
| 11–12 | `./scripts/check-test-case.sh` + `./scripts/test-loop.sh PDX-024` | **GREEN** (exit 0) — the tree this report describes. Carries report review round 2's notes: the four registry unit tests, and the correction to this report's own false "PDX-033 has no branch" sentence (§3) |

Two loops went red before round 6 and are recorded rather than smoothed over: `pnpm lint`
BLOCKed the formatting of `installability.ts`, and the regression BLOCKed on
`PDX-004-the-catalogue-reads.sh` (§6).

### 4.1 Final GREEN evidence

All re-run while writing this report:

- `./scripts/verify.sh` — **PASS (48s)**, all twelve steps
- `./scripts/e2e.sh` — **PASS 11/11**
- `@plugdex/data` — **78/78**; `@plugdex/registry` — **25/25**, four of them added after
  report review round 2 noted the six new exports had none. They pin the branch a scenario
  cannot reach cheaply: `installStateFor` over an empty record set returns `unmeasured` and
  carries no `record` field to read a verdict from; `summariseInstallability` reports the
  oldest of two stamps that **share a calendar date**, which is the trap AC-3 exists for,
  asserted at the source as well as in the page; and an empty record set is refused rather
  than summarised into an invented date
- The PDX-024 scenario's **ten** assertions, every one naming what it measured. Two were added
  after report review round 1 (see §8):
  - AC-1 (control): the state sweep reports a card that declares no install state
  - AC-1/AC-6: 5 cards, every one a legal state (`{'installs': 4, 'blocked': 1}`), both
    directions present
  - AC-1: 5 cards agree with their records (5 recorded, 0 unmeasured)
  - AC-1 (control): a card claiming `installs` for an unmeasured pack is reported
  - AC-2: 1 blocked listing carries the recorded error and offers no copy control; 4
    installing listings keep theirs
  - AC-3: 4 install, 1 blocked, oldest `2026-08-18T22:55:14Z` (newest
    `2026-08-18T22:57:08Z` — **the same date**, compared at full stamp)
  - AC-3 (direction): a record planted a year earlier becomes the reported oldest attempt
  - AC-4: 5 dialogs carry measured commit, upstreamHead and installedVersion; the two
    commits differ for `['caveman', 'mattpocock']`
  - AC-7 (control): the sweep reports a hardcoded pack id
  - AC-7: no pack id is typed into site source (sweep covers `'`, `"` and `` ` `` forms)

## 5. Non-Scriptable Verification (DEV-01)

| Row | Tool | Result |
|---|---|---|
| The blocked dialog as a reader meets it | Chromium over `astro preview`, 1440px, light and dark | **Checked, and it caught a defect no gate could.** After steps 3–6 every assertion passed and `grep -c` over `global.css` for the five new class names returned **0** — the notice, the marker, the withdrawn-affordance label, the gap paragraph and the counts line all rendered unstyled on a page redesigned the same day. A ticket whose point is that a reader is told cannot ship raw markup. The stylesheet is the fix; the screenshots are the evidence |
| The card | Chromium, 1440px | The figures, the chip and the attribution stay (DEC-021); the marker reads *does not install right now* in delivery language; the `--fail` hue appears only as a dot and never as text colour (DEC-018) |
| Horizontal overflow | Chromium, light and dark | No body-level horizontal scroll in either |
| The install command reproduces its recorded failure | `./scripts/check-installability.sh` | **5/5 reproduced**, caveman blocked against a *newer* upstream head than the record names — so the disclosure is current, not a stale record being defended |

## 6. Regression Check

`./scripts/e2e.sh` — **11/11**.

One scenario broke and was fixed rather than excused. `PDX-004-the-catalogue-reads.sh`'s AC-6
plants a fixture page that renders `PackCard` twice and compares the two skeletons; adding two
required props broke that build, and the scenario reported it as *"the fixture page did not
build"*. The fixture now passes both props, and **both cards are given the same install
state on purpose** — AC-6 asserts that the two *rates* are indistinguishable to a stylesheet,
so varying any other input would let the skeletons differ for a reason that assertion is not
about. The reason is written into the fixture.

## 7. Rules Verification

- **DATA-01 / DEC-017**: PASS. The truncations live in `@plugdex/registry` (`shortCommit`,
  `attemptedOn`) rather than in a template. Plan review round 3 reproduced
  `{r.upstreamHead.slice(0, 7)}` and `{r.attemptedAt.slice(0, 10)}` as BLOCKs against the
  gate's own regex while `{r.upstreamHead}` passed, so this was known before the code existed
  rather than discovered by the gate.
- **DATA-02**: PASS. No filename decides an install state; `loadInstallabilityRecords` already
  rejects a record whose `pack` disagrees with its filename.
- **DEC-021**: PASS. The blocked listing keeps its card, its four rates, its chip and its
  attribution. §5 records the visual check.
- **DEC-018**: PASS. The `--fail` hue is a dot and a border; every word a reader must read is
  ink.
- **DEC-022**: PASS. The gap is disclosed rather than closed — the ticket forbids pinning the
  install to the measured commit, and nothing here attempts it.
- **ASSERT-01**: PASS, and demonstrated. The two checks whose natural failure mode is silence
  each run against a planted violation first and must report it before their real run is
  believed. A zero-card page fails rather than satisfying every per-card check vacuously.
- **INST-01**: untouched. This ticket renders the record; it does not decide what makes one
  valid, and it wrote nothing under `packages/registry/installability/`.
- **LANG-01**: `./scripts/check-language.sh` PASS.

## 8. Risks / Notes

**Three corrections were made to this ticket's own text, and they share one cause.** The
ticket cited `MissingInstallabilityError` and `DESIGN.md:174` as though both were facts about
the shipped tree. Neither was: `grep -rn MissingInstallabilityError --include='*.ts' packages/`
returns nothing while the same grep for `MalformedInstallabilityError` returns five files, and
`DESIGN.md:174` says only *"PDX-024 is the ticket that tells them"* — the string `PDX-014` is
not on that line and `grep -c PDX-024 DESIGN.md` returns 1. Both claims came from
`.docs/analysis/PDX-023_plan.md`, which *proposed* the error class and said the roadmap *would*
pin the ordering. **A plan is a statement of intent, not a record of what landed**, and citing
one with a file:line is worse than saying "unverified" because it looks checked. The
corrections are left readable in the ticket rather than erased.

**The ordering against PDX-014 (deploy) is therefore a judgement, not a recorded decision.**
It is a defensible one — a catalogue whose front door offers a failing install should not be
advertised — but DESIGN.md carries no row saying so. Whoever wants it recorded owes one.

**Two probe defects, neither an implementation defect.** The AC-2 probe compared the recorded
`verbatim` against raw HTML, where the quotes and the `✘` glyph are entity-escaped; it now
unescapes first. The AC-3 probe captured the counts line up to the first child tag and read an
empty string; it now captures the whole element **and fails explicitly on empty text**, which
the first version would have passed on had the numbers not also been missing.

**AC-5 is closed, and the way it was nearly not is the finding.** An earlier revision of this
report deferred it to PDX-033 on a scope claim the ticket contradicts in as many words. Two
things made that possible: the deferral was written in prose that no gate reads, and the
overlap AC-5 itself anticipated ("whichever lands first satisfies it") gave it a place to
hide. A shared AC between two tickets needs a detector or it becomes a way for both to
believe the other did it — and PDX-033 has no implementation, so there was no other.

**Report review round 1's second blocker was a mutation test, and it found a real hole.**
The scenario proved every card stated *something* legal; it did not prove the card stated the
*right* thing. With `karpathy.json` hidden and `installStateFor`'s `undefined` branch mutated
to return `installs`, the page rendered a measured verdict for a pack nothing had measured and
the scenario still reported PASS. The implementation was correct — with only the record hidden
it rendered `unmeasured` — so nothing was broken; nothing was *protected* either. The
agreement assertion added in §4.1 derives the expected state from the record files
independently of the page, and the same mutation now fails by name: *"karpathy: renders
`installs` but its record says `unmeasured`"*, re-run and confirmed, with the tree restored
and `installability.ts` sha256-checked afterwards.

**What is still not said on the site.** A pack whose record is missing renders `unmeasured`,
but no listing is in that state today, so that branch is exercised only by the type system and
by the planted control, never by the live page.

## 9. CR-01 Compliance

- No commit / push / issue / PR / merge / release performed without explicit user instruction:
  **YES.** The user's standing instruction in this session delegates commit, push, issue, PR
  and merge for the ticket cycle; that delegation is what authorises the commit that follows,
  and it is the only thing that does.
- Nothing was published and nothing outside the repository was contacted in write mode.
  `check-installability.sh` clones from author repositories into a scratch config directory,
  which is a read.
- The working tree holds **16 entries**, all of them this ticket's. Nothing is held back and
  no second commit is needed.

## 10. Agent Review

### Reviewer

- Model: Opus 5
- Reviewed at: 2026-08-20 13:40

### Verdict

- [x] APPROVED_WITH_NOTES

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | PASS | Round 1's two blockers are closed against the tree, not against the claim. AC-5: `README.md:70` and `CLAUDE.md:17-21` are both modified in `git diff` and neither now says "makes every listed pack installable by name"; `README.md:109-117` carries the CLAIM-01 withdrawal, and every fact in it verifies — `caveman` is at `.claude-plugin/marketplace.json:9`, `packages/registry/installability/caveman.json` holds `outcome=blocked` at `attemptedAt=2026-08-18T22:57:08Z`, and my own `./scripts/check-installability.sh` run today returned "INST-01 PASS (5 listing(s), every recorded state reproduced)" with `caveman verdict=blocked-reproduced (kind=manifest-validation keys=agents)`. AC-1: I re-ran round 1's exact mutation (hid `packages/registry/installability/karpathy.json` **and** made `installStateFor`'s `undefined` branch return `{ state: 'installs', … }`) and `./scripts/e2e.sh PDX-024` now reports **FAIL** — "AC-1 (the rendered state agrees with the record): karpathy: renders `installs` but its record says `unmeasured`" — where round 1 got PASS 8/8. §5's four DEV-01 rows are all filled with a tool and a result; none is blank |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | PASS | `.docs/state/PDX-024.state` holds one `red` at `2026-08-20T07:50:39`, ahead of all three `green` stamps (`08:07:37`, `08:58:43`, `09:25:36`), and §4.0 round 2 names the RED failures (5/5 cards without a state, no `installabilitySummary` export) together with both positive controls passing in the same run, so the FAIL was absence-of-feature rather than a broken probe |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | PASS | §3's false scope claim is gone and is replaced by an accurate account of itself: the ticket's §2 Allowed does name both files verbatim ("`README.md`, `CLAUDE.md` — the two sentences that currently overstate installability") and `.docs/analysis/PDX-024_plan.md:118` does tag them `docs`, so §3's statement that the earlier deferral reason was false is itself true. The one addition beyond the plan (`packages/site/src/styles/global.css`) is disclosed in §3 with the reason §5 records. Two precision notes, neither load-bearing, are under Comments 2 and 4 |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | PASS | `git status --porcelain` returns **14** entries, matching §2 and §9; the table's 13 rows cover all 14 entries with nothing extra (plan + receipt share one row) and name nothing absent from the tree. Rules verified in the built page over `astro`-built `dist` in Chromium at 1440px: DEC-021 — the caveman card keeps its chip, its four `[data-rate]` elements and its "by Julius Brussee" byline; DEC-018 — the marker's colour is `rgb(14,17,22)` (ink) and the `--fail` hue `rgb(168,67,44)` appears only as the `::before` dot; DEC-022 — the dialog prints "measured `27d5a39`, recorded head `6c5eea6`"; DATA-01 — the truncations are `shortCommit` / `attemptedOn` in `packages/registry/src/installability.ts`, not slices in a template |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | PASS | `git log --oneline main..HEAD` is empty, HEAD is `9606a37` — the same commit as `main` and `origin/main` — all 14 entries are uncommitted working-tree changes, `.docs/drafts/` contains no `issue-pdx-024.md` or `pr-pdx-024.md`, and `.docs/receipts/` holds only the plan-review receipt for this ticket. This review performed no git mutation |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` → "LANG-01 PASS — no Korean text in repository artifacts"; `grep -cP '[\x{AC00}-\x{D7A3}\x{3130}-\x{318F}]'` returns 0 on each of the 14 changed entries and **1** on a planted Hangul file, so the zeroes are the pattern working rather than the pattern missing |

### Comments

1. **Round 1's two blockers are genuinely closed, and the second one was verified by re-running the mutation rather than by reading the fix.** Round 1 (2026-08-20 09:14, NEEDS_REVISION, R1 + R3 FAIL) found (a) AC-5 shipped unmet with `README.md:70` / `CLAUDE.md:18` byte-unmodified behind a §3 scope claim the ticket's own §2 Allowed contradicts, and (b) a planted flattering default — `karpathy.json` hidden plus `installStateFor`'s `undefined` branch returning `installs` — that the scenario reported PASS 8/8. On this tree the same mutation now fails by name, and the tree was restored byte-exactly afterwards: `packages/registry/src/installability.ts` back to sha256 `34e1185b…`, `karpathy.json` back to `0b96b56b…`, and `git status --porcelain` byte-identical to the pre-mutation capture (14 entries, same order). Round 1's other findings that were not blockers still stand and are carried below.

2. **The agreement probe cannot pass vacuously, and its control genuinely fires — both tested directly rather than inferred.** Lifting `agreement.py` out of the scenario and running it against four inputs: a page with `li.card` elements but no attributes → `{"ok": false, "detail": "no card carries both a pack id and a state"}`; a zero-byte page → the same failure; the planted `ghostpack` control page → `{"ok": false, "detail": "ghostpack: renders \`installs\` but its record says \`unmeasured\`"}`; the real `dist/index.html` → `{"ok": true, "detail": "5 cards agree with their records (5 recorded, 0 unmeasured)"}`. The shell wrapper inverts the control's exit status, so an always-`ok` probe would make the control row fail rather than pass. One residual worth naming, not blocking: the probe checks rendered → record and never record → rendered, so a card vanishing entirely would not be caught here — it would be caught by `blocked.py`, which requires a dialog for every record.

3. **§4.0's stamp count is now right, and its structural-cause argument is honest rather than an excuse.** Independently derived: `.docs/state/PDX-024.state` holds **12** lines — `1 preflight, 1 plan-reviewed, 6 test-case, 1 red, 3 green` — which is exactly what §4.0 claims, and the breakdown sums to 12 rather than to something else. Every timestamp in the rounds 1–10 table maps to a real stamp and the ten rounds account for all twelve stamps with none left over. The cause story checks out too: `.docs/analysis/PDX-005_report.md:249` records the identical diagnosis in the identical words ("the log is written before the loops that fix the round's findings, so it is wrong by construction until it is re-derived last"), and it was the third consecutive round there. A cause story attached to a still-wrong number would be an excuse; this one is attached to a number that re-derives, and it names the real remedy (a derived round log, a harness change). The one thing it does not do is file that harness change as a ticket, which is where the fix will get lost if nobody does.

4. **Two precision errors in prose whose conclusions are nevertheless true.** (a) §3 and §8 say PDX-033 has "no branch"; `origin/docs/pdx-033-validity-claim-corrected` exists (one commit, `f419105`), so the literal claim is wrong. It changes nothing: `git diff --stat main...` on that branch touches only `.docs/tickets/PDX-026_*.md` and `.docs/tickets/PDX-033_*.md`, contains no `README.md` or `CLAUDE.md` edit and no plan or scenario, so "nothing was landing first and AC-5 would have shipped unmet" is still true. Worth correcting the phrase to "no branch that touches these files" whenever the report is next opened; it is not worth a review round on its own. (b) §1's `99a9aa2` is verifiable and correct — `git ls-remote https://github.com/JuliusBrussee/caveman HEAD` returns `99a9aa2f5a45097fc3563febea7d0baf64407441`, distinct from the recorded head `6c5eea66…` — but nothing in the repository asserts it, so it is a prose figure that will go stale silently. The README withdrawal's version of the same claim ("against a *newer* upstream commit than the record names") is durable because it names no SHA.

5. **§2 and §9's tree count is correct in both places, re-derived.** `git status --porcelain` returns 14 entries; §2's 13 table rows cover all 14 (`.docs/analysis/PDX-024_plan.md` and `.docs/receipts/PDX-024-plan-review.json` share one row) and no row names a file absent from the tree. Round 1 found this figure wrong at "11 entries" when the tree held 12; it has now been re-derived rather than adjusted, and the count moved for the legitimate reason §2 states — the round-1 fixes added `README.md` and `CLAUDE.md`.

6. **Gates re-run clean on the tree as I found it, and again after the mutation was reverted.** `./scripts/verify.sh` PASS (45s, 12/12 steps, registry units 21/21); `./scripts/e2e.sh` PASS 11/11; `./scripts/e2e.sh PDX-024` PASS with all **ten** assertions, matching §4.1 row for row including the two added after round 1; `./scripts/check-installability.sh` INST-01 PASS 5/5. The scenario's assertion wording in the live run is identical to what §4.1 transcribes, so §4.1 is a transcript rather than a summary.

7. **The rendered page matches every §5 claim, checked in a real browser rather than read off the JSX.** Over `packages/site/dist` served statically, Chromium at 1440px: the five cards render `karpathy/installs`, `caveman/blocked`, `mattpocock/installs`, `ponytail/installs`, `superpowers/installs` with the caveman marker reading *does not install right now*; the counts line reads "4 of these listings install from this marketplace today; 1 do not … oldest attempt 2026-08-18"; the caveman dialog carries the styled blocked notice, the verbatim CLI error in a `<pre>`, "not offered — see above" in place of the Copy control, and the DEC-022 gap sentence. `document.documentElement.scrollWidth > clientWidth` is `false`. §5's first row is the load-bearing one and it is true: the five new class names are styled, not raw markup.

8. **Findings carried from round 1 that were never blockers and remain open.** (a) Six new exports still land with no line in `packages/registry/src/installability.test.ts`; `installStateFor` is now covered end-to-end by the agreement assertion, which is what closed blocker 2, but a unit test is still cheaper than a rebuild. (b) `offersCopy = state.state !== 'blocked'` in `InstallDialog.astro` still gives an `unmeasured` listing the full Copy affordance — no AC forbids it and no listing is in that state today, but AC-1's own sentence is "the default on missing data must not be the flattering one" and the dialog is where the reader acts. (c) The cosmetic space before the full stop — the dialog still reads "recorded head `6c5eea6` ." at 1440px, visible in the screenshot. (d) AC-5 is closed by hand and has no permanent detector; §8 names this gap itself, and plan §9 note (a) proposed the one-line `grep -F` assertion that would close it. None of these can let an AC ship unmet, which is why none is a blocker.

### Blockers (only if NEEDS_REVISION)

- None.

## 11. Final Report Status

- Agent: APPROVED_WITH_NOTES (round 2, 2026-08-20 — Opus 5; 0 blockers. Both round-1 blockers verified closed against the tree rather than against the claim: AC-5's two sentences are corrected with a CLAIM-01 withdrawal whose every fact re-checks, including a fresh `check-installability.sh` run reproducing caveman's blocked state today; and round 1's exact mutation was re-run and now FAILs by name, with the tree restored byte-exactly and sha256-confirmed. Independently re-derived: 12 state stamps matching §4.0's breakdown, 14 porcelain entries matching §2 and §9 with the table complete in both directions. Gates green — verify 12/12, e2e 11/11, PDX-024 10/10, INST-01 5/5, LANG-01 PASS — and the rendered page confirmed in Chromium at 1440px. Notes only: PDX-033 does have a branch (which touches no file this AC is about), §1's `99a9aa2` is correct but unasserted, and AC-5 still has no permanent detector. Round 1, 2026-08-20 09:14 — Opus 5, NEEDS_REVISION, 2 blockers: AC-5 shipped unmet behind a §3 scope claim the ticket's §2 Allowed contradicts, and a planted flattering default for an unmeasured pack passed the scenario 8/8)
- Human: _(pending)_
