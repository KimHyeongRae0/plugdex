CASE_DESC="DATA-01 clean pass: element access, slice-class arguments, machine-facing attributes and a digit-free content are all legal"
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

  # Plan step 10's exemption plants, which shipped uncovered until the PDX-004 report
  # review said so. Every allowance the gate grants is exercised here, so a future
  # tightening that quietly revokes one fails this case instead of somebody's work.
  #
  # The slice-class list in particular was added *by* the ticket that wrote this gate and
  # had no case at all, against the gate's own rule that an allowlist may only be extended
  # together with a case.
  mkdir -p packages/site/src/styles
  cat > packages/site/src/styles/exempt.css <<'CSS'
.grid {
  grid-template-columns: repeat(3, 1fr);
  z-index: 10;
  gap: 8px;
}

/* A digit-free `content` — so the CSS rule is shown to block on the digit and on attr(),
   not on the property. */
.card::after {
  content: "→";
}
CSS

  cat > packages/site/src/components/Exempt.astro <<'ASTRO'
---
interface Props {
  cells: readonly string[];
  list: readonly string[];
}

const { cells, list } = Astro.props;

/** Layout vocabulary. */
const gridColumns = 3;

/** Element access and slice-class arguments: positions in a sequence, not measurements. */
const first = cells[3];
const pair = list.slice(0, 2);
const head = list.at(0);
const padded = 'x'.padStart(4, '0');
---

<svg viewBox="0 0 24 24" width="24" height="24"></svg>
<button tabindex="0" class="col-6" style={`--columns: ${gridColumns}`}>copy</button>
<meta name="viewport" content="width=device-width, initial-scale=1" />
<p>{first}{pair.length ? head : null}{padded ? null : null}</p>
ASTRO
}
