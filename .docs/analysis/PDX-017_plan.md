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
`blocked` baseline is 5/20, `as-shipped` is 8/11. The preregistrations kept the two apart
deliberately; a card that merges them publishes a condition that never ran.

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
| `20260817-162601` | `blocked` | `bench/PREREGISTRATION-3.md` §Design — "**Regime**: blocked (Bash disallowed, NO_RUN prompt appended)" |

Every adjudication agrees with what the filenames currently imply. That is the expected
result and it is what makes this diff reviewable: it relocates a fact and moves no number,
which AC-4 proves by re-deriving D-002's table from the recorded field.

Two of the ten are settled by inference rather than by a sentence naming them — `225842`
by a preregistration written to match it, and `222615` by arithmetic on a published table.
Both are recorded as such in the derivation entry, because an adjudication whose strength
varies by record and does not say so is a table that reads stronger than it is.

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
| 1 | The type, the parse, the filter | `packages/data/src/schema.ts`, `load.ts`, `index.ts` | `Regime = 'blocked' \| 'as-shipped'`; `regime: Regime` **required** on `AcceptanceRecord` — not optional, because an optional field with a default is the current misclassification with somewhere to hide. `MissingRegimeError` on absent, `UnknownRegimeError` on a value outside the union (the two are separate so a golden case can prove which fired). `loadAcceptanceRecords({ dir, regime })` filters when asked and returns everything when not. Exported through `index.ts`. The mixed-environment and withdrawal behaviour is untouched |
| 2 | Unit coverage on synthetic corpora | `packages/data/src/load.test.ts` | Cases in §7. Synthetic throughout, so nothing depends on which runs exist; plus one committed-corpus consistency test asserting the two regimes partition the corpus exactly |
| 3 | The adjudication, written onto the records | `bench/data/runs/*.acceptance.json` (10 files) | One key per record, from §1's table, by a scripted single-key insert that touches no other byte. The insert is done per file with the value taken from a table in the script, so a reader can diff the script against §1 rather than trusting ten edits |
| 4 | fisher.py reads the record | `bench/harness/fisher.py` | Delete the `"as-shipped" in name` derivation; read `record["regime"]`; `ValueError` on absent or unknown, matching the loader's refusals. `_regime` keeps its name and meaning so every existing caller — `derive_d001.py`, the analysis scripts — is unaffected. The docstring's DATA-01 confession is replaced by a statement that the debt is paid, with DEC-015 named |
| 5 | DATA-02 gains its regime clauses | `scripts/check-data-universe.sh` | Three new lettered rules (§below). The header's disclosure that DATA-02 covers withdrawal only is removed, because after this it does not — and leaving a stale disclosure would be its own defect |
| 6 | Documentation | `docs/WORKFLOW.md`, `CLAUDE.md` | DATA-02's rows in both documents gain the regime clause and drop the "round one enforces withdrawal only" sentence; the golden-case range is updated |
| 7 | Golden cases — the record-side rules | `tests/meta/cases/` (3 files, numbers derived at implementation) | DATA-02e (no regime), DATA-02f (unknown regime value), and a clean-pass guarding the two legal values. Construction table below |
| 8 | Golden case — the harness rule | `tests/meta/cases/` (1 file) | DATA-02g: a planted `fisher.py` deriving regime from the filename is caught behaviourally against a corpus whose names contradict its records |
| 9 | The derivation entry | `bench/DERIVATIONS.md` | Next free number, derived at write time. Contents in §below — including the per-record evidence table and the explicit note on which two adjudications rest on inference |
| 10 | The decision, and the debt closed | `DESIGN.md` | DEC-015's scope note updated to say its second half landed; the PDX-017 harness-debt row struck with a pointer to this ticket; the decision log gains **DEC-016** for the adjudication standard — *a run-level condition is settled from a document, and the document is named per record* |

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
- **Making the field required breaks the golden-set fixtures and any test corpus** →
  intended, and cheap to fix; a fixture that loads without a regime is a fixture that
  proves nothing about a corpus that needs one. Every planted corpus in the meta cases and
  the unit tests is updated in the same change.
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
- **Produced by this ticket**: **DEC-016** — a run-level condition is settled from a
  document, and the document is named per record. PDX-016 established that such a fact
  belongs on the record; it did not say how the value is decided. Ten records adjudicated
  from prose is where that question becomes real.

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
    to the unfiltered count, and both are ≥ 1.

## 8. Feature Tags

- `data` — the record schema, the loader, the analysis harness
- `harness` — a gate rule set and four golden cases affect every later ticket

## 8.5 References Consulted (REF-01)

| Reference | Consulted | Note |
|---|---|---|
| `bench/PREREGISTRATION-2.md` §Experiment A / C | Y (2026-08-18) | Defines both regimes and the `PONYTAIL_REGIME` switch; §Experiment C states caveman ran blocked. Its coverage table is explicitly **not** used as evidence — D-002 withdrew it |
| `bench/PREREGISTRATION-3.md` §Design | Y (2026-08-18) | States round three's regime before the run, which is what makes it evidence rather than reconstruction |
| `bench/README.md` D-002 corrected table | Y (2026-08-18) | The classification that reproduces; the source that pins the sonnet probe by arithmetic and the anchor AC-4 re-derives |

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

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Goal and scope: the plan's goal matches the ticket, and Scope Check shows Allowed/NotAllowed respected | | |
| P2 | Steps: concrete, ordered, each naming its files, implementable without further design decisions | | |
| P3 | Design soundness: the mechanisms proposed are correct, and no proposed decision contradicts DESIGN.md or the decision log | | |
| P4 | Test plan: TDD-real (a RED that must fail before implementation), PLAN-01 and ASSERT-01 respected | | |
| P5 | Risks: the real ones are named, with what would be done about each | | |
| P6 | Rules/decisions applied: the rules this ticket touches are named and correctly interpreted | | |
| P7 | REF-01: required references for this ticket are shown consulted with a note | | |

### Comments
1.

### Blockers (only if NEEDS_REVISION)
-

## 10. Final Plan Status

- Agent: _(pending)_
- Human: _(pending)_
