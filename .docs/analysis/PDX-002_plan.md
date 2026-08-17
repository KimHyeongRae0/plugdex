# PDX-002 Plan — Absorb the measurement project and bake its records

- Ticket: `.docs/tickets/PDX-002_data-absorb-the-measurement-project-and-bake-its-records.md`
- Author: Opus 5 (main agent)
- Date: 2026-08-17

## 1. Goal & Context

The measurements plugdex publishes currently live in a separate repository
(`does-it-compile`, 4 commits, all pushed — the fourth, `d63ff3b`, landed 2026-08-17 15:15 +0900, after the first revision of this plan). DATA-01 says every figure the site renders must
trace to a fingerprinted record — but a trace that crosses a repository boundary can go
stale on either side without anything noticing. That is not hypothetical: instrument
failures 15 and 16 in that very project were both "two things drifted apart and the
output did not say so".

This ticket makes the trace local. `bench/` receives the measurement project with its
git history intact, and `packages/data` becomes the typed reading of it — the single
module the site and the registry both consume.

The history matters beyond tidiness. `PREREGISTRATION-2.md` was committed at
2026-08-16 08:37:16 +0900; the earliest round-two run **file** in the published subset is
`20260816-092732-caveman-blocked`. The commit precedes the runs it predicts by 50m 16s.
(The imported subset contains run files, not the ~10 GB cell directories, which this
ticket excludes.) That ordering is the only evidence
the preregistration is real, and it exists solely as commit metadata.

Current state: the workspace is empty, `verify.sh` runs in empty-workspace mode, and no
package exists. This ticket ends that.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: work is confined to `bench/` (imported, not
  authored), `packages/data/`, `tests/e2e/PDX-002-*.sh`, the root workspace manifests, and
  `README.md`. The first draft of this plan touched the last two without the ticket
  permitting them, while the ticket's own AC-7 demanded the README change — a
  self-contradiction the plan review caught (P1 FAIL). The ticket's Scope.Allowed now
  names both. ST-07 already admits `bench` (landed with PDX-001).
- **Ticket Scope.NotAllowed respected**:
  - No squash, rebase, or re-authoring. `git subtree add` **without** `--squash`, which
    grafts the original commits as a second parent with their author dates untouched.
    Step 1 verifies this by reading the dates back out, not by assuming.
  - The ~10 GB of preserved cell workspaces stay in `pack-pilot`. Only the published
    subset already committed to `does-it-compile` moves.
  - No number changes. `packages/data` parses and validates; it computes no statistic
    that is not already in a record.
  - The source repository is not deleted. Archiving is deferred until after this ticket
    proves the import.

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | Import the measurement project with history | `bench/**` (imported) | `git subtree add --prefix=bench ../does-it-compile main`, no `--squash`. Fetch the source first so the import cannot come from a stale clone, then read back the author dates of all four commits and confirm the corrected `PREREGISTRATION.md` sentence arrived |
| 2 | Declare the first workspace package | `packages/data/package.json`, `packages/data/tsconfig.json` | name `@plugdex/data`; scripts `typecheck` / `lint` / `test` / `build`. This is what takes `verify.sh` out of empty-workspace mode |
| 3 | Types and the fingerprint invariant | `packages/data/src/schema.ts` | `AcceptanceFile`, `Cell`, `RunEnv`. `npm_fingerprint` is a required non-optional field, so a record without one fails typecheck rather than at render time (AC-3) |
| 4 | The loader and its refusals | `packages/data/src/load.ts` | reads `bench/data/runs/*.acceptance.json` **only** — `results.json` (no fingerprint) and `gate-limits.json` (a third schema) are out by the ticket's record-universe table, not by loader convenience; throws `MissingFingerprintError` on a record with no `env.npm_fingerprint` and `MixedEnvironmentError` when the loaded set spans more than one fingerprint (AC-3, AC-4). Never silently unions |
| 5 | Public surface and unit tests | `packages/data/src/index.ts`, `packages/data/src/load.test.ts` | `node:test` via `tsx`, no test-framework dependency. Cases: a good set loads; a fingerprint-less record throws; a two-fingerprint set throws |
| 6 | Wire the workspace | root `package.json` (devDeps: `typescript`, `tsx`, `@types/node`), `pnpm-lock.yaml` | `pnpm install`. Lint and prettier already cover `packages/**` via existing config |
| 7 | One project, one README | `README.md` | remove the wording that implies a separate measurement repository (AC-7) |

## 4. Risks

- **The import silently squashes and the evidence dies** → step 1 does not trust the
  command; it reads all four original commits' author dates back out of the graph, and
  the e2e scenario asserts the preregistration commit still precedes the earliest
  round-two run file (AC-2). If either check fails, reset and re-import.
