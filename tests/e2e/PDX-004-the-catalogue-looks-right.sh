#!/usr/bin/env bash
# tests/e2e/PDX-004-the-catalogue-looks-right.sh
#
# PDX-004 — the catalogue looks right, in a real browser.
#
# Scenario 2 of two. Everything here needs a rendering engine to answer, which is why it
# is a separate scenario rather than more greps: computed style does not exist outside
# one, and a contrast ratio read off a stylesheet is a claim about what the CSS says
# rather than about what the reader sees. Chromium via Playwright, over the built output
# served by `astro preview`, across {360x740, 1280x800} x {light, dark}.
#
# Three things are checked that a markup scenario structurally cannot:
#
#   1. Colour is never the only carrier. DEC-018 exists because the palette's `no code`
#      hue computes to 2.10:1 on light and 2.51:1 on dark — below both WCAG floors — so
#      chip text and the load-bearing glyph render in ink and the hue is background only.
#      Here that is measured on `getComputedStyle`, not trusted.
#   2. The two rates on a card are styled identically. DEC-016 removed a significance
#      claim from the code; a hue, a weight, or an arrow keyed to which rate is larger
#      would put it straight back through the stylesheet. Asserted on computed values.
#   3. A disappointing result keeps full visual weight (AC-6's other half). The chip is
#      located by comparing the two rendered rates at run time, never by naming a pack.
#
# ASSERT-01: every `page.evaluate` returns a JSON report that the scenario judges, every
# probe prints a sentinel, and every count carries a floor — a matrix that rendered no
# cards must fail rather than report no problems. The preflight fails loudly before any
# browser claim is made, so a missing Playwright reads as "the check did not run" instead
# of as a page that passed.
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

echo "PDX-004 — the catalogue looks right"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx004b.XXXXXX")"
SHOTS="$PROJECT_ROOT/.docs/scratch/pdx-004-browser"
PREVIEW_PID=""

cleanup() {
  [[ -n "$PREVIEW_PID" ]] && kill "$PREVIEW_PID" 2>/dev/null
  rm -rf "$SB"
}
trap cleanup EXIT

export PROJECT_ROOT SB SHOTS
export SITE_DIR="$PROJECT_ROOT/packages/site"
export PORT="4321"
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
# Preflight — the instrument exists before any claim is made about what it saw.
#
# A browser scenario whose browser is missing must say so. The alternative is an empty
# findings list read as a clean page, which is the failure this project has a rule about.
# ---------------------------------------------------------------------------
cat > "$SB/preflight.mjs" <<'JS'
import { existsSync } from 'node:fs';
import { join } from 'node:path';

const siteDir = process.env.SITE_DIR;
const problems = [];

if (!existsSync(join(siteDir, 'package.json'))) {
  problems.push('packages/site does not exist');
}

if (!existsSync(join(siteDir, 'dist', 'index.html'))) {
  problems.push('the site is not built (no dist/index.html)');
}

let chromium;

try {
  ({ chromium } = await import('playwright'));
} catch (error) {
  problems.push(`playwright is not importable: ${String(error).split('\n')[0]}`);
}

if (chromium) {
  try {
    const browser = await chromium.launch();
    await browser.close();
  } catch (error) {
    problems.push(`chromium will not launch: ${String(error).split('\n')[0]}`);
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') || 'the site is built and chromium launches',
}));
JS

# Run from the site package when it exists, so `import('playwright')` resolves against
# that package's own dependencies; from the repository root when it does not, so the probe
# still runs and reports the absence by name. A probe that cannot start reports "did not
# run", which is honest but tells a reader nothing about why.
PREFLIGHT_CWD="$PROJECT_ROOT"
[[ -d "$SITE_DIR" ]] && PREFLIGHT_CWD="$SITE_DIR"

PREFLIGHT="$(cd "$PREFLIGHT_CWD" && node "$SB/preflight.mjs" 2>/dev/null)"
judge "${PREFLIGHT:-}" "preflight"

if [[ "${PREFLIGHT:-}" != SENTINEL\ * ]] || [[ "$PREFLIGHT" == *'"ok": false'* ]] || [[ "$PREFLIGHT" == *'"ok":false'* ]]; then
  # Every remaining assertion depends on the browser. Reporting each one separately would
  # turn one cause into six lines that all say the same thing, so they are named once and
  # the scenario stops.
  fail "the browser matrix did not run: AC-6 (computed style), the contrast floors, the two-rate styling, the keyboard walk, and the screenshots are all unverified"
  echo
  echo -e "${RED}PDX-004 (looks right) FAIL${NC}" >&2
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
  echo -e "${RED}PDX-004 (looks right) FAIL${NC}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# The matrix. One node run drives every combination and returns one report.
