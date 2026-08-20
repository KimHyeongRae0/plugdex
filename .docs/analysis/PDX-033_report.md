# PDX-033 — implementation report

- Ticket: `.docs/tickets/PDX-033_docs-every-published-claim-is-true-in-one-pass.md`
- Plan: `.docs/analysis/PDX-033_plan.md` (APPROVED_WITH_NOTES, review round 3)
- Date: 2026-08-20
- Branch: `feat/pdx-033-every-published-claim-is-true`

## 1. Summary

Six statements this repository published that its own records contradicted are corrected, each
as a CLAIM-01 record rather than a silent rewrite. They landed together because a reader who
arrives between corrections meets a half-corrected story, and because four of them share the
same five files.

| Claim | Was | Is |
|---|---|---|
| the premise | "in every published benchmark we could find, measured **without checking that the delivered code compiles**" — and *"Almost nobody checks whether it builds"* as `bench/README.md`'s first line | no published work grades **behaviour-norm packs** by whether the delivered code builds. The universal claim is withdrawn in all four files that carried it |
| 68/69 | `DESIGN.md`'s PDX-007 row stated the headline as "one number (68/69)" | the row names no figure. `bench/DERIVATIONS.md` proves none is derivable, and the scenario re-derives that over four poolings rather than trusting it |
| the chip's regime | the priority-1 row said "under the **as-shipped** regime" | `blocked`, which is what `index.astro:47` publishes and what DEC-020 fixes the catalogue on. The **spec** was wrong, not the code |
| probe count | "Four of eight injected defects passed every gate", under a sentence saying the 60-test suite runs on every probe | **five of eight pass** under the gate this benchmark ships, and three are caught. `grep -c pytest bench/harness/acceptance.py` is 0 while `gate_probes.py:82` runs it |
| PREREGISTRATION-3 | no outcome section, three days after the run | an outcome section: prediction 3 **failed** at 55% against a below-40% forecast |
| the skills count | "the runner blocks **12** built-in skills" | the fact without the number, because the number has no source anywhere in this tree |

## 2. Files Changed

Built from `git status --porcelain` (**14 entries**) and `git diff`, checked row by row.

| File | Change |
|---|---|
| `README.md` | The premise narrowed; the withdrawal record in the Withdrawals section |
| `bench/README.md` | The premise in two places including the file's first line; the probe count corrected to five passing of eight (three caught) with its withdrawal; the `pytest`-only row marked as a miss under the shipped gate |
| `CLAUDE.md` | The premise narrowed; the withdrawal record |
| `DESIGN.md` | The premise narrowed; the PDX-007 row's withdrawn 68/69 removed; the priority-1 chip row corrected to `blocked`; three withdrawal records |
| `bench/PREREGISTRATION-3.md` | The outcome section it never got, every figure re-derived |
| `.docs/references/README.md` | **New.** The six works this project opened, with dates and what each grades with — the evidence AC-2 requires for the premise correction |
| `packages/registry/installability/caveman.json` | Regenerated twice by real installs as upstream moved (§8) |
| `.docs/tickets/PDX-037_*.md` | **New ticket** carrying the analysis five plan steps did not produce (§3) |
| `.docs/tickets/PDX-033_*.md` | Scope widened for `.docs/tickets/`; corrections recorded (§8) |
| `tests/e2e/PDX-033-*.sh` | **New.** §4 |
| `.docs/analysis/PDX-033_plan.md`, `.docs/receipts/PDX-033-plan-review.json` | The plan across three review rounds, and the receipt |
| `.docs/analysis/PDX-033_report.md` | This document |

## 3. Plan Compliance

**Five of the plan's twelve steps did not land, and an earlier revision of this section said
they all did.** Report review round 1 found it: AC-3, AC-4, AC-5, AC-8, AC-9 and the
as-shipped half of AC-6 produced no change at all — `.docs/references/` was absent,
`grep -c as-shipped bench/README.md` returned 0, and `bench/DERIVATIONS.md` was untouched —
while §3 reported "Steps 1–12 landed, with one deviation".

