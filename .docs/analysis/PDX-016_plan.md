# PDX-016 Plan — Withdrawn runs are a record, not a filename

- Ticket: `.docs/tickets/PDX-016_data-withdrawn-runs-are-a-record-not-a-filename.md`
- Author: Fable 5 (planning agent)
- Date: 2026-08-17

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

Two deliberate non-changes, both of which the review should rule on rather than discover:

- **`derive_d001.py` keeps its `startswith("20260815-225842")` comparisons.** Verified:
  every one of them operates on the corpus *frozen at `63735e6`*, read via `git show` —
  a historical tree whose records do not and can never carry the field, because history
  is immutable and the whole point of that code is to reproduce the past corpus exactly.
  They are subset *selection inside a forensic derivation*, not exclusion of live records
  from a published pool; the live-corpus half (`current_corpus()`) goes through
  `load_cells` and touches no filename. AC-4's sentence "a filename-prefix comparison
  surviving anywhere in `bench/harness/` is a BLOCK" is therefore read as "no filename
  comparison may *decide inclusion of a live record in an analysis pool*", enforced
  behaviourally by DATA-02d (below) plus the deletion of `WITHDRAWN_RUN`. `derive_d001.py`
  is not in the ticket's Scope.Allowed, so amending it is not an option this ticket has;
  if the reviewer reads AC-4 literally, the resolution is a ticket amendment clarifying
  the AC (precedent: PDX-003 round 3 and PDX-004 B4 both amended ticket text when an AC's
  letter contradicted its intent), not an out-of-scope edit.
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

**Decision: defer regime to a named successor ticket, and say what that costs.**

- Why not fold it in: the ticket's ACs are all withdrawal; its Scope.Allowed grants
  "the withdrawal field written onto the affected run" — one field, one record. Regime
  relocation writes a field onto **all ten** records, changes `load_cells`' tagging, and
  needs its own before/after derivation — it would triple the corpus edit surface and
  destroy the property that makes AC-3 checkable, namely that this diff is a single-field
  relocation whose only possible effect on any count is the one the scenario measures.
  P1 scores scope fidelity against the ticket as written; regime is not in it.
- What the deferral costs, stated plainly: `check-data-universe.sh` ships with a hole its
  own rationale describes. DATA-02d proves the *withdrawal* decision cannot come from a
  filename while `_regime`, in the same function, still does. The gate's rule set does not
  cover regime yet because there is no record field for it to check agreement against —
  the field is the successor ticket's deliverable, and a gate row that asserts agreement
  with a field that does not exist would block every run in the corpus today.
- The successor: step 9 adds a row to DESIGN.md's harness-debt table —
  "regime is a record, not a filename" — under the next free ticket id, derived at
  implementation from `.docs/tickets/` and the DESIGN.md roadmap (measured now: PDX-015
  and PDX-016 are the highest allocated, so it is PDX-017; the step re-derives rather
  than trusts this). The row names the same mechanism (optional record field, both
  loaders, a DATA-02 rule row + golden cases on both sides), so the gate is extended, not
  re-invented. DATA-02's sub-rule lettering leaves room for it by design.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: every step in §3 touches only
  `packages/data/src/{schema,load,index}.ts`, `packages/data/src/load.test.ts`,
  `bench/data/runs/*.acceptance.json` (one file, one added key),
  `bench/harness/fisher.py`, `bench/DERIVATIONS.md`, `scripts/check-data-universe.sh`,
  `scripts/verify.sh`, `tests/meta/cases/`, `tests/e2e/PDX-016-*.sh`, and `DESIGN.md`.
