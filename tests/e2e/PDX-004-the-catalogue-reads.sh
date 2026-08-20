#!/usr/bin/env bash
# tests/e2e/PDX-004-the-catalogue-reads.sh
#
# PDX-004 — the catalogue reads without a bundle.
#
# Scenario 1 of two. This one works on built output and on the built packages: does the
# emitted HTML carry every pack's name, does every rendered rate carry its denominator,
# does the install dialog name the repository a user's `claude plugin install` will
# actually clone from, and is the DATA-01 gate real. Scenario 2 drives a browser for the
# things only a rendering engine can answer.
#
# The load-bearing idea of this ticket is that a number on a card is worth what its
# receipt is worth, so the assertions here are all positive matches over what was
# actually emitted. Nothing is asserted by absence: "no chip is missing its n" is green on
# a page with no chips, which is why every count below carries a floor and the chip
# assertions refuse to run until at least one chip has been found.
#
# ASSERT-01 throughout. Every probe is a file in the sandbox that prints
# `SENTINEL {"ok": bool, "detail": str}` on its own success path and decides its own
# verdict; a capture that is empty or unprefixed is "the probe did not run", which fails.
# Probes are never inlined into `$(...)`: the shell re-lexes a command substitution, so an
# apostrophe or a parenthesis inside a quoted string silently eats an argument and the
# assertion then reports against the wrong label. PDX-016 shipped that bug and caught it.
#
# PLAN-01: no pack name, no verdict-to-pack table, and no golden-case number is written
# down here. Pack names come from the built registry at run time; the AC-6 target is found
# by comparing the two rates each card renders; the DATA-01 case numbers are globbed.
#
# Nothing outside the repository is contacted and nothing is published (CR-01). The site
# is built locally into its own package and read from disk.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-004 — the catalogue reads"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx004.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export PROJECT_ROOT SB
export REGISTRY_PKG="file://$PROJECT_ROOT/packages/registry/dist/index.js"
export DATA_PKG="file://$PROJECT_ROOT/packages/data/dist/index.js"
export SITE_DIST="$PROJECT_ROOT/packages/site/dist"
export INDEX_HTML="$SITE_DIST/index.html"

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
# Reported rather than swallowed: on the untouched tree there is no site package, and a
# build failure must be visible as the reason every assertion below then fails, instead of
# leaving a reader to guess why the HTML is missing.
# ---------------------------------------------------------------------------
if [[ -f "$PROJECT_ROOT/packages/site/package.json" ]]; then
  ( cd "$PROJECT_ROOT" && pnpm --filter @plugdex/site build ) > "$SB/site-build.log" 2>&1 \
    || echo "  (site build failed; see the AC-1 detail below)" >&2
else
  echo "  (packages/site does not exist yet — every assertion below reports that as its cause)" >&2
fi

# The shared reader every markup probe uses. The site emits one article per pack; a card
# is located by its data attributes rather than by class names, so restyling cannot break
# the scenario and a renamed class cannot silently empty it.
cat > "$SB/read_html.py" <<'READER'
"""Parses the built index into cards, with no dependency beyond the standard library.

The contract this reads is the one the ticket states: every card carries its packId, the
chip carries the verdict label with its rate and denominator, and the install dialog names
the upstream repository. Attributes are the contract because they survive restyling.

Every extractor walks matching open/close tags rather than reading to the first `</`.
That is not tidiness: a non-greedy `(.*?)</` stops inside the first nested element, so a
chip whose glyph sits in its own span yields the glyph and nothing else — and an assertion
like "a chip containing % must also contain n=" then passes because the text it examined
was never the chip's text. This scenario shipped that bug for exactly one run.
"""
import html
import os
import re

ANY_VALUE = '[^"]+'


def read_index():
    path = os.environ["INDEX_HTML"]

    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_tags(fragment):
    text = re.sub(r"<[^>]+>", " ", fragment)
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def _inner(markup, tag, start):
    """The markup between a just-matched opening tag and its own closing tag."""
    depth, cursor = 1, start
    token = re.compile(r"</?" + tag + r"\b")

    while depth and cursor < len(markup):
        step = token.search(markup, cursor)

        if not step:
            break

        depth += -1 if step.group(0).startswith("</") else 1
        cursor = step.end()

    return markup[start:cursor]


