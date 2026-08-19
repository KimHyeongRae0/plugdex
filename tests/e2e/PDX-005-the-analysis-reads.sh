#!/usr/bin/env bash
# tests/e2e/PDX-005-the-analysis-reads.sh
#
# PDX-005 — the analysis page reads, and every figure on it was derived.
#
# Scenario 1 of two. This one works on built output and on the built packages: does the
# leaderboard render one row per listed pack with figures that recompute, does every rate
# on either page name its population and carry its denominator, do the scatters draw a
# frontier only where a frontier exists, does the radar band reach the interval it claims
# to show, does the grid hold every cell of the published corpus, does the page refuse a
# composite index in writing, and does the DATA-01 walk cover `.tsx`. Scenario 2 drives a
# browser for the things only a rendering engine can answer.
#
# ASSERT-01 throughout. Every probe is a file in the sandbox that prints
# `SENTINEL {"ok": bool, "detail": str}` on its own success path and decides its own
# verdict; a capture that is empty or unprefixed is "the probe did not run", which fails.
# Probes are never inlined into `$(...)`: the shell re-lexes a command substitution, so an
# apostrophe or a parenthesis inside a quoted string silently eats an argument and the
# assertion then reports against the wrong label.
#
# The rule this scenario is most exposed to is the vacuous pass, because it is written
# before the page exists and will therefore never be seen failing for a reason it did not
# name. So: every count carries a floor derived at run time, every negative sweep runs
# only after its positive half found something to sweep, and the AC-2 reader is proven
# against a planted bad fragment before it is trusted against the live pages.
#
# PLAN-01: no arm name, no ticket name, no count, and no expected figure is written down
# here. The ticket's 312 / 229 / 72 are claims `derive.mjs` computes from the built
# `@plugdex/data` and this scenario asserts against the DOM; if the corpus changes, the
# expectations change with it and the assertions stay true statements about the page.
#
# **The reader is PDX-004's, extended — not a second one.** `read_html.py` is lifted
# verbatim out of `tests/e2e/PDX-004-the-catalogue-reads.sh` at run time and imported by
# `read_pages.py`, which adds the page-wide sweep AC-2 needs. One reader, two scenarios: a
# second implementation of "a percentage and its denominator in the same element" is how
# the two drift until one of them is wrong.
#
# ---------------------------------------------------------------------------
# The interface this scenario pins (plan §3, steps 1-5). Every name below is asserted by
# `derive.mjs` and must be exported from the built `@plugdex/data`:
#
#   wilson({ hits, n })                 -> { lo, hi }   fractions in 0..1
#   gradeCell({ cell })                 -> 'invalid' | 'no-code' | 'built' | 'failed' | 'ungraded'
#   armSummary({ cells, arm })          -> { arm, hits, n, wilson, silent, valid, cells }
#   taskSummary({ cells, arm, task })   -> { hits, n, wilson, domain }
#   domainSummary({ cells, arm, domain })-> { hits, n, wilson }
#   cellGrid({ cells })                 -> { squares: [{ arm, task, marks: [{ cell, state }] }],
#                                            totals: { cells, valid, squares, arms, tasks } }
#   loadEconomics({ dir, corpus })      -> { arms: [{ arm, econN, econMissing, cost,
#                                            turns, outputTokens, loc, seconds, shares }] }
#                                          each mean a Measured { value: number|null, n },
#                                          absent when no pooled row carried it
#   paretoFrontier({ points })          -> [{ id, x, y }]   (members, in x order)
#   formatRate({ hits, n, population }) / formatIntervalPercent({ lo, hi }) /
#   formatCountOverCount({ hits, n }) / formatMoney({ usd }) / formatSeconds({ seconds }) /
#   formatTokens({ count }) / formatMeasured({ measured, format })
#
# And the markup contract the built page must satisfy (attributes, never class names, so
# restyling cannot empty an assertion). Every attribute below carries a non-empty value:
# the reader locates an element by an attribute *and* its value, so a bare `data-band`
# renders as an element this scenario cannot see.
#
#   [data-leaderboard-row="<arm>"]      one per listed pack plus baseline
#     [data-rate][data-population]      the rate string, or the words `no graded cell`
#     [data-interval="wilson"]          the Wilson interval, formatted
#     [data-no-code="silent"]           the silent-cell count
#     [data-econ="cost|turns|outputTokens|loc|seconds"]
#   [data-scatter="cost"|"seconds"]     the two trade-off charts
#     path.pareto[d]                    drawn only for a frontier with >= 2 distinct x
#     [data-frontier-note="sole"]       the sentence naming the sole member when it is not
#   [data-radar="<arm>"][data-center-x][data-center-y][data-unit-radius][data-spokes]
#     [data-band="interval"][points] / [data-estimate="point"][points]
#     [data-radar-subtitle="graded"]    carries the graded-cell count
#   [data-counts-cell="<arm>|<task>"]   k/n in ink, every cell
#   [data-square="<arm>|<task>"] > [data-cell-mark="<state>"]
#   [data-composite-index="refused"]    the AC-8 statement
#   <noscript>                          the drawer's one JavaScript dependency, named
# ---------------------------------------------------------------------------
#
# Nothing outside the repository is contacted and nothing is published (CR-01). The site
# is built locally into its own package and read from disk; the AC-9 probe runs the gate
# over a sandbox it plants and deletes.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-005 — the analysis reads"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx005.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export PROJECT_ROOT SB
export REGISTRY_PKG="file://$PROJECT_ROOT/packages/registry/dist/index.js"
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"
export RUNS_DIR="$PROJECT_ROOT/bench/data/runs"
export SITE_DIST="$PROJECT_ROOT/packages/site/dist"
export INDEX_HTML="$SITE_DIST/index.html"
export ANALYSIS_HTML="$SITE_DIST/analysis.html"
export DERIVED="$SB/derived.json"

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

# ---------------------------------------------------------------------------
# Setup — build the site.
#
# Reported rather than swallowed: a build failure must be visible as the reason every
# assertion below then fails, instead of leaving a reader to guess why the HTML is missing.
# ---------------------------------------------------------------------------
if [[ -f "$PROJECT_ROOT/packages/site/package.json" ]]; then
  ( cd "$PROJECT_ROOT" && pnpm --filter @plugdex/site build ) > "$SB/site-build.log" 2>&1 \
    || echo "  (site build failed; see $SB/site-build.log — every assertion below reports the missing output as its cause)" >&2
else
  echo "  (packages/site does not exist yet — every assertion below reports that as its cause)" >&2
fi

# ---------------------------------------------------------------------------
# The shared reader, lifted from PDX-004 rather than rewritten.
#
# If the heredoc marker in that file ever changes, this extraction produces nothing and
# the floor below says so by name — an empty reader must not read as a clean page.
# ---------------------------------------------------------------------------
PDX004_READS="$PROJECT_ROOT/tests/e2e/PDX-004-the-catalogue-reads.sh"

awk "/<<'READER'/{taking=1; next} /^READER\$/{taking=0} taking" "$PDX004_READS" \
  > "$SB/read_html.py" 2>/dev/null

READER_OK=1

for symbol in "def strip_tags" "def _inner" "def _by_attribute" "def rates"; do
  if ! grep -q "$symbol" "$SB/read_html.py" 2>/dev/null; then
    READER_OK=0
  fi
done

if [[ "$READER_OK" -ne 1 ]]; then
  fail "the shared reader could not be lifted from $PDX004_READS — AC-2 and AC-8 below have no reader"
fi

cat > "$SB/report.py" <<'REPORT'
"""One verdict shape for every probe in this scenario.

Two jobs, both learned from reading a RED run. Findings are ordered so a missing artifact
comes first: when the page is not built, every rule below it fails too, and a truncated
list showing six consequences while hiding the cause is a worse report than none. And the
count of what was elided is printed, so nobody reads six findings as all of them.
"""

