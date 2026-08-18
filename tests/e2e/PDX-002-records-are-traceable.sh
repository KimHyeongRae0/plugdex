#!/usr/bin/env bash
# tests/e2e/PDX-002-records-are-traceable.sh
#
# PDX-002 — the absorbed measurement project is traceable, and the loader refuses
# what it cannot trace.
#
# One assertion per acceptance criterion. Every assertion must be capable of failing
# before the implementation; an assertion that is green on an empty tree proves nothing
# and is the failure the plan review caught in the first draft (AC-7).
#
# Self-contained: reads the repository, starts nothing, writes only under a temp dir.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-002 — records are traceable"

# ---------------------------------------------------------------------------
# AC-1 — all four original commits reachable, original author dates intact.
#
# Not `git log -- bench/`: `git subtree add` grafts commits whose own trees hold
# files at the root, so a pathspec-filtered log correctly shows only the merge.
# The commits are reached through the graft merge's second parent instead.
# ---------------------------------------------------------------------------
#
# The graft is identified by what its second parent CONTAINS, not by being the first
# merge in the log. On CI that heuristic picks the wrong commit: GitHub checks a pull
# request out as `refs/pull/N/merge`, a merge of the branch into base, whose second
# parent is `main` — so the scenario read main's history, found no PREREGISTRATION-2.md,
# and failed on CI while passing locally. Searching for the merge whose second parent
# holds the file at its root finds the import no matter what else has been merged.
GRAFT=""
IMPORTED_TIP=""
while read -r sha p1 p2; do
  [[ -n "$p2" ]] || continue
  if git cat-file -e "$p2:PREREGISTRATION-2.md" 2>/dev/null; then
    GRAFT="$sha"; IMPORTED_TIP="$p2"; break
  fi
done < <(git log --format='%H %P')

if [[ -z "$GRAFT" ]]; then
  fail "AC-1: no merge whose second parent holds PREREGISTRATION-2.md — bench/ was never imported"
else
  N_COMMITS=$(git rev-list --count "$IMPORTED_TIP" 2>/dev/null || echo 0)

  if [[ "$N_COMMITS" -lt 4 ]]; then
    fail "AC-1: expected at least 4 imported commits, reached $N_COMMITS"
  else
    # The author date must be the original one, not the import date.
    PRE_COMMIT=$(git log --format=%H --diff-filter=A "$IMPORTED_TIP" -- PREREGISTRATION-2.md | tail -1)
    PRE_DATE=$(git log -1 --format=%ad --date=format:'%Y-%m-%d' "$PRE_COMMIT" 2>/dev/null)

    if [[ "$PRE_DATE" == "2026-08-16" ]]; then
      pass "AC-1: $N_COMMITS imported commits reachable, author dates preserved ($PRE_DATE)"
    else
      fail "AC-1: preregistration commit authored '$PRE_DATE', expected 2026-08-16 — history was rewritten"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# AC-1 staleness — the corrected PREREGISTRATION.md arrived.
#
# A clone still at 5d3ba47 satisfies every other assertion here while silently
# dropping the provenance correction this ticket exists to preserve. Counting
# commits cannot see that; the sentence can. Anchored to a substring that sits
# entirely on PREREGISTRATION.md:204 — the sentence itself wraps to line 205.
# ---------------------------------------------------------------------------
if grep -q "Both fixes postdate the runs published here" bench/PREREGISTRATION.md 2>/dev/null; then
  pass "AC-1: the imported PREREGISTRATION.md carries the provenance correction (d63ff3b)"
else
  fail "AC-1: the provenance correction is missing — the import came from a stale clone"
fi

# ---------------------------------------------------------------------------
# AC-2 — the preregistration commit precedes every round-two run.
#
# Round-two membership is DERIVED, never globbed. A date glob on 20260816-* sweeps
# in 20260816-010513 and 20260816-020247, which are round-one runs recorded before
# the preregistration commit.
#
# The derivation is on the run id (the timestamp prefix), not the filename:
# commit 3 renamed two round-one files, so "files this commit added" misclassifies
# 20260815-225842-frontend-withdrawn-different-prompt and 20260816-020247-frontend
# as round two. Their run ids are already in the preregistration tree, so a set
# difference over run ids gets it right and a set difference over paths does not.
# ---------------------------------------------------------------------------
run_ids() { sed 's|.*/||; s|^\([0-9]\{8\}-[0-9]\{6\}\).*|\1|' | sort -u; }

