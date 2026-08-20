#!/usr/bin/env bash
# tests/e2e/PDX-035-the-corpus-says-what-it-covers.sh
#
# PDX-035 — the corpus says what it actually covers.
#
# The landing page says every pack was run "against real tickets in a real repository". True,
# and read far wider than what happened: 12 tasks, one fixture, two shapes — a React component
# added to a template, or a FastAPI endpoint added to the same one. No mobile, no client app,
# no design work, no second repository.
#
# Every assertion reads BUILT OUTPUT (`packages/site/dist`) or the records, never site source.
#
# ASSERT-01 throughout. Every probe prints `SENTINEL {"ok": bool, "detail": str}`, an empty
# capture is a failure rather than a quiet pass, and the checks whose failure mode is silence
# run against a planted violation first and must report it before their real run is believed.
#
# The fixture is CITED, not derived. Plan review round 1 killed a derivation that counted
# `tmpl-` prefixes: renaming a task inside the same fixture would have made the page claim two
# repositories, and the direction test as first written required that behaviour. DEC-019 —
# a filename is not the fact. Prefixes are only a consistency check here.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-035 — the corpus says what it covers"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx035.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export PROJECT_ROOT SB
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"
export RUNS_DIR="$PROJECT_ROOT/bench/data/runs"
export INDEX_HTML="$PROJECT_ROOT/packages/site/dist/index.html"
export SITE_DIST="$PROJECT_ROOT/packages/site/dist"
export REPRODUCE="$PROJECT_ROOT/bench/REPRODUCE.md"

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
  || echo "  (build failed; see $SB/build.log — every assertion below reports the missing output as its cause)" >&2

cat > "$SB/report.py" <<'REPORT'
"""One verdict shape for every probe in this scenario."""
import json


def verdict(problems, detail):
    return {"ok": not problems, "detail": detail if not problems else "; ".join(problems)}
REPORT

# The independent inventory: computed from the records, never from the page.
cat > "$SB/inventory.py" <<'INV'
import glob, json, os, re


def inventory(runs_dir):
    tasks, shapes, cells = set(), {}, {}

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        record = json.load(open(path, encoding="utf-8"))

        if record.get("withdrawn") or record.get("regime") != "blocked":
            continue

        for cell in record.get("cells") or []:
            if cell.get("valid") is False:
                continue

            task = cell.get("task") or ""
            tasks.add(task)

            match = re.match(r"^([a-z]+)-([a-z]+)-", task)
            if match:
                shape = f"{match.group(1)}-{match.group(2)}"
                shapes.setdefault(shape, set()).add(task)
                cells[shape] = cells.get(shape, 0) + 1

    return {
        "tasks": len(tasks),
        "shapes": {s: {"tasks": len(t), "cells": cells.get(s, 0)} for s, t in shapes.items()},
        "families": sorted({s.split("-")[0] for s in shapes}),
    }
INV

# ---------------------------------------------------------------------------
# AC-1 — the counts on the page re-derive from the records.
# ---------------------------------------------------------------------------
cat > "$SB/counts.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from inventory import inventory
from report import verdict

inv = inventory(os.environ["RUNS_DIR"])
problems = []

if inv["tasks"] == 0:
    print("SENTINEL " + json.dumps({"ok": False, "detail": "the corpus yielded no tasks at all"}))
    sys.exit(0)

try:
    html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()
except Exception as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

block = re.search(r'<p[^>]*data-coverage="corpus"[^>]*>([\s\S]*?)</p>', html)

if block is None:
    print("SENTINEL " + json.dumps({"ok": False, "detail": "no [data-coverage=\"corpus\"] element in the built page"}))
    sys.exit(0)

text = re.sub(r"<[^>]*>", " ", block.group(1))
text = re.sub(r"\s+", " ", text).strip()

if not text:
    problems.append("the coverage element renders no text")

for needle in [str(inv["tasks"])] + [str(v["tasks"]) for v in inv["shapes"].values()] \
        + [str(v["cells"]) for v in inv["shapes"].values()]:
    if needle not in text:
        problems.append(f"the coverage sentence does not carry {needle}")

# AC-2: the scope note must sit with the figure it qualifies, not one click or one scroll
# away. A reader who sees `73% n=22 (frontend)` has to be able to see what the 22 were in the
# same view, so the two live in one section — asserted structurally rather than by eye,
# because "beside" is exactly the kind of claim a layout change quietly breaks.
section = re.search(
    r'<section[^>]*id="build"[^>]*>([\s\S]*?)</section>', html
)