MISSING = "does not exist"


def verdict(problems, detail, limit=6):
    ordered = ([entry for entry in problems if MISSING in entry]
               + [entry for entry in problems if MISSING not in entry])

    if not ordered:
        return {"ok": True, "detail": detail}

    elided = len(ordered) - limit

    return {
        "ok": False,
        "detail": "; ".join(ordered[:limit]) + (f" (+{elided} more)" if elided > 0 else ""),
    }
REPORT

cat > "$SB/read_pages.py" <<'READER2'
"""PDX-004's reader, extended to sweep whole pages (PDX-005 AC-2).

Nothing here re-implements what `read_html.py` already does. `_inner`, `_by_attribute`
and `strip_tags` are imported from it, and this module adds three things the page-wide
rules need and a card-shaped reader did not:

  * `elements()` — every element with its attributes, its full text, and its **own** text
    (the text directly under it, with every nested element's text removed). Own text is
    what makes the rules per-element rather than per-subtree: `<body>` contains every rate
    on the page, and a rule keyed on subtree text would report the body as a rate carrier
    and the `%`-only half of a split rate as clean. Both directions are wrong.
  * the rate shape — a percentage as a reader reads it. `\\d+%` **and** `\\d+ percent`,
    because the round-2 plan review put the demonstrated bypass through the spelled-out
    form while still carrying the digit.
  * the reader-facing attribute sweep — an imported rate string bound into `aria-label`
    or `title` never becomes element text, and a screen reader is a reader by the gate's
    own argument.

The three rules, exactly as plan §6.5 D2 states them:

  1. an element whose own text carries a percentage carries its denominator there too;
  2. rate-shaped own text appears only inside a `data-rate` / `data-verdict` element;
  3. every `data-rate` element names its population in an attribute and in its own visible
     text, and a `data-verdict="build-rate"` chip's text names the frontend population.
"""
import html
import os
import re
import sys

sys.path.insert(0, os.environ["SB"])

from read_html import _by_attribute, _inner, strip_tags  # noqa: F401  (re-exported)

# A percentage as a reader meets one, both spellings. The word form still carries the
# digit, so refusing to match it would leave the cheapest bypass open.
PERCENT = re.compile(r"\d+(?:\.\d+)?\s*(?:%|percent\b)", re.I)
DENOMINATOR = re.compile(r"\bn\s*=\s*\d+")

OPEN_TAG = re.compile(r"<([a-zA-Z][\w:-]*)((?:\"[^\"]*\"|'[^']*'|[^>\"'])*)>")
ATTRIBUTE = re.compile(r"([:@\w.-]+)\s*=\s*\"([^\"]*)\"")
TAG_TOKEN = re.compile(r"<[^>]*>")

VOID = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
}

# `_inner` stops on the closing tag's *name*, not on its `>`, so every fragment it returns
# ends in a dangling `</span`. PDX-004 never noticed because its assertions are substring
# matches; here the fragment's text is quoted back in findings and compared for emptiness,
# so the dangling half-tag is trimmed at this boundary rather than by editing the shared
# reader out from under the scenario that owns it.
DANGLING = re.compile(r"</?[\w:-]*$")

# A stylesheet's percentages are `color-mix(... 14%, ...)` and a script's are machine
# instructions. Neither is a rendered figure, and the DATA-01 gate exempts both for the
# same reason. Every other element on the page is swept.
NOT_RENDERED_TEXT = {"style", "script"}

READER_FACING_ATTRIBUTES = (
    "alt", "title", "placeholder",
    "aria-label", "aria-description", "aria-valuetext", "aria-roledescription",
)

DECLARED_RATE_ATTRIBUTES = ("data-rate", "data-verdict")
POPULATIONS = ("frontend", "backend")


class Element:
    """One element: what it is, what it says, and where it sits."""

    def __init__(self, tag, attributes, inner, start, end):
        self.tag = tag
        self.attributes = attributes
        self.inner = inner
        self.start = start
        self.end = end

    @property
    def text(self):
        """Everything a reader sees inside this element, nested elements included."""
        return strip_tags(DANGLING.sub("", self.inner))

    @property
    def own_text(self):
        """Only the text directly under this element."""
        kept = []
        depth = 0
        cursor = 0

        for token in TAG_TOKEN.finditer(self.inner):
            if depth == 0:
                kept.append(self.inner[cursor:token.start()])

            raw = token.group(0)
            name = re.match(r"</?\s*([a-zA-Z][\w:-]*)", raw)

            if raw.startswith("</"):
                depth = max(depth - 1, 0)
            elif not raw.endswith("/>") and name and name.group(1).lower() not in VOID:
                depth += 1

            cursor = token.end()

        if depth == 0:
            kept.append(DANGLING.sub("", self.inner[cursor:]))

        return strip_tags(" ".join(kept))

    def declared(self):
        return any(name in self.attributes for name in DECLARED_RATE_ATTRIBUTES)


def text_of(fragment):
    """The visible text of a fragment `_inner` produced, without its dangling half-tag.

    Every probe reads text through this rather than through `strip_tags` directly: the
    dangling `</td` left on the end of a fragment is enough to make an emptiness check
    ("a heat cell that renders no count") true of every cell forever.
    """
    return strip_tags(DANGLING.sub("", fragment))


def read_page(path):
    """The built page, or None when the build did not emit it."""
    if not path or not os.path.exists(path):
        return None

    with open(path, encoding="utf-8") as handle:
        return handle.read()


def elements(markup):
    """Every element of the document, in source order."""
    found = []

    for match in OPEN_TAG.finditer(markup):
        tag = match.group(1)
        attributes = {
            name.lower(): html.unescape(value)
            for name, value in ATTRIBUTE.findall(match.group(2))
        }

        if match.group(0).endswith("/>") or tag.lower() in VOID:
            inner = ""
        else:
            inner = _inner(markup, tag, match.end())

        found.append(Element(tag.lower(), attributes, inner, match.start(),
                             match.end() + len(inner)))

    return found


def rate_shaped(text):
    return bool(PERCENT.search(text)) and bool(DENOMINATOR.search(text))


def sweep(markup, where):
    """Applies the three rules to one document. Returns (problems, carriers, declared)."""
    problems = []
    found = elements(markup)
    declared = [element for element in found if element.declared()]
    carriers = 0

    for element in found:
        if element.tag in NOT_RENDERED_TEXT:
            continue

        text = element.own_text

        if PERCENT.search(text):
            if not DENOMINATOR.search(text):
                problems.append(
                    f"{where}: a <{element.tag}> shows a percentage with no denominator "
                    f"in the same element ({text[:70]!r})"
                )
                continue

            carriers += 1

            # Rule 2 — the declared-element contract. A rate the page did not declare is
            # a rate no attribute-keyed assertion can hold to a population.
            inside = any(
                owner.start <= element.start and element.end <= owner.end
                for owner in declared
            )

            if not inside:
                problems.append(
                    f"{where}: a <{element.tag}> renders a rate outside any "
                    f"data-rate / data-verdict element ({text[:70]!r})"
                )

        # Rule 1, second surface: a rate bound into an attribute never becomes text.
        for name in READER_FACING_ATTRIBUTES:
            value = element.attributes.get(name, "")

            if PERCENT.search(value) and not DENOMINATOR.search(value):
                problems.append(
                    f"{where}: <{element.tag} {name}> carries a percentage with no "
                    f"denominator ({value[:70]!r})"
                )

    # Rule 3 — the population is named twice: once for a machine, once for a reader.
    for element in declared:
        if "data-rate" in element.attributes:
            population = element.attributes.get("data-population", "")

            if population not in POPULATIONS:
                problems.append(
                    f"{where}: a data-rate element carries data-population="
                    f"{population!r}, which names no population"
                )
            elif population.lower() not in element.text.lower():
                problems.append(
                    f"{where}: a data-rate element declares the {population} population "
                    f"but does not say so to a reader ({element.text[:70]!r})"
                )

        if element.attributes.get("data-verdict") == "build-rate":
            if "frontend" not in element.text.lower():
                problems.append(
                    f"{where}: the build-rate chip does not name the frontend population "
                    f"({element.text[:70]!r})"
                )

    return problems, carriers, len(declared)
