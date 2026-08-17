# PDX-003 Report — Pack entries, marketplace generation, and SRC-01

- Ticket: `.docs/tickets/PDX-003_registry-pack-entries-and-marketplace-generation.md`
- Plan: `.docs/analysis/PDX-003_plan.md`
- Author: Opus 5 (claude-opus-5)
- Date: 2026-08-17

## 1. Summary

plugdex now has a machine face. `packages/registry` holds one `PackEntry` per measured
arm and generates `.claude-plugin/marketplace.json` deterministically from those entries,
and `scripts/check-src.sh` makes SRC-01 a BLOCK rather than an intention, running as
`verify.sh` step 10/10 with six planted violations in the golden set.

The premise is proven rather than assumed: AC-5 runs a real `claude plugin marketplace
add` followed by a real `claude plugin install`, and asserts on the resulting installed
listing. `caveman@plugdex` installs from `JuliusBrussee/caveman` — the author's own
repository — and appears in `claude plugin list`.

Attribution is derived from each pack's own recorded manifest and tagged `upstream` or
`curated` in the type, so our claim about a person and their declaration about themselves
are different values rather than a convention. The case that forced it is real: the pack
commonly called "Karpathy's skills" is listed as `andrej-karpathy-skills` by
**forrestchang**, which is what its own manifest declares.

## 2. Files Changed

| File | Change |
|---|---|
| `packages/registry/package.json`, `tsconfig.json` | New workspace package, depending on `@plugdex/data` for the AC-6 join |
| `packages/registry/src/schema.ts` | `PackEntry` with every SRC-01 field required; `Attributed` as a tagged union; `InstallSource` as a union of one (DEC-012) |
| `packages/registry/src/upstream.ts` | Reads a pack's recorded manifest; refuses to tag a field `upstream` when the manifest declares nothing |
| `packages/registry/src/entries.ts` | Five listings, curated values each carrying their `why`, the misattribution case handled explicitly |
| `packages/registry/src/generate.ts` | Pure builder: sorted, fixed-indent, byte-stable |
| `packages/registry/src/generate-cli.ts` | The write, split out so importing the package has no side effect |
| `packages/registry/src/index.ts` | Public surface |
| `packages/registry/src/registry.test.ts` | 11 unit tests: determinism, sorting, tag discrimination, the misattribution case |
| `packages/registry/attribution/*/plugin.json` | Five upstream manifests recorded verbatim (DEC-011, DEC-013) |
| `packages/registry/test/fixtures/{supported,unsupported}-source.ts` | The AC-2 compile pair |
| `.claude-plugin/marketplace.json` | Generated output, committed so it is diffable |
| `scripts/check-src.sh` | The SRC-01 gate |
| `scripts/verify.sh` | New step 10/10; the nine existing steps renumbered |
| `tests/meta/cases/18..23-src-*.sh` | Six golden cases: four planted violations, one ASSERT-01 case, one clean pass |
| `tests/e2e/PDX-003-the-hub-installs.sh` | The scenario |
| `.github/workflows/ci.yml` | Installs the Claude Code CLI so AC-5 can run on the runner |
| `.prettierignore` | Recorded manifests exempted from formatting (DEC-013) |
| `scripts/check-structure.sh`, `CLAUDE.md` | `.claude-plugin/` registered in the layout — the path is fixed by the CLI, so it is registered rather than relocated |
| `DESIGN.md` | DEC-012, DEC-013, DEC-014 |

## 3. Plan Compliance

| Plan step | Done | Deviation (if any) |
|---|---|---|
| 1 Declare the package | ✅ | — |
| 2 Entry type + provenance discriminator | ✅ | — |
| 3 Read a pack's attribution manifest | ✅ | — |
| 4 The entries | ✅ | — |
| 5 Generate the marketplace | ✅ | Split into `generate.ts` (pure) and `generate-cli.ts` (writes). The plan had one module; as written it wrote the manifest as an import side effect, so every scenario assertion that imports the package would have rewritten the file it was about to compare |
| 6 The SRC-01 gate | ✅ | — |
| 7 Golden cases | ✅ | Six rather than the four the plan implied: one per blocked condition, plus an ASSERT-01 case (unbuilt registry must refuse) and a clean pass so the gate is shown not to false-positive |
| 8 The scenario | ✅ | — |

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

