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
# The comparison is done twice over and the two are never crossed: the corpus line in
# `fisher.py` counts every cell, while the published tables count valid cells only. A
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
# Every probe is written to the sandbox and run from there — never inlined with `-e` or a
# heredoc inside `$(...)`. A probe long enough to decide its own verdict does not survive
# being nested in a command substitution: bash re-lexes the substitution body, so a stray
# apostrophe, a backtick, or a parenthesis inside a quoted Python string silently eats an
# argument, and the assertion then reports against the wrong label. That was observed on
# this file before the probes were moved out.
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

export PROJECT_ROOT
export RUNS="bench/data/runs"
export WITHDRAWN_RUN_ID="20260815-225842"
export SB
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"

cat > "$SB/verdict.py" <<'PY'
"""Reads one probe answer on stdin and prints the verdict the shell reports."""
import json, sys

try:
    result = json.load(sys.stdin)
except Exception as error:
    print(f"MALFORMED {error}")
    sys.exit(0)

print(("OK " if result.get("ok") else "BAD ") + str(result.get("detail", "")))
PY

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
  verdict="$(printf '%s' "${capture#SENTINEL }" | python3 "$SB/verdict.py" 2>/dev/null)"

  case "$verdict" in
    OK\ *) pass "$label: ${verdict#OK }" ;;
    BAD\ *) fail "$label: ${verdict#BAD }" ;;
    *) fail "$label: the probe answered in a shape this scenario cannot read" ;;
  esac
}

# Writes a synthetic acceptance corpus from a spec, so the loaders are exercised on a
# corpus this scenario chose rather than on the one under measurement.
cat > "$SB/plant.py" <<'PY'
import json, os, sys

target, spec = sys.argv[1], json.loads(sys.argv[2])
os.makedirs(target, exist_ok=True)

for entry in spec:
    run = entry["run"]
    record = {
        "run": run,
        "env": {
            "npm_fingerprint": entry.get("fingerprint", "synthetic00000000"),
            "npm_undeclared_toplevel": 0,
            "npm_packages": 1,
            "npm_installed": [],
            "npm_extraneous": [],
        },
        "cells": [
            {
                "cell": f"{run}__t{index}",
                "task": f"t{index}",
                "arm": entry.get("arm", "baseline"),
                "model": "haiku",
                "rep": index,
                "valid": True,
                "build": index % 2 == 0,
            }
            for index in range(entry.get("cells", 2))
        ],
    }

    if "withdrawn" in entry:
        record["withdrawn"] = entry["withdrawn"]
    elif entry.get("null_withdrawal"):
        record["withdrawn"] = None

    with open(os.path.join(target, f"{run}.acceptance.json"), "w", encoding="utf-8") as handle:
        json.dump(record, handle)
PY

REASONED='{"reason": "planted by the PDX-016 scenario", "recorded_at": "2026-08-17T00:00:00+09:00"}'

# ---------------------------------------------------------------------------
# AC-1 — the withdrawal is a field on the record, carrying why it was withdrawn.
#
# Read off the records themselves. RED today: no record carries the field, so `marked` is
# empty and the floor rejects it rather than reporting "nothing wrong".
# ---------------------------------------------------------------------------
cat > "$SB/ac1.py" <<'PY'
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

flagged = [run for run in marked if run.startswith(target)]

if not marked:
    problems.append("no acceptance record carries a withdrawal field")
elif not flagged:
    problems.append(f"{target} is not marked withdrawn in its own record")
else:
    withdrawal = marked[flagged[0]]
    reason = str(withdrawal.get("reason", "")).strip()

    if not reason:
        problems.append(f"{target}: the withdrawal states no reason")
    elif "16" not in reason:
        problems.append(f"{target}: the reason does not name instrument failure 16")

    if not str(withdrawal.get("recorded_at", "")).strip():
        problems.append(f"{target}: the withdrawal has no recorded_at")

