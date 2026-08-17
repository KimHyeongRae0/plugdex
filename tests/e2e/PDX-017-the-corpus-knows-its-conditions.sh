#!/usr/bin/env bash
# tests/e2e/PDX-017-the-corpus-knows-its-conditions.sh
#
# PDX-017 — regime is a record, not a filename.
#
# Every run in this corpus executed under one of two conditions: `blocked` (Bash
# disallowed, a write-don't-run instruction appended) or `as-shipped` (Bash allowed,
# ticket only). The condition moves the baseline build rate from 25% to 73%, so it
# decides what almost every published figure means. Until this ticket it was derived by
# `"as-shipped" in name` inside one Python function, invisible to the TypeScript half.
#
# The heuristic is not currently wrong — the ten filenames happen to encode the fact
# correctly, re-derived at drafting. That is the argument for this ticket rather than
# against it: nothing checks that they do, and the next run named without the substring
# joins the wrong pool in silence. This scenario is the thing that checks.
#
# The load-bearing assertion is AC-3: both implementations, per regime, over the live
# corpus, compared view against matching view. The two regimes are never crossed — that
# comparison would fail on a healthy tree and could pass on a sick one.
#
# ASSERT-01 throughout. On the untouched tree every probe below exits non-zero with its
# diagnostics on a stderr this scenario discards, and every variable they fill is the
# empty string. An assertion phrased as "no disagreement found" would therefore report a
# pass in exactly the state it exists to reject. So every probe prints `SENTINEL {json}`
# on its success path, every assertion requires a sentinel-prefixed capture before
# reading it, and every count carries a floor.
#
# Every probe is written to the sandbox and run from there — never inlined with `-e` or a
# heredoc inside `$(...)`. Bash re-lexes a command substitution, so a stray apostrophe, a
# backtick, or a parenthesis inside a quoted Python string silently eats an argument and
# the assertion then reports against the wrong label. That was observed on PDX-016's
# scenario before its probes were moved out.
#
# Nothing is published and nothing outside the repository is contacted (CR-01). Synthetic
# corpora are planted under a scratch directory; the live corpus is only ever read, and
# the writer probe runs against a scratch run directory, never against `bench/data/runs/`.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-017 — the corpus knows its conditions"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx017.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export PROJECT_ROOT
export RUNS="bench/data/runs"
export HARNESS="bench/harness"
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
# never a silent pass. `judge <capture> <label>` is the only thing that reports.
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
# corpus this scenario chose rather than on the one under measurement. `regime` is written
# only when the spec asks for it, because half of these probes are about its absence.
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
                "wrote_code": True,
                "build": index % 2 == 0,
            }
            for index in range(entry.get("cells", 2))
        ],
    }

    if "regime" in entry:
        record["regime"] = entry["regime"]

    if "withdrawn" in entry:
        record["withdrawn"] = entry["withdrawn"]

    name = entry.get("filename", f"{run}.acceptance.json")

    with open(os.path.join(target, name), "w", encoding="utf-8") as handle:
        json.dump(record, handle)
PY

# ---------------------------------------------------------------------------
# AC-1 — the regime is a field, and every record carries it, with the document that
# settles each adjudication written down.
#
# Read off the records themselves and off `bench/DERIVATIONS.md`. RED today: no record
# carries the field, so `seen` is empty and the floor rejects that rather than reporting
# "nothing wrong". A default is refused explicitly — absent must never read as `blocked`,
# because that is today's behaviour with a field in front of it.
# ---------------------------------------------------------------------------
cat > "$SB/ac1.py" <<'PY'
import json, os, pathlib, re

runs = pathlib.Path(os.environ["RUNS"])
legal = {"blocked", "as-shipped"}
seen, missing, illegal = {}, [], []

for path in sorted(runs.glob("*.acceptance.json")):
    record = json.loads(path.read_text(encoding="utf-8"))
    run = record["run"]

    if "regime" not in record:
        missing.append(run)
        continue

    value = record["regime"]

    if value not in legal:
        illegal.append(f"{run}={value!r}")
        continue

    seen[run] = value

problems = []

if not seen and not illegal:
    problems.append(f"no acceptance record carries a regime field ({len(missing)} scanned)")
else:
    if missing:
        problems.append("no regime on: " + ", ".join(sorted(missing)))
    if illegal:
        problems.append("regime outside the two legal values: " + ", ".join(sorted(illegal)))

counts = {value: sum(1 for held in seen.values() if held == value) for value in sorted(legal)}

for value, count in counts.items():
    if count < 1:
        problems.append(f"no record is recorded as {value} — a corpus of one condition is not this corpus")

