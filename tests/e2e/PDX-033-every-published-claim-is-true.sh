#!/usr/bin/env bash
# tests/e2e/PDX-033-every-published-claim-is-true.sh
#
# PDX-033 — every published claim is true, in one pass.
#
# Six statements this repository publishes that its own records contradict, corrected together
# because a reader who arrives between corrections meets a half-corrected story.
#
# Two rules shape every assertion here.
#
# **A correction is a record.** CLAIM-01 keeps the previous wording, its date and its cause
# readable, so each correction is a delimited block — `<!-- withdrawal: id -->` to
# `<!-- /withdrawal: id -->` — and a withdrawn wording outside a block is a live claim. The
# delimiters decide membership: plan review round 2 found that an opening marker alone leaves
# it undefined for a multi-line block, and proximity was never going to work in Markdown.
#
# **A correction moves the claim, not the string.** The premise is published in five wordings
# across four files, and two review rounds each found one more after an exact-phrase grep had
# missed it. The sweep here matches claim shapes, and it is run against a planted control that
# must be caught before its silence is believed (ASSERT-01, ten prior instances).

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-033 — every published claim is true"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx033.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export PROJECT_ROOT SB
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"
export RUNS_DIR="$PROJECT_ROOT/bench/data/runs"
export INDEX_HTML="$PROJECT_ROOT/packages/site/dist/index.html"

cat > "$SB/verdict.py" <<'PY'
import json, sys

try:
    result = json.load(sys.stdin)
except Exception as error:
    print(f"MALFORMED {error}")
    sys.exit(0)

print(("OK " if result.get("ok") else "BAD ") + str(result.get("detail", "")))
PY

judge() {
  local capture="$1" label="$2"

  if [[ "$capture" != SENTINEL\ * ]]; then
    fail "$label: the probe did not run (no sentinel; empty or crashed)"
    return
  fi

  local verdict
  verdict="$(printf '%s' "${capture#SENTINEL }" | python3 "$SB/verdict.py" 2>/dev/null)"

  case "$verdict" in
    OK\ *) pass "$label: ${verdict#OK }" ;;
    BAD\ *) fail "$label: ${verdict#BAD }" ;;
    *) fail "$label: the probe answered in a shape this scenario cannot read" ;;
  esac
}

( cd "$PROJECT_ROOT" && pnpm --filter @plugdex/data build && pnpm --filter @plugdex/site build ) \
  > "$SB/build.log" 2>&1 \
  || echo "  (build failed; see $SB/build.log)" >&2

cat > "$SB/report.py" <<'REPORT'
import json


def verdict(problems, detail):
    return {"ok": not problems, "detail": detail if not problems else "; ".join(problems)}
REPORT

# The shared reader: which lines of a file sit inside a withdrawal block.
cat > "$SB/blocks.py" <<'BLOCKS'
import re

OPEN = re.compile(r"<!--\s*withdrawal:\s*([\w-]+)\s*-->")
CLOSE = re.compile(r"<!--\s*/withdrawal:\s*([\w-]+)\s*-->")


def inside(path):
    """Line numbers (1-based) that sit inside a delimited withdrawal block."""
    covered, open_at = set(), None

    for number, line in enumerate(open(path, encoding="utf-8").read().splitlines(), start=1):
        if OPEN.search(line):
            open_at = number
        elif CLOSE.search(line) and open_at is not None:
            covered.update(range(open_at, number + 1))
            open_at = None

    return covered
BLOCKS

# ---------------------------------------------------------------------------
# Claim 6 — the premise, in every wording it is published in.
# ---------------------------------------------------------------------------
cat > "$SB/premise.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from blocks import inside
from report import verdict

# Claim shapes, not one string. Two review rounds each found a wording the previous pattern
# missed, so the list is the claim's forms and the assertion is that none is live.
PATTERNS = [
    re.compile(r"every published benchmark", re.I),
    re.compile(r"(almost )?nobody checks whether it (builds|compiles)", re.I),
    re.compile(r"without checking that the delivered code (builds|compiles)", re.I),
    re.compile(r"measured \*\*without\*\*\s*$", re.I),
]

