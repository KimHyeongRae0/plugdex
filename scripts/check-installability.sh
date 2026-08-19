#!/usr/bin/env bash
# scripts/check-installability.sh
#
# INST-01 — every listing's recorded install state still holds.
#
# For each plugin in `.claude-plugin/marketplace.json`, this runs a real install and
# compares the outcome against `packages/registry/installability/<pack>.json`:
#
#   record says   attempt                                      verdict
#   -----------   ------------------------------------------   -------------------------
#   installs      installs AND is listed afterwards            pass
#   installs      anything else                                INST-01b
#   installs      installs, but at a different version         INST-01f
#   blocked       fails, and the failure classifies the same   pass
#   blocked       INSTALLS                                     INST-01c — the dodge
#   blocked       fails differently, or unclassifiably         INST-01d
#
# INST-01c is the reason this gate exists in this shape. Without it, "record the pack as
# broken" would be a way to turn a red gate green — mark it once, and nothing ever tests
# the claim again. Here a blocked pack that starts installing is a FAILURE, because the
# record is then stale and someone has to refresh it. The gate never decides that for you.
#
# INST-01a and INST-01e come first: a listing with no record, a record for no listing, or
# a record this gate cannot act on BLOCKs rather than being skipped, so a malformed file
# can never quietly thin the coverage.
#
# Reproduction is judged by `scripts/lib/install-signature.py`, the same classifier the
# recorder used to write the record. That sharing replaces an earlier design in which this
# gate carried its own `grep -wF` key match — plan review round 1 broke it by pointing out
# that `-w` treats a hyphen as a word boundary, so `custom-agents: Invalid input` matched a
# record whose key was `agents`. With one classifier there is no match width to get wrong.
#
# Every listing produces one undecorated `INST-01 PACK <name> verdict=<verdict>` line on
# stdout beside the human-readable one. Callers count those rather than parsing coloured
# output: the first version of the PDX-003 assertion grepped the decorated lines and found
# none, because the escape sequence sits where the leading whitespace was expected.
#
# NOT part of `verify.sh`. Verify is what a contributor runs before every commit and it
# stays offline; this needs the network and a real CLI, so it runs from the PDX-003 e2e
# scenario and from the golden set (where a planted `claude` on PATH stands in for the CLI).

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck source=lib/gate-log.sh
source "$PROJECT_ROOT/scripts/lib/gate-log.sh"
gate_log_init "check-installability" "-" "${*:-}"

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

CLASSIFIER="$PROJECT_ROOT/scripts/lib/install-signature.py"
MARKETPLACE="$PROJECT_ROOT/.claude-plugin/marketplace.json"
RECORDS="${PLUGDEX_INSTALLABILITY_DIR:-$PROJECT_ROOT/packages/registry/installability}"

VIOLATIONS=0

violation() {
  # The machine line is emitted for failures too, so a scenario counting coverage sees
  # every listing the gate reached rather than only the ones that passed — a sweep that
  # looked at a pack and rejected it still looked at it.
  echo "INST-01 PACK ${PACK:-?} verdict=violation"
  echo -e "${RED}  ✗ $1${NC}" >&2
  VIOLATIONS=$((VIOLATIONS + 1))
}

die() { GATE_LOG_DETAIL="$1"; echo -e "${RED}❌ $1${NC}" >&2; exit 1; }

[[ -f "$MARKETPLACE" ]] || die "no marketplace manifest at $MARKETPLACE"
[[ -d "$RECORDS" ]] || die "no installability records at $RECORDS"
command -v claude >/dev/null 2>&1 || die "'claude' is not on PATH — an unrun install proves nothing, and a skip here would leave every listing unchecked while the gate stayed green"

# ---- INST-01a / INST-01e — the join, and the records' shape ----
# Structural first: a behavioural verdict on a listing whose record is missing or unusable
# would be a verdict about nothing.
JOIN="$(RECORDS="$RECORDS" MARKETPLACE="$MARKETPLACE" python3 "$PROJECT_ROOT/scripts/lib/installability-join.py" 2>&1)"
JOIN_STATUS=$?