detail = (
    f"{len(marked)} record-flagged withdrawal(s), {target} among them, "
    "reason names instrument failure 16"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac1.py" 2>/dev/null)" "AC-1"

# The same fact through the built package — what a consumer reads, not what the JSON holds.
cat > "$SB/ac1-package.mjs" <<'JS'
const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

const target = process.env.WITHDRAWN_RUN_ID;
const corpus = loadAcceptanceRecords({ dir: process.env.RUNS });
const listed = corpus.withdrawnRecords ?? [];
const marked = listed.filter((record) => record.run.startsWith(target));
const reason = marked[0]?.withdrawn?.reason ?? '';

const problems = [];

if (listed.length < 1) problems.push('withdrawnRecords is empty');
if (marked.length !== 1) problems.push(`${target} appears ${marked.length} times in withdrawnRecords`);
if (!reason.trim()) problems.push(`${target}: the parsed withdrawal carries no reason`);

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') || `the built package exposes ${target} in withdrawnRecords with its reason`,
}));
JS

judge "$(node "$SB/ac1-package.mjs" 2>/dev/null)" "AC-1 (package)"

# ---------------------------------------------------------------------------
# AC-2 — the loader partitions on the field, over a corpus this scenario controls.
#
# The live corpus holds exactly one withdrawn run, so an assertion written against it
# could not tell "the loader excludes withdrawn records" from "the loader excludes that
# one file". Everything below is planted in a scratch directory instead, so the property
# is tested rather than the fixture.
# ---------------------------------------------------------------------------
python3 "$SB/plant.py" "$SB/good-runs" "[
  {\"run\": \"20200101-000000-kept\", \"cells\": 3, \"arm\": \"baseline\"},
  {\"run\": \"20200102-000000-also-kept\", \"cells\": 2, \"arm\": \"ponytail\"},
  {\"run\": \"20200103-000000-pulled\", \"cells\": 4, \"arm\": \"ponytail\", \"withdrawn\": $REASONED}
]" 2>/dev/null

python3 "$SB/plant.py" "$SB/unreasoned-runs" '[
  {"run": "20200101-000000-kept", "cells": 2},
  {"run": "20200104-000000-pulled-silently", "cells": 2, "withdrawn": {"recorded_at": "2026-08-17T00:00:00+09:00"}}
]' 2>/dev/null

cat > "$SB/ac2.mjs" <<'JS'
const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

const sandbox = process.env.SB;
const pulled = '20200103-000000-pulled';
const problems = [];

const runsOf = (corpus) => corpus.records.map((record) => record.run).sort();

let defaultView;
let pooledView;

try {
  defaultView = loadAcceptanceRecords({ dir: `${sandbox}/good-runs` });
  pooledView = loadAcceptanceRecords({ dir: `${sandbox}/good-runs`, includeWithdrawn: true });
} catch (error) {
  console.log('SENTINEL ' + JSON.stringify({
    ok: false,
    detail: `the loader threw on a well-formed synthetic corpus: ${String(error)}`,
  }));
  process.exit(0);
}

// The default view holds the two kept runs and nothing else; the pooled view holds all
// three. Both are asserted on the run names, not on a count, so a loader that dropped the
// wrong record could not pass by keeping the arithmetic right.
const wantDefault = ['20200101-000000-kept', '20200102-000000-also-kept'];
const wantPooled = [...wantDefault, pulled].sort();

if (JSON.stringify(runsOf(defaultView)) !== JSON.stringify(wantDefault)) {
  problems.push(`default view holds [${runsOf(defaultView).join(', ')}], wanted [${wantDefault.join(', ')}]`);
}

if (JSON.stringify(runsOf(pooledView)) !== JSON.stringify(wantPooled)) {
  problems.push(`pooled view holds [${runsOf(pooledView).join(', ')}], wanted [${wantPooled.join(', ')}]`);
}

if (defaultView.cells.length !== 5) problems.push(`default view has ${defaultView.cells.length} cells, wanted 5`);
if (pooledView.cells.length !== 9) problems.push(`pooled view has ${pooledView.cells.length} cells, wanted 9`);

// `withdrawnRecords` is the same answer in both views: what was pulled is a property of
// the corpus, not of which view a caller asked for.
for (const [name, view] of [['default', defaultView], ['pooled', pooledView]]) {
  const listed = (view.withdrawnRecords ?? []).map((record) => record.run);

  if (listed.length !== 1 || listed[0] !== pulled) {
    problems.push(`${name} view lists withdrawnRecords [${listed.join(', ')}], wanted [${pulled}]`);
  }

  const reason = view.withdrawnRecords?.[0]?.withdrawn?.reason ?? '';

  if (!reason.trim()) problems.push(`${name} view: the listed withdrawal carries no reason`);
}

// A withdrawal with no reason is a deletion wearing a field. The loader refuses it, and
// the refusal is asserted on the name of the error, so a future reword of the message
// cannot silently turn this into a pass.
let refusal = 'nothing thrown';

try {
  loadAcceptanceRecords({ dir: `${sandbox}/unreasoned-runs` });
} catch (error) {
  refusal = error?.name ?? String(error);
}

if (refusal !== 'UnreasonedWithdrawalError') {
  problems.push(`an unreasoned withdrawal produced '${refusal}', wanted UnreasonedWithdrawalError`);
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') ||
    'synthetic corpus: default 5 cells / 2 runs, pooled 9 / 3, withdrawnRecords stable across both views, unreasoned withdrawal refused',
}));
JS