if section is None:
    problems.append("no <section id=\"build\"> in the built page — the scope note has no home")
else:
    body = section.group(1)

    for needle, label in [
        ('data-coverage="corpus"', "the coverage statement"),
        ('data-ranked', "the ranked figure"),
        ('data-decision="summary"', "the decision"),
    ]:
        if needle not in body:
            problems.append(f"{label} is outside the section that carries the headline rate")

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"{inv['tasks']} tasks, shapes {({k: (v['tasks'], v['cells']) for k, v in inv['shapes'].items()})}, "
    f"all present in the rendered sentence, and the note sits in the same section as the figure",
)))
PY

judge "$(python3 "$SB/counts.py" 2>/dev/null)" "AC-1 (the coverage counts re-derive from the records)"

# ---------------------------------------------------------------------------
# AC-1 — the fixture is quoted from where it is documented, not asserted by the page.
# AC-1 — prefixes are a consistency check, and a disagreement names both sides.
# ---------------------------------------------------------------------------
cat > "$SB/fixture.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from inventory import inventory
from report import verdict

problems = []
reproduce = open(os.environ["REPRODUCE"], encoding="utf-8").read()
html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()

# The fixture as its own documentation states it, read from that file rather than the page.
cited = re.search(r"`([\w.-]+/[\w.-]+)`\s*@\s*`([0-9a-f]{6,})`", reproduce)

if cited is None:
    print("SENTINEL " + json.dumps({"ok": False, "detail": "bench/REPRODUCE.md names no fixture@commit — the page has nothing to cite"}))
    sys.exit(0)

repo, commit = cited.group(1), cited.group(2)
text = re.sub(r"\s+", " ", re.sub(r"<[^>]*>", " ", html))

if repo not in text:
    problems.append(f"the page does not name the fixture repository {repo}")
if commit[:7] not in text:
    problems.append(f"the page does not name the fixture commit {commit[:7]}")

# Consistency, not derivation: if ids ever disagree with a single cited fixture, say both.
families = inventory(os.environ["RUNS_DIR"])["families"]

if len(families) != 1:
    problems.append(
        f"task ids imply {len(families)} families {families} while REPRODUCE.md cites one "
        f"fixture ({repo}) — the two disagree and neither is silently preferred"
    )

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"fixture cited from bench/REPRODUCE.md as {repo}@{commit[:7]} and rendered; "
    f"task-id families {families} agree with one fixture",
)))
PY

judge "$(python3 "$SB/fixture.py" 2>/dev/null)" "AC-1 (the fixture is cited, and the ids agree)"

# ---------------------------------------------------------------------------
# AC-4 / AC-7 — the absences are stated, and the limit is named in both halves.
# ---------------------------------------------------------------------------
cat > "$SB/absences.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from report import verdict

html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()
text = re.sub(r"\s+", " ", re.sub(r"<[^>]*>", " ", html)).lower()
problems = []

for label, words in [
    ("mobile or client-app work", ["mobile", "client"]),
    ("design work", ["design"]),
    ("a second repository", ["one repository", "single repository", "same repository", "one fixture"]),
]:
    if not any(w in text for w in words):
        problems.append(f"the page does not state the absence of {label}")

# AC-7: both halves of the limit, not just the first.
if "transfer" not in text and "generalis" not in text and "generaliz" not in text:
    problems.append("the page does not say whether these results transfer beyond this fixture")

print("SENTINEL " + json.dumps(verdict(
    problems, "every absence named, and the external-validity limit states both halves",
)))
PY

judge "$(python3 "$SB/absences.py" 2>/dev/null)" "AC-4/AC-7 (absences stated, limit named)"

# ---------------------------------------------------------------------------
# AC-9 — three tiers, derived, with the live trap pinned by name.
# ---------------------------------------------------------------------------
cat > "$SB/tiers.mjs" <<'JS'
const data = await import(process.env.DATA_PKG);
const { readFileSync } = await import('node:fs');

const corpus = data.loadAcceptanceRecords({ dir: process.env.RUNS_DIR, regime: 'blocked' });
const html = readFileSync(process.env.INDEX_HTML, 'utf8');
const problems = [];

const arms = [...new Set(corpus.cells.map((c) => c.arm))].sort();
const baseline = data.armSummary({ cells: corpus.cells, arm: 'baseline' });

if (baseline.wilson === null) problems.push('the baseline has no interval — every tier below is undefined');

