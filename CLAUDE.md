# plugdex — Project Instructions

plugdex is the hub for agent behaviour packs — ponytail, superpowers, caveman,
Karpathy's `CLAUDE.md`, Matt Pocock's skills, and whatever ships next week. You
browse them in one place, you install them with one command, and every listing
carries a measured verdict: **we ran the pack against real tickets in a real
repository and built the code it delivered.**

The packs advertise headline numbers — less code, fewer tokens, lower cost. Those
numbers are real measurements. They are also, in every published benchmark we could
find, measured without checking that the delivered code compiles. plugdex is the
catalogue that checks, and publishes the receipt beside the listing.

Two faces, one dataset:

- **the site** — a browsable catalogue, one card per pack, verdict chip, install button
- **the registry** — a Claude Code marketplace generated from the same records, so
  `claude plugin marketplace add plugdex` makes every listed pack installable by name

The product philosophy — *a claim is worth what its receipt is worth* — is applied
to this repository's own harness. Work proceeds via workflow tickets (`PDX-###`),
never ad hoc.

## LANG-01 — English Only (mandatory)

**Every project artifact MUST be written in English.** No Korean (or any
non-English) text in: source code, comments, identifiers, docs, tickets, plans,
reports, commit messages, test fixtures, script output, or PR/issue text.
Conversation with the user may be in any language; artifacts may not.

**There is no allowlist.** The harness this was ported from carried one exception (a
Korean normative spec); plugdex publishes to a global audience and `DESIGN.md` is
English like everything else. Enforced deterministically: `./scripts/check-language.sh`
greps for Hangul and BLOCKs. It runs inside `verify.sh`, so no gate passes while
Korean exists anywhere in a tracked file. Golden-set case 11 asserts that the
allowlist is still empty.

## CR-01 — Cardinal Rule

GitHub-external actions (commit / push / issue / PR / merge / release / workflow
trigger / deploy) are **forbidden until the user explicitly instructs that exact
action**. This rule overrides every other rule in this project. On violation: stop
immediately, disclose, and restore state.

**Commit convention:** one ticket = one commit, landed only after GREEN (every
commit's tree is a verified-green state — mid-cycle RED or partial states are never
committed). The ticket, plan, and report live in the same commit for traceability.
Post-GREEN fixes found later use a follow-up commit titled
`PDX-###: follow-up — <what>`. The agent only stages and hands over the message; the
user runs `git commit` (CR-01) unless they explicitly delegate.

**Issue linkage (mandatory):** every ticket opens a GitHub issue when work starts
(draft the body in `.docs/drafts/issue-pdx-###.md`). The issue number MUST appear in
the commit message — title suffix `(#N)` plus a `Closes #N` line in the body.
Message shape: `PDX-###: <imperative summary> (#N)`.

**Submissions are scripted, never hand-rolled:** issues and PRs are created ONLY via
`./scripts/gh-submit.sh issue|pr <PDX-###>` — raw `gh issue create` / `gh pr create`
is forbidden. The script derives the title (issue: from the ticket H1; PR: from the
HEAD commit title), gates the draft body (TMPL-01), always assigns the authenticated
user, and derives labels deterministically (area from the ticket slug:
site/data/registry/harness/docs; type from the branch prefix: feat→enhancement,
fix→bug, docs→documentation, chore→chore). Same inputs, same submission — every time.

**Branch + PR flow (mandatory):** work happens on a ticket branch named
`<type>/pdx-###-<kebab-slug>` (type: `feat` | `fix` | `chore` | `docs`, e.g.
`feat/pdx-004-pack-cards`), never directly on `main`. After GREEN + report review:
push the branch, open a PR from the `.docs/drafts/pr-pdx-###.md` draft
(TMPL-01-gated), wait for CI green, merge (rebase merge — linear history), delete the
branch, then move to the next ticket.

## Workflow — 9-Stage Gate Cycle

Full spec: `docs/WORKFLOW.md`. The user gives one ticket ID; the whole cycle runs as
one loop. Every gate retries until PASS — a BLOCK/FAIL at any stage means fix and
re-run the same gate, never skip ahead.

| # | Stage | Artifact | Gate command |
|---|---|---|---|
| 1 | preflight | context staged | `./scripts/preflight.sh <ID>` |
| 2 | plan | `.docs/analysis/<ID>_plan.md` | — |
| 3 | plan cross-review | Agent Review section | `./scripts/agent-review.sh plan <path>` |
| 4 | test-case first | `tests/e2e/<ID>-*.sh` | `./scripts/check-test-case.sh <ID>` |
| 5 | RED check | verify PASS + e2e FAIL | `./scripts/test-loop.sh <ID> --red` |
| 6 | implement | `packages/` changes | — |
| 7 | GREEN check | verify + e2e + regression PASS | `./scripts/test-loop.sh <ID>` |
| 8 | report | `.docs/analysis/<ID>_report.md` | — |
| 9 | report cross-review | Agent Review section | `./scripts/agent-review.sh report <path>` |

