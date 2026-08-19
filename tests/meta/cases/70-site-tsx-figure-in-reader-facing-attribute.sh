CASE_DESC="DATA-01b: a figure in a reader-facing .tsx attribute is blocked on the attribute, not on whatever declaration the context climb happens to reach"
GATE="scripts/check-data.sh"
EXPECT_PATTERN="DATA-01b.*Row.tsx"

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

  # The component name is the point. Climbing out of the attribute reaches
  # `LeaderboardRow`, `/row/i` is layout vocabulary, and the generic rule therefore
  # PASSES this figure — verified against the TypeScript API during the plan review. The
  # `JsxAttribute` branch fires on the attribute itself, which is what closes it.
  cat > packages/site/src/components/Row.tsx <<'TSX'
export const LeaderboardRow = () => (
  <td title="47% of deliveries build">see the analysis page</td>
);
TSX
}
