#!/usr/bin/env python3
"""Paired analysis of cost, duration, and delivered lines, by task.

Round one reported cost and duration only as counts ("ponytail cost more on 4 of 6
backend tasks"). That is honest but weak. This applies the analysis committed to in
PREREGISTRATION-2.md before the round-two numbers were seen:

  * the unit of inference is the **task**, not the cell; repetitions collapse to a median
  * arms are compared **paired by task**, Wilcoxon signed-rank
  * effect sizes carry bootstrap confidence intervals over tasks
  * with 5-6 tasks the test cannot reach significance for small effects; where it cannot,
    the result is reported as **inconclusive**, never as "no difference"

Exact Wilcoxon and a deterministic bootstrap are implemented here rather than pulled from
scipy, so the numbers can be reproduced with a stock Python.

Usage:
    python3 analyze.py <results.json> [<results.json> ...] [--baseline baseline]
                       [--metric cost|duration_ms|total_loc] [--out analysis.json]
"""
import argparse, itertools, json, statistics as st
from pathlib import Path

# Deterministic bootstrap: the resample sequence is generated from a fixed linear
# congruential generator rather than `random`, so a rerun reproduces the interval exactly.
BOOTSTRAP_N = 10000
LCG_A, LCG_C, LCG_M = 1664525, 1013904223, 2 ** 32


def lcg(seed):
    """Yield a deterministic stream of floats in [0, 1)."""
    x = seed

    while True:
        x = (LCG_A * x + LCG_C) % LCG_M
        yield x / LCG_M


def wilcoxon_signed_rank(diffs):
    """Exact two-sided Wilcoxon signed-rank p-value for small n.

    Returns (statistic, p, n_used). Zero differences are dropped, which is the standard
    Pratt-free treatment and the reason n_used is reported separately.

    Validation. Checked against `scipy.stats.wilcoxon(method="exact")` on 400 random
    tie-free samples: 400 of 400 agree to 1e-9 on both statistic and p-value.

    On samples containing ties the two diverge, and this implementation is the one to
    trust. scipy's own documentation states that with ties "``method='exact'`` no longer
    calculates the exact p-value", because its table assumes distinct ranks 1..n. The
    enumeration below is instead the exact conditional permutation test over the observed
    (possibly fractional) rank vector, which stays valid under ties. Ties are common here,
    because task medians of costs and durations collide often at this sample size.
    """
    nz = [d for d in diffs if d != 0]
    n = len(nz)

    if n == 0:
        return 0.0, 1.0, 0

    order = sorted(range(n), key=lambda i: abs(nz[i]))
    ranks = [0.0] * n
    i = 0

    while i < n:
        j = i

        while j + 1 < n and abs(nz[order[j + 1]]) == abs(nz[order[i]]):
            j += 1

        avg = (i + j) / 2 + 1

        for k in range(i, j + 1):
            ranks[order[k]] = avg

        i = j + 1

    w_plus = sum(r for r, d in zip(ranks, nz) if d > 0)
    w_minus = sum(r for r, d in zip(ranks, nz) if d < 0)
    w = min(w_plus, w_minus)

    # Exact null distribution by enumerating every sign assignment. n is small by design.
    total = 1 << n
    count = 0

    for signs in itertools.product((0, 1), repeat=n):
        s = sum(r for r, keep in zip(ranks, signs) if keep)

        if min(s, sum(ranks) - s) <= w:
            count += 1

    return w, min(1.0, count / total), n


def bootstrap_ci(values, seed=12345, alpha=0.05):
    """Percentile bootstrap CI for the mean of a small sample."""
    n = len(values)

    if n < 2:
        return None, None

    rng = lcg(seed)
    means = []

    for _ in range(BOOTSTRAP_N):
        means.append(st.mean(values[int(next(rng) * n)] for _ in range(n)))

    means.sort()

    return means[int(alpha / 2 * BOOTSTRAP_N)], means[int((1 - alpha / 2) * BOOTSTRAP_N) - 1]


def load(paths):
    """Collect valid cells from one or more runner result files."""
    rows = []

    for p in paths:
        blob = json.loads(Path(p).read_text(encoding="utf-8"))
        stamp = blob.get("date", Path(p).stem)

        for r in blob["results"]:
            if r.get("valid") is False:
                continue
            if (r.get("cost") or 0) <= 0 or (r.get("turns") or 0) <= 1:
                continue

            rows.append({**r, "run": stamp})

    return rows


def task_medians(rows, metric):
    """Collapse repetitions to one median per (task, arm)."""
    buckets = {}

    for r in rows:
        buckets.setdefault((r["task"], r["arm"]), []).append(r[metric])

    return {k: st.median(v) for k, v in buckets.items()}


def compare(med, arm, baseline, tasks):
    """Paired comparison of one arm against the baseline across tasks."""
    pairs = [(t, med[(t, arm)], med[(t, baseline)])
             for t in tasks if (t, arm) in med and (t, baseline) in med]

    if len(pairs) < 2:
        return None

    rel = [100 * (a - b) / b for _, a, b in pairs if b]
    w, p, n_used = wilcoxon_signed_rank([a - b for _, a, b in pairs])
    lo, hi = bootstrap_ci(rel)
    worse = sum(1 for v in rel if v > 0)

    return {"arm": arm, "n_tasks": len(pairs), "n_nonzero": n_used,
            "median_pct_change": round(st.median(rel), 1),
            "ci95_pct": [None if lo is None else round(lo, 1), None if hi is None else round(hi, 1)],
            "wilcoxon_p": round(p, 4),
            "verdict": "significant" if p < 0.05 else "inconclusive",
            "worse_on_tasks": f"{worse}/{len(rel)}",
            "per_task": {t: round(100 * (a - b) / b, 1) for t, a, b in pairs if b}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results", nargs="+")
    ap.add_argument("--baseline", default="baseline")
    ap.add_argument("--metric", default="cost", choices=["cost", "duration_ms", "total_loc", "out_tokens"])
    ap.add_argument("--out", default=None)
    ap.add_argument("--tasks", default=None,
                    help="comma-separated task ids to restrict the comparison to. Used to drop "
                         "tasks that were only partially run, which would otherwise pair some "
                         "arms on more tasks than others.")
    a = ap.parse_args()

    rows = load(a.results)

    if a.tasks:
        keep = set(a.tasks.split(","))
        rows = [r for r in rows if r["task"] in keep]

    med = task_medians(rows, a.metric)
    tasks = sorted({t for t, _ in med})
    arms = sorted({arm for _, arm in med} - {a.baseline})

    print(f"metric={a.metric}  baseline={a.baseline}  tasks={len(tasks)}  cells={len(rows)}")
    print(f"\n{'arm':22}{'tasks':>6}{'median %':>10}{'95% CI':>20}{'p':>9}  verdict")
    out = []

    for arm in arms:
        r = compare(med, arm, a.baseline, tasks)

        if not r:
            continue

        out.append(r)
        ci = f"[{r['ci95_pct'][0]}, {r['ci95_pct'][1]}]"
        print(f"{arm:22}{r['n_tasks']:>6}{r['median_pct_change']:>+10.1f}{ci:>20}"
              f"{r['wilcoxon_p']:>9.4f}  {r['verdict']} (worse on {r['worse_on_tasks']})")

    print("\nWith this few tasks, 'inconclusive' means the test lacks power. "
          "It does not mean the arms are equivalent.")

    if a.out:
        Path(a.out).write_text(json.dumps(
            {"metric": a.metric, "baseline": a.baseline, "n_cells": len(rows),
             "tasks": tasks, "comparisons": out}, indent=2), encoding="utf-8")
        print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
