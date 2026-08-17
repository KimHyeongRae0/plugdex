#!/usr/bin/env bash
# scripts/record-attribution.sh
#
# Records, for every listed pack, the manifest we quote and the facts that fix it in time:
# the upstream commit it was read from and the star count with the moment it was read.
#
# This exists because of a report-review blocker. The first version of `source.json` carried
# five star counts with no retrieval method recorded anywhere — numbers a reader could
# neither reproduce nor refute. On a site whose whole argument is that a claim is worth its
# receipt, an unreceipted number is the one thing that cannot ship, and the reviewer was
# right to treat it as fabricated until receipted regardless of whether it was.
#
# What lands in each `source.json` is therefore not just the value but how it was obtained:
# the exact command, the timestamp, and two corroborating fields from the same response
# (`full_name` and `forks_count`) so a re-run can be compared rather than merely repeated.
#
# Network: yes, read-only, and only against the GitHub API and local clones. Nothing is
# published (CR-01).
#
# Usage:
#   ./scripts/record-attribution.sh            # refresh every recorded pack
#   PACK_CLONES=/path/to/arms ./scripts/record-attribution.sh

set -uo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ATTRIBUTION="packages/registry/attribution"
CLONES="${PACK_CLONES:-$HOME/Desktop/project/pack-pilot/arms}"

# packId : local clone directory. The clone is the copy that was actually measured, so the
# commit recorded here is the one the grading ran against, not whatever upstream is today.
PACKS=(
  "ponytail:ponytail"
  "caveman:caveman"
  "karpathy:andrej-karpathy-skills"
  "mattpocock:mattpocock-skills"
  "superpowers:superpowers"
)

command -v gh >/dev/null 2>&1 || { echo -e "${RED}❌ gh is not on PATH${NC}" >&2; exit 1; }

FAILED=0

for entry in "${PACKS[@]}"; do
  pack="${entry%%:*}"
  clone="$CLONES/${entry##*:}"

  if [[ ! -d "$clone/.git" ]]; then
    echo -e "${RED}❌ $pack: no clone at $clone — set PACK_CLONES${NC}" >&2
    FAILED=1
    continue
  fi

  commit="$(git -C "$clone" rev-parse HEAD)"
  repo="$(git -C "$clone" config --get remote.origin.url | sed 's#.*github.com[:/]##; s#\.git$##')"
  read_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # The whole response is captured once, so the value and its corroborating fields come
  # from the same read rather than from three reads that could disagree.
  if ! response="$(gh api "repos/$repo" 2>/dev/null)"; then
    echo -e "${RED}❌ $pack: GitHub API read failed for $repo${NC}" >&2
    FAILED=1
    continue
  fi

  if ! REPO="$repo" COMMIT="$commit" READ_AT="$read_at" PACK="$pack" \
    python3 -c "
import json, os, sys, pathlib

response = json.loads(sys.stdin.read())
stars = response.get('stargazers_count')

if not isinstance(stars, int):
    sys.exit('no stargazers_count in the response')

# full_name is checked rather than trusted: a redirected or renamed repository would
# otherwise attach one project's popularity to another project's listing.
if response.get('full_name', '').lower() != os.environ['REPO'].lower():
    sys.exit(f\"response is for {response.get('full_name')!r}, not {os.environ['REPO']!r}\")

path = pathlib.Path('$ATTRIBUTION') / os.environ['PACK'] / 'source.json'
path.write_text(json.dumps({
    'repo': os.environ['REPO'],
    'commit': os.environ['COMMIT'],
    'path': '.claude-plugin/plugin.json',
    'readAt': os.environ['READ_AT'][:10],
    'stars': stars,
    'receipt': {
        'starsCommand': f\"gh api repos/{os.environ['REPO']} --jq .stargazers_count\",
        'commitCommand': 'git -C <clone> rev-parse HEAD',
        'readAt': os.environ['READ_AT'],
        'fullName': response.get('full_name'),
        'forks': response.get('forks_count'),
        'note': 'stars move; this is the value at readAt, not a live figure',
    },
}, indent=2) + '\n', encoding='utf-8')
print(f\"  {os.environ['PACK']:<12} {os.environ['REPO']:<38} stars={stars} commit={os.environ['COMMIT'][:7]}\")
" <<<"$response"; then
    FAILED=1
  fi
done

if [[ $FAILED -ne 0 ]]; then
  echo -e "${RED}❌ attribution recording incomplete${NC}" >&2
  exit 1
fi

echo -e "${GREEN}✅ attribution recorded for ${#PACKS[@]} packs${NC}"
