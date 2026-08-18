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
import { pathToFileURL } from 'node:url';

const siteDir = process.env.SITE_DIR;
const problems = [];

if (!existsSync(join(siteDir, 'package.json'))) {
  problems.push('packages/site does not exist');
}

if (!existsSync(join(siteDir, 'dist', 'index.html'))) {
  problems.push('the site is not built (no dist/index.html)');
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

// Not `if (chromium)`. A guard that skips silently when the binding is undefined reports
// a green preflight for a browser that never opened, which is precisely the DEV-01
// failure this scenario exists to prevent — and it is what this file did until the
// matrix crashed one line later and gave the game away.
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
  detail: problems.join('; ') || 'the site is built and chromium launches',
}));
JS

# Playwright is resolved here rather than imported by bare name inside the probes.
#
# The probes live in a scratch directory, and Node resolves a bare specifier from the
# *module file's* location, not from the working directory — so `cd packages/site && node
# $SB/probe.mjs` does not help, which is what this scenario did until the whole browser
# matrix silently reported "playwright is not importable" and every visual assertion went
# unverified. That is the DEV-01 failure mode exactly: a UI claim nothing rendered.
#
# When the package is absent the variable stays empty and the probe says so by name,
# rather than failing to start and reporting nothing a reader can act on.
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
import { pathToFileURL } from 'node:url';

const playwright = await import(pathToFileURL(process.env.PLAYWRIGHT_MODULE).href);
// CommonJS entry: the named exports live on `.default`. See the preflight probe.
const chromium = playwright.chromium ?? playwright.default?.chromium;

if (!chromium) throw new Error('playwright exposes no chromium — nothing can be rendered');

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

      // Colours are resolved by painting them, not by parsing the computed string.
      //
      // Two reasons, both of which produced false failures before this was rewritten.
      // `getComputedStyle` does not promise `rgb()`: this stylesheet uses `color-mix`,
      // which Chromium reports as `color(srgb 0.086 0.082 0.059 / 0.12)` — channels in
      // 0..1, not 0..255. Reading those as bytes made every chip look near-black and
      // reported 1.15:1 against its own ink. And a semi-transparent background is not a
      // colour a reader sees; what they see is that colour composited over what is
      // behind it. A 1x1 canvas does both correctly, for every syntax CSS may grow.
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

      // The effective background: every ancestor's background composited from the
      // outermost inward, which is the order the compositor paints them.
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

      /** A foreground colour as seen: composited over the ground it sits on. */
      const parse = (value, backdrop) => paint(value, backdrop ?? [255, 255, 255]);

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
        const ground = effectiveBackground(element);
        const fg = parse(style.color, ground);

        if (!fg) continue;

        const ratio = contrast(fg, ground);

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

      // **No pack in this corpus is at or below baseline**, in either condition, so this
      // half of AC-6 cannot be anchored to a live card without making the assertion
      // depend on the measurement coming out a particular way. The markup scenario proves
      // the decidable half — an above-baseline and a below-baseline card build to the same
      // markup skeleton, so no selector can separate them. What is checked here is the
      // property that half cannot see: that every chip on the page resolves to the same
      // computed weight and size, and that the two rates inside a card do too (DEC-016).
      // A below-baseline card, when the corpus ever contains one, is styled by the same
      // rules these assertions pin.
      const chipStyles = chips.map((chip) => getComputedStyle(chip));

      for (const property of ['fontSize', 'fontWeight', 'opacity']) {
        const values = [...new Set(chipStyles.map((style) => String(style[property])))];

        if (values.length > 1) {
          findings.push(
            `chips differ in ${property} (${values.join(', ')}) — a verdict is being ` +
              'given more or less visual weight than another',
          );
        }
      }

      for (const style of chipStyles) {
        if (Number(style.opacity) < 1) {
          findings.push(`a chip is faded to ${style.opacity} — a result rendered as an absence`);
        }
      }

      if (withRates.length < 1) {
        findings.push('no card renders a pair of rates — the two-rate styling has no subject');
      }

      for (const entry of withRates) {
        const packStyle = getComputedStyle(entry.card.querySelector('[data-rate="pack"]'));
        const baselineStyle = getComputedStyle(entry.card.querySelector('[data-rate="baseline"]'));

        for (const property of ['fontSize', 'fontWeight', 'color', 'opacity']) {
          if (String(packStyle[property]) !== String(baselineStyle[property])) {
            findings.push(
              `${entry.card.getAttribute('data-pack-id')}: the two rates differ in ` +
                `${property} (${packStyle[property]} against ${baselineStyle[property]}) — ` +
                'the stylesheet is making the comparison the verdict function refuses to',
            );
          }
        }
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
        const outlineGround = effectiveBackground(trigger);
        const outline = parse(style.outlineColor, outlineGround);

        if (outline) {
          const ratio = contrast(outline, outlineGround);

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

judge "$(cd "$SITE_DIR" && node "$SB/matrix.mjs" 2>"$SB/matrix.err")" "AC-7 + AC-6 (computed style)"

# A probe that crashed says nothing about why unless its stderr survives. Discarding it
# is how "the probe did not run" became the only diagnosis available for a browser matrix
# that had never once executed.
if [[ -s "$SB/matrix.err" ]]; then
  echo "     browser probe stderr (first 5 lines):" >&2
  head -5 "$SB/matrix.err" | sed 's/^/       /' >&2
fi

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-004 (looks right) PASS${NC}"
else
  echo -e "${RED}PDX-004 (looks right) FAIL${NC}" >&2
fi

exit $FAILED