# The evidence, not just the value. One derivation entry about regime must exist and it
# must name every run, so a reader can check each adjudication against its own source.
derivations = pathlib.Path("bench/DERIVATIONS.md").read_text(encoding="utf-8")
sections = re.split(r"^## ", derivations, flags=re.M)[1:]
about_regime = [body for body in sections if "regime" in body.split("\n", 1)[0].lower()]

if len(about_regime) != 1:
    problems.append(
        f"bench/DERIVATIONS.md holds {len(about_regime)} entries about regime, expected exactly 1"
    )
else:
    unnamed = [run for run in sorted(seen) if run not in about_regime[0]]

    if unnamed:
        problems.append("the derivation entry does not name: " + ", ".join(unnamed))

detail = (
    f"{len(seen)} records carry a regime "
    f"({counts['blocked']} blocked, {counts['as-shipped']} as-shipped), "
    "each named with its evidence in bench/DERIVATIONS.md"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac1.py" 2>/dev/null)" "AC-1"

# ---------------------------------------------------------------------------
# AC-2 — the loader exposes the field and refuses what it cannot read.
#
# Synthetic throughout, so no assertion depends on which runs happen to exist. The two
# refusals are asserted on error *names*, because "it threw" is satisfied by a typo.
# ---------------------------------------------------------------------------
cat > "$SB/ac2.mjs" <<'JS'
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

const problems = [];

/** Writes one synthetic record; `regime` is omitted entirely when the spec has none. */
const plant = ({ dir, run, regime, cells = 2 }) => {
  const record = {
    run,
    env: {
      npm_fingerprint: 'synthetic00000000',
      npm_undeclared_toplevel: 0,
      npm_packages: 1,
      npm_installed: [],
      npm_extraneous: [],
      node: 'v22.14.0',
      python_gate: '/usr/bin/python3',
    },
    cells: Array.from({ length: cells }, (_, index) => ({
      cell: `${run}__t${index}`,
      task: `t${index}`,
      arm: 'baseline',
      model: 'haiku',
      rep: index,
      valid: true,
      wrote_code: true,
      build: index % 2 === 0,
    })),
  };

  if (regime !== undefined) record.regime = regime;

  writeFileSync(join(dir, `${run}.acceptance.json`), JSON.stringify(record));
};

const freshDir = () => {
  const dir = mkdtempSync(join(tmpdir(), 'pdx017-ac2-'));
  mkdirSync(dir, { recursive: true });
  return dir;
};

/** Runs `body` and returns the thrown error's name, or '' when nothing was thrown. */
const nameOfThrow = (body) => {
  try {
    body();
    return '';
  } catch (error) {
    return error?.name ?? 'unnamed';
  }
};

// Filtering returns only the asked-for regime; omitting the option returns everything.
const mixed = freshDir();
plant({ dir: mixed, run: '20200101-000000', regime: 'blocked', cells: 2 });
plant({ dir: mixed, run: '20200102-000000', regime: 'as-shipped', cells: 3 });

const blocked = loadAcceptanceRecords({ dir: mixed, regime: 'blocked' });
const asShipped = loadAcceptanceRecords({ dir: mixed, regime: 'as-shipped' });
const everything = loadAcceptanceRecords({ dir: mixed });

if (blocked.records.length !== 1 || blocked.cells.length !== 2) {
  problems.push(`blocked view is ${blocked.records.length} records / ${blocked.cells.length} cells, expected 1 / 2`);
}

if (asShipped.records.length !== 1 || asShipped.cells.length !== 3) {
  problems.push(`as-shipped view is ${asShipped.records.length} records / ${asShipped.cells.length} cells, expected 1 / 3`);
}

if (everything.records.length !== 2 || everything.cells.length !== 5) {
  problems.push(`the unfiltered view is ${everything.records.length} records / ${everything.cells.length} cells, expected 2 / 5`);
}

if (blocked.records[0]?.regime !== 'blocked') {
  problems.push('the parsed record does not carry its regime through to the consumer');
}

// A record with no regime is refused, never defaulted.
const absent = freshDir();
plant({ dir: absent, run: '20200103-000000' });

const absentThrow = nameOfThrow(() => loadAcceptanceRecords({ dir: absent }));

if (absentThrow !== 'MissingRegimeError') {
  problems.push(`a record with no regime threw ${absentThrow || 'nothing'}, expected MissingRegimeError`);
}

// A near-miss value is refused too: a parser that trims or lowercases would move a run
// between conditions on a typo, which is the failure this field exists to prevent.
for (const value of ['Blocked', 'as shipped', 'blocked ', '']) {
  const dir = freshDir();
  plant({ dir, run: '20200104-000000', regime: value });

  const thrown = nameOfThrow(() => loadAcceptanceRecords({ dir }));

  if (thrown !== 'UnknownRegimeError') {
    problems.push(`regime ${JSON.stringify(value)} threw ${thrown || 'nothing'}, expected UnknownRegimeError`);
  }
}

// A filter matching nothing is an empty result, not a fallback to everything.
const onlyBlocked = freshDir();
plant({ dir: onlyBlocked, run: '20200105-000000', regime: 'blocked' });

const empty = loadAcceptanceRecords({ dir: onlyBlocked, regime: 'as-shipped' });

if (empty.records.length !== 0 || empty.cells.length !== 0) {
  problems.push(`a filter matching no record returned ${empty.records.length} records — it fell back instead of returning empty`);
}

const detail =
  'filters both ways, returns everything unfiltered, refuses an absent regime and four near-miss values by name, and an empty pool stays empty';

console.log('SENTINEL ' + JSON.stringify({ ok: problems.length === 0, detail: problems.join('; ') || detail }));
JS

judge "$(node "$SB/ac2.mjs" 2>/dev/null)" "AC-2"

# ---------------------------------------------------------------------------
# AC-3 — the two implementations agree, per regime. The load-bearing assertion.
#
# The TypeScript loader that feeds the site and the Python harness that computed every
# published figure are both run over the live corpus, and their counts are compared view
# against matching view. The two regimes are never crossed: comparing blocked against
# as-shipped would fail on a healthy tree and could pass on a sick one.
#
# Both probes write JSON to a file rather than answering through the shell, and a third
# probe does the comparison, so no capture is re-parsed by bash. `arms` follows
# `rate_table` semantics on outcome `build` — a cell is skipped when `build` is absent
# *or* null, because Python's `is None` covers both and a future record writing an
# explicit null would otherwise split the two probes inside the comparison meant to prove
# them equal.
# ---------------------------------------------------------------------------
cat > "$SB/ac3-ts.mjs" <<'JS'
import { writeFileSync } from 'node:fs';

const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

/** `rate_table(cells, 'build')` semantics: absent and null are both "no outcome". */
const armTable = ({ cells }) => {
  const table = {};

  for (const cell of cells) {
    if (cell.build === undefined || cell.build === null) continue;

    const [hits, n] = table[cell.arm] ?? [0, 0];
    table[cell.arm] = [hits + (cell.build === true ? 1 : 0), n + 1];
  }

  return table;
};

const view = ({ regime }) => {
  const corpus = regime === null
    ? loadAcceptanceRecords({ dir: process.env.RUNS })
    : loadAcceptanceRecords({ dir: process.env.RUNS, regime });

  return {
    cells: corpus.cells.length,
    valid: corpus.cells.filter((cell) => cell.valid === true).length,
    arms: armTable({ cells: corpus.cells }),
  };
};

writeFileSync(process.env.TS_VIEWS, JSON.stringify({
  blocked: view({ regime: 'blocked' }),
  'as-shipped': view({ regime: 'as-shipped' }),
  all: view({ regime: null }),
}));

console.log('SENTINEL ' + JSON.stringify({ ok: true, detail: 'the TypeScript views were written' }));
JS

cat > "$SB/ac3-py.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["HARNESS"])
from fisher import load_cells, rate_table

cells = load_cells()

# Read off the record, never off the name. The scenario refuses to reproduce the
# heuristic it exists to remove, so a cell with no recorded regime is a failure here
# rather than something this probe quietly buckets.
def view(selected):
    return {
        "cells": len(selected),
        "valid": sum(1 for cell in selected if cell.get("valid") is True),
        "arms": {arm: list(counts) for arm, counts in rate_table(selected, outcome="build").items()},
    }

unlabelled = [cell for cell in cells if cell.get("_regime") not in ("blocked", "as-shipped")]

if unlabelled:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{len(unlabelled)} cells carry no legal _regime — the harness did not read the field",
    }))
    sys.exit(0)

