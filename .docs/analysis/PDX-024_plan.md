# PDX-024 — implementation plan

- Ticket: `.docs/tickets/PDX-024_site-a-listing-says-whether-it-installs.md`
- Date: 2026-08-20
- Branch: `feat/pdx-024-a-listing-says-whether-it-installs`

## 1. What this closes, stated as it is today

The site currently renders, for every listing including the one that does not install:

```html
<button class="install" data-install-trigger data-dialog="install-caveman">Install caveman</button>
<dialog id="install-caveman">
  <code>claude plugin install caveman@plugdex</code>
  <button class="copy" data-copy-command="claude plugin install caveman@plugdex">Copy</button>
```

That is not an omission, it is an affordance: the page offers a copy button for a command
the repository's own record says fails. Re-measured on this branch with
`./scripts/check-installability.sh` — `caveman — blocked, and the recorded failure
reproduces (kind=manifest-validation keys=agents)`, against upstream head `99a9aa2`
(2026-08-19), which is **newer** than the head the record names (`6c5eea6`, 2026-08-18).
Upstream changed `agents` to an array of file paths and the CLI still rejects it. So the
record is not stale, and the gap this ticket closes is live.

The other four listings install as recorded. INST-01 PASS, 5 of 5 reproduced.

## 2. Approach

The record already exists and the API already exports what renders it
(`installabilityFor`, `packages/registry/src/installability.ts:160`). Nothing needs to be
measured or generated. This is a rendering ticket with one hard rule attached: the site must
never *state* an install state it did not *read*, which is the same discipline DATA-01
applies to figures, applied to this fact.

**One join is needed, and an earlier draft of this section denied it.** That draft said
"nothing needs to be measured, generated, or joined", which is false of AC-4: the measured
commit is not on the installability record. `InstallabilityBase` carries pack, repo,
cliVersion, attemptedAt, upstreamHead and transport. The measured commit lives in
`packages/registry/attribution/<pack>/source.json` (caveman's is `27d5a39…`) and is reached
through `readSource`. AC-4 therefore joins the two records by pack id, and §4 asserts all
three values rather than the one that happens to be nearest.

**Round 2 caught this claim before the code existed.** An earlier revision of this section
said "§4 asserts all three values" while §4 still asserted only `upstreamHead` — the design
was corrected and the assertion table was not, so the plan vouched for a check that did not
exist. Per REV-02 this is logged as an incompletely applied round 1 fix rather than a new
design finding, and it is the second time in this cycle that a fix's own claim outran the
artifact it described.

Three structural choices, each with its reason:

**The card carries the state, the dialog carries the receipt.** A reader scanning the grid
needs one glance; a reader about to run the command needs the verbatim error. Splitting them
means neither surface has to be a compromise, and AC-2's requirement ("a reader who reaches
the install dialog without scrolling past a banner must still be told") is satisfied
structurally rather than by hoping the banner is seen.

**A missing record renders as an absence, never as installable.** `installabilityFor`
returns `undefined` for an unmeasured pack. The default on missing data must not be the
flattering one, so the type is narrowed at the boundary and the "installs" branch is
reachable only from an `InstallsRecord`.

**No pack id appears in an install-state expression in site source.** AC-7. A hand-kept list
of which packs work is exactly how the site would drift from the record it publishes, and a
grep in the e2e is what keeps that true after this ticket.

## 3. Steps

| # | Step | Files | What it does |
|---|---|---|---|
| 1 | The state, named once | `packages/registry/src/installability.ts` | Add `installStateFor({ packId })` returning a discriminated `{ state: 'installs' \| 'blocked' \| 'unmeasured' }` plus the fields each state carries. The three-way narrowing lives in the package that owns the record, so no component re-derives it and `undefined` cannot be read as a boolean. Exported from `index.ts` |
| 2 | The counts line, derived | `packages/registry/src/installability.ts` | `installabilitySummary()` → installs count, blocked count, and the **oldest** `attemptedAt` among the records. Oldest, not newest: a mixed-age summary presented as current is a figure without its denominator (AC-3) |
| 3 | The card states it | `packages/site/src/components/PackCard.astro` | A `data-install-state` attribute and a visible marker. Blocked is not styled as an error chip competing with the verdict chip — DEC-021 keeps the measurement and its figures, and a red card would read as "the pack is bad" rather than "the current upstream does not install" |
| 4 | The dialog carries the receipt | `packages/site/src/components/InstallDialog.astro` | For a blocked record: the state, the verbatim CLI error in a `<pre>`, and the install command **still shown but not offered as a copy affordance**. Removing the command entirely would hide what was attempted; keeping the copy button would keep handing out a failing command |
| 5 | DEC-022's gap, in the dialog | `packages/registry/src/installability.ts`, `packages/site/src/components/InstallDialog.astro` | The button installs upstream **HEAD**; the figures describe the measured commit; those may differ. All three shown: the measured commit **joined from `readSource`** (`packages/registry/attribution/<pack>/source.json`, not on the installability record — plan review round 1's B2), the recorded `upstreamHead`, and `installedVersion` where present. The join and any truncation of a SHA or a date happen in the registry package: round 1 reproduced `{r.upstreamHead.slice(0, 7)}` and `{r.attemptedAt.slice(0, 10)}` as DATA-01 BLOCKs against the gate's own regex, so a truncation written inline in a template does not survive the gate (AC-4) |
| 6 | The counts line on the page | `packages/site/src/pages/index.astro` | Rendered from step 2, with its date. Renders at zero blocked too — a disclosure that vanishes when the news is good is one a reader learns to distrust |
| 7 | The two overstating sentences | `README.md`, `CLAUDE.md` | AC-5, under CLAIM-01. Coordinated with PDX-033 AC-1.1: whichever lands first satisfies it, the second records that it was already closed |
| 8 | The scenario | `tests/e2e/PDX-024-a-listing-says-whether-it-installs.sh` | §4 |

