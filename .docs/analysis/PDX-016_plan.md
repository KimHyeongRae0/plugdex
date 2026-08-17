# PDX-016 Plan — Withdrawn runs are a record, not a filename

- Ticket: `.docs/tickets/PDX-016_data-withdrawn-runs-are-a-record-not-a-filename.md`
- Author: Fable 5 (planning agent)
- Date: 2026-08-17 (revision 2, after the round-1 plan review and the ticket amendment)

## 1. Goal & Context

The project computes its figures in two languages, and they disagree about what the
corpus is. `bench/harness/fisher.py:74` skips the withdrawn run by comparing filenames
against the constant `WITHDRAWN_RUN = "20260815-225842"`; `packages/data/src/load.ts:206`
reads every `*.acceptance.json` and has no concept of withdrawal at all — no schema
field, no loader branch (`grep -rn withdrawn packages/data/src/` returns nothing). Every
figure in `bench/README.md` and `bench/DERIVATIONS.md` is computed on the excluded pool;
every figure the site would compute through `@plugdex/data` is computed on the pooled
one. Measured now (2026-08-17, `python3 bench/harness/fisher.py` plus a valid-cell
one-liner over `load_cells`): the excluded view is 371 cells of which 283 are valid, the
pooled view is 447 of which 357 are valid — a 74-valid-cell disagreement, all of it the
withdrawn run. These numbers are quoted as evidence of the current state, not as plan
constants; the scenario derives every one of them at run time (PLAN-01).

One fact keeps this a near-miss instead of a shipped error: the set of arm names is
identical in both views (verified against `load_cells` under both flags), and PDX-004 —
the first ticket that would have rendered a number — was paused when its plan review
found this. Nothing published today is wrong. The first card rendered would have been.

This ticket moves the exclusion into the record. The defect class is the one DEC-005
records as its second ground for refusing a leaderboard — a fact that governs the
analysis living in a filename rather than in the data — made by this project for the
second time. So the fix is not a patch to the loader; it is a field, both loaders honouring
it, a gate that makes the filename mechanism unrevivable, and a derivation entry proving
the published figures did not move.

**The one claim this plan must make checkable is AC-3: no figure moves.** The whole
ticket is a relocation of where an exclusion is recorded. §7's scenario therefore runs
both implementations over the live corpus and compares the counts they produce — and the
comparison is built so it cannot pass on empty output, on two accidentally-equal views,
or on a field that was never written (ASSERT-01; the specific floors are in §7).

### The record has no header object — where the field goes

The ticket says "run header". Verified against two records
(`20260815-225842-frontend-withdrawn-different-prompt.acceptance.json`,
`20260816-020247-frontend.acceptance.json`): the top level is flat — `run` is a plain
string sibling of `env` and `cells`, and there is no header object to hang anything on.
So `withdrawn` becomes a fourth optional top-level key, snake_case like everything else
the harness writes:

```json
{
  "run": "20260815-225842",
  "withdrawn": {
    "reason": "instrument failure 16: the run carried an extra instruction the other runs did not, and was graded against a different set of installed packages (bench/PREREGISTRATION.md, failures 15-16)",
    "recorded_at": "<author date of the withdrawing commit 5d3ba47, derived at implementation via git log -1 --format=%aI 5d3ba47>"
  },
  "env": { ... },
  "cells": [ ... ]
}
```

`recorded_at` is the date the withdrawal was adjudicated, not the date this ticket runs —
inventing a timestamp is the exact defect the PDX-002 report review blocked on. The
withdrawal was recorded by `5d3ba47` ("Withdraw the two-run reproduction claim…"), which
the subtree import preserved with its author date intact, so the value is derived from
git rather than typed.

In TypeScript (`schema.ts`), the field is:

```ts
/** A withdrawal the record carries: the cause, and when it was adjudicated. */
export type Withdrawal = {
  /** Why the run was withdrawn. A withdrawal with no stated cause is refused at parse. */
  readonly reason: string;

  /** When the withdrawal was recorded (ISO 8601), from the adjudication, not the edit. */
  readonly recordedAt: string;
};
```

with `readonly withdrawn?: Withdrawal` on `AcceptanceRecord`. A record where `withdrawn`
is present but `reason` or `recorded_at` is missing or empty throws a new
`UnreasonedWithdrawalError` — a parse error, never a silent exclusion, because a
withdrawal with no stated cause is the thing this project refuses (CLAIM-01's whole
argument is that the cause stays attached to the correction).

### The loader's two views

D-001's argument is *about* the pooled figures — the 0.0352 → 0.0055 move is the evidence
that pooling matters — so the pooled corpus must stay deliberately reachable, not be
deleted. `loadAcceptanceRecords` keeps its single destructured-object signature and gains
one option:

```ts
export const loadAcceptanceRecords = ({
  dir,
  includeWithdrawn = false,
}: {
  dir: string;
  includeWithdrawn?: boolean;
}): AcceptanceCorpus => { ... };
```

- **Default view** (`includeWithdrawn` absent or false): `records` and `cells` contain
  only non-withdrawn runs. This is what every consumer that renders a figure gets.
- **Pooled view** (`includeWithdrawn: true`): `records` and `cells` contain everything.
  This is how D-001-style derivations are recomputed deliberately.
- **Always**, in both views: `AcceptanceCorpus` gains
  `readonly withdrawnRecords: readonly AcceptanceRecord[]` — the withdrawn records,
  parsed and marked. A withdrawn run stays in the corpus, reachable; that is the
  difference between a withdrawal and a disappearance (ticket Scope, CLAIM-01).

The fingerprint invariant runs over **all** parsed records including withdrawn ones —
the withdrawn run shares fingerprint `4b140e75d7dc1828` with the live runs (it was
withdrawn for a different prompt, not a different environment; the PDX-002 plan records
this limit explicitly), so behaviour on today's corpus is unchanged, and a future
withdrawn record from an alien environment still refuses to union. A corpus where every
run is withdrawn returns an empty default pool rather than falling back to including
them — an empty result is a result; only a directory with no acceptance files at all
remains the existing `MalformedRecordError`.