views = {
    "blocked": view([cell for cell in cells if cell["_regime"] == "blocked"]),
    "as-shipped": view([cell for cell in cells if cell["_regime"] == "as-shipped"]),
    "all": view(cells),
}

with open(os.environ["PY_VIEWS"], "w", encoding="utf-8") as handle:
    json.dump(views, handle)

print("SENTINEL " + json.dumps({"ok": True, "detail": "the Python views were written"}))
PY

cat > "$SB/ac3-compare.py" <<'PY'
import json, os, pathlib

problems = []
ts_path, py_path = pathlib.Path(os.environ["TS_VIEWS"]), pathlib.Path(os.environ["PY_VIEWS"])

if not ts_path.exists() or not py_path.exists():
    missing = [str(path) for path in (ts_path, py_path) if not path.exists()]
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": "a probe wrote no views: " + ", ".join(missing),
    }))
    raise SystemExit(0)

ts, py = json.loads(ts_path.read_text()), json.loads(py_path.read_text())

# Floors first (ASSERT-01). Two empty pools compare equal, so equality is only meaningful
# once both sides are known to hold something.
for name, views in (("typescript", ts), ("python", py)):
    for regime in ("blocked", "as-shipped"):
        view = views.get(regime, {})

        if view.get("cells", 0) < 1:
            problems.append(f"{name}/{regime}: {view.get('cells', 0)} cells — an empty pool proves nothing")
        if view.get("valid", 0) < 1:
            problems.append(f"{name}/{regime}: no valid cells")

    larger = max(("blocked", "as-shipped"), key=lambda regime: views.get(regime, {}).get("cells", 0))

    if len(views.get(larger, {}).get("arms", {})) < 2:
        problems.append(f"{name}/{larger}: fewer than 2 arms — a single-arm pool cannot show a comparison")

    split = views.get("blocked", {}).get("cells", 0) + views.get("as-shipped", {}).get("cells", 0)

    if split != views.get("all", {}).get("cells", -1):
        problems.append(
            f"{name}: the two regimes hold {split} cells but the unfiltered view holds "
            f"{views.get('all', {}).get('cells')} — a record is in neither pool or in both"
        )