| Round | Command | Result |
|---|---|---|
| 1 | `./scripts/test-loop.sh PDX-003 --red` | verify PASS, e2e FAIL — 8 assertions failing, each naming its own cause (AC-1 "not built", AC-2 "compile pair is missing", AC-4 "check-src.sh does not exist", Attribution "produced no report"). RED OK, state stamped |
| 2 | `./tests/e2e/PDX-003-the-hub-installs.sh` | 5 pass, 4 fail — see the four defects below |
| 3 | `./tests/e2e/PDX-003-the-hub-installs.sh` | 9/9 pass |
| 4 | `./scripts/test-loop.sh PDX-003` | verify PASS, e2e 3/3, GREEN, state stamped |

Round 2's four failures are worth recording because two of them are the project's
recurring shape:

1. **The AC-2 negative fixture compiled.** Its comment explaining why `@ts-expect-error`
   is not used began a line with `// @ts-` + `expect-error`, which *is* the directive —
   so the comment suppressed the exact error the assertion exists to catch, and `tsc`
   exited 0 on a fixture that must fail. Reworded, and the comment now says so.
2. **AC-7 failed while finding what it looked for.** `verify.sh | grep -qi SRC-01` under
   `set -o pipefail`: `grep -q` exits on first match, `verify.sh` dies of SIGPIPE, and the
   pipeline reports 141. The output is captured first and searched second.
3. **AC-5's install failed on transport.** The CLI clones over SSH and this machine has no
   GitHub SSH key; both the manifest and the repository are fine over HTTPS. The scenario
   now tries plain first and retries once on a recognised publickey failure with an HTTPS
   rewrite scoped to the process via `GIT_CONFIG_*`, leaving global git config untouched,
   and reports which transport succeeded.
4. **Attribution looked for the wrong id.** It pinned `andrej-karpathy-skills`, the
   manifest name, where the entry is keyed by its arm id `karpathy`. Corrected.

### 4.1 Final GREEN evidence

- check-test-case: PASS
- verify (language + structure + gates + no-llm + templates + typecheck + lint + test +
  build + **SRC-01**): PASS, 10/10
- gate self-test: PASS, 23/23 planted violations caught
- registry unit tests: 11/11
- ticket e2e: PASS, 9/9 assertions
- regression (`e2e.sh` all): PASS, 3/3

## 5. Non-Scriptable Verification (DEV-01)

| Item | Result | Notes |
|---|---|---|
| Studio visual quality (agent-browser screenshot review) | N/A | No UI in this ticket; the catalogue lands with PDX-004 |
| CI workflow executes on the runner (declared, then verified) | PASS | Run 32013908666 on PR #4: `verify` pass 31s, `e2e` pass 55s. The CLI installed in 4s (`added 2 packages`) and AC-5 ran for real on the runner — `✓ AC-5: caveman@plugdex installed over https and appears in the installed list` — so `plugin install` needs no credentials, and the HTTPS retry path is exercised on a machine with no SSH key at all. This row was written as DECLARED, NOT VERIFIED before the push and is updated with the run that settled it |
| A real pack installs from its author's repository | PASS | `caveman@plugdex` cloned from `JuliusBrussee/caveman` over HTTPS and appears in `claude plugin list`, under a scratch `CLAUDE_CONFIG_DIR` |

## 6. Regression Check

`./scripts/e2e.sh` with no argument, 3/3: PDX-001, PDX-002, PDX-003. Nothing skipped.
`verify.sh` renumbering touched all nine existing step labels; the gate self-test and the
full regression both pass after it.

On CI, run 32013908666: `verify` pass, `changed` pass, `e2e` pass 3/3 with AC-5 executing
a real install on the runner.

