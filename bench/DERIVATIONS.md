# Derivations

Every statistical claim this repository publishes gets an entry here: the subset it was
computed on, the comparison it makes, the code that reproduces it, and the number that
came out. A claim with no entry here is a claim we cannot defend.

This file exists because of D-001. A number was published for a day, carried through the
commit that invalidated its inputs, and load-bearing for the shape of the product — and no
one could say where it came from.

The test code is `bench/harness/fisher.py`. It implements the two-tailed Fisher exact test
from the hypergeometric distribution, because `scipy` is not installed on the measurement
machine and a claim nobody can rerun is the thing this project objects to. It validates
itself against three textbook tables on import and raises rather than returning a number if
any of them is off.

---

## D-001 — "best pairwise Fisher p = 0.060" — **WITHDRAWN**

**Claimed in:** `bench/README.md:47`, `DESIGN.md` §4.1, §4.2, §4.3, and DEC-005.
**Introduced:** `63735e6` (2026-08-16), in the commit message and the README, with no
derivation attached.
**Status: withdrawn.** It does not reproduce on the corpus that existed when it was
written, and that corpus has since been partly retracted.

### Why it was looked at

DEC-005 — the landing view is a cell grid and not a leaderboard — cites this number as its
reason. The site's whole shape rests on it, so it had to be either defensible or gone.

### What the corpus was when the claim was made

At `63735e6` the tree held three runs:

| Run | Domain | Cells |
|---|---|--:|
| `20260815-225842` | frontend | 76 |
| `20260816-020247` | frontend | 75 |
| `20260816-010513` | backend + dead frontend | 165 |

`20260815-225842` was **later withdrawn** as instrument failure 16 — it was given an extra
instruction the other runs were not, and graded against a different set of installed
packages. The commit that withdrew it, `5d3ba47`, rewrote the headline table around this
sentence and left the sentence itself untouched. So the number outlived its own inputs.

### The search

Pairwise Fisher exact was computed over every plausible reading of "best pairwise", on the
corpus as it stood at `63735e6`:

- **subsets:** all three runs; the two frontend runs; the backend run; each frontend run
  alone
- **cell filters:** code-producing cells only, and all valid cells
- **outcomes:** `typecheck`, `build`, `passes`, `wrote_code`, `import_ok`, and the
  runner's own `correct` / `safe` verdicts from the results records
- **comparisons:** all arm pairs, not only pack-vs-baseline

58 subset x filter x outcome combinations, 424 arm pairs. **`p = 0.060` appears in none of
them.** The nearest value swept was `0.0732` — baseline 4/16 against ponytail 9/15, inside
the withdrawn run alone.

The best pairwise result on code-producing cells was **`p = 0.0009`** — baseline 7/32
against ponytail 20/31, identical under `typecheck`, `build`, and `passes`. Not `0.060`,
and not "not enough": significant by a wide margin, on the very corpus that was used to
argue no pack differs from another.

### What the number probably was

`bench/harness/analyze.py` is the only analysis tool in the repository, and it computes
**Wilcoxon signed-rank on task medians**, not Fisher exact — over `cost`, `duration_ms`,
`total_loc`, and `out_tokens`, not over whether the code builds. A `p` near `0.06` from
that tool would be a claim about **cost**, and calling it "Fisher" and filing it under
"does the pack do anything at all" would be two errors on top of each other. This is the
most likely origin and it is **not established**; it is written here as a hypothesis so the
next person does not repeat the search.

### What the corpus says now

Blocked regime, haiku, code-producing cells, outcome `passes`, each pack against baseline:

```
baseline    12/34 = 35%
ponytail    22/36 = 61%   p = 0.0352
karpathy    15/36 = 42%   p = 0.6299
mattpocock  15/36 = 42%   p = 0.6299
caveman     11/35 = 31%   p = 0.8015
Bonferroni threshold for 4 pack-vs-baseline tests = 0.0125
```

As-shipped regime: nothing close, the best being caveman at `p = 0.5147` on n=11 baseline.

**ponytail is nominally significant at 0.05 and does not clear the correction for testing
four packs.** The honest verdict is *inconclusive*, and it is inconclusive in the direction
of an effect rather than away from one.

### A correction to an earlier recomputation

The handoff at `832869b` §3.1 reported ponytail `31/51 = 61%` against baseline
`16/49 = 33%`, `p = 0.0055`, "clears Bonferroni". Those figures reproduce exactly — and
**only** — when the withdrawn run is included in the pool. Excluding it, as the published
headline table already does, gives the table above: the rate holds at 61%, the p-value
moves from `0.0055` to `0.0352`, and it stops clearing the correction. The recomputation
that found the problem had the same defect as the number it was checking.

### What this does to DEC-005

**DEC-005 stands, and its stated reason does not.** "Pairwise pack differences were not
significant" was never shown; on the original corpus the best pairwise difference was
`p = 0.0009`. The decision survives on different grounds, which are now the recorded ones:

1. One pack out of five showing a nominal effect that does not survive correction for four
   comparisons is not a ranking.
2. The effect that does show up is confined to one regime, and the regime is not a recorded
   field — it survives only in a filename (see the DATA-01 note in the handoff). A
   leaderboard would rank on a condition the dataset cannot state.
3. Four of five packs sit on top of baseline at `p > 0.6`. A ranking would order noise.

### Reproduce it

```bash
cd ~/Desktop/project/plugdex
python3 bench/harness/derive_d001.py           # the sweep, and the current-corpus table
```


---

## D-002 — "superpowers writes no code in N of M cells" — **count unreconciled, claim holds**

**Claimed in:** `5d3ba47`'s commit message as "68 of 69 valid cells"; the 2026-08-17
handoff as "61 of 62 valid haiku cells, plus 3 of 3 in the sonnet probe, plus 3 of 3 in
round three", which totals 67 of 68.

Counted directly off the published corpus — valid cells, withdrawn run excluded, which is
the same pool the headline build-rate table uses — the figure is **49 of 50**:

```
haiku   as-shipped   9/9
haiku   blocked     34/35
sonnet  blocked      6/6
```

The single exception is `tmpl-be-uniquetitle__superpowers__haiku__0`. Including the
withdrawn run gives 64 of 65, which is not either published figure either.

**The finding is not in doubt** — it is the strongest result in the project and it holds at
98% under every pool tried. What is unreconciled is the denominator: three counts of the
same thing disagree, and none of them says which pool it counted. Until that is settled,
`49 of 50` is the figure to publish, because it is the one that reproduces:

```bash
python3 - <<'EOF'
import sys; sys.path.insert(0, "bench/harness")
from fisher import load_cells
sp = [c for c in load_cells() if c["arm"] == "superpowers" and c.get("valid")]
print(sum(1 for c in sp if not c.get("wrote_code")), "of", len(sp))
EOF
```

**Next move:** find what the other two counts pooled. The likely cause is the same one
behind D-001 — a number computed on one corpus and carried forward across a change to it.