# Then the comparison itself, canonicalized: the two languages order keys differently and
# a raw compare would fail on a healthy tree.
for regime in ("blocked", "as-shipped", "all"):
    left = json.dumps(ts.get(regime), sort_keys=True)
    right = json.dumps(py.get(regime), sort_keys=True)

    if left != right:
        problems.append(f"{regime}: typescript {left} vs python {right}")

detail = (
    f"blocked {ts['blocked']['cells']} cells / {ts['blocked']['valid']} valid, "
    f"as-shipped {ts['as-shipped']['cells']} / {ts['as-shipped']['valid']}, "
    f"summing to {ts['all']['cells']} — identical in both implementations, per regime"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

export TS_VIEWS="$SB/ts-views.json"
export PY_VIEWS="$SB/py-views.json"

judge "$(node "$SB/ac3-ts.mjs" 2>/dev/null)" "AC-3 (the TypeScript views)"
judge "$(python3 "$SB/ac3-py.py" 2>/dev/null)" "AC-3 (the Python views)"
judge "$(python3 "$SB/ac3-compare.py" 2>/dev/null)" "AC-3 (per regime, the two agree)"

# ---------------------------------------------------------------------------
# AC-4 — no filename decides a regime, proven behaviourally.
#
# A grep only catches the spelling of the last mechanism. This plants a corpus whose
# names say the opposite of what its records say and asserts the harness reports the
# records' values. Today the decoy comes back inverted, which is the RED.
#
# And because the relocation is supposed to change nothing, D-002's corrected condition
# table is re-derived from the recorded field rather than quoted. A row that moves names
# the derivation to correct in place under CLAIM-01 — it does not license editing this
# assertion.
# ---------------------------------------------------------------------------
python3 "$SB/plant.py" "$SB/decoy" '[
  {"run": "20200101-000000", "filename": "20200101-000000-as-shipped-decoy.acceptance.json", "regime": "blocked", "cells": 2},
  {"run": "20200102-000000", "filename": "20200102-000000-plain.acceptance.json", "regime": "as-shipped", "cells": 3},
  {"run": "20200103-000000", "filename": "20200103-000000-withdrawn-plain.acceptance.json", "regime": "as-shipped", "cells": 4,
   "withdrawn": {"reason": "planted by the PDX-017 scenario", "recorded_at": "2026-08-18T00:00:00+09:00"}}
]' 2>/dev/null

cat > "$SB/ac4-decoy.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["HARNESS"])
from fisher import load_cells

# The third record is withdrawn, and it is here because the regime check used to sit
# behind the withdrawal `continue`: a withdrawn record was exempt from it in the Python
# half while the TypeScript half refused the same directory. Its name derives `blocked`
# and it is recorded `as-shipped`, so a loader reading names for withdrawn records only —
# the shape a whole-corpus decoy cannot see — is caught here.
expected = {
    "20200101-000000-as-shipped-decoy": "blocked",
    "20200102-000000-plain": "as-shipped",
    "20200103-000000-withdrawn-plain": "as-shipped",
}
problems = []