if [[ -n "${PRE_COMMIT:-}" ]]; then
  R1=$(git ls-tree -r --name-only "$PRE_COMMIT" -- data/runs | run_ids)
  ALL=$(ls bench/data/runs 2>/dev/null | run_ids)
  ROUND2=$(comm -13 <(echo "$R1") <(echo "$ALL"))

  if [[ -z "$ROUND2" ]]; then
    fail "AC-2: derivation produced no round-two runs — the set difference is wrong or bench/ is missing"
  else
    EARLIEST=$(echo "$ROUND2" | head -1)
    # Both sides to epoch: the commit, and the run id encoded in the filename.
    #
    # The run id is a wall-clock stamp with no timezone in it, and every timestamp in
    # this corpus was recorded in +0900. Parsing it in the host's zone would be right
    # here and on a UTC runner, and wrong on a UTC+10 host — where the 50-minute margin
    # flips sign and the assertion fails on correct data. TZ is pinned so the comparison
    # means the same thing everywhere.
    PRE_EPOCH=$(git log -1 --format=%at "$PRE_COMMIT")
    RUN_EPOCH=$(TZ=Asia/Seoul date -j -f '%Y%m%d-%H%M%S' "$EARLIEST" +%s 2>/dev/null \
             || TZ=Asia/Seoul date -d "${EARLIEST:0:4}-${EARLIEST:4:2}-${EARLIEST:6:2} ${EARLIEST:9:2}:${EARLIEST:11:2}:${EARLIEST:13:2}" +%s)

    if [[ "$PRE_EPOCH" -lt "$RUN_EPOCH" ]]; then
      pass "AC-2: preregistration precedes the earliest derived round-two run ($EARLIEST) by $(( (RUN_EPOCH - PRE_EPOCH) / 60 ))m"
    else
      fail "AC-2: preregistration commit is NOT earlier than $EARLIEST — the preregistration claim does not hold"
    fi
  fi
else
  fail "AC-2: preregistration commit not found in the imported history"
fi

# ---------------------------------------------------------------------------
# AC-3 — the loader refuses a record with no fingerprint.
# Exercised through the built package, against a synthetic record, so it cannot
# pass merely because today's corpus happens to be well-formed.
#
# The record below is missing more than one required field — since PDX-017 it has no
# regime either — so this assertion depends on the loader's check order rather than on
# the record's shape alone. That order is fixed deliberately in `parseAcceptanceRecord`
# (fingerprint, then the environment audit, then the regime) and this scenario is named
# in the comment there. Adding a regime here would make the assertion pass for a weaker
# reason: the point is that the *first* refusal is the one about traceability.
# ---------------------------------------------------------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx002.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/runs"
printf '{"run":"synthetic","env":{},"cells":[]}\n' > "$SB/runs/synthetic.acceptance.json"

if node -e "
  const { loadAcceptanceRecords } = require('./packages/data/dist/index.js');
  try { loadAcceptanceRecords({ dir: process.argv[1] }); process.exit(0); }
  catch (e) { process.exit(e.name === 'MissingFingerprintError' ? 42 : 1); }
" "$SB/runs" 2>/dev/null; then
  fail "AC-3: the loader accepted a record with no npm_fingerprint"
else
  [[ $? -eq 42 ]] \
    && pass "AC-3: the loader throws MissingFingerprintError on a fingerprint-less record" \
    || fail "AC-3: the loader failed, but not with MissingFingerprintError (package not built?)"
fi

# ---------------------------------------------------------------------------
# AC-4 — one fingerprint across the whole acceptance corpus.
# ---------------------------------------------------------------------------
FPS=$(grep -ho '"npm_fingerprint": *"[^"]*"' bench/data/runs/*.acceptance.json 2>/dev/null \
      | sed 's/.*: *"//; s/"//' | sort -u)
N_FP=$(echo "$FPS" | grep -c . || true)

if [[ "$N_FP" -eq 1 && "$FPS" == "4b140e75d7dc1828" ]]; then
  pass "AC-4: every acceptance record carries one fingerprint ($FPS)"
else
  fail "AC-4: expected exactly one fingerprint 4b140e75d7dc1828, found: $(echo "$FPS" | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
# AC-5 — verify.sh no longer runs in empty-workspace mode.
# Exit code alone asserts nothing: verify.sh exits 0 in that mode too.
# ---------------------------------------------------------------------------
VOUT="$(./scripts/verify.sh 2>&1)"
VRC=$?

if [[ $VRC -ne 0 ]]; then
  fail "AC-5: verify.sh failed"
elif grep -qi "EMPTY-WORKSPACE MODE" <<< "$VOUT"; then
  fail "AC-5: verify.sh passed but skipped the Node steps (still empty-workspace mode)"
else
  pass "AC-5: verify.sh passes with the Node steps executed"
fi

# ---------------------------------------------------------------------------
# AC-6 — LANG-01 holds over the imported tree.
# ---------------------------------------------------------------------------
if ./scripts/check-language.sh >/dev/null 2>&1; then
  pass "AC-6: LANG-01 passes with bench/ present"
else
  fail "AC-6: LANG-01 BLOCKs on the imported artifacts"
fi

# ---------------------------------------------------------------------------
# AC-7 — the README describes one project.
# Anchored to a sentence that exists today, so this assertion is red before step 7.
# ---------------------------------------------------------------------------
if grep -q "The measurement harness and its data exist" README.md; then
  fail "AC-7: README still describes the harness and the catalogue as two things standing apart"
else
  pass "AC-7: the two-projects sentence is gone from README.md"
fi

if [[ $FAILED -ne 0 ]]; then
  echo -e "${RED}PDX-002 scenario FAILED${NC}" >&2
  exit 1
fi

echo -e "${GREEN}PDX-002 scenario PASS${NC}"
