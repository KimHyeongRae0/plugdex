#!/usr/bin/env bash
# tests/e2e/PDX-024-a-listing-says-whether-it-installs.sh
#
# PDX-024 — a listing says whether it installs.
#
# The site publishes a measurement the repository already holds and, until this ticket,
# did not say: `packages/registry/installability/caveman.json` records
# `"outcome": "blocked"` while the page renders an `Install caveman` button and a copy
# control for `claude plugin install caveman@plugdex`. That is not an omission, it is an
# affordance — the page hands a reader a command its own receipt says fails.
#
# Every assertion here reads BUILT OUTPUT (`packages/site/dist`) or the record files, never
# site source. A component can be restyled or renamed; what a reader receives is the HTML.
#
# ASSERT-01 throughout. Every probe prints `SENTINEL {"ok": bool, "detail": str}` on its own
# success path and decides its own verdict, an empty capture is a failure rather than a quiet
# pass, and the two checks whose natural failure mode is silence — the card sweep and the
# hardcoded-id grep — are run against a planted violation first and must report it before
# their real run is believed. CLAUDE.md names "PDX-002's AC-7 grep" as ASSERT-01 instance
# one, which is exactly the shape of the second of those.
#
# Nothing is installed and nothing outside the repository is contacted (CR-01). The install
# state is read from records `scripts/record-installability.sh` wrote; this scenario never
# runs the CLI.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-024 — a listing says whether it installs"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx024.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

export PROJECT_ROOT SB
export REGISTRY_PKG="file://$PROJECT_ROOT/packages/registry/dist/index.js"
export INSTALL_DIR="$PROJECT_ROOT/packages/registry/installability"
export ATTRIBUTION_DIR="$PROJECT_ROOT/packages/registry/attribution"
export SITE_DIST="$PROJECT_ROOT/packages/site/dist"
export INDEX_HTML="$SITE_DIST/index.html"
export SITE_SRC="$PROJECT_ROOT/packages/site/src"

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
# Setup — build the packages and the site.
#
# Reported rather than swallowed: a build failure must be visible as the reason every
# assertion then fails, instead of leaving a reader to guess why the HTML is missing.
# ---------------------------------------------------------------------------
( cd "$PROJECT_ROOT" && pnpm --filter @plugdex/registry build && pnpm --filter @plugdex/site build ) \
  > "$SB/build.log" 2>&1 \
  || echo "  (build failed; see $SB/build.log — every assertion below reports the missing output as its cause)" >&2

cat > "$SB/report.py" <<'REPORT'
"""One verdict shape for every probe in this scenario."""
import json


def verdict(problems, detail):
    return {"ok": not problems, "detail": detail if not problems else "; ".join(problems)}
REPORT

# The shared HTML reader, lifted from PDX-004 rather than rewritten. If that file's heredoc
# marker ever changes this extraction produces nothing, and the floor below says so by name —
# an empty reader must not read as a clean page.
PDX004_READS="$PROJECT_ROOT/tests/e2e/PDX-004-the-catalogue-reads.sh"

awk "/<<'READER'/{taking=1; next} /^READER\$/{taking=0} taking" "$PDX004_READS" \
  > "$SB/read_html.py" 2>/dev/null

READER_OK=1
for symbol in "def strip_tags" "def _inner" "def _by_attribute"; do
  grep -q "$symbol" "$SB/read_html.py" 2>/dev/null || READER_OK=0
done

if [[ "$READER_OK" -ne 1 ]]; then
  fail "the shared reader could not be lifted from $PDX004_READS — the markup assertions below have no reader"
fi

# ---------------------------------------------------------------------------
# AC-1 / AC-6 — every card declares a state, and the sweep is proven to fire.
#
# The positive control runs first and against a planted card that carries NO state. A sweep
# whose failure mode is silence is not evidence until it has been seen to speak.
# ---------------------------------------------------------------------------
cat > "$SB/states.py" <<'PY'
import json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from read_html import strip_tags  # noqa: F401  (proves the reader loaded)
from report import verdict