Key invariants:

- **TDD with explicit RED**: stage 5 requires verify PASS **and** the ticket's e2e
  FAIL simultaneously. A test that already passes before implementation is a fake cycle.
- **Cross review is rubric-scored** (REV-01): plan and report need verdict APPROVED or
  APPROVED_WITH_NOTES (0 blockers) AND a fully scored rubric (plan P1–P7 / report
  R1–R6, each row PASS/FAIL/N-A with one line of evidence). The gate rejects missing
  rows, empty evidence, and APPROVED with any FAIL row.
- **REV-02 — the plan review is capped at two rounds.** Round 1 finds design and scope
  defects, which is what a plan review is for. Round 2 confirms the fixes. After round 2,
  anything still outstanding that is not a *blocker* rides to the report stage, where the
  code exists and the finding can be checked against something real. Measured on PDX-002:
  rounds 3 and 4 each cost a full review cycle to correct one stale number in prose and
  found no defect in the work. A third round is permitted only when round 2 raises a new
  blocker, and the report must say why.
- **PLAN-01 — plans reference volatile facts, they do not restate them.** Commit counts,
  SHAs, line numbers, and file inventories go stale between writing a plan and running
  it, and every PDX-002 plan review after round 1 was spent chasing exactly that. State
  where the fact lives and let the scenario derive it. Where a number must appear for the
  argument to make sense, it is written as a claim the e2e asserts — never as prose only
  a reviewer can check.
- **ASSERT-01 — an assertion never passes on empty output.** Every subprocess whose
  output an assertion reads must print a sentinel when it succeeds, and an empty capture
  fails the assertion instead of satisfying it. The failure shape is always the same: a
  command dies, its stderr is discarded, the variable holding its findings is empty, and
  `[[ -z "$FINDINGS" ]]` prints a checkmark for a check that never ran. This project has
  produced it six times — PDX-002's AC-7 grep and its timezone comparison, PDX-003's AC-2
  and its Attribution assertion, the grader reporting zero mypy diagnostics when the
  python gate was absent, and the loader reading a missing environment audit as a clean
  environment. Six instances is a missing rule, not six mistakes.
- **Scripts decide, not vibes**: a stage is done when its gate script exits 0.
- **Stage order is enforced**: each passed stage is stamped via
  `scripts/workflow-state.sh` (`.docs/state/<ID>.state`); later gates refuse to run
  without the earlier stamp. Recovery bypass `PLUGDEX_STATE_BYPASS=1` is loud and must
  be justified in the report.
- **Gates are themselves tested** (GATE-01): `scripts/check-gates.sh` replays a golden
  set of planted violations (`tests/meta/cases/`) against sandbox copies of the gates.
  Fix a missed case by fixing the gate — never by deleting the case.
- **Gate runs are observable** (OBS-01): every gate appends one JSONL record to
  `.docs/scratch/gate-runs.jsonl` via `scripts/lib/gate-log.sh`;
  `./scripts/gate-stats.sh` summarizes fail rates and TDD rounds-to-GREEN. Logging
  never changes a verdict.
- **NOLLM-01 — never bundle an LLM SDK**: no `packages/` manifest or source may depend
  on / import a blocklisted LLM-inference SDK. A catalogue that measures agents must
  not ship one. The blocklist at the top of `scripts/check-no-llm.sh` is the single
  source of truth (verify step 4).
- **TMPL-01 — templates don't drift**: tickets and PR drafts must carry their
  template's required `## ` sections, in order, with non-empty bodies
  (`scripts/check-templates.sh`, verify step 5 + pre-commit).
- **REF-01 — reference gate**: a mapped ticket's plan (PDX-002+) must show its required
  references opened (Y + note) in the "References Consulted" section, enforced by
  `scripts/check-references.sh` (run by `agent-review.sh plan`) and mirrored by rubric
  row P7. PDX-001 is exempt. The map lives in `DESIGN.md`, Reference Map.
- **Non-scriptable behavior is declared, not skipped** (DEV-01): behavior no gate can
  verify (visual quality of a card, whether a chip reads as a warning) gets a
  Non-Scriptable Verification checklist in the report — checked via a real browser or
  explicitly N/A.

## Rules this project adds to the lineage

These exist because plugdex publishes other people's work and our own numbers. They are
the reason the harness was worth porting rather than reinventing.

