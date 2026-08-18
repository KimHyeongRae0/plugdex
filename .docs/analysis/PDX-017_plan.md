# PDX-017 Plan — regime is a record, not a filename

## 1. Goal & Context

`load_cells` decides which condition every cell was run under with one line:
`cell["_regime"] = "as-shipped" if "as-shipped" in name else "blocked"`. The regime moves
the baseline build rate from 25% to 73%, so that substring governs the meaning of almost
every figure this project publishes. It is DEC-015's other half, left standing on purpose
when PDX-016 relocated withdrawal, and DESIGN.md's harness-debt table has carried it since.

**What is and is not wrong today, checked rather than assumed.** An earlier draft of the
ticket claimed the heuristic already misclassifies the sonnet probe, citing
`bench/PREREGISTRATION-2.md`'s coverage table. That was checked and withdrawn before this
plan: D-002 withdrew that table as unreproducible, and `bench/README.md`'s corrected table
classifies both sonnet runs as `blocked` — which the filename derivation reproduces row for
row. The ten filenames currently encode the fact correctly.

That is the argument, not a reason against it. Nothing checks that they do. The next run
named without the substring joins the wrong pool in silence, no gate objects, and every
figure computed afterwards is wrong in a way no reader can detect. It is the state PDX-016
walked into one field over — except there the two halves had already drifted, and here
there is still time to close it before they do.

**And something is blocked on it now.** `@plugdex/data` has no regime at all, so PDX-004's
`verdictFor` pools both conditions: the card currently renders a baseline of 42%, which is
25% and 73% averaged into a rate that describes neither. Measured, not estimated —
`blocked` baseline is 5/20, `as-shipped` is 8/11, pooled 13/31. The preregistrations kept
the two apart deliberately; a card that merges them publishes a condition that never ran.

*Basis, stated because two different baseline rates circulate in this repository and a
reader meeting both would reasonably think one of them wrong.* The figures above are the
**build** outcome over **code-producing valid cells**, which is what `verdictFor` computes
and what the card renders. The 35% → 73% pair quoted in `fisher.py`'s docstring, the gate
header, and DESIGN.md's debt row is D-001's: the **passes** outcome over code-producing
cells in the blocked-haiku pool. Both are real, they answer different questions, and the
derivation entry states its basis so neither reads as a correction of the other.

**The adjudication, settled from documents rather than names.** Every record's regime is
fixed by a source that is not its filename. This table is the plan's central claim and the
scenario re-derives its consequences:

| Run | Regime | Evidence |
|---|---|---|
| `20260815-225842` (withdrawn) | `blocked` | `bench/PREREGISTRATION.md` — "Bash stays blocked, matching run `20260815-225842`" |
| `20260816-010513` | `blocked` | the per-run table in `.docs/handoff-2026-08-17-plugdex-pdx002-merged-round3-measured.md` — "backend, blocked" |
| `20260816-020247` | `blocked` | same table — "frontend, blocked" |
| `20260816-092732` | `blocked` | same table, and `bench/PREREGISTRATION-2.md` §Experiment C — "Add **caveman** as an arm across the round-1 task set, in the `blocked` regime" |
| `20260816-094325` | `blocked` | same table — "frontend, blocked" |
| `20260816-094958` | `as-shipped` | same table — "as-shipped regime"; corroborated twice: `PREREGISTRATION-2.md` places `colorpicker`'s interrupted cells in the as-shipped data, and this is one of only two runs carrying `deps: cell-local`, which requires the Bash the blocked regime withholds |
| `20260816-113302` | `as-shipped` | same table, and the other `deps: cell-local` run |
| `20260816-121801` | `as-shipped` | same table — "as-shipped, combination arm" |
| `20260816-222615` | `blocked` | D-002's corrected table row "Bash blocked, **sonnet** — 6 / 6"; the corpus holds exactly six valid sonnet superpowers cells, three here and three in `20260817-162601`, so the row decomposes only one way |
| `20260817-162601` | `blocked` | **the only machine-written evidence in the corpus**: its `results.json` carries `"regime": "blocked"` alongside the verbatim `no_run_prompt` and a `run_py_sha256` — the runner gained the stamp that `bench/PREREGISTRATION.md` promised, just before round three, and it never crossed into the acceptance record. Corroborated by `bench/PREREGISTRATION-3.md` §Design, written before the run |