One caveat that is not flakiness but will look like it: AC-5 requires network and the
`claude` CLI, and fails rather than skips when either is missing. That is the ticket's
intent — a skip would leave the product's premise unproven while the run stayed green —
and it means the scenario is not runnable offline. It also means the suite now depends on
two public repositories staying reachable, which is deliberate: a listed pack that stops
installing is a broken listing, and this is what catches it.

## 7. Rules Verification

- LANG-01: `./scripts/check-language.sh` PASS
- SRC-01: now enforced by `scripts/check-src.sh`, in `verify.sh`, with six golden cases
- GATE-01: every blocked condition has a planted violation; 23/23 caught
- ASSERT-01: applied throughout the scenario and inside the gate itself — every subprocess
  prints a sentinel, every assertion requires a non-empty capture, and case 22 proves the
  gate refuses on an unbuilt registry rather than reporting nothing wrong
- DATA-01: no verdicts are produced or rendered here; the AC-6 join reads `@plugdex/data`
- CR-01: generation is local; nothing was published
- Decision conformance: DEC-003, DEC-004, DEC-006, DEC-011 honoured; DEC-012, DEC-013,
  DEC-014 added by this ticket

## 8. Risks / Notes

The four findings the plan review deferred to this stage, per REV-02, and what happened to
each:

1. **Attribution's zero-iteration vacuity — fixed.** The check now counts what it examined
   and the assertion requires that count to be positive, so a well-formed report of
   `{checked: 0, bad: []}` fails. It also pins the misattribution pack by id and requires
   its author to be `upstream`-tagged, so a listing that quietly retagged itself `curated`
   would drop out of the check and be caught rather than pass. This is ASSERT-01's own
   blind spot: a sentinel proves the subprocess ran, not that it checked anything.
2. **AC-5 skip semantics — resolved as fail.** The ticket said "skips loudly"; the
   scenario fails. A skip that leaves the suite green means the product's premise goes
   unproven on any machine without the CLI, which is the one outcome the assertion exists
   to prevent. The ticket's wording is the thing that was wrong.
3. **AC-4's failure message — fixed.** It now distinguishes "there is no gate" from "the
   gate blocks this registry", proven by the RED run naming the missing script.
4. **AC-3 mutating a tracked file — fixed.** The comparison copies to the sandbox first
   and restores only on the diff-fail branch, so a build dying mid-write cannot leave the
   tracked manifest corrupted.

Open, for later tickets:

- **Nobody has been notified.** Five packs are listed with `listingProvenance.how =
  "measured"` and a note saying the author was not consulted. PDX-013 is the launch
  blocker that fixes this, and it must land before anything is public.
- **`packages/registry/test/` is outside the package's `tsconfig` include.** The fixtures
  are compiled by the scenario with explicit flags rather than by the project, which is
  correct — one of them must fail — but it means they are not typechecked by `verify.sh`
  and a drift in `schema.ts` would show up only in the scenario.
- **The registry's `test` script would have passed with zero tests.** Before
  `registry.test.ts` existed, `tsx --test src/*.test.ts` reported `# tests 0 # pass 0` and
  exited 0 — a suite that runs nothing and a suite that passes are the same output. It is
  fixed by the tests existing; it is not fixed by anything that would catch a recurrence,
  and that is a candidate for the ASSERT-01 golden set.

## 9. CR-01 Compliance

- No commit / push / issue / PR / merge / release performed without explicit user
  instruction during this ticket: **YES**. The user delegated commit, push, PR creation,
  and merge for this session explicitly, instructing that the work continue autonomously
  and that commits be made without a per-commit approval step — which matches the standing
  delegation recorded in the 2026-08-17 handoff §5. Issue #3
  was created with `./scripts/gh-submit.sh issue PDX-003`; raw `gh issue create` was not
  used. Nothing was published: the marketplace was added from a local path and the install
  ran under a scratch `CLAUDE_CONFIG_DIR`.

## 10. Agent Review

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
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | | |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | | |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | | |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | | |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | | |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | | |

### Comments
1.

### Blockers (only if NEEDS_REVISION)
-

## 11. Final Report Status

- Agent: _(pending)_
- Human: _(pending)_
