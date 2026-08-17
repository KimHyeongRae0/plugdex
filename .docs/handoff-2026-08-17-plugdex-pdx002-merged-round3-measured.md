# Handoff — plugdex, 2026-08-17 (PDX-002 merged, PDX-003 in flight, round-3 measurement done)

Read this first in a new session. It is written to be self-contained: every claim names
the file or command it came from, and every open problem says what the next move is and
why. Where something is uncertain, it says so rather than rounding to confident.

- Repository: `~/Desktop/project/plugdex` — github.com/KimHyeongRae0/plugdex (private)
- Measurement harness: `~/Desktop/project/pack-pilot` (25 GB; holds the preserved cell
  workspaces that grading re-reads)
- Former measurement repo: `~/Desktop/project/does-it-compile` — **absorbed into
  `bench/`; should be archived on GitHub, which needs an explicit instruction (CR-01)**

---

## 1. What plugdex is, in one paragraph

A hub for Claude Code agent behaviour packs (ponytail, superpowers, caveman, Karpathy's
`CLAUDE.md`, Matt Pocock's skills) where every listing carries a measured verdict: we ran
the pack against real tickets in a real repository and built the code it delivered. Every
published pack benchmark we could find measures tokens and cost **without checking that
the delivered code compiles**. plugdex is the catalogue that checks, and publishes the
receipt beside the listing. Two faces over one dataset: a static site, and a generated
`marketplace.json` so `claude plugin install` works.

The whole product rests on being believable, which is why the repository's own rules are
gates rather than intentions, and why this handoff is blunt about what is broken.

---

## 2. State of the code

### Merged and on `main`

```
30f4ede  bench: preregister round three, and grade the sonnet probe
214c3b9  Merge pull request #2 (PDX-002)          <- MERGE COMMIT, deliberately not rebase
0020cfa  PDX-002: follow-up — find the subtree graft by content, not by position (#1)
f934cb3  PDX-002: absorb the measurement project and bake its records (#1)
1e8832a  chore: cap the plan review at two rounds and stop plans restating volatile facts
fd419bb  PDX-001: follow-up — make CI describe this repository
8827b79  Add 'bench/' from commit 'd63ff3b...'    <- subtree graft, second parent = imported history
e05b2f2  PDX-001: follow-up — repoint area labels and the issue template at plugdex
3e34289  PDX-001: follow-up — publish workflow artifacts and finish the prompt port
cbab350  PDX-001: port the gate harness and point it at plugdex
```

`origin/main` = `30f4ede`. Issue #1 closed, PR #2 merged, branch deleted.

**PR #2 was merged with a merge commit on purpose.** `8827b79` is the subtree graft whose
second parent is the imported measurement history. GitHub's rebase merge cannot replay a
merge commit, and what it would drop is the four author dates AC-1 exists to preserve.
Every later PR rebases as normal — no other ticket imports a repository. This is stated
in the PR body.

### Workflow state

| Ticket | State |
|---|---|
| PDX-001 harness port | Done (merged; its state file was never stamped — it predates the state machine's use) |
| PDX-002 data package | **Done, merged.** All 9 stages stamped |
| PDX-003 registry | preflight stamped. **Plan review round 2 returned NEEDS_REVISION with 2 new blockers** |
| PDX-004 site catalogue | Ticket written, no plan yet |

### Uncommitted in the working tree

- `DESIGN.md` — modified (DEC-011 added)
- `.docs/tickets/PDX-003_registry-pack-entries-and-marketplace-generation.md` — untracked
- `.docs/tickets/PDX-004_site-catalogue-cards-verdicts-and-install.md` — untracked
- `.docs/analysis/PDX-003_plan.md` — untracked
- `bench/data/runs/20260817-162601-sonnet-three-questions.{acceptance,results}.json` — the
  round-three run, untracked

Everything above is green: `./scripts/verify.sh` PASS 9/9, `./scripts/e2e.sh` 2/2,
`./scripts/check-gates.sh` 17/17.

---

## 3. The three open problems, in priority order

### 3.1 — `p = 0.060` may be wrong, and the product's positioning rests on it

**This is the most important item in this handoff.**

`DESIGN.md` asserts in four places that pack differences are not statistically significant,
citing a best pairwise Fisher exact result of `p = 0.060`:

- §4.1, the measurement-layer table — "**not significant — best pairwise Fisher p = 0.060**"
- §4.2, the claim-structure table
- §4.3, "No default ranking"
- **DEC-005** — "The landing view is a cell grid, not a leaderboard"

The site's entire shape — no leaderboard, no composite score, three binary questions
instead of a ranking — is built on that number.

Recomputing over the full committed corpus, separated by regime, gives a different answer:

```
--- blocked regime only (baseline n=49 code-producing valid cells)
   ponytail     31/51 = 61%  vs baseline 16/49 = 33%   Fisher p = 0.0055
   karpathy     17/51 = 33%  vs baseline           33%   p = 1.0000
   caveman      11/35 = 31%  vs baseline           33%   p = 1.0000
   mattpocock   17/50 = 34%  vs baseline           33%   p = 1.0000
   Bonferroni threshold for 4 pack-vs-baseline tests = 0.0125  ->  ponytail SIGNIFICANT

--- as-shipped regime only (baseline n=11)
   nothing close to significant; best is caveman p = 0.5147
```

Task coverage is 12/12 shared between ponytail and baseline, so this is not a task-mix
artifact. Per-task, ponytail wins 6, loses 1, ties 5.

**What is NOT established:**

- Where `0.060` came from. `bench/README.md:47` states it with no derivation, no subset,
  no comparison named. That is the exact sin this project criticises in other benchmarks,
  committed in our own README.
- Whether the recomputation is right. `scipy` is not installed on this machine. The Fisher
  implementation used was hand-written and validated against three textbook values
  (tea-tasting `[[3,1],[1,3]]` -> 0.4857; `[[1,9],[11,3]]` -> 0.0028; a degenerate case)
  before use. That is validation, not proof.
- Whether `0.060` was computed on a narrower subset — plausibly only the two frontend runs
  (72 cells) rather than the full corpus, or pack-vs-pack rather than pack-vs-baseline.

**Next move:** re-derive `p = 0.060` from a stated subset and a stated comparison, write
the derivation down next to the number, and then either keep the claim or withdraw it. If
ponytail genuinely has a significant effect, DEC-005's rationale changes and the "no
leaderboard" decision needs re-arguing on different grounds (it may still be right — one
significant pack out of five is not a ranking). **Do not quietly flip DESIGN.md.** This is
the first CLAIM-01 case and CLAIM-01's gate does not exist yet (it lands with PDX-009).

**A related data defect found while doing this:** the `regime` field (blocked vs
as-shipped) is **not in the published records**. It had to be inferred from filenames
(`...-as-shipped`), because `run.py` gained that stamp after these runs were written.
Regime changes results substantially — baseline goes from 33% to 73% build rate — so a
run-level condition that big living only in a human-readable filename is a DATA-01
problem in spirit.

### 3.2 — Instrument failure #17: 22% of the round-three run died

The sonnet run lost 4 of 18 cells to `DEAD(unparseable-result-json)`:

```
baseline/command   karpathy/command   baseline/wizard   mattpocock/wizard
```

**baseline lost 2 of its 3 cells**, which destroyed the control group and made
preregistered prediction 4 unjudgeable. Cause not yet investigated. It must be found
before spending on an opus run, or the same fraction evaporates: at ~$41 for 18 opus cells,
22% loss is ~$9 of nothing.

### 3.3 — PDX-003 plan review round 2: two new blockers, both real

Round 1 found three design defects (all fixed and confirmed). Round 2 **executed the staged
scenario** and found two more:

1. **The Attribution assertion is GREEN on today's tree.** Its node snippet imports
   `./packages/registry/dist/index.js`, which does not exist; the error goes to a discarded
   stderr, `MISMATCH` is empty, and the empty-string test prints a passing checkmark for a
   check that never ran. This is the assertion the plan calls "the one that makes SRC-01
   more than paperwork".
2. **AC-2's paired compile check does not exist.** Ticket AC-2 and plan §7 both specify it;
   the staged scenario checks only the emitted JSON. "Must fail the type" has no artifact
   that can fail it.

REV-02 caps plan review at two rounds but permits a third when round 2 raises a **new**
blocker, with the reason stated in the report. That clause applies here.

**This is the fourth fake-RED in this project** (PDX-002's AC-7 grep, PDX-002's timezone
comparison, PDX-003's AC-2, PDX-003's Attribution). The pattern is always the same shape:
*empty output read as "no problem"*. A rule should be added — every scenario subprocess
emits a sentinel, and empty output fails the assertion — rather than fixing each instance.

---

## 4. The measurement data

`bench/data/runs/` — 10 acceptance records, 10 results records, all sharing environment
fingerprint `4b140e75d7dc1828`.

| Run | What it is |
|---|---|
| `20260815-225842-frontend-withdrawn-different-prompt` | **Withdrawn.** Instrument failure 16 (prompt drift) |
| `20260816-010513-backend-and-dead-frontend` | backend, blocked |
| `20260816-020247-frontend` | frontend, blocked |
| `20260816-092732-caveman-blocked` | caveman, blocked |
| `20260816-094325-frontend-dropzone` | frontend, blocked |
| `20260816-094958-as-shipped-partial` | as-shipped regime |
| `20260816-113302-as-shipped` | as-shipped regime |
| `20260816-121801-as-shipped-combo` | as-shipped, combination arm |
| `20260816-222615-superpowers-sonnet-probe` | 3 cells, sonnet, graded 2026-08-17 |
| `20260817-162601-sonnet-three-questions` | **round three, 18 cells, sonnet — uncommitted** |

`bench/data/gate-limits.json` is a different schema — gate probe results, 8 probes, 4
caught, 4 missed. `@plugdex/data` deliberately does not read it.

### What `@plugdex/data` will and will not load

Only `*.acceptance.json`. The `*.results.json` files carry **no environment fingerprint**
— the runner gained that stamp after they were written — so under DATA-01 they cannot be
rendered. **Cost and token figures exist only in `results.json`.** The first ticket that
needs a cost number inherits that contradiction explicitly; it is named in PDX-002's
ticket and report, and it is not solved.

### Findings so far

- **~55% of delivered code does not build** across two domains and two independent gate
  stacks, 141 code-producing cells (haiku).
- **superpowers produces no code at all in an unattended session.** 61 of 62 valid haiku
  cells, plus 3 of 3 in the sonnet probe, plus 3 of 3 in round three. It classifies the
  ticket, asks a clarifying question, and stops. Strongest result in the project.
- **caveman's published −65% token headline did not reproduce** (measured +11.8%, CI
  excludes the claim).
