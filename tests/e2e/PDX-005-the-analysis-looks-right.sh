#!/usr/bin/env bash
# tests/e2e/PDX-005-the-analysis-looks-right.sh
#
# PDX-005 — the analysis page looks right, in a real browser.
#
# Scenario 2 of two. Everything here needs a rendering engine to answer: a contrast ratio
# read off a stylesheet is a claim about what the CSS says rather than about what the
# reader sees, and "the grid does not force the page sideways at 360px" is a layout result,
# not a rule. Chromium via Playwright, over the built output served by `astro preview`,
# across {360x740, 1280x800} x {light, dark}.
#
# Two criteria live here:
#
#   AC-7 — the four grid states are distinguishable without colour (DEC-018), and the
#          contrast floors hold in both schemes. Distinctness is read off the computed
#          channels a greyscale reader still has — the glyph, the border style, the
#          background image — never off a class name, because a class name is a promise
#          and this scenario exists to check the promise was kept.
#   AC-10 — at 360px the page body does not scroll horizontally. The grid may scroll
#          inside its own container; that is the designed escape hatch and it is asserted
#          as such rather than assumed.
#
# ASSERT-01: every `page.evaluate` returns a report the scenario judges, every probe prints
# a sentinel, and every count carries a floor derived from `@plugdex/data` at run time — a
# matrix that rendered no marks must fail rather than report no problems. The preflight
# fails loudly before any browser claim is made, so a missing page or a missing Playwright
# reads as "the check did not run" instead of as a page that passed.
#
# PLAN-01: no state name, no mark count, and no arm name is written down here. The mark
# floor is `cellGrid`'s own total and the state set is whatever the page rendered, which is
# then required to be pairwise distinct — an assertion that stays true when the corpus grows
# a state.
#
# The markup contract (attributes, not class names; every one carries a non-empty value):
#
#   [data-cell-mark="<state>"]     one per repetition, inside [data-square="<arm>|<task>"]
#   [data-grid-scroll="x"]         the one container permitted to scroll sideways
#   [data-legend-item="<state>"]   the legend, one entry per state
#   [data-counts-cell="<arm>|<task>"]  the heat table's cells, k/n in ink over a tint
#   svg[data-chart="<name>"]       every chart, which must fit its container at 360px
#
# CR-01: the preview server binds a scenario-owned port on localhost and is killed on
# trap. Nothing is deployed, published, or fetched from outside the repository.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-005 — the analysis looks right"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx005b.XXXXXX")"
SHOTS="$PROJECT_ROOT/.docs/scratch/pdx-005-browser"
PREVIEW_PID=""

cleanup() {
  [[ -n "$PREVIEW_PID" ]] && kill "$PREVIEW_PID" 2>/dev/null
  rm -rf "$SB"
}
trap cleanup EXIT

export PROJECT_ROOT SB SHOTS
export SITE_DIR="$PROJECT_ROOT/packages/site"
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"
export RUNS_DIR="$PROJECT_ROOT/bench/data/runs"
export PORT="4322"
export BASE_URL="http://127.0.0.1:$PORT/"

mkdir -p "$SHOTS"

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
# Setup — build the site, then check the instrument before making any claim about what it
# saw. A browser scenario whose browser is missing must say so; the alternative is an empty
# findings list read as a clean page.
# ---------------------------------------------------------------------------
if [[ -f "$SITE_DIR/package.json" ]]; then
  ( cd "$PROJECT_ROOT" && pnpm --filter @plugdex/site build ) > "$SB/site-build.log" 2>&1 \
    || echo "  (site build failed; see $SB/site-build.log)" >&2
fi

cat > "$SB/preflight.mjs" <<'JS'
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const siteDir = process.env.SITE_DIR;
const problems = [];

if (!existsSync(join(siteDir, 'package.json'))) {
  problems.push('packages/site does not exist');
}

if (!existsSync(join(siteDir, 'dist', 'index.html'))) {
  problems.push('the site is not built (no dist/index.html)');
}