### The Python side

`fisher.py`'s `load_cells` keeps its signature (`include_withdrawn=False`,
`runs_dir=RUNS_DIR` — both callers in `derive_d001.py` survive unchanged) and changes
its mechanism: the file is parsed first, and the skip decision reads
`record.get("withdrawn")` instead of `name.startswith(WITHDRAWN_RUN)`. The
`WITHDRAWN_RUN` constant is deleted. A `withdrawn` value that is present but lacks a
non-empty `reason` or `recorded_at` raises `ValueError` — the same refusal the TS parser
makes, so the two implementations cannot disagree about a malformed withdrawal either.
When pooling, each cell from a withdrawn record is tagged `_withdrawn = True` (and
`False` otherwise), alongside the existing `_run`/`_regime` tags, so a derivation can
select withdrawn cells from the record rather than from a name. The import-time textbook
self-validation is untouched — nothing in this change is anywhere near
`fisher_exact_two_tailed` — and the scenario asserts it still prints its three-table
sentinel rather than assuming.

Two deliberate non-changes, both now settled by the amended ticket:

- **`derive_d001.py` keeps its `startswith` comparisons, and the amended AC-4 states the
  contract that makes this compliant rather than tolerated:** *"No filename comparison
  may decide whether a live record enters an analysis pool"*, with an explicit exemption
  for selections over a frozen historical corpus read through `git show <commit>:` —
  naming `derive_d001.py`'s read of the corpus as it stood at `63735e6`, whose records
  can never carry the field. Verified (and re-verified by the round-1 review at
  `derive_d001.py:100/:101/:138`, plus the task-name prefix at `:50` the original
  wording would also have swept): every prefix comparison in that file operates on the
  frozen tree; the live-corpus half (`current_corpus()`) goes through `load_cells` and
  touches no filename. The ticket carries the correction inline per CLAIM-01, and this
  plan now quotes the contract instead of narrowing it. AC-5(b) enforces the same
  wording: DATA-02d (below) proves behaviourally that no filename comparison decides a
  live record's inclusion, and the frozen-corpus exemption costs the gate nothing
  because `git show` reads never pass through `load_cells`.
- **`bench/harness/acceptance.py` is untouched.** It grades runs; it does not adjudicate
  them. A withdrawal is a human decision recorded onto a record after the fact — the one
  that exists was adjudicated in `5d3ba47` — and teaching the grader to emit the field
  would put the adjudication in the instrument. `acceptance.py` is also not in
  Scope.Allowed.

### The second filename-borne fact: regime — ruled on, not folded in

`load_cells`'s own docstring confesses the sibling defect in the same breath: `_regime`
is derived by `"as-shipped" in name` because the runner gained the regime stamp after
these runs were written — "a run-level condition that moves the baseline build rate from
35% to 73% living only in a human-readable filename is a DATA-01 problem in spirit".
DEC-005 cites exactly this as its second ground. Two run-level governing facts live in
filenames; this ticket relocates one of them.

**Decision: defer regime to a named successor ticket, and say what that costs.** The
round-1 review upheld this ruling on its own verification.

- Why not fold it in: the ticket's ACs are all withdrawal; its Scope.Allowed grants
  "the withdrawal field written onto the affected run" — one field, one record. Regime
  relocation writes a field onto **all ten** records, each needing its own adjudication,
  changes `load_cells`' tagging, and needs its own before/after derivation — it would
  triple the corpus edit surface and destroy the property that makes AC-3 checkable,
  namely that this diff is a single-field relocation whose only possible effect on any
  count is the one the scenario measures. P1 scores scope fidelity against the ticket as
  written; regime is not in it.
- What the deferral costs, stated plainly — **and stated at the enforcement point, not
  only here**: `check-data-universe.sh` ships with a hole its own rationale describes.
  DATA-02d proves the *withdrawal* decision cannot come from a filename while `_regime`,
  in the same function, still does. The gate's script header discloses this (§3): its
  principle — no fact that governs the analysis lives outside the record — is broader
  than its round-1 enforcement, and the header points at the successor ticket, so the
  reader the gate blocks sees the boundary of what it checked.
- The successor: step 10 adds a row to DESIGN.md's harness-debt table —
  "regime is a record, not a filename" — under the next free ticket id, derived at
  implementation from `.docs/tickets/` and the DESIGN.md roadmap (measured now: PDX-015
  and PDX-016 are the highest allocated, so it is PDX-017; the step re-derives rather
  than trusts this). The row names the same mechanism (optional record field, both
  loaders, a DATA-02 rule row + golden cases on both sides), so the gate is extended, not
  re-invented. DATA-02's sub-rule lettering leaves room for it by design.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: every step in §3 touches only
  `packages/data/src/{schema,load,index}.ts` (the amended ticket lists `index.ts`
  explicitly — the public surface the new type and error are exported through),
  `packages/data/src/load.test.ts`, `docs/WORKFLOW.md` and `CLAUDE.md` (the amended
  ticket lists both, for the rules-table row, the script-table row, and the `verify.sh`
  composition lines — including the PDX-003 drift the same touch corrects),
  `bench/data/runs/*.acceptance.json` (one file, one added key),
  `bench/harness/fisher.py`, `bench/DERIVATIONS.md`, `scripts/check-data-universe.sh`,
  `scripts/verify.sh`, `tests/meta/cases/`, `tests/e2e/PDX-016-*.sh`, and `DESIGN.md`.