judge "$(node "$SB/ac2.mjs" 2>/dev/null)" "AC-2"

# ---------------------------------------------------------------------------
# AC-3 — the two implementations of the record universe agree.
#
# This is the assertion the ticket exists for. Both are run over the live corpus, in both
# views, and compared view against matching view. The two views are never crossed: today
# TS-default equals Python-pooled, which is exactly the disagreement being ended, and a
# scenario that compared the all-cells line against the valid-cells line would fail on a
# healthy tree instead.
# ---------------------------------------------------------------------------
cat > "$SB/ac3-ts.mjs" <<'JS'
const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

const dir = process.env.RUNS;

// `rate_table` skips a cell whose outcome is None, which in Python covers both a missing
// key and an explicit null. The corpus carries no null `build` today, so keying on
// "absent" alone would coincide — and would then split the two probes on the first record
// that wrote one, inside the very comparison meant to prove them equal.
const summarise = (corpus) => {
  const arms = {};

  for (const cell of corpus.cells) {
    if (cell.build === undefined || cell.build === null) continue;

    const [hits, n] = arms[cell.arm] ?? [0, 0];
    arms[cell.arm] = [hits + (cell.build === true ? 1 : 0), n + 1];
  }

  return {
    cells: corpus.cells.length,
    valid: corpus.cells.filter((cell) => cell.valid === true).length,
    arms,
  };
};

const corpus = process.argv[2] === 'pooled'
  ? loadAcceptanceRecords({ dir, includeWithdrawn: true })
  : loadAcceptanceRecords({ dir });

console.log('SENTINEL ' + JSON.stringify(summarise(corpus)));
JS

cat > "$SB/ac3-py.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.path.join(os.environ["PROJECT_ROOT"], "bench", "harness"))
from fisher import load_cells, rate_table

cells = load_cells(include_withdrawn=True) if sys.argv[1] == "pooled" else load_cells()

print("SENTINEL " + json.dumps({
    "cells": len(cells),
    "valid": sum(1 for cell in cells if cell.get("valid") is True),
    "arms": {arm: list(pair) for arm, pair in rate_table(cells, "build").items()},
}))
PY

