#!/usr/bin/env bash
# scripts/check-data-universe.sh
#
# DATA-02 gate — no fact that governs the analysis lives outside the record.
#
# DATA-01 says no figure the site publishes is hand-typed. DATA-02 is its other half:
# the facts that decide *which records a figure is computed over* must be in the records
# too. The rule exists because this project shipped the opposite once. A run withdrawn as
# instrument failure 16 was excluded by a filename prefix matched inside one analysis
# script, so the fact governing every published figure lived where no type could reach
# it, no gate could check it, and the TypeScript half of the codebase could not see it at
# all. The two halves disagreed by 76 cells for as long as that lasted, and nothing in
# the repository could say so.
#
# **The boundary of what this gate enforces.** The principle above covers every
# run-level governing fact. Two are enforced here: withdrawal (a, b, c) and regime
# (e, f, g). Both were filename-derived once, and the regime — a condition that moves the
# baseline build rate from 25% to 73% — was the second half of DEC-015, closed by PDX-017
# under DEC-019. If a third such fact appears, it belongs on the record and in this gate,
# not in a name.
#
# Violations:
#   DATA-02a  a filename claims withdrawal while the record it names does not
#   DATA-02b  a record is withdrawn while the filename that carries it does not say so
#   DATA-02c  a `withdrawn` field with no reason or no recorded_at — an exclusion with
#             nothing to argue with is a deletion
#   DATA-02d  a filename comparison decides whether a live record enters an analysis
#             pool, proven behaviourally rather than by grep
#   DATA-02e  a record does not say which regime it ran under — absent must never read
#             as `blocked`, which is the pre-PDX-017 default with a field in front of it
#   DATA-02f  a regime outside {blocked, as-shipped}, near-misses included. A parser that
#             trims or case-folds would move a run between conditions on a typo
#   DATA-02g  a filename comparison decides a record's regime, again proven behaviourally
#             against a corpus whose names contradict its records
#
# Precedence: a file that trips DATA-02c is skipped by the agreement checks (a and b).
# A malformed withdrawal has no well-formed field for them to agree with, so reporting
# both would be one defect counted twice — and it would make the golden set's
# EXPECT_PATTERN prove less than it appears to. Two cases in this repository have already
# tripped a second rule by accident; the precedence is designed against that. The same
# rule holds one field over: a record tripping DATA-02e or DATA-02f is skipped by every
# other regime check, because a record with no legible regime has nothing for the
# behavioural probe to disagree with.
#
# ASSERT-01: the probe prints a sentinel on its success path, an empty or unprefixed
# capture is "the gate did not run" rather than a clean bill of health, and the scanned
# record count carries a floor. DATA-02d carries its own floors, so an empty synthetic
# corpus cannot vacuously agree.

set -uo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# shellcheck source=lib/gate-log.sh
source "$PROJECT_ROOT/scripts/lib/gate-log.sh"
gate_log_init "check-data-universe" "-" "${*:-}"

RUNS_DIR="bench/data/runs"
HARNESS_DIR="bench/harness"

if [[ ! -d "$RUNS_DIR" ]]; then
  echo -e "${RED}❌ DATA-02: $RUNS_DIR does not exist — the gate scanned nothing${NC}" >&2
  exit 1
fi

PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/plugdex-data02.XXXXXX")"
# Chained, not replaced: `gate_log_init` installs its own EXIT trap, and a bare
# `trap ... EXIT` here would silently drop this gate out of the OBS-01 log.
trap 'rc=$?; rm -rf "$PROBE_DIR"; gate_log_exit "$rc"' EXIT

# The probe is a file, never an inline heredoc inside `$(...)`: the shell re-lexes a
# command substitution, so an apostrophe or a parenthesis inside a Python string can eat
# an argument and leave the gate reporting on something it never read.
cat > "$PROBE_DIR/scan.py" <<'PY'
"""Reads the corpus and the analysis loader, and reports DATA-02 violations.

Prints one sentinel line carrying the counts, then one indented line per violation. The
sentinel is what tells the caller the probe ran at all.
"""
import json
import os
import secrets
import pathlib
import sys
import tempfile

runs = pathlib.Path(os.environ["RUNS_DIR"])
harness = pathlib.Path(os.environ["HARNESS_DIR"])
REGIMES = ("blocked", "as-shipped")

violations = []
records = 0