def _by_attribute(markup, attribute, pattern=ANY_VALUE):
    """Every element carrying the attribute, as (attribute value, inner markup)."""
    found = []
    opening = re.compile(r"<(\w+)[^>]*\b" + attribute + r'="(' + pattern + r')"[^>]*>')

    for match in opening.finditer(markup):
        found.append((match.group(2), _inner(markup, match.group(1), match.end())))

    return found


def cards(markup):
    """Every element carrying data-pack-id, as (packId, inner markup)."""
    return _by_attribute(markup, "data-pack-id")


def rates(fragment):
    """Every rendered rate on a card, as (role, percent, n).

    A rate element declares whose rate it is (`data-rate="pack"` / `data-rate="baseline"`)
    and carries both numbers in its own text. Reading the pair off one element is
    deliberate: a rate whose denominator lives elsewhere on the card is exactly the shape
    AC-3 exists to reject.
    """
    found = []

    for role, inner in _by_attribute(fragment, "data-rate", "pack|baseline"):
        text = strip_tags(inner)
        percent = re.search(r"(\d+(?:\.\d+)?)\s*%", text)
        denominator = re.search(r"n\s*=\s*(\d+)", text)

        if percent and denominator:
            found.append((role, float(percent.group(1)), int(denominator.group(1))))

    return found


def chips(fragment):
    """Every verdict chip on a card, as (verdict, visible text)."""
    return [
        (verdict, strip_tags(inner))
        for verdict, inner in _by_attribute(fragment, "data-verdict")
    ]
READER

# ---------------------------------------------------------------------------
# AC-1 — the catalogue is readable without running anything.
#
# Every display name the built registry exports must be in the raw HTML. The names are
# read from the registry at run time; a hard-coded list here would go stale the first time
# a pack is added and would pass while the page lost one.
# ---------------------------------------------------------------------------
cat > "$SB/ac1.mjs" <<'JS'
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const { entries } = await import(process.env.REGISTRY_PKG);

const dist = process.env.SITE_DIST;
const indexPath = process.env.INDEX_HTML;
const problems = [];

if (entries.length < 1) {
  problems.push('the built registry lists nothing — this probe would have nothing to look for');
}

if (!existsSync(indexPath)) {
  problems.push(`the site is not built: ${indexPath} does not exist`);
} else {
  const markup = readFileSync(indexPath, 'utf8');

  for (const entry of entries) {
    if (!markup.includes(entry.displayName)) {
      problems.push(`'${entry.displayName}' is not in the emitted HTML`);
    }
  }

  // Static by inspection rather than by configuration claim: an adapter would leave a
  // server entrypoint in the output, and a page assembled by client JavaScript would
  // carry the names nowhere but in a bundle.
  const walk = (dir) => readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);

    return statSync(path).isDirectory() ? walk(path) : [path];
  });

  const emitted = walk(dist).map((path) => path.slice(dist.length + 1));
  const serverish = emitted.filter((path) =>
    /^(server|_worker|functions)\b/.test(path) || /entry\.mjs$/.test(path));

  if (serverish.length > 0) {
    problems.push(`the output carries a server entrypoint (${serverish[0]}) — this is not a static build`);
  }

  if (emitted.length < 1) {
    problems.push('the build emitted no files');
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') ||
    `${entries.length} listed packs, every display name present in static HTML with no server entrypoint`,
}));
JS

judge "$(node "$SB/ac1.mjs" 2>/dev/null)" "AC-1"

# ---------------------------------------------------------------------------
# AC-2 — the verdict is derived, never authored.
#
# Called directly against the built export a consumer sees, on synthetic cells. The unit
# tests prove the reasons; this proves the artifact. Every case here is a property of the
# fold, so none of them depends on which packs happen to be measured.
# ---------------------------------------------------------------------------
cat > "$SB/ac2.mjs" <<'JS'
const data = await import(process.env.DATA_PKG);