Every adjudication agrees with what the filenames currently imply. That is the expected
result and it is what makes this diff reviewable: it relocates a fact and moves no number,
which AC-4 proves by re-deriving D-002's table from the recorded field.

**The evidence is not equally strong across the ten, and the derivation entry says so
per record rather than presenting one table of equals.** Three tiers:

- *Machine-written*: `20260817-162601` alone. Its `results.json` carries the regime the
  runner stamped, next to the prompt text and a hash of the runner itself.
- *A document naming the run*: the seven settled by the handoff per-run table, plus
  `20260816-092732` independently by PREREGISTRATION-2 §Experiment C.
- *Inference*: `20260815-225842`, settled by a preregistration written to match it rather
  than to describe it; and `20260816-222615`, settled by arithmetic on D-002's table.
  **The second is weaker than it looks, and round 1 of this review is why that is written
  down**: D-002's per-run regime column was counted off the published corpus, which means
  plausibly through `load_cells`'s own filename-derived `_regime`. Pinning `222615` by that
  arithmetic anchors it to consistency with a published claim, not to a source independent
  of the heuristic under suspicion. It remains the best available evidence for that run and
  it is labelled as what it is.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: every step touches only
  `packages/data/src/{schema,load,index}.ts`, `packages/data/src/load.test.ts`,
  `bench/data/runs/*.acceptance.json` (one added key each, no cell touched),
  `bench/harness/fisher.py`, `scripts/check-data-universe.sh`, `tests/meta/cases/`,
  `tests/e2e/PDX-017-*.sh`, `bench/DERIVATIONS.md`, `docs/WORKFLOW.md`, `CLAUDE.md`, and
  `DESIGN.md`.
