CASE_DESC="DATA-01b: a figure typed into a .tsx JSX text node is blocked — ts.isJsxText is not ts.isStringLiteral, so the walk alone would have shipped the hole"
GATE="scripts/check-data.sh"
EXPECT_PATTERN="DATA-01b.*Claim.tsx"

# Every case plants its own site source under a sandbox that copies `scripts/` and
# nothing else. The gate resolves its two parsers from `packages/site`, so the case links
# the real workspace `node_modules` rather than installing: the parsers are the gate's
# contract and a case that used different ones would not be testing this gate.
plant_site() {
  mkdir -p bench/data/runs bench/harness packages/site/src/components
  cp -R "$PLUGDEX_REAL_ROOT/packages/site/package.json" packages/site/package.json
  ln -s "$PLUGDEX_REAL_ROOT/node_modules" node_modules 2>/dev/null || true
  ln -s "$PLUGDEX_REAL_ROOT/packages/site/node_modules" packages/site/node_modules 2>/dev/null || true
}

# The clean `.astro` companion, planted beside every `.tsx` fixture in this trio.
#
# It is load-bearing rather than scenery. A sandbox holding only a `.tsx` already exits
# non-zero before the walk change, because the gate's own scanned-file floor fires when it
# finds nothing to read — so a case matching bare `DATA-01` would have been green against
# a walk that never opened the file. The companion gives the walk something legitimate to
# find, and each case pins the specific rule id at the specific path.
plant_companion() {
  cat > packages/site/src/components/Companion.astro <<'ASTRO'
---
const gridColumns = 3;
---

<div class="grid" style={`--columns: ${gridColumns}`}>
  <p>a clean companion, so the walk has something legitimate to scan</p>
</div>
ASTRO
}

plant() {
  plant_site
  plant_companion

  # The shape the plan found by reading scanner 1: the visitor tests `ts.isStringLiteral`,
  # and a JSX text node is a `JsxText`, which is not one. Widening the walk to `.tsx`
  # without teaching the scanner about JSX text would have shipped a file that scans clean
  # while rendering a typed rate.
  cat > packages/site/src/components/Claim.tsx <<'TSX'
export const Claim = () => (
  <p className="claim">47% of deliveries build</p>
);
TSX
}