READER2

# ---------------------------------------------------------------------------
# The derivation. One node run computes every expected figure from the built packages and
# writes them where the markup probes can read them.
#
# Each section records its own failure instead of throwing, so "armSummary is missing"
# reports against AC-1 and AC-5 rather than blanking every assertion in the file with one
# stack trace. The sentinel says the derivation ran; the per-section errors say what it
# could and could not derive.
# ---------------------------------------------------------------------------
cat > "$SB/derive.mjs" <<'JS'
import { writeFileSync } from 'node:fs';

const derived = { errors: {}, sections: [] };

const record = (name, produce) => {
  derived.sections.push(name);

  try {
    derived[name] = produce();
  } catch (error) {
    derived.errors[name] = String(error?.message ?? error).split('\n')[0];
  }
};

const missingFrom = (module, names) =>
  names.filter((name) => typeof module?.[name] !== 'function');

let registry = null;
let data = null;
let importFailure = '';

try {
  registry = await import(process.env.REGISTRY_PKG);
} catch (error) {
  importFailure = `the built @plugdex/registry could not be imported (${String(error).split('\n')[0]})`;
}

try {
  data = await import(process.env.DATA_PKG);
} catch (error) {
  importFailure = `the built @plugdex/data could not be imported (${String(error).split('\n')[0]})`;
}

const need = (names) => {
  if (importFailure) throw new Error(importFailure);

  const missing = missingFrom(data, names);

  if (missing.length > 0) {
    throw new Error(`the built @plugdex/data exports no ${missing.join(', ')}`);
  }
};

let corpus = null;

if (!importFailure) {
  try {
    corpus = data.loadAcceptanceRecords({ dir: process.env.RUNS_DIR, regime: 'blocked' });
  } catch (error) {
    importFailure = `the blocked corpus would not load (${String(error).split('\n')[0]})`;
  }
}

const packIds = () => (registry?.entries ?? []).map((entry) => entry.packId);
const armsOf = () => [...packIds(), 'baseline'];
const tasksOf = () => [...new Set(corpus.cells.map((cell) => cell.task))];

// ---- AC-2: floors only, and only from exports that already exist. -------------------
// Deliberately independent of steps 1-5: AC-2 must fail because the pages do not name a
// population, not because an aggregate function has not been written yet.
record('ac2', () => {
  need(['verdictFor']);

  const buildRate = packIds().filter((packId) =>
    data.verdictFor({ packId, cells: corpus.cells }).verdict === 'build-rate');

  return {
    buildRatePacks: buildRate,
    // Today's card renders two rates; AC-2 adds the backend pair beside them. The floor
    // is what the page already had, so it can only be tripped by a page that lost rates.
    indexRateFloor: buildRate.length * 2,
    analysisRateFloor: buildRate.length,
    populations: ['frontend', 'backend'],
  };
});

// ---- AC-1: the leaderboard, recomputed row by row. ---------------------------------
record('ac1', () => {
  need(['armSummary', 'loadEconomics', 'formatRate', 'formatIntervalPercent',
        'formatCountOverCount', 'formatMeasured', 'formatMoney', 'formatSeconds',
        'formatTokens', 'formatShortfall']);

  const economics = data.loadEconomics({ dir: process.env.RUNS_DIR, corpus });
  const rows = armsOf().map((arm) => {
    const summary = data.armSummary({ cells: corpus.cells, arm });
    const econ = (economics.arms ?? []).find((entry) => entry.arm === arm) ?? null;

    return {
      arm,
      n: summary.n,
      hits: summary.hits,
      graded: summary.n > 0,
      rate: summary.n > 0
        ? data.formatRate({ hits: summary.hits, n: summary.n, population: 'frontend' })
        : null,
      interval: summary.n > 0 ? data.formatIntervalPercent(summary.wilson) : null,
      noCode: data.formatCountOverCount({ hits: summary.silent, n: summary.valid }),
      // Each mean arrives as a Measured, so the expected cell is whatever the join
      // measured *or* the absent marker — the same decision the row itself makes. A cell
      // over rows that carried nothing must read as absent on the page, not as a zero.
      econ: econ === null ? null : {
        cost: data.formatMeasured({
          measured: econ.cost,
          format: ({ value }) => data.formatMoney({ usd: value }),
        }),
        seconds: data.formatMeasured({
          measured: econ.seconds,
          format: ({ value }) => data.formatSeconds({ seconds: value }),
        }),
        outputTokens: data.formatMeasured({
          measured: econ.outputTokens,
          format: ({ value }) => data.formatTokens({ count: value }),
        }),
      },
      // AC-1's denominator clause, derived rather than listed. A mean taken over fewer
      // rows than its arm's pool must print how many; one taken over all of them must
      // print nothing, so this map is the whole expectation in both directions and an
      // arm that grows a shortfall later grows an assertion with it.
      shortfalls: econ === null ? {} : Object.fromEntries(
        ['cost', 'turns', 'outputTokens', 'loc', 'seconds']
          .map((name) => [name, data.formatShortfall({ measured: econ[name], pool: econ.econN })])
          .filter(([, value]) => value !== null),
      ),
      allMeasured: econ === null ? null : econ.econN,
    };
  });

  const withShortfall = rows.filter((row) => Object.keys(row.shortfalls).length > 0);

  return {
    rows,
    expectedRows: rows.length,
    econCells: ['cost', 'turns', 'outputTokens', 'loc', 'seconds'],
    // The assertion below refuses to pass on an empty expectation: if no arm on this corpus
    // has a shortfall, the clause is unexercised and must say so rather than go green.
    armsWithShortfall: withShortfall.length,
  };
});