- **Ticket Scope.NotAllowed respected**:
  - **Nothing is re-run or re-graded, and no cell changes.** Each record gains one
    top-level key. AC-3's per-regime comparison and AC-6's published anchors are what
    prove it, executed rather than asserted.
  - **No regime is adjudicated from a filename.** The table above cites a document per
    record; the two weaker adjudications are labelled as weaker.
  - **No published figure is corrected here.** The adjudication agrees with the current
    derivation, so none is expected to move. If one does, the ticket stops and issues a
    CLAIM-01 correction with its own derivation entry rather than absorbing it.
  - **Nothing in `packages/site/` or `verdict.ts`.** PDX-004 consumes this field after it
    lands; extending the verdict function here would put a UI decision inside a data
    ticket.
  - No GitHub-external action beyond the standing delegation (CR-01), and nothing outside
    the repository is contacted.

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | The type, the parse, the filter | `packages/data/src/schema.ts`, `load.ts`, `index.ts` | `Regime = 'blocked' \| 'as-shipped'`; `regime: Regime` **required** on `AcceptanceRecord` — not optional, because an optional field with a default is the current misclassification with somewhere to hide. `MissingRegimeError` on absent, `UnknownRegimeError` on a value outside the union (the two are separate so a golden case can prove which fired). **Check order is fixed here, not left to the implementer**: fingerprint, then the environment audit, then regime — the order the record's own refusals already run in, and the order `tests/e2e/PDX-002-records-are-traceable.sh` AC-3 depends on, since it plants a record missing both fingerprint and regime and requires `MissingFingerprintError`. Round 1 caught that this was a coin flip. `loadAcceptanceRecords({ dir, regime })` filters when asked and returns everything when not. Exported through `index.ts`. The mixed-environment and withdrawal behaviour is untouched |
| 2 | Unit coverage on synthetic corpora | `packages/data/src/load.test.ts` | Cases in §7. Synthetic throughout, so nothing depends on which runs exist; plus one committed-corpus consistency test asserting the two regimes partition the corpus exactly |
| 3 | The adjudication, written onto the records | `bench/data/runs/*.acceptance.json` (10 files) | One key per record, from §1's table, by a scripted single-key insert that touches no other byte. The insert is done per file with the value taken from a table in the script, so a reader can diff the script against §1 rather than trusting ten edits |
| 4 | fisher.py reads the record | `bench/harness/fisher.py` | Delete the `"as-shipped" in name` derivation; read `record["regime"]`; `ValueError` on absent or unknown, matching the loader's refusals. `_regime` keeps its name and meaning so every existing caller — `derive_d001.py`, the analysis scripts — is unaffected. The docstring's DATA-01 confession is replaced by a statement that the debt is paid, with DEC-015 named |
| 5 | DATA-02 gains its regime clauses | `scripts/check-data-universe.sh` | Three new lettered rules (§below). The header's disclosure that DATA-02 covers withdrawal only is removed, because after this it does not — and leaving a stale disclosure would be its own defect |
| 6 | Documentation | `docs/WORKFLOW.md`, `CLAUDE.md` | DATA-02's rows in both documents gain the regime clause; the golden-case range is updated. **Only `docs/WORKFLOW.md` carries the "round one enforces this for withdrawal only" sentence** — CLAUDE.md's row never did, so an implementer should not go hunting for it there (round-1 review note). The same stale disclosure in `scripts/check-data-universe.sh`'s header is removed by step 5 |
| 7 | Golden cases — the record-side rules | `tests/meta/cases/` (3 files, numbers derived at implementation) | DATA-02e (no regime), DATA-02f (unknown regime value), and a clean-pass guarding the two legal values. Construction table below |
| 8 | Golden case — the harness rule | `tests/meta/cases/` (1 file) | DATA-02g: a planted `fisher.py` deriving regime from the filename is caught behaviourally against a corpus whose names contradict its records |
| 9 | The derivation entry | `bench/DERIVATIONS.md` | Next free number, derived at write time. Contents in §below — including the per-record evidence table and the explicit note on which two adjudications rest on inference |
| 10 | The decision, and the debt closed | `DESIGN.md` | DEC-015's scope note updated to say its second half landed; the PDX-017 harness-debt row struck with a pointer to this ticket; the decision log gains **DEC-019** for the adjudication standard — *a run-level condition is settled from a document, and the document is named per record*. Not DEC-016: PDX-004's approved plan already holds 016 through 018 on this branch and its stacked implementation cites DEC-016 in shipped comments, so taking it here would make two different decisions share an id. This ticket lands first, which leaves 016-018 briefly unallocated in the log — an ordering oddity rather than a gap, and PDX-004 fills them immediately after |

| 11 | Every synthetic record constructor | `packages/data/src/load.test.ts`, `scripts/check-data-universe.sh`, `tests/e2e/PDX-002-records-are-traceable.sh`, `tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh`, `tests/meta/cases/28..33-data-*.sh` | **Added at review round 1, which found GREEN unreachable without it.** A required field breaks every planted corpus in the repository, and the enumeration is derived rather than remembered: `grep -rln npm_fingerprint` over tracked non-corpus files is the complete list. Each planter gains a regime, defaulting to `blocked` **inside the fixture** — a test fixture may have a default; the parser may not. PDX-016's scenario and PDX-002's are updated in place with a comment saying why, since neither is about regime |
| 12 | The writer stamps what the reader requires | `bench/harness/acceptance.py` | **Added at review round 1.** `acceptance.py` writes `{run, env, cells}` and no regime, so a required field would make the next graded run emit a record this project's own loader refuses. It gains a `--regime` argument validated against the two values, preferring the run's `results.json` when that carries one — `20260817-162601`'s already does, machine-written alongside the `no_run_prompt` text and a `run_py_sha256`. Refuses when neither is available, rather than defaulting: the writer is where a wrong regime would enter the corpus with nothing to contradict it |

**The gate — three new lettered rules under DATA-02.**

- **DATA-02e** — a record with no `regime`. Absent must never read as `blocked`: that
  default is exactly today's behaviour with a field in front of it.
- **DATA-02f** — a `regime` outside `{blocked, as-shipped}`, including near-misses like
  `Blocked`, `as shipped`, or a trailing space. A typo that silently moves a run between
  conditions is the failure this field exists to prevent, and a case-insensitive or
  trimming parser would reintroduce it under a friendlier name.