const problems = [];

if (typeof data.verdictFor !== 'function') {
  console.log('SENTINEL ' + JSON.stringify({
    ok: false,
    detail: 'verdictFor is not exported from the built @plugdex/data',
  }));
  process.exit(0);
}

const { verdictFor } = data;

// One synthetic cell. `wroteCode` and `build` are what the conditions read; everything
// else is filler the parser requires.
const cell = ({ arm, wroteCode, build }) => ({
  cell: `${arm}-${Math.abs(build ? 1 : 0)}-${wroteCode ? 'w' : 'n'}`,
  task: 't',
  arm,
  model: 'haiku',
  rep: 0,
  valid: true,
  wroteCode,
  build,
});

const many = ({ arm, count, wroteCode, builds }) =>
  Array.from({ length: count }, (_, index) =>
    cell({ arm, wroteCode, build: index < builds }));

const baseline = many({ arm: 'baseline', count: 10, wroteCode: true, builds: 5 });

const check = ({ label, cells, packId, claims, expect }) => {
  let got;

  try {
    got = verdictFor({ packId, cells, ...(claims ? { claims } : {}) });
  } catch (error) {
    problems.push(`${label}: verdictFor threw (${String(error)})`);
    return undefined;
  }

  if (got?.verdict !== expect) {
    problems.push(`${label}: got '${String(got?.verdict)}', wanted '${expect}'`);
  }

  return got;
};

// Condition 1 — writes no code unattended, at the 0.8 fraction from the chip table.
check({
  label: 'writes no code',
  packId: 'silent',
  cells: [...baseline, ...many({ arm: 'silent', count: 10, wroteCode: false, builds: 0 })],
  expect: 'no-code',
});

// A pack matching conditions 1 and 2 at once shows 1: detection precedes claim
// verification, because "it does nothing unattended" decides an install on its own.
const both = check({
  label: 'matches two conditions',
  packId: 'silent',
  cells: [...baseline, ...many({ arm: 'silent', count: 10, wroteCode: false, builds: 0 })],
  claims: [{ packId: 'silent', metric: 'tokens', claimed: 50, low: 10, high: 20 }],
  expect: 'no-code',
});

// Condition 3 — both arms, either side of baseline, must return the same verdict with
// both pairs of counts. That the losing arm is not a different verdict is the whole of
// DEC-016.
for (const [label, builds, packId] of [['above baseline', 9, 'strong'], ['below baseline', 1, 'weak']]) {
  const got = check({
    label,
    packId,
    cells: [...baseline, ...many({ arm: packId, count: 10, wroteCode: true, builds })],
    expect: 'build-rate',
  });

  if (got?.verdict === 'build-rate') {
    for (const field of ['builds', 'n', 'baselineBuilds', 'baselineN']) {
      if (typeof got[field] !== 'number') {
        problems.push(`${label}: the verdict carries no ${field}`);
      }
    }

    if (got.n === 10 && got.builds !== builds) {
      problems.push(`${label}: got ${String(got.builds)}/${String(got.n)}, wanted ${builds}/10`);
    }

    if ('rate' in got || 'percent' in got) {
      problems.push(`${label}: the verdict carries a precomputed percentage, so a chip could render a rate with no n`);
    }
  }
}

// Condition 5 — no cells for the pack. It must not render as a zero rate.
const empty = check({ label: 'unmeasured', packId: 'ghost', cells: baseline, expect: 'unmeasured' });

if (empty && ('builds' in empty || 'n' in empty)) {
  problems.push('the unmeasured verdict carries numerator/denominator fields, so a chip could render 0%');
}

// The struck verdict must not be reachable from any input.
if (both && String(both.verdict).includes('detect')) {
  problems.push('a verdict naming detectability was returned — DEC-016 struck that chip');
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') ||
    'the built verdictFor folds the conditions in priority order; both above- and below-baseline arms return the rate verdict with both pairs of counts; the unmeasured case carries no rate to render',
}));
JS

