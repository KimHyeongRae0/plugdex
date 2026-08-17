CASE_DESC="DATA-02a: a filename claims withdrawal while the record it names does not — the exclusion exists only in the name"
GATE="scripts/check-data-universe.sh"
EXPECT_PATTERN="DATA-02a"
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
            cells.append(cell)

    return cells
PY
}

plant() {
  plant_field_reading_loader

  # The regression this whole ticket exists to prevent: a future run withdrawn by
  # filename only. Nothing else here is wrong — there is no record-withdrawn run for
  # DATA-02b to catch, no `withdrawn` field for DATA-02c to find malformed, and the
  # planted loader reads the field, so DATA-02d is green.
  plant_record "20200101-000000-withdrawn-different-prompt.acceptance.json" "20200101-000000" none
  plant_record "20200102-000000-clean.acceptance.json" "20200102-000000" none
}
