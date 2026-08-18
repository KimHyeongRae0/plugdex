CASE_DESC="DATA-01c: a digit in a CSS content declaration is blocked — the one property that puts a claim in front of a reader"
GATE="scripts/check-data.sh"
EXPECT_PATTERN="DATA-01c"

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

# A component whose every figure arrives as an import — the shape the gate asks for.
plant_clean_component() {
  cat > packages/site/src/components/Clean.astro <<'ASTRO'
---
import { formatRate } from '@plugdex/data';

interface Props {
  builds: number;
  n: number;
}

const { builds, n } = Astro.props;

/** Layout vocabulary: a number about the grid is not a figure about the measurement. */
const gridColumns = 3;
const rate = n > 0 ? formatRate({ hits: builds, n }) : null;
---

<div class="card" style={`--columns: ${gridColumns}`}>
  {rate ? <span class="rate">{rate}</span> : null}
</div>
ASTRO
}

plant() {
  plant_site
  plant_clean_component

  # Everything else in the stylesheet carries digits and stays legal. `content` is the
  # single exception, because it is the only property whose value a reader sees.
  mkdir -p packages/site/src/styles
  cat > packages/site/src/styles/planted.css <<'CSS'
:root {
  --gap: 12px;
  --columns: 3;
}

.card {
  padding: 16px 24px;
  grid-template-columns: repeat(3, 1fr);
}

.card::after {
  content: "47% builds";
}
CSS
}