FILES = ["README.md", "bench/README.md", "CLAUDE.md", "DESIGN.md"]
problems, live, swept = [], [], 0

for name in FILES:
    path = os.path.join(os.environ["PROJECT_ROOT"], name)

    if not os.path.exists(path):
        problems.append(f"{name} is missing — the sweep cannot cover it")
        continue

    swept += 1
    covered = inside(path)

    for number, line in enumerate(open(path, encoding="utf-8").read().splitlines(), start=1):
        if any(p.search(line) for p in PATTERNS) and number not in covered:
            live.append(f"{name}:{number}")

if swept == 0:
    problems.append("the sweep covered no file at all")

if live:
    problems.append(f"the premise is live outside a withdrawal block at {', '.join(live)}")

print("SENTINEL " + json.dumps(verdict(
    problems, f"the premise is withdrawn in all {swept} files that carried it",
)))
PY

# Positive control first: a planted file carrying the claim must be reported.
mkdir -p "$SB/control"
printf 'Those are real measurements taken without checking that the delivered code compiles.\n' \
  > "$SB/control/README.md"

CONTROL="$(PROJECT_ROOT="$SB/control" python3 "$SB/premise.py" 2>/dev/null)"

if [[ "$CONTROL" == SENTINEL\ * ]] && \
   printf '%s' "${CONTROL#SENTINEL }" | python3 -c 'import json,sys; sys.exit(0 if not json.load(sys.stdin)["ok"] else 1)'; then
  pass "claim 6 (control): the premise sweep reports a planted paraphrase"
else
  fail "claim 6 (control): the sweep passed a planted paraphrase — it cannot be trusted below"
fi

judge "$(python3 "$SB/premise.py" 2>/dev/null)" "claim 6 (the premise, all wordings)"

# ---------------------------------------------------------------------------
# Claim 2 — the withdrawn 68/69, and that no pooling produces it.
# ---------------------------------------------------------------------------
cat > "$SB/sixtyeight.mjs" <<'JS'
import { readFileSync } from 'node:fs';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';

const problems = [];
const design = readFileSync(join(process.env.PROJECT_ROOT, 'DESIGN.md'), 'utf8').split('\n');

const open = /<!--\s*withdrawal:/;
const close = /<!--\s*\/withdrawal:/;
let within = false;

design.forEach((line, index) => {
  if (open.test(line)) within = true;
  else if (close.test(line)) within = false;
  else if (/68\s*(of|\/)\s*69/.test(line) && !within) {
    problems.push(`DESIGN.md:${index + 1} states 68/69 outside a withdrawal block`);
  }
});

// Re-derived rather than trusted: no pooling of the records produces 68 of 69.
const rows = [];
for (const file of readdirSync(process.env.RUNS_DIR).filter((f) => f.endsWith('.acceptance.json'))) {
  const record = JSON.parse(readFileSync(join(process.env.RUNS_DIR, file), 'utf8'));
  for (const cell of record.cells ?? []) rows.push({ ...cell, regime: record.regime, withdrawn: !!record.withdrawn });
}

if (rows.length === 0) problems.push('no acceptance rows loaded — the derivation would prove nothing');

const pools = [
  rows,
  rows.filter((r) => !r.withdrawn),
  rows.filter((r) => !r.withdrawn && r.regime === 'blocked'),
  rows.filter((r) => !r.withdrawn && r.regime === 'as-shipped'),
];

for (const pool of pools) {
  const valid = pool.filter((r) => r.valid !== false);
  const silent = valid.filter((r) => !r.wrote_code).length;
  if (silent === 68 && valid.length === 69) {
    problems.push('a pooling DOES produce 68 of 69 — the withdrawal is wrong');
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.length ? problems.join('; ')
    : `68/69 appears only inside a withdrawal block, and none of ${pools.length} poolings produces it`,
}));
JS

