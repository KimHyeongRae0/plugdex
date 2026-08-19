CASE_DESC="INST-01d: a blocked pack still fails, but on a different manifest key than the one recorded"
GATE='PATH="$PWD/bin:$PATH" PLUGDEX_INSTALLABILITY_DIR="$PWD/records" scripts/check-installability.sh'
EXPECT_PATTERN="INST-01d"
# Every case plants its own marketplace, its own records, and its own `claude` on PATH.
# The sandbox copies `scripts/` and nothing else, so a case that reached for the real
# manifest would be testing the repository rather than the gate. PATH rides inside the
# GATE string because `plant` and the gate run in separate subshells.
plant_cli() {
  mkdir -p bin
  cat > bin/claude <<'SHIM'
#!/usr/bin/env bash
set -uo pipefail

case "${1:-}" in
  --version) echo "2.1.233 (Claude Code)"; exit 0 ;;
  plugin) ;;
  *) exit 64 ;;
esac

case "${2:-}" in
  marketplace) echo "Successfully added marketplace: plugdex"; exit 0 ;;
  list) cat installed.txt 2>/dev/null || echo "No plugins installed."; exit 0 ;;
  install) ;;
  *) exit 64 ;;
esac

PACK="${3%%@*}"

if [[ -f "fail-$PACK.txt" ]]; then
  cat "fail-$PACK.txt"
  exit 1
fi

echo "Successfully installed plugin \"${3:-}\""
printf '  > %s@plugdex\n    Version: 1.0.0\n' "$PACK" >> installed.txt
exit 0
SHIM
  chmod +x bin/claude
}

plant_marketplace() {
  mkdir -p .claude-plugin
  python3 - "$@" <<'PY'
import json, sys

print(json.dumps({
    "name": "plugdex",
    "owner": {"name": "test"},
    "plugins": [
        {"name": name, "description": "golden case", "source": {"source": "github", "repo": f"owner/{name}"}}
        for name in sys.argv[1:]
    ],
}, indent=2), file=open(".claude-plugin/marketplace.json", "w"))
PY
}

plant_record() {
  PACK="$1" OUTCOME="$2" KEYS="${3:-}" python3 - <<'PY'
import json, os, pathlib

pack = os.environ["PACK"]
outcome = os.environ["OUTCOME"]
record = {
    "pack": pack,
    "repo": f"owner/{pack}",
    "cliVersion": "2.1.233 (Claude Code)",
    "attemptedAt": "2026-08-19T00:00:00Z",
    "upstreamHead": "0" * 40,
    "transport": "https",
    "outcome": outcome,
}

if outcome == "installs":
    # The shim's `plugin list` prints Version: 1.0.0, and INST-01f compares the record
    # against that in both directions — so a fixture that omits the field is not a clean
    # record, it is the deletion dodge case 68 plants deliberately.
    record["installedVersion"] = "1.0.0"

if outcome == "blocked":
    keys = [k for k in os.environ.get("KEYS", "").split(",") if k]
    record["signature"] = {"kind": "manifest-validation", "keys": sorted(keys)}
    record["verbatim"] = "Validation errors: " + ", ".join(f"{k}: Invalid input" for k in keys)

pathlib.Path("records").mkdir(exist_ok=True)
pathlib.Path(f"records/{pack}.json").write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
PY
}

plant_failure() {
  printf '%s\n' "$2" > "fail-$1.txt"
}

plant() {
  plant_cli
  plant_marketplace one
  plant_record one blocked agents
  plant_failure one "Validation errors: hooks: Invalid input"
}