- **Ticket Scope.NotAllowed respected**:
  - **No cell, outcome, or figure changes.** The record edit adds one top-level key; the
    D-003 reproduce command and the scenario's AC-3 comparison both prove the counts are
    unmoved, and the scenario additionally re-derives two published anchors (D-002's
    49-of-50 and D-001's excluded-pool table) so "no figure moves" is measured, not
    asserted. The documentation step changes prose tables only, no behaviour.
  - **No withdrawal or un-withdrawal.** The one withdrawal recorded is instrument
    failure 16, already adjudicated in `5d3ba47`; the field records that adjudication
    with its own date.
  - **No deletion.** The withdrawn record stays on disk and stays parsed;
    `withdrawnRecords` keeps it reachable in every view.
  - **Nothing in `packages/site/`, `packages/registry/`, or the verdict function**, and
    no deploy, announcement, or outward action (CR-01). PDX-004 resumes after this.

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | The field, the parser, the two views | `packages/data/src/schema.ts`, `packages/data/src/load.ts`, `packages/data/src/index.ts` | `Withdrawal` type + optional `withdrawn` on `AcceptanceRecord`; `withdrawnRecords` on `AcceptanceCorpus`; parse `withdrawn` with `UnreasonedWithdrawalError` on a present-but-unreasoned value; `includeWithdrawn` option (destructured, default false); fingerprint check stays over all records; export the new type and error through `index.ts` (in Scope.Allowed per the amended ticket). JSDoc in English throughout |
| 2 | Unit coverage on synthetic corpora | `packages/data/src/load.test.ts` | Extend `buildRecord`/`plantCorpus` with a `withdrawn` param. Cases in §7. Synthetic-first so no assertion depends on which runs happen to exist (AC-2), plus one committed-corpus consistency test |
| 3 | The withdrawal, written onto the record | `bench/data/runs/20260815-225842-frontend-withdrawn-different-prompt.acceptance.json` | Add the one top-level key shown in §1, `recorded_at` from `git log -1 --format=%aI 5d3ba47`. The edit is a scripted single-key insert; the sibling `.results.json` is untouched. AC-3's comparison is what proves no cell moved |
| 4 | fisher.py reads the record | `bench/harness/fisher.py` | Delete `WITHDRAWN_RUN`; skip on the parsed record's `withdrawn`; `ValueError` on unreasoned withdrawal; `_withdrawn` cell tag; `include_withdrawn=True` unchanged and reachable; textbook self-validation untouched. Update the `__main__` corpus line's wording only if needed — its numbers are computed, not typed |
| 5 | The gate and its verify step | `scripts/check-data-universe.sh`, `scripts/verify.sh` | DATA-02a–d as specified below, `check-src.sh` as the model: sentinel-printing subprocess, non-empty capture required, count floor, OBS-01 via `gate-log.sh`. The header carries the regime-hole disclosure (below). New verify step after templates (python + bench only, no build needed); later step labels renumber mechanically |
| 6 | The rule is documented where readers look | `docs/WORKFLOW.md`, `CLAUDE.md` | DATA-02's row in the WORKFLOW §3 rules table, `check-data-universe.sh`'s row in the §4 script table, and both `verify.sh` composition lines — WORKFLOW's (measured now at `docs/WORKFLOW.md:153`; located by content at edit time, not by line number) and CLAUDE.md's Verification commands entry. **The same touch sweeps the drift PDX-003 left**: `check-src.sh` appears in no script table, and neither composition line mentions the SRC-01 verify step. The sweep is a disclosed extra riding here because it is the same file, the same class of drift, and this project's pitch is that the receipt matches the claim — a verify pipeline documented as eight steps while running ten is a receipt that undersells its own gate stack. Prose tables only; changes no behaviour, and the amended ticket's Scope.Allowed names it |
| 7 | Golden cases: the three record-side rules | `tests/meta/cases/` (3 files, numbers derived at implementation — measured now the next free are 28–30) | DATA-02a (the regression that matters most: filename-only withdrawal), DATA-02b, DATA-02c — each built to trip exactly one rule; construction table below |
| 8 | Golden cases: the harness rule and the clean pass | `tests/meta/cases/` (2 files) | DATA-02d (a planted old-style filename-excluding `load_cells` is caught behaviourally) and the `EXPECT_PASS=1` clean case guarding against false positives. The DATA-02d case file's comment records which arm of the probe catches what (below) |
| 9 | The derivation entry | `bench/DERIVATIONS.md` | Next free entry number, derived from `grep '^## D-'` at write time (measured now: D-001 and D-002 exist, so D-003). Contents specified below |
| 10 | The decision, and the successor ticket | `DESIGN.md` | Decision-log entry "a fact that governs the analysis is a record field, never a filename" under **DEC-015**: the log ends at DEC-014 and the log allocates at landing — a plan proposes, it does not reserve — so PDX-004's round-1 plan text proposing DEC-015..017 is a superseded draft whose round-2 revision renumbers (round-1 ruling, upheld; its B1 kills the content of that draft's DEC-015 anyway). Plus the harness-debt row for the regime successor ticket |

**The gate — `scripts/check-data-universe.sh`, rule DATA-02.** DATA-01 says no figure is
hand-typed; DATA-02 says no fact that governs the analysis lives outside the record.
**The script header states both the principle and the boundary of its round-1
enforcement**: the principle covers every run-level governing fact, but this gate
enforces it for withdrawal only — `_regime` is still filename-derived in the very
function DATA-02d probes — and the header points at the regime successor ticket
(DESIGN.md harness-debt table) so the disclosure lives at the enforcement point, not
only in the design doc. Four lettered violations, each with a one-line reason in the
header, `check-src.sh` style:

- **DATA-02a** — a run whose filename claims withdrawal (basename contains `withdrawn`,
  case-insensitive) while its record carries no well-formed `withdrawn` field. This is
  the regression the ticket exists to prevent: a future run withdrawn by filename only.
- **DATA-02b** — the reverse: a record-withdrawn run whose filename does not say so. The
  name is a courtesy now, not a mechanism, but the two must agree — a name contradicting
  its record is how the next reader gets misled.
- **DATA-02c** — a record whose `withdrawn` is present but lacks a non-empty `reason` or
  `recorded_at`. Mirrors both parsers' refusal at the corpus level, so a malformed
  withdrawal is blocked before either loader ever runs. **Precedence rule, stated in the
  script:** a malformed field reports DATA-02c *only* — the agreement checks (a/b) skip
  that file — so every planted violation trips exactly one rule and the golden set's
  `EXPECT_PATTERN` grep proves what it appears to prove. This repository has twice
  shipped cases that silently tripped a second rule; the precedence is designed against
  that, not discovered by it.