Two things follow, and both are disclosed rather than repaired quietly.

**AC-2 is now done, because it had to be.** This ticket published *"We found no published work
that grades behaviour-norm packs by whether the code they deliver compiles"* — a claim about a
literature — with no record of what was read. Replacing one unsourced universal claim with
another is not a correction. `.docs/references/README.md` now records six works with the date
each was opened, what it grades with, and one line on whether it covers behaviour-norm packs;
the premise sentences link it. The record also states that it is not a systematic survey, which
is why the claim is worded "we found no published work" rather than "none exists".

**The analysis behind four corrections, and three claim corrections that produced no change,
move to PDX-037.** Report review round 2 found that claims 4, 7 and 8 were in *no* ticket at
all: PDX-033 absorbed them from PDX-031 and PDX-032, PDX-031's AC-3 is struck as "absorbed by
PDX-033", PDX-032 is superseded in whole, and the first draft of PDX-037 named none of them.
**Work that three tickets each believe another one owns is work nobody does**, and a
supersession marker is what makes that failure quiet. PDX-037 now names all three with the
evidence for each.

**The analysis half moves with them**, and the split line is the one that
justified merging in the first place. PDX-033's corrections all edit the same four prose files;
the matched comparison, the Fisher results, the dropzone denominator and the clustering caveat
derive new figures into `bench/DERIVATIONS.md` and the site. Reviewing new analysis beside a set
of sentence corrections helped neither, and PDX-037 carries it with the deferral named in its
own §1.

One further deviation, disclosed at first writing: **step 1's withdrawal records were not moved
into `@plugdex/data`.** The plan proposed extending `ClaimWithdrawal`
into a list so each correction is a rendered record, on the DATA-01 ground that a date a
reader reads is a figure. That applies to the *site*; five of these six corrections live in
Markdown, which the DATA-01 gate does not scan and which has no rendering layer to feed. The
records are written as delimited Markdown blocks instead, and the scenario reads them by
delimiter. Extending the data package would have bought nothing and coupled `bench/` prose to
a TypeScript build.

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

From `.docs/state/PDX-033.state`, re-derived **last**: **13 stamps** — one `preflight`, one `plan-reviewed`, 6 `test-case`, one `red`, 4 `green`.

| Round | Command | Result |
|---|---|---|
| 1 | `./scripts/check-test-case.sh PDX-033` | PASS — the scenario exists before any correction |
| 2 | `./scripts/test-loop.sh PDX-033 --red` | **RED OK** — verify PASS on the untouched tree, PDX-033 FAIL with seven live premise lines, the 68/69 in the spec, the spec/code regime disagreement, the four-of-eight count, and the missing outcome section. **Both positive controls passed in the same run** |
| 3 | `check-test-case` | After the corrections |
| 4 | `./scripts/test-loop.sh PDX-033` | **GREEN** — verify PASS, PDX-033 PASS, regression 13/13 |
| 5–7 | `check-test-case` ×3 | Report review round 1's seven blockers: the inverted probe count, the derived assertion replacing the string match, the AC-6 guard, predictions 4 and 5, `.docs/references/`, and the PDX-037 split |
| 8 | `./scripts/test-loop.sh PDX-033` | **RED** — regression FAILED on `PDX-003`: INST-01f fired because caveman's upstream moved a third time and the record named a version the install no longer produced (§8). Recorded rather than smoothed over |
| 9 | `./scripts/test-loop.sh PDX-033` | **GREEN** (exit 0) — after `record-installability.sh --pack caveman`. The tree this report describes. Round 3 found the table above listing four rounds where the state file holds nine cycles |

### 4.1 Final GREEN evidence