try:
    cells = load_cells(include_withdrawn=True, runs_dir=os.path.join(os.environ["SB"], "decoy"))
except Exception as error:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"the harness raised on the decoy corpus ({type(error).__name__}: {error})",
    }))
    raise SystemExit(0)

if len(cells) != 9:
    problems.append(f"the decoy corpus produced {len(cells)} cells, expected 9")

for cell in cells:
    run = cell["_run"]
    want = expected.get(run)

    if want is None:
        problems.append(f"unexpected run in the decoy corpus: {run}")
    elif cell.get("_regime") != want:
        problems.append(
            f"{run}: the harness reports {cell.get('_regime')!r} but the record says {want!r} — "
            "the filename decided"
        )
        break

detail = "a corpus whose names contradict its records is read off the records — both directions, withdrawn records included"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac4-decoy.py" 2>/dev/null)" "AC-4 (the decoy corpus)"

# The ticket's edge case, in the one shape that was actually broken: a withdrawn record
# with no regime. The Python half validated the regime after the withdrawal `continue`,
# so the default view loaded it in silence while `@plugdex/data` refused the whole
# directory — the two-loader disagreement this ticket exists to prevent, reintroduced by
# the ticket itself. Found by the PDX-017 report review.
python3 "$SB/plant.py" "$SB/exempt" '[
  {"run": "20200101-000000", "regime": "blocked", "cells": 2},
  {"run": "20200102-000000", "cells": 2,
   "withdrawn": {"reason": "planted by the PDX-017 scenario", "recorded_at": "2026-08-18T00:00:00+09:00"}}
]' 2>/dev/null

cat > "$SB/ac4-exempt.py" <<'PY'
import json, os, subprocess, sys

sys.path.insert(0, os.environ["HARNESS"])
from fisher import load_cells

corpus = os.path.join(os.environ["SB"], "exempt")
problems = []

try:
    cells = load_cells(runs_dir=corpus)
    problems.append(
        f"the harness loaded {len(cells)} cells from a corpus whose withdrawn record has "
        "no regime — withdrawal exempted it from the check"
    )
except ValueError as error:
    if "regime" not in str(error):
        problems.append(f"the harness refused, but not for the regime ({error})")

node = subprocess.run(
    ["node", os.path.join(os.environ["SB"], "ac4-exempt.mjs"), corpus],
    capture_output=True, text=True,
)
answer = node.stdout.strip()

if answer != "MissingRegimeError":
    problems.append(f"the TypeScript loader answered {answer!r}, expected MissingRegimeError")

detail = "a withdrawn record with no regime is refused by both implementations, in the same directory"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

cat > "$SB/ac4-exempt.mjs" <<'JS'
const { loadAcceptanceRecords } = await import(process.env.DATA_PKG);

try {
  loadAcceptanceRecords({ dir: process.argv[2] });
  console.log('LOADED');
} catch (error) {
  console.log(error?.name ?? 'unnamed');
}
JS

judge "$(python3 "$SB/ac4-exempt.py" 2>/dev/null)" "AC-4 (neither fact exempts the other)"

cat > "$SB/ac4-anchors.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["HARNESS"])
from fisher import load_cells

# D-002's corrected condition table, as published in bench/README.md and derived per run
# in bench/DERIVATIONS.md. These are the figures the relocation must not move.
EXPECTED = {
    ("blocked", "haiku"): (34, 35),
    ("as-shipped", "haiku"): (9, 9),
    ("blocked", "sonnet"): (6, 6),
}
EXPECTED_TOTAL = (49, 50)

problems = []
superpowers = [
    cell for cell in load_cells()
    if cell["arm"] == "superpowers" and cell.get("valid")
]

if not superpowers:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": "no valid superpowers cells were loaded — the anchor had nothing to re-derive",
    }))
    raise SystemExit(0)

table = {}

for cell in superpowers:
    key = (cell.get("_regime"), cell.get("model"))
    no_code, total = table.get(key, (0, 0))
    table[key] = (no_code + (not cell.get("wrote_code")), total + 1)

for key, want in EXPECTED.items():
    got = table.get(key)

    if got != want:
        problems.append(
            f"{key[0]}/{key[1]}: {got[0]} of {got[1]}" if got else f"{key[0]}/{key[1]}: absent"
        )

unexpected = sorted(str(key) for key in table if key not in EXPECTED)

if unexpected:
    problems.append("conditions D-002 does not list: " + ", ".join(unexpected))