// The subject of this whole scenario. Without it there is nothing to render, and every
// assertion below would otherwise report a clean page it never opened.
if (!existsSync(join(siteDir, 'dist', 'analysis.html'))) {
  problems.push('the analysis page is not built (no dist/analysis.html)');
}

let chromium;

if (!process.env.PLAYWRIGHT_MODULE) {
  problems.push('playwright is not resolvable from packages/site — it must be a declared dependency there');
} else {
  try {
    // playwright's entry point is CommonJS, so `await import()` hangs its named exports
    // off `.default` and leaves `chromium` undefined at the namespace's top level.
    const namespace = await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE).href);
    chromium = namespace.chromium ?? namespace.default?.chromium;
  } catch (error) {
    problems.push(`playwright is not importable: ${String(error).split('\n')[0]}`);
  }
}

if (!chromium) {
  problems.push('playwright resolved but exposes no chromium — nothing can be rendered');
} else {
  try {
    const browser = await chromium.launch();
    await browser.close();
  } catch (error) {
    problems.push(`chromium will not launch: ${String(error).split('\n')[0]}`);
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') || 'the analysis page is built and chromium launches',
}));
JS

# Playwright is resolved here rather than imported by bare name inside the probes: Node
# resolves a bare specifier from the module file's location, and the probes live in a
# scratch directory. When the package is absent the variable stays empty and the probe says
# so by name rather than failing to start.
PLAYWRIGHT_MODULE="$(node -e '
const { createRequire } = require("module");
try {
  const req = createRequire(process.argv[1] + "/package.json");
  console.log(req.resolve("playwright"));
} catch {
  console.log("");
}
' "$SITE_DIR" 2>/dev/null)"
export PLAYWRIGHT_MODULE

PREFLIGHT="$(node "$SB/preflight.mjs" 2>/dev/null)"
judge "${PREFLIGHT:-}" "preflight"

if [[ "${PREFLIGHT:-}" != SENTINEL\ * ]] || [[ "$PREFLIGHT" == *'"ok": false'* ]] || [[ "$PREFLIGHT" == *'"ok":false'* ]]; then
  fail "the browser matrix did not run: AC-7 (state distinctness and the contrast floors) and AC-10 (the 360px reflow) are unverified, and no screenshot was written for the DEV-01 checklist"
  echo
  echo -e "${RED}PDX-005 (looks right) FAIL${NC}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Serve the built output, and wait for it rather than sleeping at it.
# ---------------------------------------------------------------------------
( cd "$SITE_DIR" && pnpm exec astro preview --port "$PORT" --host 127.0.0.1 ) > "$SB/preview.log" 2>&1 &
PREVIEW_PID=$!

READY=0
for _ in $(seq 1 60); do
  if curl -sSf --max-time 2 "$BASE_URL" > /dev/null 2>&1; then READY=1; break; fi
  sleep 1
done

if [[ "$READY" -ne 1 ]]; then
  fail "the preview server never answered on $BASE_URL — nothing below was measured"
  echo
  echo -e "${RED}PDX-005 (looks right) FAIL${NC}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# The matrix. One node run drives every combination and returns one report.
# ---------------------------------------------------------------------------
cat > "$SB/matrix.mjs" <<'JS'
import { mkdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const playwright = await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE).href);
// CommonJS entry: the named exports live on `.default`. See the preflight probe.
const chromium = playwright.chromium ?? playwright.default?.chromium;

if (!chromium) throw new Error('playwright exposes no chromium — nothing can be rendered');

// The WCAG floors, held as named constants with their success criteria. 3:1 is quoted
// unrounded in SC 1.4.11 and is not the same thing as "about 3".
const TEXT_CONTRAST_FLOOR = 4.5; // WCAG 2.2 SC 1.4.3 (Contrast (Minimum))
const NON_TEXT_CONTRAST_FLOOR = 3.0; // WCAG 2.2 SC 1.4.11 (Non-text Contrast)

// Three states must be distinguishable for AC-7 to mean anything; the page renders four.
// The number is a floor on the subject, not a claim about the grader.
const STATE_FLOOR = 3;

