# PDX-033 — implementation plan

- Ticket: `.docs/tickets/PDX-033_docs-every-published-claim-is-true-in-one-pass.md`
- Date: 2026-08-20
- Branch: `feat/pdx-033-every-published-claim-is-true`

## 1. What this closes, verified against the tree today

Six claims remain. Each was re-derived before this plan was written, and each is falsifiable
by a reader with a clone:

| # | Claim | Where | Falsified by |
|---|---|---|---|
| 2 | PDX-007's headline is "one number (68/69)" | `DESIGN.md:284` | `README.md:126` withdraws it; `bench/DERIVATIONS.md:153` — *"No pooling of the committed records produces 68 of 69"* |
| 3 | the priority-1 chip is keyed to the **as-shipped** regime | `DESIGN.md:327` | `index.astro` sets `REGIME = 'blocked'` and the loader filters there (`load.ts`), so the chip is computed over `blocked` cells whatever the row says. *(Corrected after plan review round 1: an earlier draft cited `:323` and said `verdict.ts` "has no regime filter", which is misleading — filtering is a load-time decision by design, and `verdict.ts` is correct not to repeat it.)* |
| 4 | "invalid cells are counted in the denominator, with their reasons" | `bench/README.md:186` | acceptance marks 88 invalid, results marks 7, over the same 93 `(task, arm, model)` keys — two predicates, one field name |
| 5 | "the 60-test backend suite runs on every probe", "four of eight caught" | `bench/README.md` | `grep -c pytest bench/harness/acceptance.py` → **0**; `gate_probes.py:82` runs it. Under the shipped gate it is **three** of eight |
| 6 | the premise: nobody checks whether delivered code compiles — **three wordings, not one** | `README.md:12`, `bench/README.md:7`, **`bench/README.md:3`** (that file's first line), its dependent sentence at **`:19`**, **`CLAUDE.md:10`**, and **`DESIGN.md:17-18` in paraphrase** — *"real measurements taken without checking that the delivered code compiles"* | two cited works were opened and do check execution; the surviving claim is narrower. *(Plan review round 1 found the second wording and round 2 found a third — `bench/README.md:3`, the **first line of that file**: *"Agent skill packs promise less code. Almost nobody checks whether it builds."* **A correction that greps a string corrects a string; the claim is what has to move**, and two review rounds each found one more place it had moved to.)* |
| 7 | the headline rate names no condition | `bench/README.md:42` | half-corrected on 2026-08-19 — the verb was fixed, the regime was not named |

Claim 1 closed by PDX-024, and its evidence has since inverted: caveman now installs. Claim 8
(mattpocock's null is an *activation* null) is a sentence this ticket writes; the derived field
that would prove activation stays in PDX-031.

## 2. Approach

**A correction is a record, not an edit.** CLAIM-01 requires the previous wording, its date, its
cause and its replacement to stay readable, so every one of these lands as a withdrawal entry
plus a corrected sentence — never as a silent rewrite.

**The locator is a marker, not an anchor.** PDX-035's `#withdrawal-scope` works because
`index.astro` emits HTML; five of these six claims live in Markdown, which has no anchors and
where "inside a correction block" cannot be decided by proximity. Each withdrawal therefore
opens with a machine-readable marker line — `<!-- withdrawal: <id> -->` — and the sweep decides
membership by marker rather than by distance. Plan review round 1 found the anchor mechanism
did not exist outside the one file that had it.

**Claim 3 is a decision, not a correction, and the plan takes a position.** `DESIGN.md:327`
and the code disagree about which regime the priority-1 chip is over. On the live corpus the
chip fires either way — superpowers is 1/41 under `blocked` and 0/9 under `as-shipped`, both
past the 80% threshold — so nothing published moves. **The spec is the side that is wrong**:
DEC-020 fixes the catalogue on one named condition and that condition is `blocked`, so a spec
row naming `as-shipped` describes a page this project decided not to build. The row is
corrected to `blocked` and the reason recorded. Review should challenge this if the opposite
reading is better; it is stated here rather than resolved silently.

**Claim 4's substance belongs to PDX-026 and only the sentence lands here.** The two record
kinds carry a field of the same name meaning two different things — acceptance's invalid
reasons are execution failures, results' are parse failures — and fixing that is a corpus
change PDX-026 owns. This ticket corrects the commitment to say what is true of the records as
they are, and states that the substance is owed.

**Claim 6 keeps the narrow claim, and cites what it read.** The premise is false as written and
the surviving version — no published work measures behaviour-norm packs with an execution-based
oracle — is defensible. Every citation must be opened and dated in `.docs/references/`, and one
that could not be opened is dropped or labelled unverified in the text itself.

## 3. Steps

| # | Step | Files | What it does |
|---|---|---|---|
| 1 | The withdrawal records | `packages/data/src/stats.ts` | Extend `ClaimWithdrawal` into a small list so each correction is a record with a date and a cause, rendered rather than typed (DATA-01: a date a reader reads is a figure) |
| 2 | Claims 2 and 3 | `DESIGN.md` | The withdrawn 68/69 removed from the roadmap row with its withdrawal noted; the priority-1 condition corrected to `blocked` with the reason |
| 3 | Claims 4, 5, 7, 8 | `bench/README.md` | The invalid-cell commitment; three-of-eight under the shipped gate; the regime named on the headline; the activation-versus-behaviour distinction |
| 4 | Claim 6 | `README.md`, `bench/README.md`, `.docs/references/` | The premise narrowed, with a dated reference entry per citation |
| 5 | The site's copy | `packages/site/**` | Any of the above that the built page carries, with the withdrawal reachable from the sentence (the PDX-035 shape) |
| 5b | **AC-3 — the condition named wherever a rate is, swept over built output** | `packages/site/**`, `bench/README.md` | Every surface carrying a failure or build rate names its condition in the same element, the way every rate already names its population (PDX-005 AC-2). This was the first item of plan review round 1's P4 blocker and the round-1 revision covered AC-4 through AC-10 without it — the same shape as the blocker itself: answering a list and missing an entry inside it |
| 6 | **AC-4 — the matched comparison** | `packages/data/**`, `bench/DERIVATIONS.md` | The shared tasks and arms, both rates, the per-task table and the failure-cause breakdown, matched on task **and** arm because the two conditions do not share their full sets. Derived, never typed |
| 7 | **AC-5, AC-6 — the regime-conditional effect and as-shipped's own limits** | `bench/README.md` | Both Fisher results with the mechanism, the alternative reading named rather than suppressed; and as-shipped's limits riding with it — smaller n, no `mattpocock` arm, and the blocked built-in skills. **The count is unsourced and must not be published as one**: "12 built-in skills" appears only in `PDX-032`, `PDX-033` and this plan — nowhere in the harness, the bench docs or the code. Plan review round 2 found it. Either the implementation sources it from the runner or the sentence states the fact without the number and says the count is unrecorded. Publishing an unsourced figure inside the ticket that exists to remove unsourced figures is the failure this row now prevents |
| 8 | **AC-7 — `PREREGISTRATION-3.md`'s outcome section** | `bench/PREREGISTRATION-3.md` | It has none today (`grep -c '^## Outcome'` → 0) while `bench/PREREGISTRATION.md:127` commits that *"Predictions that fail will be reported as failed"*. Its central prediction came out at 55% against a below-40% forecast and **failed** |
| 9 | **AC-8 — the dropzone denominator** | `bench/DERIVATIONS.md`, `bench/README.md` | `tmpl-fe-dropzone` was excluded by `PREREGISTRATION.md` and added back by `PREREGISTRATION-2.md`; it is 12/12 and moves the frontend rate on its own. The plan change is disclosed; its effect is not |
| 10 | **AC-9 — the clustering caveat** | `bench/DERIVATIONS.md` | The Fisher figures pool repetitions of one task as independent observations; the preregistration's task-unit rule was written for cost and duration, so this is a gap rather than a broken commitment. Stated as a limitation with the recomputation left to a ticket |
| 11 | **AC-10 — the superseded tickets say so** | `.docs/tickets/PDX-030,032,028,031` | Marked superseded or struck with a pointer here. Requires the ticket's Scope.Allowed to name `.docs/tickets/`, which plan review round 1 found it does not — the ticket is amended first |
| 12 | The scenario | `tests/e2e/PDX-033-*.sh` | §4 |

## 4. Test Plan

**RED condition**: `./scripts/test-loop.sh PDX-033 --red` — `verify.sh` PASS on the untouched
tree **and** the PDX-033 scenario FAIL, failing because the corrections are absent rather than
because a file is missing.

**GREEN condition**: `./scripts/test-loop.sh PDX-033` — verify PASS, PDX-033 PASS, regression
PASS, unit suites PASS.

| Claim | Assertion | Fails when |
|---|---|---|
| all | Each withdrawn wording appears **only** inside a correction block, delimited by `<!-- withdrawal: <id> -->` … `<!-- /withdrawal: <id> -->`. Membership is decided by the delimiters, never by distance — plan review round 2 found the opening marker alone leaves membership undefined for a multi-line block | a correction is made in one file and not another, or a quotation outside a block reads as a live claim |
| all | Each correction carries a date and a cause, re-read from the record rather than matched as prose | a withdrawal is a sentence rather than a record |
| 2 | `DESIGN.md` contains no un-withdrawn `68/69`; the scenario re-derives from `bench/data/runs/` that no pooling produces it, rather than trusting `DERIVATIONS.md` | the figure survives in the normative spec |
| 3 | The regime named in the priority-1 row equals the regime `index.astro` publishes, both read from their sources | the spec and the code disagree again |
| 4 | The corrected commitment's claim is re-derived: the scenario counts invalid cells in both record kinds and asserts the sentence matches what it finds | the sentence is true of one record kind only |
| 5 | `grep -c pytest bench/harness/acceptance.py` is 0 **and** the published probe count equals what the shipped gate catches — both re-derived, and the assertion FAILs if the grep returns nothing because the file moved | the published table credits a gate the benchmark does not run |
| 6 | Every citation in the premise paragraph has a dated entry in `.docs/references/`; an entry whose source was not opened is labelled unverified in the text | a citation this project cannot vouch for is made plainly |
| 7 | Every headline rate in `bench/README.md` names its regime in the same sentence | a rate is published without its condition |
| 8 | The activation sentence states both sides — karpathy's text in context 78/78, mattpocock's skills invoked 0/69 — re-derived from the records | the null is published as a behaviour null |
| 6 | **The claim, not the string.** The premise sweep matches the *paraphrase* as well — `DESIGN.md:17-18` says "real measurements taken without checking that the delivered code compiles" with none of the words an exact-phrase grep would find. The sweep therefore runs a list of claim-shaped patterns over all four files and FAILs on any hit outside a marked withdrawal | a correction greps a string and leaves the claim standing in other words — which is what plan review round 1 found this plan about to do |
| AC-3 | **Over built output**: every element carrying a rate also names its condition, swept the way PDX-005's population sweep works — an element with a percentage and no condition FAILs, and the sweep FAILs on an empty selection | a rate ships without its condition on the page a reader actually reads |
| AC-3 | The same sweep over `bench/README.md`'s rate sentences, by marker rather than by proximity | the page is corrected and the document is not |
| AC-4 | The matched comparison re-derives in the scenario: shared tasks and arms, both rates, and the `missing-dep` count going to zero, matched on task **and** arm | the comparison is published over unmatched sets, which is a different confound |
| AC-5 | Both Fisher results appear with their p-values re-derived from the records, and the alternative reading is present as text | the regime-conditionality is stated as a result rather than an interpretation |
| AC-6 | The three as-shipped limits are each present: a smaller n re-derived, the absence of a `mattpocock` arm re-derived from the cells, and the blocked built-in skills named | a limit is disclosed in a preregistration and nowhere a reader looks |
| AC-6 | **No bare skill count ships.** The sweep FAILs on a digit adjacent to "built-in skill" in any corrected file unless a citation follows it on the same line. Plan review round 3 found the previous row asserted only that the limits were "named", which the unsourced `12` would have satisfied — an assertion that a fact is *mentioned* does not test whether the fact is *sourced* | the ticket that removes unsourced figures publishes one |
| AC-7 | `bench/PREREGISTRATION-3.md` contains an `## Outcome` section naming its central prediction, the measured value, and the word `failed`; the scenario re-derives the measured value rather than trusting the text | a preregistration reports outcomes for rounds 1 and 2 and stops |
| AC-8 | The dropzone effect is stated and re-derived: the frontend rate with and without `tmpl-fe-dropzone`, both computed by the scenario | a prereg-excluded task worth ten points sits undisclosed |
| AC-9 | The clustering caveat names that repetitions are pooled as independent, and that no site figure depends on it — the second half asserted by checking no rendered figure calls the Fisher path | a limitation is stated so vaguely it cannot be acted on |
| AC-10 | Each superseded ticket carries a pointer to this one, and the scenario FAILs if a ticket this plan claims to supersede has no marker | a queue lists work already done |
| — | **ASSERT-01**: each grep asserts a non-empty capture before reading it; the file sweep FAILs if it matches zero files; and the absence assertions (claim 5's `pytest` count, AC-9's no-figure-depends check) each run a **positive control** first — a planted file that does contain the thing — so an absence is never reported by a sweep that has not been seen to speak | a path change makes the sweep prove nothing |

**Positive controls**: a planted file containing a withdrawn wording outside a correction block
must be reported; a planted `DESIGN.md` row naming the wrong regime must be reported.

## 8. Feature Tags

- `docs` — the corrections and the withdrawal records
- `data` — the withdrawal records as data
- `site` — any corrected sentence the built page carries

## 5. Risks

| Risk | Mitigation |
|---|---|
| Claim 3's position is wrong and the code should move instead | Stated in §2 as a position rather than resolved silently; the assertion checks the two agree, not which one changed, so either resolution passes |
| A correction weakens a claim into vagueness to avoid naming what was wrong | The ticket's Not Allowed forbids it, and each assertion checks the replacement states a specific fact rather than the absence of one |
| Six corrections in one pass is too much to review | Splitting is what created the problem: four separate cycles over the same five files, with a reader meeting a half-corrected story between them. The scenario asserts each independently so a reviewer can check them one at a time |
| The premise correction cites work nobody re-read | AC-2 requires a dated entry per citation and forbids citing a source that could not be opened |

## 6. Out of scope

Re-measurement of any cell. Writing under `bench/data/runs/**` (PDX-026, PDX-028, PDX-029).
The derived activation field (PDX-031). Widening coverage (PDX-036).

## 7. References Consulted

- `.docs/tickets/PDX-033_*` — Y, including the 2026-08-20 status re-derivation
- `DESIGN.md:284` (the withdrawn 68/69), `:327` (the priority-1 chip row), DEC-020 at `:177`, DEC-021, DEC-027, DEC-028 — Y, each opened at the line cited
- `bench/README.md:7`, `:42`, `:186`; `bench/DERIVATIONS.md:132`, `:153` — Y, read directly
- `bench/harness/acceptance.py`, `gate_probes.py:82,91` — Y, `pytest` count verified as 0 and 1
- `packages/data/src/verdict.ts` — Y, no regime filter present
- `PDX-024`'s withdrawal record in `README.md` — Y, the shape step 1 follows

## 9. Agent Review

### Reviewer
- Model: Opus 5
- Reviewed at: 2026-08-20 18:05

### Verdict
- [x] APPROVED_WITH_NOTES

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | The last uncovered AC now has a step: line 67 is step 5b, "AC-3 — the condition named wherever a rate is, swept over built output", over `packages/site/**` and `bench/README.md`, both granted by the ticket's Scope.Allowed at lines 38-40 and 33; AC-1 through AC-10 each map to a step (2/3/4/5 → AC-1, 4 → AC-2, 5b → AC-3, 6 → AC-4, 7 → AC-5/6, 8 → AC-7, 9 → AC-8, 10 → AC-9, 11 → AC-10) |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | Step 5b names one glob plus one file and is verifiable on its own through its two §4 rows at lines 97-98; the distribution is otherwise unchanged from round 2 — nine of thirteen steps name 1-3 concrete files, and the three globs (`packages/site/**`, `packages/data/**`) plus step 11's four mechanical ticket edits remain the only deviations |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | PASS | Unchanged and re-confirmed: DEC-020 at `DESIGN.md:177` ends "The page reports `blocked` … and says so in the masthead rather than in a footnote"; `index.astro:47` is `const REGIME = 'blocked'` and the built page renders it — `grep -o "Frontend build rate[^<]*" packages/site/dist/index.html` → "Frontend build rate · blocked condition", so §2's correction of `DESIGN.md:327` to `blocked` moves the spec toward the decision, not away from it |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | Round 2's blocker is closed: line 97 asserts "**Over built output**: every element carrying a rate also names its condition … an element with a percentage and no condition FAILs, and the sweep FAILs on an empty selection", line 98 carries the same over `bench/README.md` "by marker rather than by proximity". Both are real checks, not restatements — the mechanism they copy exists and works: `tests/e2e/PDX-005-the-analysis-reads.sh:366-434` returns `(problems, carriers, declared)` and lines 1054-1061 fail with "`{carriers} rate-carrying elements, fewer than the derived floor of {floor}`", which is the empty-selection guard AC-3 asks for, already running against built output |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | Unchanged from round 2: §5 lines 119-124 carry four risks with mitigations (claim 3's position, vagueness, six-in-one-pass, uncited work); §6 lines 128-129 defer re-measurement, `bench/data/runs/**` (PDX-026/028/029), the derived activation field (PDX-031) and coverage (PDX-036) by name |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` → "LANG-01 PASS — no Korean text in repository artifacts"; `grep -cP '[\x{AC00}-\x{D7A3}]'` over the plan and the ticket returns 0 for both, and the identical pattern returns 1 against a piped Hangul line (positive control, so the two zeros are real negatives) |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `./scripts/check-references.sh .docs/analysis/PDX-033_plan.md` → "PDX-033 has no mapped references (§6.5.1) — nothing required … REF-01 PASS"; §7's rows re-checked at the line cited — `DESIGN.md:284` is the PDX-007 "(68/69)" row, `:327` the priority-1 chip row, `:177` DEC-020, `gate_probes.py:82` runs `-m pytest` and `grep -c pytest bench/harness/acceptance.py` → 0 |

### Comments

1. **Round 1 (14:40, four blockers) and round 2 (16:20, one blocker), summarised so the history
   stays readable.** Round 1: **B1 [P1]** no steps for AC-4 through AC-10; **B2 [P4]** most ACs
   had no assertion and the "located by its anchor" locator existed only in `index.astro`;
   **B3** the withdrawn premise survived in `DESIGN.md:17-18` and `CLAUDE.md:10`, untouched by any
   step; **B4** AC-10 mandated edits under `.docs/tickets/` that Scope.Allowed forbade. Round 2
   verified B1, B3 and B4 fixed and B2 fixed for seven of its eight rows, and raised the eighth as
   its single blocker: **AC-3's built-output sweep had no step and no assertion**. That is closed
   below. Round 2 also listed six non-blocking items; five are closed and one is closed on the
   plan side only.

2. **The round-2 blocker is genuinely closed, and closed in the disclosed way.** Step 5b (line 67)
   does not quietly fill the gap — it records it: "This was the first item of plan review round
   1's P4 blocker and the round-1 revision covered AC-4 through AC-10 without it — the same shape
   as the blocker itself: answering a list and missing an entry inside it." That is CLAIM-01
   applied to the plan's own history, which is the standard this ticket is trying to hold the
   repository to. The two §4 rows are checks a scenario can fail: the built-output row names the
   failing element ("a percentage and no condition") and the guard ("FAILs on an empty selection"),
   and the second row extends it to `bench/README.md` by marker. The claim that this copies a
   working mechanism holds — PDX-005's sweep parses built markup, counts rate carriers, and fails
   below a derived floor, so AC-3's sweep is a variation on running code rather than a new idea.
   Target reality checked too: the page it will sweep already passes in part — `dist/index.html`
   renders "Frontend build rate · blocked condition" — so the RED will come from the rates that do
   not, which is the right failure.

3. **Five of round 2's six non-blocking items are fixed; each verified against the tree.**
   (a) `:323` is gone everywhere it was a live pointer — §2 line 38 and §7 line 134 now read
   `DESIGN.md:327`, the ticket's AC-1.3 (line 82) and its Edge Cases (line 178) likewise, and the
   only surviving `:323` outside the review history is §1's parenthetical, which is a record of
   what was wrong and must stay. (b) Step 8 (line 70) now cites `bench/PREREGISTRATION.md:127`;
   `sed -n '127p'` there is "Predictions that fail will be reported as failed", so the pointer
   resolves. (c) §4's first row (line 87) no longer says "anchor". (d) The marker is now a pair —
   `<!-- withdrawal: <id> -->` … `<!-- /withdrawal: <id> -->` at line 87 — with membership decided
   "by the delimiters, never by distance", which closes the multi-line block. (e) `bench/README.md:3`
   is named in §1's claim-6 row as the third wording, quoted in full.

4. **The fourth paraphrase does not exist — the premise universe is closed, and the check that
   says so was seen to speak.** Swept the whole tree outside `node_modules`/`.git` for claim-shaped
   wording — `(nobody|no one|almost nobody|few|none) …check`, `checks whether`, `without checking`,
   `check(ing) (that|whether) the delivered code (compiles|builds)`, `whether it (builds|compiles)`,
   `never check`, `unchecked`. Outside `.docs/` it returns exactly five live lines, and the plan
   already names all five: `README.md:13`, `CLAUDE.md:11`, `DESIGN.md:18`, `bench/README.md:8` and
   `bench/README.md:3`. The pattern is not asleep — the same run also hits
   `tsconfig.base.json:8` (`noUncheckedIndexedAccess`), `scripts/check-installability.sh:75` and
   four `.docs/` records, so the small live set is a real result. The built site carries none of
   it: `grep -rnoiE "we could find|without checking that the delivered code compiles|almost nobody
   checks|whether it builds|promise less code" packages/site/dist` returns nothing while
   `grep -rloi plugdex packages/site/dist` returns `index.html` and `analysis.html`, so the empty
   result is an absence and not a bad path. One dependent sentence is worth adding to the pattern
   list rather than hunting later: `bench/README.md:19`, "This repository measures what happens
   when you check", which presupposes the premise and reads wrong once the premise narrows. Not a
   fourth claim — it asserts nothing about other benchmarks — but it is in a file two steps already
   open.

5. **AC-6's unsourced count: the plan's wording does prevent it, the ticket's wording still
   mandates it, and §4 cannot catch either.** Step 7 (line 69) now quarantines the figure instead of
   publishing it — "**The count is unsourced and must not be published as one**: '12 built-in
   skills' appears only in `PDX-032`, `PDX-033` and this plan … Either the implementation sources it
   from the runner or the sentence states the fact without the number and says the count is
   unrecorded." That is a prohibition with two named exits, not a note, and it is the right fix on
   the plan side. Re-derived the absence: `grep -rn "built-in skill"` over the tree returns three
   `.docs/` hits and `bench/PREREGISTRATION-2.md:30` ("blocked built-in skills, repetition count"),
   which carries no count and no list, and a targeted search of `bench/`, `scripts/` and `packages/`
   for `disallowed|disable.?skill|blocked_skills|--disallowed` returns nothing while the same flags
   over `bench/harness` for `regime` return `fisher.py:18,67,106` — so the harness genuinely does
   not carry it. Two gaps remain, and both are in Blockers or Notes rather than in the rubric.
   First, §4's AC-6 row (line 101) is unchanged and still asserts only that "the blocked built-in
   skills [are] named", which passes whether the sentence says twelve, seven, or nothing — the
   prohibition is untested, and on this plan every other AC row re-derives its subject. Second and
   worse, the ticket's AC-6 (line 148) still states it as fact: "the runner blocks 12 built-in
   skills for every arm including `simplify` and `code-review`". An implementer satisfying the AC
   as written publishes the number the plan forbids, and the ticket's own Scope.Not Allowed (line
   57) forbids "Any figure typed rather than derived (DATA-01)" — an acceptance criterion its own
   ticket forbids, which is the exact shape round 1's B4 was raised about, one figure smaller.

6. **The `README.md:165` correction landed on the plan and not on the ticket.** Round 2 flagged
   that step 8 and the ticket's AC-7 both carried it. Step 8 is fixed; the ticket's AC-7 (line 153)
   still reads "`README.md:165` commits that 'Predictions that fail will be reported as failed'".
   `sed -n '160,170p' README.md` is the "Listing or removing a pack" section ending "a removal
   request is honoured without argument" — the commitment is not there, and
   `grep -rn "reported as failed"` returns exactly one line, `bench/PREREGISTRATION.md:127`. Same
   half-applied shape as the round-2 blocker, on the artifact that defines what "done" means.

7. **Two more stale pointers in the ticket, not previously reported, found while checking AC-1
   against the tree.** AC-1.2 (lines 77-78) cites `DESIGN.md:280` and `README.md:105`; the PDX-007
   "(68/69)" row is at `DESIGN.md:284` and the withdrawal at `README.md:126` — which is what the
   plan's §1 uses, so the plan is right and the ticket lags. AC-1.3 (line 83) cites
   `packages/site/src/pages/index.astro:28` for `const REGIME = 'blocked'`; `grep -n REGIME` puts it
   at `:47`. None of these changes what the ACs require, and none blocks RED, but a ticket titled
   "every published claim is true" carrying four wrong pointers is worth one editing pass while the
   file is open.

8. **The AC-3 sweep still wants the third positive control round 2 asked for.** Line 106's ASSERT-01
   row names two controls (claim 5's `pytest` count, AC-9's no-figure-depends check) and the
   Positive controls paragraph at line 108 names two planted files, neither of them a rendered rate
   with no condition beside it. The empty-selection guard at line 97 is the substantive half and it
   is present, so this is a note rather than a gap — but the planted-control list is where this
   project's ten vacuity failures were caught, and the new sweep is the one least exercised.

9. **Carried forward from rounds 1 and 2, still unaddressed, still not blocking.** §7's rows carry
   `Y` with no dates where `_PLAN_TEMPLATE.md` §8.5 asks for `Y (YYYY-MM-DD) — note`; §7 line 137
   still reads "`packages/data/src/verdict.ts` — Y, no regime filter present", the leg round 1 asked
   to drop (harmless as a record of what was opened, since §1 now carries the corrected inference);
   §2's "two cited works were opened and do check execution" still names neither work, which AC-2
   will force anyway; the plan has no §2 Scope Check and no §6 Rules / Decisions Applied, and its
   sections still run 1,2,3,4,**8**,5,6,7. None of this trips a gate — `./scripts/check-templates.sh`
   → "TMPL-01 PASS — 30 instance(s) match their templates", and `grep -n "analysis\|_PLAN_TEMPLATE"
   scripts/check-templates.sh` returns nothing, so plan documents are not template-gated.

10. **Nothing regressed.** Re-checked the round-2 confirmations rather than trusting them:
    `bench/README.md:186` is still method commitment 5, `bench/README.md:42` is still a rate row
    with no condition above the "55% of it fails its domain's gate" headline, `grep -c pytest
    bench/harness/acceptance.py` is still 0 against `gate_probes.py:82`, and `DESIGN.md:284`/`:327`
    hold. The plan is ready for RED once the ticket edit below is made.

### Blockers (only if NEEDS_REVISION)

- **Ticket revision needed (not a rubric FAIL — every rubric row PASSes and the plan itself is
  approved).** Logged here because the review contract requires a flawed ticket to appear under
  Blockers regardless of verdict. Three text fixes in
  `.docs/tickets/PDX-033_docs-every-published-claim-is-true-in-one-pass.md`, no re-planning: **(i)**
  AC-6 line 148 states the unsourced "12 built-in skills" as fact, which the plan's step 7 forbids
  publishing and the ticket's own Not Allowed line 57 forbids as a typed figure — reword it to the
  fact without the number, or source it; **(ii)** AC-7 line 153 cites `README.md:165` for a
  commitment that lives at `bench/PREREGISTRATION.md:127`; **(iii)** AC-1.2 lines 77-78 cite
  `DESIGN.md:280` and `README.md:105` (actual `:284` and `:126`) and AC-1.3 line 83 cites
  `index.astro:28` (actual `:47`). While the file is open, §4's AC-6 row in the plan (line 101)
  should assert the count is sourced or absent, so the prohibition is tested rather than trusted.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (Opus 5, 2026-08-20, round 3) — round 2's single blocker is closed:
  AC-3 has step 5b (line 67) and two §4 assertions (lines 97-98), the built-output sweep names its
  failing element and its empty-selection guard, and it copies a mechanism already running in
  `tests/e2e/PDX-005-the-analysis-reads.sh:1054-1061`. The gap is disclosed in the step rather than
  quietly filled. Five of round 2's six non-blocking items are fixed (`:323`, the
  `PREREGISTRATION.md:127` citation, "anchor" → marker, the closing delimiter,
  `bench/README.md:3`); the sixth — AC-6's unsourced "12" — is fixed in the plan and still stated as
  fact in the ticket. The premise hunt is closed: a claim-shaped sweep of the whole tree finds no
  fourth wording, and the built site carries none of it, both with positive controls. One ticket
  revision (three text fixes, listed above) before RED; no plan revision required, no rubric FAIL
- Human: _(pending)_