- **DATA-01 — no hand-typed numbers.** Every figure rendered by the site must come
  from a record in `packages/data`, and every record must carry the environment
  fingerprint of the run that produced it. A number typed into a component is a
  number nobody can check.
- **DATA-02 — no fact that governs the analysis lives outside the record.** DATA-01's
  other half. Which records a figure is computed over is decided by fields on those
  records — a withdrawal carries its reason and its date on the record itself — and no
  filename comparison decides whether a live record enters an analysis pool. The rule
  exists because the opposite shipped: one run was excluded by a filename prefix inside
  a single analysis script, and the two halves of this codebase disagreed by 76 cells
  about what the corpus was. Gate: `./scripts/check-data-universe.sh` (verify step 6).
- **CLAIM-01 — withdrawn claims stay reachable.** A published verdict that turns out
  to be wrong is corrected in place and its previous value, the cause, and the
  replacement remain on the site. Deleting a wrong number is worse than never
  publishing it.
- **SRC-01 — attribution and opt-out.** Every listed pack links to its upstream
  repository and names its author, the registry points at that repository rather than
  vendoring it, and the listing records how the author asked to be listed or removed.

## Layout

```
CLAUDE.md              this file
DESIGN.md              normative spec + decision log + Reference Map
README.md              public pitch + development pointer
LICENSE                MIT
docs/WORKFLOW.md       9-stage gate workflow (full spec)
.docs/tickets/         ticket files: PDX-###_<slug>.md (template: _TICKET_TEMPLATE.md)
.docs/analysis/        plans & reports per ticket (templates: _PLAN_TEMPLATE.md, _REPORT_TEMPLATE.md)
.docs/drafts/          issue / PR drafts staged for the user to submit (TMPL-01, CR-01)
.docs/scratch/         preflight stage output + gate logs (generated, not committed)
.docs/state/           per-ticket stage stamps (generated, not committed)
scripts/               deterministic gates (see docs/WORKFLOW.md §4)
tests/e2e/             per-ticket scenarios: PDX-###-*.sh + all.sh regression
tests/meta/            gate self-test golden set (lib.sh + cases/*.sh)
packages/              pnpm workspace (planned; absence OK until each package's ticket):
  data                 baked measurement records: pack entries, verdicts, cell receipts, fingerprints
  registry             marketplace.json generation from the same records — the machine face
  site                 the public catalogue (Astro, static, React islands where interaction is real)
.claude-plugin/        generated marketplace.json — the file `claude plugin marketplace add`
                       reads. Generated by @plugdex/registry and committed so it is diffable;
                       the path is fixed by the CLI, not chosen by us
```

## Stack conventions

- TypeScript everywhere, pnpm workspaces. Node steps in `verify.sh` are skipped with a
  loud warning in empty-workspace mode until a `packages/*/package.json` exists.
- `const fn = ({ a, b }) => {}` — arrow functions assigned to const, never `function`
  declarations; params always a single destructured object, never positional.
- JSX conditionals `cond ? <X/> : null`, never `cond && <X/>` (avoids falsy-leak).
- Blank lines separate logically distinct chunks (guard ↔ logic, call ↔ post-processing).
- JSDoc/TSDoc comments in English.
- The site is static-first. An interactive island has to earn its JavaScript; a
  catalogue that cannot be read without a bundle is a catalogue nobody indexes.

## Model policy

Design, plans, and cross-reviews (REV-01 plan/report reviews) = **Fable**; ticket
implementation and mechanical code work = **Opus** subagents. Reviews loop
autonomously until they pass. Rationale: judgment quality where it matters,
throughput where it counts.

## Browser verification

Any UI behaviour is verified in a real browser, not by reading the JSX. Cards,
chips, the receipt drawer, dark mode, and the narrow-viewport reflow are driven and
screenshotted by an e2e scenario; a claim about how something looks that was never
rendered is a DEV-01 violation.

## Verification commands

- `./scripts/verify.sh` — check-language + check-structure + check-gates + check-no-llm + check-templates + check-data-universe + typecheck + lint + test + build + check-src
- `./scripts/check-gates.sh` — gate self-test (golden set of planted violations)
- `./scripts/workflow-state.sh show <ID>` — per-ticket stage stamps (order enforcement)
- `./scripts/gate-stats.sh` — gate-run observability summary
- `./scripts/install-hooks.sh` — installs the pre-commit hook (run once per clone)
- `./scripts/e2e.sh [<ID>]` — run ticket e2e scenarios (no arg = full regression)
- `./scripts/test-loop.sh <ID> [--red]` — the combined TDD gate