judge "$(node "$SB/ac2.mjs" 2>/dev/null)" "AC-2"

# ---------------------------------------------------------------------------
# AC-3 — every chip carries its n.
#
# The floor is the assertion. "No chip lacks a denominator" is green on a page with no
# chips, which is the exact shape ASSERT-01 exists to reject, so this refuses to judge
# anything until it has found a chip.
# ---------------------------------------------------------------------------
cat > "$SB/ac3.py" <<'PY'
import json, os, sys

sys.path.insert(0, os.environ["SB"])
from read_html import cards, chips, rates, read_index

problems = []
seen_rates = 0
seen_chips = 0

try:
    markup = read_index()
except FileNotFoundError:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": "the site is not built, so no chip could be examined",
    }))
    sys.exit(0)

found = cards(markup)

if not found:
    problems.append("no pack card carries a data-pack-id, so no chip could be located")

for pack_id, fragment in found:
    on_card = chips(fragment)
    seen_chips += len(on_card)

    if not on_card:
        problems.append(f"{pack_id}: the card renders no verdict chip")

    for verdict, text in on_card:
        if not text:
            problems.append(f"{pack_id}: the '{verdict}' chip renders no text")

        # A percentage anywhere in a chip must be accompanied by its denominator in the
        # same element. A denominator elsewhere on the card is a number the reader has to
        # go and find, which is the thing this project objects to.
        if "%" in text and "n=" not in text.replace(" ", ""):
            problems.append(f"{pack_id}: the '{verdict}' chip shows a percentage with no n ({text!r})")

    for role, percent, denominator in rates(fragment):
        seen_rates += 1

        if denominator < 1:
            problems.append(f"{pack_id}: the {role} rate reports n={denominator}")

        if not 0 <= percent <= 100:
            problems.append(f"{pack_id}: the {role} rate reports {percent}%")

if seen_chips < 1:
    problems.append("zero chips found — an assertion over no chips is not an assertion")

