# PDX-027 — harness: the gate stack pays for itself

- Status: TODO
- Created: 2026-08-19

## 1. Goal

The user asked whether unnecessary gates are the bottleneck. The gate log answers it, and
the answer is narrower than the question: **one gate is the bottleneck and the rest are
free.**

Measured over 4,296 recorded gate runs in `.docs/scratch/gate-runs.jsonl`:

| gate | runs | hours | avg | catches | wall clock per catch |
|---|---|---|---|---|---|
| `check-gates` | 628 | **2.52** | 14.4s | 6 | **25 min** |
| `check-fresh-clone` | 16 | 0.17 | 37.1s | 4 | 2 min |
| `check-data` | 242 | 0.06 | 0.8s | 14 | 16s |
| `check-templates` | 565 | 0.04 | 0.3s | 0 | — |
| `check-language` | 640 | 0.01 | 0.1s | 3 | 12s |
| `check-no-llm` | 455 | 0.01 | 0.1s | 0 | — |
| `check-structure` | 511 | 0.01 | 0.1s | 2 | 18s |
| `check-data-universe` | 419 | 0.01 | 0.1s | 1 | 36s |
| `check-test-case`, `check-references` | 114 | 0.00 | 0.0s | 0 | — |

`check-gates` is **89% of all leaf-gate wall clock** (2.52 of 2.82 hours). The other nine
gates together cost 18 minutes across 3,668 runs and caught 24 violations. So the cheap
gates are not the problem and this ticket does not touch them — a gate that costs a tenth of
a second is not worth a decision, and removing one to save 0.1s while it holds a rule in
place is the kind of tidying that trades a guarantee for nothing.

**Re-measured 2026-08-20, after PDX-005 merged**, because a table in a ticket is exactly the
kind of fact PLAN-01 says goes stale: 4,622 records now, `check-gates` at 2.93 hours over 671
runs and still 6 catches, so **89.9% of leaf-gate wall clock** and **29.3 minutes per catch**.
Timed live rather than averaged: `check-gates` **32.03s** (71/71), the seven cheap gates
**1.78s combined**, full `verify.sh` **51.10s** — so `check-gates` is **62.7% of a verify run
today**, up from the 14.4s historical average because the case set grew to 71. At ~98 verify
runs per ticket (492 runs over 5 tickets), scoping saves roughly 49 minutes per ticket, which
is about one ticket-cycle of payback.

**The obvious cheaper alternative was tried and does not work.** Sharding the existing
per-case selector with `xargs -P8` gives **22.70s against 32.03s — 1.4×**, because the cost is
per-case sandbox setup rather than CPU. Parallelism is not the answer; scoping is. This is
recorded so the next person does not spend a cycle re-deriving it, and so AC-5's measurement
has a baseline to beat.

`check-gates` is expensive for a good reason: it replays 71 planted violations against
sandbox copies of the gates, and it grew from ~20 cases to 71 as the rules grew. It is also
the reason GATE-01 means anything. **This ticket does not shrink the golden set and does not
weaken GATE-01.** It changes *when the full set runs*, on exactly the argument `ci.yml`'s
`changed` job already makes: the set has to run against every change that could break it,
and a change that touches no gate and no case cannot break it.

## 2. Scope

### Allowed
- `scripts/check-gates.sh` — case selection by what changed, and the flag that disables it
- `scripts/verify.sh` — how it invokes `check-gates`
- `.git/hooks` installer `scripts/install-hooks.sh` and `.github/workflows/ci.yml` — the two
  places the **full** set must keep running unconditionally
