CASE_DESC="DATA-02e: a record that does not say which regime it ran under — absent must never read as blocked"
GATE="scripts/check-data-universe.sh"
EXPECT_PATTERN="DATA-02e"

# Writes one acceptance record. Every case plants its own corpus and its own analysis
# loader: the sandbox copies `scripts/` and nothing else, so a case that assumed the real
# `bench/` would be testing the repository rather than the gate.
#
# `regime` is written verbatim, and the literal string `omit` leaves the key out
# entirely — the one shape a parser must never read as `blocked`.
plant_record() {
  local file="$1" run="$2" regime="$3"
  mkdir -p bench/data/runs
  RUN="$run" REGIME="$regime" python3 - "bench/data/runs/$file" <<'PY'
import json, os, sys

run = os.environ["RUN"]
regime = os.environ["REGIME"]
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

if regime != "omit":
    record["regime"] = regime

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(record, handle)
PY
}

# An analysis loader that reads both governing facts off the record — the shape DATA-02d
# and DATA-02g both ask for.
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
            cell["_regime"] = record["regime"]
            cells.append(cell)

    return cells
PY
}

plant() {
  plant_field_reading_loader

  # The regression this rule exists to prevent: a run written without the field, which
  # before PDX-017 would have been silently pooled as `blocked` by a substring test on
  # its own filename. Nothing else here is wrong — no withdrawal exists for DATA-02a/b/c
  # to find, and the planted loader reads both fields, so DATA-02d and g stay green.
  plant_record "20200101-000000-unstated.acceptance.json" "20200101-000000" omit
  plant_record "20200102-000000-clean.acceptance.json" "20200102-000000" blocked
}