- `./scripts/verify.sh` — **PASS**, all twelve steps
- `./scripts/e2e.sh` — **PASS 13/13**
- `@plugdex/data` **83/83**
- The scenario's **eight** assertions, each naming what it measured (report review round 3 found this said nine, and the claim-5 bullet below stale — both re-derived by running it):
  - claim 6 (control): the premise sweep reports a planted paraphrase
  - claim 6: the premise is withdrawn in all 4 files that carried it
  - claim 2: 68/69 appears only inside a withdrawal block, and **none of 4 poolings produces it**
  - claim 3: spec and page agree on `blocked`, both read from their own source
  - claim 5: `acceptance.py` runs no `pytest`; **3 of 8 caught and 5 pass** under the shipped gate set, and the published sentence states the passed count — derived from `gate-limits.json`, not matched as a string
  - AC-6: no bare built-in-skill count is published without a citation beside it
  - AC-7: PREREGISTRATION-3 reports its outcome and names the failure
  - AC-10: every ticket this one supersedes says so

## 5. Non-Scriptable Verification (DEV-01)

| Row | Tool | Result |
|---|---|---|
| Do the corrections read as corrections | reading the four files | Each withdrawal states the previous wording, the date, the cause and the replacement. The cause is the part most easily skipped and it is present in all six: a pitch written before the survey, a withdrawal recorded where the figure was published rather than where it was specified, a validation harness stricter than the thing it validates, a preregistration that reported two rounds and stopped |
| The prediction outcome is honest about what it cannot say | re-derivation | Prediction 4 is reported **FAILED**: its condition is "Fails if any pack's build rate exceeds baseline's by 2 or more cells out of 3", baseline built 0 and ponytail built 2, so the trigger fired. The thin-sample caveat — baseline contributed one valid sonnet cell — stands beside the verdict rather than replacing it. **An earlier revision of this row said "undecidable" and survived §8's correction**, which report review round 2 caught: a report can contradict its own artifact when two sections are fixed at different times |
| The site is unaffected | `grep` over `packages/site/dist` | The built pages never carried the premise, so no page changed. Verified rather than assumed |

## 6. Regression Check

`./scripts/e2e.sh` — **13/13**. No scenario broke.

## 7. Rules Verification

- **CLAIM-01**: PASS. **Seven** delimited withdrawal blocks across four files, each with the
  previous wording, a date, a cause and a replacement, read by marker rather than by proximity.
  (Round 3 found this said six; the seventh is the second correction of the probe count, which
  is itself a record of a correction that was wrong.)
- **DATA-01**: PASS. No site source changed; the corrections are Markdown.
- **DEC-020**: the chip row now names the condition the catalogue publishes.
- **ASSERT-01**: PASS, and demonstrated. Both absence assertions carry positive controls — the
  premise sweep against a planted paraphrase, and the `pytest` grep against the file where
  `pytest` exists. An absence reported by a sweep that has not been seen to speak is not a
  finding.
- **NOLLM-01, LANG-01**: PASS.

## 8. Risks / Notes

**The premise was published in five wordings and two review rounds each found one more.** The
first draft grepped `every published benchmark`. Round 1 found `DESIGN.md:17-18` saying the
same thing with none of those words. Round 2 found `bench/README.md:3` — the **first line of
that file** — saying it a third way. **A correction that greps a string corrects a string.**
The scenario now sweeps claim shapes and is run against a planted paraphrase first.

**The ticket published an unsourced figure while existing to remove unsourced figures.** AC-6
stated "the runner blocks 12 built-in skills". Plan review round 2 found that number appears
only in `PDX-032`, in this ticket, and in the plan that inherited it from both — nowhere in the
harness, the bench documents or the code. It is now stated as a fact without a count, and the
scenario fails on a bare skill count with no citation beside it.

**A blocker was raised twice.** Round 1's P4 blocker listed AC-3 first; the round-1 revision
covered AC-4 through AC-10 and skipped it, so round 2 raised it again. That is the second time
in two tickets that a fix round answered the blocker list rather than the plan it was answering
to.