- **ponytail at 61% build rate vs baseline 33% in the blocked regime** — see §3.1; this
  contradicts the currently published "not significant" claim and is unresolved.

### Round three (2026-08-17), preregistered in `bench/PREREGISTRATION-3.md`

Preregistration committed at `30f4ede` **before** the run started at 16:26 — the same
ordering the project asks of everyone else, checkable in `git log`.

Design: `claude-sonnet-4-6` (deliberately the same model string as the probe, so the two
are comparable), 3 frontend tasks (datepicker, command, wizard), 6 arms, 1 rep, blocked
regime, Claude Code 2.1.233.

| # | Prediction | Outcome |
|---|---|---|
| 1 | superpowers produces no code in all 3 | **HELD** — 3/3 NO-CODE |
| 2 | mattpocock produces code in >= 2 of 3 | **HELD** — both valid cells produced code (1 DEAD) |
| 3 | sonnet build-failure rate below 40% | **FAILED** — measured 54.5% |
| 4 | no pack beats baseline by 2+ of 3 cells | **UNJUDGEABLE** — baseline lost 2 of 3 cells to #17 |
| 5 | caveman token headline still does not reproduce | not yet analysed |

**Prediction 3 failing is the finding of the round.** Like-for-like on the same three
tasks and the same regime:

```
haiku    14/81 built = 17.3%   ->  failure 82.7%
sonnet    5/11 built = 45.5%   ->  failure 54.5%
```

Sonnet is clearly better than haiku, and still more than half of what it delivers does not
build. The obvious objection to every earlier finding — "you only measured the cheapest
model" — does not survive. Caveats that must travel with this number: n=11, and these
three tasks are among the harder ones in the haiku set (wizard 2/12, datepicker 2/12), so
the bias is pessimistic rather than optimistic.

Prediction 4 being unjudgeable is recorded as a **failure of the run**, not converted into
support. Writing "unjudgeable" where the temptation is "supported" is the whole discipline.

### What has not been measured

- **Opus.** ~$41 for 18 cells. Recommendation: hold until #17 is fixed.
- **GPT / Codex.** `codex-cli 0.147.0` is installed and **authenticated via ChatGPT
  subscription** — running it consumes the user's ChatGPT plan quota, not an API bill.
  Flag that before launching anything.
  **Structural asymmetry, already recorded in `PREREGISTRATION-3.md`:** only 4 of 7 arms
  are portable. `baseline`, `ponytail`, `caveman`, `karpathy` inject text. `superpowers`,
  `mattpocock`, and `ponytail+superpowers` are Claude Code **plugins** loaded through a
  SessionStart hook and have no form outside Claude Code. The most-installed pack in the
  set, and the subject of the project's strongest finding, cannot be measured on GPT at
  all. That is a publishable fact about the ecosystem, not a gap in our method. Also:
  `run.py` drives the `claude` CLI only; a Codex backend is a code ticket, not a flag.

