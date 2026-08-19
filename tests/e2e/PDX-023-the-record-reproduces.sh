#!/usr/bin/env bash
# tests/e2e/PDX-023-the-record-reproduces.sh
#
# PDX-023 — a listing states whether it installs, and the claim is measured.
#
# This scenario is deliberately OFFLINE. The real installs — five of them, against five
# third-party repositories — live in PDX-003's rewritten AC-5, because that is where a
# network assertion belongs and where failing rather than skipping is already the standing
# policy. What lives here is everything that can be proven without the network: the shared
# classifier's parse, and the recorder's behaviour driven by planted `claude` and `git`
# shims on PATH.
#
# The split matters. A classifier is the one component whose correctness is a claim about
# text, and text can be fed to it directly; a recorder is a component whose correctness is
# a claim about what it refuses to write, and a refusal is only observable when the thing
# it refuses is manufactured. Neither needs a network, and neither should wait on one.
#
# The load-bearing assertion is AC-1's refusal path: a failure the classifier cannot name
# must leave NO record behind. A recorder that approximates an unrecognised failure writes
# a record the gate will happily re-check forever, and INST-01 would then be defending a
# guess. Plan review round 1 broke the first design of this component with a counterexample
# — `Validation errors: custom-agents: Invalid input` matched a record whose key was
# `agents`, because `grep -w` treats a hyphen as a word boundary — so the counterexample is
# asserted here by name rather than trusted to a rewritten sentence.
#
# ASSERT-01 throughout. Every probe prints `SENTINEL {json}` on its success path, every
# assertion requires the sentinel before reading a capture, and an empty capture is a
# failure rather than a quiet pass. Probes are written to the sandbox and run by path,
# never inlined inside `$(...)`, because bash re-lexes a command substitution's body and a
# stray quote inside a Python string silently eats an argument.
#
# Nothing is published and nothing outside the repository is contacted (CR-01). The shims
# make that structural rather than promised: the `claude` this scenario runs is forty lines
# of bash in a scratch directory, and the `git` beside it answers `ls-remote` from a
# constant.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0
pass() { echo -e "${GREEN}  ✓ $1${NC}"; }
fail() { echo -e "${RED}  ✗ $1${NC}" >&2; FAILED=1; }

echo "PDX-023 — the record reproduces"

SB="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-pdx023.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

CLASSIFIER="$PROJECT_ROOT/scripts/lib/install-signature.py"
RECORDER="$PROJECT_ROOT/scripts/record-installability.sh"

# ---------------------------------------------------------------------------
# The shims.
#
# `claude` answers four verbs and takes its install behaviour from SHIM_MODE, which the
# recorder passes through untouched because it is an ordinary subprocess. The error text
# for the validation modes is copied from a real run against the live CLI (2.1.233) rather
# than invented, so a parse that only works on a plausible-looking string fails here.
# ---------------------------------------------------------------------------
mkdir -p "$SB/bin"

cat > "$SB/bin/claude" <<'SHIM'
#!/usr/bin/env bash
set -uo pipefail

case "${1:-}" in
  --version)
    echo "2.1.233 (Claude Code)"
    exit 0
    ;;
  plugin) ;;
  *) echo "shim: unsupported invocation: $*" >&2; exit 64 ;;
esac

case "${2:-}" in
  marketplace)
    echo "Successfully added marketplace: plugdex"
    exit 0
    ;;
  list)
    case "${SHIM_MODE:-ok}" in
      ok)
        printf 'Installed plugins:\n\n  > %s@plugdex\n    Version: 4.9.0\n    Scope: user\n    Status: enabled\n' "${SHIM_PACK:-probe}"
        ;;
      *)
        echo "No plugins installed. Use \`claude plugin install\` to install a plugin."
        ;;
    esac
    exit 0
    ;;
  install) ;;
  *) echo "shim: unsupported plugin verb: ${2:-}" >&2; exit 64 ;;
esac

case "${SHIM_MODE:-ok}" in
  ok)
    echo "Successfully installed plugin \"${3:-}\""
    exit 0
    ;;
  validation-agents)
    echo "Failed to install plugin \"${3:-}\": Plugin temp_github_1 has an invalid manifest file at /cache/temp_github_1/.claude-plugin/plugin.json."
    echo ""
    echo "Validation errors: agents: Invalid input"
    exit 1
    ;;
  validation-two-keys)
    echo "Failed to install plugin \"${3:-}\": Plugin temp_github_1 has an invalid manifest file at /cache/temp_github_1/.claude-plugin/plugin.json."
    echo ""
    echo "Validation errors: hooks: Invalid input, agents: Invalid input"
    exit 1
    ;;
  unclassifiable)
    echo "Failed to install plugin \"${3:-}\": the disk caught fire"
    exit 1
    ;;
  silent)
    exit 1
    ;;
  *)
    echo "shim: unknown SHIM_MODE ${SHIM_MODE:-}" >&2
    exit 64
    ;;
