#!/usr/bin/env bash
# tests/e2e/PDX-016-the-corpus-agrees-with-itself.sh
#
# PDX-016 — withdrawn runs are a record, not a filename.
#
# The load-bearing assertion is AC-3: both implementations of the record universe — the
# TypeScript loader that feeds the site and the Python harness that computed every
# published figure — are run over the live corpus and their counts compared. Before this
# ticket they disagree by the withdrawn run, because `fisher.py` skips it on a filename
# prefix and `@plugdex/data` skips nothing at all. This scenario is what proves the
# disagreement ended, rather than a report asserting that it did.
#
# The comparison is done twice over and the two are never crossed: `fisher.py`'s own
# corpus line counts every cell, while the published tables count valid cells only. A
# scenario that compared one against the other would fail on a healthy tree — or worse,
# pass on a sick one.
#
# ASSERT-01 throughout. On the untouched tree every probe below exits non-zero with its
# diagnostics on a stderr this scenario discards, and every variable they fill is the
# empty string. An assertion phrased as "no differences found" would therefore report a
# pass in exactly the state it exists to reject. So every probe prints `SENTINEL {json}`
# on its success path, every assertion requires a sentinel-prefixed capture before reading
# it, and every count carries a floor. Each probe also decides its own verdict and returns
# a `problems` list, so no JSON is passed back through the shell to be re-parsed.
#
# Nothing is published and nothing outside the repository is contacted (CR-01). Synthetic
# corpora are planted under a scratch directory; the live corpus is only ever read.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-016 — the corpus agrees with itself"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx016.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export RUNS="bench/data/runs"
export WITHDRAWN_RUN_ID="20260815-225842"
export SB

# Every probe answers in one shape: `SENTINEL {"ok": bool, "detail": str}`. A capture that
# is empty or not sentinel-prefixed means the probe did not run, which is a failure and
# never a silent pass. `judge <capture> <ac-label>` is the only thing that reports.
judge() {
  local capture="$1" label="$2"

  if [[ "$capture" != SENTINEL\ * ]]; then
    fail "$label: the probe did not run (no sentinel; empty or crashed)"
    return
  fi

  local verdict
  verdict=$(printf '%s' "${capture#SENTINEL }" | python3 -c '
import json, sys
try:
    result = json.load(sys.stdin)
except Exception as error:
    print(f"MALFORMED {error}")
    sys.exit(0)
print(("OK " if result.get("ok") else "BAD ") + str(result.get("detail", "")))
' 2>/dev/null)

  case "$verdict" in
    OK\ *) pass "$label: ${verdict#OK }" ;;
    BAD\ *) fail "$label: ${verdict#BAD }" ;;
    *) fail "$label: the probe answered in a shape this scenario cannot read" ;;
  esac
}

# ---------------------------------------------------------------------------
# AC-1 — the withdrawal is a field on the record, carrying why it was withdrawn.
#
# Read off the records themselves. RED today: no record carries the field, so `marked` is
# empty and the floor rejects it rather than reporting "nothing wrong".
# ---------------------------------------------------------------------------
judge "$(python3 - <<'PY' 2>/dev/null
import json, os, pathlib

runs = pathlib.Path(os.environ["RUNS"])
target = os.environ["WITHDRAWN_RUN_ID"]
marked, problems = {}, []

for path in sorted(runs.glob("*.acceptance.json")):
    record = json.loads(path.read_text(encoding="utf-8"))
    withdrawal = record.get("withdrawn")

    if withdrawal is None:
        continue

    marked[record["run"]] = withdrawal

if not marked:
    problems.append("no acceptance record carries a withdrawal field")
elif target not in marked:
    problems.append(f"{target} is not marked withdrawn in its own record")
else:
    withdrawal = marked[target]
    reason = str(withdrawal.get("reason", "")).strip()

    if not reason:
        problems.append(f"{target}: the withdrawal states no reason")
    elif "16" not in reason:
        problems.append(f"{target}: the reason does not name instrument failure 16")

    if not str(withdrawal.get("recorded_at", "")).strip():
        problems.append(f"{target}: the withdrawal has no recorded_at")

print("SENTINEL " + json.dumps({
    "ok": not problems,
    "detail": "; ".join(problems) or
              f"{len(marked)} record-flagged withdrawal(s), {target} among them, reason names instrument failure 16",
}))
PY
)" "AC-1"

# The same fact through the built package — what a consumer reads, not what the JSON holds.
#
# Node probes are written to the sandbox rather than passed with `-e`: a probe long enough
# to decide its own verdict does not survive being nested inside a command substitution,
# and a probe mangled by quoting fails in a way that looks like a failing assertion. The
# package is imported through an absolute URL handed over in the environment, so the probe
# does not depend on where it happens to sit.
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"

cat > "$SB/ac1-package.mjs" <<'JS'
const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

const target = process.env.WITHDRAWN_RUN_ID;
const corpus = loadAcceptanceRecords({ dir: process.env.RUNS });
const marked = corpus.withdrawnRecords.filter((record) => record.run === target);
const reason = marked[0]?.withdrawn?.reason ?? '';

const problems = [];

if (corpus.withdrawnRecords.length < 1) problems.push('withdrawnRecords is empty');
if (marked.length !== 1) problems.push(`${target} appears ${marked.length} times in withdrawnRecords`);
if (!reason.trim()) problems.push(`${target}: the parsed withdrawal carries no reason`);

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') || `the built package exposes ${target} in withdrawnRecords with its reason`,
}));
JS

judge "$(node "$SB/ac1-package.mjs" 2>/dev/null)" "AC-1 (package)"
