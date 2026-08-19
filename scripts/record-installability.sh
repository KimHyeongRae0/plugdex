#!/usr/bin/env bash
# scripts/record-installability.sh
#
# Writes `packages/registry/installability/<pack>.json` — the record saying whether a
# listed pack installs, and, when it does not, what it failed with.
#
# Nothing here is typed. The CLI version comes from `claude --version`, the upstream head
# from `git ls-remote`, the date from `date`, the outcome from a real `claude plugin
# install` into a scratch config directory, and the failure's signature from
# `scripts/lib/install-signature.py` — the same classifier `check-installability.sh` uses
# later to decide whether the failure still happens. That sharing is the point: a recorder
# and a gate with separate notions of what an error is would drift, and the gate would end
# up defending a claim nobody made.
#
# It fails closed. A failure the classifier cannot name leaves NO record behind and exits
# non-zero saying why, because a blocked record the gate cannot re-check is a green gate
# waiting to happen — the pack would be marked broken forever and nothing would ever test
# that it still is.
#
# CR-01: this contacts GitHub, because installing a `github` source clones from the
# author's repository, and that is the whole assertion. It publishes nothing and mutates no
# remote.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

CLASSIFIER="$PROJECT_ROOT/scripts/lib/install-signature.py"
MARKETPLACE="$PROJECT_ROOT/.claude-plugin/marketplace.json"
OUT_DIR="$PROJECT_ROOT/packages/registry/installability"
PACKS=()

die()  { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }
info() { echo -e "${YELLOW}$1${NC}"; }