// ---- AC-3 surface: the join exists and answers over the live corpus. ---------------
record('ac3', () => {
  need(['loadEconomics']);

  const economics = data.loadEconomics({ dir: process.env.RUNS_DIR, corpus });
  const arms = economics.arms ?? [];
  const problems = [];
  const measures = ['cost', 'turns', 'outputTokens', 'loc', 'seconds'];

  if (arms.length < 1) problems.push('the join produced no arm at all');

  for (const arm of armsOf()) {
    const entry = arms.find((candidate) => candidate.arm === arm);

    if (!entry) {
      problems.push(`${arm}: the join produced no economics row`);
      continue;
    }

    if (!(entry.econN > 0)) problems.push(`${arm}: econN is ${String(entry.econN)}`);

    // Published beside the means and asserted with them: `econMissing` is the count of
    // pooled rows that carried no economics at all, and it is the only thing that tells a
    // reader a mean over 52 rows from a mean over 54 of the same arm.
    if (!Number.isInteger(entry.econMissing) || entry.econMissing < 0) {
      problems.push(`${arm}: econMissing is ${String(entry.econMissing)}, not a count of rows`);
    } else if (entry.econMissing > entry.econN) {
      problems.push(
        `${arm}: econMissing is ${String(entry.econMissing)} of ${String(entry.econN)} pooled rows`,
      );
    }

    for (const field of measures) {
      const measured = entry[field];

      // Each mean is a { value, n }. An absent mean is a legitimate answer and is asserted
      // as one rather than skipped — what is refused is a value that is neither a finite
      // number nor an explicit absence, and a denominator that disagrees with it.
      if (typeof measured !== 'object' || measured === null) {
        problems.push(`${arm}: ${field} is ${String(measured)}, not a measured mean`);
        continue;
      }

      const { value, n } = measured;

      if (value !== null && !Number.isFinite(value)) {
        problems.push(`${arm}: ${field} is ${String(value)}, neither a finite number nor absent`);
      }

      if (!Number.isInteger(n) || n < 0 || n > entry.econN) {
        problems.push(
          `${arm}: ${field} claims a mean over ${String(n)} of ${String(entry.econN)} pooled rows`,
        );
      }

      if ((value === null) !== (n === 0)) {
        problems.push(
          `${arm}: ${field} is ${value === null ? 'absent' : 'measured'} but its denominator ` +
            `is ${String(n)}`,
        );
      }

      if (entry.econN - n > entry.econMissing) {
        problems.push(
          `${arm}: ${field} is a mean over ${String(n)} of ${String(entry.econN)} rows, more ` +
            `absent than the ${String(entry.econMissing)} rows econMissing accounts for`,
        );
      }
    }

    // And it is tight: some mean is short by exactly that many rows. A count nobody's
    // denominator reaches is a count that overstates what is missing, which is the same
    // defect as understating it seen from the other side.
    const deepest = Math.max(
      ...measures.map((field) => entry.econN - (entry[field]?.n ?? entry.econN)),
    );

    if (Number.isFinite(deepest) && deepest !== entry.econMissing) {
      problems.push(
        `${arm}: econMissing is ${String(entry.econMissing)} but the thinnest mean is short ` +
          `${String(deepest)} of ${String(entry.econN)} rows`,
      );
    }

    const shares = Object.values(entry.shares ?? {});

    if (shares.length < 2) {
      problems.push(`${arm}: the token shares carry ${shares.length} member(s)`);
    } else {
      const total = shares.reduce((sum, share) => sum + share, 0);

      if (Math.abs(total - 1) > 0.01) {
        problems.push(`${arm}: the token shares sum to ${total.toFixed(3)}, not 1 — they are not fractions`);
      }
    }
  }

  return {
    problems,
    arms: arms.length,
    econN: arms.map((entry) => entry.econN ?? 0),
    econMissing: arms.map((entry) => entry.econMissing),
  };
});

// ---- AC-4: the two frontiers, and whether each one is drawable. --------------------
record('ac4', () => {
  need(['armSummary', 'loadEconomics', 'paretoFrontier']);

  const economics = data.loadEconomics({ dir: process.env.RUNS_DIR, corpus });
  const charts = [
    { kind: 'cost', field: 'cost' },
    { kind: 'seconds', field: 'seconds' },
  ];

  return charts.map(({ kind, field }) => {
    const points = [];

    for (const arm of armsOf()) {
      const summary = data.armSummary({ cells: corpus.cells, arm });
      const econ = (economics.arms ?? []).find((entry) => entry.arm === arm);

      // An arm whose mean was never measured is off the chart rather than at the origin,
      // and the page plots exactly the points this line does. Reading an absence as a zero
      // is what put a second position on a frontier that has one.
      if (summary.n > 0 && econ && econ[field].value !== null) {
        points.push({ id: arm, x: econ[field].value, y: summary.hits / summary.n });
      }
    }

    const frontier = data.paretoFrontier({ points });
    const distinctX = new Set(frontier.map((point) => point.x)).size;

    return {
      kind,
      points: points.length,
      members: frontier.map((point) => point.id),
      vertices: frontier.length,
      // A line needs two distinct x positions. On the live wall-clock chart it has one,
      // and the page owes the reader a sentence rather than an empty chart.
      drawsLine: distinctX >= 2,
      soleMember: distinctX >= 2 ? null : (frontier[0]?.id ?? null),
    };
  });
});

// ---- AC-5: the radars and the counts table. ----------------------------------------
record('ac5', () => {
  need(['armSummary', 'taskSummary', 'formatCountOverCount']);

  const tasks = tasksOf();
  const measured = armsOf().filter((arm) => data.armSummary({ cells: corpus.cells, arm }).n > 0);

  const radars = measured.map((arm) => {
    const summary = data.armSummary({ cells: corpus.cells, arm });

    return {
      arm,
      graded: summary.n,
      spokes: tasks.map((task) => {
        const perTask = data.taskSummary({ cells: corpus.cells, arm, task });

        return {
          task,
          hi: perTask.n > 0 ? perTask.wilson.hi : 0,
          estimate: perTask.n > 0 ? perTask.hits / perTask.n : 0,
        };
      }),
    };
  });

  const counts = [];

  for (const arm of armsOf()) {
    for (const task of tasks) {
      const perTask = data.taskSummary({ cells: corpus.cells, arm, task });

      counts.push({
        key: `${arm}|${task}`,
        text: perTask.n > 0
          ? data.formatCountOverCount({ hits: perTask.hits, n: perTask.n })
          : null,
      });
    }
  }

  return { tasks, radars, counts, expectedCells: counts.length };
});

// ---- AC-6: the corpus totals the grid must hold. -----------------------------------
record('ac6', () => {
  need(['cellGrid', 'gradeCell']);

  const grid = data.cellGrid({ cells: corpus.cells });
  const states = {};

  for (const cell of corpus.cells) {
    const state = data.gradeCell({ cell });
    states[state] = (states[state] ?? 0) + 1;
  }

  const squares = (grid.squares ?? []).map((square) => ({
    key: `${square.arm}|${square.task}`,
    marks: (square.marks ?? []).length,
  }));

  const fullest = squares.reduce(
    (best, square) => (square.marks > (best?.marks ?? 0) ? square : best),
    null,
  );

  return { totals: grid.totals, states, squares: squares.length, fullest };
});

writeFileSync(process.env.DERIVED, JSON.stringify(derived, null, 2), 'utf8');

console.log('SENTINEL ' + JSON.stringify({
  ok: Object.keys(derived.errors).length === 0,
  detail: Object.entries(derived.errors)
    .map(([section, message]) => `${section}: ${message}`)
    .join('; ')
    || `derived expectations for ${derived.sections.join(', ')} from the built packages`,
}));
JS

DERIVE_OUT="$(node "$SB/derive.mjs" 2>"$SB/derive.err")"

if [[ "$DERIVE_OUT" != SENTINEL\ * ]]; then
  # Not judged as an assertion: it is the input to five of them. Reported here so the
  # failures below are readable as one cause rather than five mysteries.
  echo "  (the derivation crashed; the AC probes below report it as their cause)" >&2
  head -5 "$SB/derive.err" 2>/dev/null | sed 's/^/     /' >&2
fi

cat > "$SB/derived.py" <<'PY'
"""Shared access to derive.mjs's output, with the ASSERT-01 floor on the file itself."""
import json
import os


class Missing(Exception):
    pass


def section(name):
    path = os.environ["DERIVED"]

    if not os.path.exists(path):
        raise Missing("the derivation did not run, so nothing could be recomputed")

    with open(path, encoding="utf-8") as handle:
        derived = json.load(handle)

    if name in derived.get("errors", {}):
        raise Missing(derived["errors"][name])

    if name not in derived:
        raise Missing(f"the derivation produced no {name} section")

    return derived[name]
PY

# ---------------------------------------------------------------------------
# AC-1 — the leaderboard is one row per pack, and every figure on it recomputes.
#
# Both sides derived: the row set comes from the built registry plus the baseline arm, and
# every cell's expected text comes from `@plugdex/data`'s own formatters. A row whose rate
# string the site assembled itself will not match one this probe computed.
# ---------------------------------------------------------------------------
cat > "$SB/ac1.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["SB"])