detail = (
    f"{len(found)} cards, {seen_chips} chips, {seen_rates} rendered rates; "
    "every percentage carries its denominator in the same element"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac3.py" 2>/dev/null)" "AC-3"

# ---------------------------------------------------------------------------
# AC-4 — the DATA-01 gate is real, and it discriminates.
#
# Run against planted fixtures rather than against the live site: a gate that passes on
# the tree it was written for has been tested on one input. The claim fixture must be
# blocked and the layout fixture must not, because a gate that flags `z-index: 10` is a
# gate somebody disables within a week.
# ---------------------------------------------------------------------------
cat > "$SB/ac4.py" <<'PY'
import json, os, pathlib, re, shutil, subprocess, tempfile

root = pathlib.Path(os.environ["PROJECT_ROOT"])
gate = root / "scripts" / "check-data.sh"
problems = []

if not gate.exists():
    problems.append("scripts/check-data.sh does not exist — the gate script is missing")
elif not os.access(gate, os.X_OK):
    problems.append("scripts/check-data.sh exists but is not executable")
else:
    def run_against(sources):
        """Runs the gate over a planted packages/site tree in a scratch copy of scripts/."""
        sandbox = pathlib.Path(tempfile.mkdtemp())

        try:
            shutil.copytree(root / "scripts", sandbox / "scripts")
            site = sandbox / "packages" / "site" / "src"
            site.mkdir(parents=True)

            # The gate resolves its two parsers from `packages/site`, by design: pinning
            # `@astrojs/compiler` there is what keeps the gate's contract declared rather
            # than inherited from Astro's transitive tree. So the fixture needs the site
            # manifest and a link to the installed modules — without them the gate refuses
            # to run at all, which is correct behaviour and useless as a fixture.
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

    # A claim typed into a component. This is the whole point of the gate.
    code, output = run_against({
        "components/Claim.astro": "---\nconst buildRate = 47;\n---\n<p>{buildRate}</p>\n",
    })

    if not output.strip():
        problems.append("the gate printed nothing on a planted violation — it did not run")
    elif code == 0:
        problems.append("a hardcoded percentage in a component was not blocked")

    # Layout constants, machine-facing attributes, and an element access. Every one of
    # these is legal, and a gate that flags any of them dies of false positives.
    code, output = run_against({
        "components/Layout.astro": (
            "---\nconst gridColumns = 3;\nconst first = cells[3];\nconst pair = list.slice(0, 2);\n---\n"
            '<svg viewBox="0 0 24 24"></svg>\n'
            '<button tabindex="0">copy</button>\n'
            "<style>.grid { z-index: 10; gap: 8px; }</style>\n"
        ),
    })

    if not output.strip():
        problems.append("the gate printed nothing on the clean fixture — it did not run")
    elif code != 0:
        problems.append(
            "the gate blocked a clean layout fixture (grid columns, element access, "
            f"viewBox, tabindex, z-index): {output.strip().splitlines()[-1]}"
        )

    # An empty tree must fail, not pass. A gate reporting zero findings over zero files
    # reads exactly like a gate reporting zero findings over a clean tree.
    code, output = run_against({})

    if code == 0:
        problems.append("the gate PASSed with nothing to scan — a scan of no files is not a clean bill of health")

detail = (
    "the gate blocks a hardcoded percentage, passes layout constants and machine-facing "
    "attributes, and fails rather than passes when it scanned nothing"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac4.py" 2>/dev/null)" "AC-4"

# ---------------------------------------------------------------------------
# AC-5 — the install action names where the code comes from.
#
# SRC-01 rendered, not merely stored. The repository the install will clone from has to be
# in the DOM, per entry, derived from the built registry.
# ---------------------------------------------------------------------------
cat > "$SB/ac5.mjs" <<'JS'
import { existsSync, readFileSync } from 'node:fs';

const { entries } = await import(process.env.REGISTRY_PKG);

const indexPath = process.env.INDEX_HTML;
const problems = [];

if (!existsSync(indexPath)) {
  console.log('SENTINEL ' + JSON.stringify({
    ok: false,
    detail: 'the site is not built, so no install dialog could be read',
  }));
  process.exit(0);
}

const markup = readFileSync(indexPath, 'utf8');

if (entries.length < 1) problems.push('the built registry lists nothing');
if (!markup.includes('claude plugin marketplace add')) {
  problems.push('the marketplace-add command is not in the markup');
}

for (const entry of entries) {
  if (!markup.includes(`claude plugin install ${entry.packId}@plugdex`)) {
    problems.push(`${entry.packId}: the install command is not rendered`);
  }

  const repo = entry.installSource?.repo ?? entry.upstreamRepo?.value ?? '';

  if (!repo) {
    problems.push(`${entry.packId}: the entry names no repository to check for`);
  } else if (!markup.includes(repo)) {
    problems.push(`${entry.packId}: the dialog does not name '${repo}', the repository the install clones from`);
  }
}

// A copy control the reader can act on. Asserted on the attribute the component owns, not
// on a class name.
const copyControls = markup.match(/data-copy-command/g) ?? [];

if (copyControls.length < entries.length) {
  problems.push(`${copyControls.length} copy controls for ${entries.length} packs`);
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.join('; ') ||
    `${entries.length} install dialogs, each with both commands, a copy control, and the upstream repository named in the DOM`,
}));
JS

judge "$(node "$SB/ac5.mjs" 2>/dev/null)" "AC-5"

