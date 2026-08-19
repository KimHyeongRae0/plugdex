CASE_DESC="DATA-01 clean pass: a .tsx whose figures are imported and whose literals are layout vocabulary passes, and its machine-facing attributes are exempt"
GATE="scripts/check-data.sh"
EXPECT_PASS=1
EXPECT_PATTERN="DATA-01 PASS"

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

  # A clean-pass case is the only shape that can hold a false-positive fix in place, and
  # this trio needs two of them held at once. The `JsxAttribute` exemption: `className`
  # and `data-mark-size` carry digits and are machine-facing, and the generic rule flags
  # both today because the context climb reaches the component's own declaration. The
  # dispatch: `const markSize = 8` is a digit-bearing line to the Astro parser, so a
  # `.tsx` mis-routed into the template scanner blocks on it — this case fails the moment
  # the routing regresses.
  cat > packages/site/src/components/Mark.tsx <<'TSX'
import { formatRate } from '@plugdex/data';

const markSize = 8;

export const Mark = ({ rate }: { rate: string }) => (
  <span className="mark-2" data-mark-size={markSize} style={{ width: markSize }}>
    {rate}
  </span>
);
TSX
}
