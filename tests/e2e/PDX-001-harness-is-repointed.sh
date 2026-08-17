#!/usr/bin/env bash
# tests/e2e/PDX-001-harness-is-repointed.sh
#
# PDX-001 — the ported harness answers to plugdex, not to its source.
#
# check-gates.sh already proves the gates still catch what they were written to
# catch. What it cannot prove is that they are catching it FOR THIS PROJECT: a
# rename that missed a file leaves a gate enforcing the source project's registry,
# its ticket prefix, or its language allowlist, and every one of those still passes
# a self-test. This scenario asserts the re-pointing itself.
#
# Self-contained: reads the working tree, starts nothing, writes nothing.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-001 — harness is re-pointed at plugdex"

# ---- AC-4: no identifier from the port source survives ----
LEAK=$(grep -rIn -e 'ONT-[0-9]' -e 'orangerail' -e 'ontogate' -e 'ORANGERAIL_' -e 'ONTOGATE_' \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.docs --exclude-dir=dist \
  . 2>/dev/null | grep -v 'DESIGN\.md\|docs/WORKFLOW\.md\|CLAUDE\.md\|check-references\.sh\|PDX-001-harness-is-repointed\.sh' || true)

if [[ -n "$LEAK" ]]; then
  fail "port-source identifiers still present:"
  echo "$LEAK" | head -5 >&2
else
  pass "no port-source identifiers outside the prose that names the lineage"
fi

# ---- AC-5: the package registry is the plugdex one ----
if grep -q "PKG_ALLOWED='\^(site|data|registry)\\\$'" scripts/check-structure.sh; then
  pass "check-structure enforces the plugdex package registry"
else
  fail "check-structure does not carry the plugdex package registry (site|data|registry)"
fi

# ---- AC-3: LANG-01 carries no allowlist ----
# Asserted behaviourally, not by reading the source: plant Korean in the one file
# the lineage exempted and require a BLOCK.
SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx001.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
cp -R scripts "$SB/scripts"
printf '# DESIGN\n\n\xed\x95\x9c\xea\xb5\xad\xec\x96\xb4\n' > "$SB/DESIGN.md"

if ( cd "$SB" && scripts/check-language.sh ) >/dev/null 2>&1; then
  fail "LANG-01 passed Korean in DESIGN.md — an allowlist survived the port"
else
  pass "LANG-01 blocks Korean in DESIGN.md — no allowlist"
fi

# ---- AC-6: the Reference Map in the gate matches DESIGN.md ----
MISMATCH=0
for ref in "acceptance.json" "marketplace.schema.json" "site-design" "_invocation.json" "bootstrap CI"; do
  grep -q -- "$ref" scripts/check-references.sh || { fail "Reference Map missing '$ref' in the gate"; MISMATCH=1; }
  grep -q -- "$ref" DESIGN.md || { fail "Reference Map missing '$ref' in DESIGN.md"; MISMATCH=1; }
done
[[ $MISMATCH -eq 0 ]] && pass "Reference Map agrees between check-references.sh and DESIGN.md"

# ---- AC-7: the docs describe plugdex ----
if grep -q "plugdex is the hub for agent behaviour packs" CLAUDE.md && grep -q "DATA-01" docs/WORKFLOW.md; then
  pass "CLAUDE.md and docs/WORKFLOW.md describe plugdex's own rules"
else
  fail "project docs do not describe plugdex (missing the pitch line or the added rules)"
fi

if [[ $FAILED -ne 0 ]]; then
  echo -e "${RED}PDX-001 scenario FAILED${NC}" >&2
  exit 1
fi

echo -e "${GREEN}PDX-001 scenario PASS${NC}"