- **DATA-02d** — a filename comparison deciding a live record's inclusion in an analysis
  pool (AC-4's wording; the frozen-corpus exemption is free here because `git show`
  reads never pass through `load_cells`), proven behaviourally rather than by grep: the
  gate writes a two-record synthetic corpus into a `mktemp -d` directory — a *decoy*
  (filename contains `withdrawn`, record clean) and a *marked* record (record-withdrawn,
  clean filename) — then runs `load_cells(runs_dir=...)` under both flags and asserts:
  decoy cells present in the default view (any filename mechanism, however spelled,
  fails here), marked cells absent by default and present when pooled
  (`include_withdrawn=True` is reachable). The synthetic directory is the gate's own
  instrument and is exempt from the a/b agreement scan, which runs only over
  `bench/data/runs/`. A grep would only catch the spelling of the last bug; this catches
  the mechanism.

ASSERT-01 shape, copied from `check-src.sh`: the embedded python prints
`SENTINEL {json}` on its success path; a capture that does not start with the sentinel is
"the gate did not run", not a pass; the scanned-record count carries a floor of ≥ 1 on
the live corpus; and the DATA-02d subprocess has its own sentinel and floors (decoy cell
count ≥ 1, marked cell count ≥ 1) so an empty synthetic corpus cannot vacuously agree.

**Golden-case construction — each case trips exactly one rule.** For every violation
case, the other three rules are made to pass by construction, and the table below is the
checklist stage 4 writes the cases from:

| Case | Trips | Why the others stay green |
|---|---|---|
| DATA-02a | filename says withdrawn, record clean (+ one fully clean record) | 02b: no record-withdrawn run exists; 02c: no `withdrawn` field exists to be malformed; 02d: planted `fisher.py` stub honours the field |
| DATA-02b | record withdrawn with full reason + `recorded_at`, filename clean | 02a: no filename claims withdrawal; 02c: the field is well-formed; 02d: stub honours the field |
| DATA-02c | `withdrawn` present with empty `reason`, filename also says withdrawn | 02a/b: agreement checks skip the malformed file by the precedence rule; 02d: stub honours the field |
| DATA-02d | planted `fisher.py` with the OLD `startswith` filename skip | corpus planted fully consistent (one properly withdrawn run, name and record agreeing; one live run) so 02a/b/c all pass; only the behavioural probe fires |
| clean pass (`EXPECT_PASS=1`) | nothing — `EXPECT_PATTERN="DATA-02 PASS"` | consistent corpus + field-honouring stub; guards the gate against false-positiving on a healthy tree, like cases 13 and 23 do for their gates |

A note the DATA-02d case file itself must carry (round-1 comment 8): the planted
old-style stub is caught by the **marked-record arm** of the probe — the stub, seeing a
clean filename, pools a record the field says to exclude — while the **decoy arm**
(`"withdrawn" in name`, record clean) is what catches the inverse mechanism, a loader
that trusts names over records in the other direction. Both arms are needed, both carry
their own ≥ 1 cell floors, and a case comment saying which arm fires keeps the next
editor from "simplifying" one of them away.

Each case's `plant()` writes its own `bench/harness/fisher.py` stub and
`bench/data/runs/*.acceptance.json` fixtures into the sandbox (the sandbox copies only
`scripts/`), the same self-containment as case 18's fake registry dist. No case file
hard-codes live-corpus numbers.

**The derivation entry (AC-6).** The next free entry (derived; measured now D-003)
records:

- **Before**: the withdrawal existed only in a filename; `fisher.py` excluded it by
  string prefix, `@plugdex/data` did not exclude it at all; the two views and their
  counts (all/valid, both pools), each produced by the stated command at write time, not
  copied from this plan.
- **After**: the withdrawal is a record field carrying instrument failure 16 and the
  adjudication date from `5d3ba47`; both implementations select on it; the same commands
  produce the same counts.
- **The claim that matters**: the published figures do not change — D-001's excluded-pool
  table (ponytail 0.0352, baseline 12/34) and D-002's 49-of-50 are re-derived by their own
  existing reproduce commands and quoted as unchanged, because those figures were always
  computed on the excluded pool and the excluded pool is byte-for-byte the same set of
  cells.
- **Reproduce it**: a fenced command block — the python/node count comparison (the same
  pair the scenario runs, so the entry and the gate cannot drift apart), plus
  `python3 bench/harness/derive_d001.py` and the D-002 snippet, both pre-existing.

## 4. Risks

- **The comparison passes because both sides are wrong the same way** (both pool, or the
  field was never written) → the scenario asserts `pooled_cells − default_cells` equals
  the withdrawn records' own cell count, derived at run time from the records flagged
  withdrawn, with a floor of ≥ 1 withdrawn record. If the field is missing, both sides
  pool, the difference is 0, and the assertion fails loudly instead of celebrating
  agreement.
- **A fabricated `recorded_at`** — the PDX-002 report review's exact finding, in a
  project whose central evidence is commit ordering → the value is derived from
  `git log -1 --format=%aI 5d3ba47` and the D-003 entry says so; nothing is typed from
  memory.
- **The record edit corrupts what it must not touch** → the edit is a scripted
  single-key insert; AC-3's count equality over all cells, valid cells, and per-arm build
  counts is the proof no cell moved, and the untouched `.results.json` sibling is outside
  the edit entirely.
- **A golden case trips a second rule silently** — shipped twice before in this
  repository → the DATA-02c precedence rule in the gate plus the per-case construction
  table in §3; stage 4 writes the cases from that table, and the clean-pass case guards
  the false-positive side.
- **The gate greps for a spelling instead of a mechanism** → DATA-02d is behavioural: it
  detects filename sensitivity by planting a decoy, so a re-implementation of the
  exclusion under any other name still fails.