if [[ "$JOIN_STATUS" -ne 0 ]]; then
  echo "$JOIN" >&2
  die "INST-01 structural check failed"
fi

PACKS="$(sed -n 's/^PACK //p' <<<"$JOIN")"
[[ -n "$PACKS" ]] || die "no listings to check — refusing to report a pass over an empty set"

RUNNING_CLI="$(claude --version 2>/dev/null | head -1)"
[[ -n "$RUNNING_CLI" ]] || die "'claude --version' printed nothing — the environment is not what it claims"

echo -e "${BOLD}INST-01 — every listing's recorded install state, re-measured with $RUNNING_CLI${NC}"

SB="$(mktemp -d "${TMPDIR:-/tmp}"/plugdex-inst.XXXXXX)"
SB="$(cd "$SB" && pwd -P)"
trap 'rm -rf "$SB"' EXIT

export CLAUDE_CONFIG_DIR="$SB/claude-home"
mkdir -p "$CLAUDE_CONFIG_DIR"

claude plugin marketplace add "$PROJECT_ROOT" >"$SB/add.log" 2>&1 ||
  die "'claude plugin marketplace add' rejected our own manifest — no per-pack verdict is meaningful: $(tail -2 "$SB/add.log" | tr '\n' ' ')"

CHECKED=0

while IFS= read -r PACK; do
  [[ -n "$PACK" ]] || continue

  RECORD="$RECORDS/$PACK.json"
  OUTCOME="$(python3 -c "
import json
print(json.load(open('$RECORD'))['outcome'])
")"

  LOG="$SB/$PACK.log"
  STATUS=0

  claude plugin install "${PACK}@plugdex" >"$LOG" 2>&1 || STATUS=$?

  if [[ "$STATUS" -ne 0 ]] &&
     grep -qE 'Permission denied \(publickey\)|Could not read from remote repository' "$LOG"; then
    STATUS=0

    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0='url.https://github.com/.insteadOf' \
    GIT_CONFIG_VALUE_0='git@github.com:' \
      claude plugin install "${PACK}@plugdex" >"$LOG" 2>&1 || STATUS=$?
  fi

  LISTED="$(claude plugin list 2>/dev/null)"
  IS_LISTED=1
  grep -qF "${PACK}@plugdex" <<<"$LISTED" || IS_LISTED=0

  CHECKED=$((CHECKED + 1))

  if [[ "$OUTCOME" == "installs" ]]; then
    if [[ "$STATUS" -eq 0 && "$IS_LISTED" -eq 1 ]]; then
      # INST-01f — the recorded version is re-measured too, not merely carried. The report
      # review of this ticket fabricated an `installedVersion` of 9.9.9 and watched it pass
      # both the offline test and this gate, because nothing compared it to anything. A
      # field no check reads is decoration, and this one is the closest thing the catalogue
      # gives a reader to "what you actually get".
      RECORDED_VERSION="$(python3 -c "