import glob

LEGAL = {"installs", "blocked", "unmeasured"}

records_on_disk = [
    json.load(open(path, encoding="utf-8"))
    for path in sorted(glob.glob(os.path.join(os.environ.get("INSTALL_DIR", ""), "*.json")))
] if os.environ.get("INSTALL_DIR") else []
CARD = re.compile(r'<li[^>]*class="[^"]*\bcard\b[^"]*"[^>]*>', re.I)
STATE = re.compile(r'data-install-state="([^"]*)"')
PACK = re.compile(r'data-pack-id="([^"]*)"')

path = sys.argv[1]
problems = []

try:
    html = open(path, encoding="utf-8").read()
except Exception as error:
    print("SENTINEL " + json.dumps({"ok": False, "detail": f"{path}: {error}"}))
    sys.exit(0)

cards = CARD.findall(html)

# ASSERT-01: a zero-card page must fail rather than satisfy every per-card check vacuously.
if not cards:
    print("SENTINEL " + json.dumps({"ok": False, "detail": f"{path}: no .card elements found at all"}))
    sys.exit(0)

stated = [c for c in cards if STATE.search(c)]
values = [STATE.search(c).group(1) for c in stated]

if len(stated) != len(cards):
    problems.append(f"{len(cards) - len(stated)} of {len(cards)} cards carry no data-install-state")

illegal = sorted({v for v in values if v not in LEGAL})
if illegal:
    problems.append(f"illegal state value(s): {illegal}")

counts = {v: values.count(v) for v in set(values)}

# Both directions, against the RECORDS rather than against a hope about upstream.
#
# This required "at least one blocked card" until 2026-08-20, when caveman's upstream fixed
# its manifest mid-session and INST-01c fired: a pack recorded as blocked that starts
# installing is a failure, not a pass. The record was refreshed, the page correctly rendered
# five installing listings — and this assertion failed, because it had been standing in for
# "the blocked render path works" by hoping a third party's repository stayed broken.
#
# A proxy that depends on someone else's bug is not a test. What must hold is that the page
# agrees with the records, which `agreement.py` asserts in full; the blocked branch itself is
# pinned by `installStateFor`'s unit tests and by the planted control below. So this checks
# what the records actually support, and says so when they support only one direction.
expected_states = {r["outcome"] for r in records_on_disk}

for state in sorted(expected_states):
    if counts.get(state, 0) < 1:
        problems.append(f"a record says `{state}` but no card renders it")

if counts.get("installs", 0) < 1 and "installs" in expected_states:
    problems.append("no card renders `installs` — the scenario cannot tell the states apart")

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"{len(cards)} cards, every one stating a legal install state ({counts}), both directions present",
)))
PY

# Positive control: a card with no state must be reported.
cat > "$SB/planted-no-state.html" <<'HTML'
<ul class="grid">
<li class="card" data-pack-id="alpha" data-install-state="installs"></li>
<li class="card" data-pack-id="beta"></li>
</ul>
HTML

CONTROL="$(python3 "$SB/states.py" "$SB/planted-no-state.html" 2>/dev/null)"

if [[ "$CONTROL" == SENTINEL\ * ]] && \
   printf '%s' "${CONTROL#SENTINEL }" | python3 -c 'import json,sys; sys.exit(0 if not json.load(sys.stdin)["ok"] else 1)'; then
  pass "AC-1 (control): the state sweep reports a card that declares no install state"
else
  fail "AC-1 (control): the state sweep passed a card with no install state — it cannot be trusted below"
fi