esac
SHIM
chmod +x "$SB/bin/claude"

cat > "$SB/bin/git" <<'SHIM'
#!/usr/bin/env bash
# Only `ls-remote` is shimmed; anything else is a bug in the caller, and saying so is
# better than silently answering a question this scenario never meant to answer.
set -uo pipefail

if [[ "${1:-}" == "ls-remote" ]]; then
  echo -e "1111111111111111111111111111111111111111\tHEAD"
  exit 0
fi

echo "shim: git $* is not shimmed" >&2
exit 64
SHIM
chmod +x "$SB/bin/git"

export SB PROJECT_ROOT CLASSIFIER RECORDER

# ---------------------------------------------------------------------------
# The verdict reader. Every probe answers in one shape.
# ---------------------------------------------------------------------------
cat > "$SB/verdict.py" <<'PY'
"""Reads one probe answer on stdin and prints the verdict the shell reports."""
import json, sys

try:
    result = json.load(sys.stdin)
except Exception as error:
    print(f"MALFORMED {error}")
    sys.exit(0)

print(("OK " if result.get("ok") else "BAD ") + str(result.get("detail", "")))
PY

judge() {
  local capture="$1" label="$2"

  if [[ "$capture" != SENTINEL\ * ]]; then
    fail "$label: the probe did not run (no sentinel; empty or crashed)"
    return
  fi

  local verdict
  verdict="$(printf '%s' "${capture#SENTINEL }" | python3 "$SB/verdict.py" 2>/dev/null)"

  case "$verdict" in
    OK\ *) pass "$label: ${verdict#OK }" ;;
    BAD\ *) fail "$label: ${verdict#BAD }" ;;
    *) fail "$label: the probe answered in a shape this scenario cannot read" ;;
  esac
}

# ---------------------------------------------------------------------------
# AC-1 (the classifier) — what it names, and what it refuses to name.
#
# Four logs, three of them measured against the live CLI and one manufactured to be
# unrecognisable. The third is plan review round 1's counterexample and the reason this
# component exists in its current form.
# ---------------------------------------------------------------------------
cat > "$SB/classify.py" <<'PY'
"""Feeds the classifier each log and checks the signature it returns, or its refusal."""
import json, os, subprocess

CLASSIFIER = os.environ["CLASSIFIER"]

CASES = [
    {
        "name": "the measured single-key failure",
        "log": (
            'Failed to install plugin "caveman@plugdex": Plugin temp_github_1 has an '
            "invalid manifest file at /cache/temp_github_1/.claude-plugin/plugin.json.\n"
            "\nValidation errors: agents: Invalid input\n"
        ),
        "expect": {"kind": "manifest-validation", "keys": ["agents"]},
    },
    {
        "name": "the measured two-key failure, emitted unsorted",
        "log": "Validation errors: hooks: Invalid input, agents: Invalid input\n",
        "expect": {"kind": "manifest-validation", "keys": ["agents", "hooks"]},
    },
    {
        "name": "round 1's counterexample",
        "log": "Validation errors: custom-agents: Invalid input\n",
        "expect": {"kind": "manifest-validation", "keys": ["custom-agents"]},
    },
    {
        "name": "a failure with no validation segment",
        "log": 'Failed to install plugin "x@y": the disk caught fire\n',
        "expect": None,
    },
    {
        "name": "an empty log",
        "log": "",
        "expect": None,
    },
]

problems = []
named = 0
refused = 0

