CASE_DESC="DATA-01b: a script that writes a digit into the document is blocked, though script bodies are otherwise machine-facing"
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

  # Script bodies were exempt wholesale, which was inconsistent with the gate's own
  # treatment of the identical string in a `.ts` file, and report review round 3 used it.
  # The legal half is here too: a script doing arithmetic on values it was given, writing
  # nothing to the document, must stay legal or the exemption is worthless.
  cat > packages/site/src/components/Scripted.astro <<'ASTRO'
---
const gridColumns = 3;
---

<script>
  const columns = 3;
  const width = columns * 240;
  window.addEventListener('resize', () => void width);
  document.title = 'plugdex — 47% builds';
</script>
ASTRO
}