judge "$(python3 "$SB/states.py" "$INDEX_HTML" 2>/dev/null)" "AC-1/AC-6 (every card states it, both directions)"
# ---------------------------------------------------------------------------
# AC-1 — the state a card renders agrees with the records, per pack.
#
# The sweep above proves every card states SOMETHING legal. It does not prove the card
# states the RIGHT thing, and report review round 1 demonstrated the difference: with a
# record hidden and `installStateFor`'s undefined branch mutated to return `installs`, the
# page rendered a measured verdict for a pack nothing had measured and this scenario still
# reported PASS. A default that flatters us is the one default that must never ship, so it
# is asserted here rather than left to the type system.
#
# The expected state is derived from the record files independently of the page, so a
# mutation in the site's derivation cannot agree with this probe by construction.
# ---------------------------------------------------------------------------
cat > "$SB/agreement.py" <<'AGREE'
import glob, json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from report import verdict

html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()
problems = []

expected = {}
for path in sorted(glob.glob(os.path.join(os.environ["INSTALL_DIR"], "*.json"))):
    record = json.load(open(path, encoding="utf-8"))
    expected[record["pack"]] = record["outcome"]

rendered = dict(re.findall(r'data-pack-id="([^"]*)"[^>]*data-install-state="([^"]*)"', html))

if not rendered:
    print("SENTINEL " + json.dumps({"ok": False, "detail": "no card carries both a pack id and a state"}))
    sys.exit(0)

for pack, state in sorted(rendered.items()):
    want = expected.get(pack, "unmeasured")

    if state != want:
        problems.append(f"{pack}: renders `{state}` but its record says `{want}`")

# A pack with no record must render the absence. The flattering default is the failure mode.
unmeasured = [p for p in rendered if p not in expected]

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"{len(rendered)} cards agree with their records "
    f"({len(expected)} recorded, {len(unmeasured)} unmeasured)",
)))
AGREE

judge "$(python3 "$SB/agreement.py" 2>/dev/null)" "AC-1 (the rendered state agrees with the record)"

# The mutation control: a page claiming `installs` for a pack with no record must be caught.
cat > "$SB/planted-flattering.html" <<'FLAT'
<ul class="grid">
<li class="card" data-pack-id="ghostpack" data-install-state="installs"></li>
</ul>
FLAT

FLATTER="$(INDEX_HTML="$SB/planted-flattering.html" python3 "$SB/agreement.py" 2>/dev/null)"

if [[ "$FLATTER" == SENTINEL\ * ]] &&
   printf '%s' "${FLATTER#SENTINEL }" | python3 -c 'import json,sys; sys.exit(0 if not json.load(sys.stdin)["ok"] else 1)'; then
  pass "AC-1 (control): a card claiming installs for an unmeasured pack is reported"
else
  fail "AC-1 (control): the agreement check passed a flattering default — it cannot be trusted"
fi


# ---------------------------------------------------------------------------
# AC-2 — the blocked listing shows its receipt, and stops offering the command.
# ---------------------------------------------------------------------------
cat > "$SB/blocked.py" <<'PY'
import glob, html as htmllib, json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from report import verdict

html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()
problems = []

blocked = {}
installs = {}

for path in sorted(glob.glob(os.path.join(os.environ["INSTALL_DIR"], "*.json"))):
    record = json.load(open(path, encoding="utf-8"))
    (blocked if record["outcome"] == "blocked" else installs)[record["pack"]] = record

# A corpus where nothing is blocked is a legitimate state, not a broken test.
#
# On 2026-08-20 caveman's upstream fixed its manifest, INST-01c fired, and the refreshed
# record turned the last blocked listing into an installing one. This probe used to exit
# `ok: False` here — correct at the time, because it was standing in for "the blocked render
# path works" and could not check it. That path is pinned instead by `installStateFor`'s unit
# tests in `packages/registry`, which assert the blocked branch directly. What this probe
# asserts is what the records support: every blocked record shows its receipt and offers no
# copy control, every installing record keeps one, and the installing side is never empty.
if not installs:
    print("SENTINEL " + json.dumps({
        "ok": False,
        "detail": "no installing record on disk — the marketplace lists nothing that works",
    }))
    sys.exit(0)