for case in CASES:
    run = subprocess.run(
        ["python3", CLASSIFIER],
        input=case["log"],
        capture_output=True,
        text=True,
    )
    out = (run.stdout or "").strip()

    if case["expect"] is None:
        if run.returncode == 0:
            problems.append(f"{case['name']}: classified something it cannot name (exit 0)")
        elif not out.startswith("UNCLASSIFIED "):
            problems.append(
                f"{case['name']}: refused without saying so — output {out!r}; a silent "
                "refusal is indistinguishable from a crash"
            )
        else:
            refused += 1
        continue

    if run.returncode != 0:
        problems.append(f"{case['name']}: refused a log it should name — {out!r}")
        continue

    if not out.startswith("SIGNATURE "):
        problems.append(f"{case['name']}: answered in an unreadable shape — {out!r}")
        continue

    fields = dict(
        part.split("=", 1) for part in out[len("SIGNATURE "):].split() if "=" in part
    )
    keys = [k for k in fields.get("keys", "").split(",") if k]
    got = {"kind": fields.get("kind", ""), "keys": keys}

    if got != case["expect"]:
        problems.append(f"{case['name']}: expected {case['expect']}, got {got}")
    else:
        named += 1

# The counterexample is the whole point, so it gets its own assertion rather than riding
# on the loop's arithmetic: `agents` and `custom-agents` must not be the same signature.
one = subprocess.run(
    ["python3", CLASSIFIER],
    input="Validation errors: agents: Invalid input\n",
    capture_output=True,
    text=True,
).stdout.strip()
other = subprocess.run(
    ["python3", CLASSIFIER],
    input="Validation errors: custom-agents: Invalid input\n",
    capture_output=True,
    text=True,
).stdout.strip()

if one and one == other:
    problems.append(
        "`agents` and `custom-agents` classify identically — round 1's hole is open again"
    )

if named + refused != len(CASES) and not problems:
    problems.append("the probe did not reach a verdict on every case")

print(
    "SENTINEL "
    + json.dumps(
        {
            "ok": not problems,
            "detail": "; ".join(problems)
            or (
                f"{named} logs named, {refused} refused out loud, and `agents` never "
                "collides with `custom-agents`"
            ),
        }
    )
)
PY

CLASSIFY_OUT="$(python3 "$SB/classify.py" 2>/dev/null | tail -1)"
judge "$CLASSIFY_OUT" "AC-1 (the classifier)"

# ---------------------------------------------------------------------------
# AC-1 (the recorder) — three runs, three outcomes, and one of them writes nothing.
# ---------------------------------------------------------------------------
cat > "$SB/record.py" <<'PY'
"""Drives the recorder through the shims and inspects what it left on disk."""
import json, os, subprocess
from pathlib import Path

RECORDER = os.environ["RECORDER"]
SB = Path(os.environ["SB"])
ROOT = os.environ["PROJECT_ROOT"]

problems = []
wrote = []


def run(mode, pack, out_dir):
    env = dict(os.environ)
    env["PATH"] = f"{SB}/bin:" + env["PATH"]
    env["SHIM_MODE"] = mode
    env["SHIM_PACK"] = pack

    out_dir.mkdir(parents=True, exist_ok=True)

    return subprocess.run(
        [RECORDER, "--pack", pack, "--out", str(out_dir)],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
    )


def records_in(out_dir):
    return sorted(p.name for p in out_dir.glob("*.json"))


# 1. A clean install becomes an `installs` record.
out = SB / "rec-ok"
result = run("ok", "ponytail", out)
files = records_in(out)

if result.returncode != 0:
    problems.append(f"clean install: recorder exited {result.returncode} — {result.stderr.strip()[:160]}")
elif files != ["ponytail.json"]:
    problems.append(f"clean install: expected one record named for the pack, found {files}")
else:
    record = json.loads((out / "ponytail.json").read_text())
    if record.get("outcome") != "installs":
        problems.append(f"clean install: outcome is {record.get('outcome')!r}")
    elif not record.get("cliVersion"):
        problems.append("clean install: the record carries no CLI version")
    elif not record.get("attemptedAt"):
        problems.append("clean install: the record carries no attempt date")
    else:
        wrote.append("installs")

# 2. A validation failure becomes a `blocked` record carrying the key that failed.
out = SB / "rec-blocked"
result = run("validation-agents", "caveman", out)
files = records_in(out)

if result.returncode != 0:
    problems.append(f"blocked: recorder exited {result.returncode} — {result.stderr.strip()[:160]}")
elif files != ["caveman.json"]:
    problems.append(f"blocked: expected one record, found {files}")
else:
    record = json.loads((out / "caveman.json").read_text())
    signature = record.get("signature") or {}

    if record.get("outcome") != "blocked":
        problems.append(f"blocked: outcome is {record.get('outcome')!r}")
    elif signature.get("keys") != ["agents"]:
        problems.append(f"blocked: signature keys are {signature.get('keys')!r}, not ['agents']")
    elif not record.get("verbatim"):
        problems.append(
            "blocked: the record carries no verbatim error — a blocked listing that "
            "cannot quote its own failure is an assertion, not a receipt"
        )
    else:
        wrote.append("blocked")

