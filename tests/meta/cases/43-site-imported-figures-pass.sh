CASE_DESC="DATA-01 clean pass: imported figures and layout literals are not blocked"
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

  # Without this case the four above are satisfied by a gate that blocks everything. The
  # legitimate literals the ticket names are all here: layout vocabulary, a guard
  # comparison, digits in machine-facing attributes, and a stylesheet full of numbers.
  mkdir -p packages/site/src/styles
  cat > packages/site/src/styles/planted.css <<'CSS'
:root {
  --gap: 12px;
}

.grid {
  grid-template-columns: repeat(3, minmax(0, 1fr));
  padding: 16px;
}
CSS

  cat > packages/site/src/components/Legal.astro <<'ASTRO'
---
import { percentOf } from '@plugdex/data';

interface Props {
  silent: number;
  n: number;
}

const { silent, n } = Astro.props;

const breakpoint = 720;
const percent = n > 0 ? percentOf({ hits: silent, n }) : null;
---

<div class="pane" style={`--breakpoint: ${breakpoint}px`} tabindex="0" width="240">
  {percent === null ? null : <span class="rate">{percent}</span>}
</div>
ASTRO
}
