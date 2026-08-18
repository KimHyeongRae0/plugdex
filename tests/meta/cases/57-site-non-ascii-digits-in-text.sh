CASE_DESC="DATA-01b: a figure written in fullwidth numerals is blocked — a figure is not an ASCII digit"
GATE="scripts/check-data.sh"
EXPECT_PATTERN="DATA-01b"

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

  # A goal audit drove this into built output through a plain text node, because the
  # scanner's digit test was `/\d/` and that is ASCII-only. Spelled-out figures are still
  # outside any digit scanner and are named as residue in DEC-017 rather than pretended
  # away.
  cat > packages/site/src/components/Wide.astro <<'ASTRO'
---
const gridColumns = 3;
---

<p>４７％ of deliveries build</p>
ASTRO
}