total = (
    sum(1 for cell in superpowers if not cell.get("wrote_code")),
    len(superpowers),
)

if total != EXPECTED_TOTAL:
    problems.append(f"total {total[0]} of {total[1]}, D-002 publishes {EXPECTED_TOTAL[0]} of {EXPECTED_TOTAL[1]}")

if problems:
    problems.append(
        "a moved row is a CLAIM-01 correction in bench/DERIVATIONS.md D-002, not an edit to this assertion"
    )

detail = "D-002 re-derives from the recorded field: 34/35 blocked haiku, 9/9 as-shipped haiku, 6/6 blocked sonnet, 49/50 total"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac4-anchors.py" 2>/dev/null)" "AC-4 (D-002 re-derives)"

# ---------------------------------------------------------------------------
# AC-5 — DATA-02 covers regime.
#
# Three new lettered rules, each proven against a sandbox repository the way
# `check-gates.sh` does it: `scripts/` copied and nothing else, so a case that assumed the
# real `bench/` would be testing the repository rather than the gate. Each planted
# violation must trip exactly one lettered rule — a case that trips two proves less than
# it appears to, and this repository has had two such cases by accident already.
# ---------------------------------------------------------------------------

# A sandbox repository: the gate's scripts, a corpus, and an analysis loader. `kind`
# chooses whether the planted loader reads the record's field or derives it from the name.
plant_gate_sandbox() {
  local dir="$1" kind="$2"

  mkdir -p "$dir/bench/data/runs" "$dir/bench/harness"
  cp -R scripts "$dir/scripts"

  if [[ "$kind" == "field-reading" ]]; then
    cat > "$dir/bench/harness/fisher.py" <<'LOADER'
import glob, json, os


def load_cells(include_withdrawn=False, runs_dir="bench/data/runs"):
    cells = []

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        record = json.load(open(path, encoding="utf-8"))

        if record.get("withdrawn") is not None and not include_withdrawn:
            continue

        for cell in record["cells"]:
            cell = dict(cell)
            cell["_run"] = os.path.basename(path).split(".")[0]
            cell["_regime"] = record["regime"]
            cells.append(cell)

    return cells
LOADER
  else
    cat > "$dir/bench/harness/fisher.py" <<'LOADER'
import glob, json, os


def load_cells(include_withdrawn=False, runs_dir="bench/data/runs"):
    cells = []

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        name = os.path.basename(path)
        record = json.load(open(path, encoding="utf-8"))

        if record.get("withdrawn") is not None and not include_withdrawn:
            continue

        for cell in record["cells"]:
            cell = dict(cell)
            cell["_run"] = name.split(".")[0]
            # The regression DATA-02g exists to catch.
            cell["_regime"] = "as-shipped" if "as-shipped" in name else "blocked"
            cells.append(cell)

    return cells
LOADER
  fi
}

# `expect_one_rule <label> <letter> <dir>` — the gate must BLOCK, and name that rule only.
expect_one_rule() {
  local label="$1" letter="$2" dir="$3"
  local output letters status

  output="$(PLUGDEX_GATE_SANDBOX=1 "$dir/scripts/check-data-universe.sh" 2>&1)"
  status=$?

  if [[ -z "$output" ]]; then
    fail "$label: the gate produced no output — it did not run"
    return
  fi

  if [[ $status -eq 0 ]]; then
    fail "$label: the gate PASSED a corpus planted to violate $letter"
    return
  fi

  letters="$(printf '%s' "$output" | grep -o 'DATA-02[a-g]' | sort -u | tr '\n' ' ')"
  letters="${letters% }"

  if [[ "$letters" != "$letter" ]]; then
    fail "$label: the gate named [$letters], expected exactly [$letter]"
    return
  fi

  pass "$label: BLOCKed, naming $letter and nothing else"
}

# DATA-02e — a record with no regime. Absent must never read as blocked.
plant_gate_sandbox "$SB/gate-e" field-reading
python3 "$SB/plant.py" "$SB/gate-e/bench/data/runs" '[
  {"run": "20200101-000000", "cells": 2},
  {"run": "20200102-000000", "regime": "blocked", "cells": 2}
]' 2>/dev/null
expect_one_rule "AC-5 (DATA-02e, no regime)" "DATA-02e" "$SB/gate-e"

# DATA-02f — a near-miss value. A typo that silently moves a run between conditions is
# the failure the field exists to prevent.
plant_gate_sandbox "$SB/gate-f" field-reading
python3 "$SB/plant.py" "$SB/gate-f/bench/data/runs" '[
  {"run": "20200101-000000", "regime": "Blocked", "cells": 2},
  {"run": "20200102-000000", "regime": "as-shipped", "cells": 2}
]' 2>/dev/null
expect_one_rule "AC-5 (DATA-02f, an unknown value)" "DATA-02f" "$SB/gate-f"

