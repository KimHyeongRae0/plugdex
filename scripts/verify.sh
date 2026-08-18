#!/usr/bin/env bash
# scripts/verify.sh
#
# Mandatory static verification after implementation.
# language + structure + gate self-test + no-llm + templates + typecheck + lint +
# test + build — all must pass.
#
# While the workspace has no package yet (packages/ lands from PDX-002), Node
# steps are skipped with a loud warning ("empty-workspace mode") so the
# harness-only bootstrap can still run the gate. The pnpm-workspace.yaml file
# ships at PDX-001, so the skip keys on the absence of any packages/*/package.json,
# not on the workspace manifest.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck source=lib/gate-log.sh
source "$PROJECT_ROOT/scripts/lib/gate-log.sh"
gate_log_init "verify" "-" "${*:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

fail() { GATE_LOG_DETAIL="$1"; echo -e "${RED}❌ $1 FAILED${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}✅ $1 passed${NC}"; }
step() { echo -e "\n${BOLD}${YELLOW}>>> $1${NC}"; }
skip() { echo -e "${YELLOW}⏭  $1${NC}"; }

START_TS=$(date +%s)

# ---- 1. Language (LANG-01) ----
step "1/12 Language gate (LANG-01)"
./scripts/check-language.sh || fail "check-language"

# ---- 2. Structure (ST-*) ----
step "2/12 Structure gate"
./scripts/check-structure.sh || fail "check-structure"

# ---- 3. Gate self-test (golden set, tests/meta) ----
step "3/12 Gate self-test"
if [[ "${PLUGDEX_GATE_SANDBOX:-0}" == "1" ]]; then
  skip "inside a gate sandbox — self-test skipped (recursion guard)"
else
  ./scripts/check-gates.sh || fail "check-gates"
fi

# ---- 4. No-LLM (NOLLM-01) ----
step "4/12 No-LLM gate (NOLLM-01)"
./scripts/check-no-llm.sh || fail "check-no-llm"

# ---- 5. Templates (TMPL-01) ----
step "5/12 Templates gate (TMPL-01)"
./scripts/check-templates.sh || fail "check-templates"

# ---- 6. Record universe (DATA-02) ----
# Before the workspace check on purpose: the gate reads `bench/` and the analysis loader
# with stock python, so it has an answer whether or not a package has landed yet. The
# facts it guards decide what every published figure is computed over, and those existed
# before the first package did.
step "6/12 Record-universe gate (DATA-02)"
./scripts/check-data-universe.sh || fail "DATA-02"

HAS_PKG=0
for p in packages/*/package.json; do
  [[ -f "$p" ]] && { HAS_PKG=1; break; }
done
if [[ "$HAS_PKG" -eq 0 ]]; then
  echo -e "\n${BOLD}${YELLOW}⚠️  ⚠️  ⚠️  EMPTY-WORKSPACE MODE — no packages/*/package.json yet; Node steps (typecheck/lint/test/build) SKIPPED ⚠️  ⚠️  ⚠️${NC}"
  skip "first package lands with PDX-002; until then verify runs in empty-workspace mode"
  echo -e "\n${BOLD}${GREEN}========== VERIFY PASS (empty-workspace mode, $(( $(date +%s) - START_TS ))s) ==========${NC}"
  exit 0
fi

command -v node >/dev/null || fail "node not found in PATH"
command -v pnpm >/dev/null || fail "pnpm not found in PATH"

# ---- 7. Figure provenance (DATA-01) ----
# After the workspace check, because it parses site source with the site package's own
# pinned compiler. DATA-02 decides which records a figure is computed over; DATA-01
# decides that the figure came from a record at all.
step "7/12 Figure-provenance gate (DATA-01)"
./scripts/check-data.sh || fail "DATA-01"

# ---- 8. Typecheck ----
step "8/12 pnpm typecheck"
pnpm typecheck || fail "pnpm typecheck"
ok "typecheck"

# ---- 9. Lint ----
step "9/12 pnpm lint"
pnpm lint || fail "pnpm lint"
ok "lint"

# ---- 10. Tests ----
step "10/12 pnpm test"
pnpm test || fail "pnpm test"
ok "test"

# ---- 11. Build ----
step "11/12 pnpm build"
pnpm build || fail "pnpm build"
ok "build"

# ---- 12. SRC-01 ----
# Runs after the build on purpose: the gate reads the built registry, because what a
# consumer installs is generated output rather than source. Before the build there is
# nothing to check, and the gate says so rather than passing.
step "12/12 Attribution gate (SRC-01)"
./scripts/check-src.sh || fail "SRC-01"
ok "SRC-01"

echo -e "\n${BOLD}${GREEN}========== VERIFY PASS ($(( $(date +%s) - START_TS ))s) ==========${NC}"