- **The published anchors are recomputed from the live corpus, so they are fragile to
  corpus growth** → the AC-3 anchor assertions (D-002's `49 of 50`, D-001's `12/34` and
  `p = 0.0352`) re-derive from `bench/data/runs/` at every regression run. A future
  ticket that adds runs turns this scenario red for a reason unrelated to withdrawal
  mechanics — and that is defensible under CLAIM-01, because a published figure that
  moved *should* be loud, not silently re-anchored. The mitigation is not to weaken the
  assertion but to label it: each anchor's failure message names the derivation entry it
  re-derives (`D-002` / `D-001 in bench/DERIVATIONS.md`) and says "a published figure
  moved — if the corpus legitimately changed, the derivation entry must be corrected in
  place per CLAIM-01 before this assertion is touched", so the next reader knows which
  of the two failures they are looking at.
- **Two probes computing "the same" count could themselves disagree on skip semantics**
  → §7 pins the TS probe's per-arm skip condition to *absent or null*, matching
  `rate_table`'s `cell.get(outcome) is None`, and says why (measured today the corpus
  has no null outcome fields, so the two readings coincide — the pin is for the future
  record that breaks the coincidence).
- **verify.sh renumbering breaks something** → the step labels are cosmetic; the gate
  order (new step after templates, before Node steps — it needs only python3 and
  `bench/`) is asserted by the scenario's AC-7 check on verify output, and the golden set
  replay inside verify catches any wiring mistake in the same run.

## 5. Out of Scope

- **Regime as a record field** — deferred with a named successor ticket and stated costs
  (§1); the gate header discloses the hole at the enforcement point. The same mechanism,
  the same gate family, its own before/after derivation.
- **`bench/harness/acceptance.py` and `derive_d001.py`** — the grader does not
  adjudicate, and the forensic derivation reads immutable history through
  `git show 63735e6:`, which the amended AC-4 exempts by name; neither file is in
  Scope.Allowed.
- **Anything in `packages/site/`, `packages/registry/`, or `verdictFor`** — PDX-004
  resumes after this against a corpus whose exclusions are recorded.
- **Re-measuring, re-adjudicating, or adding runs**; the withdrawal recorded is the one
  already adjudicated.
- **Cost/token figures and `results.json`** — the PDX-002 record-universe boundary is
  unchanged; results files carry no fingerprint and stay outside the corpus.

## 6. Rules / Decisions Applied

- **LANG-01** — every artifact this ticket produces is English-only, including the
  withdrawal reason text and the gate output.
- **CR-01** — everything lands locally; no commit, push, issue, PR, or deploy from the
  planning or implementation stages.
- **DATA-01** — the rule this extends in spirit: a governing fact nobody can read out of
  the record is a figure nobody can check. The new DATA-02 is its record-side sibling,
  and step 6 puts it in the same normative tables DATA-01 lives in.
- **CLAIM-01** — the withdrawal stays reachable with its cause attached, in every view,
  in both languages; the amended AC-4 carries its own correction inline the same way;
  deleting the record would be worse than never withdrawing it.
- **GATE-01** — the new gate lands with golden cases on both sides in the same ticket,
  like SRC-01 did with PDX-003.
- **ASSERT-01 / PLAN-01** — sentinels and floors throughout (§3, §7); every number in
  this plan is either marked measured-now with its producing command or written as a
  claim the scenario asserts.
- **DEC-005** — this ticket repairs the defect class DEC-005's second ground names; its
  rationale text is untouched (the regime half of that ground remains true until the
  successor ticket lands).
- **DESIGN.md decision produced**: DEC-015, "a fact that governs the analysis is a
  record field, never a filename" — the log ends at DEC-014 and allocates at landing;
  PDX-004's round-1 draft proposals renumber in its own revision (§3 step 10).

## 7. Test Plan (mandatory — TDD)

