#!/usr/bin/env python3
"""D-001 — where `p = 0.060` came from, and what the corpus says instead.

Two things run here. The first searches the corpus **as it stood when the claim was
made** for any subset, outcome, or arm pair that yields 0.060, so the claim can be
reproduced or withdrawn on evidence rather than on memory. The second recomputes the
pack-vs-baseline comparison on the corpus as it stands now, with the withdrawn run
excluded and included, because the difference between those two is the whole story.

Reads nothing but committed records and makes no API calls. See bench/DERIVATIONS.md.

Usage:
    python3 bench/harness/derive_d001.py
"""
import itertools
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fisher import fisher_exact_two_tailed, load_cells, rate_table

TARGET = 0.060
CLAIM_COMMIT = "63735e6"

# The three runs that were in the tree at CLAIM_COMMIT, under that commit's paths. The
# schema then was a bare list of cells with no run envelope and no `domain` on every cell.
CLAIM_RUNS = [
    "20260815-225842-frontend-run1",
    "20260816-010513-backend-and-dead-frontend",
    "20260816-020247-frontend-run2",
]

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _show(path):
    """A file as committed at CLAIM_COMMIT."""
    return subprocess.run(
        ["git", "show", f"{CLAIM_COMMIT}:{path}"],
        cwd=REPO_ROOT, capture_output=True, text=True, check=True,
    ).stdout


def _tag(cell, run):
    cell = dict(cell)
    cell["_run"] = run
    cell["_domain"] = "frontend" if cell["task"].startswith("tmpl-fe") else "backend"
    return cell


def load_claim_corpus():
    """The acceptance records as committed at CLAIM_COMMIT, read straight out of git."""
    return [
        _tag(cell, run)
        for run in CLAIM_RUNS
        for cell in json.loads(_show(f"data/runs/{run}.acceptance.json"))
    ]


def load_claim_results():
    """The runner's own result records at CLAIM_COMMIT — `correct` and `safe` live here,
    not on the acceptance records, so a claim about them is a separate sweep."""
    cells = []

    for run in CLAIM_RUNS:
        blob = json.loads(_show(f"data/runs/{run}.results.json"))
        rows = blob["results"] if isinstance(blob, dict) else blob
        cells += [_tag(r, run) for r in rows if r.get("valid") is not False]

    return cells


def best_pairwise(cells, outcome):
    """Every arm pair on one outcome, sorted by p. Returns [] when the outcome is absent."""
    scored = rate_table(cells, outcome)
    results = []

    for left, right in itertools.combinations(sorted(scored), 2):
        hits_l, n_l = scored[left]
        hits_r, n_r = scored[right]

        if n_l and n_r:
            p = fisher_exact_two_tailed([[hits_l, n_l - hits_l], [hits_r, n_r - hits_r]])
            results.append((p, left, f"{hits_l}/{n_l}", right, f"{hits_r}/{n_r}"))

    return sorted(results)


def search_for_the_claim():
    cells = load_claim_corpus()
    print(f"=== corpus at {CLAIM_COMMIT}: {len(cells)} cells across {len(CLAIM_RUNS)} runs ===\n")

    subsets = {
        "all three runs": cells,
        "frontend (2 runs)": [c for c in cells if c["_domain"] == "frontend"],
        "backend": [c for c in cells if c["_domain"] == "backend"],
        "run2 alone": [c for c in cells if c["_run"].startswith("20260816-020247")],
        "run1 alone (withdrawn)": [c for c in cells if c["_run"].startswith("20260815-225842")],
    }
    outcomes = ["typecheck", "build", "passes", "wrote_code", "import_ok"]


    hits, swept, overall, nearest = [], 0, [], []

    for subset_name, subset in subsets.items():
        for code_only in (True, False):
            pool = [c for c in subset if c.get("valid", True)]

            if code_only:
                pool = [c for c in pool if c.get("wrote_code")]

            label = f"{subset_name} [{'code-producing' if code_only else 'all valid'}]"

            for outcome in outcomes:
                results = best_pairwise(pool, outcome)

                if not results:
                    continue

                swept += len(results)
                hits += [r for r in results if abs(r[0] - TARGET) < 0.0006]
                nearest += [(abs(r[0] - TARGET), r, label, outcome) for r in results]

                if code_only:
                    overall.append((results[0], label, outcome))

    # `correct` and `safe` are the runner's own verdicts rather than gate outcomes. They
    # are swept too, because "does the pack do anything at all" — the question DESIGN.md
    # files this number under — is a claim about those, not about whether code builds.
    results_cells = load_claim_results()
    results_subsets = {
        "all three runs": results_cells,
        "frontend (2 runs)": [c for c in results_cells if c["_domain"] == "frontend"],
        "backend": [c for c in results_cells if c["_domain"] == "backend"],
        "run2 alone": [c for c in results_cells if c["_run"].startswith("20260816-020247")],
    }

    for subset_name, subset in results_subsets.items():
        for outcome in ("correct", "safe"):
            found = best_pairwise(subset, outcome)
            swept += len(found)
            hits += [r for r in found if abs(r[0] - TARGET) < 0.0006]
            nearest += [(abs(r[0] - TARGET), r, subset_name, outcome) for r in found]

    best = min(overall)
    p, left, count_l, right, count_r = best[0]
    combos = len(subsets) * 2 * len(outcomes) + len(results_subsets) * 2
    print(f"swept {swept} arm pairs across {combos} subset x filter x outcome combinations")
    print(f"tables matching p = {TARGET}: {len(hits)}")
    print(f"best pairwise result on code-producing cells: {left} {count_l} vs {right} {count_r}")
    print(f"    p = {p:.4f}   ({best[1]}, outcome={best[2]})\n")

    if hits:
        print("MATCHES:")
        for row in hits:
            print(f"    {row}")
    else:
        _, row, label, outcome = min(nearest)
        near_p, left, count_l, right, count_r = row
        print(f"nearest value swept: p = {near_p:.4f}  ({left} {count_l} vs {right} {count_r},")
        print(f"    {label}, outcome={outcome})")
        print(f"\np = {TARGET} does not reproduce anywhere in this corpus. The claim is withdrawn.")


def current_corpus():
    print(f"\n=== the corpus now — blocked regime, haiku, code-producing, outcome=passes ===")

    for include_withdrawn in (False, True):
        cells = [
            c for c in load_cells(include_withdrawn=include_withdrawn)
            if c.get("valid") and c.get("wrote_code")
            and c["_regime"] == "blocked" and c["model"] == "haiku"
        ]
        scored = rate_table(cells, "passes")
        hits_b, n_b = scored["baseline"]

        packs = [a for a in sorted(scored) if a != "baseline" and scored[a][1] >= 5]
        threshold = 0.05 / len(packs)

        print(f"\nwithdrawn run {'INCLUDED' if include_withdrawn else 'excluded'}"
              f"   baseline {hits_b}/{n_b} = {100 * hits_b / n_b:.0f}%")

        for arm in packs:
            hits, n = scored[arm]
            p = fisher_exact_two_tailed([[hits, n - hits], [hits_b, n_b - hits_b]])
            verdict = "SIGNIFICANT" if p < threshold else ("nominal only" if p < 0.05 else "")
            print(f"    {arm:<12} {hits}/{n} = {100 * hits / n:>3.0f}%   p = {p:.4f}   {verdict}")

        print(f"    Bonferroni threshold for {len(packs)} pack-vs-baseline tests = {threshold:.4f}")


if __name__ == "__main__":
    search_for_the_claim()
    current_corpus()
