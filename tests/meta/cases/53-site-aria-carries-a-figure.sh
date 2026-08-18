CASE_DESC="DATA-01b: a figure in a spoken ARIA attribute is blocked — a screen reader is a reader"
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

  # Round 2 of the report review put figures through these attributes into built output,
  # and the fix that followed shipped with no case at all — reverting the widened
  # attribute set would still have passed the whole golden run. This is that case.
  # `aria-hidden` is here too, carrying nothing a reader hears, so the rule is shown to
  # be about what is spoken rather than about the `aria-` prefix.
  cat > packages/site/src/components/Spoken.astro <<'ASTRO'
---
const gridColumns = 3;
---

<span aria-hidden="true">▪</span>
<p aria-description="47% of deliveries build">builds</p>
ASTRO
}