for path in sorted(runs.glob("*.acceptance.json")):
    records += 1
    name = path.name

    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except Exception as error:
        violations.append(f"DATA-02c {name}: the record is not readable JSON ({error})")
        continue

    # Presence, not truthiness: an explicit `"withdrawn": null` is a malformed
    # withdrawal, not an absent one. Reading it with `.get()` would let it through here
    # while the TypeScript loader refuses it, which is a two-halves disagreement inside
    # the gate that exists to stop them.
    withdrawn = "withdrawn" in record
    withdrawal = record.get("withdrawn")
    name_says = "withdrawn" in name.lower()

    if withdrawn:
        if not isinstance(withdrawal, dict):
            violations.append(
                f"DATA-02c {name}: withdrawn is present but is {type(withdrawal).__name__}, "
                "not an object"
            )
            continue

        reason = str(withdrawal.get("reason", "")).strip()
        recorded_at = str(withdrawal.get("recorded_at", "")).strip()

        if not reason:
            violations.append(f"DATA-02c {name}: withdrawn carries no reason")
            continue

        if not recorded_at:
            violations.append(f"DATA-02c {name}: withdrawn carries no recorded_at")
            continue

        if not name_says:
            violations.append(
                f"DATA-02b {name}: the record is withdrawn but the filename does not say so"
            )
    elif name_says:
        violations.append(
            f"DATA-02a {name}: the filename claims withdrawal but the record carries no "
            "withdrawn field — the exclusion exists only in the name"
        )

    # Regime, by presence and then by value. Matched exactly: no trimming, no case
    # folding. `Blocked` and `as shipped` are typos, and a gate forgiving enough to
    # accept them is a gate that lets a run change condition on a stray keystroke.
    if "regime" not in record:
        violations.append(
            f"DATA-02e {name}: the record does not say which regime it ran under — "
            "absent must never read as blocked"
        )
    elif record["regime"] not in REGIMES:
        violations.append(
            f"DATA-02f {name}: regime is {record['regime']!r}, expected one of "
            f"{', '.join(REGIMES)}"
        )

# DATA-02d. A grep would catch the spelling of the last bug; this catches the mechanism.
# Two records are planted whose filenames and records disagree on purpose, and the real
# loader is asked what it pools.
loader = harness / "fisher.py"

if not loader.exists():
    violations.append(f"DATA-02d {loader}: the analysis loader is missing — nothing was probed")