# DATA-02g — a filename comparison deciding a regime, caught behaviourally: the corpus is
# entirely consistent and only the loader is wrong.
plant_gate_sandbox "$SB/gate-g" name-deriving
python3 "$SB/plant.py" "$SB/gate-g/bench/data/runs" '[
  {"run": "20200101-000000", "filename": "20200101-000000-as-shipped-run.acceptance.json", "regime": "blocked", "cells": 2},
  {"run": "20200102-000000", "filename": "20200102-000000-plain.acceptance.json", "regime": "as-shipped", "cells": 2}
]' 2>/dev/null
expect_one_rule "AC-5 (DATA-02g, a filename deciding a regime)" "DATA-02g" "$SB/gate-g"

# The clean pass. Without it the three rules above are satisfied by a gate that blocks
# everything.
plant_gate_sandbox "$SB/gate-clean" field-reading
python3 "$SB/plant.py" "$SB/gate-clean/bench/data/runs" '[
  {"run": "20200101-000000", "regime": "blocked", "cells": 2},
  {"run": "20200102-000000", "regime": "as-shipped", "cells": 2}
]' 2>/dev/null

CLEAN_OUT="$(PLUGDEX_GATE_SANDBOX=1 "$SB/gate-clean/scripts/check-data-universe.sh" 2>&1)"

if [[ -z "$CLEAN_OUT" ]]; then
  fail "AC-5 (the clean pass): the gate produced no output — it did not run"
elif ! printf '%s' "$CLEAN_OUT" | grep -q "DATA-02 PASS"; then
  fail "AC-5 (the clean pass): a consistent corpus was BLOCKed — $(printf '%s' "$CLEAN_OUT" | tr '\n' ' ')"
else
  pass "AC-5 (the clean pass): one record per legal value passes"
fi

# The golden set carries all of it, so the rules stay proven after this ticket closes.
GOLDEN_MISSING=""

for letter in DATA-02e DATA-02f DATA-02g; do
  if ! grep -rlq "$letter" tests/meta/cases/ 2>/dev/null; then
    GOLDEN_MISSING="$GOLDEN_MISSING $letter"
  fi
done

if [[ -n "$GOLDEN_MISSING" ]]; then
  fail "AC-5 (the golden set): no case covers$GOLDEN_MISSING"
else
  pass "AC-5 (the golden set): every new rule has a case in tests/meta/cases/"
fi

# ---------------------------------------------------------------------------
# AC-6 — no published figure moves without a correction.
#
# The relocation is supposed to change nothing, so the anchors are run rather than
# trusted. `derive_d001.py` reads the frozen corpus at `63735e6` directly and the live
# corpus through `load_cells`, and its blocked-regime block is exactly the thing a regime
# error would move. AC-4's re-derivation of D-002 is the other half of this criterion.
# ---------------------------------------------------------------------------
D001_OUT="$(python3 bench/harness/derive_d001.py 2>&1)"
FISHER_OUT="$(python3 bench/harness/fisher.py 2>&1)"
export D001_OUT FISHER_OUT

cat > "$SB/ac6.py" <<'PY'
import json, os

d001 = os.environ.get("D001_OUT", "")
fisher = os.environ.get("FISHER_OUT", "")
problems = []

if not d001.strip():
    problems.append("derive_d001.py produced no output — the anchor was never executed")
else:
    # The published pair: the excluded-pool baseline and ponytail's nominal p. Both are
    # computed inside the blocked regime, so a misread regime moves them.
    for needle, what in (
        ("baseline 12/34", "the excluded-pool baseline"),
        ("p = 0.0352", "ponytail's nominal p in the excluded pool"),
        ("p = 0.0055", "ponytail's p with the withdrawn run pooled"),
        ("blocked regime", "the blocked-regime heading the whole derivation is scoped to"),
    ):
        if needle not in d001:
            problems.append(f"{what} moved: derive_d001.py no longer prints {needle!r}")

if not fisher.strip():
    problems.append("fisher.py produced no output — the self-validation never ran")
else:
    if "3 textbook tables validated" not in fisher:
        problems.append("fisher.py no longer validates itself against the textbook tables")
    if "corpus: 371 cells (447 with the withdrawn run)" not in fisher:
        problems.append("the corpus line moved — 371/447 is what D-003 published")