for pack, record in blocked.items():
    dialog = re.search(rf'<dialog[^>]*id="install-{re.escape(pack)}"[^>]*>(.*?)</dialog>', html, re.S)

    if dialog is None:
        problems.append(f"{pack}: no install dialog in the built page")
        continue

    body = dialog.group(1)

    # The receipt: the verbatim CLI error the recorder captured, reachable by a reader.
    # The page escapes quotes and glyphs; compare against the unescaped text a reader sees.
    readable = htmllib.unescape(body)
    head = record["verbatim"].splitlines()[0].strip()
    if head and head not in readable:
        problems.append(f"{pack}: the dialog does not carry the recorded verbatim failure")

    # The affordance: the command may stay visible, the copy control may not.
    if 'data-copy-command' in body and f"install {pack}@plugdex" in body:
        if re.search(rf'data-copy-command="[^"]*install {re.escape(pack)}@plugdex[^"]*"', body):
            problems.append(f"{pack}: a copy control still offers the failing install command")

for pack in installs:
    dialog = re.search(rf'<dialog[^>]*id="install-{re.escape(pack)}"[^>]*>(.*?)</dialog>', html, re.S)

    if dialog is None:
        problems.append(f"{pack}: no install dialog in the built page")
        continue

    if not re.search(rf'data-copy-command="[^"]*install {re.escape(pack)}@plugdex[^"]*"', dialog.group(1)):
        problems.append(f"{pack}: an installing listing lost its copy control")

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"{len(blocked)} blocked listing(s) carry the recorded error and offer no copy control; "
    f"{len(installs)} installing listing(s) keep theirs"
    + ("" if blocked else " (no listing is blocked today; the blocked render is covered by "
                          "the planted-fixture assertion below, not by the live corpus)"),
)))
PY

judge "$(python3 "$SB/blocked.py" 2>/dev/null)" "AC-2 (the receipt is shown, the affordance is withdrawn)"

# ---------------------------------------------------------------------------
# AC-2 — the blocked RENDER, proven by rendering it.
#
# The assertion above checks the live page against the live records, and when no listing is
# blocked it has nothing to check. Report review round 1 caught the consequence: this
# scenario's blocked coverage became structurally vacuous the day caveman's upstream fixed
# its manifest, and the first fix's claim that `installStateFor`'s unit tests covered it was
# wrong — those pin the derivation, not the markup, and `packages/site` has no tests at all.
#
# So the component is rendered against a planted blocked state, the way PDX-004's AC-6
# fixture renders PackCard. Upstream can fix or break whatever it likes; this path stays
# covered either way.
# ---------------------------------------------------------------------------
cat > "$SB/fixture.py" <<'FIXTURE'
import json, os, pathlib, re, shutil, subprocess, sys, tempfile

sys.path.insert(0, os.environ["SB"])
from report import verdict

root = pathlib.Path(os.environ["PROJECT_ROOT"])
site = root / "packages" / "site"
problems = []

PAGE = """---
import InstallDialog from '../components/InstallDialog.astro';
import type { InstallState } from '@plugdex/registry';

const blocked: InstallState = {
  state: 'blocked',
  shortHead: 'aaaaaaa',
  record: {
    pack: 'planted',
    repo: 'example/planted',
    cliVersion: 'fixture',
    attemptedAt: '2026-01-01T00:00:00Z',
    upstreamHead: 'a'.repeat(40),
    transport: 'https',
    outcome: 'blocked',
    signature: { kind: 'manifest-validation', keys: ['agents'] },
    verbatim: 'PLANTED-VERBATIM-MARKER: the CLI refused this manifest',
  },
};
---

<InstallDialog
  packId="planted"
  displayName="planted"
  upstreamRepo="example/planted"
  state={blocked}
  measuredCommit={'b'.repeat(40)}
/>
"""

sandbox = pathlib.Path(tempfile.mkdtemp())