import json
print(json.load(open('$RECORD')).get('installedVersion', ''))
")"
      FRESH_VERSION="$(awk -v pack="${PACK}@plugdex" '
        index($0, pack) { seen = 1; next }
        seen && $1 == "Version:" { print $2; exit }
      ' <<<"$LISTED")"

      # Compared in BOTH directions. Report review round 2 pointed out that checking only
      # "the record names a version" leaves the deletion dodge open: drop the field and the
      # check never runs while the CLI still prints 1.0.0. An optional field is exactly
      # where a check goes to die, so absence is compared too — the record must say what the
      # install says, including saying nothing when the install says nothing.
      if [[ "$RECORDED_VERSION" != "$FRESH_VERSION" ]]; then
        violation "INST-01f: $PACK installs, but the record names version '${RECORDED_VERSION:-none}' and the install produced '${FRESH_VERSION:-none}' — refresh it: ./scripts/record-installability.sh --pack $PACK"
        continue
      fi

      echo "INST-01 PACK $PACK verdict=installs"
      echo -e "${GREEN}  ✓ $PACK — installs, as recorded${NC}"
    else
      violation "INST-01b: $PACK is recorded as installable and did not install (exit $STATUS, listed=$IS_LISTED) — $(tail -1 "$LOG" | cut -c1-140)"
    fi

    continue
  fi

  # outcome == blocked
  if [[ "$STATUS" -eq 0 ]]; then
    violation "INST-01c: $PACK is recorded as blocked and installed — the record is stale, and a blocked record is not a way to keep a gate green. Refresh it: ./scripts/record-installability.sh --pack $PACK"
    continue
  fi

  if [[ "$IS_LISTED" -eq 1 ]]; then
    violation "INST-01c: $PACK is recorded as blocked, its install failed, and it is in the installed list anyway — a half state is neither outcome"
    continue
  fi

  FRESH="$(python3 "$CLASSIFIER" <"$LOG" 2>&1)"
  CLASSIFIED=$?

  if [[ "$CLASSIFIED" -ne 0 ]]; then
    violation "INST-01d: $PACK failed in a way this repository cannot name — $FRESH. The record describes a different failure; re-record it or extend the classifier"
    continue
  fi

  RECORDED="$(python3 -c "
import json

signature = json.load(open('$RECORD'))['signature']
print(f\"SIGNATURE kind={signature['kind']} keys={','.join(sorted(signature['keys']))}\")
")"

  if [[ "$FRESH" == "$RECORDED" ]]; then
    echo "INST-01 PACK $PACK verdict=blocked-reproduced"
    echo -e "${GREEN}  ✓ $PACK — blocked, and the recorded failure reproduces (${RECORDED#SIGNATURE })${NC}"
  else
    violation "INST-01d: $PACK fails differently than recorded — recorded [${RECORDED#SIGNATURE }], now [${FRESH#SIGNATURE }]"
  fi
done <<<"$PACKS"

# Which CLI re-measured is part of the verdict, not decoration. A record names the CLI it
# was written with; CI installs whatever `npm install -g @anthropic-ai/claude-code` gives
# it that morning. When those differ the gate still re-measures — that is the honest test —
# but it says so, because "the recorded failure reproduces" means something weaker when the
# instrument changed. This is a notice rather than a violation: refusing to check on a newer
# CLI would leave a hub blind to exactly the release that breaks its listings.
DRIFTED="$(RECORDS="$RECORDS" RUNNING_CLI="$RUNNING_CLI" python3 -c "
import json, os, pathlib

running = os.environ['RUNNING_CLI']
drifted = [
    path.stem
    for path in sorted(pathlib.Path(os.environ['RECORDS']).glob('*.json'))
    if json.loads(path.read_text())['cliVersion'] != running
]

print(','.join(drifted))
")"

if [[ -n "$DRIFTED" ]]; then
  echo -e "\n${BOLD}NOTICE: re-measured with $RUNNING_CLI, which is not the CLI these records name: $DRIFTED${NC}"
  echo "  the outcomes above still hold for the CLI running here; refresh the records to make the two agree"
fi

EXPECTED="$(wc -l <<<"$PACKS" | tr -d ' ')"

if [[ "$CHECKED" -ne "$EXPECTED" ]]; then
  die "checked $CHECKED of $EXPECTED listings — a partial sweep is not a pass"
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo -e "\n${BOLD}${RED}========== INST-01 BLOCK ($VIOLATIONS violation(s) over $CHECKED listing(s)) ==========${NC}" >&2
  GATE_LOG_DETAIL="$VIOLATIONS violation(s)"
  exit 1
fi

echo -e "\n${BOLD}${GREEN}========== INST-01 PASS ($CHECKED listing(s), every recorded state reproduced) ==========${NC}"