if problems:
    problems.append(
        "a moved figure is a CLAIM-01 correction with its own derivation entry, not an edit here"
    )

detail = "D-001's anchors and fisher.py's corpus line reproduce unchanged from the recorded field"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac6.py" 2>/dev/null)" "AC-6"

# ---------------------------------------------------------------------------
# AC-2 (the writer) — the grader stamps what the reader requires.
#
# `acceptance.py` writes the records. A required field the writer does not stamp means the
# next graded run emits a record this project's own loader refuses — a self-inflicted
# outage with a clean error message. The refusal has to come *before* the grading
# prerequisites, so this probe is meaningful on a machine without the fixture installed:
# a regime that cannot be established is a reason not to start, not a reason to stop
# halfway through with a directory full of scored cells.
#
# Run against a scratch run directory. `bench/data/runs/` is never written to.
# ---------------------------------------------------------------------------
mkdir -p "$SB/writer/20200101-000000" "$SB/writer-stamped/20200102-000000"
printf '%s' '{"date": "2020-01-02", "regime": "as-shipped", "results": []}' \
  > "$SB/writer-stamped/20200102-000000/results.json"

cat > "$SB/ac2w.py" <<'PY'
import json, os, subprocess, sys

sandbox = os.environ["SB"]
problems = []


def run(args):
    completed = subprocess.run(
        [sys.executable, "bench/harness/acceptance.py"] + args,
        capture_output=True, text=True,
    )
    return completed.returncode, (completed.stdout + completed.stderr)


# No regime anywhere: refuse, and say why.
code, output = run([os.path.join(sandbox, "writer", "20200101-000000")])

if code == 0:
    problems.append("the grader wrote a record with no regime established")
elif "regime" not in output.lower():
    problems.append(f"the grader refused without naming regime: {output.strip()[:120]!r}")

# An unknown value: refuse rather than pass it through to the corpus.
code, output = run([os.path.join(sandbox, "writer", "20200101-000000"), "--regime", "as shipped"])

if code == 0:
    problems.append("the grader accepted an unknown regime value")
elif "regime" not in output.lower():
    problems.append(f"the grader refused an unknown value without naming regime: {output.strip()[:120]!r}")

# A legal value, and a value the run's own results.json already carries: neither may be
# refused *for want of a regime*. Both may still stop on a missing grading fixture, which
# is a different failure and must not be reported as this one.
for label, args in (
    ("--regime blocked", [os.path.join(sandbox, "writer", "20200101-000000"), "--regime", "blocked"]),
    ("a results.json carrying the regime", [os.path.join(sandbox, "writer-stamped", "20200102-000000")]),
):
    code, output = run(args)

    if code != 0 and "regime" in output.lower():
        problems.append(f"{label}: the grader still refused for want of a regime — {output.strip()[:120]!r}")

detail = "the grader refuses to write without a regime and refuses an unknown value, and accepts both the flag and a run's own results.json"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac2w.py" 2>/dev/null)" "AC-2 (the writer stamps it)"

# ---------------------------------------------------------------------------
# AC-7 — the extended gate is composed into verify, and the documents say so.
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
    if "DATA-02 PASS" not in output:
        problems.append("verify.sh ran without a passing DATA-02 step")
    if "VERIFY PASS" not in output:
        problems.append("verify.sh did not finish green")

workflow = (root / "docs" / "WORKFLOW.md").read_text(encoding="utf-8")
claude_md = (root / "CLAUDE.md").read_text(encoding="utf-8")
gate = (root / "scripts" / "check-data-universe.sh").read_text(encoding="utf-8")

for name, text in (("docs/WORKFLOW.md", workflow), ("CLAUDE.md", claude_md)):
    if "regime" not in text.lower():
        problems.append(f"{name}: the DATA-02 row does not mention regime")

# The stale disclosure is removed rather than left standing. Both the gate header and
# WORKFLOW.md said DATA-02 covered withdrawal only and pointed at this ticket; a scope
# note that outlives its scope is its own defect.
for name, text in (("docs/WORKFLOW.md", workflow), ("scripts/check-data-universe.sh", gate)):
    for stale in ("withdrawal only", "Round one enforces", "round one enforces"):
        if stale in text:
            problems.append(f"{name}: still claims DATA-02 covers {stale!r}")

detail = "verify runs DATA-02 green, both documents carry the regime clause, and the withdrawal-only disclosure is gone"

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac7.py" 2>/dev/null)" "AC-7"

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-017 PASS${NC}"
else
  echo -e "${RED}PDX-017 FAIL${NC}" >&2
fi

exit $FAILED