## 4. Test Plan

**RED condition** (before step 3): `./scripts/test-loop.sh PDX-024 --red` — `verify.sh` PASS
on the untouched tree **and** the PDX-024 scenario FAIL. The scenario must fail because no
card carries `data-install-state`, not because the file is missing or the build is broken;
the first assertion therefore builds the site and greps the emitted HTML, so a FAIL from a
broken build is distinguishable from a FAIL from a missing attribute.

**GREEN condition**: `./scripts/test-loop.sh PDX-024` — verify PASS, PDX-024 scenario PASS,
full regression PASS, `@plugdex/data` and `@plugdex/registry` unit suites PASS.

Assertions, all over **built output** (`packages/site/dist`), never over source:

| AC | Assertion | Fails when |
|---|---|---|
| 1 | Every `.card` carries `data-install-state` ∈ {installs, blocked, unmeasured}; the count of cards with the attribute equals the count of cards | a listing renders without a state |
| 1 | An unmeasured pack renders `unmeasured`, planted by hiding a record file in a scratch copy | the missing case defaults to installs |
| 2 | The card whose record says blocked renders `blocked`, and its dialog contains the record's `verbatim` string | the receipt is claimed but not shown |
| 2 | No `data-copy-command` exists inside a dialog whose card is `blocked` | the failing command keeps its copy affordance |
| 3 | The counts line re-derives from `packages/registry/installability/*.json` — installs, blocked, and the oldest `attemptedAt` — computed independently in the scenario and compared to the rendered text | the line is typed or stale |
| 3 | **The oldest/newest distinction is asserted at timestamp granularity, not date.** On the live corpus every record was written inside one two-minute window — oldest `2026-08-18T22:55:14Z`, newest `2026-08-18T22:57:08Z`, **the same calendar date** — so a date-level comparison passes even when the newest is rendered by mistake. The scenario therefore asserts against the full ISO timestamp, and additionally plants a scratch record dated a year earlier and asserts the rendered line moves | the page renders the newest and nobody notices, which is exactly what the live corpus would have allowed |
| 4 | Each dialog contains its record's `upstreamHead`, and the HEAD-vs-measured sentence | DEC-022's gap is implied rather than stated |
| 4 | **All three values, each re-derived from its own file.** The scenario reads `upstreamHead` from `packages/registry/installability/<pack>.json`, the **measured commit** from `packages/registry/attribution/<pack>/source.json` (`commit` — caveman's is `27d5a39…`, the file `readSource` reads), and `installedVersion` from the installability record where the outcome is `installs`. Each must appear in that pack's dialog in the built HTML. The two files are read separately in the scenario so a join that silently drops one side cannot pass | the join renders the value that happens to be nearest and the missing half ships green — AC-4's own words, and the shape plan review round 1 raised as B2 |
| 4 | **The measured commit and `upstreamHead` are asserted to be different for at least one pack**, and the scenario FAILs if no pack differs | the disclosure is untestable because the two values coincide, which is exactly the state DEC-022 says lasted one day before it stopped being true |
| 6 | **Both directions**: at least one `blocked` card and at least one `installs` card exist, and the scenario FAILs if either count is zero | the corpus changes such that the test proves nothing |
| 6 | **ASSERT-01**: the card selection is asserted non-empty before any per-card check runs | a selector typo passes vacuously — this project has produced that shape seven times |
| 7 | **Pack ids are derived, and the check has a positive control.** The id list comes from `entries` at scenario runtime rather than being typed (PLAN-01: a hardcoded roster goes stale the day a pack is added). The sweep covers single-quoted, double-quoted and template-literal forms. And it runs **twice**: once against a planted file that *does* hardcode an id, asserting the sweep reports it, and once against `packages/site/src`, asserting it reports nothing. CLAUDE.md names "PDX-002's AC-7 grep" as ASSERT-01 instance one — a grep whose empty output was read as proof — so this one is not trusted until it has been seen to fire | a pack id is hardcoded into a state expression, **or** the sweep is silently broken |
| 5 | The two overstating sentences carry a CLAIM-01 record, or the report states that PDX-033 closed them first and cites the commit | AC-5 has no detector and both tickets assume the other did it |

**Negative control, run and recorded in the report**: flip a record's `outcome` to
`installs` in a scratch copy, rebuild, and confirm the blocked assertions FAIL. A check
never observed failing is not evidence.

## 8. Feature Tags

- `site` — the card state, the install dialog's receipt and disclosure, the counts line
- `registry` — the three-way state and the summary, derived where the record lives
- `docs` — the two overstating sentences in `README.md` and `CLAUDE.md` (AC-5)

## 5. Risks

| Risk | Mitigation |
|---|---|
| The blocked card reads as "this pack is bad" rather than "the current upstream does not install" | Step 3 keeps the verdict chip, the figures and the attribution (DEC-021 requires all three); the state marker uses delivery language, not quality language, and the report records the exact wording |
| Removing the copy button is read as hiding the command | Step 4 keeps the command visible and drops only the affordance, and says why in the dialog |
| The scenario passes because the corpus happens to contain a blocked pack today | The both-directions assertion FAILs at zero of either kind, so a corpus change breaks the test loudly instead of quietly weakening it |
| Overlap with PDX-033 AC-1.1 produces a double edit or a missed one | Step 7 names the coordination explicitly and the report states which ticket closed it |
| `installStateFor` duplicates `installabilityFor` | It narrows rather than duplicates; `installabilityFor` stays and is what step 1 is built on |

## 6. Out of scope

Running an install (`scripts/record-installability.sh` owns that), changing INST-01,
re-ranking or hiding a blocked listing, pinning the install to the measured commit
(DEC-022 records why that is unavailable), and the methodology page (PDX-025).

## 7. References Consulted

- `.docs/tickets/PDX-024_*` — Y, the ticket as written 2026-08-20
- `.docs/tickets/PDX-023_*` AC-3 — Y, the split that created this ticket and the handover list
- `.docs/analysis/PDX-023_plan.md` §3, step 2 — Y, names `installabilityFor` as "the API PDX-024 renders from"
- `DESIGN.md` DEC-021, DEC-022 — Y, read in full; DEC-021 requires the blocked pack keeps card, figures and attribution; DEC-022 records why pinning is unavailable
- `packages/registry/src/installability.ts` — Y, read in full; record types at :29–57, `installabilityFor` at :160
- `packages/site/src/components/{PackCard,InstallDialog}.astro`, `pages/index.astro` — Y, read in full
- `./scripts/check-installability.sh` — Y, **run** on this branch; 5/5 reproduced, caveman still blocked against a newer upstream head

## 9. Agent Review

### Reviewer

- Model: Opus 5
- Reviewed at: 2026-08-20 14:05

### Verdict

- [x] APPROVED_WITH_NOTES

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | Confirmed in round 2 and unchanged by this round's edit: the ticket's Allowed list (ticket:37-49) covers `packages/site/**`, `packages/registry/src/installability.ts` + `index.ts`, read-only `packages/registry/src/upstream.ts`, `tests/e2e/PDX-024-*.sh`, `README.md`, `CLAUDE.md`, and every §3 step's files fall inside it; AC-1..AC-7 each map to a step and to at least one §4 assertion row |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | §3 (plan:70-79) has eight steps naming 1-2 files each — step 5 is `installability.ts` + `InstallDialog.astro`, step 7 is `README.md` + `CLAUDE.md`; each is separately observable in built output or in a grep |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | PASS | DEC-021 (DESIGN.md:174) requires the blocked pack keeps card, figures and attribution — step 3 and §6 keep all three; DEC-022 (DESIGN.md:175) names `upstreamHead` and `installedVersion` as the disclosure fields step 5 renders, and §6 declines pinning for DEC-022's stated reason |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | **B2-residual is closed.** §4 now carries two AC-4 rows beyond the original: plan:103 asserts all three values *each re-derived from its own file* — `upstreamHead` from `packages/registry/installability/<pack>.json`, the measured commit from `packages/registry/attribution/<pack>/source.json` (`commit`), `installedVersion` from the installability record where the outcome is `installs` — and plan:104 asserts the two commits differ for at least one pack. Every value named is real in the tree: `readSource` builds exactly `join(ATTRIBUTION_DIR, packId, 'source.json')` (upstream.ts:69-77, exported index.ts:34), `caveman/source.json:3` is `27d5a3981a34…`, and the four installing records carry `installedVersion` 1.0.0 / 1.2.3 / 4.9.0 / 6.3.0 while `caveman.json` carries none. §2's claim (plan:41-42) that "§4 asserts all three values" is now true of its own document |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | §5 (plan:120-129) carries five risks each with a mitigation and §6 (plan:130-134) names five out-of-scope items; step 5's DATA-01 exposure claim was verified in round 2 against `check-data.sh`'s own template-expression regex at :397 — `{r.upstreamHead.slice(0, 7)}` and `{r.attemptedAt.slice(0, 10)}` BLOCK, `{r.upstreamHead}` passes |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` → "LANG-01 PASS — no Korean text in repository artifacts"; `grep -cP '[\x{AC00}-\x{D7A3}]'` returns 0 on both the plan and the ticket, and 1 on a planted Hangul file, so the zeroes are the pattern working rather than the pattern missing |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `./scripts/check-references.sh .docs/analysis/PDX-024_plan.md` → "REF-01: PDX-024 has no mapped references (§6.5.1) — nothing required" / "REF-01 PASS"; §7 (plan:136-144) records seven Y rows regardless, including `check-installability.sh` **run** on this branch |

### Comments

1. **Round 3 exists only to confirm B2-residual, and it is closed.** Round 2 pre-recorded the remedy as a two-cell edit — extend the AC-4 assertion row, and honour or soften §2's claim. Both halves are present. §4 keeps the original AC-4 row (plan:102, `upstreamHead` + the HEAD-vs-measured sentence) and adds plan:103 (all three values, each read from its own file, "so a join that silently drops one side cannot pass") and plan:104 (the two commits must differ for at least one pack). §2 additionally logs the miss in place (plan:44-49) rather than quietly rewriting it, which is the CLAIM-01 posture applied to the plan's own history. No further round is warranted.
2. **The new "at least one pack differs" assertion was checked against the live records and is satisfiable today — it will not block at GREEN.** Comparing `upstreamHead` in each `packages/registry/installability/*.json` against `commit` in the matching `packages/registry/attribution/<pack>/source.json`: **caveman** `6c5eea66…` vs `27d5a398…` **differ**, **mattpocock** `9c9f36cc…` vs `8b78b531…` **differ**; karpathy (`2c606141…`), ponytail (`2ed6c52c…`) and superpowers (`b36e0829…`) are identical on both sides. Two of five differ, so the row FAILs only if the corpus is re-recorded into total agreement, which is the loud-break behaviour the plan intends. The check is non-vacuous in both directions: it printed a distinct measured commit for all five packs and correctly reported three of them as equal, so a bug that made every pair look different would have shown up as five differences rather than two.
3. **The AC-4 rows do not overreach into an untestable claim.** plan:103's "Each must appear in that pack's dialog in the built HTML" is satisfiable for the three packs whose two commits coincide (one rendered string satisfies both greps), and plan:104 is what stops that coincidence from making the assertion hollow — for caveman and mattpocock two distinct SHAs must both appear. `installedVersion` is asserted only "where the outcome is `installs`", which matches the records: `caveman.json` has no such field, so the row does not demand a value that does not exist.
4. **Round 1 (2026-08-20 07:33, NEEDS_REVISION — 7 blockers), summarised.** B1 scope breach on `installability.ts`; B2 AC-4's measured commit had no named source; B3 `## 4. Test plan` failed the heading gate; B4 Feature Tags section absent; B5 AC-3 vacuous at date granularity; B6 AC-7 grep had no positive control; B7 ticket revision needed (a `MissingInstallabilityError` that does not exist, and a false `DESIGN.md:174` citation). All seven fixes were verified against the tree in round 2 — including that the corrected ticket now asserts the `unmeasured` state instead of a nonexistent error class, and that the AC-7 sweep runs twice with a planted positive control.
5. **Round 2 (2026-08-20 11:20, NEEDS_REVISION — 1 blocker), summarised.** Six of round 1's seven were confirmed fixed; only **B2-residual** stood: the AC-4 join had been corrected in the ticket, §2 and §3 step 5, but §4's assertion table still asserted `upstreamHead` alone while §2 vouched that it asserted all three. Round 2 classified this as an incompletely applied round 1 fix rather than a new design finding, which is why REV-02 permits this third round. Round 2 also recorded three non-blocking notes: the frontmatter/`slice` exemption asymmetry in `check-data.sh` golden case 49, the AC-5 row being a detector on one branch and prose on the other, and round 1's comments 1/3/6/7 riding to the report.
6. **Open non-blocking notes, all riding to the report per REV-02.** (a) The AC-5 row's second branch — "or the report states that PDX-033 closed them first and cites the commit" — is not something the scenario can decide; the cheap fix is one unconditional assertion that `grep -F 'every listed pack installable by name'` in `README.md` / `CLAUDE.md` either misses or hits adjacent to a CLAIM-01 record. (b) Whether `installStateFor` earns its keep over the existing `outcome` discriminant. (c) Naming the oldest…newest range rather than the oldest alone. (d) §1's restated volatile facts against PLAN-01 — `99a9aa2` appears nowhere in the repository and no scenario asserts it. (e) Step 6 does not say which of DEC-027's sections the counts line joins. None of these can let an AC ship unmet.
7. **Cosmetic, not raised as a blocker in any round.** `## 8. Feature Tags` sits between `## 4. Test Plan` and `## 5. Risks`, so the section numbers do not run in file order. Neither `agent-review.sh` nor `check-templates.sh` imposes an order on a plan, so this is readability only; worth tidying whenever the file is next touched.

### Blockers (only if NEEDS_REVISION)

- None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (round 3, 2026-08-20 — Opus 5; 0 blockers. Round 3 was a confirmation pass permitted by REV-02 because round 2's single finding, B2-residual, was an incompletely applied round 1 fix rather than a new blocker; the two-cell remedy is present and correct — §4 plan:103/104 now assert the measured commit, `upstreamHead` and `installedVersion` each re-derived from its own file, and the "commits differ for at least one pack" guard was verified satisfiable against the live records, caveman and mattpocock. Round 2, 2026-08-20 11:20 — Opus 5, 1 blocker: B2-residual. Round 1, 2026-08-20 07:33 — Opus 5, 7 blockers: B1 scope breach on `installability.ts`, B2 AC-4's measured commit has no source, B3 Test Plan heading fails the gate, B4 Feature Tags absent, B5 AC-3 vacuous at date granularity, B6 AC-7 grep has no positive control, B7 ticket revision needed — all seven confirmed fixed against the tree across rounds 2 and 3)
- Human: pending