TS_DEFAULT="$(node "$SB/ac3-ts.mjs" default 2>/dev/null)"
TS_POOLED="$(node "$SB/ac3-ts.mjs" pooled 2>/dev/null)"
PY_DEFAULT="$(python3 "$SB/ac3-py.py" default 2>/dev/null)"
PY_POOLED="$(python3 "$SB/ac3-py.py" pooled 2>/dev/null)"
export TS_DEFAULT TS_POOLED PY_DEFAULT PY_POOLED

# The comparison is itself a probe, so a capture that never arrived is reported as "the
# probe did not run" rather than silently comparing two empty strings and agreeing.
cat > "$SB/ac3-compare.py" <<'PY'
import json, os, pathlib

problems = []
views = {}

for name in ("TS_DEFAULT", "TS_POOLED", "PY_DEFAULT", "PY_POOLED"):
    capture = os.environ.get(name, "")

    if not capture.startswith("SENTINEL "):
        problems.append(f"{name}: the probe did not run (empty or crashed)")
        continue

    try:
        views[name] = json.loads(capture[len("SENTINEL "):])
    except Exception as error:
        problems.append(f"{name}: unreadable answer ({error})")

detail = ""

if len(views) == 4:
    # Canonicalized before comparing: the two languages serialize the same object in
    # different key order, so a raw string compare would fail on a healthy tree.
    canon = {name: json.dumps(value, sort_keys=True) for name, value in views.items()}

    for view in ("DEFAULT", "POOLED"):
        left, right = canon["TS_" + view], canon["PY_" + view]

        if left != right:
            problems.append(
                f"{view.lower()} view disagrees — TypeScript {left} vs Python {right}"
            )

    default, pooled = views["PY_DEFAULT"], views["PY_POOLED"]
    arms = len(default["arms"])

    # Floors. Every one of these is a state in which the comparison above would agree
    # while proving nothing: an empty corpus, a field that was never written, or both
    # sides pooling together.
    if default["cells"] < 1:
        problems.append("the default view is empty — a comparison of two nothings is not agreement")

    if default["valid"] < 1:
        problems.append("the default view holds no valid cell")

    if arms < 2:
        problems.append(f"the default view has {arms} arm(s); baseline plus one pack is the floor")

    runs = pathlib.Path(os.environ["PROJECT_ROOT"], os.environ["RUNS"])
    withdrawn_cells = 0
    withdrawn_count = 0

    for path in sorted(runs.glob("*.acceptance.json")):
        record = json.loads(path.read_text(encoding="utf-8"))

        # Read off the field the record itself carries. Deriving this from a filename
        # would make the scenario agree with the defect it exists to catch.
        if record.get("withdrawn") is None:
            continue

        withdrawn_count += 1
        withdrawn_cells += len(record["cells"])

    if withdrawn_count < 1:
        problems.append("no record carries a withdrawal field, so both views are the same view")

    gap = pooled["cells"] - default["cells"]

    if gap < 1:
        problems.append(f"pooled exceeds default by {gap} cells — the two views did not separate")
    elif gap != withdrawn_cells:
        problems.append(
            f"pooled exceeds default by {gap} cells, but the record-flagged withdrawals hold "
            f"{withdrawn_cells} — the loaders are not partitioning on the same fact"
        )

    detail = (
        f"default {default['cells']} cells / {default['valid']} valid / {arms} arms, "
        f"pooled {pooled['cells']} / {pooled['valid']}, "
        f"both implementations identical in both views; the {gap}-cell gap is the "
        f"{withdrawn_count} record-flagged withdrawal(s)"
    )

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac3-compare.py" 2>/dev/null)" "AC-3"

# ---------------------------------------------------------------------------
# AC-3 (published anchors) — the new Python still reproduces the published figures.
#
# The comparison above proves the two implementations agree with each other; it does not
# prove they agree with what is already published. These two anchors close that loop.
# A moved figure here means a derivation must be corrected in place under CLAIM-01 before
# this assertion is touched — the assertion is not the thing that is wrong.
# ---------------------------------------------------------------------------
cat > "$SB/ac3-anchors.py" <<'PY'
import json, os, subprocess