# ---------------------------------------------------------------------------
# AC-6 — a disappointing result is styled as a result, proven where it is decidable.
#
# **The acceptance criterion could not be met as written, and this is the correction.**
# It asked for a card whose pack rate is at or below baseline's. No pack in this corpus is
# — not in `blocked` (baseline 5/20, lowest pack 6/21) and not in `as-shipped`. An
# assertion that needs the measurement to come out a particular way is an assertion that
# puts pressure on the measurement, and waiting for a disappointing result before the
# disappointing case can be tested is exactly backwards for a project whose whole claim is
# that it publishes nulls.
#
# So the property is proven at the level where it is a property of the code rather than of
# the data: a real Astro build of a planted fixture page that renders the card twice, once
# above baseline and once below. If the component emitted any tag, class or data attribute
# for one and not the other, a stylesheet could key on it — and the skeleton comparison
# below fails. If it emits the same skeleton, no selector can separate them, now or later.
#
# The browser scenario carries the other half in a real renderer: that the two rates a
# card shows resolve to identical computed style.
# ---------------------------------------------------------------------------
cat > "$SB/ac6.py" <<'PY'
import json, os, pathlib, re, shutil, subprocess, tempfile

root = pathlib.Path(os.environ["PROJECT_ROOT"])
site = root / "packages" / "site"
problems = []

FIXTURE = """---
import PackCard from '../components/PackCard.astro';
import type { BuildRateVerdict } from '@plugdex/data';
import type { InstallState } from '@plugdex/registry';

/**
 * Two cards, identical but for the rate: one above the baseline, one below it.
 *
 * Both are given the SAME install state on purpose. PDX-024 added that prop, and a fixture
 * that varied it would let the skeleton differ for a reason this assertion is not about —
 * AC-6 is that the two RATES are indistinguishable to a stylesheet, and holding every other
 * input equal is what keeps the comparison honest.
 */
const state: InstallState = {
  state: 'installs',
  shortHead: '0000000',
  record: {
    pack: 'fixture',
    repo: 'example/fixture',
    cliVersion: 'fixture',
    attemptedAt: '2026-08-18T00:00:00Z',
    upstreamHead: '0000000000000000000000000000000000000000',
    transport: 'https',
    outcome: 'installs',
  },
};

const card = ({ builds, n }: { builds: number; n: number }) => ({
  packId: 'fixture',
  displayName: 'fixture',
  author: { value: 'fixture', tag: 'declared' as const },
  upstreamRepo: 'https://example.invalid/fixture',
  stars: { count: 1, readAt: '2026-08-18' },
  state,
  measuredCommit: '1111111111111111111111111111111111111111',
  verdict: {
    verdict: 'build-rate',
    packId: 'fixture',
    builds,
    n,
    baselineBuilds: 5,
    baselineN: 20,
  } satisfies BuildRateVerdict,
});
---

<ul>
  <PackCard {...card({ builds: 16, n: 22 })} />
  <PackCard {...card({ builds: 2, n: 20 })} />
</ul>
"""


def skeleton(html):
    """Everything a stylesheet could key on: tags with their attributes, no text."""
    return "\n".join(re.sub(r">[^<]*", ">", tag) for tag in re.findall(r"<[a-z][^>]*>", html))


sandbox = pathlib.Path(tempfile.mkdtemp())