- **`bench/` breaks a gate that PDX-001 never saw content for** → LANG-01 now scans
  imported artifacts. `gate-limits.json` was regenerated in English in `5d3ba47`, so this should pass; if anything Korean survived, it is fixed in the
  source repo and re-imported, not allowlisted (DEC-002 admits no exceptions).
- **Leaving empty-workspace mode surfaces failures the harness has been skipping** →
  that is the intent (AC-5). Node steps must genuinely pass; a green `verify.sh` that
  still prints the empty-workspace warning does not satisfy this ticket.
- **The loader is written to fit the data rather than the rule** → the two error paths
  are unit-tested against synthetic records, not against the real corpus, so they cannot
  pass merely because today's eight files happen to agree.
- **The fingerprint is mistaken for a validity check** → it is not. The withdrawn run
  carries the same fingerprint as the live ones, because it was withdrawn for a different
  prompt and the fingerprint encodes only the environment. `MixedEnvironmentError` will
  never flag it. This ticket ships that limit stated rather than papered over; separating
  withdrawn from live is CLAIM-01's job and lands with the withdrawal register.
- **Path collision on import** → the subtree prefix nests everything under `bench/`, so
  the imported `README.md` and `PREREGISTRATION.md` never touch the root whitelist.
- **The import is taken from a stale clone** → every other criterion would pass while the
  provenance correction silently never arrives. Step 1 fetches first, and AC-1 asserts the
  corrected sentence is present rather than trusting a commit count.

## 5. Out of Scope

- `packages/registry` and `packages/site` — their own tickets.
- Rendering anything. This ticket produces a typed reading, not a page.
- The DATA-01 gate script. The rule becomes *checkable* here because the records are
  local and typed; the script that enforces it across the site lands with the site.
- Resolving how cost and token figures satisfy DATA-01. They exist only in
  `results.json`, which carries no fingerprint. The ticket's record-universe table names
  the contradiction so the first ticket that needs those numbers inherits it explicitly.
- Re-measuring, re-scoring, or adding runs.
- Archiving `does-it-compile` — a separate, explicitly-instructed action after this
  ticket lands (CR-01).

## 6. Rules / Decisions Applied

- LANG-01 (English-only artifacts; no allowlist) — applies to the imported tree too
- CR-01 — the import is a local commit; pushing and archiving are separate instructions
- ST-07 — `bench` was added to the known-directory whitelist in PDX-001
- ST-02 — `data` is a registered package name
- DATA-01 (`docs/WORKFLOW.md` §3.1) — the rule this ticket makes enforceable
- DESIGN.md decision log: DEC-002 (no LANG-01 allowlist), DEC-003 (three packages;
  the dataset is the product and keeping it separate is what makes DATA-01 checkable)
- DESIGN.md §4.2 — the three questions the records must answer

## 7. Test Plan (mandatory — TDD)

- **E2E scenario file**: `tests/e2e/PDX-002-records-are-traceable.sh`
- **RED condition** (must hold before step 1): `verify.sh` PASSes and the scenario FAILs.
  Every assertion must be capable of failing now, which the review found was not true of
  the first draft's AC-7 check — "does-it-compile" appears nowhere in plugdex, so a grep
  for it was green before any implementation and proved nothing. AC-7 is therefore
  anchored to text that does exist today (the Status sentence in `README.md:38`) and goes
  red only once that sentence is removed. The scenario reports each absence as a failed
  assertion and continues, rather than crashing on the first missing file.
- **GREEN condition** (after step 7): `verify.sh` PASSes **with Node steps executed**
  (no empty-workspace warning), the scenario PASSes all assertions, and the full
  regression (`e2e.sh` with no argument) PASSes, so PDX-001 still holds.
