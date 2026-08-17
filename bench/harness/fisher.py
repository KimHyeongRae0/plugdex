#!/usr/bin/env python3
"""Two-tailed Fisher exact test, and a loader for the graded corpus.

scipy is not installed on the measurement machine, so the test is implemented directly
from the hypergeometric distribution. That is deliberate rather than a workaround: every
number this repository publishes should be reproducible with a stock Python, the same way
`analyze.py` implements Wilcoxon and the bootstrap itself.

The implementation validates itself against three textbook tables at import time and
raises rather than returning a number if any of them is off. A statistics routine that
silently returns a plausible wrong value is worse than one that is missing.
"""
import glob
import json
import os
from math import comb

RUNS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "runs")

# The run withdrawn as instrument failure 16: it carried an extra instruction the other
# runs did not, and was graded against a different set of installed packages. It is
# excluded by default and kept on disk rather than deleted.
WITHDRAWN_RUN = "20260815-225842"


def fisher_exact_two_tailed(table):
    """p for [[a, b], [c, d]] with both margins fixed.

    Two-tailed by the conventional definition: the sum of the probabilities of every
    table with the same margins whose probability is no greater than the observed one.
    """
    (a, b), (c, d) = table
    n = a + b + c + d
    row1, row2 = a + b, c + d
    col1 = a + c

    def prob(x):
        return comb(row1, x) * comb(row2, col1 - x) / comb(n, col1)

    p_observed = prob(a)
    lo, hi = max(0, col1 - row2), min(row1, col1)

    # The tolerance keeps a table that is equiprobable with the observed one from being
    # dropped by floating-point noise, which would understate p on symmetric tables.
    return sum(prob(x) for x in range(lo, hi + 1) if prob(x) <= p_observed * (1 + 1e-12))


_TEXTBOOK = [
    ([[3, 1], [1, 3]], 0.4857),    # Fisher's tea-tasting experiment
    ([[1, 9], [11, 3]], 0.0028),   # standard worked example
    ([[10, 0], [0, 10]], 2 / 92378),  # complete separation, n=20
]

for _table, _expected in _TEXTBOOK:
    _got = fisher_exact_two_tailed(_table)
    if abs(_got - _expected) > 5e-4:
        raise AssertionError(f"fisher_exact_two_tailed({_table}) = {_got}, expected {_expected}")


def load_cells(include_withdrawn=False, runs_dir=RUNS_DIR):
    """Every graded cell from the acceptance records, newest schema.

    Each cell gains `_run` and `_regime`. The regime is read off the filename because the
    runner gained that stamp after these runs were written, so it is not a field on the
    record — a run-level condition that moves the baseline build rate from 35% to 73%
    living only in a human-readable filename is a DATA-01 problem in spirit, and this
    function is where that is paid for.
    """
    cells = []

    for path in sorted(glob.glob(os.path.join(runs_dir, "*.acceptance.json"))):
        name = os.path.basename(path)

        if not include_withdrawn and name.startswith(WITHDRAWN_RUN):
            continue

        for cell in json.load(open(path, encoding="utf-8"))["cells"]:
            cell = dict(cell)
            cell["_run"] = name.split(".")[0]
            cell["_regime"] = "as-shipped" if "as-shipped" in name else "blocked"
            cells.append(cell)

    return cells


def rate_table(cells, outcome="passes"):
    """{arm: (successes, n)} over the cells given, skipping cells the outcome is None on."""
    table = {}

    for cell in cells:
        if cell.get(outcome) is None:
            continue

        hits, n = table.get(cell["arm"], (0, 0))
        table[cell["arm"]] = (hits + (cell[outcome] is True), n + 1)

    return table


if __name__ == "__main__":
    print(f"fisher.py: {len(_TEXTBOOK)} textbook tables validated")
    print(f"corpus: {len(load_cells())} cells ({len(load_cells(include_withdrawn=True))} with the withdrawn run)")