root = os.environ["PROJECT_ROOT"]
problems = []

# The reproduce block of D-002, verbatim from bench/DERIVATIONS.md.
d002_source = "\n".join([
    'import sys; sys.path.insert(0, "bench/harness")',
    "from fisher import load_cells",
    'sp = [c for c in load_cells() if c["arm"] == "superpowers" and c.get("valid")]',
    'print(sum(1 for c in sp if not c.get("wrote_code")), "of", len(sp))',
])

d002 = subprocess.run(
    ["python3", "-c", d002_source], capture_output=True, text=True, cwd=root
)
printed = d002.stdout.strip()

if not printed:
    problems.append("D-002: the reproduce command printed nothing")
elif printed != "49 of 50":
    problems.append(
        f"D-002: the reproduce command now prints {printed}, published as 49 of 50 — "
        "correct bench/DERIVATIONS.md D-002 in place (CLAIM-01) before touching this assertion"
    )

d001 = subprocess.run(
    ["python3", os.path.join("bench", "harness", "derive_d001.py")],
    capture_output=True, text=True, cwd=root,
)

if not d001.stdout.strip():
    problems.append("D-001: derive_d001.py printed nothing")
else:
    excluded = d001.stdout.split("withdrawn run INCLUDED")[0]

    for needle in ("p = 0.0352", "12/34"):
        if needle not in excluded:
            problems.append(
                f"D-001: {needle} is gone from the excluded-pool block — "
                "correct bench/DERIVATIONS.md D-001 in place (CLAIM-01) before touching this assertion"
            )