usage() {
  cat <<'USAGE'
usage: record-installability.sh (--all | --pack <name> [--pack <name> ...]) [--out <dir>]

  --all          record every plugin listed in .claude-plugin/marketplace.json
  --pack <name>  record one listing; repeatable
  --out <dir>    write records here instead of packages/registry/installability

Exit status is non-zero if any pack's failure could not be classified. Nothing is written
for such a pack — see the header comment for why that is the safe direction.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)  PACKS=(__ALL__); shift ;;
    --pack) [[ $# -ge 2 ]] || die "--pack needs a name"; PACKS+=("$2"); shift 2 ;;
    --out)  [[ $# -ge 2 ]] || die "--out needs a directory"; OUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

[[ ${#PACKS[@]} -gt 0 ]] || { usage >&2; die "nothing to record — pass --all or --pack"; }
[[ -f "$MARKETPLACE" ]] || die "no marketplace manifest at $MARKETPLACE"
command -v claude >/dev/null 2>&1 || die "'claude' is not on PATH — an unrun install records nothing"

if [[ "${PACKS[0]}" == "__ALL__" ]]; then
  # `while read` rather than `mapfile`: mapfile is bash 4+, and macOS ships bash 3.2 as
  # /bin/bash. A gate that only runs on the CI runner is a gate contributors cannot use.
  PACKS=()
  while IFS= read -r name; do
    [[ -n "$name" ]] && PACKS+=("$name")
  done < <(python3 -c "
import json, sys

manifest = json.load(open('$MARKETPLACE'))
names = [plugin['name'] for plugin in manifest.get('plugins', [])]

if not names:
    sys.exit('no plugins listed')

print('\n'.join(names))
")
  [[ ${#PACKS[@]} -gt 0 ]] || die "no listing names read from $MARKETPLACE"
fi

mkdir -p "$OUT_DIR"

CLI_VERSION="$(claude --version 2>/dev/null | head -1)"
[[ -n "$CLI_VERSION" ]] || die "'claude --version' printed nothing — the environment is not what it claims"

ATTEMPTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FAILURES=0

for PACK in "${PACKS[@]}"; do
  REPO="$(python3 -c "
import json, sys

manifest = json.load(open('$MARKETPLACE'))

for plugin in manifest.get('plugins', []):
    if plugin['name'] == '$PACK':
        source = plugin.get('source') or {}
        print(source.get('repo', '') if isinstance(source, dict) else '')
        sys.exit(0)

sys.exit('not listed: $PACK')
")" || die "pack '$PACK' is not in $MARKETPLACE"

  UPSTREAM_HEAD="$(git ls-remote "https://github.com/$REPO" HEAD 2>/dev/null | awk '{print $1}' | head -1)"
  [[ -n "$UPSTREAM_HEAD" ]] || die "could not read the upstream head of $REPO — an unnamed version is not a record"

  # `${TMPDIR%/}` because a TMPDIR ending in a slash yields a doubled separator, and the
  # path the CLI prints back carries a single one.
  SB="$(mktemp -d "${TMPDIR:-/tmp}"/plugdex-record.XXXXXX)"
  SB="$(cd "$SB" && pwd -P)"
  LOG="$SB/install.log"

  (
    export CLAUDE_CONFIG_DIR="$SB/claude-home"
    mkdir -p "$CLAUDE_CONFIG_DIR"

    claude plugin marketplace add "$PROJECT_ROOT" >"$SB/add.log" 2>&1
  ) || { rm -rf "$SB"; die "'claude plugin marketplace add' rejected our own manifest — no per-pack record is meaningful"; }

  export CLAUDE_CONFIG_DIR="$SB/claude-home"

  # The CLI clones over SSH; a machine with no GitHub key fails with a publickey error
  # that says nothing about the manifest. One retry with an HTTPS rewrite scoped to the
  # process, exactly as the PDX-003 scenario does, and which transport worked is recorded.
  TRANSPORT="ssh"
  INSTALL_STATUS=0

  claude plugin install "${PACK}@plugdex" >"$LOG" 2>&1 || INSTALL_STATUS=$?

  if [[ "$INSTALL_STATUS" -ne 0 ]] &&
     grep -qE 'Permission denied \(publickey\)|Could not read from remote repository' "$LOG"; then
    TRANSPORT="https"
    INSTALL_STATUS=0

    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0='url.https://github.com/.insteadOf' \
    GIT_CONFIG_VALUE_0='git@github.com:' \
      claude plugin install "${PACK}@plugdex" >"$LOG" 2>&1 || INSTALL_STATUS=$?
  fi

  LISTED="$(claude plugin list 2>/dev/null)"
  unset CLAUDE_CONFIG_DIR

  RECORD="$OUT_DIR/${PACK}.json"
  TMP="$RECORD.tmp"

  if [[ "$INSTALL_STATUS" -eq 0 ]] && grep -qF "${PACK}@plugdex" <<<"$LISTED"; then
    # An exit code alone asserts nothing — the pack has to be in the installed list, and
    # the version beside it is the closest thing the CLI gives a reader to "what you get".
    VERSION="$(awk -v pack="${PACK}@plugdex" '
      index($0, pack) { seen = 1; next }
      seen && $1 == "Version:" { print $2; exit }
    ' <<<"$LISTED")"

    PACK="$PACK" REPO="$REPO" CLI_VERSION="$CLI_VERSION" ATTEMPTED_AT="$ATTEMPTED_AT" \
    UPSTREAM_HEAD="$UPSTREAM_HEAD" TRANSPORT="$TRANSPORT" VERSION="$VERSION" \
      python3 "$PROJECT_ROOT/scripts/lib/write-installability.py" installs >"$TMP" \
      || { rm -rf "$SB" "$TMP"; die "could not write the record for $PACK"; }

    mv "$TMP" "$RECORD"
    echo -e "${GREEN}RECORDED $PACK outcome=installs version=${VERSION:-unstated} transport=$TRANSPORT${NC}"
    rm -rf "$SB"
    continue
  fi

  if [[ "$INSTALL_STATUS" -eq 0 ]]; then
    rm -rf "$SB"
    die "$PACK: install exited 0 but the pack is not in 'claude plugin list' — a half state is neither outcome"
  fi

  SIGNATURE="$(python3 "$CLASSIFIER" <"$LOG" 2>&1)"
  CLASSIFIED=$?

  if [[ "$CLASSIFIED" -ne 0 ]]; then
    echo -e "${RED}REFUSED $PACK — ${SIGNATURE}${NC}" >&2
    echo -e "${RED}  nothing written: a blocked record this repository cannot re-check would mark the pack broken forever${NC}" >&2
    FAILURES=$((FAILURES + 1))
    rm -rf "$SB"
    continue
  fi

  KIND="$(sed -n 's/.*kind=\([^ ]*\).*/\1/p' <<<"$SIGNATURE")"
  KEYS="$(sed -n 's/.*keys=\([^ ]*\).*/\1/p' <<<"$SIGNATURE")"

  PACK="$PACK" REPO="$REPO" CLI_VERSION="$CLI_VERSION" ATTEMPTED_AT="$ATTEMPTED_AT" \
  UPSTREAM_HEAD="$UPSTREAM_HEAD" TRANSPORT="$TRANSPORT" KIND="$KIND" KEYS="$KEYS" \
  VERBATIM_FILE="$LOG" SCRATCH_DIR="$SB" \
    python3 "$PROJECT_ROOT/scripts/lib/write-installability.py" blocked >"$TMP" \
    || { rm -rf "$SB" "$TMP"; die "could not write the record for $PACK"; }

  mv "$TMP" "$RECORD"
  echo -e "${GREEN}RECORDED $PACK outcome=blocked kind=$KIND keys=$KEYS${NC}"
  rm -rf "$SB"
done

if [[ "$FAILURES" -gt 0 ]]; then
  echo -e "\n${BOLD}${RED}========== RECORDER REFUSED ($FAILURES unclassifiable) ==========${NC}" >&2
  exit 1
fi

echo -e "\n${BOLD}${GREEN}========== RECORDED (${#PACKS[@]} pack(s), $CLI_VERSION) ==========${NC}"