from derived import Missing, section
from report import verdict
from read_pages import _by_attribute, read_page, text_of

problems = []
markup = read_page(os.environ["ANALYSIS_HTML"])

try:
    expected = section("ac1")
except Missing as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

if markup is None:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{os.environ['ANALYSIS_HTML']} does not exist — the analysis page is not built",
    }))
    sys.exit(0)

rows = dict(_by_attribute(markup, "data-leaderboard-row"))
wanted = [row["arm"] for row in expected["rows"]]

if len(wanted) < 2:
    problems.append(f"only {len(wanted)} row(s) expected — an assertion over one row is not an assertion")

if len(rows) != len(wanted):
    problems.append(f"the leaderboard renders {len(rows)} rows, the registry plus baseline is {len(wanted)}")

for row in expected["rows"]:
    arm = row["arm"]
    fragment = rows.get(arm)

    if fragment is None:
        problems.append(f"{arm}: no leaderboard row")
        continue

    text = text_of(fragment)
    rate_elements = _by_attribute(fragment, "data-rate")

    if row["graded"]:
        if not rate_elements:
            problems.append(f"{arm}: the row renders no data-rate element")
        elif row["rate"] not in text:
            problems.append(f"{arm}: the rate cell does not carry {row['rate']!r} ({text[:80]!r})")

        interval = _by_attribute(fragment, "data-interval")

        if not interval:
            problems.append(f"{arm}: the row renders no interval")
        elif row["interval"] not in text_of(interval[0][1]):
            problems.append(f"{arm}: the interval cell does not carry {row['interval']!r}")
    else:
        # The unmeasured arm, found by its derived zero rather than by name (the ticket's
        # own edge case). A rate of 0% here would report a measurement never taken.
        if "no graded cell" not in text.lower():
            problems.append(f"{arm}: has no graded cell but the row does not say so ({text[:80]!r})")

        if "%" in " ".join(text_of(inner) for _, inner in rate_elements):
            problems.append(f"{arm}: has no graded cell but a rate element renders a percentage")

    no_code = _by_attribute(fragment, "data-no-code")

    if not no_code:
        problems.append(f"{arm}: the row renders no no-code count")
    elif row["noCode"] not in text_of(no_code[0][1]):
        problems.append(f"{arm}: the no-code cell does not carry {row['noCode']!r}")

    econ = dict(_by_attribute(fragment, "data-econ"))

    for name in expected["econCells"]:
        if name not in econ:
            problems.append(f"{arm}: the row renders no {name} economics cell")
        elif not text_of(econ[name]).strip():
            problems.append(f"{arm}: the {name} economics cell is empty")

    # The three with a named formatter are matched against it; turns and LOC are asserted
    # non-empty above, because no formatter is specified for them to be matched against.
    if row["econ"] is None:
        problems.append(f"{arm}: the economics join produced no row for this arm")
    else:
        for name, value in row["econ"].items():
            rendered = text_of(econ.get(name, ""))

            if value not in rendered:
                problems.append(f"{arm}: the {name} cell renders {rendered[:40]!r}, not {value!r}")

    # AC-1's denominator clause, both directions. A mean over fewer rows than the pool must
    # print its shortfall; a mean over all of them must not, because a denominator repeated
    # on every cell is one a reader stops seeing on the cells where it changes the claim.
    shortfalls = row["shortfalls"]

    for name in expected["econCells"]:
        rendered = text_of(econ.get(name, ""))
        wanted_note = shortfalls.get(name)

        if wanted_note is None:
            # Structural, not textual: the marker's presence is the claim, so this keeps
            # asserting the right thing if the wording of the denominator ever changes.
            if f'data-shortfall="{name}"' in (econ.get(name, "") or ""):
                problems.append(
                    f"{arm}: the {name} mean used every row in the pool but the cell prints "
                    f"a shortfall ({rendered[:60]!r})"
                )
        elif wanted_note not in rendered:
            problems.append(
                f"{arm}: the {name} mean is {wanted_note!r} but the cell does not say so "
                f"({rendered[:60]!r})"
            )

if expected["armsWithShortfall"] < 1:
    problems.append(
        "no arm on this corpus has a mean over fewer rows than its pool, so AC-1's "
        "denominator clause was not exercised — a passing assertion here would be vacuous"
    )

detail = (
    f"{len(rows)} leaderboard rows, one per listed pack plus baseline; every rate, "
    "interval, no-code count and economics cell recomputed from @plugdex/data; "
    f"{expected['armsWithShortfall']} arm(s) print the denominator their means fell short by"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac1.py" 2>/dev/null)" "AC-1"

# ---------------------------------------------------------------------------
# AC-2 — a rate carries its denominator and names its population, on both pages.
#
# The reader is proven before it is trusted: four planted fragments, three of them the
# shapes the plan's review round drove past the first draft. A reader that passes a known
# bad input is worse than no reader, because it reports a page as clean.
# ---------------------------------------------------------------------------
cat > "$SB/ac2.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["SB"])

from derived import Missing, section
from report import verdict
from read_pages import _by_attribute, read_page, sweep

problems = []

# --- the reader, on planted inputs ---------------------------------------------------
PLANTED = [
    # The round-1 bypass, verbatim: `percentOf` renders a bare rate with no denominator.
    ("percentOf bypass", "<p>40% of deliveries build</p>", False),
    # The same bypass spelled out. It still carries the digit, so it is still a figure.
    ("spelled-out percent", "<p>40 percent of deliveries build</p>", False),
    # A rate the page never declared: honest arithmetic no attribute can hold to a
    # population.
    ("hand-rolled rate", "<span>73% n=22</span>", False),
    # A rate split across children — the `%`-only child is the one that fails.
    ("split rate",
     '<span data-rate="pack" data-population="frontend">frontend <b>73%</b> <b>n=22</b></span>',
     False),
    # A rate bound into an attribute never becomes element text.
    ("attribute-borne rate", '<div aria-label="73% of deliveries"></div>', False),
    # The shape the plan specifies, which must be clean.
    ("declared rate",
     '<span data-rate="pack" data-population="frontend">frontend builds 73% n=22</span>',
     True),
]

for label, fragment, should_pass in PLANTED:
    found, _, _ = sweep(fragment, "planted")

    if should_pass and found:
        problems.append(f"the reader rejects the legitimate {label} fragment: {found[0]}")

    if not should_pass and not found:
        problems.append(f"the reader passes the planted {label} fragment — it does not discriminate")

try:
    floors = section("ac2")
except Missing as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

# --- the same reader, on the live pages ----------------------------------------------
pages = [
    ("dist/index.html", os.environ["INDEX_HTML"], floors["indexRateFloor"]),
    ("dist/analysis.html", os.environ["ANALYSIS_HTML"], floors["analysisRateFloor"]),
]

for where, path, floor in pages:
    markup = read_page(path)

    if markup is None:
        problems.append(f"{where} does not exist, so no rate on it could be examined")
        continue

    found, carriers, declared = sweep(markup, where)
    problems.extend(found)

    if floor < 1:
        problems.append(f"{where}: the derived floor is {floor} — this sweep would pass on an empty page")

    if carriers < floor:
        problems.append(f"{where}: {carriers} rate-carrying elements, fewer than the derived floor of {floor}")

    if declared < 1:
        problems.append(f"{where}: no data-rate / data-verdict element at all")

# --- both populations, side by side, on the card -------------------------------------
index_markup = read_page(os.environ["INDEX_HTML"])

if index_markup is not None:
    cards = dict(_by_attribute(index_markup, "data-pack-id"))

    for pack_id in floors["buildRatePacks"]:
        fragment = cards.get(pack_id)

        if fragment is None:
            problems.append(f"{pack_id}: the catalogue renders no card for a pack with a build rate")
            continue

        populations = {
            population for population, _ in _by_attribute(fragment, "data-population")
        }

        for population in floors["populations"]:
            if population not in populations:
                problems.append(f"{pack_id}: the card shows no {population} rate beside the other")

detail = (
    "the reader rejects every planted bypass and passes the declared shape; on both built "
    "pages every percentage carries its denominator in its own element, every rate sits in "
    "a declared element naming its population, and every card shows both populations"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac2.py" 2>/dev/null)" "AC-2"

# ---------------------------------------------------------------------------
# AC-3 (surface) — the economics join answers over the live corpus.
#
# The join's discipline (records over filenames, the orphan refusal, the withdrawn run) is
# unit-tested where fixtures can contradict each other. What is asserted here is that the
# thing exists, runs on the published corpus, and returns per-arm means with a denominator
# — a page cannot render an average of nothing.
# ---------------------------------------------------------------------------
cat > "$SB/ac3.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["SB"])

from derived import Missing, section
from report import verdict

try:
    result = section("ac3")
except Missing as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

problems = list(result["problems"])

if result["arms"] < 2:
    problems.append(f"the join produced {result['arms']} arm(s) — an assertion over one arm is not an assertion")

# `econMissing` is part of the published contract now that an absent metric is no longer
# read as a measured zero: it is the difference between the rows pooled and the rows each
# mean is actually over, and a join that reports the means without it hands a reader a
# denominator that is not the one the mean used.
missing = result.get("econMissing")

if not isinstance(missing, list) or len(missing) != result["arms"]:
    problems.append(
        f"the join reports econMissing for {0 if not isinstance(missing, list) else len(missing)} "
        f"of its {result['arms']} arms"
    )
elif any(entry is None for entry in missing):
    problems.append("at least one arm reports no econMissing at all")

reported = [entry for entry in (missing or []) if isinstance(entry, int)]

detail = (
    f"the join answers for {result['arms']} arms over the published corpus, each with a "
    f"denominator (econN {min(result['econN'] or [0])} at the floor), an econMissing count "
    f"({sum(reported)} pooled rows across the corpus carry no transcript economics) and token "
    "shares that sum to one"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac3.py" 2>/dev/null)" "AC-3 (surface)"

# ---------------------------------------------------------------------------
# AC-4 — a frontier is drawn where one exists and stated in words where it does not.
#
# The negative half is the whole point of the criterion and is also the half that passes
# on a blank page, so it runs only after the positive half has found the chart it is
# supposed to be judging.
# ---------------------------------------------------------------------------
cat > "$SB/ac4.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])

from derived import Missing, section
from report import verdict
from read_pages import _by_attribute, read_page, text_of

problems = []
markup = read_page(os.environ["ANALYSIS_HTML"])

try:
    charts = section("ac4")
except Missing as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

if markup is None:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{os.environ['ANALYSIS_HTML']} does not exist — neither scatter could be examined",
    }))
    sys.exit(0)