- **Scenario assertions**, one per acceptance criterion:
  - AC-1 — all four original commits (`63735e6`, `869b7de`, `5d3ba47`, `d63ff3b`) are
    reachable with their original author dates
  - AC-2 — the `PREREGISTRATION-2.md` commit date is strictly earlier than the earliest
    round-two run file, where round two is **derived from provenance**: the run files
    absent from the preregistration commit's tree and introduced by the commit after it.
    Verified by hand before writing this revision — the preregistration tree holds
    `20260815-225842-*`, `20260816-010513-*`, `20260816-020247-*` (round one) and the
    next commit adds `092732`, `094325`, `094958`, `113302`, `121801`, `222615` (round
    two). A `20260816-*` glob, as the first draft specified, would have swept in two
    round-one runs that precede the commit and failed on a correct implementation
  - AC-3 — `packages/data` rejects a synthetic record with no fingerprint (non-zero exit)
  - AC-4 — every `bench/data/runs/*.acceptance.json` carries `4b140e75d7dc1828`
  - AC-5 — `verify.sh` output does not contain the empty-workspace warning. `verify.sh`
    exits 0 in that mode too, so exit code alone asserts nothing
  - AC-6 — `check-language.sh` passes with `bench/` present
  - AC-7 — the `README.md` Status sentence is gone. Matched as the single-line substring
    "The measurement harness and its data exist", which sits entirely on `README.md:38`;
    the full sentence wraps onto line 39, so a fixed-string grep of the whole thing is
    green today and would be a second fake-RED
  - AC-1 staleness — the imported tree contains the corrected `PREREGISTRATION.md`
    sentence, so an import from a pre-`d63ff3b` clone fails rather than passing quietly.
    The anchor is the literal substring `Both fixes postdate the runs published here`,
    which sits entirely on `PREREGISTRATION.md:204` (the sentence continues onto the
    next line); stage 4 uses this string rather than choosing its own
- **Unit tests**: yes, `packages/data/src/load.test.ts`. The two refusal paths
  (`MissingFingerprintError`, `MixedEnvironmentError`) are exercised against synthetic
  fixtures. An e2e shell assertion can only prove the loader rejects *something*; the
  unit test proves it rejects for the stated reason.

## 8. Feature Tags

- `data` — record loading and validation; regression scenario `PDX-002-*`
- `harness` — `verify.sh` leaving empty-workspace mode affects every later ticket

## 8.5 References Consulted (REF-01)

Per DESIGN.md, Reference Map: PDX-002 requires `acceptance.json`, `PREREGISTRATION`,
`gate-limits`.

| Reference | Consulted | Note |
|---|---|---|
| acceptance.json | Y (2026-08-17) | Opened `20260816-020247-frontend.acceptance.json`: shape is `{run, env, cells}`, `env.npm_fingerprint = 4b140e75d7dc1828`, `env.npm_extraneous = []`, 75 cells. All 8 acceptance files in the corpus share that one fingerprint — the invariant AC-4 asserts is true today, which is exactly why the loader must enforce it rather than assume it |
| PREREGISTRATION | Y (2026-08-17) | Read both: `PREREGISTRATION.md` (210 lines, round-one predictions + outcomes + instrument failures 1–16) and `PREREGISTRATION-2.md` (165 lines, round-two predictions with two marked failed). Their value is the commit ordering, which is why step 1 refuses `--squash` |
| gate-limits | Y (2026-08-17) | Opened `data/gate-limits.json`: `{probes: 8, caught: 4, missed: 4}`, `restored_clean: true`. Schema differs from the run files — a separate record type, not a run — so the loader must not try to read it through the same path |

## 9. Agent Review

Round 1 (Fable 5) returned **NEEDS_REVISION** with P1 and P4 FAIL and a
ticket-revision blocker. Round 2 re-verified every round-1 fix against the
artifacts rather than the plan's prose and found them all holding — all seven rubric rows
PASS — but returned NEEDS_REVISION again on three factual errors introduced by time
passing: the source repository gained a fourth commit after the first revision, leaving an
undetectable stale-clone import; the new record-universe table placed `gate-limits.json`
in `data/runs/` when it lives at `data/gate-limits.json`; and this plan's opening line
still said three commits. All three are fixed above, and AC-1 now asserts staleness
semantically (the corrected sentence must be present) rather than by commit count.

One correction ran the other way. Round 2 endorsed the AC-2 derivation as "implementable
and gives the right answer", having checked the outcome — which run timestamps fall either
side of the commit — rather than the mechanism. The mechanism as worded, "files introduced
by the commit after it", misclassifies two round-one files that a later commit renamed.
The derivation is now over run ids rather than paths, and both rejected alternatives are
recorded in AC-2 so neither is tried again.

Round 3 re-verified all three round-2 blockers and the AC-2 rework against the
source repository rather than this plan's prose, and confirmed each. It returned
NEEDS_REVISION on one mechanical survivor: the round-2 "three commits → four" correction
had reached §1 and step 1 but missed §4's first risk bullet and — the one that mattered —
§7's AC-1 assertion, the normative text stage 4 writes the scenario from. Round 3 also
recommended quoting the staleness anchor literally rather than leaving stage 4 to choose
one.