# ---------------------------------------------------------------------------
cat > "$SB/matrix.mjs" <<'JS'
import { mkdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const { chromium } = await import('playwright');

// The WCAG floors, held as named constants with their success criteria. 3:1 is quoted
// unrounded in SC 1.4.11 and is not the same thing as "about 3".
const TEXT_CONTRAST_FLOOR = 4.5; // WCAG 2.2 SC 1.4.3 (Contrast (Minimum))
const NON_TEXT_CONTRAST_FLOOR = 3.0; // WCAG 2.2 SC 1.4.11 (Non-text Contrast)

const VIEWPORTS = [
  { name: '360x740', width: 360, height: 740 },
  { name: '1280x800', width: 1280, height: 800 },
];
const SCHEMES = ['light', 'dark'];

const shots = process.env.SHOTS;
mkdirSync(shots, { recursive: true });

const problems = [];
let cardsSeen = 0;
let shotsWritten = 0;

const browser = await chromium.launch();

for (const viewport of VIEWPORTS) {
  for (const colorScheme of SCHEMES) {
    const where = `${viewport.name} ${colorScheme}`;
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      colorScheme,
    });
    const page = await context.newPage();

    await page.goto(process.env.BASE_URL, { waitUntil: 'load' });

    // Everything measured in one pass, in the page, so a value is never read from one
    // render and judged against another.
    const report = await page.evaluate(({ textFloor, nonTextFloor }) => {
      const channel = (value) => {
        const c = value / 255;

        return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
      };

      const luminance = (rgb) =>
        0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2]);

      const parse = (value) => {
        const found = (value || '').match(/[\d.]+/g);

        return found ? found.slice(0, 4).map(Number) : null;
      };

      // The effective background: the first ancestor that actually paints one. A chip
      // with a transparent background sits on whatever is behind it, and that is the
      // pair a reader's eye resolves.
      const effectiveBackground = (element) => {
        let node = element;

        while (node) {
          const parsed = parse(getComputedStyle(node).backgroundColor);

          if (parsed && (parsed.length < 4 || parsed[3] > 0)) return parsed;

          node = node.parentElement;
        }

        return [255, 255, 255];
      };

      const contrast = (fg, bg) => {
        const a = luminance(fg);
        const b = luminance(bg);

        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
      };

      const findings = [];
      const cards = [...document.querySelectorAll('[data-pack-id]')];
      const chips = [...document.querySelectorAll('[data-verdict]')];

      // 1. No horizontal scroll. A catalogue that scrolls sideways at 360px is unusable
      // on the device most people will open it on.
      if (document.documentElement.scrollWidth > window.innerWidth) {
        findings.push(
          `the page scrolls horizontally (${document.documentElement.scrollWidth} > ${window.innerWidth})`,
        );
      }

      // 2. Shape carries the signal (SC 1.4.1), so the chip is readable in greyscale.
      const glyphs = new Map();

      for (const chip of chips) {
        const glyph = (chip.getAttribute('data-glyph') || '').trim();

        if (!glyph) {
          findings.push(`the '${chip.getAttribute('data-verdict')}' chip carries no shape glyph`);
          continue;
        }

        const verdict = chip.getAttribute('data-verdict');

        if (glyphs.has(verdict) && glyphs.get(verdict) !== glyph) {
          findings.push(`the '${verdict}' verdict renders two different glyphs`);
        }

        glyphs.set(verdict, glyph);
      }

      if (glyphs.size > 1 && new Set(glyphs.values()).size !== glyphs.size) {
        findings.push('two verdicts share a glyph, so shape does not distinguish them');
      }

      // 3. Contrast, measured rather than assumed.
      const textTargets = [...chips, document.body];

      for (const element of textTargets) {
        const style = getComputedStyle(element);
        const fg = parse(style.color);

        if (!fg) continue;

        const ratio = contrast(fg, effectiveBackground(element));

        if (ratio < textFloor) {
          const what = element.getAttribute('data-verdict') || element.tagName.toLowerCase();
          findings.push(`${what} text contrast is ${ratio.toFixed(2)}:1, below ${textFloor}:1 (SC 1.4.3)`);
        }
      }

      // 4. The two rates on a card are styled identically. This is DEC-016's live risk:
      // a comparison taken out of the code and put back through the stylesheet.
      for (const card of cards) {
        const packRate = card.querySelector('[data-rate="pack"]');
        const baselineRate = card.querySelector('[data-rate="baseline"]');

        if (!packRate || !baselineRate) continue;

        const a = getComputedStyle(packRate);
        const b = getComputedStyle(baselineRate);

        for (const property of ['fontWeight', 'color', 'fontSize']) {
          if (a[property] !== b[property]) {
            findings.push(
              `${card.getAttribute('data-pack-id')}: the two rates differ in ${property} ` +
                `(${a[property]} vs ${b[property]}) — the card is asserting a comparison`,
            );
          }
        }
      }

      // 5. AC-6's computed half: a pack at or below baseline is styled as a result.
      const rateOf = (card, role) => {
        const element = card.querySelector(`[data-rate="${role}"]`);
        const found = element ? (element.textContent || '').match(/([\d.]+)\s*%/) : null;

        return found ? Number(found[1]) : null;
      };

      const withRates = cards
        .map((card) => ({ card, pack: rateOf(card, 'pack'), baseline: rateOf(card, 'baseline') }))
        .filter((entry) => entry.pack !== null && entry.baseline !== null);

      const below = withRates.filter((entry) => entry.pack <= entry.baseline);
      const above = withRates.filter((entry) => entry.pack > entry.baseline);

      if (below.length < 1) {
        findings.push('no card renders a pack rate at or below baseline — AC-6 has no target here');
      }

      for (const entry of below) {
        const chip = entry.card.querySelector('[data-verdict]');

        if (!chip) {
          findings.push(`${entry.card.getAttribute('data-pack-id')}: no chip to weigh`);
          continue;
        }

        const style = getComputedStyle(chip);

        if (Number(style.opacity) < 1) {
          findings.push(
            `${entry.card.getAttribute('data-pack-id')}: the chip is faded to ${style.opacity} — ` +
              'a disappointing result is rendered as an absence',
          );
        }

        const reference = above[0]?.card.querySelector('[data-verdict]');

        if (reference) {
          const other = getComputedStyle(reference);

          for (const property of ['fontSize', 'fontWeight']) {
            if (style[property] !== other[property]) {
              findings.push(
                `${entry.card.getAttribute('data-pack-id')}: chip ${property} is ${style[property]} ` +
                  `against ${other[property]} on an above-baseline chip`,
              );
            }
          }
        }
      }

      // 6. The focus ring is a non-text contrast target of its own.
      const trigger = document.querySelector('[data-install-trigger]');

      if (!trigger) {
        findings.push('no install trigger is present to focus');
      } else {
        trigger.focus();
        const style = getComputedStyle(trigger);
        const outline = parse(style.outlineColor);

        if (outline) {
          const ratio = contrast(outline, effectiveBackground(trigger));

          if (ratio < nonTextFloor) {
            findings.push(
              `the install control focus ring is ${ratio.toFixed(2)}:1, below ${nonTextFloor}:1 (SC 1.4.11)`,
            );
          }
        }
      }

      return { findings, cards: cards.length, chips: chips.length };
    }, { textFloor: TEXT_CONTRAST_FLOOR, nonTextFloor: NON_TEXT_CONTRAST_FLOOR });

    cardsSeen += report.cards;

    if (report.cards < 1) {
      problems.push(`${where}: the page rendered no cards, so nothing here was measured`);
    }

    if (report.chips < 1) {
      problems.push(`${where}: the page rendered no chips`);
    }

    for (const finding of report.findings) problems.push(`${where}: ${finding}`);

    // Keyboard reachability (AC-7), driven rather than evaluated: the dialog has to open,
    // trap focus, and give it back.
    let reached = false;

    for (let step = 0; step < 25 && !reached; step += 1) {
      await page.keyboard.press('Tab');
      reached = await page.evaluate(() =>
        document.activeElement?.hasAttribute('data-install-trigger') === true);
    }

    if (!reached) {
      problems.push(`${where}: no install control is reachable by Tab within 25 steps`);
    } else {
      await page.keyboard.press('Enter');

      const opened = await page.evaluate(() => {
        const dialog = document.querySelector('dialog[open]');

        return Boolean(dialog && dialog.contains(document.activeElement));
      });

      if (!opened) problems.push(`${where}: Enter did not open a dialog holding focus`);

      await page.keyboard.press('Escape');

      const returned = await page.evaluate(() =>
        !document.querySelector('dialog[open]') &&
        document.activeElement?.hasAttribute('data-install-trigger') === true);

      if (!returned) problems.push(`${where}: Escape did not close the dialog and return focus`);
    }

    const shot = join(shots, `${viewport.name}-${colorScheme}.png`);
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

if (cardsSeen < expected) {
  problems.push('at least one matrix combination rendered nothing');
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') ||
    `${expected} combinations: no horizontal scroll, distinct glyphs per verdict, every text pair at or above ${TEXT_CONTRAST_FLOOR}:1, both rates styled identically, below-baseline chips at full weight, keyboard open/close round trip, ${shotsWritten} screenshots`,
}));
JS

judge "$(cd "$SITE_DIR" && node "$SB/matrix.mjs" 2>/dev/null)" "AC-7 + AC-6 (computed style)"

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-004 (looks right) PASS${NC}"
else
  echo -e "${RED}PDX-004 (looks right) FAIL${NC}" >&2
fi

exit $FAILED