# 3. A failure the classifier cannot name writes NOTHING. This is the load-bearing one.
out = SB / "rec-refused"
result = run("unclassifiable", "caveman", out)
files = records_in(out)

if result.returncode == 0:
    problems.append("unclassifiable: the recorder exited 0 on a failure it cannot name")
elif files:
    problems.append(
        f"unclassifiable: the recorder wrote {files} for a failure it cannot classify — "
        "a record the gate cannot re-check is a green gate waiting to happen"
    )
elif not (result.stdout + result.stderr).strip():
    problems.append("unclassifiable: the recorder refused in silence, saying nothing about why")
else:
    wrote.append("refusal")

print(
    "SENTINEL "
    + json.dumps(
        {
            "ok": not problems,
            "detail": "; ".join(problems)
            or "installs recorded, blocked recorded with keys ['agents'], and an "
               "unclassifiable failure left no record behind",
        }
    )
)
PY

RECORD_OUT="$(python3 "$SB/record.py" 2>/dev/null | tail -1)"
judge "$RECORD_OUT" "AC-1 (the recorder)"

# ---------------------------------------------------------------------------
# AC-2 — the join is total, and it is total in the built package rather than in source.
#
# What a consumer reads is `dist/`, so that is what is asserted. Every listing has a
# record and every record has a listing: a record for a pack nobody lists is as much a
# hole as a listing nobody measured, and only checking both directions catches the second.
# ---------------------------------------------------------------------------
cat > "$SB/join.mjs" <<'JS'
import { readFileSync } from 'node:fs';

const problems = [];

const marketplace = JSON.parse(
  readFileSync(`${process.env.PROJECT_ROOT}/.claude-plugin/marketplace.json`, 'utf8'),
);
const listed = marketplace.plugins.map((plugin) => plugin.name).sort();

let installability;

try {
  const registry = await import(`${process.env.PROJECT_ROOT}/packages/registry/dist/index.js`);
  installability = registry.installabilityRecords;
} catch (error) {
  problems.push(`the built registry could not be imported: ${String(error).split('\n')[0]}`);
}

// An absent export is not an exception — the import succeeds and the binding is
// `undefined`, so a bare `if (installability)` skips every check below and the probe
// reports a pass for a package that exports nothing. That is exactly the shape ASSERT-01
// exists to forbid, and the RED run of this scenario produced it: AC-2 went green while
// the feature did not exist. The absence is therefore an assertion of its own.
if (installability === undefined) {
  problems.push('the built registry exports no `installabilityRecords`');
} else if (typeof installability !== 'object' || installability === null) {
  problems.push(`\`installabilityRecords\` is ${typeof installability}, not a record map`);
} else if (Object.keys(installability).length === 0) {
  problems.push('`installabilityRecords` is empty — a join over nothing is total for free');
}

if (installability && Object.keys(installability).length > 0) {
  const recorded = Object.keys(installability).sort();

  if (listed.length === 0) {
    problems.push('no listings — the probe would have passed on an empty marketplace');
  }

  const unrecorded = listed.filter((name) => !recorded.includes(name));
  const unlisted = recorded.filter((name) => !listed.includes(name));

  if (unrecorded.length > 0) problems.push(`listed but not measured: ${unrecorded.join(', ')}`);
  if (unlisted.length > 0) problems.push(`measured but not listed: ${unlisted.join(', ')}`);

  for (const [name, record] of Object.entries(installability)) {
    if (!record.outcome) problems.push(`${name}: record carries no outcome`);
    if (record.outcome === 'blocked' && !(record.signature?.keys?.length > 0)) {
      problems.push(`${name}: blocked with no signature keys — nothing for the gate to re-check`);
    }
  }
}

console.log(
  'SENTINEL ' +
    JSON.stringify({
      ok: problems.length === 0,
      detail:
        problems.join('; ') ||
        `${listed.length} listings, each joined to a record in both directions`,
    }),
);
JS

JOIN_OUT="$(node "$SB/join.mjs" 2>/dev/null | tail -1)"
judge "$JOIN_OUT" "AC-2 (the join is total, in built output)"

# ---------------------------------------------------------------------------
# Result.
# ---------------------------------------------------------------------------
echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}PDX-023 PASS${NC}"
  exit 0
fi

echo -e "${RED}PDX-023 FAIL${NC}"
exit 1
