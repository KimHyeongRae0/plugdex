#!/usr/bin/env bash
# scripts/check-src.sh
#
# SRC-01 gate — every listed pack links upstream, names its author, and records how its
# author can ask to be removed.
#
# We publish verdicts about other people's work. Attribution and an opt-out are the
# minimum that makes that defensible, and a rule enforced by intention is not enforced.
#
# Violations:
#   SRC-01a  a listing is missing a required field
#   SRC-01b  an attribution field is untagged (neither upstream nor curated)
#   SRC-01c  a curated value carries no `why`
#   SRC-01d  an upstream-tagged author disagrees with the manifest that declares it
#   SRC-01e  an upstream repository that cannot be resolved to a location
#   SRC-01f  a recorded manifest with no source commit — an audit with no fixed point
#
# ASSERT-01: the check prints a sentinel on its success path, and an empty capture is a
# failure here rather than a clean bill of health. A gate whose "nothing wrong" and
# "did not run" are the same output is not a gate.

set -uo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

REGISTRY_DIST="packages/registry/dist/index.js"

if [[ ! -f "$REGISTRY_DIST" ]]; then
  echo -e "${RED}❌ SRC-01: $REGISTRY_DIST not built — the gate cannot read the listings${NC}" >&2
  exit 1
fi

REPORT=$(node --input-type=module -e "
  import { entries } from './$REGISTRY_DIST';
  import { declaredAuthor, readManifest, readSource } from './$REGISTRY_DIST';
  const REQUIRED = ['packId','displayName','author','upstreamRepo','license','stars','installSource','listingProvenance','optOutContact'];
  const TAGGED = ['author','upstreamRepo','license'];
  const bad = [];
  for (const e of entries) {
    for (const f of REQUIRED) {
      if (e[f] === undefined || e[f] === null || e[f] === '') bad.push(\`SRC-01a \${e.packId ?? '?'}.\${f}: missing\`);
    }
    for (const f of TAGGED) {
      const v = e[f];
      if (typeof v !== 'object' || !v || !('from' in v)) { bad.push(\`SRC-01b \${e.packId}.\${f}: untagged\`); continue; }
      if (!['upstream','curated'].includes(v.from)) bad.push(\`SRC-01b \${e.packId}.\${f}: bad tag '\${v.from}'\`);
      if (!v.value) bad.push(\`SRC-01a \${e.packId}.\${f}: tagged with no value\`);
      if (v.from === 'curated' && !v.why) bad.push(\`SRC-01c \${e.packId}.\${f}: curated with no why\`);
    }
    if (e.author?.from === 'upstream') {
      const declared = declaredAuthor({ manifest: readManifest({ packId: e.packId }) });
      if (declared !== e.author.value) bad.push(\`SRC-01d \${e.packId}: listed '\${e.author.value}', manifest declares '\${declared}'\`);
    }
    // A repository nobody can open is not an upstream link. Either owner/repo or an
    // absolute URL resolves; a bare name does not, and SRC-01's whole point is that a
    // reader can go and look.
    const repo = e.upstreamRepo?.value ?? '';
    if (repo && !/^[\\w.-]+\\/[\\w.-]+$/.test(repo) && !/^https?:\\/\\//.test(repo)) {
      bad.push(\`SRC-01e \${e.packId}: upstream '\${repo}' resolves to no location\`);
    }
    // The recorded manifest is the audit; the commit is what fixes it to a version.
    try {
      const src = readSource({ packId: e.packId });
      if (!src.commit) bad.push(\`SRC-01f \${e.packId}: recorded manifest has no source commit\`);
      if (!src.readAt) bad.push(\`SRC-01f \${e.packId}: recorded manifest has no read date\`);
      if (typeof e.stars?.count !== 'number' || !e.stars?.readAt) {
        bad.push(\`SRC-01a \${e.packId}.stars: not recorded with the date it was read\`);
      }
    } catch {
      bad.push(\`SRC-01f \${e.packId}: no source record for the recorded manifest\`);
    }
  }
  console.log('SENTINEL ' + JSON.stringify({ n: entries.length, bad }));
" 2>&1)

if [[ "$REPORT" != SENTINEL* ]]; then
  echo -e "${RED}❌ SRC-01: the gate produced no report — it did not run${NC}" >&2
  echo "$REPORT" | tail -3 >&2
  exit 1
fi

N=$(echo "${REPORT#SENTINEL }" | sed 's/.*"n":\([0-9]*\).*/\1/')
BAD=$(echo "${REPORT#SENTINEL }" | sed 's/.*"bad":\[\(.*\)\]}/\1/')

if [[ "$N" -lt 1 ]]; then
  echo -e "${RED}❌ SRC-01: the registry lists nothing — the gate checked no listings${NC}" >&2
  exit 1
fi

if [[ -n "$BAD" ]]; then
  echo -e "${RED}❌ SRC-01 BLOCK:${NC}" >&2
  echo "$BAD" | tr ',' '\n' | sed 's/^ *"//; s/"$//; s/^/   /' >&2
  exit 1
fi

echo -e "${GREEN}✅ SRC-01 PASS — $N listings, every attribution field tagged and sourced${NC}"