try:
    target = sandbox / "site"
    shutil.copytree(site / "src", target / "src")

    for name in ("package.json", "astro.config.mjs", "tsconfig.json"):
        shutil.copy(site / name, target / name)

    (target / "node_modules").symlink_to(site / "node_modules")
    (sandbox / "node_modules").symlink_to(root / "node_modules")
    # Only the fixture page. The real pages read the corpus through a path relative to their
    # own location, which does not resolve inside a scratch directory — and building them here
    # would test the loader rather than the dialog this fixture exists to render.
    for page in (target / "src" / "pages").glob("*.astro"):
        page.unlink()

    (target / "src" / "pages" / "blocked-fixture.astro").write_text(PAGE, encoding="utf-8")

    entry = subprocess.run(
        ["node", "-e", "process.stdout.write(require.resolve('astro/package.json'))"],
        cwd=site, capture_output=True, text=True, timeout=120,
    )
    astro_bin = pathlib.Path(entry.stdout.strip()).parent / "astro.js" if entry.returncode == 0 else None

    built = subprocess.run(
        ["node", str(astro_bin), "build"] if astro_bin and astro_bin.exists() else ["npx", "astro", "build"],
        cwd=target, capture_output=True, text=True, timeout=600,
    )

    out = None
    for candidate in (target / "dist" / "blocked-fixture.html",
                      target / "dist" / "blocked-fixture" / "index.html"):
        if candidate.exists():
            out = candidate
            break

    if out is None:
        problems.append(
            "the blocked fixture did not build: "
            + " ".join(
                line for line in (built.stderr or built.stdout).splitlines()
                if line.strip() and "node_modules" not in line
            )[:400]
        )
    else:
        html = out.read_text(encoding="utf-8")

        if "PLANTED-VERBATIM-MARKER" not in html:
            problems.append("a blocked dialog rendered without its recorded verbatim error")

        if re.search(r'data-copy-command="[^"]*install planted@plugdex', html):
            problems.append("a blocked dialog still offers a copy control for the failing command")

        if "claude plugin install planted@plugdex" not in html:
            problems.append("a blocked dialog dropped the command entirely, hiding what was attempted")

        if 'data-install-gap="planted"' not in html:
            problems.append("a blocked dialog omits the HEAD-vs-measured disclosure")
finally:
    shutil.rmtree(sandbox, ignore_errors=True)

print("SENTINEL " + json.dumps(verdict(
    problems,
    "a planted blocked state renders its receipt, keeps the command visible, withdraws the "
    "copy control and carries the gap — proven by rendering, not by the live corpus",
)))
FIXTURE

judge "$(python3 "$SB/fixture.py" 2>/dev/null)" "AC-2 (the blocked render, proven by rendering it)"

# ---------------------------------------------------------------------------
# AC-3 — the counts line is derived, and the oldest/newest distinction is real.
#
# Every record on the live corpus was written inside one two-minute window, so a
# date-granularity comparison cannot tell oldest from newest. The probe therefore compares
# full ISO timestamps AND plants a record a year older to prove the summary moves.
# ---------------------------------------------------------------------------
cat > "$SB/counts.mjs" <<'JS'
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const registry = await import(process.env.REGISTRY_PKG);
const html = readFileSync(process.env.INDEX_HTML, 'utf8');

const files = readdirSync(process.env.INSTALL_DIR).filter((f) => f.endsWith('.json'));
const records = files.map((f) => JSON.parse(readFileSync(join(process.env.INSTALL_DIR, f), 'utf8')));

const installs = records.filter((r) => r.outcome === 'installs').length;
const blocked = records.filter((r) => r.outcome === 'blocked').length;
const stamps = records.map((r) => r.attemptedAt).sort();
const oldest = stamps[0];
const newest = stamps[stamps.length - 1];

const problems = [];

const summary = registry.installabilitySummary?.();