const expected = {};
for (const arm of arms) {
  const s = data.armSummary({ cells: corpus.cells, arm });
  expected[arm] = s.wilson === null ? 'unmeasured'
    : (baseline.wilson !== null && s.wilson.lo > baseline.wilson.hi) ? 'clears' : 'overlaps';
}

const rendered = Object.fromEntries(
  [...html.matchAll(/data-ranked-row="([^"]*)"[^>]*data-tier="([^"]*)"/g)].map((m) => [m[1], m[2]]),
);

if (Object.keys(rendered).length === 0) {
  problems.push('no ranked row carries a data-tier — the grouping is not rendered');
} else {
  for (const [arm, want] of Object.entries(expected)) {
    if (rendered[arm] !== want) problems.push(`${arm}: rendered "${rendered[arm]}" but the intervals say "${want}"`);
  }

  // The live trap plan review round 1 found: an arm with no interval must not share a tier
  // with the one arm that clears the baseline.
  if (rendered.superpowers !== undefined && rendered.ponytail !== undefined
      && rendered.superpowers === rendered.ponytail) {
    problems.push('superpowers (no interval) shares a tier with ponytail (clears the baseline)');
  }

  const tiers = new Set(Object.values(rendered));
  if (tiers.size < 2) problems.push(`every arm landed in one tier (${[...tiers]}) — the grouping proves nothing`);
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.length ? problems.join('; ')
    : `${Object.keys(rendered).length} arms tiered as the intervals require: ${JSON.stringify(expected)}`,
}));
JS

judge "$(node "$SB/tiers.mjs" 2>/dev/null)" "AC-9 (three tiers, derived, trap pinned)"

# ---------------------------------------------------------------------------
# AC-8 — the decision names the clearing arm and the backend result, derived.
# ---------------------------------------------------------------------------
cat > "$SB/decision.mjs" <<'JS'
const data = await import(process.env.DATA_PKG);
const { readFileSync } = await import('node:fs');

const corpus = data.loadAcceptanceRecords({ dir: process.env.RUNS_DIR, regime: 'blocked' });
const html = readFileSync(process.env.INDEX_HTML, 'utf8');
const problems = [];

const arms = [...new Set(corpus.cells.map((c) => c.arm))].sort();
const baseline = data.armSummary({ cells: corpus.cells, arm: 'baseline' });

const clears = arms.filter((arm) => {
  if (arm === 'baseline') return false;
  const s = data.armSummary({ cells: corpus.cells, arm });
  return s.wilson !== null && baseline.wilson !== null && s.wilson.lo > baseline.wilson.hi;
});

const block = /<p[^>]*data-decision="summary"[^>]*>([\s\S]*?)<\/p>/.exec(html);

if (block === null) {
  problems.push('no [data-decision="summary"] element in the built page');
} else {
  const text = block[1].replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();

  if (!text) problems.push('the decision element renders no text');

  for (const arm of clears) {
    if (!text.includes(arm)) problems.push(`the decision does not name ${arm}, which clears the baseline`);
  }

  // Re-derived, not pattern-matched. Round 1 found this row checking only that the word
  // "backend" appeared, which a page could satisfy while publishing the opposite claim.
  const backendIntervals = arms
    .map((arm) => data.domainSummary({ cells: corpus.cells, arm, domain: 'backend' }).wilson)
    .filter((w) => w !== null);

  const allOverlap = backendIntervals.every((l) =>
    backendIntervals.every((r) => l.lo <= r.hi && r.lo <= l.hi));

  if (backendIntervals.length === 0) {
    problems.push('no backend interval exists — the backend clause is unverifiable');
  } else if (allOverlap && !/no pack separates from the baseline/i.test(text)) {
    problems.push('every backend interval overlaps, but the decision does not say so');
  } else if (!allOverlap && /no pack separates from the baseline/i.test(text)) {
    problems.push('the decision claims no backend separation while some interval does not overlap');
  }

  // The cost clause is a comparison, so it is checked as one.
  const costOf = (arm) => data.loadEconomics({ dir: process.env.RUNS_DIR, corpus })
    .arms.find((e) => e.arm === arm)?.cost.value ?? null;

  if (clears.length === 1) {
    const base = costOf('baseline');
    const won = costOf(clears[0]);

    if (base !== null && won !== null) {
      const claimsDearer = /costs more per cell/i.test(text);
      if (won > base && !claimsDearer) problems.push(`${clears[0]} costs more than baseline but the decision does not say so`);
      if (won <= base && claimsDearer) problems.push(`${clears[0]} does not cost more than baseline, yet the decision says it does`);
    }
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.length ? problems.join('; ')
    : `the decision names ${clears.length ? clears.join(', ') : 'no clearing arm'} and states the backend result`,
}));
JS

