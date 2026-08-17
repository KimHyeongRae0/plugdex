#!/usr/bin/env bash
# scripts/check-references.sh
#
# REF-01 gate — the reference gate (DESIGN.md, Reference Map). Before a design/implementation
# step, its mandated reference material must actually be opened and recorded. This
# gate reads a plan document and verifies that its "References Consulted" section
# names each reference required for that ticket, marked consulted with a "Y".
#
# The ticket -> required-references mapping below is embedded from DESIGN.md.
# Each reference is a grep token (case-insensitive) the plan author must include on
# a References Consulted row alongside a "Y" mark:
#
#   PDX-002  data package        acceptance.json · PREREGISTRATION · gate-limits
#   PDX-003  registry package    marketplace.schema.json · plugin.json · plugin marketplace add
#   PDX-004  site catalogue      site-design · WCAG contrast
#   PDX-005  receipt drawer      _invocation.json · acceptance cells
#   PDX-006  shape summaries     bootstrap CI · radar chart critique
#
# The mapping exists because plugdex republishes measurements and other people's
# packs. A plan that reaches those without opening the artefact it is citing is how
# a wrong number reaches the site, so the reference is a gate rather than a habit.
#
# Exemption list: PDX-001 — the harness copy source (orangerail) is itself the
# reference, so no separate row is required. Exempt tickets PASS with an
# info line. Tickets with no mapping (and not exempt) have no required references and
# also PASS.
#
# Usage:
#   ./scripts/check-references.sh .docs/analysis/PDX-002_plan.md

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PLAN="${1:-}"
[[ -z "$PLAN" ]] && { echo "usage: $0 <path-to-plan.md>" >&2; exit 2; }
[[ ! -f "$PLAN" ]] && { echo -e "${RED}❌ plan not found: $PLAN${NC}" >&2; exit 2; }

TKT="$(basename "$PLAN" | sed -E 's/_(plan|report)\.md$//')"

# shellcheck source=lib/gate-log.sh
source "$PROJECT_ROOT/scripts/lib/gate-log.sh"
gate_log_init "check-references" "$TKT" "${*:-}"

# ---- embedded mapping (DESIGN.md, Reference Map) ----
required_refs() {
  case "$1" in
    PDX-002) printf '%s\n' "acceptance.json" "PREREGISTRATION" "gate-limits" ;;
    PDX-003) printf '%s\n' "marketplace.schema.json" "plugin.json" "plugin marketplace add" ;;
    PDX-004) printf '%s\n' "site-design" "WCAG contrast" ;;
    PDX-005) printf '%s\n' "_invocation.json" "acceptance cells" ;;
    PDX-006) printf '%s\n' "bootstrap CI" "radar chart critique" ;;
    *) : ;;
  esac
}
is_exempt() { [[ "$1" == "PDX-001" ]]; }

if is_exempt "$TKT"; then
  echo -e "${BLUE}ℹ️  REF-01: $TKT is on the exemption list — no references required${NC}"
  echo -e "${GREEN}✅ REF-01 PASS${NC}"
  exit 0
fi

REQ=()
while IFS= read -r r; do [[ -n "$r" ]] && REQ+=("$r"); done < <(required_refs "$TKT")

if [[ ${#REQ[@]} -eq 0 ]]; then
  echo -e "${BLUE}ℹ️  REF-01: $TKT has no mapped references (§6.5.1) — nothing required${NC}"
  echo -e "${GREEN}✅ REF-01 PASS${NC}"
  exit 0
fi

# ---- extract the References Consulted section ----
SECTION="$(awk '/^## .*References Consulted/{f=1;next} f&&/^## /{f=0} f' "$PLAN")"
if [[ -z "$(printf '%s' "$SECTION" | tr -d '[:space:]')" ]]; then
  echo -e "${BOLD}${RED}========== REF-01 BLOCK — no References Consulted section ==========${NC}" >&2
  echo -e "${RED}$TKT requires a 'References Consulted' section listing: ${REQ[*]}${NC}" >&2
  echo -e "${RED}Add §8.5 References Consulted to $PLAN (see _PLAN_TEMPLATE.md).${NC}" >&2
  exit 1
fi

MISSING=()
for tok in "${REQ[@]}"; do
  MATCHES="$(printf '%s\n' "$SECTION" | grep -iF "$tok" || true)"
  if [[ -z "$MATCHES" ]]; then
    MISSING+=("$tok — not listed")
    continue
  fi
  if ! printf '%s\n' "$MATCHES" | grep -qE '(^|[^A-Za-z])Y([^A-Za-z]|$)'; then
    MISSING+=("$tok — listed but not marked consulted (Y)")
  fi
done

echo ""
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo -e "${BOLD}${RED}========== REF-01 BLOCK — required references not consulted ($TKT) ==========${NC}" >&2
  for m in "${MISSING[@]}"; do echo -e "${RED}  ✗ $m${NC}" >&2; done
  echo -e "${RED}Open each reference and record it as 'Y (date) — note' in References Consulted (§6.5.1).${NC}" >&2
  exit 1
fi
echo -e "${GREEN}✅ REF-01 PASS — all ${#REQ[@]} required reference(s) consulted for $TKT${NC}"