- **Ticket Scope.NotAllowed respected**:
  - **No cell, outcome, or figure changes.** The record edit adds one top-level key; the
    D-003 reproduce command and the scenario's AC-3 comparison both prove the counts are
    unmoved, and the scenario additionally re-derives two published anchors (D-002's
    49-of-50 and D-001's excluded-pool table) so "no figure moves" is measured, not
    asserted.
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
| 1 | The field, the parser, the two views | `packages/data/src/schema.ts`, `packages/data/src/load.ts`, `packages/data/src/index.ts` | `Withdrawal` type + optional `withdrawn` on `AcceptanceRecord`; `withdrawnRecords` on `AcceptanceCorpus`; parse `withdrawn` with `UnreasonedWithdrawalError` on a present-but-unreasoned value; `includeWithdrawn` option (destructured, default false); fingerprint check stays over all records; export the new type and error. JSDoc in English throughout |
| 2 | Unit coverage on synthetic corpora | `packages/data/src/load.test.ts` | Extend `buildRecord`/`plantCorpus` with a `withdrawn` param. Cases in §7. Synthetic-first so no assertion depends on which runs happen to exist (AC-2), plus one committed-corpus consistency test |
| 3 | The withdrawal, written onto the record | `bench/data/runs/20260815-225842-frontend-withdrawn-different-prompt.acceptance.json` | Add the one top-level key shown in §1, `recorded_at` from `git log -1 --format=%aI 5d3ba47`. The edit is a scripted single-key insert; the sibling `.results.json` is untouched. AC-3's comparison is what proves no cell moved |
| 4 | fisher.py reads the record | `bench/harness/fisher.py` | Delete `WITHDRAWN_RUN`; skip on the parsed record's `withdrawn`; `ValueError` on unreasoned withdrawal; `_withdrawn` cell tag; `include_withdrawn=True` unchanged and reachable; textbook self-validation untouched. Update the `__main__` corpus line's wording only if needed — its numbers are computed, not typed |
| 5 | The gate and its verify step | `scripts/check-data-universe.sh`, `scripts/verify.sh` | DATA-02a–d as specified below, `check-src.sh` as the model: sentinel-printing subprocess, non-empty capture required, count floor, OBS-01 via `gate-log.sh`. New verify step after templates (python + bench only, no build needed); later step labels renumber mechanically |
| 6 | Golden cases: the three record-side rules | `tests/meta/cases/` (3 files, numbers derived at implementation — measured now the next free are 28–30) | DATA-02a (the regression that matters most: filename-only withdrawal), DATA-02b, DATA-02c — each built to trip exactly one rule; construction table below |
| 7 | Golden cases: the harness rule and the clean pass | `tests/meta/cases/` (2 files) | DATA-02d (a planted old-style filename-excluding `load_cells` is caught behaviourally) and the `EXPECT_PASS=1` clean case guarding against false positives |
| 8 | The derivation entry | `bench/DERIVATIONS.md` | Next free entry number, derived from `grep '^## D-'` at write time (measured now: D-001 and D-002 exist, so D-003). Contents specified below |
| 9 | The decision, and the successor ticket | `DESIGN.md` | Decision-log entry "a fact that governs the analysis is a record field, never a filename" under the next number actually free in the log at commit time (measured now: DEC-015 — see the collision note in §4); harness-debt row for the regime successor ticket |

**The gate — `scripts/check-data-universe.sh`, rule DATA-02.** DATA-01 says no figure is
hand-typed; DATA-02 says no fact that governs the analysis lives outside the record. Four
lettered violations, each with a one-line reason in the script header, `check-src.sh`
style:

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
- **DATA-02d** — a filename-based exclusion surviving in the harness, proven
  behaviourally rather than by grep: the gate writes a two-record synthetic corpus into a
  `mktemp -d` directory — a *decoy* (filename contains `withdrawn`, record clean) and a
  *marked* record (record-withdrawn, clean filename) — then runs
  `load_cells(runs_dir=...)` under both flags and asserts: decoy cells present in the
  default view (any filename mechanism, however spelled, fails here), marked cells absent
  by default and present when pooled (`include_withdrawn=True` is reachable). The
  synthetic directory is the gate's own instrument and is exempt from the a/b agreement
  scan, which runs only over `bench/data/runs/`. A grep would only catch the spelling of
  the last bug; this catches the mechanism.

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
- **DEC-number collision**: PDX-004's plan proposes DEC-015..017, but those are
  plan-stage proposals in a paused ticket, not landed log entries — the DESIGN.md log
  ends at DEC-014 today. This ticket takes the next number actually free in the log at
  its commit time; PDX-004's round-2 revision renumbers its proposals. A plan does not
  reserve log numbers. Flagged for the reviewer to confirm this ordering rule.
- **`derive_d001.py`'s frozen-corpus prefix comparisons vs AC-4's literal wording** →
  ruled on in §1 (they select within an immutable historical tree, they exclude nothing
  from a live pool, and the file is outside Scope.Allowed); if the reviewer holds the
  literal reading, the resolution is a ticket amendment to AC-4's sentence, per the
  PDX-003/PDX-004 amendment precedent.
- **verify.sh renumbering breaks something** → the step labels are cosmetic; the gate
  order (new step after templates, before Node steps — it needs only python3 and
  `bench/`) is asserted by the scenario's AC-7 check on verify output, and the golden set
  replay inside verify catches any wiring mistake in the same run.

## 5. Out of Scope

- **Regime as a record field** — deferred with a named successor ticket and stated costs
  (§1). The same mechanism, the same gate family, its own before/after derivation.
- **`bench/harness/acceptance.py` and `derive_d001.py`** — the grader does not
  adjudicate, and the forensic derivation reads immutable history; neither is in
  Scope.Allowed.
- **A WORKFLOW.md rules-table row for DATA-02.** `docs/WORKFLOW.md` and `CLAUDE.md` are
  not in Scope.Allowed, so the rule is documented in the gate's header and the DESIGN.md
  decision entry. Flagged for the reviewer: either this rides to the next docs/harness
  ticket, or the ticket's Scope.Allowed gains `docs/WORKFLOW.md` by amendment. The gate's
  teeth do not depend on the table row.
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
  the record is a figure nobody can check. The new DATA-02 is its record-side sibling.
- **CLAIM-01** — the withdrawal stays reachable with its cause attached, in every view,
  in both languages; deleting the record would be worse than never withdrawing it.
- **GATE-01** — the new gate lands with golden cases on both sides in the same ticket,
  like SRC-01 did with PDX-003.
- **ASSERT-01 / PLAN-01** — sentinels and floors throughout (§3, §7); every number in
  this plan is either marked measured-now with its producing command or written as a
  claim the scenario asserts.
- **DEC-005** — this ticket repairs the defect class DEC-005's second ground names; its
  rationale text is untouched (the regime half of that ground remains true until the
  successor ticket lands).
- **DESIGN.md decision produced**: "a fact that governs the analysis is a record field,
  never a filename" — next free DEC number at commit time (§4 collision note).

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
  `rate_table` semantics on outcome `build` — a cell with no `build` field is skipped,
  `hits` counts `build === true`, `n` counts cells where the field is present.
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
  volatile state.

**Per-AC RED / GREEN:**

| AC | RED today because | GREEN asserts |
|---|---|---|
| AC-1 | no record carries `withdrawn` (grep over `packages/data/src/` and the corpus both come back empty — and the scenario treats that empty capture as the failure it is, behind a sentinel-printing python scan) | a python scan of all acceptance records finds ≥ 1 record-flagged withdrawal, run `20260815-225842` among them, `reason` non-empty and naming instrument failure 16, `recorded_at` present; and the built package's corpus exposes the same run in `withdrawnRecords` with the parsed `Withdrawal` |
| AC-2 | `loadAcceptanceRecords` has no `includeWithdrawn` and no `withdrawnRecords`; the node probe's synthetic-corpus assertions fail on the old dist | a node probe over a synthetic corpus planted in `mktemp -d` (never the live one, so the assertion is independent of which runs exist): default view excludes the withdrawn record, `includeWithdrawn: true` pools it, `withdrawnRecords` carries it in both views, and a planted no-reason withdrawal makes the loader throw — asserted on the error name, sentinel-wrapped |
| AC-3 | the cross-implementation comparison above fails — TS-default equals Python-*pooled*, not Python-default; this is the disagreement the ticket ends, proven ended rather than asserted | the full comparison above passes with all floors |
| AC-4 | `WITHDRAWN_RUN` exists in `fisher.py` (grep positive), and the decoy probe shows `load_cells` is filename-sensitive | `grep WITHDRAWN_RUN bench/harness/` is empty *and* the behavioural decoy probe (same design as DATA-02d, run directly by the scenario against the real `fisher.py` with a synthetic `runs_dir`) shows filename-insensitivity, `include_withdrawn=True` still pooling, and `python3 bench/harness/fisher.py` still printing its "3 textbook tables validated" line — self-validation alive, not assumed |
| AC-5 | `scripts/check-data-universe.sh` does not exist | the gate exists, is executable, PASSes on the live tree with its `DATA-02 PASS` sentinel, and `./scripts/check-gates.sh <new-case-numbers>` (numbers derived at run time by globbing `tests/meta/cases/` for the DATA-02 cases, not hard-coded) replays all five cases green |
| AC-6 | `bench/DERIVATIONS.md` has no entry past D-002 (`grep -c '^## D-'` is 2, measured now — the scenario derives the count rather than trusting this) | a new `## D-` entry exists naming run `20260815-225842`, containing a fenced reproduce command and the no-figure-moves statement; the scenario executes the published anchors (the D-002 command and `derive_d001.py`) as specified above rather than trusting the entry's prose |
| AC-7 | `verify.sh` output contains no `DATA-02` | captured verify output (captured then searched — never piped into `grep -q` under pipefail, the PDX-003 SIGPIPE lesson) is non-empty and contains the DATA-02 gate's pass line; the golden set is unregressed because check-gates runs inside that same verify |

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
- `harness` — fisher.py's corpus selection, the DATA-02 gate, verify wiring

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
| bench/harness/fisher.py + derive_d001.py + acceptance.py | Y (2026-08-17) | `WITHDRAWN_RUN` prefix skip and the `_regime`-from-filename confession in the same docstring (the deferral §1 rules on); derive_d001's prefix comparisons all address the `63735e6` frozen corpus via `git show`; acceptance.py writes records but never adjudicates them |
| scripts/check-src.sh, check-gates.sh, tests/meta/cases (01, 18, 23) | Y (2026-08-17) | the sentinel + non-empty-capture + count-floor shape DATA-02 copies; check-gates greps only for `EXPECT_PATTERN` presence — the reason each case must trip exactly one rule; cases plant their own fixtures because sandboxes copy `scripts/` only |
| tests/e2e/PDX-003-the-hub-installs.sh | Y (2026-08-17) | the scenario format: per-AC pass/fail with sentinels, the capture-then-grep pipefail lesson for AC-7, and the derived-not-hardcoded list discipline AC-3's comparison follows |

## 9. Agent Review

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
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | | |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | | |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | | |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | | |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | | |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | | |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | | |

### Comments
1.

### Blockers (only if NEEDS_REVISION)
-

## 10. Final Plan Status

- Agent: _(pending)_
- Human: _(pending)_