rendered = dict(_by_attribute(markup, "data-scatter"))
PARETO = re.compile(r"<path\b[^>]*\bclass=\"[^\"]*\bpareto\b[^\"]*\"[^>]*>")
COMMAND = re.compile(r"[MLml]")
drawn = 0
stated = 0

if len(charts) < 2:
    problems.append(f"{len(charts)} chart(s) derived — the ticket asks for two trade-off scatters")

for chart in charts:
    kind = chart["kind"]
    fragment = rendered.get(kind)

    # Positive half first: without the chart there is nothing for the negative half of
    # this criterion to be true of.
    if fragment is None:
        problems.append(f"the {kind} scatter is not in the built page")
        continue

    if chart["points"] < 2:
        problems.append(f"the {kind} scatter was derived from {chart['points']} point(s)")

    paths = PARETO.findall(fragment)

    if chart["drawsLine"]:
        if not paths:
            problems.append(f"the {kind} scatter draws no frontier, but one has {chart['vertices']} members")
            continue

        drawn += 1
        geometry = re.search(r"\bd=\"([^\"]*)\"", paths[0])
        vertices = len(COMMAND.findall(geometry.group(1))) if geometry else 0

        if vertices != chart["vertices"]:
            problems.append(
                f"the {kind} frontier draws {vertices} vertices, the derived frontier has "
                f"{chart['vertices']} ({', '.join(chart['members'])})"
            )
    else:
        if paths:
            problems.append(
                f"the {kind} frontier has fewer than two distinct x positions but the "
                "chart draws a line through it anyway"
            )

        note = _by_attribute(fragment, "data-frontier-note")

        if not note:
            problems.append(f"the {kind} scatter draws no frontier and says nothing about why")
        else:
            text = text_of(note[0][1])
            stated += 1

            if not text.strip():
                problems.append(f"the {kind} frontier note renders no text")
            elif chart["soleMember"] and chart["soleMember"] not in text:
                problems.append(
                    f"the {kind} frontier note does not name {chart['soleMember']}, its "
                    f"single member ({text[:70]!r})"
                )

if drawn + stated < len(charts):
    problems.append("at least one scatter neither drew a frontier nor explained its absence")

detail = (
    f"{len(charts)} scatters rendered; {drawn} draw a frontier with the derived vertex "
    f"count and {stated} state in words which single member the frontier is"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac4.py" 2>/dev/null)" "AC-4"

# ---------------------------------------------------------------------------
# AC-5 — the band reaches the interval it claims to show, and every count is printed.
#
# The radar's honesty is the band, so the band is measured rather than looked for: each
# vertex radius must sit on the Wilson `hi` radius within 0.5 viewBox units — the named
# tolerance from plan §7 — which is what "unclipped" means when a machine says it.
# ---------------------------------------------------------------------------
cat > "$SB/ac5.py" <<'PY'
import json, math, os, re, sys

sys.path.insert(0, os.environ["SB"])

from derived import Missing, section
from report import verdict
from read_pages import elements, read_page, text_of

TOLERANCE = 0.5  # viewBox units (plan §7, AC-5 row)

problems = []
markup = read_page(os.environ["ANALYSIS_HTML"])

try:
    expected = section("ac5")
except Missing as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

if markup is None:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{os.environ['ANALYSIS_HTML']} does not exist — no radar could be measured",
    }))
    sys.exit(0)

found = elements(markup)
radars = {element.attributes["data-radar"]: element
          for element in found if "data-radar" in element.attributes}

if len(expected["radars"]) < 1:
    problems.append("no measured pack was derived — this assertion would have no subject")

if len(radars) != len(expected["radars"]):
    problems.append(
        f"the page renders {len(radars)} radars, one per measured pack is "
        f"{len(expected['radars'])}"
    )


def points_of(fragment, attribute):
    for element in elements(fragment):
        if attribute in element.attributes and "points" in element.attributes:
            raw = element.attributes["points"].replace(",", " ").split()

            return [(float(raw[index]), float(raw[index + 1]))
                    for index in range(0, len(raw) - 1, 2)]

    return None


bands_checked = 0

