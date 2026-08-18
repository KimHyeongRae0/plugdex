CASE_DESC="DATA-01b: a digit in a reader-facing attribute is blocked; machine-facing attributes are not"
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

  # `class`, `style`, `width` and `tabindex` all carry digits here and must stay legal —
  # a gate that blocked those would be turned off within a week. Only the `title` a reader
  # can actually read is a violation.
  cat > packages/site/src/components/Attribute.astro <<'ASTRO'
---
const columnWidth = 12;
---

<img
  src="/chart.svg"
  class="col-6"
  style="width: 12rem"
  width="240"
  tabindex="0"
  alt="a chart"
  title="build rate 47 percent"
  data-columns={columnWidth}
/>
ASTRO
}