try:
    target = sandbox / "site"
    shutil.copytree(site / "src", target / "src")

    for name in ("package.json", "astro.config.mjs", "tsconfig.json"):
        shutil.copy(site / name, target / name)

    (target / "node_modules").symlink_to(site / "node_modules")
    (sandbox / "node_modules").symlink_to(root / "node_modules")
    (target / "src" / "pages" / "ac6-fixture.astro").write_text(FIXTURE, encoding="utf-8")

    # Astro is resolved from the site package rather than assumed at the workspace root:
    # pnpm's isolated linker keeps the real package under `.pnpm/`, and a hardcoded path
    # would break on the next lockfile change in the direction of "the fixture did not
    # build", which reads as a failure of the property rather than of the harness.
    astro_entry = subprocess.run(
        ["node", "-e",
         'const {createRequire} = require("module");'
         'const req = createRequire(process.argv[1] + "/package.json");'
         'console.log(require("path").join(require("path").dirname(req.resolve("astro/package.json")), "astro.js"));',
         str(site)],
        capture_output=True, text=True,
    ).stdout.strip()

    if not astro_entry:
        problems.append("astro is not resolvable from packages/site — the fixture cannot be built")
        astro_entry = "missing"

    build = subprocess.run(
        ["node", astro_entry, "build"],
        capture_output=True, text=True, cwd=target,
    )

    # Astro writes either `ac6-fixture.html` or `ac6-fixture/index.html` depending on the
    # project's `build.format`, and this fixture must not care which.
    page = next(
        (candidate for candidate in (
            target / "dist" / "ac6-fixture.html",
            target / "dist" / "ac6-fixture" / "index.html",
        ) if candidate.exists()),
        target / "dist" / "ac6-fixture.html",
    )

    if not page.exists():
        problems.append(
            "the fixture page did not build, so the property was never rendered: "
            + " | ".join(
                line.strip()
                for line in (build.stderr + "\n" + build.stdout).strip().split("\n")
                if line.strip()
            )[-300:]
        )
    else:
        html = page.read_text(encoding="utf-8")
        cards = re.findall(r"<li class=\"card\".*?</li>", html, flags=re.S)

        if len(cards) != 2:
            problems.append(f"the fixture rendered {len(cards)} cards, expected 2")
        else:
            above, below = cards
            above_skeleton, below_skeleton = skeleton(above), skeleton(below)

            if above == below:
                problems.append("both cards rendered identically — the fixture is not exercising the rate")
            elif above_skeleton != below_skeleton:
                problems.append(
                    "the below-baseline card carries a tag, class or attribute the "
                    "above-baseline one does not, so a stylesheet can key on it"
                )

            if "10% n=20" not in below:
                problems.append("the below-baseline card does not render its own rate")
finally:
    shutil.rmtree(sandbox, ignore_errors=True)

detail = (
    "a real Astro build of an above-baseline and a below-baseline card emits the same "
    "markup skeleton, so no selector can style a disappointing result as an absence"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac6.py" 2>/dev/null)" "AC-6 (markup)"

# ---------------------------------------------------------------------------
# AC-8 — the gate is composed into verify, and the golden set covers it.
#
# The verify output is captured and then searched, never piped into `grep -q`: under
# `pipefail` a grep that exits on its first match kills the producer with SIGPIPE, and the
# assertion then reads a truncated log as a clean run.
# ---------------------------------------------------------------------------
VERIFY_OUT="$(./scripts/verify.sh 2>&1)"
export VERIFY_OUT

cat > "$SB/ac8.py" <<'PY'
import json, os, pathlib, re, subprocess

root = pathlib.Path(os.environ["PROJECT_ROOT"])
output = os.environ.get("VERIFY_OUT", "")
problems = []

if not output.strip():
    problems.append("verify.sh produced no output — its step list cannot be searched")
else:
    if "DATA-01" not in output:
        problems.append("verify.sh ran without a DATA-01 step")

    if "VERIFY PASS" not in output:
        problems.append("verify.sh did not finish green")

# Case numbers are globbed, never written down: a renumbered case would otherwise make
# this assertion quietly test nothing.
cases = []

for path in sorted((root / "tests" / "meta" / "cases").glob("*.sh")):
    match = re.match(r"^(\d+)-site-", path.name)

    if match:
        cases.append(match.group(1))

if len(cases) < 1:
    problems.append("no DATA-01 golden case exists — the gate is untested (GATE-01)")
else:
    replay = subprocess.run(
        [str(root / "scripts" / "check-gates.sh")] + cases,
        capture_output=True, text=True, cwd=root,
    )

    if not (replay.stdout + replay.stderr).strip():
        problems.append("check-gates printed nothing when replaying the DATA-01 cases")
    elif replay.returncode != 0:
        problems.append("check-gates FAILs on cases " + " ".join(cases))

detail = (
    "verify runs the DATA-01 step and finishes green; check-gates replays cases "
    + " ".join(cases) + " green"
)

print("SENTINEL " + json.dumps({"ok": not problems, "detail": "; ".join(problems) or detail}))
PY

judge "$(python3 "$SB/ac8.py" 2>/dev/null)" "AC-8"

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-004 (reads) PASS${NC}"
else
  echo -e "${RED}PDX-004 (reads) FAIL${NC}" >&2
fi

exit $FAILED