else:
    def synthetic(run, withdrawn, regime):
        record = {
            "run": run,
            # Deliberately contradicting the filename in both directions: see probe_runs.
            "regime": regime,
            "env": {
                "npm_fingerprint": "data02probe000000",
                "npm_undeclared_toplevel": 0,
                "npm_packages": 1,
                "npm_installed": [],
                "npm_extraneous": [],
            },
            "cells": [
                {
                    "cell": f"{run}__probe{index}",
                    "task": "probe",
                    "arm": "baseline",
                    "model": "haiku",
                    "rep": index,
                    "valid": True,
                    "build": True,
                }
                for index in range(2)
            ],
        }

        if withdrawn:
            record["withdrawn"] = {
                "reason": "planted by the DATA-02 gate probe",
                "recorded_at": "2026-01-01T00:00:00+09:00",
            }

        return record

    # decoy: the name says withdrawn, the record does not. Any filename mechanism,
    # however it is spelled, drops these cells and fails the first floor below.
    # marked: the record says withdrawn, the name does not. A loader that reads names
    # pools these cells and fails the second.
    #
    # The same three records also carry the DATA-02g decoy, so one sandbox covers both
    # fields: every one of them is recorded with the regime its filename does NOT imply,
    # in both directions. That includes the withdrawn record — it was recorded `blocked`
    # under a name that also derives `blocked`, so a loader deriving the regime for
    # withdrawn records only slipped through the probe unseen. The PDX-017 report review
    # found that hole; a decoy that agrees with the mechanism it is decoying is not a
    # decoy.
    # The run ids carry a per-invocation nonce. With fixed ids a loader could special-case
    # the probe's prefix and pass the gate while reading filenames everywhere else — the
    # PDX-017 report review demonstrated exactly that. A probe a defect can recognise is
    # not a probe, so the identifiers it is recognised by change every run.
    nonce = secrets.token_hex(4)
    probe_runs = {
        f"20200101-000000-{nonce}-withdrawn-by-name-only": (False, "as-shipped"),
        f"20200102-000000-{nonce}-marked-in-its-record": (True, "as-shipped"),
        f"20200103-000000-{nonce}-as-shipped-in-name-only": (False, "blocked"),
    }

    with tempfile.TemporaryDirectory() as sandbox:
        for run, (withdrawn, regime) in probe_runs.items():
            target = pathlib.Path(sandbox, f"{run}.acceptance.json")
            target.write_text(json.dumps(synthetic(run, withdrawn, regime)), encoding="utf-8")

        sys.path.insert(0, str(harness.resolve()))

        try:
            from fisher import load_cells

            default = load_cells(runs_dir=sandbox)
            pooled = load_cells(include_withdrawn=True, runs_dir=sandbox)
        except Exception as error:
            default = pooled = None
            violations.append(f"DATA-02d: the analysis loader raised on a clean corpus ({error})")

        if default is not None and pooled is not None:
            decoy = [cell for cell in default if "withdrawn-by-name-only" in cell.get("_run", "")]
            marked_default = [
                cell for cell in default if "marked-in-its-record" in cell.get("_run", "")
            ]
            marked_pooled = [
                cell for cell in pooled if "marked-in-its-record" in cell.get("_run", "")
            ]

            if len(decoy) < 1:
                violations.append(
                    "DATA-02d: a record whose filename says withdrawn but whose record does "
                    "not was dropped from the default pool — a filename is deciding inclusion"
                )

            if len(marked_default) > 0:
                violations.append(
                    "DATA-02d: a record marked withdrawn in its own record was pooled by "
                    "default — the loader is reading names, not records"
                )

            if len(marked_pooled) < 1:
                violations.append(
                    "DATA-02d: include_withdrawn=True did not pool the withdrawn record — "
                    "the withdrawn view is unreachable"
                )

            # DATA-02g, over the pooled view so the withdrawn record is checked too.
            expected = {run: regime for run, (_, regime) in probe_runs.items()}

            # A decoy that happens to agree with the filename mechanism proves nothing,
            # so the probe checks its own construction before checking the loader.
            agreeing = sorted(
                run for run, regime in expected.items()
                if regime == ("as-shipped" if "as-shipped" in run else "blocked")
            )

            if agreeing:
                violations.append(
                    "DATA-02d: the regime decoy is not a decoy — " + ", ".join(agreeing)
                    + " would derive the same value from the filename, so this probe "
                    "cannot see a loader that reads names"
                )

            mislabelled = sorted(
                f"{cell['_run']} read as {cell.get('_regime')!r}, recorded as {expected[cell['_run']]!r}"
                for cell in pooled
                if cell.get("_run") in expected and cell.get("_regime") != expected[cell["_run"]]
            )

            if not pooled:
                violations.append(
                    "DATA-02g: the probe corpus produced no cells — nothing was checked"
                )
            elif mislabelled:
                violations.append(
                    "DATA-02g: the analysis loader reports a regime the record does not "
                    "carry, so a filename is deciding it — " + "; ".join(mislabelled[:2])
                )

print("SENTINEL " + json.dumps({"records": records, "violations": len(violations)}))

for line in violations:
    print("   " + line)
PY

REPORT="$(RUNS_DIR="$RUNS_DIR" HARNESS_DIR="$HARNESS_DIR" python3 "$PROBE_DIR/scan.py" 2>&1)"

if [[ "$REPORT" != SENTINEL* ]]; then
  echo -e "${RED}❌ DATA-02: the gate produced no report — it did not run${NC}" >&2
  echo "$REPORT" | tail -5 >&2
  exit 1
fi

HEAD_LINE="$(printf '%s\n' "$REPORT" | head -1)"
RECORDS="$(printf '%s' "$HEAD_LINE" | sed 's/.*"records": *\([0-9]*\).*/\1/')"
VIOLATIONS="$(printf '%s' "$HEAD_LINE" | sed 's/.*"violations": *\([0-9]*\).*/\1/')"

if [[ "$RECORDS" -lt 1 ]]; then
  echo -e "${RED}❌ DATA-02: $RUNS_DIR holds no acceptance record — the gate checked nothing${NC}" >&2
  exit 1
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo -e "${RED}❌ DATA-02 BLOCK:${NC}" >&2
  printf '%s\n' "$REPORT" | tail -n +2 >&2
  exit 1
fi

echo -e "${GREEN}✅ DATA-02 PASS — $RECORDS records, every withdrawal and every regime on the record and no filename deciding either${NC}"