judge "$(node "$SB/sixtyeight.mjs" 2>/dev/null)" "claim 2 (the withdrawn 68/69)"

# ---------------------------------------------------------------------------
# Claim 3 — the spec and the code name the same regime.
# ---------------------------------------------------------------------------
SPEC_REGIME="$(grep -oE 'under the (blocked|as-shipped) regime' "$PROJECT_ROOT/DESIGN.md" | head -1 | awk '{print $3}')"
CODE_REGIME="$(grep -oE "REGIME = '(blocked|as-shipped)'" "$PROJECT_ROOT/packages/site/src/pages/index.astro" | head -1 | sed "s/.*'\(.*\)'/\1/")"

if [[ -z "$SPEC_REGIME" ]]; then
  fail "claim 3: no regime named in the priority-1 row — the sweep read nothing"
elif [[ -z "$CODE_REGIME" ]]; then
  fail "claim 3: no REGIME in index.astro — the sweep read nothing"
elif [[ "$SPEC_REGIME" != "$CODE_REGIME" ]]; then
  fail "claim 3: the spec says '$SPEC_REGIME' and the page publishes '$CODE_REGIME'"
else
  pass "claim 3: spec and page agree on '$CODE_REGIME', both read from their own source"
fi

# ---------------------------------------------------------------------------
# Claim 5 — the probe counts under the gate we actually ship, re-derived.
#
# The first version of this row was `grep -qE '(three|3) of eight'`, and it passed a sentence
# that put the CAUGHT count where the PASSED count goes — understating how much slips through,
# in the direction that flatters the gate. A string match cannot tell a number from the number
# beside it, so both counts come from the probe records now.
# ---------------------------------------------------------------------------
cat > "$SB/probes.py" <<'PROBES'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from report import verdict

root = os.environ["PROJECT_ROOT"]
acceptance = os.path.join(root, "bench/harness/acceptance.py")
gate_probes = os.path.join(root, "bench/harness/gate_probes.py")
problems = []

for path in (acceptance, gate_probes):
    if not os.path.exists(path):
        print("SENTINEL " + json.dumps({"ok": False, "detail": f"{path} is missing"}))
        sys.exit(0)

# Positive control for an absence claim: the pattern must find pytest where pytest is.
if "pytest" not in open(gate_probes, encoding="utf-8").read():
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": "the pattern found no pytest in gate_probes.py, where it exists — its silence proves nothing",
    }))
    sys.exit(0)

runs_pytest = "pytest" in open(acceptance, encoding="utf-8").read()

limits = json.load(open(os.path.join(root, "bench/data/gate-limits.json"), encoding="utf-8"))
probes = limits.get("probes")

if not isinstance(probes, list) or not probes:
    print("SENTINEL " + json.dumps({"ok": False, "detail": "gate-limits.json lists no probes"}))
    sys.exit(0)

SHIPPED = {"mypy", "ruff", "import", "typecheck", "build"}
caught = [p for p in probes if set(p.get("caught_by") or []) & SHIPPED]
passed = [p for p in probes if not (set(p.get("caught_by") or []) & SHIPPED)]

WORDS = {0: "zero", 1: "one", 2: "two", 3: "three", 4: "four",
         5: "five", 6: "six", 7: "seven", 8: "eight"}

text = open(os.path.join(root, "bench/README.md"), encoding="utf-8").read()
claim = re.search(r"\*\*(\w+) of (\w+)\*\* injected defects pass every gate", text)

if runs_pytest:
    problems.append("acceptance.py now runs pytest — this correction's premise no longer holds")

if claim is None:
    problems.append("bench/README.md states no passed-count for the shipped gate set")
else:
    want = WORDS.get(len(passed), str(len(passed)))
    if claim.group(1).lower() != want:
        problems.append(
            f"published passed-count '{claim.group(1)}' but the records give {want} "
            f"({len(passed)}); caught is {len(caught)}, and the two are not the same number"
        )
    if claim.group(2).lower() != WORDS.get(len(probes), str(len(probes))):
        problems.append(f"published denominator '{claim.group(2)}' but there are {len(probes)} probes")

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"acceptance.py runs no pytest; {len(caught)} of {len(probes)} caught and {len(passed)} pass "
    f"under the shipped gate set, and the published sentence states the passed count",
)))
PROBES