for radar in expected["radars"]:
    arm = radar["arm"]
    element = radars.get(arm)

    if element is None:
        problems.append(f"{arm}: no radar for a pack with graded cells")
        continue

    geometry = element.attributes

    try:
        centre = (float(geometry["data-center-x"]), float(geometry["data-center-y"]))
        unit = float(geometry["data-unit-radius"])
    except (KeyError, ValueError):
        problems.append(f"{arm}: the radar declares no centre and unit radius, so no radius can be checked")
        continue

    spokes = [name for name in geometry.get("data-spokes", "").split(",") if name]

    if spokes != [spoke["task"] for spoke in radar["spokes"]]:
        problems.append(f"{arm}: the radar's spoke order is not the loader's task order")
        continue

    band = points_of(element.inner, "data-band")
    estimate = points_of(element.inner, "data-estimate")

    if band is None or estimate is None:
        problems.append(f"{arm}: the radar renders no band polygon and point-estimate polygon pair")
        continue

    if len(band) != len(spokes) or len(estimate) != len(spokes):
        problems.append(
            f"{arm}: the polygons carry {len(band)} / {len(estimate)} vertices for "
            f"{len(spokes)} spokes"
        )
        continue

    for index, spoke in enumerate(radar["spokes"]):
        measured = math.dist(band[index], centre)
        wanted = spoke["hi"] * unit

        if abs(measured - wanted) > TOLERANCE:
            problems.append(
                f"{arm}/{spoke['task']}: the band vertex sits at {measured:.2f} viewBox "
                f"units, the Wilson hi is {wanted:.2f} — the band is clipped or scaled away"
            )
            break

        estimated = math.dist(estimate[index], centre)

        if estimated - measured > TOLERANCE:
            problems.append(
                f"{arm}/{spoke['task']}: the point estimate reaches past its own interval band"
            )
            break

        bands_checked += 1

    subtitle = [element_.own_text for element_ in elements(element.inner)
                if "data-radar-subtitle" in element_.attributes]

    if not subtitle:
        problems.append(f"{arm}: the radar carries no subtitle")
    elif str(radar["graded"]) not in " ".join(subtitle):
        problems.append(f"{arm}: the subtitle does not carry the graded-cell count ({radar['graded']})")

# The counts table: the same numbers with no angular artefact, and a colour without its
# count is the AC-5 violation the ticket names.
cells = {element.attributes["data-counts-cell"]: element
         for element in found if "data-counts-cell" in element.attributes}

if len(cells) != expected["expectedCells"]:
    problems.append(
        f"the counts table renders {len(cells)} cells, the derived pack x ticket grid is "
        f"{expected['expectedCells']}"
    )

if expected["expectedCells"] < 1:
    problems.append("the derived counts table is empty — this assertion would have no subject")

empty = 0

for entry in expected["counts"]:
    element = cells.get(entry["key"])

    if element is None:
        problems.append(f"{entry['key']}: no counts cell")
        continue

    text = text_of(element.inner)

    if not text.strip():
        empty += 1
        continue

    if entry["text"] is not None and entry["text"] not in text:
        problems.append(f"{entry['key']}: the cell renders {text[:30]!r}, not {entry['text']!r}")

if empty:
    problems.append(f"{empty} counts cells render no text — a tint without its count is the violation")

if bands_checked < 1:
    problems.append("no band vertex was measured — the radar assertion never ran")

detail = (
    f"{len(radars)} radars, {bands_checked} band vertices each within {TOLERANCE} viewBox "
    f"units of their Wilson hi radius, and {len(cells)} counts cells printing k/n in ink"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac5.py" 2>/dev/null)" "AC-5"

# ---------------------------------------------------------------------------
# AC-6 — the grid is the corpus, not a picture of it.
#
# Every total is derived by the loader and the grader at run time; the ticket's 312 / 229 /
# 72 are the claims this derivation makes and the DOM has to match, not constants typed
# into an assertion.
# ---------------------------------------------------------------------------
cat > "$SB/ac6.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["SB"])

from derived import Missing, section
from report import verdict
from read_pages import _by_attribute, elements, read_page

problems = []
markup = read_page(os.environ["ANALYSIS_HTML"])

try:
    expected = section("ac6")
except Missing as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": str(error)}))
    sys.exit(0)

if markup is None:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{os.environ['ANALYSIS_HTML']} does not exist — no grid could be counted",
    }))
    sys.exit(0)

totals = expected["totals"]

for name in ("cells", "valid", "squares", "arms", "tasks"):
    if not isinstance(totals.get(name), int) or totals[name] < 1:
        problems.append(f"the derived corpus reports {name}={totals.get(name)!r}")

marks = [element for element in elements(markup) if "data-cell-mark" in element.attributes]
squares = _by_attribute(markup, "data-square")

if len(marks) != totals.get("cells"):
    problems.append(f"the grid draws {len(marks)} marks for {totals.get('cells')} cells in the corpus")

if len(squares) != totals.get("squares"):
    problems.append(f"the grid draws {len(squares)} squares for {totals.get('squares')} arm x ticket squares")

if expected["squares"] != totals.get("squares"):
    problems.append(
        f"the derivation itself disagrees: {expected['squares']} squares against a "
        f"reported total of {totals.get('squares')}"
    )

empty = [key for key, fragment in squares
         if not [element for element in elements(fragment)
                 if "data-cell-mark" in element.attributes]]

if empty:
    problems.append(f"{len(empty)} squares hold no mark (first: {empty[0]})")

drawn = {}

for mark in marks:
    state = mark.attributes["data-cell-mark"]
    drawn[state] = drawn.get(state, 0) + 1

for state, count in expected["states"].items():
    if drawn.get(state, 0) != count:
        problems.append(f"the grid draws {drawn.get(state, 0)} '{state}' marks, the grader counts {count}")

for state in drawn:
    if state not in expected["states"]:
        problems.append(f"the grid draws a '{state}' mark the grader never returns")

# One repetition, one mark — checked where it bites hardest: the fullest square. A
# majority verdict would collapse exactly here (the ticket's disagreeing-repetitions case).
fullest = expected["fullest"]

if not fullest or fullest.get("marks", 0) < 2:
    problems.append("no square with more than one repetition was derived — the mark-per-rep rule has no subject")
else:
    fragment = dict(squares).get(fullest["key"])

    if fragment is None:
        problems.append(f"{fullest['key']}: the fullest square is not in the grid")
    else:
        inside = [element for element in elements(fragment)
                  if "data-cell-mark" in element.attributes]

        if len(inside) != fullest["marks"]:
            problems.append(
                f"{fullest['key']}: {len(inside)} marks for {fullest['marks']} repetitions "
                "— the square is summarising rather than showing"
            )

if len(marks) < 1:
    problems.append("the grid draws no mark at all — nothing above was an assertion")

detail = (
    f"{len(marks)} marks over {len(squares)} squares: the corpus is {totals.get('cells')} "
    f"cells, {totals.get('valid')} valid, {totals.get('arms')} arms x {totals.get('tasks')} "
    "tickets, no square empty, and each state's count matches the grader"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac6.py" 2>/dev/null)" "AC-6"

# ---------------------------------------------------------------------------
# AC-8 — the refusal is written down, and nothing on the page quietly does it anyway.
#
# The sweep is a proxy and is named as one: it cannot prove no single score exists, only
# that no element says it does. It runs after the positive assertion has found the
# statement, because a grep for absence over a missing page is not an assertion.
# ---------------------------------------------------------------------------
cat > "$SB/ac8.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])

from read_pages import elements, read_page, text_of
from report import verdict

problems = []
markup = read_page(os.environ["ANALYSIS_HTML"])

if markup is None:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{os.environ['ANALYSIS_HTML']} does not exist — the refusal is not on any page",
    }))
    sys.exit(0)

found = elements(markup)
refusals = [element for element in found
            if element.attributes.get("data-composite-index") == "refused"]

if not refusals:
    problems.append("no data-composite-index=\"refused\" element — the page does not state the refusal")
else:
    statement = text_of(refusals[0].inner)

    if not statement.strip():
        problems.append("the composite-index refusal renders no text")
    elif "because" not in statement.lower() and "weight" not in statement.lower():
        problems.append(f"the refusal states no reason ({statement[:80]!r})")

