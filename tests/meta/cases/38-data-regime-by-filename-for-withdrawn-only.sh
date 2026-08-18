CASE_DESC="DATA-02g: a loader that derives the regime from the filename for withdrawn records only is still caught"
GATE="scripts/check-data-universe.sh"
EXPECT_PATTERN="DATA-02g"
# Writes one acceptance record. Every case plants its own corpus and its own analysis
# loader: the sandbox copies `scripts/` and nothing else, so a case that assumed the real
# `bench/` would be testing the repository rather than the gate.
plant_record() {
  local file="$1" run="$2" regime="$3"
  mkdir -p bench/data/runs
  RUN="$run" REGIME="$regime" python3 - "bench/data/runs/$file" <<'PY'
import json, os, sys

run = os.environ["RUN"]
regime = os.environ["REGIME"]
record = {
    "run": run,
    "regime": regime,
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

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(record, handle)
PY
}

plant() {
  # The live corpus is entirely consistent, so a through f are all green and only the
  # behavioural probe can fire.
  plant_record "20200101-000000-first.acceptance.json" "20200101-000000" blocked
  plant_record "20200102-000000-second.acceptance.json" "20200102-000000" "as-shipped"

  # The partial regression. This loader reads the record for live runs and falls back to
  # the filename only for withdrawn ones — the shape that slipped past the DATA-02g probe
  # until the PDX-017 report review found that the probe's own withdrawn decoy agreed
  # with the filename it was supposed to contradict. A mechanism that is wrong on a
  # subset is still a filename deciding a regime, and the corpus it corrupts is the
  # pooled view every withdrawal argument is made in.
  mkdir -p bench/harness
  cat > bench/harness/fisher.py <<'PY'
import glob, json, os


def load_cells(include_withdrawn=False, runs_dir="bench/data/runs"):
    cells = []

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        name = os.path.basename(path)
        record = json.load(open(path, encoding="utf-8"))
        withdrawn = record.get("withdrawn") is not None

        if withdrawn and not include_withdrawn:
            continue

        for cell in record["cells"]:
            cell = dict(cell)
            cell["_run"] = name.split(".")[0]

            if withdrawn:
                cell["_regime"] = "as-shipped" if "as-shipped" in name else "blocked"
            else:
                cell["_regime"] = record["regime"]

            cells.append(cell)

    return cells
PY
}