Round 4 confirmed both round-3 blocker sites fixed and re-derived every factual
claim from the source repository: four commits at the tip, `869b7de` preceding the
earliest derived round-two run by 50m 16s, 17 files in `data/runs/`, one fingerprint
across all 8 acceptance records, and the 9−3=6 run-id derivation — checked against the
`869b7de` tree, where the three round-one ids appear under their **pre-rename** filenames,
which is the direct evidence that both rejected derivations misfire. It confirmed all
eight scenario assertions are RED-capable on today's tree. Its full-document sweep for the
staleness error class found two more instances, both inert narrative text: §4 called
`5d3ba47` "the source repo's last commit" (true until `d63ff3b` landed) and §8.5 gave
`PREREGISTRATION.md` as 202 lines (now 210). Both are corrected above. Verdict
**APPROVED_WITH_NOTES**, zero blockers.

**On the timestamps in this section.** An earlier revision labelled these four rounds with
wall-clock times (14:40, 16:10, 17:05, 17:36). Those times were invented: they postdate
both this file's last write and the clock at which they were written. The report review
caught it and blocked on it, correctly — in a project whose central evidence is that a
preregistration commit precedes the runs it predicts, a receipt that postdates itself is
the exact failure this repository exists to reject.

Per-round wall-clock was never recorded, so it is not reconstructed here. What is
verifiable: `preflight` stamped 2026-08-17 15:00:18 +0900 and `plan-reviewed` stamped
15:38:00 +0900 (`.docs/state/PDX-002.state`, corroborated by
`.docs/scratch/gate-runs.jsonl`), so all four rounds ran inside that 38-minute window.
Rounds are identified by ordinal, which is what the gate actually needs.

### Reviewer
- Model: Fable 5
- Reviewed at: 2026-08-17, before the `plan-reviewed` stamp at 15:38:00 +0900

### Verdict
- [ ] APPROVED
- [x] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | §3 touches only Scope.Allowed paths (`bench/`, `packages/data/`, root manifests, `README.md`, e2e); all four NotAllowed honored (no `--squash`; the ~10 GB stays in `pack-pilot`; no number changes; archiving deferred per CR-01); every AC 1–7 maps to a step and a §7 assertion |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | Steps 2–7 touch 1–2 files each; step 1 is a single `git subtree add` verified by reading author dates back (plan step 1) |
| P3 | Decision consistency: no conflict with DESIGN.md decisions or the decision log | PASS | §6 applies DEC-002 (no-allowlist honored in §4: "not allowlisted") and DEC-003 (`data` as first of three packages); no conflict with DEC-001–006 on a full read of the log |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | `tests/e2e/PDX-002-records-are-traceable.sh` with explicit RED (verify PASS + scenario FAIL) and GREEN (no empty-workspace warning + regression); all 8 assertions verified RED-capable today (no `bench/`, no `packages/`, `verify.sh:67` prints "empty-workspace mode", AC-7 anchor present on `README.md:38`); staleness anchor confirmed single-line at source `PREREGISTRATION.md:204` |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | §4 lists seven risks each with a mitigation (incl. stale-clone: fetch-first + semantic anchor); §5 names six exclusions incl. the inherited `results.json`/DATA-01 contradiction |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | Hangul grep over the plan and ticket: zero hits; `git grep` for Hangul over the entire `does-it-compile` tracked tree: zero hits, so AC-6 is satisfiable as planned |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | §8.5 shows all three required refs as Y + substantive notes, verified against the files (fingerprint `4b140e75d7dc1828`, 75 cells, `npm_extraneous: []`, gate-limits `{probes:8, caught:4, missed:4}`, `restored_clean: true`) |

### Comments

1. Surviving instance of the round-2/3 staleness class, non-blocking: §4's second risk
   bullet called `5d3ba47` "the source repo's last commit", which stopped being true when
   `d63ff3b` landed. Inert — the mitigation (fix in source, re-import, never allowlist) is
   unaffected and LANG-01 is decided by a deterministic gate. Corrected to name `5d3ba47`.
2. Second surviving instance, non-blocking: §8.5 gave `PREREGISTRATION.md` as 202 lines;
   `d63ff3b` added 8, and the file is 210, which quietly contradicted §7's own line-204
   anchor. Corrected.
3. Both round-3 blocker sites confirmed fixed: §4's first risk bullet reads "all four
   original commits' author dates" and §7's AC-1 lists all four SHAs, matching `git log`
   in the source repository with original author dates intact.
4. The AC-2 derivation was re-verified against the actual trees, not the prose. The
   `869b7de` tree holds run ids 225842/010513/020247 under the pre-rename filenames
   `*-run1` / `*-run2` — direct evidence that both rejected derivations misclassify, and
   that the run-id set difference yields exactly the six claimed. Note 222615 has only a
   `.results.json`, which the id-based derivation handles and a file-based one would not.

### Blockers (only if NEEDS_REVISION)

- None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (Fable 5, round 4) — both notes applied
- Human: _(pending)_