---

## 5. The workflow, and what changed today

Nine-stage gate cycle per ticket; full spec in `docs/WORKFLOW.md`, summary in `CLAUDE.md`.
Ported from orangerail/ontogate with contents swapped for plugdex.

Two rules were **added today** after the plan review on PDX-002 ran to four rounds:

- **REV-02** — plan review is capped at two rounds. Round 1 finds design and scope
  defects; round 2 confirms the fixes; non-blocking findings after that ride to the report
  stage where the code exists. A third round requires a **new** blocker in round 2,
  justified in the report.
- **PLAN-01** — plans reference volatile facts rather than restating them. Every PDX-002
  plan-review round after the first was spent on the plan having copied a count or a path
  that then went stale.

The report review was deliberately **not** trimmed: its first round on PDX-002 caught a
fabricated timestamp and a host-timezone-dependent assertion. A gate that keeps finding
defects is not the one to cut.

Decision log now runs DEC-001..DEC-011 in `DESIGN.md`. The ones added today:

- DEC-007 — workflow artifacts are tracked, not local-only (`.gitignore` had excluded all
  of `.docs/` while `CLAUDE.md` required the ticket in the commit — unsatisfiable)
- DEC-008 — ticket slugs lead with their area, because `gh-submit.sh` derives the area
  label from the slug prefix and yields **no label** on a miss rather than erroring
- DEC-009 — `bench/` is imported with history
- DEC-010 — prettier does not format Markdown
- DEC-011 — a pack's `plugin.json` is recorded here; its content is not. Vendoring ships
  someone's functionality; recording their manifest ships their declaration so our listing
  can be audited against it

### Submission, and the standing delegation

The user has explicitly delegated **commit, push, PR creation, and merge**. Standing
instruction: keep issue and PR format identical to orangerail, every time. Verified
line-for-line — `PULL_REQUEST_TEMPLATE.md`, `bug_report.yml`, `feature_request.yml`, and
`gh-submit.sh` differ from orangerail only in identifiers, areas, and repo name.

Flow: ticket -> `./scripts/gh-submit.sh issue PDX-###` -> commit with `(#N)` and
`Closes #N` -> push -> `./scripts/gh-submit.sh pr PDX-###` -> wait for CI -> merge ->
delete branch. Raw `gh issue create` / `gh pr create` is forbidden. `gh-submit.sh` does
**not** substitute the issue number into the PR draft's `Fixes #` line — fill it manually
after the issue exists.

### Things CI taught us that local runs could not

Both were found on the first CI run of PDX-002 and are fixed:

- GitHub checks a PR out as `refs/pull/N/merge`, a merge of the branch into base. A
  scenario that finds the subtree graft as "the first merge commit in the log" picks
  GitHub's merge commit instead and reads `main`'s history. The graft is now found by
  **what its second parent contains**.
- `actions/checkout` defaults to depth 1, which has no second parent at all. The e2e job
  now sets `fetch-depth: 0`.
- The e2e job does not run `verify.sh`, so nothing built `packages/data/dist`, which AC-3
  loads. A build step was added; proven by deleting `dist/` and watching AC-3 fail.