**Three of the plan's own citations were wrong** and are corrected in place: `DESIGN.md:323`
for the chip row (it is `:327`), `README.md:165` for the failed-predictions commitment (it is
`bench/PREREGISTRATION.md:127`), and "`verdict.ts` has no regime filter", which is true and
misleading — filtering is a load-time decision by design.

**Two numbers this ticket published were wrong before review caught them, and both flattered
us.** The probe correction first said *"three of eight injected defects passed every gate"* —
putting the **caught** count where the **passed** count goes. Under the shipped gate three are
caught and **five** pass; the sentence understated how much slips through. And the assertion
that let it through was `grep -qE '(three|3) of eight'`, a string match, where the plan had
committed to re-deriving from `gate-limits.json`. **A string match cannot tell a number from
the number beside it.** Both are fixed and the assertion now derives both counts.

The second: **prediction 4 was reported as "not decidable" when its own failure condition had
fired.** The condition reads *"Fails if any pack's build rate exceeds baseline's by 2 or more
cells out of 3"*; baseline built 0 and ponytail built 2. Softening a preregistered failure
because the sample is thin is precisely the move a preregistration exists to prevent — the
thinness was knowable when the condition was written. It is now reported as **FAILED**, with
the thin-sample caveat standing beside the verdict rather than replacing it. Prediction 5 was
missing from the section entirely and is now reported: caveman's tokens are 33% below baseline
on sonnet, against a published headline of −65%.

**caveman's upstream moved a third time during this ticket, and INST-01f caught it.** The
record named `702da5ce4c5e`; the install produced `a42ef766cede`. INST-01f is the rule for *a
pack that installs at a version the record does not name*, and it fired on a regression run
that was otherwise green. The record was regenerated by a real install and nothing else
changed, because every install state on the site is derived.

Three changes in one day is an operational fact worth writing down: **a live third-party
dependency goes stale on its schedule, not ours**, and the only reason that is survivable here
is that the gate re-measures rather than trusting. A benchmark that recorded install state once
would have been wrong within hours and had no way to know.

**Still open.** The substance behind claim 4 — that the two record kinds carry a field of the
same name meaning two different things — belongs to PDX-026 and is untouched here. PDX-036
owns widening the coverage PDX-035 states. Claim 8's derived activation field stays in PDX-031.

## 9. CR-01 Compliance

- No commit / push / issue / PR / merge / release without explicit user instruction: **YES.**
  The user's standing instruction in this session delegates them for the ticket cycle.
- Nothing outside the repository was contacted.
- The working tree holds **14 entries**, all this ticket's.

## 10. Agent Review

### Reviewer
- Model: Opus 5
- Reviewed at: 2026-08-20 21:05