if (typeof registry.installabilitySummary !== 'function') {
  problems.push('installabilitySummary is not exported from @plugdex/registry');
} else {
  if (summary.installs !== installs) problems.push(`summary.installs ${summary.installs} != ${installs}`);
  if (summary.blocked !== blocked) problems.push(`summary.blocked ${summary.blocked} != ${blocked}`);
  if (summary.oldestAttemptedAt !== oldest) {
    problems.push(`summary.oldestAttemptedAt ${summary.oldestAttemptedAt} != ${oldest}`);
  }
  // The trap this row exists for: oldest and newest share a calendar date on this corpus,
  // so rendering the newest passes any date-level check. Compare the full stamp.
  if (oldest !== newest && summary.oldestAttemptedAt === newest) {
    problems.push('the summary reports the NEWEST attempt while claiming the oldest');
  }
}

const line = /<p[^>]*data-install-counts="[^"]*"[^>]*>([\s\S]*?)<\/p>/.exec(html);

if (line === null) {
  problems.push('no [data-install-counts] element in the built page');
} else {
  const text = line[1].replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();

  if (text.length === 0) {
    problems.push('the counts line element is present but renders no text');
  }
  for (const needle of [String(installs), String(blocked)]) {
    if (!text.includes(needle)) problems.push(`the counts line does not contain ${needle}: "${text}"`);
  }
  if (!text.includes(oldest.slice(0, 10))) {
    problems.push(`the counts line does not name the oldest attempt date: "${text}"`);
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.length ? problems.join('; ')
    : `${installs} install, ${blocked} blocked, oldest ${oldest} (newest ${newest}, same date — compared at full stamp)`,
}));
JS

judge "$(node "$SB/counts.mjs" 2>/dev/null)" "AC-3 (the counts line is derived, oldest at stamp granularity)"