- **E2E scenario file**: `tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh` (verbatim
  from the ticket's §5).
- **Global RED condition** (stage 5): `verify.sh` PASSes on the untouched tree and the
  scenario FAILs — today it fails on every AC below, and the AC-3 failure *is* the live
  defect: the TypeScript loader pools what fisher.py excludes, so the counts differ by
  the withdrawn run. A scenario that could pass before implementation would be a fake
  cycle; each assertion below states why it cannot.
- **Global GREEN condition** (stage 7): `verify.sh` PASSes with the new gate executed
  (not merely present), the scenario PASSes every assertion, and the full regression
  (`e2e.sh` no-arg: PDX-001, PDX-002, PDX-003) PASSes — PDX-002's scenario in particular,
  since it exercises the same loader.

**AC-3 — the load-bearing assertion, specified exactly.** Both implementations run over
the live corpus, both views each:

- *TypeScript*: `node --input-type=module -e` importing
  `./packages/data/dist/index.js` (built by verify in the same test-loop run), calling
  `loadAcceptanceRecords({ dir: 'bench/data/runs' })` and again with
  `includeWithdrawn: true`; for each view it emits
  `SENTINEL {"cells": N, "valid": N, "arms": {arm: [hits, n]}}` where `arms` follows
  `rate_table` semantics on outcome `build`: a cell whose `build` is **absent or null**
  is skipped — the two-sided condition matters, because `rate_table` skips on
  `cell.get(outcome) is None`, which is true for both a missing key and an explicit
  `null`. Measured today the corpus has no null outcome fields, so "absent" alone would
  coincide — but a future record carrying `"build": null` would then split the two
  probes inside the very comparison meant to prove them equal, so the TS probe pins the
  skip to `cell.build === undefined || cell.build === null`. `hits` counts
  `build === true`, `n` counts cells that were not skipped.
- *Python*: `python3` heredoc inserting `bench/harness` on `sys.path`, calling
  `load_cells()` and `load_cells(include_withdrawn=True)`, computing the same three
  numbers per view with `rate_table(cells, "build")`, printing the same
  `SENTINEL {json}`.
- *Comparison*: each of the four captures must be non-empty and sentinel-prefixed
  (a dead subprocess with discarded stderr fails here, not downstream); each JSON is
  canonicalized through `python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))'`
  (TS and Python key order differ; a raw string compare would fail on healthy output);
  then TS-default must equal Python-default byte-for-byte, and TS-pooled must equal
  Python-pooled. Comparing like with like is the point — the coordinator-verified trap is
  that fisher.py's own corpus line prints *all* cells (371/447 measured now) while the
  published tables count *valid* cells (283/357), so the scenario compares both counts,
  each labelled, and never one against the other.
- *Floors* (ASSERT-01): default `cells ≥ 1`, `valid ≥ 1`, `|arms| ≥ 2`
  (baseline plus at least one pack); withdrawn-record count ≥ 1 (derived by python from
  the records' own `withdrawn` fields, never from filenames);
  `pooled.cells − default.cells` exactly equals the withdrawn records' summed cell count
  and is ≥ 1 — so the comparison fails if the field was never written, if both sides
  accidentally pool, or if the corpus scan came back empty.
- *Published anchors*: the D-002 reproduce command (verbatim from `bench/DERIVATIONS.md`,
  sentinel-wrapped) must print `49 of 50`, and `python3 bench/harness/derive_d001.py`'s
  excluded-pool block must contain `p = 0.0352` and baseline `12/34` — anchoring the
  post-change Python to the figures published *before* the change, which closes the loop
  published-figure == new-Python == new-TypeScript. These two numbers appear in this plan
  as claims the scenario asserts, per PLAN-01 — they are frozen published values, not
  volatile state. Each anchor's failure message names its derivation entry (D-002 /
  D-001) and states that a moved figure means the derivation must be corrected in place
  per CLAIM-01 before the assertion is touched — the live-corpus fragility risk in §4,
  labelled at the point of failure.

**Per-AC RED / GREEN:**

| AC | RED today because | GREEN asserts |
|---|---|---|
| AC-1 | no record carries `withdrawn` (grep over `packages/data/src/` and the corpus both come back empty — and the scenario treats that empty capture as the failure it is, behind a sentinel-printing python scan) | a python scan of all acceptance records finds ≥ 1 record-flagged withdrawal, run `20260815-225842` among them, `reason` non-empty and naming instrument failure 16, `recorded_at` present; and the built package's corpus exposes the same run in `withdrawnRecords` with the parsed `Withdrawal` |
| AC-2 | `loadAcceptanceRecords` has no `includeWithdrawn` and no `withdrawnRecords`; the node probe's synthetic-corpus assertions fail on the old dist | a node probe over a synthetic corpus planted in `mktemp -d` (never the live one, so the assertion is independent of which runs exist): default view excludes the withdrawn record, `includeWithdrawn: true` pools it, `withdrawnRecords` carries it in both views, and a planted no-reason withdrawal makes the loader throw — asserted on the error name, sentinel-wrapped |
| AC-3 | the cross-implementation comparison above fails — TS-default equals Python-*pooled*, not Python-default; this is the disagreement the ticket ends, proven ended rather than asserted | the full comparison above passes with all floors |
| AC-4 | `WITHDRAWN_RUN` exists in `fisher.py` (grep positive), and the decoy probe shows `load_cells` is filename-sensitive | `grep WITHDRAWN_RUN bench/harness/` is empty *and* the behavioural decoy probe (same design as DATA-02d, run directly by the scenario against the real `fisher.py` with a synthetic `runs_dir`) shows no filename comparison decides a live record's inclusion — AC-4's amended wording, under which `derive_d001.py`'s `git show 63735e6:` selections are exempt by name — plus `include_withdrawn=True` still pooling, and `python3 bench/harness/fisher.py` still printing its "3 textbook tables validated" line — self-validation alive, not assumed |
| AC-5 | `scripts/check-data-universe.sh` does not exist | the gate exists, is executable, PASSes on the live tree with its `DATA-02 PASS` sentinel, and `./scripts/check-gates.sh <new-case-numbers>` (numbers derived at run time by globbing `tests/meta/cases/` for the DATA-02 cases, not hard-coded) replays all five cases green |
| AC-6 | `bench/DERIVATIONS.md` has no entry past D-002 (`grep -c '^## D-'` is 2, measured now — the scenario derives the count rather than trusting this) | a new `## D-` entry exists naming run `20260815-225842`, containing a fenced reproduce command and the no-figure-moves statement; the scenario executes the published anchors (the D-002 command and `derive_d001.py`) as specified above rather than trusting the entry's prose |
| AC-7 | `verify.sh` output contains no `DATA-02`, and neither `docs/WORKFLOW.md` nor `CLAUDE.md` mentions the gate | captured verify output (captured then searched — never piped into `grep -q` under pipefail, the PDX-003 SIGPIPE lesson) is non-empty and contains the DATA-02 gate's pass line; the golden set is unregressed because check-gates runs inside that same verify; and the documentation landed — `docs/WORKFLOW.md`'s rules table carries a DATA-02 row and both composition lines name the data-universe and SRC-01 steps (each grep RED-capable today: all four targets are absent) |

- **Unit tests** (step 2, `packages/data/src/load.test.ts`) — synthetic corpora
  throughout, mirroring the ticket's §4 edge cases:
  - a withdrawn record is excluded from the default view and listed in `withdrawnRecords`;
  - `includeWithdrawn: true` returns the pooled view, withdrawn record included and still
    listed in `withdrawnRecords`;
  - `withdrawn` present with empty/missing `reason` → throws `UnreasonedWithdrawalError`;
  - `withdrawn` present with missing `recorded_at` → throws `UnreasonedWithdrawalError`;
  - a corpus where every run is withdrawn → default view has empty `records`/`cells`,
    does not throw, does not fall back to including — an empty result is a result;
  - an empty directory still throws `MalformedRecordError` (the existing refusal is not
    weakened by the previous case);
  - a withdrawn record with an alien fingerprint still triggers
    `MixedEnvironmentError` — withdrawal does not exempt a record from the environment
    invariant;
  - committed-corpus consistency (the instrument-failure-19 pattern already in this
    file): the live corpus loads, `default.cells.length + withdrawn cells == pooled.cells.length`,
    and every `withdrawnRecords` entry carries a non-empty reason.
  The e2e can only show the loader rejects *something*; the unit tests prove it rejects
  and partitions for the stated reasons.

## 8. Feature Tags

- `data` — the record schema and the loader's two views; regression scenario `PDX-016-*`,
  and `PDX-002-*` continues to guard the loader's older refusals
- `harness` — fisher.py's corpus selection, the DATA-02 gate, verify wiring, and the
  workflow documentation the gate is now listed in

## 8.5 References Consulted (REF-01)

PDX-016 has no Reference Map entry (`check-references.sh` maps PDX-002..006 only, so the
gate passes with an info line). The references below are the ticket's §6 list plus the
artifacts this plan's claims are anchored to, recorded in the same discipline:

| Reference | Consulted | Note |
|---|---|---|
| bench/DERIVATIONS.md D-001, D-002 | Y (2026-08-17) | D-001: pooling the withdrawn run moves ponytail's p from 0.0352 to 0.0055 — the pooled view is an *argument*, which is why `includeWithdrawn` must survive; D-002: 49/50 with the withdrawn run excluded, 64/65 pooled, with a reproduce command the scenario reuses as a published anchor |
| bench/README.md | Y (2026-08-17) | the withdrawal of `20260815-225842` is recorded at lines 61-65 (extra instruction + different installed packages, instrument failures 15/16); the headline table (47% / 42% strict) is computed on the excluded pool and is among the figures AC-3 protects |
| DESIGN.md DEC-005 + Reference Map + roadmap | Y (2026-08-17) | DEC-005's second ground is verbatim this defect class ("a regime the records do not carry as a field"); the log ends at DEC-014; PDX-016's harness-debt row names the PDX-004 review as the finder; no PDX-017 exists anywhere in the tree |
| PDX-004 plan §9 / §9.1 | Y (2026-08-17) | the origin of this ticket: B2 verified first-hand (76 cells / 74 valid in the withdrawn record, `grep -rn withdrawn packages/data/src/` empty, fisher.py:74 excluding by prefix) and escalated out of the UI ticket — this plan inherits those verifications and re-derives rather than restates them |
| PDX-002 plan | Y (2026-08-17) | the accepted register for this package; its §4 already stated the limit this ticket closes ("separating withdrawn from live is CLAIM-01's job") and its fingerprint note (the withdrawn run shares `4b140e75d7dc1828`) is why the fingerprint invariant runs over all records unchanged |
| packages/data/src/{schema,load,index}.ts + load.test.ts | Y (2026-08-17) | record top level is flat `{run, env, cells}` — no header object, hence the top-level field; the loader's refusal-class pattern (`MissingFingerprintError` et al.) and the synthetic `plantCorpus` helper are what steps 1-2 extend |
| bench/data/runs/ (both header shapes) | Y (2026-08-17) | `20260815-225842-…` (76 cells, 74 valid) and `20260816-020247-frontend` (75/75) both confirm `run` is a plain string sibling of `env`/`cells`; the withdrawn record's env carries extra keys (`python_gate_present`, `mypy`, `ruff`) the parser already carries through untouched |
| bench/harness/fisher.py + derive_d001.py + acceptance.py | Y (2026-08-17) | `WITHDRAWN_RUN` prefix skip and the `_regime`-from-filename confession in the same docstring (the deferral §1 rules on); derive_d001's prefix comparisons all address the `63735e6` frozen corpus via `git show` — the read path the amended AC-4 exempts by name; acceptance.py writes records but never adjudicates them |
| scripts/check-src.sh, check-gates.sh, tests/meta/cases (01, 18, 23) | Y (2026-08-17) | the sentinel + non-empty-capture + count-floor shape DATA-02 copies; check-gates greps only for `EXPECT_PATTERN` presence — the reason each case must trip exactly one rule; cases plant their own fixtures because sandboxes copy `scripts/` only |
| tests/e2e/PDX-003-the-hub-installs.sh | Y (2026-08-17) | the scenario format: per-AC pass/fail with sentinels, the capture-then-grep pipefail lesson for AC-7, and the derived-not-hardcoded list discipline AC-3's comparison follows |
| PDX-016 ticket (as amended after round 1) | Y (2026-08-17) | re-read in full for this revision: AC-4 restated as the live-pool property with the `git show 63735e6:` exemption and inline CLAIM-01 correction; AC-5(b) aligned; Scope.Allowed extended with `index.ts`, `docs/WORKFLOW.md`, `CLAUDE.md` including the PDX-003 drift sweep |

## 9. Agent Review

Round 1 (Fable 5, 2026-08-17 20:58) returned **NEEDS_REVISION** with three blockers —
all three of them ticket defects rather than plan defects. The single FAIL row (P1)
recorded two facts about the contract, not the work: the plan touched
`packages/data/src/index.ts`, which the ticket's Scope.Allowed had omitted while
`index.ts` is the only place the new type and error can be exported; and the plan had
treated AC-4's absolute sentence by narrowing it in prose, where the reviewer's own
verification (`derive_d001.py:100/:101/:138`, plus the task-name prefix at `:50` the
sentence would also have swept) confirmed the narrowing was substantively correct and
the sentence was the defect. All four rulings the plan requested — the regime deferral,
the `derive_d001.py` exemption, the DEC-numbering rule, and the rules-table row riding
with the ticket — were upheld on the reviewer's own verification, the last one by
putting `docs/WORKFLOW.md` and `CLAUDE.md` *into* scope rather than deferring the row.

The ticket has been amended accordingly (AC-4 restated as the property it protects with
the frozen-corpus exemption and an inline CLAIM-01 correction note; AC-5(b) aligned;
Scope.Allowed extended). What this revision does — and all it claims — is bring the plan
back to the amended contract and fold in the reviewer's non-blocking notes: §1 quotes
AC-4 instead of interpreting it, §2 lists the new Allowed entries as allowed, §3 gains
the documentation step (with the disclosed PDX-003 drift sweep) and the gate-header
regime-hole disclosure, §7 pins the TS probe's skip condition to absent-or-null, §4
gains the live-corpus anchor risk with its labelled failure message, the DATA-02d case
comment records which probe arm catches what, and step 10 fixes the decision at DEC-015
under the log-allocates-at-landing rule. Round 2 confirms these against the artifacts.

### Reviewer
- Model: Fable 5 (claude-fable-5)
- Reviewed at: 2026-08-17 20:58

### Verdict
- [ ] APPROVED
- [ ] APPROVED_WITH_NOTES
- [x] NEEDS_REVISION

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | FAIL | Plan §2/§3 step 1 touch `packages/data/src/index.ts`, which the ticket's Scope.Allowed did not list, while §2 claimed "Scope.Allowed respected"; and AC-4 was addressed by narrowing its BLOCK sentence rather than as written — both fixed by ticket amendment, not by the plan alone |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | Counted per §3: steps 1/6 touch 3 files, 5/7 touch 2, steps 2/3/4/8/9 touch 1; each carries its own gate, golden case, or scenario assertion |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | PASS | The log ends at DEC-014 (`DESIGN.md:168`); PDX-004's DEC-015..017 exist only inside its round-1 NEEDS_REVISION plan; the new decision restates DEC-005's second ground (`DESIGN.md:159`) without altering it |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | §7 names `tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh` verbatim from ticket §5 with per-AC RED/GREEN rows for AC-1..7, sentinels and floors throughout; all four AC-3 numbers re-derived (371/447 all cells, 283/357 valid under both flags) and they match |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | §4 covers symmetric-failure, fabricated timestamp, double-tripping cases, spelling-vs-mechanism, DEC collision and verify renumbering, each with a mechanism; §5 is explicit — one un-listed risk (live-corpus anchor fragility) rides as a note |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | Hangul scan over the ticket and plan returned zero hits; the review is in English |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `./scripts/check-references.sh .docs/analysis/PDX-016_plan.md` → "no mapped references — nothing required / REF-01 PASS"; §8.5 notes spot-verified, including all ten records sharing fingerprint `4b140e75d7dc1828` |

### Comments
1. CR-01 acknowledged and complied with: the review was read-only — no file created or edited, no git mutation, no commit or push recommended. LANG-01 acknowledged.
2. **Ruling 1 — regime deferral is RIGHT, and the stated cost and successor are adequate.** Folding regime in would write a field onto all ten records, each needing its own adjudication, and would destroy the property that makes AC-3 checkable: that this diff is a single-field relocation whose only possible count effect is the one measured. The withdrawal defect is live and blocking PDX-004. One improvement: the gate script's header should disclose the regime hole with the successor pointer at the enforcement point, not only in DESIGN.md.
3. **Ruling 2 — the `derive_d001.py` exemption is substantively real, but it was an AC being narrowed.** The `startswith` comparisons at `:100`, `:101`, `:138` select on `_run` tags of the corpus read via `git show 63735e6:` — an immutable historical tree whose records can never carry the field — and the live-pool half goes through `load_cells` with no filename logic. The ticket is the contract, so it was amended rather than reinterpreted.
4. **Ruling 3 — DEC numbering produces no collision and no gap.** The log is the allocator and allocates at landing; a plan proposes. PDX-004's round-1 text is a superseded draft whose B1 kills DEC-015's content anyway.
5. **Ruling 4 — the rules-table row must ride with the ticket.** A rule ID enforced inside `verify.sh` but absent from every normative table exists only for readers the gate has already blocked, and the merged state would make WORKFLOW.md's own `verify.sh` composition line false. Related pre-existing drift found: `check-src.sh` appears in no script table, and neither that line nor CLAUDE.md's Verification commands line mentions the SRC-01 verify step.
6. **AC-3 vacuous-pass audit: clean.** Both-sides-pool is caught by the `pooled − default == withdrawn-cell-count ≥ 1` floor; empty output by sentinel-prefix and the `cells ≥ 1, valid ≥ 1, |arms| ≥ 2` floors; `sort_keys` canonicalisation reorders keys only and cannot hide a value difference; the like-with-like trap is explicitly labelled per view. Anchors re-run: `baseline 12/34 = 35%`, ponytail `p = 0.0352`, and the D-002 snippet's `49 of 50`. `5d3ba47` verified as the adjudicating commit, author date `2026-08-17T14:56:03+09:00`, its diff renaming the run's files to `-withdrawn-different-prompt`.
7. Two notes for the revision: (a) state the TS probe's skip condition as "absent **or** null" to match `rate_table`; (b) add the live-corpus anchor fragility to §4 with a failure message pointing at the derivation entry.
8. **Golden-case construction verified: each case trips exactly one rule.** The DATA-02c precedence rule is load-bearing — without it a malformed field also satisfies 02a's "no well-formed `withdrawn` field" and double-trips, the exact defect shipped twice before. In the DATA-02d case the planted old-style stub is caught by the marked-record arm and the decoy by the `"withdrawn" in name` arm; both arms are needed and both carry floors. Next free case numbers confirmed: the set ends at 27.

### Blockers (only if NEEDS_REVISION)
- **Ticket revision needed — AC-4's letter contradicted the plan's correct treatment of `derive_d001.py`** (P1 FAIL, part 1). Amended.
- **Ticket revision needed — Scope.Allowed omitted `packages/data/src/index.ts`** (P1 FAIL, part 2). Amended.
- **Ticket revision needed — `docs/WORKFLOW.md` must be in Scope.Allowed so DATA-02's rules-table row and the `verify.sh` composition line land with the gate.** Amended.

## 10. Final Plan Status

- Agent: _(pending — round 2)_
- Human: _(pending)_