- `tests/e2e/PDX-027-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision
- `docs/WORKFLOW.md` — the gate table row, if the invocation changes

### Not Allowed
- Deleting, skipping or merging any golden case. GATE-01's fix-the-gate-never-the-case rule
  is untouched; this is about scheduling, not coverage
- Any path where a full run is skipped at commit time or in CI. The scoped run is a local
  inner-loop convenience and must be impossible to mistake for the real one
- Touching the cheap gates. They are measured free and two of them (`check-language`,
  `check-data`) are among the top catchers
- Scoping `e2e` by changed files. At 74.7s per run for 21 catches (~8 min per catch) it is
  already paying for itself, and a scenario's blast radius is not derivable from a path list

## 3. Acceptance Criteria

- [ ] AC-1: `check-gates` accepts a changed-file set and runs the subset of cases whose
      gate under test could be affected — a case is selected when the diff touches that
      case's gate script, any library it sources, the case file itself, or the shared
      harness (`tests/meta/lib.sh`). **The mapping is derived from the case, not maintained
      by hand**: each case already names the gate it replays, and a case that cannot be
      attributed to a gate runs always rather than never.
- [ ] AC-2: **the default is the full set.** Scoping happens only when the caller passes the
      changed set explicitly. `./scripts/check-gates.sh` with no argument runs 71/71, and the
      pre-commit hook and CI both call it that way. An e2e asserts both call sites by reading
      the hook and the workflow, not by trusting this sentence.
- [ ] AC-3: **a scoped run says it was scoped, in its own output and in the gate log.** The
      pass line names the count and the total (`GATE SELF-TEST PASS (12/12 selected, 71 in
      set)`), and the `.docs/scratch/gate-runs.jsonl` record carries the selected count, so
      `gate-stats.sh` can never report a scoped run as full coverage. A green line that
      reads like a full pass when it was not is the failure mode this criterion exists for.
- [ ] AC-4: **the selector fails safe, proven by planting.** A case whose gate cannot be
      determined, a diff the selector cannot parse, and an empty changed set each run the
      full set. A golden case plants each of those three conditions and asserts 71 cases ran.
- [ ] AC-5: **the saving is measured, not assumed.** The scenario runs the same realistic
      diff scoped and unscoped and prints both wall clocks and both case counts. The ticket
      is worth landing only if the scoped inner loop is materially faster; the report states
      the measured figure whatever it turns out to be, including if it is small.
- [ ] AC-6: **the six historical catches are replayed against the selector.** For each of
      the 6 `check-gates` failures in the log, the diff that was in the tree at that moment
      must select the case that caught it. A selector that would have missed a real catch is
      rejected — this is the criterion that decides whether the ticket ships at all.
- [ ] AC-7: `gate-stats.sh` gains the cost-per-catch column this ticket's §1 table was
      derived from, so the next person asking "which gate is the bottleneck" runs a command
      instead of writing a script.

## 4. Edge Cases & Error Handling

- A change touches a gate's *behaviour* through a file the selector does not know about
  (a sourced helper added later) → the selector reads the gate's actual `source` lines
  rather than a hardcoded list, and a gate whose sources cannot be read runs its full case
  set. Covered by AC-4's planted unattributable case.
- The developer runs `verify` on a dirty tree with no diff against any ref → there is no
  changed set, so the full run happens. Scoping needs a baseline and silently inventing one
  is how a skipped case becomes invisible.
- A case tests interaction between two gates → it is attributed to both and runs when either
  changes. Attribution is many-to-many by construction, not one-to-one.
- The full set is green but a scoped run went green earlier on the same tree → not a
  conflict; the commit-time full run is the authority and AC-3's labelling is what keeps the
  two readable apart in the log.

## 5. E2E Mapping

- `tests/e2e/PDX-027-the-selector-is-honest.sh` — AC-1, AC-3, AC-4, AC-6: attribution
  derived from the cases, scoped output and log record labelled, three fail-safe conditions
  planted, and the six historical catches replayed against the selector
- `tests/e2e/PDX-027-the-full-set-is-unconditional.sh` — AC-2, AC-5: the hook and the
  workflow are read and asserted to invoke the unscoped form, and the scoped/unscoped wall
  clocks are measured and printed

## 6. References

- `.docs/scratch/gate-runs.jsonl` and `./scripts/gate-stats.sh` — the measurement §1 is
  built from; re-derive rather than trusting the table, it will have moved
- GATE-01 in `CLAUDE.md` — the rule this ticket must not weaken
- `.github/workflows/ci.yml`, the `changed` job — the scoping pattern this reuses
- PDX-026 — the other half of the same directive. **This ticket previously claimed PDX-026
  "lands first"; that ordering was wrong and is withdrawn (2026-08-20).** The two touch
  disjoint trees — PDX-026 is `bench/harness/`, `bench/data/runs/`, `packages/data/`; this is
  `scripts/`, hooks, CI, `tests/meta/cases/`. The reason given for the ordering ("a validity
  change re-grades every pool and this ticket only changes scheduling") is an argument that
  they are *independent*, not that one precedes the other. Either order works, and they can
  run concurrently.