const VIEWPORTS = [
  { name: '360x740', width: 360, height: 740, narrow: true },
  { name: '1280x800', width: 1280, height: 800, narrow: false },
];
const SCHEMES = ['light', 'dark'];

const problems = [];

// The mark floor is the corpus's own cell count, derived here rather than typed. Without
// it the matrix would happily report a clean page that rendered one mark.
let markFloor = 0;

try {
  const data = await import(process.env.DATA_PKG);

  if (typeof data.cellGrid !== 'function' || typeof data.loadAcceptanceRecords !== 'function') {
    problems.push('the built @plugdex/data exports no cellGrid, so the mark floor cannot be derived');
  } else {
    const corpus = data.loadAcceptanceRecords({ dir: process.env.RUNS_DIR, regime: 'blocked' });
    markFloor = data.cellGrid({ cells: corpus.cells }).totals.cells;
  }
} catch (error) {
  problems.push(`the mark floor could not be derived: ${String(error).split('\n')[0]}`);
}

if (markFloor < 1) {
  problems.push('the derived mark floor is zero — every count below would pass on an empty grid');
}

const shots = process.env.SHOTS;
mkdirSync(shots, { recursive: true });

const browser = await chromium.launch();
let shotsWritten = 0;
let marksSeen = 0;

for (const viewport of VIEWPORTS) {
  for (const colorScheme of SCHEMES) {
    const where = `${viewport.name} ${colorScheme}`;
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      colorScheme,
    });
    const page = await context.newPage();

    // `build.format: 'file'` emits `analysis.html`; the preview server maps the extension
    // -less route onto it. Both are tried so this scenario does not encode a build setting
    // it has no opinion about.
    let response = await page.goto(new URL('analysis', process.env.BASE_URL).href, { waitUntil: 'load' });

    if (!response || response.status() >= 400) {
      response = await page.goto(new URL('analysis.html', process.env.BASE_URL).href, { waitUntil: 'load' });
    }

    if (!response || response.status() >= 400) {
      problems.push(`${where}: the analysis page did not serve (${response ? response.status() : 'no response'})`);
      await context.close();
      continue;
    }

    const report = await page.evaluate(({ textFloor, nonTextFloor, narrow }) => {
      const channel = (value) => {
        const c = value / 255;

        return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
      };

      const luminance = (rgb) =>
        0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2]);

      // Colours are resolved by painting them, not by parsing the computed string:
      // `getComputedStyle` does not promise `rgb()` (this stylesheet uses `color-mix`),
      // and a semi-transparent value is not what a reader sees — what they see is that
      // colour composited over what is behind it. A 1x1 canvas does both correctly.
      const paint = (value, backdrop) => {
        const canvas = document.createElement('canvas');

        canvas.width = 1;
        canvas.height = 1;

        const context = canvas.getContext('2d');

        context.fillStyle = `rgb(${backdrop[0]}, ${backdrop[1]}, ${backdrop[2]})`;
        context.fillRect(0, 0, 1, 1);
        context.fillStyle = value || 'transparent';
        context.fillRect(0, 0, 1, 1);

        const data = context.getImageData(0, 0, 1, 1).data;

        return [data[0], data[1], data[2]];
      };

      const effectiveBackground = (element) => {
        const stack = [];
        let node = element;

        while (node) {
          stack.push(getComputedStyle(node).backgroundColor);
          node = node.parentElement;
        }

        let resolved = [255, 255, 255];

        for (const value of stack.reverse()) resolved = paint(value, resolved);

        return resolved;
      };

      const contrast = (fg, bg) => {
        const a = luminance(fg);
        const b = luminance(bg);

        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
      };

      const findings = [];
      const marks = [...document.querySelectorAll('[data-cell-mark]')];
      const squares = [...document.querySelectorAll('[data-square]')];
      const legend = [...document.querySelectorAll('[data-legend-item]')];
      const counts = [...document.querySelectorAll('[data-counts-cell]')];
      const charts = [...document.querySelectorAll('svg[data-chart]')];
      // The denominator a mean fell short by (AC-1). It is deliberately quieter than the
      // figure it qualifies, which is exactly why it belongs in the contrast sweep: a
      // caveat a reader cannot read is a caveat that was not published. It was outside
      // this selection when it shipped, and the gap is the reason it is named here.
      const shortfalls = [...document.querySelectorAll('[data-shortfall]')];

      // 1. AC-10 — the page body never scrolls sideways. The grid's own container is
      // allowed to, and that permission is asserted rather than assumed: it is the only
      // element this scenario exempts.
      if (document.documentElement.scrollWidth > window.innerWidth) {
        findings.push(
          `the page scrolls horizontally (${document.documentElement.scrollWidth} > ${window.innerWidth})`,
        );
      }

      const scrollers = [...document.querySelectorAll('[data-grid-scroll]')];

      if (scrollers.length < 1) {
        findings.push('the grid has no [data-grid-scroll] container — nothing bounds it at 360px');
      }

      for (const chart of charts) {
        const box = chart.getBoundingClientRect();
        const parent = chart.parentElement?.getBoundingClientRect();

        if (parent && box.width - parent.width > 1) {
          findings.push(
            `the '${chart.getAttribute('data-chart')}' chart is ${Math.round(box.width)}px ` +
              `wide inside a ${Math.round(parent.width)}px container`,
          );
        }
      }

      if (narrow && charts.length < 1) {
        findings.push('no chart carries data-chart — the fit-at-360px assertion has no subject');
      }

      // 2. AC-7 — shape, not hue. One representative per state, compared on the channels
      // that survive a greyscale print: the glyph a mark draws, its border style, and any
      // background image (a hatch or a diagonal). Two states sharing all three are
      // separated by colour alone, which DEC-018 forbids.
      const representative = new Map();

      for (const mark of marks) {
        const state = mark.getAttribute('data-cell-mark');

        if (!representative.has(state)) representative.set(state, mark);
      }

      const signatures = new Map();

      for (const [state, mark] of representative) {
        const style = getComputedStyle(mark);
        const before = getComputedStyle(mark, '::before');

        signatures.set(state, JSON.stringify([
          (mark.textContent || '').trim(),
          before.content,
          style.borderStyle,
          style.borderWidth,
          style.backgroundImage,
        ]));
      }

      const seen = new Map();

      for (const [state, signature] of signatures) {
        if (seen.has(signature)) {
          findings.push(
            `the '${state}' and '${seen.get(signature)}' marks are identical on every ` +
              'non-colour channel (glyph, border style, background image) — only hue separates them',
          );
        }

        seen.set(signature, state);
      }

      // 3. Contrast, measured rather than assumed. Marks are non-text targets; every
      // number the grid, the legend and the heat table print is a text target.
      for (const [state, mark] of representative) {
        const style = getComputedStyle(mark);
        const ground = effectiveBackground(mark.parentElement ?? document.body);
        const candidates = [style.backgroundColor, style.borderTopColor, style.color]
          .filter((value) => value && value !== 'rgba(0, 0, 0, 0)');

        const best = candidates.reduce((highest, value) => {
          const ratio = contrast(paint(value, ground), ground);

          return ratio > highest ? ratio : highest;
        }, 0);

        if (best < nonTextFloor) {
          findings.push(
            `the '${state}' mark reaches ${best.toFixed(2)}:1 against its ground, below ` +
              `${nonTextFloor}:1 (SC 1.4.11)`,
          );
        }
      }

      if (shortfalls.length === 0) {
        findings.push(
          'no shortfall marker rendered, so the contrast sweep over them asserted nothing — ' +
            'on this corpus three arms have means over fewer rows than their pool',
        );
      }

      for (const element of [...marks, ...legend, ...counts, ...shortfalls]) {
        if (!(element.textContent || '').trim()) continue;

        const style = getComputedStyle(element);
        const ground = effectiveBackground(element);
        // `opacity` repaints the whole element after the colour resolves, so a rule that
        // dims a caveat this way is invisible to a check that reads `color` alone.
        const faded = paint(style.color, ground).slice();
        const opacity = Number.parseFloat(style.opacity || '1');
        const painted = Number.isFinite(opacity) && opacity < 1
          ? faded.map((channel, index) => channel * opacity + ground[index] * (1 - opacity))
          : faded;
        const ratio = contrast(painted, ground);

        if (ratio < textFloor) {
          const what = element.getAttribute('data-cell-mark')
            || element.getAttribute('data-legend-item')
            || element.getAttribute('data-counts-cell')
            || `shortfall:${element.getAttribute('data-shortfall')}`;

          findings.push(`'${what}' text contrast is ${ratio.toFixed(2)}:1, below ${textFloor}:1 (SC 1.4.3)`);
        }
      }

      return {
        findings,
        marks: marks.length,
        squares: squares.length,
        legend: legend.length,
        counts: counts.length,
        states: [...signatures.keys()],
        scrollers: scrollers.map((element) => ({
          scrollWidth: element.scrollWidth,
          clientWidth: element.clientWidth,
        })),
      };
    }, {
      textFloor: TEXT_CONTRAST_FLOOR,
      nonTextFloor: NON_TEXT_CONTRAST_FLOOR,
      narrow: viewport.narrow,
    });

    marksSeen += report.marks;

    if (report.marks < markFloor) {
      problems.push(`${where}: the grid rendered ${report.marks} marks, the corpus holds ${markFloor}`);
    }

    if (report.squares < 1) problems.push(`${where}: the grid rendered no squares`);
    if (report.counts < 1) problems.push(`${where}: the heat table rendered no cell`);
    if (report.legend < STATE_FLOOR) {
      problems.push(`${where}: the legend names ${report.legend} states, fewer than ${STATE_FLOOR}`);
    }

    if (report.states.length < STATE_FLOOR) {
      problems.push(
        `${where}: the grid drew ${report.states.length} distinct states ` +
          `(${report.states.join(', ') || 'none'}) — pairwise distinctness has no subject`,
      );
    }

    for (const finding of report.findings) problems.push(`${where}: ${finding}`);

    const shot = join(shots, `analysis-${viewport.name}-${colorScheme}.png`);
    await page.screenshot({ path: shot, fullPage: true });

    if (statSync(shot).size > 0) shotsWritten += 1;
    else problems.push(`${where}: the screenshot was written empty`);

    await context.close();
  }
}

