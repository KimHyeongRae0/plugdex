CASE_DESC="DATA-02d: an analysis loader that decides inclusion by filename is caught behaviourally, not by grep"
GATE="scripts/check-data-universe.sh"
EXPECT_PATTERN="DATA-02d"
# Writes one acceptance record. Every case plants its own corpus and its own analysis
# loader: the sandbox copies `scripts/` and nothing else, so a case that assumed the real
# `bench/` would be testing the repository rather than the gate.
plant_record() {
  local file="$1" run="$2" withdrawn="$3"
  mkdir -p bench/data/runs
  RUN="$run" WITHDRAWN="$withdrawn" python3 - "bench/data/runs/$file" <<'PY'
import json, os, sys

withdrawn = os.environ["WITHDRAWN"]
run = os.environ["RUN"]
record = {
    "run": run,
    "env": {
        "npm_fingerprint": "goldencase0000000",
        "npm_undeclared_toplevel": 0,
        "npm_packages": 1,
        "npm_installed": [],
        "npm_extraneous": [],
    },
    "cells": [
        {
            "cell": f"{run}__c{index}",
            "task": "t",
            "arm": "baseline",
            "model": "haiku",
            "rep": index,
            "valid": True,
            "build": True,
        }
        for index in range(2)
    ],
}

# PDX-017 made the regime required. These cases are about withdrawal, so every planted
# record carries a legal one and the case keeps testing what it was written to test.
record["regime"] = "blocked"

if withdrawn == "full":
    record["withdrawn"] = {"reason": "planted", "recorded_at": "2026-01-01T00:00:00+09:00"}
elif withdrawn == "empty-reason":
    record["withdrawn"] = {"reason": "   ", "recorded_at": "2026-01-01T00:00:00+09:00"}

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(record, handle)
PY
}

# An analysis loader that selects on the record's own field — the shape DATA-02d asks for.
plant_field_reading_loader() {
  mkdir -p bench/harness
  cat > bench/harness/fisher.py <<'PY'
import glob, json, os


def load_cells(include_withdrawn=False, runs_dir="bench/data/runs"):
    cells = []

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        record = json.load(open(path, encoding="utf-8"))

        if record.get("withdrawn") is not None and not include_withdrawn:
            continue

        for cell in record["cells"]:
            cell = dict(cell)
            cell["_run"] = os.path.basename(path).split(".")[0]
            # Read off the record, so DATA-02g stays green and each case trips one rule.
            cell["_regime"] = record["regime"]
            cells.append(cell)

    return cells
PY
}

plant() {
  # The corpus is fully consistent — one properly withdrawn run whose name and record
  # agree, one live run — so DATA-02a, b, and c are all green and only the behavioural
  # probe can fire.
  plant_record "20200101-000000-withdrawn-run.acceptance.json" "20200101-000000" full
  plant_record "20200102-000000-clean.acceptance.json" "20200102-000000" none

  # The old mechanism, restored: inclusion decided by a string prefix on the filename.
  #
  # Which arm of the probe catches this matters, and the next editor should not
  # "simplify" the other one away. The MARKED arm is the one that fires for any filename
  # mechanism however it is spelled: seeing a clean filename, the loader pools a record
  # the field says to exclude. The DECOY arm — a filename containing `withdrawn` over a
  # clean record — catches the inverse, a loader that drops records because of their
  # names; it also fires here, because this stub's constant happens to prefix the probe's
  # decoy run. Only the marked arm is guaranteed by construction, so a case that dropped
  # the decoy arm would still pass while losing half the coverage.
  mkdir -p bench/harness
  cat > bench/harness/fisher.py <<'PY'
import glob, json, os

WITHDRAWN_RUN = "20200101-000000"


def load_cells(include_withdrawn=False, runs_dir="bench/data/runs"):
    cells = []

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        name = os.path.basename(path)

        if not include_withdrawn and name.startswith(WITHDRAWN_RUN):
            continue

        record = json.load(open(path, encoding="utf-8"))

        for cell in record["cells"]:
            cell = dict(cell)
            cell["_run"] = name.split(".")[0]
            # Correct, so that only the withdrawal mechanism above is wrong and this case
            # trips DATA-02d alone rather than DATA-02g as well.
            cell["_regime"] = record["regime"]
            cells.append(cell)

    return cells
PY
}