---

## 6. The roadmap

`DESIGN.md` §8 carries the full version. Shape:

```
A. dataset + machine face     PDX-002 (done)  PDX-003 (in flight)
B. the catalogue  -- SHIP --  PDX-004  PDX-005
C. the arguments              PDX-006  PDX-007  PDX-008  PDX-009  PDX-010
D. becoming a register        PDX-011  PDX-012  PDX-013  PDX-014
   harness debt               PDX-015
```

**Ship after PDX-005.** Cards plus install plus receipts is the whole argument; everything
after strengthens it and nothing after is required to be useful.

- **PDX-003** — registry, marketplace generation, SRC-01. Ticket and plan written; two
  blockers open (§3.3). The design's core: attribution is **derived** from each pack's own
  `.claude-plugin/plugin.json`, tagged `{from: "upstream"}` vs `{from: "curated", why}`,
  because a hand-typed author is our claim about someone and a derived one is their own
  declaration.
- **PDX-004** — the catalogue. Ticket written (`.docs/tickets/PDX-004_site-...md`), no
  plan. DATA-01 becomes a gate here: a numeric literal in a component that is not sourced
  from `@plugdex/data` is a BLOCK, and the gate must distinguish a claim from a layout
  constant or it will be disabled within a week.
- **PDX-012** — top-N listing plus a request-driven queue. Not "list everything": a GitHub
  code search for `.claude-plugin/marketplace.json` returns ~30,656 repositories.
- **PDX-013** — notify each measured pack's author before anything is public, offer a
  correction window, publish their response beside ours. Launch blocker.
- **PDX-015** — `check-templates.sh` states that issue-draft validation is deferred "until
  the repo is public and issue drafts actually exist". Both are now true, so TMPL-01
  claims coverage it does not have.

### Two findings that must reach the site

1. **The pack commonly called "Karpathy's skills" declares a different author.**
   `andrej-karpathy-skills/.claude-plugin/plugin.json` names `forrestchang` and declares
   no `repository`. It is a third party's packaging of Karpathy's published `CLAUDE.md`.
   Listing it under Karpathy's name would be misattribution on the front page of a
   provenance site. PDX-003's scenario asserts the listed author matches the manifest.
2. **ponytail ships two `plugin.json` files** — a stub `{"name":"ponytail"}` at the
   repository root and the real manifest under `.claude-plugin/` (author: Dietrich
   Gebert). Reading the wrong one yields a silently empty author, so `.claude-plugin/`
   is the canonical path and a root-level read is an error, not a fallback.

---

## 7. Verification commands

```bash
./scripts/verify.sh                    # 9 gates: language, structure, gate self-test,
                                       # no-llm, templates, typecheck, lint, test, build
./scripts/check-gates.sh               # gate self-test — 17 planted violations
./scripts/e2e.sh [PDX-###]             # no arg = full regression
./scripts/test-loop.sh PDX-### [--red] # the combined TDD gate
./scripts/workflow-state.sh show PDX-###
./scripts/agent-review.sh prompt plan PDX-###   # generates the reviewer prompt
./scripts/agent-review.sh plan .docs/analysis/PDX-###_plan.md   # the gate
```

Model policy: design, plans, and cross-reviews go to **Fable**; ticket implementation and
mechanical work to **Opus**. Reviews loop until they pass, within REV-02's cap.

Re-grading a run costs nothing and makes no API calls — it re-reads the preserved cell
workspaces:

```bash
cd ~/Desktop/project/pack-pilot
python3 acceptance.py arms/ponytail/benchmarks/agentic/runs/<RUN_ID> --out /tmp/x.json
```

Running new cells (this spends money — say so before launching):

```bash
cd ~/Desktop/project/pack-pilot/arms/ponytail/benchmarks/agentic
A=~/Desktop/project/pack-pilot/arms
PONYTAIL_PLUGIN_DIR=$A/ponytail SUPERPOWERS_PLUGIN_DIR=$A/superpowers \
MATTPOCOCK_PLUGIN_DIR=$A/mattpocock-skills CAVEMAN_PLUGIN_DIR=$A/caveman \
python3 -u run.py --task tmpl-fe-datepicker,tmpl-fe-command,tmpl-fe-wizard \
  --arms baseline,ponytail,caveman,karpathy,mattpocock,superpowers \
  --models sonnet --runs 1 --workers 3
```