detail = (
    "D-002 still prints 49 of 50; the excluded pool of D-001 still shows "
    "baseline 12/34 and ponytail p = 0.0352"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac3-anchors.py" 2>/dev/null)" "AC-3 (published anchors)"

# ---------------------------------------------------------------------------
# AC-4 — the Python side reads the field too, and no filename decides inclusion.
#
# The grep is necessary and not sufficient: a constant can be renamed while the same
# comparison survives. So the probe also plants a decoy corpus whose filenames say the
# opposite of what its records say, and requires the loader to believe the records.
# ---------------------------------------------------------------------------
python3 "$SB/plant.py" "$SB/decoy-runs" "[
  {\"run\": \"20260815-225842-decoy-named-like-the-withdrawn-run\", \"cells\": 3},
  {\"run\": \"20200105-000000-innocent-name-but-pulled\", \"cells\": 2, \"withdrawn\": $REASONED}
]" 2>/dev/null

python3 "$SB/plant.py" "$SB/null-runs" '[
  {"run": "20200106-000000-explicitly-null", "cells": 2, "null_withdrawal": true}
]' 2>/dev/null

cat > "$SB/ac4.py" <<'PY'
import json, os, subprocess, sys

root, sandbox = os.environ["PROJECT_ROOT"], os.environ["SB"]
problems = []

# The inclusion of a live record must not be decided by a filename comparison anywhere
# under bench/harness/. derive_d001.py is exempt by name: its selections read a frozen
# corpus through `git show 63735e6:`, whose records can never carry the field.
grep = subprocess.run(
    ["grep", "-rn", "WITHDRAWN_RUN", os.path.join(root, "bench", "harness")],
    capture_output=True, text=True,
)
survivors = [line for line in grep.stdout.splitlines() if "derive_d001.py" not in line]

if survivors:
    problems.append(f"a filename constant survives: {survivors[0].strip()}")

sys.path.insert(0, os.path.join(root, "bench", "harness"))
from fisher import load_cells

decoy = os.path.join(sandbox, "decoy-runs")

# The filenames and the records disagree on purpose. A loader that reads names keeps the
# wrong three cells and drops the wrong two, and every number below moves.
default = load_cells(runs_dir=decoy)
pooled = load_cells(include_withdrawn=True, runs_dir=decoy)
default_runs = sorted({cell["_run"] for cell in default})
pooled_runs = sorted({cell["_run"] for cell in pooled})

if default_runs != ["20260815-225842-decoy-named-like-the-withdrawn-run"]:
    problems.append(
        f"the default pool holds {default_runs} — a record is being selected by its "
        "filename, not by its withdrawal field"
    )

if len(default) != 3:
    problems.append(f"the default pool holds {len(default)} cells, wanted 3")

if len(pooled) != 5 or len(pooled_runs) != 2:
    problems.append(
        f"include_withdrawn=True pooled {len(pooled)} cells across {len(pooled_runs)} run(s), "
        "wanted 5 across 2"
    )

# An explicit `"withdrawn": null` is where the two loaders would part company without
# anybody noticing: `.get()` reads it as absent, the TypeScript parser refuses it. Both
# must refuse, or a malformed withdrawal means one thing on one side of the project and
# another on the other.
null_corpus = os.path.join(sandbox, "null-runs")
refusal = "nothing raised"

try:
    load_cells(runs_dir=null_corpus)
except ValueError as error:
    refusal = "ValueError"
except Exception as error:
    refusal = type(error).__name__

if refusal != "ValueError":
    problems.append(
        f"an explicit null withdrawal produced {refusal} — the Python loader read it as "
        "absent while the TypeScript loader refuses it"
    )

# The self-validation is a property of this module and must still be alive after the edit.
selftest = subprocess.run(
    ["python3", os.path.join(root, "bench", "harness", "fisher.py")],
    capture_output=True, text=True, cwd=root,
)

if "textbook tables validated" not in selftest.stdout:
    problems.append("fisher.py no longer prints its textbook-table self-validation line")

detail = (
    "no filename constant survives; on a corpus whose names contradict its records the "
    "loader believes the records (3 cells default, 5 pooled); an explicit null withdrawal "
    "is refused on both sides; self-validation still runs"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac4.py" 2>/dev/null)" "AC-4"

# ---------------------------------------------------------------------------
# AC-5 — DATA-02 is a gate, and the gate is proven by planted violations.
#
# The case numbers are globbed rather than written down: a case renamed or renumbered
# would otherwise make this assertion quietly test nothing.
# ---------------------------------------------------------------------------
cat > "$SB/ac5.py" <<'PY'
import json, os, pathlib, re, subprocess

root = pathlib.Path(os.environ["PROJECT_ROOT"])
gate = root / "scripts" / "check-data-universe.sh"
problems = []

if not gate.exists():
    problems.append("scripts/check-data-universe.sh does not exist")
elif not os.access(gate, os.X_OK):
    problems.append("scripts/check-data-universe.sh is not executable")
else:
    run = subprocess.run([str(gate)], capture_output=True, text=True, cwd=root)
    output = run.stdout + run.stderr

    if not output.strip():
        problems.append("the gate printed nothing — a silent gate cannot be said to have passed")
    elif run.returncode != 0:
        problems.append(f"the gate FAILs on the live tree: {output.strip().splitlines()[-1]}")
    elif "DATA-02 PASS" not in output:
        problems.append("the gate exited 0 without printing its DATA-02 PASS line")

cases = []

for path in sorted((root / "tests" / "meta" / "cases").glob("*.sh")):
    match = re.match(r"^(\d+)-data-", path.name)

    if match:
        cases.append(match.group(1))

if len(cases) < 5:
    problems.append(f"{len(cases)} DATA-02 golden case(s) found; the plan plants five")
else:
    replay = subprocess.run(
        [str(root / "scripts" / "check-gates.sh")] + cases,
        capture_output=True, text=True, cwd=root,
    )

    if not (replay.stdout + replay.stderr).strip():
        problems.append("check-gates printed nothing when replaying the DATA-02 cases")
    elif replay.returncode != 0:
        problems.append("check-gates FAILs on cases " + " ".join(cases))

detail = (
    "the gate PASSes on the live tree and check-gates replays cases "
    + " ".join(cases) + " green"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac5.py" 2>/dev/null)" "AC-5"

# ---------------------------------------------------------------------------
# AC-6 — the corpus change is derived in the open.
#
# The prose of the entry is checked for shape only; whether the figures actually held is
# what the published anchors above executed.
# ---------------------------------------------------------------------------
cat > "$SB/ac6.py" <<'PY'
import json, os, pathlib, re

text = pathlib.Path(os.environ["PROJECT_ROOT"], "bench", "DERIVATIONS.md").read_text(encoding="utf-8")
entries = re.split(r"^## (D-\d+)", text, flags=re.M)
problems = []

# entries alternates [preamble, id, body, id, body, ...]
sections = dict(zip(entries[1::2], entries[2::2]))
newest = ""

if len(sections) < 3:
    problems.append(
        f"bench/DERIVATIONS.md holds {len(sections)} derivation(s); this ticket adds one past D-002"
    )
else:
    newest = max(sections, key=lambda name: int(name.split("-")[1]))
    body = sections[newest]

    if os.environ["WITHDRAWN_RUN_ID"] not in body:
        problems.append(newest + " does not name run " + os.environ["WITHDRAWN_RUN_ID"])

    # The fence is built rather than typed: a literal backtick in this file would be read
    # as markup by every tool that also reads the scenario.
    fence = chr(96) * 3

    if fence not in body:
        problems.append(newest + " carries no fenced reproduce command")

    if not re.search(r"no (published )?figure moves|moves no figure|figures? (are )?unchanged", body, re.I):
        problems.append(newest + " does not state that no published figure moves")

detail = newest + " names the run, carries a reproduce command, and states that no published figure moves"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac6.py" 2>/dev/null)" "AC-6"

# ---------------------------------------------------------------------------
# AC-7 — the gate is composed into verify, and both documents say so.
#
# The output of verify is captured and then searched. It is never piped into `grep -q`:
# under `pipefail` a grep that exits on its first match closes the pipe and the producer
# dies of SIGPIPE, which is how PDX-003 nearly shipped a green assertion over a killed
# step.
# ---------------------------------------------------------------------------
VERIFY_OUT="$(./scripts/verify.sh 2>&1)"
export VERIFY_OUT

cat > "$SB/ac7.py" <<'PY'
import json, os, pathlib

output = os.environ.get("VERIFY_OUT", "")
root = pathlib.Path(os.environ["PROJECT_ROOT"])
problems = []

if not output.strip():
    problems.append("verify.sh produced no output — the step list cannot be searched")
else:
    if "DATA-02" not in output:
        problems.append("verify.sh ran without a DATA-02 step")

    if "VERIFY PASS" not in output:
        problems.append("verify.sh did not finish green")

workflow = (root / "docs" / "WORKFLOW.md").read_text(encoding="utf-8")
claude_md = (root / "CLAUDE.md").read_text(encoding="utf-8")

if "DATA-02" not in workflow:
    problems.append("docs/WORKFLOW.md has no DATA-02 row in its rules table")

# The PDX-003 drift is swept here rather than left for a later reader to rediscover: the
# SRC-01 gate has been running as a verify step while neither document listed it.
for name, text in (("docs/WORKFLOW.md", workflow), ("CLAUDE.md", claude_md)):
    for needle in ("check-data-universe", "check-src"):
        if needle not in text:
            problems.append(f"{name}: the verify composition does not name {needle}.sh")

detail = (
    "verify runs the DATA-02 step and finishes green; both documents name the "
    "data-universe and SRC-01 gates"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac7.py" 2>/dev/null)" "AC-7"

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-016 PASS${NC}"
else
  echo -e "${RED}PDX-016 FAIL${NC}" >&2
fi

exit $FAILED