# Only now the negative sweep, over the elements the refusal does not own.
SCORE = re.compile(r"\b(composite (index|score)|overall score|index score|total score|combined score)\b", re.I)
HEADER = re.compile(r"^(score|index|rank|ranking)$", re.I)

if not problems:
    owned = refusals[0]

    for element in found:
        if owned.start <= element.start and element.end <= owned.end:
            continue

        text = element.own_text

        if SCORE.search(text):
            problems.append(f"a <{element.tag}> outside the refusal names a composite score ({text[:60]!r})")

        if element.tag in ("th", "caption") and HEADER.match(text.strip()):
            problems.append(f"a leaderboard header is {text.strip()!r} — a single-score column")

if len(found) < 1:
    problems.append("the page holds no element — the sweep had nothing to read")

detail = (
    "the page states the composite-index refusal with its reason, and no other element "
    "names a composite / overall / index score and no header is a score column "
    "(a proxy for 'no single-score element', not a proof)"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac8.py" 2>/dev/null)" "AC-8"

# ---------------------------------------------------------------------------
# AC-9 (RED-visible half) — the DATA-01 walk covers `.tsx`.
#
# Run over planted sandboxes rather than the live tree, which ships no `.tsx` by design
# (plan §6.5 D1): a walk whose coverage is vacuous today is exactly the walk that has to be
# proven against planted files.
#
# **The clean `.astro` companion is load-bearing.** A tsx-only sandbox already exits
# non-zero printing bare `DATA-01` — the gate's own scanned-file floor fires when the walk
# finds nothing — so a probe matching `DATA-01` over a tsx-only tree would be green before
# the walk was ever widened. The companion gives the walk something legitimate to find, and
# the assertion pins the specific rule id (`DATA-01b`) at the `.tsx` path.
# ---------------------------------------------------------------------------
cat > "$SB/ac9.py" <<'PY'
import json, os, pathlib, shutil, subprocess, sys, tempfile

sys.path.insert(0, os.environ["SB"])

from report import verdict

root = pathlib.Path(os.environ["PROJECT_ROOT"])
gate = root / "scripts" / "check-data.sh"
problems = []

# A clean `.astro`, planted beside every `.tsx` fixture. Layout vocabulary in the
# frontmatter, no digit at any rendered position — the gate must pass this file today and
# after the walk widens.
COMPANION = """---
const gridColumns = 3;
---

<div class="grid">
  <p>a clean companion, so the walk has something legitimate to scan</p>
</div>
"""

# A figure a reader reads, in a JSX text node. `ts.isJsxText` is not `ts.isStringLiteral`,
# which is the hole the plan found: widening the walk without teaching scanner 1 about JSX
# text would ship a `.tsx` that scans clean while rendering a typed rate.
DIGIT_BEARING_TSX = """export const Claim = () => (
  <p className="claim">47% of deliveries build</p>
);
"""

# Layout vocabulary in code, machine-facing attributes in markup, every reader-visible
# string imported. This one must pass, or the walk dies of false positives within a week.
CLEAN_TSX = """import { formatRate } from '@plugdex/data';

const markSize = 8;

export const Mark = ({ rate }: { rate: string }) => (
  <span className="mark" data-mark-size={markSize} style={{ width: markSize }}>
    {rate}
  </span>
);
"""


def run_against(sources):
    """Runs the gate over a planted packages/site tree in a scratch copy of scripts/."""
    sandbox = pathlib.Path(tempfile.mkdtemp())

    try:
        shutil.copytree(root / "scripts", sandbox / "scripts")
        site = sandbox / "packages" / "site" / "src"
        site.mkdir(parents=True)

        # The gate resolves its parsers from `packages/site` by design, so the fixture
        # needs the manifest and a link to the installed modules; without them the gate
        # refuses to run, which is correct behaviour and useless as a fixture.
        shutil.copy(root / "packages" / "site" / "package.json",
                    sandbox / "packages" / "site" / "package.json")
        (sandbox / "node_modules").symlink_to(root / "node_modules")
        (sandbox / "packages" / "site" / "node_modules").symlink_to(
            root / "packages" / "site" / "node_modules")

        for name, text in sources.items():
            target = site / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")

        done = subprocess.run(
            [str(sandbox / "scripts" / "check-data.sh")],
            capture_output=True, text=True, cwd=sandbox,
        )

        return done.returncode, done.stdout + done.stderr
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


if not gate.exists():
    problems.append("scripts/check-data.sh does not exist — the gate script is missing")
elif not os.access(gate, os.X_OK):
    problems.append("scripts/check-data.sh exists but is not executable")
else:
    code, output = run_against({
        "components/Companion.astro": COMPANION,
        "components/Claim.tsx": DIGIT_BEARING_TSX,
    })

    if not output.strip():
        problems.append("the gate printed nothing on the planted .tsx — it did not run")
    elif code == 0:
        problems.append(
            "a typed figure in a .tsx JSX text node was not blocked: the gate exited 0 "
            "over a tree holding it (the walk does not reach .tsx)"
        )
    else:
        # The rule id, not the family. Bare `DATA-01` is what the scanned-file floor
        # prints, so matching it would make this assertion green on a walk that never
        # opened the file.
        if "DATA-01b" not in output:
            problems.append(
                "the gate blocked, but names no DATA-01b — a rendered-position violation "
                f"in a .tsx must be reported as one ({output.strip().splitlines()[-1][:90]!r})"
            )

        if "Claim.tsx" not in output:
            problems.append("the gate blocked without naming the .tsx file it blocked on")

    # The other direction: a clean `.tsx` beside the same companion must pass, or the
    # widened walk is a false-positive machine (plan §9 comment 5 — the `.tsx` must be
    # routed to the code scanner, not the template one).
    code, output = run_against({
        "components/Companion.astro": COMPANION,
        "components/Mark.tsx": CLEAN_TSX,
    })

    if not output.strip():
        problems.append("the gate printed nothing on the clean .tsx — it did not run")
    elif code != 0:
        problems.append(
            "the gate blocked a clean .tsx (layout-vocabulary constants, machine-facing "
            f"attributes, an imported rate): {output.strip().splitlines()[-1][:120]}"
        )

detail = (
    "with a clean .astro companion planted beside it, the gate BLOCKs a digit-bearing JSX "
    "text node as DATA-01b at the .tsx path, and passes a clean .tsx"
)

print("SENTINEL " + json.dumps(verdict(problems, detail)))
PY

judge "$(python3 "$SB/ac9.py" 2>/dev/null)" "AC-9 (gate)"

# ---------------------------------------------------------------------------
# The page reads with JavaScript off. The whole scenario is that assertion — every figure
# above was read out of static markup — and the drawer is the one exception, which the
# ticket requires the page to name rather than to hide.
# ---------------------------------------------------------------------------
cat > "$SB/noscript.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["SB"])

from read_pages import elements, read_page, text_of
from report import verdict

markup = read_page(os.environ["ANALYSIS_HTML"])

if markup is None:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": f"{os.environ['ANALYSIS_HTML']} does not exist",
    }))
    sys.exit(0)

problems = []
notes = [text_of(element.inner) for element in elements(markup) if element.tag == "noscript"]

if not notes:
    problems.append("the page carries no <noscript> naming the drawer as its one JavaScript dependency")
elif not any(note.strip() for note in notes):
    problems.append("the <noscript> renders no text")

print("SENTINEL " + json.dumps(verdict(
    problems,
    "every figure above was read out of static markup, and the drawer's JavaScript "
    "dependency is named in a <noscript>",
)))
PY

judge "$(python3 "$SB/noscript.py" 2>/dev/null)" "AC-6/AC-7 (JavaScript disabled)"

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-005 (reads) PASS${NC}"
else
  echo -e "${RED}PDX-005 (reads) FAIL${NC}" >&2
fi

exit $FAILED
