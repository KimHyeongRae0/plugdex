#!/usr/bin/env bash
# tests/e2e/PDX-003-the-hub-installs.sh
#
# PDX-003 — the hub installs, and every listing says whose work it is.
#
# The load-bearing assertion is AC-5: a real `claude plugin marketplace add` followed by
# a real `claude plugin install`, asserted on the resulting installed listing rather than
# on an exit code. If that does not work, plugdex is a report with an install button
# drawn on it.
#
# Network IS required, and that is deliberate. The install source is a github repo, so a
# successful install clones from the author's own repository — proving end-to-end delivery
# rather than manifest syntax. A listed pack that stops installing is a broken listing and
# this is what catches it, so a network error fails rather than skips.
#
# Nothing is published: the marketplace is added from a local path (CR-01), and everything
# runs under a scratch CLAUDE_CONFIG_DIR so the developer's real config is untouched.
#
# ASSERT-01 throughout. Before step 1 nothing under packages/registry/dist/ exists, so
# every node block below exits non-zero with its diagnostics on a stderr this scenario
# discards, and every variable they fill is the empty string. An assertion phrased as
# "empty output means nothing was wrong" therefore reports a pass in exactly the state it
# exists to reject — which is how the Attribution check was green on an unimplemented tree.
# So every subprocess prints a sentinel on its success path, and every assertion requires a
# non-empty capture before it reads the contents.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-003 — the hub installs"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx003.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

MARKET=".claude-plugin/marketplace.json"
FIXTURES="packages/registry/test/fixtures"