---

## 8. Suggested next moves

1. **Re-derive `p = 0.060`** (§3.1). The product's shape depends on it, and the number
   currently has no derivation attached.
2. **Diagnose instrument failure #17** (§3.2) before any opus spend.
3. **Fix PDX-003's two blockers, add the empty-output-fails rule, run review round 3**
   (§3.3), then RED -> implement -> GREEN -> report -> merge.
4. Commit what is uncommitted (§2) — the round-three data especially; it currently exists
   only in the working tree and in `~/Desktop/project/pack-pilot`.
5. Archive `does-it-compile` on GitHub — needs an explicit instruction (CR-01).

---

## 9. Appendix — the PDX-003 scenario draft

Staged during this session and **not** in the repository: the structure gate correctly
refuses a `.sh` under `.docs/analysis/`, and dropping it into `tests/e2e/` would make it
part of the regression before its ticket is implemented. It is reproduced here in full so
the next session does not rewrite it, **and it carries the two open blockers from §3.3** —
the Attribution block passes on an empty result, and there is no paired compile check.

```bash
#!/usr/bin/env bash
# tests/e2e/PDX-003-the-hub-installs.sh
#
# PDX-003 — the hub installs, and every listing says whose work it is.
#
# The load-bearing assertion is AC-5: a real `claude plugin marketplace add` followed by
# a real `claude plugin install`, asserted on the resulting installed listing rather than
# on an exit code. If that does not work, plugdex is a report with an install button
# drawn on it.
#
# Network IS required, and that is deliberate. The install source is a github repo, so a
# successful install clones from the author's own repository — proving end-to-end delivery
# rather than manifest syntax. A listed pack that stops installing is a broken listing and
# this is what catches it, so a network error fails rather than skips.
#
# Nothing is published: the marketplace is added from a local path (CR-01), and everything
# runs under a scratch CLAUDE_CONFIG_DIR so the developer's real config is untouched.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }
skip() { echo -e "${YELLOW}  ⏭ $1${NC}"; }

echo "PDX-003 — the hub installs"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx003.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

MARKET=".claude-plugin/marketplace.json"

# ---------------------------------------------------------------------------
# AC-1 — every entry carries every SRC-01 field, each tagged upstream or curated.
#
# Read through the built package rather than by grepping the source, so this asserts
# what a consumer sees.
# ---------------------------------------------------------------------------
ENTRY_REPORT=$(node --input-type=module -e "
  import { entries } from './packages/registry/dist/index.js';
  const required = ['packId','displayName','author','upstreamRepo','license','installSource','listingProvenance','optOutContact'];
  const bad = [];
  for (const e of entries) {
    for (const f of required) {
      const v = e[f];
      if (v === undefined || v === null) { bad.push(\`\${e.packId ?? '?'}.\${f}: missing\`); continue; }
      // Attribution fields are tagged values, not bare strings.
      if (['author','upstreamRepo','license'].includes(f)) {
        if (typeof v !== 'object' || !('from' in v)) { bad.push(\`\${e.packId}.\${f}: untagged\`); continue; }
        if (v.from === 'curated' && !v.why) bad.push(\`\${e.packId}.\${f}: curated with no why\`);
        if (!['upstream','curated'].includes(v.from)) bad.push(\`\${e.packId}.\${f}: bad tag '\${v.from}'\`);
      }
    }
  }
  console.log(JSON.stringify({ n: entries.length, bad }));
" 2>/dev/null)

if [[ -z "$ENTRY_REPORT" ]]; then
  fail "AC-1: could not read entries from @plugdex/registry (package not built?)"
else
  N_ENTRIES=$(echo "$ENTRY_REPORT" | sed 's/.*"n":\([0-9]*\).*/\1/')
  BAD=$(echo "$ENTRY_REPORT" | sed 's/.*"bad":\[\(.*\)\]}/\1/')
  if [[ "$N_ENTRIES" -lt 1 ]]; then
    fail "AC-1: no entries — the registry lists nothing"
  elif [[ -n "$BAD" && "$BAD" != "" ]]; then
    fail "AC-1: entries with missing or untagged SRC-01 fields: $BAD"
  else
    pass "AC-1: $N_ENTRIES entries, every SRC-01 field present and tagged"
  fi
fi

# ---------------------------------------------------------------------------
# AC-2 — the install source is the github/repo form.
#
# The type is what forbids the git/url form; this asserts the emitted data agrees,
# because a type is not enforcement once the JSON is written.
# ---------------------------------------------------------------------------
if [[ ! -f "$MARKET" ]]; then
  fail "AC-2: $MARKET does not exist"
else
  BAD_SRC=$(python3 -c "
import json,sys
d=json.load(open('$MARKET'))
bad=[p.get('name','?') for p in d.get('plugins',[])
     if not (isinstance(p.get('source'),dict) and p['source'].get('source')=='github' and p['source'].get('repo'))]
print(','.join(bad))
" 2>/dev/null)
  if [[ -n "$BAD_SRC" ]]; then
    fail "AC-2: plugins whose source is not {source:github, repo}: $BAD_SRC"
  else
    pass "AC-2: every plugin source is the supported github/repo form"
  fi
fi

# ---------------------------------------------------------------------------
# AC-3 — generation is deterministic.
#
# Non-emptiness is checked FIRST. With no generator, two runs both produce nothing and
# "identical" would be vacuously true — the fake-green the plan review flagged.
# ---------------------------------------------------------------------------
if [[ ! -s "$MARKET" ]]; then
  fail "AC-3: $MARKET is missing or empty — nothing to compare"
else
  cp "$MARKET" "$SB/first.json"
  if pnpm --filter @plugdex/registry run build >/dev/null 2>&1; then
    if diff -q "$SB/first.json" "$MARKET" >/dev/null 2>&1; then
      pass "AC-3: regeneration is byte-identical ($(wc -c < "$MARKET" | tr -d ' ') bytes)"
    else
      fail "AC-3: regenerating changed the file — output is not deterministic"
      cp "$SB/first.json" "$MARKET"
    fi
  else
    fail "AC-3: the generator failed to run"
  fi
fi

# ---------------------------------------------------------------------------
# AC-4 — the SRC-01 gate blocks what it claims to block.
# The golden set is check-gates.sh's job; here we assert the gate runs clean on
# the real tree, so a broken gate cannot hide behind a green golden set.
# ---------------------------------------------------------------------------
if ./scripts/check-src.sh >/dev/null 2>&1; then
  pass "AC-4: SRC-01 passes on the real registry"
else
  fail "AC-4: SRC-01 BLOCKs the registry this ticket ships"
fi

# ---------------------------------------------------------------------------
# AC-5 — the hub actually installs. The one that matters.
#
# The marketplace is added from a local path so nothing is published (CR-01), but the
# install itself reaches GitHub because the source is a github repo. So this proves
# end-to-end delivery of a real pack from a real upstream. What it does NOT prove is that
# our marketplace is addable remotely — that needs this repository public, and the report
# states the limit in those terms rather than the reverse.
# ---------------------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  skip "AC-5: 'claude' is not on PATH — install proof NOT run (recorded, not passed)"
  FAILED=1
else
  export CLAUDE_CONFIG_DIR="$SB/claude-home"
  mkdir -p "$CLAUDE_CONFIG_DIR"

  FIRST_PACK=$(python3 -c "
import json
d=json.load(open('$MARKET'))
print(d['plugins'][0]['name'] if d.get('plugins') else '')
" 2>/dev/null)

  if [[ -z "$FIRST_PACK" ]]; then
    fail "AC-5: no plugin in the marketplace to install"
  elif ! claude plugin marketplace add "$PROJECT_ROOT" >"$SB/add.log" 2>&1; then
    fail "AC-5: 'claude plugin marketplace add' rejected our generated manifest — $(tail -2 "$SB/add.log" | tr '\n' ' ')"
  else
    MKT_NAME=$(python3 -c "import json;print(json.load(open('$MARKET'))['name'])")
    if ! claude plugin install "${FIRST_PACK}@${MKT_NAME}" >"$SB/install.log" 2>&1; then
      fail "AC-5: install failed for ${FIRST_PACK}@${MKT_NAME} — $(tail -2 "$SB/install.log" | tr '\n' ' ')"
    elif claude plugin list 2>/dev/null | grep -q "$FIRST_PACK"; then
      pass "AC-5: ${FIRST_PACK}@${MKT_NAME} installed and appears in the installed list"
    else
      fail "AC-5: install exited 0 but ${FIRST_PACK} is not in 'claude plugin list' — exit code alone asserted nothing"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# AC-6 — every measured arm is listed or explicitly excluded.
#
# The arm list is DERIVED from the corpus at runtime. A hard-coded list is how a
# future measured pack silently vanishes from the catalogue.
# ---------------------------------------------------------------------------
JOIN=$(node --input-type=module -e "
  import { loadAcceptanceRecords } from './packages/data/dist/index.js';
  import { entries, excludedArms } from './packages/registry/dist/index.js';
  const arms = new Set(loadAcceptanceRecords({ dir: 'bench/data/runs' }).cells.map(c => c.arm));
  arms.delete('baseline');
  const listed = new Set(entries.map(e => e.packId));
  const excluded = new Set(Object.keys(excludedArms));
  const orphans = [...arms].filter(a => !listed.has(a) && !excluded.has(a));
  const unexplained = [...excluded].filter(a => !excludedArms[a]);
  console.log(JSON.stringify({ arms: arms.size, orphans, unexplained }));
" 2>/dev/null)

if [[ -z "$JOIN" ]]; then
  fail "AC-6: could not join the registry against @plugdex/data (packages not built?)"
else
  ORPHANS=$(echo "$JOIN" | sed 's/.*"orphans":\[\([^]]*\)\].*/\1/')
  UNEXPLAINED=$(echo "$JOIN" | sed 's/.*"unexplained":\[\([^]]*\)\].*/\1/')
  if [[ -n "$ORPHANS" ]]; then
    fail "AC-6: measured arms neither listed nor excluded: $ORPHANS"
  elif [[ -n "$UNEXPLAINED" ]]; then
    fail "AC-6: arms excluded with no stated reason: $UNEXPLAINED"
  else
    pass "AC-6: every measured arm is listed or excluded with a reason"
  fi
fi

# ---------------------------------------------------------------------------
# AC-7 — verify runs SRC-01, and the golden set is unregressed.
# ---------------------------------------------------------------------------
if ./scripts/verify.sh 2>&1 | grep -qi "SRC-01"; then
  pass "AC-7: verify.sh runs the SRC-01 gate"
else
  fail "AC-7: verify.sh does not run SRC-01 — the rule is not enforced by the gate stack"
fi

# ---------------------------------------------------------------------------
# Attribution — the assertion that makes SRC-01 more than paperwork.
#
# A pack's listed author must be the one its own manifest declares. The pack commonly
# called "Karpathy's skills" declares someone else; listing it under the famous name
# would be misattribution on the front page of a provenance site.
# ---------------------------------------------------------------------------
MISMATCH=$(node --input-type=module -e "
  import { entries } from './packages/registry/dist/index.js';
  import { readFileSync, existsSync } from 'node:fs';
  const bad = [];
  for (const e of entries) {
    if (e.author.from !== 'upstream') continue;
    const path = \`packages/registry/attribution/\${e.packId}/plugin.json\`;
    if (!existsSync(path)) { bad.push(\`\${e.packId}: claims upstream author with no recorded manifest\`); continue; }
    const m = JSON.parse(readFileSync(path, 'utf8'));
    const declared = typeof m.author === 'string' ? m.author : m.author?.name;
    if (declared !== e.author.value) bad.push(\`\${e.packId}: listed '\${e.author.value}', manifest declares '\${declared}'\`);
  }
  console.log(bad.join(' | '));
" 2>/dev/null)

if [[ -n "$MISMATCH" ]]; then
  fail "Attribution: $MISMATCH"
else
  pass "Attribution: every upstream-tagged author matches the manifest that declares it"
fi

if [[ $FAILED -ne 0 ]]; then
  echo -e "${RED}PDX-003 scenario FAILED${NC}" >&2
  exit 1
fi

echo -e "${GREEN}PDX-003 scenario PASS${NC}"
```