### Verdict
- [x] APPROVED_WITH_NOTES  (report review round 3)

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | PASS | The three ACs that were in no ticket are now in one: PDX-037 §1 names claim 4 (`bench/README.md` commitment 5), claim 7 (`bench/README.md:41-42`, the headline that names no regime) and claim 8 (the activation null), each with its evidence, plus a "**These last three were nearly orphaned**" paragraph; I re-ran the cited evidence — `grep -c as-shipped bench/README.md` → 0 and `grep -ci activation bench/README.md` → 0, both non-vacuous (the same patterns return 6 in `DESIGN.md` and 17 in `.docs/tickets/PDX-031_*.md`), and commitment 5 is live and un-corrected. §5's three DEV-01 rows are all present and row 2 now attests **FAILED**, matching `bench/PREREGISTRATION-3.md:103` ("**FAILED** — the trigger fired") |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | PASS | `.docs/scratch/gate-runs.jsonl`: `19:27:02 e2e PDX-033 FAIL` with `test-loop:red PASS` (verify PASS on the untouched tree) precedes `test-loop:green PASS` at 19:35:45, 20:07:06 and 20:34:18; the 20:27:09 `test-loop:green FAIL` ("regression FAILED") is INST-01f firing, and the final GREEN at 20:34:18 postdates every changed file's mtime except this report (`caveman.json` 20:28:47, `bench/README.md` 20:20:46, ticket 20:21:11, PDX-037 20:21:35). I re-ran the whole stack myself: `./scripts/verify.sh` PASS (43s, 12/12) and `./scripts/e2e.sh` **PASS 13/13** with `PDX-033 PASS` on all 8 assertions |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | PASS | §3 discloses the five steps that produced no change, names report review rounds 1 and 2 as the finders, routes AC-3/4/5/8/9 and AC-6's remainder to PDX-037, and now carries a paragraph for AC-1's claims 4, 7 and 8 — "**Work that three tickets each believe another one owns is work nobody does**" — with the supersession markers named (`PDX-031` AC-3 struck, `PDX-032` superseded in whole). The DATA-01 deviation from step 1 is still disclosed with its reason. Nothing I could find changed without a disclosure |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | PASS | `git status --porcelain \| wc -l` = **13**, and every entry maps to a §2 row with no row naming a file outside the list. The probe count is now one noun everywhere and re-derives: intersecting each probe's `caught_by` in `bench/data/gate-limits.json` with the shipped gate set `{mypy, ruff, import, typecheck, build}` gives 3 caught (`be-type-error`, `be-syntax-error`, `fe-type-error`) and 5 passing (`be-owner-filter`, `be-sort-flip`, `be-off-by-one`, `be-swallow-404`, `fe-render-nothing`) — which is exactly what `bench/README.md:142` publishes, what its CLAIM-01 record at :152 states (with all eight probes enumerated by id on both sides at :153-156), what §1's *Is* column and §2's row say, and what ticket AC-1.5 says. The record's second paragraph (:158-167) now records that the first correction was itself inverted and in which direction ("putting the caught count where the passed count goes … understates how much slips through") |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | PASS | `git rev-parse HEAD main origin/main` all return `5a0d3cf`, `git log --oneline origin/main..HEAD` is empty, and `git reflog -5` shows only `checkout: moving from main to feat/pdx-033-every-published-claim-is-true` since PDX-035 merged; all 13 entries are uncommitted working-tree changes. This review ran no git mutation |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` → "LANG-01 PASS — no Korean text in repository artifacts", exit 0; `git ls-files -z \| xargs -0 grep -lP '[\x{AC00}-\x{D7A3}]'` is empty and the same pattern over the five untracked new artifacts is empty, while the pattern against a piped Hangul line returns 1 (positive control, so the empty results are real absences) |

### Comments

1. **Where the three rounds stand.** Round 1 raised seven blockers; round 2 confirmed four fixed by execution (B2 the string-matched assertion, B4 AC-6's unfireable guard, B5 the missing prediction 5, B6 the softened prediction 4, B7 the "six/seven" miscount) and raised three, all of them round-1 fixes applied to one surface and not the rest. **All three are closed.** I checked each by re-deriving from the artifact rather than reading the claim, and I did not re-litigate what round 2 verified.

2. **The inverted probe count is now one noun in every place it appears.** Derived independently from `bench/data/gate-limits.json` (three caught, five passing, ids above) and checked against all five surfaces round 2 listed: `bench/README.md:142` "**Five of eight** … pass every gate … three are caught"; the CLAIM-01 record at :152 "Under the shipped gate **three of eight are caught and five pass**", followed by the enumeration by probe id on both sides with `be-swallow-404` marked as the probe that moves; §1's *Is* column ("**five of eight pass** … and three are caught"); §2's row ("corrected to five passing of eight (three caught)"); and ticket AC-1.5 ("**three of eight are caught and five pass**; the published sentence must state the passing count"). The second withdrawal paragraph exists and names the direction of the error and the round that caught it. Sweeping the tree for "of eight" turns up no surviving instance where the caught count sits in a passed-count position outside a record of what was wrong.

3. **The near-orphaned three are in a ticket, and its evidence checks out.** PDX-037 §1 carries claim 4, claim 7 and claim 8 as named bullets, its Scope.Allowed includes `bench/README.md`, and its closing paragraph states the failure mode in the project's own terms. Two of the three evidence citations are exact and non-vacuous (greps above); the third, `bench/README.md:203` for commitment 5, is **stale by twelve lines** — the sentence is at `:215` after this ticket's own edits to that file. The quoted text is unique and correct, so it is a citation drift, not a wrong claim, but this repository has now recorded stale line citations three times in two tickets (§8's own "Three of the plan's own citations were wrong").

4. **§5's DEV-01 row is honest about having been wrong.** Row 2 reports prediction 4 as **FAILED** with the trigger re-stated (baseline built 0, ponytail 2, threshold 2 of 3), keeps the thin-sample caveat beside rather than in place of the verdict, and adds "**An earlier revision of this row said 'undecidable' and survived §8's correction**, which report review round 2 caught: a report can contradict its own artifact when two sections are fixed at different times". That is the named contradiction the blocker asked for, and it matches `bench/PREREGISTRATION-3.md:103` and :112.

5. **The two figures that were wrong in five consecutive tickets are right, re-derived last.** `.docs/state/PDX-033.state` holds exactly **11** stamps — 1 `preflight`, 1 `plan-reviewed`, 5 `test-case`, 1 `red`, 3 `green` — matching §4.0's sentence token for token; `git status --porcelain | wc -l` is **13**, matching §2 and §9.

6. **The third upstream move is recorded and re-measured, not asserted.** `packages/registry/installability/caveman.json` now names `a42ef766cede` on both `installedVersion` and `upstreamHead`, which is what §8 says the install produced. I ran `./scripts/check-installability.sh`: **INST-01 PASS**, 5 listings, caveman "installs, as recorded" — and the check is live rather than carried, because `check-installability.sh:140-160` re-measures the version and raises INST-01f on a mismatch (the same rule that failed the 20:27:09 GREEN attempt in `gate-runs.jsonl` before the record was regenerated). The CLI-version NOTICE names four other packs and is not this ticket's.

7. **Note — §4.0's round table under-reports the rounds its own sentence counts.** The sentence reconciles exactly to 11 stamps (5 `test-case`, 3 `green`), but the table lists four rounds with two `check-test-case` entries and one GREEN. Missing as rows: the `19:24:50 check-test-case FAIL` that round 1 flagged, the round-2 fix cycle (`20:01:35` / `20:07:06`), and the round-3 fix cycle including the INST-01f regression FAIL at `20:27:09` and the re-green at `20:34:18` — which is the most interesting round in the log, since it is the gate catching a live dependency drift mid-ticket. The TDD claim is not affected; the log is just shorter than the history it summarises.

8. **Note — three residual count/wording drifts, each carried over from round 2 unfixed.** (a) §4.1 says "nine assertions"; the scenario prints eight, and its claim-5 bullet still reads "the published count says three of eight" where the scenario now prints "3 of 8 caught and 5 pass … and the published sentence states the passed count" — the one place left in this document where "three of eight" sits next to the words "the published count". (b) §7's "Six withdrawals" counts corrections, not blocks: there are **seven** delimited blocks over four distinct claims (`premise` ×4, `probe-gate-set`, `chip-regime`, `sixty-eight-of-sixty-nine`). (c) §3 says "the premise sentences link it", but only `README.md:12` and `bench/README.md:7` carry the link to `.docs/references/README.md`; `CLAUDE.md:9` and `DESIGN.md:18` carry the narrowed premise with no link.

9. **Note — PDX-037 names the three in its Goal but writes no AC for two of them.** Its §3 has ACs for the matched comparison, the regime-conditionality, the as-shipped limits, the dropzone, the clustering caveat, the built-page condition sweep and the withdrawal rule — none of which is the invalid-cell sentence (claim 4) or the activation sentence (claim 8), and AC-6 scopes the condition sweep to "every rate on a **built page**" while claim 7's surviving surface is `bench/README.md:41-42` prose. Naming work in a Goal is strictly better than the ticket-gap that produced this blocker, and PDX-037 has its own ticket-review gate ahead of it, so this is a note rather than a blocker — but it is the same failure one level down, and the fix is three lines in §3.

10. **Note — PDX-033's own ACs are not struck where the work moved.** ACs 3, 4, 5, 8, 9 and AC-1's sub-claims 4, 7 and 8 are delivered by PDX-037, but the ticket still lists them as its own, unmarked; only its §1 line 29 mentions that "the analysis behind four of them moves to PDX-037". Nothing false is asserted — `Status: TODO` with all ten boxes unticked — but this repository already has the convention that closes this gap: `PDX-031` AC-3 is struck as "Absorbed by PDX-033 AC-1.8". Striking the moved ACs with "Deferred to PDX-037" would make the ticket readable on its own, which is what AC-10 asks of every other ticket in the chain. Related and minor: ticket AC-1.4 still cites `bench/README.md:186` for commitment 5, now at `:215`.

11. **The ticket is otherwise sound and no revision is required to close this gate.** Goal, Scope.Allowed/NotAllowed and the ten ACs are objectively verifiable, the edge cases map to the scenario, and the scenario carries a positive control for every absence assertion it makes (ASSERT-01) — the premise sweep against a planted paraphrase, the AC-6 guard against a planted bare count, the `pytest` grep against the file where `pytest` exists. Every absence I relied on in this review carries its own control, recorded in the rubric rows above.

### Blockers (only if NEEDS_REVISION)

- None.

## 11. Final Report Status

- Agent: APPROVED_WITH_NOTES (Opus 5, 2026-08-20, report review round 3) — zero blockers, down from seven in round 1 and three in round 2. All three round-2 blockers are closed and each was checked by re-deriving from the artifact: the probe count is one noun on all five surfaces (`bench/README.md:142` live sentence, its CLAIM-01 record at :152 with all eight probes enumerated by id on both sides and a second paragraph recording that the first correction was itself inverted and in which direction, §1, §2, ticket AC-1.5), and it matches `bench/data/gate-limits.json` intersected with the shipped gate set — 3 caught, 5 passing; AC-1's claims 4, 7 and 8 are carried by PDX-037 with the near-orphaning disclosed in §3, and its cited evidence re-runs (`grep -c as-shipped bench/README.md` → 0, `grep -ci activation bench/README.md` → 0, both with positive controls); and §5's DEV-01 row reports prediction 4 as FAILED and names the contradiction it used to carry. The figures wrong in five prior tickets are right and re-derived last: 11 stamps (1 preflight, 1 plan-reviewed, 5 test-case, 1 red, 3 green) and 13 working-tree entries. caveman's third upstream move is recorded rather than asserted — the record names `a42ef766cede`, and I re-ran `check-installability.sh` → INST-01 PASS with the version re-measured. I re-ran the stack: `verify.sh` PASS (12/12), `e2e.sh` **PASS 13/13**, `PDX-033 PASS` 8/8, `check-test-case` PASS, LANG-01 PASS with a positive control, CR-01 intact (`origin/main..HEAD` empty, HEAD = main = origin/main = `5a0d3cf`). Notes only, none blocking: §4.0's round table lists four rounds where the log holds seven cycles including the INST-01f regression FAIL; §4.1's "nine assertions" and its stale claim-5 bullet; §7's "six withdrawals" against seven blocks; two of four premise sentences do not link `.docs/references/`; PDX-037 names claims 4 and 8 in its Goal without an AC and cites `bench/README.md:203` for a sentence now at :215; and PDX-033's moved ACs are not struck the way `PDX-031` AC-3 is
- Human: _(pending)_