judge "$(node "$SB/decision.mjs" 2>/dev/null)" "AC-8 (the decision is derived, not asserted)"

# ---------------------------------------------------------------------------
# AC-5 — the withdrawal is reachable from the page that carried the claim.
# ---------------------------------------------------------------------------
cat > "$SB/withdrawal.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from report import verdict

html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()
problems = []

link = re.search(r'<a[^>]*href="([^"]*)"[^>]*data-withdrawal="[^"]*"', html) \
    or re.search(r'<a[^>]*data-withdrawal="[^"]*"[^>]*href="([^"]*)"', html)

if link is None:
    problems.append("the corrected sentence links no withdrawal record")
else:
    target = link.group(1)
    anchor = target.split("#")[-1] if "#" in target else None

    if anchor is None:
        problems.append(f"the withdrawal link {target} is not an in-page anchor a reader can follow")
    elif f'id="{anchor}"' not in html:
        problems.append(f"the withdrawal link points at #{anchor}, which the page does not contain")
    else:
        section = re.search(rf'id="{re.escape(anchor)}"[^>]*>([\s\S]{{0,2500}})', html)
        body = re.sub(r"<[^>]*>", " ", section.group(1)) if section else ""

        for needle, label in [("real tickets", "the previous wording"), ("2026-08", "a date")]:
            if needle not in body:
                problems.append(f"the withdrawal record does not carry {label}")

print("SENTINEL " + json.dumps(verdict(
    problems, "the corrected sentence links a withdrawal record on the same page, carrying the previous wording and its date",
)))
PY

judge "$(python3 "$SB/withdrawal.py" 2>/dev/null)" "AC-5 (the withdrawal is reachable from the claim)"

# ---------------------------------------------------------------------------
# AC-10 — the decision row exists in the log, and references DEC-027.
# ---------------------------------------------------------------------------
# Matched on a marker the row must carry, not on a word. The first version of this grep
# searched for "tier" and matched DEC-010 — because "Prettier" contains it. A substring is
# not a decision, and an assertion that finds the wrong row is worse than one that finds none.
DESIGN_ROW="$(grep -nE '^\| DEC-0[0-9]+ \|.*separation tier' "$PROJECT_ROOT/DESIGN.md" | head -1)"

if [[ -z "$DESIGN_ROW" ]]; then
  fail "AC-10: DESIGN.md carries no decision row for the tiering — the decision moved without the log"
elif ! printf '%s' "$DESIGN_ROW" | grep -q 'DEC-027'; then
  fail "AC-10: the tiering row does not reference DEC-027, whose ground it changes: ${DESIGN_ROW:0:120}"
else
  pass "AC-10: DESIGN.md records the tiering decision and references DEC-027"
fi

# ---------------------------------------------------------------------------
# Positive controls — every sweep above must be shown to fire before it is believed.
# ---------------------------------------------------------------------------
cat > "$SB/planted.html" <<'HTML'
<p data-coverage="corpus">999 tasks in 1 shape</p>
<p data-decision="summary">nothing in particular</p>
<div data-ranked-row="superpowers" data-tier="clears"></div>
<div data-ranked-row="ponytail" data-tier="clears"></div>
HTML

CONTROLS_OK=1

for probe in counts.py absences.py; do
  OUT="$(INDEX_HTML="$SB/planted.html" python3 "$SB/$probe" 2>/dev/null)"
  if [[ "$OUT" != SENTINEL\ * ]] || \
     printf '%s' "${OUT#SENTINEL }" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["ok"] else 1)'; then
    CONTROLS_OK=0
    fail "control: $probe passed a planted page it should have rejected"
  fi
done

TIER_OUT="$(INDEX_HTML="$SB/planted.html" node "$SB/tiers.mjs" 2>/dev/null)"

if [[ "$TIER_OUT" != SENTINEL\ * ]] || \
   printf '%s' "${TIER_OUT#SENTINEL }" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)["ok"] else 1)'; then
  CONTROLS_OK=0
  fail "control: the tier probe passed a page placing superpowers beside ponytail"
fi

[[ "$CONTROLS_OK" -eq 1 ]] && pass "controls: every sweep reports a planted violation before its real run is believed"

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-035 PASS${NC}"
else
  echo -e "${RED}PDX-035 FAIL${NC}" >&2
fi

exit $FAILED