# ---------------------------------------------------------------------------
# AC-1 — every entry carries every SRC-01 field, each tagged upstream or curated.
#
# Read through the built package rather than by grepping the source, so this asserts
# what a consumer sees.
# ---------------------------------------------------------------------------
ENTRY_REPORT=$(node --input-type=module -e "
  import { entries } from './packages/registry/dist/index.js';
  const required = ['packId','displayName','author','upstreamRepo','license','stars','installSource','listingProvenance','optOutContact'];
  const bad = [];
  for (const e of entries) {
    for (const f of required) {
      const v = e[f];
      if (v === undefined || v === null) { bad.push(\`\${e.packId ?? '?'}.\${f}: missing\`); continue; }
      // Attribution fields are tagged values, not bare strings.
      if (f === 'stars') {
        // A star count with no read date is a claim with no expiry, which is the one
        // shape a number on a provenance site must not have.
        if (typeof v.count !== 'number' || !v.readAt) bad.push(\`\${e.packId}.stars: not recorded with the date it was read\`);
        continue;
      }
      if (['author','upstreamRepo','license'].includes(f)) {
        if (typeof v !== 'object' || !('from' in v)) { bad.push(\`\${e.packId}.\${f}: untagged\`); continue; }
        if (v.from === 'curated' && !v.why) bad.push(\`\${e.packId}.\${f}: curated with no why\`);
        if (!['upstream','curated'].includes(v.from)) bad.push(\`\${e.packId}.\${f}: bad tag '\${v.from}'\`);
      }
    }
  }
  console.log('SENTINEL ' + JSON.stringify({ n: entries.length, bad }));
" 2>/dev/null)

if [[ "$ENTRY_REPORT" != SENTINEL* ]]; then
  fail "AC-1: @plugdex/registry produced no report — the package is not built"
else
  N_ENTRIES=$(echo "${ENTRY_REPORT#SENTINEL }" | sed 's/.*"n":\([0-9]*\).*/\1/')
  BAD=$(echo "${ENTRY_REPORT#SENTINEL }" | sed 's/.*"bad":\[\(.*\)\]}/\1/')
  if [[ "$N_ENTRIES" -lt 1 ]]; then
    fail "AC-1: no entries — the registry lists nothing"
  elif [[ -n "$BAD" ]]; then
    fail "AC-1: entries with missing or untagged SRC-01 fields: $BAD"
  else
    pass "AC-1: $N_ENTRIES entries, every SRC-01 field present and tagged"
  fi
fi

# ---------------------------------------------------------------------------
# AC-2 — the install source is the github/repo form, and the type forbids git/url.
#
# Asserted as a pair. A lone negative compile check is green before the code exists,
# because the fixture fails to compile for a missing module rather than for the type it
# is supposed to violate — the review's second blocker, and PDX-002's fake-RED class. The
# positive fixture must compile and the negative one must not; only both together say
# anything. The emitted JSON is checked as well, because a type stops enforcing anything
# once the JSON is written.
# ---------------------------------------------------------------------------
TSC="node_modules/.bin/tsc"

if [[ ! -f "$FIXTURES/supported-source.ts" || ! -f "$FIXTURES/unsupported-source.ts" ]]; then
  fail "AC-2: the compile pair is missing — expected $FIXTURES/{supported,unsupported}-source.ts"
elif [[ ! -x "$TSC" ]]; then
  fail "AC-2: no tsc at $TSC — the compile pair cannot be judged"
else
  # Each fixture is compiled on its own. Compiling them as one project would collapse
  # the pair into a single verdict, and the pair is the whole point.
  TSC_FLAGS=(--noEmit --strict --target es2022 --module esnext --moduleResolution bundler)

  "$TSC" "${TSC_FLAGS[@]}" "$FIXTURES/supported-source.ts" >"$SB/pos.log" 2>&1
  POS=$?
  "$TSC" "${TSC_FLAGS[@]}" "$FIXTURES/unsupported-source.ts" >"$SB/neg.log" 2>&1
  NEG=$?

  if [[ $POS -ne 0 ]]; then
    fail "AC-2: the supported github/repo fixture does not compile — $(tail -1 "$SB/pos.log")"
  elif [[ $NEG -eq 0 ]]; then
    fail "AC-2: the unsupported git/url fixture compiles — the type forbids nothing"
  else
    pass "AC-2: the type accepts github/repo and rejects git/url"
  fi
fi

if [[ ! -f "$MARKET" ]]; then
  fail "AC-2: $MARKET does not exist"
else
  SRC_REPORT=$(python3 -c "
import json
d = json.load(open('$MARKET'))
bad = [p.get('name','?') for p in d.get('plugins',[])
       if not (isinstance(p.get('source'), dict) and p['source'].get('source') == 'github' and p['source'].get('repo'))]
print('SENTINEL ' + ','.join(bad))
" 2>/dev/null)

  if [[ "$SRC_REPORT" != SENTINEL* ]]; then
    fail "AC-2: $MARKET could not be read as JSON"
  elif [[ -n "${SRC_REPORT#SENTINEL }" ]]; then
    fail "AC-2: plugins whose source is not {source:github, repo}: ${SRC_REPORT#SENTINEL }"
  else
    pass "AC-2: every emitted plugin source is the supported github/repo form"
  fi
fi

# ---------------------------------------------------------------------------
# AC-3 — generation is deterministic.
#
# Non-emptiness is checked FIRST. With no generator, two runs both produce nothing and
# "identical" would be vacuously true — the fake-green the plan review flagged.
#
# The regeneration goes to the sandbox via `--out` and the tracked file is never written.
# An earlier version regenerated in place and restored only on the diff-fail branch, so a
# generator dying mid-write left the committed manifest corrupted — a round-3 review
# finding, and the report review then caught that the claimed fix had not closed it.
# ---------------------------------------------------------------------------
if [[ ! -s "$MARKET" ]]; then
  fail "AC-3: $MARKET is missing or empty — nothing to compare"
elif ! node packages/registry/dist/generate-cli.js --out "$SB/regen.json" >"$SB/gen.log" 2>&1; then
  fail "AC-3: the generator failed to run — $(tail -1 "$SB/gen.log")"
elif [[ ! -s "$SB/regen.json" ]]; then
  fail "AC-3: the generator wrote nothing — there is no second copy to compare"
elif ! diff -q "$MARKET" "$SB/regen.json" >/dev/null 2>&1; then
  fail "AC-3: regenerating produced a different file — output is not deterministic"
else
  pass "AC-3: regeneration is byte-identical ($(wc -c < "$MARKET" | tr -d ' ') bytes)"
fi

# ---------------------------------------------------------------------------
# AC-4 — the SRC-01 gate blocks what it claims to block.
#
# The golden set is check-gates.sh's job; here we assert the gate runs clean on the real
# tree, so a broken gate cannot hide behind a green golden set. The missing-script case is
# named separately: before step 6 the failure is "there is no gate", not "the gate blocks
# this registry", and a scenario that reports the wrong cause is a scenario that will be
# debugged in the wrong place.
# ---------------------------------------------------------------------------
if [[ ! -x scripts/check-src.sh ]]; then
  fail "AC-4: scripts/check-src.sh does not exist or is not executable — SRC-01 has no gate"
elif ./scripts/check-src.sh >"$SB/src.log" 2>&1; then
  pass "AC-4: SRC-01 passes on the real registry"
else
  fail "AC-4: SRC-01 BLOCKs the registry this ticket ships — $(tail -1 "$SB/src.log")"
fi

# ---------------------------------------------------------------------------
# AC-5 — the hub actually installs. The one that matters.
#
# The marketplace is added from a local path so nothing is published (CR-01), but each
# install reaches GitHub because the sources are github repos. So this proves end-to-end
# delivery of real packs from real upstreams. What it does NOT prove is that our
# marketplace is addable remotely — that needs this repository public, and the report
# states the limit in those terms rather than the reverse.
#
# This assertion used to install the FIRST plugin in the manifest and stop. That was a cap
# nobody had chosen: coverage depended on sort order, and on 2026-08-18 it only caught the
# `caveman` breakage because `caveman` sorts first. Had the broken pack sorted second, the
# suite would have gone green over a listing that does not install. PDX-023 replaced it
# with `scripts/check-installability.sh`, which sweeps EVERY listing and compares each
# outcome against its recorded state — so a pack recorded as installable must install, and
# a pack recorded as blocked must still fail the same way. Marking a pack blocked is
# therefore not a route to a green gate, which is the property that makes recording the
# state honest rather than convenient.
#
# A missing `claude` binary is recorded and FAILS. The ticket calls this a loud skip; a
# skip that leaves the run green would let the product's premise go unproven on any machine
# without the CLI, which is the one outcome this assertion exists to prevent.
# ---------------------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  fail "AC-5: 'claude' is not on PATH — the install proof did not run, and an unproven install is not a pass"
elif [[ ! -f "$MARKET" ]]; then
  fail "AC-5: no marketplace manifest to add"
else
  INST_LOG="$SB/installability.log"
  INST_STATUS=0

  ./scripts/check-installability.sh >"$INST_LOG" 2>&1 || INST_STATUS=$?

  # The gate prints one line per listing. Counting them against the manifest is what turns
  # "the gate exited 0" into "the gate looked at everything": an early return would exit 0
  # having checked nothing, and the floor makes an empty sweep a failure rather than a
  # vacuous pass (ASSERT-01).
  SWEPT=$(grep -c '^INST-01 PACK ' "$INST_LOG" 2>/dev/null || echo 0)
  LISTED_COUNT=$(python3 -c "
import json
print(len(json.load(open('$MARKET')).get('plugins') or []))
" 2>/dev/null || echo 0)

  if [[ "$INST_STATUS" -ne 0 ]]; then
    fail "AC-5: INST-01 blocked — $(grep -E '✗|INST-01' "$INST_LOG" | head -2 | tr '\n' ' ' | cut -c1-220)"
  elif [[ -z "$LISTED_COUNT" || "$LISTED_COUNT" -lt 1 ]]; then
    fail "AC-5: the manifest lists no plugins, so the sweep asserted nothing"
  elif [[ "$SWEPT" -ne "$LISTED_COUNT" ]]; then
    fail "AC-5: the gate reported on $SWEPT listing(s) but the manifest carries $LISTED_COUNT — a partial sweep is not a pass"
  elif ! grep -q '^INST-01 PACK caveman ' "$INST_LOG"; then
    fail "AC-5: caveman is not among the listings the gate swept — a pack that stops installing must stay listed and stay checked, not disappear (CLAIM-01)"
  else
    pass "AC-5: INST-01 swept all $LISTED_COUNT listings and every recorded install state reproduced, caveman included"
  fi
fi

# ---------------------------------------------------------------------------
# AC-6 — every measured arm is listed or explicitly excluded.
#
# The arm list is DERIVED from the corpus at runtime. A hard-coded list is how a future
# measured pack silently vanishes from the catalogue.
# ---------------------------------------------------------------------------
JOIN=$(node --input-type=module -e "
  import { loadAcceptanceRecords } from './packages/data/dist/index.js';
  import { entries, excludedArms } from './packages/registry/dist/index.js';
  const arms = new Set(loadAcceptanceRecords({ dir: 'bench/data/runs' }).cells.map(c => c.arm));
  arms.delete('baseline');
  const listed = new Set(entries.map(e => e.packId));
  const excluded = new Set(Object.keys(excludedArms));
  const orphans = [...arms].filter(a => !listed.has(a) && !excluded.has(a));
  const unexplained = [...excluded].filter(a => !excludedArms[a]);
  console.log('SENTINEL ' + JSON.stringify({ arms: arms.size, orphans, unexplained }));
" 2>/dev/null)

if [[ "$JOIN" != SENTINEL* ]]; then
  fail "AC-6: the registry/data join produced no report — one of the packages is not built"
else
  N_ARMS=$(echo "${JOIN#SENTINEL }" | sed 's/.*"arms":\([0-9]*\).*/\1/')
  ORPHANS=$(echo "${JOIN#SENTINEL }" | sed 's/.*"orphans":\[\([^]]*\)\].*/\1/')
  UNEXPLAINED=$(echo "${JOIN#SENTINEL }" | sed 's/.*"unexplained":\[\([^]]*\)\].*/\1/')
  if [[ "$N_ARMS" -lt 1 ]]; then
    fail "AC-6: the corpus yielded no measured arms — the join proves nothing"
  elif [[ -n "$ORPHANS" ]]; then
    fail "AC-6: measured arms neither listed nor excluded: $ORPHANS"
  elif [[ -n "$UNEXPLAINED" ]]; then
    fail "AC-6: arms excluded with no stated reason: $UNEXPLAINED"
  else
    pass "AC-6: all $N_ARMS measured arms are listed or excluded with a reason"
  fi
fi

# ---------------------------------------------------------------------------
# AC-7 — verify runs SRC-01, and the golden set is unregressed.
#
# Passes only on a positive match, so an empty verify output fails rather than passes.
# ---------------------------------------------------------------------------
# Captured before it is searched, rather than piped into `grep -q`. Under `pipefail` a
# `-q` grep exits on its first match, verify.sh dies of SIGPIPE, and the pipeline reports
# 141 — so a run that found what it was looking for is indistinguishable from one that
# failed. That is ASSERT-01's shape with the polarity reversed, and it cost a debugging
# round here.
VERIFY_OUT=$(./scripts/verify.sh 2>&1)

if [[ -z "$VERIFY_OUT" ]]; then
  fail "AC-7: verify.sh produced no output — it did not run"
elif grep -qi "SRC-01" <<<"$VERIFY_OUT"; then
  pass "AC-7: verify.sh runs the SRC-01 gate"
else
  fail "AC-7: verify.sh does not run SRC-01 — the rule is not enforced by the gate stack"
fi

# ---------------------------------------------------------------------------
# Attribution — the assertion that makes SRC-01 more than paperwork.
#
# A pack's listed author must be the one its own manifest declares. The pack commonly
# called "Karpathy's skills" declares someone else; listing it under the famous name would
# be misattribution on the front page of a provenance site.
#
# Two vacuous passes are closed here. The empty capture — the round-2 blocker — is closed
# by the sentinel. The second is subtler and survives a sentinel: a well-formed report of
# zero checked entries agrees with everything. So the check counts what it examined, the
# assertion requires that count to be positive, and the known-misattribution pack is
# asserted by name regardless of how its author is tagged, because a listing that quietly
# retags itself `curated` would otherwise drop out of the only check that names it.
# ---------------------------------------------------------------------------
ATTRIB=$(node --input-type=module -e "
  import { entries } from './packages/registry/dist/index.js';
  import { readFileSync, existsSync } from 'node:fs';
  const KNOWN_MISATTRIBUTED = 'karpathy';  // the arm id; its displayName is andrej-karpathy-skills
  const bad = [];
  let checked = 0;
  for (const e of entries) {
    if (e.author.from !== 'upstream') continue;
    checked++;
    const path = \`packages/registry/attribution/\${e.packId}/plugin.json\`;
    if (!existsSync(path)) { bad.push(\`\${e.packId}: claims upstream author with no recorded manifest\`); continue; }
    const m = JSON.parse(readFileSync(path, 'utf8'));
    const declared = typeof m.author === 'string' ? m.author : m.author?.name;
    if (declared !== e.author.value) bad.push(\`\${e.packId}: listed '\${e.author.value}', manifest declares '\${declared}'\`);
  }
  const pack = entries.find(e => e.packId === KNOWN_MISATTRIBUTED);
  if (!pack) bad.push(\`\${KNOWN_MISATTRIBUTED}: not listed — the misattribution case is unasserted\`);
  else if (pack.author.from !== 'upstream') bad.push(\`\${KNOWN_MISATTRIBUTED}: author is tagged '\${pack.author.from}', so our claim about a real person is not checked against their own manifest\`);
  console.log('SENTINEL ' + JSON.stringify({ checked, bad }));
" 2>/dev/null)

if [[ "$ATTRIB" != SENTINEL* ]]; then
  fail "Attribution: the check produced no report — @plugdex/registry is not built, so nothing was verified"
else
  CHECKED=$(echo "${ATTRIB#SENTINEL }" | sed 's/.*"checked":\([0-9]*\).*/\1/')
  MISMATCH=$(echo "${ATTRIB#SENTINEL }" | sed 's/.*"bad":\[\(.*\)\]}/\1/')
  if [[ "$CHECKED" -lt 1 ]]; then
    fail "Attribution: zero entries carry an upstream-tagged author — the check agreed with nothing"
  elif [[ -n "$MISMATCH" ]]; then
    fail "Attribution: $MISMATCH"
  else
    pass "Attribution: $CHECKED upstream-tagged authors each match the manifest that declares it"
  fi
fi

if [[ $FAILED -ne 0 ]]; then
  echo -e "${RED}PDX-003 scenario FAILED${NC}" >&2
  exit 1
fi

echo -e "${GREEN}PDX-003 scenario PASS${NC}"