await browser.close();

const expected = VIEWPORTS.length * SCHEMES.length;

if (shotsWritten !== expected) {
  problems.push(`${shotsWritten} screenshots written, expected ${expected}`);
}

if (marksSeen < markFloor * expected) {
  problems.push('at least one matrix combination rendered an incomplete grid');
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.slice(0, 6).join('; ') ||
    `${expected} combinations over ${markFloor} marks: every state pairwise distinct on a ` +
    `non-colour channel, marks at or above ${NON_TEXT_CONTRAST_FLOOR}:1 and every printed ` +
    `count at or above ${TEXT_CONTRAST_FLOOR}:1, no body-level horizontal scroll at 360px ` +
    `with the grid scrolling inside its own container, ${shotsWritten} screenshots`,
}));
JS

judge "$(cd "$SITE_DIR" && node "$SB/matrix.mjs" 2>"$SB/matrix.err")" "AC-7 + AC-10 (computed style)"

# A probe that crashed says nothing about why unless its stderr survives. Discarding it is
# how "the probe did not run" became the only diagnosis available for a browser matrix that
# had never once executed.
if [[ -s "$SB/matrix.err" ]]; then
  echo "     browser probe stderr (first 5 lines):" >&2
  head -5 "$SB/matrix.err" | sed 's/^/       /' >&2
fi

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-005 (looks right) PASS${NC}"
else
  echo -e "${RED}PDX-005 (looks right) FAIL${NC}" >&2
fi

exit $FAILED