- **DATA-02g** — a filename comparison deciding a record's regime anywhere under
  `bench/harness/`, proven behaviourally: the gate plants a two-record corpus whose names
  say the opposite of what the records say (a run named `...-as-shipped` recorded
  `blocked`, and a plainly-named run recorded `as-shipped`) and asserts `load_cells`
  reports the records' values. The existing DATA-02d probe already plants a corpus; this
  extends it rather than adding a second sandbox, so one instrument covers both fields.

Precedence, stated in the script as DATA-02c's already is: a record tripping DATA-02e or
DATA-02f is skipped by every other regime check, so each planted violation trips exactly
one rule and the golden set's `EXPECT_PATTERN` proves what it appears to prove.

**Golden-case construction — each trips exactly one rule.**

| Case | Trips | Why the others stay green |
|---|---|---|
| DATA-02e | one record with no `regime`, one clean | 02f: no bad value exists; 02g: planted loader reads the field; 02a/b/c: withdrawal consistent |
| DATA-02f | one record with `regime: "Blocked"`, one clean | 02e: the key is present; 02g: planted loader reads the field |
| DATA-02g | corpus fully consistent, planted `fisher.py` derives regime from the name | 02e/f: every record carries a legal value |
| clean pass (`EXPECT_PASS=1`) | nothing — `EXPECT_PATTERN="DATA-02 PASS"` | one record per legal value, consistent withdrawal, field-reading loader |

**The derivation entry.** The next free number records: the before (regime derived from a
substring, in one function, invisible to the TypeScript half); the after (a required field
on every record, both loaders selecting on it, three gate rules); §1's evidence table
verbatim, with the two inference-based adjudications marked; and the claim that matters —
that D-002's corrected condition table re-derives identically from the field, with the
command that produces it. If any figure moves, the entry records the movement and its
cause instead, and the ticket stops for a CLAIM-01 correction.

## 4. Risks

- **The adjudication is wrong for a record, and the error is now recorded rather than
  inferred** → this is the risk that matters, because a field looks more authoritative
  than a filename. Mitigated by citing a document per record, by marking the two weaker
  adjudications as weaker, and by AC-4's re-derivation: an adjudication that disagreed
  with the corpus would move D-002's table and the scenario would fail.
- **A required field breaks a consumer that constructs records** → `pnpm typecheck` covers
  both packages; the risk is real and the compiler is the mitigation, which is the reason
  the field is on the type rather than only in the parser.
