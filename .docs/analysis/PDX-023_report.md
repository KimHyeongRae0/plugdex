# PDX-023 Report — registry: a listing states whether it installs, and the claim is measured

- Ticket: `.docs/tickets/PDX-023_registry-a-listing-states-whether-it-installs.md`
- Plan: `.docs/analysis/PDX-023_plan.md`
- Author: Opus 5 (implementation) — plan and plan review by Fable 5
- Date: 2026-08-19

## 1. Summary

On 2026-08-18 a listing in this catalogue stopped installing. Upstream `caveman` added an
`agents` array to its `.claude-plugin/plugin.json` (commit `902eba3`, fixing its own issue
#855) and the Claude Code CLI rejects that field — `Validation errors: agents: Invalid
input`. It reproduces on 2.1.233, the version every `results.json` in this corpus records,
and on 2.1.234, so it is an upstream defect rather than a CLI regression. `main` went red,
and PDX-004's PR #10 could not merge behind it.

The install proof caught it inside a day of the measurement it publishes, which is the
scenario doing exactly what its own comment says it should: *a listed pack that stops
installing is a broken listing.* What the repository could not do was **say so**. A listing
carried a measured build rate and an install button with nothing between them able to
express "this one does not install today", so the only available moves were a red gate
forever or a green gate that lied.

Install state is now a record, written by a real install and re-checked by a gate. Two
things about that are worth more than the fix itself.

**The old assertion had a cap nobody chose.** It installed `plugins[0]` and stopped, so its
coverage depended on sort order — it caught this breakage only because `caveman` sorts
first. Had the broken pack sorted second, the suite would have gone green over a listing
that does not install. INST-01 sweeps every listing.

**Recording a pack as blocked must not be a way to make a red gate green.** INST-01c is the
rule that makes this honest: a pack recorded as blocked that *installs* is a FAILURE, not a
pass, because the record is then stale and someone has to refresh it. Without that branch,
marking a pack broken would silence the check permanently, and the honest record would be
the one nobody could afford to write.

## 2. Files Changed

| File | Change |
|---|---|
| `scripts/lib/install-signature.py` | **New.** The one classifier, read by both the recorder and the gate. Parses the CLI's `Validation errors:` segment into sorted keys and prints `SIGNATURE kind=… keys=…`, or prints `UNCLASSIFIED <reason>` and exits non-zero. It never exits silently |
| `scripts/lib/write-installability.py` | **New.** The canonical serialisation, split out so the unit test can re-serialise every committed record and require byte-identity of its *form*. Also redacts the recorder's scratch directory and the CLI's per-run cache id, and refuses to emit a record that still names the scratch directory |
| `scripts/lib/installability-join.py` | **New.** INST-01a/e — the join in both directions and the records' shape, checked before any install runs |
| `scripts/record-installability.sh` | **New.** The recorder. Real `claude plugin marketplace add` + `claude plugin install` into a scratch `CLAUDE_CONFIG_DIR`, `claude --version`, `git ls-remote` for the upstream head. A failure the classifier cannot name leaves **no** record and exits non-zero |
| `scripts/check-installability.sh` | **New.** The INST-01 gate: six behavioural branches (INST-01f added in round 13), a per-listing `INST-01 PACK <name> verdict=<v>` line for callers to count, and a notice when the CLI re-measuring differs from the CLI the records name |
| `packages/registry/installability/*.json` | **New, generated** — five records, one per listing. Never edited by hand; the unit test enforces that offline |
| `packages/registry/src/installability.ts` | **New.** The typed reading: a discriminated union on `outcome`, refusing a record it cannot act on rather than skipping it, and refusing a record whose filename disagrees with its `pack` (DATA-02 one level up) |
| `packages/registry/src/installability.test.ts` | **New.** 9 tests: the join both ways, blocked records carry a re-checkable signature, no record leaks an absolute local path, canonical-form re-serialisation (form, not content — see §7 and §8), and three refusal paths |
| `packages/registry/src/index.ts` | The installability surface |
| `tests/e2e/PDX-003-the-hub-installs.sh` | AC-5 rewritten from one pack to every pack, via the gate; asserts the sweep count equals the manifest's listing count and that `caveman` is still among them (CLAIM-01 — a broken pack stays listed and stays checked) |
| `tests/e2e/PDX-023-the-record-reproduces.sh` | **New.** The offline scenario: the classifier's parse against measured logs, and the recorder's three outcomes driven by planted `claude` and `git` shims |
| `tests/meta/cases/59..68-registry-installability-*.sh` | **Ten** golden cases: the dodge (INST-01c), a recorded-installable pack that fails, a different failure, the `custom-agents` counterexample, a listing with no record, a clean pass, a fabricated `installedVersion`, a record naming another repository, a record disagreeing with its own quoted failure, and the deleted-version dodge |
| `DESIGN.md` | DEC-021 (install state is a generated record; blocked must keep failing) and DEC-022 (what the figures describe and what the button installs are different artifacts) |
| `docs/WORKFLOW.md` | The INST-01 rule row and three script rows |
| `.prettierignore` | The generated records, excluded — a formatter reflowing them would break the byte-identity test while changing no fact |
| `.docs/tickets/PDX-023_*.md`, `.docs/analysis/PDX-023_plan.md` | The ticket (amended twice, §3) and the approved plan |

## 3. Plan Compliance

| Plan step | Done | Deviation (if any) |
|---|---|---|
| 3a — the shared classifier | ✅ | None. The parse handles the measured multi-key form (`, ` separated) and sorts keys, which the plan added as a note after the format was measured |
| 3 — the recorder | ✅ | Extended: the scratch-path redaction and its fail-closed outcome check were not in the plan. They exist because the first version silently did nothing and would have committed a developer's absolute path into a record (§4.0 round 3) |
| 4 — the records | ✅ | Five records; four `installs`, one `blocked`. The plan said the content is what the recorder measures on the day, not an assertion — which is what happened |
| 5 — the gate | ✅ | Extended: the per-listing machine-readable line (§4.0 round 4) and the CLI-drift notice, neither planned. The notice is discussed in §8 as an unresolved fork rather than a settled design |
| 6 — AC-5 rewritten | ✅ | None structurally |
| 7 — golden cases | ✅ | Numbered **59-68 rather than 39-48**. The plan said "next free after 38", which is true of `main` and false of the tree this ticket rebases against: PDX-004's branch holds 39..58 and lands after this ticket, so the planned numbers would have collided on rebase |
| 8 — offline shape tests + the ticket scenario | ✅ | None |
| 9 — docs and the decision | ✅ | Numbered **DEC-021/DEC-022 rather than DEC-020**, for the same reason: PDX-004's unmerged branch holds DEC-020. The plan anticipated a skip in the log; the actual collision was in the other direction |

Two ticket amendments are disclosed rather than silent. The first moved the site half out to
PDX-024 and added `scripts/**` and `docs/WORKFLOW.md` to Scope.Allowed (the plan flagged the
scope gap; the split was forced by `main` having no `packages/site`). The second reversed a
mistake I made in the first: I had declared that this ticket ships no scenario of its own,
which would have made stages 4 and 5 unrunnable, because `check-test-case.sh` globs by
ticket id and `test-loop.sh --red` needs this ticket's own scenario to FAIL. A ticket cannot
opt out of the TDD gate by describing the absence nicely.

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

| Round | Command | Result |
|---|---|---|
| 1 | `./scripts/test-loop.sh PDX-023 --red` | **verify FAIL** — LANG-01 blocked the plan. The plan review's own P6 row cited a grep whose pattern spelled out a Hangul character range, so the review asserting the language gate passes was rejected by the language gate. LANG-01 has no allowlist, and a rule with an exception for quoting itself would not be one. Row rewritten to cite `check-language.sh` |
| 2 | `./scripts/test-loop.sh PDX-023 --red` | **RED OK** — verify PASS, e2e FAIL. But AC-2 reported **green** inside that failing run, and it should not have: the registry export did not exist, the import succeeded with the binding `undefined`, and a bare `if (installability)` skipped every assertion under it. That is ASSERT-01's exact shape appearing inside the scenario written to enforce it. The absence is now asserted explicitly, and the RED run then failed all three |
| 3 | `./scripts/record-installability.sh --all` | **FAIL** — `mapfile: command not found`. `mapfile` is bash 4+; macOS ships bash 3.2 as `/bin/bash`, so the construct would have worked on the CI runner and not on a contributor's machine. Replaced with `while read` |
| 4 | `./scripts/record-installability.sh --all` | 5 records written. But the `verbatim` field carried the recorder's own absolute scratch path and the CLI's per-run cache id — values that differ on every run and every machine and are no part of the failure |
| 5 | redaction, first attempt | Marked the cache id and **silently missed the path**: `mktemp -d "$TMPDIR/…"` on a machine whose `TMPDIR` ends in a slash yields a doubled separator, which never string-matches the single-separator path the CLI prints. A redaction that can quietly not happen is worse than none, because the record looks clean |
| 6 | redaction, second attempt | Over-corrected — it *required* the scratch path to appear and so refused legitimate failures that never name it, which the shim-driven scenario caught immediately. Final rule: redact best-effort, then assert the **outcome** (no `plugdex-record.` in the committed text) and refuse otherwise. Pinned by a unit test |
| 7 | `./scripts/e2e.sh PDX-003` | **FAIL** — the rewritten AC-5 grepped the gate's decorated output and matched nothing: the ANSI escape sits where the leading whitespace was expected. The gate now prints an undecorated `INST-01 PACK <name> verdict=<v>` line per listing and the scenario counts those. A first draft of that count hardcoded the five pack names in a regex; removed, it derives from the manifest |
| 8 | `./scripts/check-gates.sh 59 60 61 62 63 64` | 6/6 caught, but case 62's `CASE_DESC` contained backticks and case files are sourced by bash, so the shell executed them (`custom-agents: command not found`) and the description printed with holes in it. It was still caught for the right reason, which is the interesting part: a case can pass while its own description is broken, so the pass says nothing about the description |
| 9 | `./scripts/verify.sh` | **FAIL** — prettier wanted to reformat the generated records. Excluding them is not cosmetic: reformatting would break the byte-identity test while changing no fact, and would make the formatter rather than the recorder the thing that decides what a record is |
| 10 | `./scripts/test-loop.sh PDX-023` | **GREEN** — verify PASS, ticket e2e PASS, regression 6/6 |
| 11 | CLI-drift notice added, `./scripts/test-loop.sh PDX-023` re-run | **GREEN** — verify PASS, e2e 6/6 |
| 12 | report review round 1 | **NEEDS_REVISION, 1 blocker, and it was demonstrated rather than argued.** The reviewer flipped caveman's `outcome` from blocked to installs, softened a signature, and fabricated an `installedVersion` of 9.9.9 for karpathy — all three passed the unit suite 21/21, and the fabricated version passed the live gate too. This report's DATA-01 row claimed the byte-identity test makes a hand edit fail offline. It does not, and cannot: the test re-serialises the record's own fields, so any canonical edit round-trips. Only a reordered key fails |
| 13 | claims corrected, INST-01f added, `./scripts/check-gates.sh 65` | The claim is now what the mechanism is (§7, §8, and both code comments that made the same overstatement). The fabricated version is no longer merely mis-described: INST-01f re-measures `installedVersion` against the fresh install, verified by planting 9.9.9 on the live tree — `INST-01 BLOCK (1 violation over 5 listings)` — and pinned by golden case 65. The other two edits the reviewer made were already caught online by INST-01b and INST-01d; what had been unguarded was the version field, and it is a field the catalogue publishes. The row said INST-01b/c; the softened signature fires INST-01**d**, not c |
| 14 | report review round 2 | **NEEDS_REVISION, 2 blockers, both text.** The reviewer confirmed INST-01f by execution and mutation-tested case 65, then went after §8's corrected disclosure and found it still understated the gap: a forged `repo` (`someone/else-entirely`), a flipped `transport`, and a `verbatim` quoting a hooks failure beside an agents signature all passed the live gate, as did **deleting** `installedVersion` outright — so "caught for installedVersion" was one-directional. Second blocker: stale counts (44/44 against a 45/45 tree), case range, and the b/c mislabel |
| 15 | three holes closed, `./scripts/check-gates.sh` | Two of the reviewer's four forgeries were checkable and are now checked, offline: `repo` against the manifest that lists it, and `verbatim` against its own signature via the classifier — two fields unverifiable alone and checkable against each other. INST-01f compares presence in **both** directions, so the deletion dodge fires. Verified by planting each forgery on the live tree, and pinned by cases 66, 67, 68. `transport` stays unenforceable and is named as such |
| 16 | `./scripts/check-gates.sh` after the new checks | **Case 64, the clean pass, went MISSED** — and that is the case earning its place. The stricter INST-01f rejected the fixture, because `plant_record` never set `installedVersion` while the shim's `plugin list` prints one. A violation case cannot catch over-blocking; only a clean pass can, and this one did on the first run after the gate tightened. Ten fixtures corrected; 48/48 |

### 4.1 Final GREEN evidence

- check-test-case: **PASS**
- verify (language + structure + gates + no-llm + templates + data-universe + typecheck + lint + test + build + SRC-01): **PASS, 20s**
- ticket e2e (`PDX-023-the-record-reproduces.sh`): **PASS** — 3/3 assertions
- regression (`./scripts/e2e.sh`, no argument): **PASS 6/6**
- gate self-test (`./scripts/check-gates.sh`): **48/48**
- registry units (`pnpm --filter @plugdex/registry test`): **21/21**
- INST-01 live, CLI 2.1.233: **PASS**, 5 listings, every recorded state reproduced, no drift notice
- INST-01 live, CLI 2.1.234: **PASS**, 5 listings, drift notice naming all five records

The recorder's output over the live listings, which is the ticket's substance:

```
RECORDED caveman     outcome=blocked  kind=manifest-validation keys=agents
RECORDED karpathy    outcome=installs version=1.0.0 transport=https
RECORDED mattpocock  outcome=installs version=1.2.3 transport=https
RECORDED ponytail    outcome=installs version=4.9.0 transport=https
RECORDED superpowers outcome=installs version=6.3.0 transport=https
```

## 5. Non-Scriptable Verification (DEV-01)

| Item | Result | Notes |
|---|---|---|
| CI workflow on the runner | **Checked, no change needed — and the check is the point** | PDX-004's report marked this row N/A on the grounds that no workflow file changed, and that was the reasoning that let its browser scenario reach CI with no browser installed. So it was read rather than assumed: `.github/workflows/ci.yml:153` installs the CLI (`npm install -g @anthropic-ai/claude-code`) in the e2e job, which is the only job that runs this gate, so `claude` is on the runner's PATH. What that reading also surfaced is that the install is **unpinned** while every record names `2.1.233` — see §8, where it is recorded as an open fork rather than settled here |
| Whether a blocked listing reads as honest rather than as an excuse | **N/A for this ticket** | Nothing reader-facing ships here; the site says nothing yet. It becomes checkable in PDX-024, and §8 states how long the gap stays open |
| The gate's output is legible to a human, not only to a scenario | **Checked by reading a real run** | Each listing prints a verdict line with its reason, the blocked line names the reproduced signature, and every violation names the refresh command. Judged rather than measured |

## 6. Regression Check

`./scripts/e2e.sh` with no argument: **6/6**, including PDX-002, PDX-003 (whose AC-5 this
ticket rewrote), PDX-016 and PDX-017. `check-gates.sh` 48/48. Nothing flaky, nothing
skipped.

PDX-003 is the load-bearing regression here: it went from installing one pack to installing
five, so a green result now covers strictly more than it did, and the assertion that used to
pass is not the assertion that passes today.

## 7. Rules Verification

| Rule | How it is satisfied |
|---|---|
| DATA-01 | No field in any record is typed: version, date, upstream head, transport, outcome, installed version and failure signature all come off commands the recorder runs. **Enforcement is split, and an earlier draft of this row overstated the offline half.** The byte-identity unit test pins canonical form only — key order, indent, the redactions — and cannot authenticate content, because it re-serialises the record's own fields, so any edit that is itself canonical round-trips. The report review demonstrated that by flipping `outcome` from blocked to installs and watching the suite stay green. Content is enforced online by INST-01, which re-measures `outcome`, `signature` and now `installedVersion` against a fresh install. What no check reaches is listed in §8 |
| DATA-02 | The filename is not the fact: a record whose `pack` disagrees with its filename is refused by both the loader and the join gate |
| CLAIM-01 | `caveman` keeps its listing, its measured figures and its attribution. AC-5 asserts it is still among the swept listings, so removing it to make a gate green fails the gate |
| ASSERT-01 | Every probe prints a sentinel; the scenario fails on an empty capture; the classifier never exits silently; the gate refuses an empty listing set and compares its checked count against the expected count rather than reporting a pass over a partial sweep |
| SRC-01 | Untouched and still passing — 5 listings, every attribution field tagged and sourced |
| REV-02 | The plan review ran two rounds, not more. Round 1 raised one blocker and it was real |
| GATE-01 | Ten golden cases, each tripping exactly one INST-01 rule, plus a clean pass that earned its place: it went MISSED the first time the gate tightened (round 16) |

## 8. Risks / Notes

**The site still says nothing.** This ticket makes the fact exist; it does not publish it.
From the moment this merges until PDX-024 lands, the repository knows `caveman` does not
install while the catalogue shows it a plain install button. That is a real gap and it is
stated here rather than discovered later. PDX-024 must therefore precede PDX-014 (deploy):
publishing the site with a known-broken install button and no marker would be the catalogue
doing the thing this project exists to object to.

**The shims prove the recorder, not the CLI.** `PDX-023-the-record-reproduces.sh` runs
offline against a planted `claude`, so it proves what the recorder does with a given log,
never that the CLI produces that log. The real CLI is exercised only by PDX-003's AC-5. The
logs the shim prints were copied from real runs rather than invented, which narrows the gap
without closing it.

**A third party can red this build.** If the CLI's validation output is ever reworded past
what the classifier parses, the classifier refuses, INST-01d fires, and the build goes red
with nothing wrong in this repository. That is the fail-closed direction and it is the right
one — the alternative is a gate that quietly accepts a failure it cannot name — but it is
worth saying plainly rather than discovering during a release.

**Unresolved fork: should CI pin the CLI?** Every record names `2.1.233`; CI installs
whatever is current that morning. Pinning makes the re-check deterministic and comparable to
the record, and makes a hub blind to precisely the release that breaks its listings.
Staying unpinned catches that release and lets a third party's publish turn this build red.
The gate currently does neither silently: it names the CLI it re-measured with and reports
drift. Deciding the fork is not an implementation commit's business, and it is left open
here on purpose.

**What no check reaches — third statement of this list, and the first two were both wrong.**
The first version of §7 claimed the offline test caught hand edits; report review round 1
falsified it. The corrected version listed three unguarded fields; round 2 falsified that
too, by forging a `repo`, flipping a `transport`, and pairing an `agents` signature with a
`verbatim` quoting a `hooks` failure — all three passed the live gate — plus deleting
`installedVersion` outright, which passed because the check only ran when the field was
present. Two wrong statements about the same list is a pattern, so this one is written
from what was measured rather than from what seems plausible.

Enforced, each verified by planting the forgery and watching the gate refuse:

- `outcome` — INST-01b/c/d, by re-installing.
- `signature` — INST-01d, by classifying the fresh failure with the classifier that wrote it.
- `installedVersion` — INST-01f, compared in **both** directions, so absence is a mismatch too.
- `repo` — INST-01e, against the manifest that lists the pack. Offline and free: the value is
  derivable, so leaving it unchecked was an oversight rather than a limit.
- `verbatim` — INST-01e, classified and required to equal the record's own signature. Neither
  field is verifiable alone offline; together they are, because the classifier is the
  function that relates them.
- `pack` — refused when it disagrees with the filename (DATA-02 one level up).

Still unenforced, with the reason each resists it:

- `attemptedAt` — a forged date makes a stale measurement look fresh. Nothing can contradict
  it: time passing is not evidence of anything.
- `cliVersion` — a forged version misnames the instrument. The gate reports drift as a notice
  rather than a violation, because a legitimate re-check on a newer CLI is the normal case.
- `transport` — `ssh` or `https` depends on whether the machine running the install has a
  GitHub key, so the honest value differs per machine and a mismatch carries no information.
- `upstreamHead` — the commit the pack was at when recorded. Upstream moves, so a difference
  is expected rather than suspicious; this is the field DEC-022 is about, and it is
  disclosed on the site rather than gated.

One more shape sits between the two lists rather than on either. Report review round 3
rewrote a blocked record's `verbatim` prose around a segment that still classifies to the
recorded keys — "agents: nothing serious - install it anyway" — and it passes. That is the
stated granularity working as designed rather than a hole: what is enforced is the failure's
classification, and byte-comparing the quoted prose would break the reword tolerance the
classifier exists to provide. A reader should know the quote is checked for what it means,
not for what it says. (Round 3's first attempt at this was refused by accident, because a
comma in the invented prose minted a phantom key and the self-consistency check caught it.)

None of the four is closable by re-measurement, and a checksum would not help — anyone
editing a record can recompute one. Closing them needs a witness outside this repository,
which it does not have. The list is here so a reader does not assume the whole record is
enforced, which is exactly what the first version of §7 invited.

**The records are a snapshot with no calendar.** Nothing re-runs the recorder on a schedule.
Structurally the state is re-checked on every regression run, which is what makes the
records honest rather than decorative — but "when did we last look" is answered by
`attemptedAt`, and if the repository ever wants a freshness guarantee it is an ops ticket,
not a field.

**Out of PDX-004's way.** `main` is red without this, and PR #10 cannot merge until it
lands. The landing order is PDX-023 → PDX-004 rebase and merge → PDX-024.

## 9. CR-01 Compliance

No commit, push, branch beyond the ticket branch, tag, issue, PR, merge or release was made
while this work was done. The recorder and the gate both contact GitHub — they clone the
authors' repositories, which is the assertion — and neither writes to any remote.

## 10. Agent Review

### Reviewer
- Model: Fable 5
- Reviewed at: 2026-08-19 09:33

### Verdict
- [ ] APPROVED
- [x] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric
| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | PASS | Re-run in round 3: verify PASS 22s, e2e 6/6 with the strengthened gate, units 21/21, gates 48/48, INST-01 PASS live on 2.1.233 and on 2.1.234 with the drift notice — every §4.1 line reproduced against the current tree |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | PASS | `.docs/state/PDX-023.state`: red 07:53:05 before greens at 08:08, 09:04 and 09:24 — a fresh green stamp follows each fix round |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | PASS | §3 step 7 now reads 59-68; rounds 12-16 disclose the two review-driven extensions with what broke on the way (case 64 catching the over-strict INST-01f is round 16, and it is the honest kind of disclosure) |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | PASS | Both round-2 blockers fixed and verified by execution: forged repo and self-disagreeing verbatim now refused by INST-01e naming both sides; deleted `installedVersion` fires INST-01f ("record names version 'none' and the install produced '1.0.0'"); §4.1/§6 say 48/48 and the tree reproduces 48/48; WORKFLOW.md's INST-01 row describes all three closures; row 13's mislabel corrected in place |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | PASS | `git log` head still 62d76dd; all work uncommitted on the ticket branch; this round ran gates, installs and sandbox mutations only |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | PASS | verify (which runs `check-language.sh`) PASS this round; cases 66-68, the rewritten §8 and the new join code read in full, all English |

### Comments
1. All four round-2 forgeries re-run against the live tree. Forged `repo` (`someone/else-entirely` on ponytail): refused, `INST-01e ... while the manifest lists 'DietrichGebert/ponytail'`. Hooks-verbatim beside an agents-signature: refused, `INST-01e ... disagrees with itself`, naming both classifications. Deleted `installedVersion` on karpathy: refused, `INST-01f ... 'none' and the install produced '1.0.0'`. Flipped `transport`: still passes, and §8 now lists it with the per-machine SSH-key reason — which is the correct disposition, not a gap.
2. Cases 66, 67 and 68 mutation-tested like the rest: dropping the repo-vs-manifest check misses 66; dropping the verbatim self-consistency check misses 67; reverting INST-01f to one-directional misses 68 while 65 stays caught — so 65 and 68 pin the two directions separately rather than shadowing each other.
3. The fifth forgery, tried as asked: a `verbatim` whose prose is rewritten around a segment that still classifies to the recorded keys — `"Validation errors: agents: nothing serious - install it anyway"` — passes the gate. This is not a defect in §8: the row says verbatim is "classified and required to equal the record's own signature", which is exactly what is enforced, and byte-comparing the prose against a fresh install would break the ticket's own edge case (reworded CLI text must not read as a different defect). It is the residue inside an enforced field, and it belongs to neither list; if §8 wants to be airtight it can say in half a sentence that the prose around the segment is trusted at classification granularity. First attempt at this forgery was caught by accident: a comma in the invented prose minted a phantom key (`keys=agents,honestly`) and the self-consistency check refused it — the classifier's strict key shape working in the gate's favour.
4. One stale count survived round 15's sweep: §7's GATE-01 row still says "Six golden cases" while ten ship (nine violation cases plus the clean pass). Understatement, not overstatement, and everything the row gestures at was mutation-verified this round — fix the word before commit; it does not need a round 4.
5. Round 16 deserves the attention it asks for: the clean-pass case catching the over-strict INST-01f on its first run after the tightening is case 64 doing the one job the nine violation cases cannot, and it retroactively justifies round 1's worry that 64 was the case most likely to be vacuous. It is not.
6. Confirmed live on both CLIs after the strengthening: 2.1.233 clean PASS, 2.1.234 PASS with the drift notice naming all five records — §4.1's claims hold on the tree as it stands.

### Blockers (only if NEEDS_REVISION)
- None.

### Round 2 (Fable 5) — NEEDS_REVISION, 2 blockers

#### Reviewer
- Model: Fable 5
- Reviewed at: 2026-08-19 09:14

#### Verdict
- [x] NEEDS_REVISION

#### Rubric
| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | PASS | Re-run in round 2: verify PASS 20s, e2e 6/6, units 21/21, full gate self-test now 45/45, INST-01f verified live (fabricated 9.9.9 on karpathy → `INST-01 BLOCK (2 violation(s) over 5 listing(s))` alongside the flipped-outcome INST-01b); §5 rows unchanged and still accurate |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | PASS | `.docs/state/PDX-023.state`: red 07:53:05 before green 08:08/08:13, and a fresh green stamp 09:04:22 after the round-13 fix |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | PASS | Round-1 verification stands (PDX-004 branch holds 39-58 and DEC-020); INST-01f is disclosed in rounds 12-13 as review-driven — but §3 step 7 still says "59-64", see Blockers |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | FAIL | The round-1 blocker is genuinely fixed in all four places and INST-01f works (verified live and by mutation), but §8's "what no check reaches" list is incomplete — `repo`, `transport` and `verbatim` forgeries passed the live gate in this round — and §4.1/§6 still cite 44/44 where the tree reproduces 45/45 |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | PASS | `git log` head still 62d76dd; all work uncommitted on the ticket branch; this review ran gates and installs only |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` passes inside verify (re-run this round); case 65, the new §7/§8 text and both corrected comments read in full, all English |

#### Comments
1. The round-1 blocker is fixed in both directions, verified by execution. Claims: §7's DATA-01 row, §2's writer row, the `installability.test.ts` comment and the `write-installability.py` docstring now all say canonical form only, and each names the mechanism honestly. Enforcement: planting `installedVersion: 9.9.9` on karpathy in a scratch records dir made the live gate BLOCK with `INST-01f ... record names version '9.9.9' and the install produced '1.0.0'`.
2. The round-13 claim that the other two edits were "already caught online rather than newly fixed" is TRUE and was confirmed live this round: the flipped outcome fired INST-01b and the softened signature fired INST-01d — both pre-existing branches. But the row names them "INST-01b/c", and the softened signature is caught by INST-01d, not INST-01c (measured: `INST-01d: caveman fails differently than recorded — recorded [keys=hooks], now [keys=agents]`). One-letter fix, listed under Blockers because it is a rule attribution in the round log.
3. Case 65 mutation-tested like 59-64: with the INST-01f comparison neutered in a sandbox copy, `check-gates.sh 65` reports MISSED; restored, 45/45. The fail-closed edge also holds: a record naming a version while the CLI prints no `Version:` line fires INST-01f with `produced 'none'` (verified with a shim).
4. INST-01f's optional-field dodge exists and is the mild direction: hand-DELETING `installedVersion` from a record passes the gate even while the fresh install prints 1.0.0 (verified live). That edit removes a published claim rather than forging one, but it means §8's sentence "a hand edit is caught for outcome, signature and installedVersion" is one-directional, and it should say so.
5. Cheap closures exist for two of the newly named gaps, both offline: the join can require `record.repo` to equal the marketplace plugin's `source.repo` (the gate installs from the manifest, so equality is the fact), and a blocked record's `verbatim` can be required to classify — via the one classifier — to the very signature it sits beside. `transport` genuinely is machine-dependent (SSH key present or not), so listing it with that reason is enough. None of this is required to fix the blocker; correcting §8's text is.
6. Regression state after the fix: verify PASS 20s, e2e 6/6 (re-run with the changed gate), units 21/21, gates 45/45, and a post-fix green stamp in the state file. The tree is GREEN; every remaining defect is report/doc text.

#### Blockers (only if NEEDS_REVISION)
- R4a — §8's unguarded list is incomplete, which is the exact overstatement class this round's correction was about. Demonstrated by execution against the live gate: a record with `repo` forged to `someone/else-entirely` passed; `transport` flipped https→ssh passed; caveman's `verbatim` forged to quote a hooks failure while its signature says agents passed (the gate never reads `verbatim`). All three are canonical, so the offline suite passes them too. Add them to §8's list (repo and verbatim do not "legitimately change", so they need their own sentence — or the cheap offline checks in comment 5), and qualify the `installedVersion` claim as one-directional per comment 4.
- R4b — rows the round-13 fix left stale, each contradicted by the tree: §4.1 and §6 say `check-gates.sh` **44/44** where the tree reproduces **45/45**; §3 step 7 says cases "59-64" while seven cases 59-65 ship (§2 was updated, §3 was not); `docs/WORKFLOW.md`'s INST-01 row says "golden cases 59-64" and its rule text omits the version re-measure INST-01f performs; round 13 says "INST-01b/c" where the softened signature is caught by INST-01d (measured this round).

### Round 1 (Fable 5) — NEEDS_REVISION, 1 blocker

#### Reviewer
- Model: Fable 5
- Reviewed at: 2026-08-19 08:57

#### Verdict
- [x] NEEDS_REVISION

#### Rubric
| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | PASS | Re-run by this review: e2e 6/6 (PDX-023 3/3, rewritten AC-5 sweep incl. caveman), gates 44/44, units 21/21, INST-01 PASS live on 2.1.233 (no drift) and 2.1.234 (drift notice naming all five); §5 rows checked or explicit N/A, and the ci.yml claim is real (unpinned `npm install -g @anthropic-ai/claude-code` in the e2e job) |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | PASS | `.docs/state/PDX-023.state` stamps `red 2026-08-19T07:53:05` before `green 08:08:19` and `08:13:12`, matching §4.0 rounds 2/10/11 |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | PASS | Both numbering deviations verified true against the tree: `git ls-tree feat/pdx-004-catalogue-cards-verdicts-and-install tests/meta/cases/` holds 39-58 and that branch's DESIGN.md line 175 holds DEC-020; both ticket amendments are disclosed in §3 |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | FAIL | Files Changed matches `git status --short` row for row, but the DATA-01 claim ("the byte-identity unit test makes a later hand edit fail offline") is not reflected in behavior: a canonical hand edit flipping caveman `blocked` to `installs` passed the unit suite 21/21 in this review, and fabricated `upstreamHead`/`attemptedAt`/`installedVersion` passed the suite AND the live gate |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | PASS | `git log` head is still 62d76dd (PDX-017) with all PDX-023 work uncommitted on the ticket branch; the recorder and gate contact GitHub read-only (clones), mutating no remote |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` passes inside `./scripts/verify.sh` (VERIFY PASS, 23s, re-run by this review); every new script, test, case, and doc read for this review is English |

#### Comments
1. Verified by execution, not by reading: all six golden cases are non-vacuous. Each of 59-63 is MISSED by `check-gates.sh` when the specific branch it targets is reverted in a sandbox copy (INST-01c branch neutered → 59 missed; INST-01b neutered → 60 missed; signature comparison forced true → 61 and 62 missed; join direction removed → 63 fails for the wrong rule). Reinstating plan review round 1's `grep -wF` design misses case 62 while case 61 still catches — 62 uniquely pins the hyphen-boundary regression. Case 64 FAILS under over-strict mutations of either green branch (inverted signature comparison; broken installs check), so it guards both pass paths and is not vacuous.
2. The blocker is a claims defect, not a gate defect. The property the ticket rests on holds: INST-01c fired live in this review's sandbox mutations, a blocked record that installs cannot go green, and outcome/signature dishonesty is caught online (INST-01b/c/d). What the byte-identity test actually pins is canonical FORM — it re-serialises each record from that record's own fields, so a key reorder fails (verified: 20/21) but any content edit that keeps canonical shape passes. Fix by rewriting the claim in §2 (write-installability row), §7 (DATA-01 row), the `installability.test.ts` comment, and the `write-installability.py` docstring to what is true: form is pinned offline, outcome and signature are pinned online by INST-01, and `attemptedAt`/`upstreamHead`/`installedVersion` are currently re-checked nowhere. Alternatively strengthen the gate to compare `installedVersion` against `claude plugin list` output, which this review confirmed it does not (a record claiming 9.9.9 for karpathy passed live).
3. Classifier probing: a comma-bearing message body ("agents: Expected array, received object" — the ordinary zod shape) is REFUSED, which is the fail-closed direction §8 already discloses; and a body containing ", expected: array" mints a phantom key (measured: keys=agents,expected). Neither turns red green. Worth extending the parse the first time a comma-bearing message is measured from the real CLI.
4. §8's CI-pinning fork is genuinely open, not a dodged decision: the gate names the CLI it re-measured with and reports drift, so neither choice is being made silently, and pinning is a CI/ops change outside this ticket's scope. Drift-as-notice is right — a violation would red the build on every CLI release even when all five outcomes reproduce, which is the exact blindness the unpinned choice exists to avoid.
5. The PDX-024 split leaves `main` green with the fact recorded but unpublished; the report states the gap plainly and orders PDX-024 before PDX-014. No objection.
6. Note: `verify.sh` measured 23s here vs the reported 20s — machine variance, not a discrepancy.

#### Blockers (only if NEEDS_REVISION)
- R4: the report and the shipped comments claim the byte-identity test makes a hand-edited record "fail verify offline", naming "an outcome flipped" and "a signature softened" as examples — demonstrated false by execution. A canonical re-serialisation with caveman's outcome flipped `blocked` to `installs` (signature and verbatim dropped) passes the full unit suite 21/21; softening the signature keys to `hooks` also passes 21/21; and a record with fabricated `upstreamHead` (40 zeros), `attemptedAt` (1999), and `installedVersion` (9.9.9) passes the unit suite and `./scripts/check-installability.sh` live. Only non-canonical edits (e.g. key order) fail. Correct the claim in §2, §7, `packages/registry/src/installability.test.ts`, and `scripts/lib/write-installability.py` — or make the enforcement match the claim.

## 11. Final Report Status

- Agent: APPROVED_WITH_NOTES — round 3, 2026-08-19 09:33, Fable 5 (both round-2 blockers fixed and verified by execution; cases 66-68 mutation-tested; fifth forgery found only classification-granularity residue in verbatim, disclosed correctly by §8; one note: §7 GATE-01 row says "Six golden cases", ten ship — fix the word before commit)
- Human: _(pending)_