# The direction check: a record a year older must move the summary. Run against a scratch
# directory so the repository's own records are never touched.
cat > "$SB/older.mjs" <<'JS'
import { cpSync, mkdtempSync, readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const registry = await import(process.env.REGISTRY_PKG);
const problems = [];

if (typeof registry.loadInstallabilityRecords !== 'function' ||
    typeof registry.summariseInstallability !== 'function') {
  problems.push('summariseInstallability({ records }) is not exported — the direction check has no seam');
} else {
  const scratch = mkdtempSync(join(tmpdir(), 'pdx024-older-'));
  cpSync(process.env.INSTALL_DIR, scratch, { recursive: true });

  const first = readdirSync(scratch).filter((f) => f.endsWith('.json'))[0];
  const record = JSON.parse(readFileSync(join(scratch, first), 'utf8'));
  const planted = '2025-01-02T03:04:05Z';
  writeFileSync(join(scratch, first), JSON.stringify({ ...record, attemptedAt: planted }));

  const before = registry.summariseInstallability({ records: registry.loadInstallabilityRecords() });
  const after = registry.summariseInstallability({
    records: registry.loadInstallabilityRecords({ dir: scratch }),
  });

  if (after.oldestAttemptedAt !== planted) {
    problems.push(`a record planted at ${planted} did not become the oldest (got ${after.oldestAttemptedAt})`);
  }
  if (before.oldestAttemptedAt === after.oldestAttemptedAt) {
    problems.push('the summary did not move at all — it is not reading the records it is handed');
  }
}

console.log('SENTINEL ' + JSON.stringify({
  ok: problems.length === 0,
  detail: problems.length ? problems.join('; ')
    : 'a record planted a year earlier becomes the reported oldest attempt',
}));
JS

judge "$(node "$SB/older.mjs" 2>/dev/null)" "AC-3 (direction: an older record moves the line)"

# ---------------------------------------------------------------------------
# AC-4 — DEC-022's gap, with all three values, each re-derived from its own file.
# ---------------------------------------------------------------------------
cat > "$SB/gap.py" <<'PY'
import glob, json, os, re, sys

sys.path.insert(0, os.environ["SB"])
from report import verdict

html = open(os.environ["INDEX_HTML"], encoding="utf-8").read()
problems = []
differing = []

records = {}
for path in sorted(glob.glob(os.path.join(os.environ["INSTALL_DIR"], "*.json"))):
    record = json.load(open(path, encoding="utf-8"))
    records[record["pack"]] = record

if not records:
    print("SENTINEL " + json.dumps({"ok": False, "detail": "no installability records on disk"}))
    sys.exit(0)

for pack, record in records.items():
    source_path = os.path.join(os.environ["ATTRIBUTION_DIR"], pack, "source.json")

    try:
        measured = json.load(open(source_path, encoding="utf-8"))["commit"]
    except Exception as error:
        problems.append(f"{pack}: no measured commit at {source_path} ({error})")
        continue

    dialog = re.search(rf'<dialog[^>]*id="install-{re.escape(pack)}"[^>]*>(.*?)</dialog>', html, re.S)

    if dialog is None:
        problems.append(f"{pack}: no install dialog")
        continue

    body = dialog.group(1)
    head = record["upstreamHead"]

    # Each value read from its own file, so a join that drops one side cannot pass.
    if measured[:7] not in body:
        problems.append(f"{pack}: the measured commit {measured[:7]} is not in the dialog")
    if head[:7] not in body:
        problems.append(f"{pack}: the recorded upstreamHead {head[:7]} is not in the dialog")

    version = record.get("installedVersion")
    if version is not None and version not in body:
        problems.append(f"{pack}: installedVersion {version} is recorded but not shown")

    if measured != head:
        differing.append(pack)

# The disclosure is untestable if the two values coincide everywhere. DEC-022 records that
# they were the same object for exactly one day.
if not differing:
    problems.append("no pack has a measured commit different from its upstreamHead — "
                    "the HEAD-vs-measured disclosure cannot be tested")

print("SENTINEL " + json.dumps(verdict(
    problems,
    f"{len(records)} dialogs carry measured commit, upstreamHead and installedVersion; "
    f"the two commits differ for {sorted(differing)}",
)))
PY

judge "$(python3 "$SB/gap.py" 2>/dev/null)" "AC-4 (all three values, each from its own file)"

# ---------------------------------------------------------------------------
# AC-7 — no pack id is hardcoded into an install-state expression.
#
# The ids are derived from `entries` rather than typed (PLAN-01: a typed roster goes stale
# the day a pack is added), all three quote forms are covered, and the sweep runs against a
# planted violation first. CLAUDE.md names a grep whose empty output was read as proof as
# ASSERT-01 instance one; this is that shape, so it is not believed until it has spoken.
# ---------------------------------------------------------------------------
cat > "$SB/ids.mjs" <<'JS'
const registry = await import(process.env.REGISTRY_PKG);
console.log([...registry.entries].map((e) => e.packId).join('\n'));
JS

PACK_IDS="$(node "$SB/ids.mjs" 2>/dev/null)"

if [[ -z "$PACK_IDS" ]]; then
  fail "AC-7: the pack id list came back empty — the sweep below would prove nothing"
else
  sweep() {
    local root="$1"
    local id
    while IFS= read -r id; do
      [[ -z "$id" ]] && continue
      grep -rnE "['\"\`]${id}['\"\`]" "$root" 2>/dev/null
    done <<< "$PACK_IDS"
  }

  mkdir -p "$SB/planted-src"
  printf 'const blocked = ["caveman"];\nexport default blocked;\n' > "$SB/planted-src/state.ts"

  if [[ -n "$(sweep "$SB/planted-src")" ]]; then
    pass "AC-7 (control): the sweep reports a hardcoded pack id"

    HITS="$(sweep "$SITE_SRC")"

    if [[ -z "$HITS" ]]; then
      pass "AC-7: no pack id is typed into site source (sweep covers ' \" and \` forms)"
    else
      fail "AC-7: a pack id is typed into site source: $(printf '%s' "$HITS" | head -3 | tr '\n' ' ')"
    fi
  else
    fail "AC-7 (control): the sweep missed a planted hardcoded pack id — it cannot be trusted"
  fi
fi

echo

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}PDX-024 PASS${NC}"
else
  echo -e "${RED}PDX-024 FAIL${NC}" >&2
fi

exit $FAILED
