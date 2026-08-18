#!/usr/bin/env bash
# scripts/check-fresh-clone.sh
#
# Runs `verify.sh` the way CI runs it: against a clone of HEAD with no build output,
# no `node_modules`, and none of the working tree's leftovers.
#
# This exists because of a defect it would have caught. `verify.sh` ran `pnpm typecheck`
# before `pnpm build`; the library packages typecheck with `tsc --noEmit`, so nothing
# emitted `dist/`, and the site's `astro check` resolves `@plugdex/data` through that
# directory. On a developer's tree `dist/` is left over from a previous run and the
# ordering never shows. A GREEN stamp, a written report, and a full report-review round
# were all taken on a tree whose fresh clone failed at step 8 — the first defect in this
# repository that only CI could see, found by a goal audit rather than by a gate.
#
# It is not part of `verify.sh`: a gate that clones and installs the workspace cannot be
# a step inside the thing it runs. It belongs to the stage gate, before a PR is opened.
#
# Usage:
#   ./scripts/check-fresh-clone.sh            # HEAD
#   ./scripts/check-fresh-clone.sh <ref>      # any committed ref
#
# ASSERT-01: the clone's file count and the verify output are both floored, so an empty
# clone or a silent verify cannot read as a pass.

set -uo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# shellcheck source=lib/gate-log.sh
source "$PROJECT_ROOT/scripts/lib/gate-log.sh"
gate_log_init "check-fresh-clone" "-" "${*:-}"

REF="${1:-HEAD}"
CLONE="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-fresh.XXXXXX")"
trap 'rc=$?; rm -rf "$CLONE"; gate_log_exit "$rc"' EXIT

if ! git rev-parse --verify --quiet "$REF" >/dev/null; then
  echo -e "${RED}❌ fresh-clone: '$REF' is not a committed ref — there is nothing to clone${NC}" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo -e "${BLUE}ℹ️  the working tree has uncommitted changes; they are NOT in this clone${NC}"
fi

echo -e "${BLUE}ℹ️  cloning $REF ($(git rev-parse --short "$REF"))${NC}"

if ! git clone --quiet --no-local --branch "$(git rev-parse --abbrev-ref HEAD)" "$PROJECT_ROOT" "$CLONE/repo" 2>/dev/null; then
  git clone --quiet --no-local "$PROJECT_ROOT" "$CLONE/repo" || {
    echo -e "${RED}❌ fresh-clone: the clone failed — nothing was verified${NC}" >&2
    exit 1
  }
fi

( cd "$CLONE/repo" && git checkout --quiet "$(git rev-parse "$REF")" ) || {
  echo -e "${RED}❌ fresh-clone: could not check out $REF in the clone${NC}" >&2
  exit 1
}

FILES="$(cd "$CLONE/repo" && git ls-files | wc -l | tr -d ' ')"

if [[ "$FILES" -lt 20 ]]; then
  echo -e "${RED}❌ fresh-clone: the clone holds $FILES tracked files — it is not this repository${NC}" >&2
  exit 1
fi

for leftover in packages/data/dist packages/registry/dist packages/site/dist node_modules; do
  if [[ -e "$CLONE/repo/$leftover" ]]; then
    echo -e "${RED}❌ fresh-clone: $leftover is present in a fresh clone — it is tracked, and it must not be${NC}" >&2
    exit 1
  fi
done

echo -e "${BLUE}ℹ️  $FILES tracked files, no build output, installing${NC}"

if ! ( cd "$CLONE/repo" && pnpm install --frozen-lockfile ) > "$CLONE/install.log" 2>&1; then
  echo -e "${RED}❌ fresh-clone: pnpm install --frozen-lockfile failed${NC}" >&2
  tail -15 "$CLONE/install.log" >&2
  exit 1
fi

( cd "$CLONE/repo" && ./scripts/verify.sh ) > "$CLONE/verify.log" 2>&1
STATUS=$?

if [[ ! -s "$CLONE/verify.log" ]]; then
  echo -e "${RED}❌ fresh-clone: verify produced no output — it did not run${NC}" >&2
  exit 1
fi

if [[ $STATUS -ne 0 ]]; then
  echo -e "${RED}❌ FRESH-CLONE FAIL — verify does not pass on a clone of $REF${NC}" >&2
  echo -e "${RED}   This is what CI runs. A local pass here means only that your tree has${NC}" >&2
  echo -e "${RED}   build output an empty checkout does not.${NC}" >&2
  grep -E '❌|FAILED|error' "$CLONE/verify.log" | tail -10 >&2
  exit 1
fi

if ! grep -q "VERIFY PASS" "$CLONE/verify.log"; then
  echo -e "${RED}❌ fresh-clone: verify exited 0 without printing VERIFY PASS${NC}" >&2
  exit 1
fi

echo -e "${GREEN}✅ FRESH-CLONE PASS — $(grep -o 'VERIFY PASS ([0-9]*s)' "$CLONE/verify.log" | tail -1) on a clone of $REF${NC}"