- **Making the field required breaks every planted corpus in the repository** → round 1 of
  this review found the enumeration was understated and that GREEN was unreachable as
  planned. The list is now derived rather than remembered — `grep -rln npm_fingerprint`
  over tracked non-corpus files — and step 11 covers all of it: `load.test.ts`, the DATA-02
  gate's own probe corpus, the six existing DATA-02 golden cases' shared `plant_record`,
  **`tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh`** (which plants regime-less records
  and requires them to load, so it fails unconditionally otherwise), and
  **`tests/e2e/PDX-002-records-are-traceable.sh`** (whose AC-3 plants a record missing both
  fingerprint and regime and requires `MissingFingerprintError`, which is why step 1 fixes
  the check order rather than leaving it to an implementer's coin flip). Two of those files
  needed a ticket scope amendment, which is recorded in the ticket.
- **The grader stops being able to produce a loadable record** → `acceptance.py` writes
  `{run, env, cells}`. A required field the writer does not stamp means the next graded run
  emits a record this project's own loader refuses — a self-inflicted outage with a clean
  error message. Step 12 makes the writer stamp it, refusing rather than defaulting,
  because the writer is the one place a wrong regime could enter the corpus with nothing to
  contradict it.
- **`derive_d001.py` reads a frozen corpus through `git show 63735e6:`**, whose records
  predate the field → it must keep working. It calls `load_cells` only for the live half;
  the frozen half is read directly. Verified before implementation and asserted by AC-6
  running the script.
- **Live-corpus fragility**: AC-4 and AC-6 anchor on published figures, so a future
  legitimate corpus change fails them. That is the intended trade — the alternative is an
  assertion that cannot notice a moved figure — and each failure message names the
  derivation to correct in place under CLAIM-01 before the assertion is touched.

## 5. Out of Scope

- Rendering anything, and any change to `verdictFor`. PDX-004 resumes after this and
  consumes the field; how the card presents two regimes is that ticket's decision.
- Re-running, re-grading, or excluding any cell.
- The `results.json` claims record (PDX-002 §5's deferral) — a different field, a
  different ticket.
- Any further filename-derived fact. If one is found while doing this, it is recorded in
  DESIGN.md's harness-debt table, not folded in — the same rule PDX-016 followed to get
  here.

## 6. Rules / Decisions Applied

- **DATA-02** — the rule this extends. Its round-one scope note said it enforced
  withdrawal only and pointed here; that sentence is removed rather than left stale.
- **DATA-01** — no figure is hand-typed; the derivation entry's numbers are produced by
  the commands printed beside them.
- **CLAIM-01** — if the adjudication moves a published figure, it is corrected in place
  with its cause, never absorbed.
- **GATE-01** — three new rules, four new golden cases, both sides of each.
- **ASSERT-01** — every probe prints a sentinel, empty captures fail, and every count
  carries a floor; the per-regime comparison additionally floors both regimes at ≥ 1 cell
  so two empty pools cannot agree.
- **PLAN-01** — golden-case numbers, the derivation number, and the case list are derived
  at implementation. The figures quoted in §1 (25%, 73%, 5/20, 8/11, 34/35, 9/9, 6/6,
  49/50) are claims the scenario asserts, not prose only a reviewer can check.
- **LANG-01, CR-01, NOLLM-01, DEV-01** — as everywhere.
- DEC-005 (the effect confined to a regime the records do not carry as a field — this is
  the ticket that makes that sentence obsolete), DEC-015 (a fact that governs the analysis
  is a record field, never a filename).
- **Produced by this ticket**: **DEC-019** — a run-level condition is settled from a
  document, and the document is named per record. PDX-016 established that such a fact
  belongs on the record; it did not say how the value is decided. Ten records adjudicated
  from prose is where that question becomes real. The number skips ahead because PDX-004's
  approved plan holds 016-018 on this branch (round 1 of this review caught the collision);
  see step 10.

## 7. Test Plan (mandatory — TDD)

- **E2E scenario**: `tests/e2e/PDX-017-the-corpus-knows-its-conditions.sh` (the ticket's §5
  name, verbatim).
- **Global RED** (stage 5): `verify.sh` PASSes and the scenario FAILs — today no record
  carries `regime`, `@plugdex/data` has no such type (`grep -rn regime packages/data/src/`
  is empty), `fisher.py` derives it from the name, and DATA-02 has no e/f/g rules.
- **Global GREEN** (stage 7): `verify.sh` PASSes with the extended gate executed, the
  scenario PASSes every assertion, and the full regression (`e2e.sh`, no argument) PASSes
  — PDX-016's scenario in particular, since it exercises the same loader and the same gate.

**AC-3, the load-bearing assertion, specified exactly.** Both implementations, per regime,
over the live corpus:

- *TypeScript*: a probe file in the sandbox importing the built `@plugdex/data`, calling
  `loadAcceptanceRecords({ dir, regime })` for each of the two values and once unfiltered,
  emitting `SENTINEL {"cells": N, "valid": N, "arms": {arm: [hits, n]}}` per view, with
  `arms` following `rate_table` semantics on outcome `build` — a cell skipped when `build`
  is `undefined` **or** `null`, because Python's `is None` covers both and a future record
  writing an explicit null would otherwise split the two probes inside the comparison meant
  to prove them equal.
- *Python*: a probe file inserting `bench/harness` on `sys.path`, calling `load_cells()`
  and filtering on `_regime`, computing the same three numbers with `rate_table`.
- *Comparison*: each capture must be non-empty and sentinel-prefixed; each JSON is
  canonicalized with `json.dumps(..., sort_keys=True)` (the two languages order keys
  differently and a raw compare would fail on a healthy tree); then blocked must equal
  blocked and as-shipped must equal as-shipped, byte for byte. The two regimes are never
  crossed — that comparison would fail on a healthy tree and could pass on a sick one.
- *Floors* (ASSERT-01): each regime's `cells ≥ 1` and `valid ≥ 1`; `|arms| ≥ 2` in the
  larger regime; the two regimes' cell counts must sum exactly to the unfiltered count, so
  a record assigned to neither or to both is caught; and the regime labels must be read off
  the records, never off filenames, inside the probe itself.

**Per-AC RED / GREEN:**

| AC | RED today because | GREEN asserts |
|---|---|---|
| AC-1 | no record carries `regime` — a python scan finds zero, and the floor turns that empty result into the failure it is | every acceptance record carries a `regime` of one of the two legal values; the counts per value are ≥ 1 each; and `bench/DERIVATIONS.md`'s new entry names every run with its evidence source |
| AC-2 | `loadAcceptanceRecords` has no `regime` option and the type has no such field, so the node probe fails on the old dist | a node probe over synthetic corpora planted in `mktemp -d`: filtering returns only the asked-for regime, omitting the option returns everything, a record with no regime throws `MissingRegimeError`, an unknown value throws `UnknownRegimeError`, and a filter matching nothing returns an empty corpus rather than falling back — asserted on error names, sentinel-wrapped |
| AC-3 | the per-regime comparison cannot run: the TypeScript side has no regime to filter on | the full comparison above passes with all floors |
| AC-4 | `grep -n 'as-shipped" in name' bench/harness/fisher.py` matches, and the decoy probe shows the loader is name-sensitive | no filename comparison decides a regime under `bench/harness/`, proven by the decoy corpus; **and** D-002's four published rows (34/35, 9/9, 6/6, 49/50) re-derive from the recorded field, executed by the scenario. A moved row names the derivation to correct under CLAIM-01 rather than the assertion to edit |
| AC-5 | `check-data-universe.sh` has no e/f/g rules; a planted no-regime record passes it today | the gate BLOCKs each of the three shapes, `check-gates.sh` replays all four new cases green (numbers globbed at run time), and each violation case trips exactly one lettered rule |
| AC-6 | the anchors would run but prove nothing about a field that does not exist — so this AC is asserted together with AC-4's re-derivation, and separately runs `derive_d001.py`, whose excluded-pool block must still show baseline 12/34 and ponytail `p = 0.0352` | both anchors reproduce; `python3 bench/harness/fisher.py` still prints its textbook self-validation line |
| AC-2 (writer) | `acceptance.py` accepts no regime and stamps none, so `--regime` is an unknown argument | the grader refuses to write a record without a regime — invoked with no `--regime` and no `results.json` regime, it exits non-zero and names the reason; invoked with an unknown value it refuses; and its output record carries the value. Asserted against a scratch run directory, never against `bench/data/runs/` |
| AC-7 | verify output contains no regime clause and `check-gates.sh` knows no such cases | captured verify output (captured then searched — never piped into `grep -q` under pipefail) contains the DATA-02 pass line, and both documents carry the regime clause with the stale withdrawal-only sentence gone |

- **Unit tests** (step 2, `packages/data/src/load.test.ts`), synthetic throughout:
  - a corpus of both regimes, filtered each way, returns only that regime's records;
  - no filter returns every record;
  - a record with no `regime` → `MissingRegimeError`;
  - `regime: "Blocked"`, `"as shipped"`, `"blocked "`, and `""` → `UnknownRegimeError`
    (four values, one test, because a parser that trims or lowercases would pass three of
    them and fail this);
  - a filter matching no record → empty `records`/`cells`, no throw, no fallback;
  - regime and withdrawal are independent: a withdrawn `as-shipped` record is excluded from
    the default view and still listed in `withdrawnRecords` with its regime intact;
  - committed-corpus consistency: the live corpus loads, the two regimes' cell counts sum
    to the unfiltered count, and both are ≥ 1;
  - check order: a record missing both the fingerprint and the regime throws
    `MissingFingerprintError`, not `MissingRegimeError` — the order PDX-002's scenario
    depends on, pinned here so it cannot drift.

## 8. Feature Tags

- `data` — the record schema, the loader, the analysis harness
- `harness` — a gate rule set and four golden cases affect every later ticket

## 8.5 References Consulted (REF-01)

| Reference | Consulted | Note |
|---|---|---|
| `bench/PREREGISTRATION-2.md` §Experiment A / C | Y (2026-08-18) | Defines both regimes and the `PONYTAIL_REGIME` switch; §Experiment C states caveman ran blocked. Its coverage table is explicitly **not** used as evidence — D-002 withdrew it |
| `bench/PREREGISTRATION-3.md` §Design | Y (2026-08-18) | States round three's regime before the run, which is what makes it evidence rather than reconstruction |
| `bench/README.md` D-002 corrected table | Y (2026-08-18) | The classification that reproduces; the source that pins the sonnet probe by arithmetic and the anchor AC-4 re-derives |

### 9.0 What round 1 of this review found

Two blockers, both about consequences the plan had not followed through, and three notes
that made the evidence honest rather than merely correct.

- **A decision-log id collision I created.** PDX-004's approved plan holds DEC-016 through
  018 on this same branch, and its stacked implementation already cites DEC-016 in shipped
  comments. This ticket's decision moves to DEC-019.
- **The required field's blast radius was understated, and GREEN was unreachable.**
  PDX-016's own scenario plants regime-less records and requires them to load; PDX-002's
  AC-3 requires a specific error from a record missing two fields at once. Neither file was
  in a step or in the ticket's scope. Both are now, along with the four other planters the
  grep finds, and the parser's check order is fixed in step 1 rather than left to chance.
  The grader that *writes* records was missing entirely — a required field it does not
  stamp would make the next run emit a record this project's own loader refuses.
- **The adjudication table survived a full independent re-derivation** — every cited
  sentence, the sonnet arithmetic, the `deps: cell-local` corroboration, and all four D-002
  rows. No adjudication is wrong. What changed is honesty about strength: `222615`'s pin
  rests on a table whose own regime column was plausibly computed by the heuristic under
  suspicion, and `162601` was under-cited — its `results.json` carries a machine-written
  regime, the strongest evidence in the corpus and the only one of its kind.

## 9. Agent Review

### Reviewer
- Model: Fable 5
- Reviewed at: 2026-08-18 00:53

### Verdict
- [ ] APPROVED
- [x] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Goal and scope: the plan's goal matches the ticket, and Scope Check shows Allowed/NotAllowed respected | PASS | Every file steps 1-12 touch is in the ticket's Scope.Allowed (including the round-1 amendments: `bench/harness/acceptance.py`, `tests/e2e/PDX-002-*`, `tests/e2e/PDX-016-*`), and each of AC-1..AC-7 has a step plus a RED/GREEN row in §7; §2's "touches only" list is stale against steps 11-12 — carried as comment 1, not a scope breach |
| P2 | Steps: concrete, ordered, each naming its files, implementable without further design decisions | PASS | The coin-flip decisions are pre-made in the step text: parse order fixed in step 1 (matches `load.ts` — fingerprint at src/load.ts:103 before audit at :109), two distinct error names, DEC-019 chosen with its reason, and a golden-case construction table showing each case trips exactly one rule |
| P3 | Design soundness: the mechanisms proposed are correct, and no proposed decision contradicts DESIGN.md or the decision log | PASS | Re-verified first-hand: DESIGN.md's log ends at DEC-015 (lines 155-169) while DEC-016..018 are held by PDX-004's approved plan and shipped code (`packages/data/src/verdict.ts:9,34`, `verdict.test.ts`, `global.css`), so DEC-019 is collision-free and no dangling DEC-016 reference survives in this plan or the ticket; step 12 matches `acceptance.py` reality (it writes `{run, env, cells}`, has no `--regime`, and `20260817-162601`'s `results.json` carries top-level `"regime": "blocked"` beside `no_run_prompt` and `run_py_sha256`) |
| P4 | Test plan: TDD-real (a RED that must fail before implementation), PLAN-01 and ASSERT-01 respected | PASS | RED verified by execution: `grep -rn regime packages/data/src/` exits 1, zero of the 10 acceptance records carry a `regime` key, `fisher.py:106` still derives it from the name, and `check-data-universe.sh` defines only DATA-02a-d; floors, sentinels, and the regimes-sum-to-unfiltered check satisfy ASSERT-01; one PLAN-01 wording overreach carried as comment 2 |
| P5 | Risks: the real ones are named, with what would be done about each | PASS | The blast-radius enumeration was re-derived independently — `git ls-files \| grep -v bench/data/runs \| xargs grep -ln npm_fingerprint` yields exactly the constructors steps 1/11/12 cover, and the two other `acceptance.json`-referencing candidates construct nothing (`PDX-001` e2e greps a string; `derive_d001.py` reads the frozen corpus directly at :55-60 and calls `load_cells` only at :173, with no filename-regime logic of its own) |
| P6 | Rules/decisions applied: the rules this ticket touches are named and correctly interpreted | PASS | §6 names DATA-02/DATA-01/CLAIM-01/GATE-01/ASSERT-01/PLAN-01/DEC-005/DEC-015 and produces DEC-019; the step-6 claim that only `docs/WORKFLOW.md` carries the "withdrawal only" sentence checks out (WORKFLOW.md §3 DATA-02 row has it, CLAUDE.md's row does not, and `check-data-universe.sh` header lines 16-18 carry the copy step 5 removes) |
| P7 | REF-01: required references for this ticket are shown consulted with a note | PASS | `./scripts/check-references.sh .docs/analysis/PDX-017_plan.md` → "PDX-017 has no mapped references — nothing required / REF-01 PASS" (exit 0); §8.5 nonetheless records three references Y + note, and both preregistration citations plus the D-002 table were re-read and match (`PREREGISTRATION.md:91`, `PREREGISTRATION-2.md:67`, `PREREGISTRATION-3.md:29`, `bench/README.md:85-88`) |

### Comments
1. **§2's "every step touches only ..." list is stale against the plan's own steps 11-12.**
   It omits `bench/harness/acceptance.py`, `tests/e2e/PDX-002-records-are-traceable.sh`,
   and `tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh` — the three round-1 additions
   the ticket's Scope.Allowed now names. Nothing out-of-scope is touched, so this is a
   sentence that lags its own document, not a scope defect. Rides to the report (REV-02).
2. **§6's PLAN-01 bullet overclaims by four figures.** It says the scenario asserts 25%,
   73%, 5/20, and 8/11, but no §7 row pins them — AC-3's comparison uses equality and
   floors, and AC-4/AC-6 anchor only the D-002 rows and `derive_d001.py`'s pair. The
   figures are correct today (re-derived from the live corpus: blocked baseline build
   5/20, as-shipped 8/11, pooled 13/31), so either add them as AC-3 anchors when writing
   the scenario or narrow §6's sentence in the report. Rides to the report (REV-02).
3. **The step-12 test row is labelled "AC-2 (writer)" but ticket AC-2 is about the
   loader.** The writer behaviour is ticket-Allowed and well-specified; the label just
   borrows an AC number that does not cover it. Cosmetic.
4. Round-1 closure checks were all re-verified first-hand and hold: the DEC-019 skip, the
   step-11 enumeration, the step-12 writer gap and `162601`'s machine-written regime, the
   step-1 parse order against `PDX-002-records-are-traceable.sh:131-149` (its synthetic
   record `{"run":"synthetic","env":{},"cells":[]}` misses both fields and accepts only
   `MissingFingerprintError`), and §1's evidence tiers — the handoff per-run table names
   regimes for exactly the seven runs the plan says (its `225842`, `222615`, and `162601`
   rows carry no regime), and the corpus holds exactly 3 valid sonnet superpowers cells in
   each of `222615` and `162601`, so the 6/6 decomposition is as stated.

### Blockers (only if NEEDS_REVISION)
- None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (round 2, Fable 5, 2026-08-18 00:53 — 0 blockers; round-1 closures verified first-hand; 3 non-blocking comments ride to the report per REV-02)
- Human: _(pending)_