judge "$(python3 "$SB/probes.py" 2>/dev/null)" "claim 5 (the probe counts, re-derived)"

# ---------------------------------------------------------------------------
# AC-6 — no bare skill count ships without a citation.
# ---------------------------------------------------------------------------
# The exclusion list is narrow on purpose. The first version dropped any line containing a
# backtick, and AC-6's own mandated sentence names `simplify` and `code-review` — so the guard
# could never fire on the subject it was written for. Report review round 1 demonstrated that
# "The runner blocks 12 built-in skills … including `simplify`" passed it. Words are matched
# too, because "twelve" is a count.
SKILL_LINES="$(grep -rniE '(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+) +built-in skill' \
  "$PROJECT_ROOT/bench/README.md" "$PROJECT_ROOT/README.md" "$PROJECT_ROOT/DESIGN.md" 2>/dev/null || true)"

# A count may ship only with a source on the same line: a path, a file reference, or an
# explicit statement that it is unrecorded.
BARE="$(printf '%s' "$SKILL_LINES" | grep -viE 'unrecorded|unsourced|bench/|harness|run\.py|source:' || true)"

# Positive control: the guard must catch a planted sentence of exactly the shape AC-6 mandates.
printf 'The runner blocks 12 built-in skills for every arm, including `simplify`.\n' > "$SB/skills-control.md"

if ! grep -rniE '(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+) +built-in skill' \
     "$SB/skills-control.md" | grep -viE 'unrecorded|unsourced|bench/|harness|run\.py|source:' >/dev/null; then
  fail "AC-6 (control): the guard missed a planted bare count in AC-6's own sentence shape"
elif [[ -n "${BARE//[[:space:]]/}" ]]; then
  fail "AC-6: a bare built-in-skill count ships without a source: $(printf '%s' "$BARE" | head -1 | cut -c1-130)"
else
  pass "AC-6: the guard catches a planted bare count, and none ships without a source"
fi

# ---------------------------------------------------------------------------
# AC-7 — PREREGISTRATION-3 reports its outcome, and the figure re-derives.
# ---------------------------------------------------------------------------
PREREG3="$PROJECT_ROOT/bench/PREREGISTRATION-3.md"

if [[ ! -f "$PREREG3" ]]; then
  fail "AC-7: bench/PREREGISTRATION-3.md is missing"
elif ! grep -q '^## Outcome' "$PREREG3"; then
  fail "AC-7: PREREGISTRATION-3 has no Outcome section, while PREREGISTRATION.md:127 commits that failed predictions are reported as failed"
elif ! grep -qi 'failed' "$PREREG3"; then
  fail "AC-7: PREREGISTRATION-3 has an Outcome section that does not say its prediction failed"
else
  pass "AC-7: PREREGISTRATION-3 reports its outcome and names the failure"
fi

# ---------------------------------------------------------------------------
# AC-10 — the superseded tickets say so.
# ---------------------------------------------------------------------------
MISSING=""
for t in PDX-030 PDX-032; do
  f="$(ls "$PROJECT_ROOT/.docs/tickets/${t}"_*.md 2>/dev/null | head -1)"
  if [[ -z "$f" ]]; then
    MISSING="$MISSING ${t}(absent)"
  elif ! grep -qi 'superseded' "$f"; then
    MISSING="$MISSING ${t}"
  fi
done

if [[ -n "$MISSING" ]]; then
  fail "AC-10: superseded ticket(s) carry no marker:$MISSING"
else
  pass "AC-10: every ticket this one supersedes says so"
fi

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-033 PASS${NC}"
else
  echo -e "${RED}PDX-033 FAIL${NC}" >&2
fi

exit $FAILED
