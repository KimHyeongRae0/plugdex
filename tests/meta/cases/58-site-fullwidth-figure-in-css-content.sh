CASE_DESC="DATA-01c: a fullwidth figure inside a content declaration is blocked — two fixes that were each correct alone left their composition open"
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

  # Report review round 4 composed case 57's channel (non-ASCII numerals) with case 54's
  # (a CSS declaration), and found the gate exiting 0: the digit test had been widened to
  # \p{N} for the two markup scanners while the stylesheet scanner kept a private ASCII
  # test. Both fixes were correct in isolation. Neither covered the other's channel, and
  # the report called all five "closed and pinned" while this one was open.
  #
  # The second rule below is the false positive that came with the fix and must stay legal:
  # a single-line pseudo-element rule whose digit belongs to `width`, not to `content`.
  mkdir -p packages/site/src/styles
  cat > packages/site/src/styles/composed.css <<'CSS'
.rate::after {
  content: "４７％ builds";
}

.tick::before { content: "▪"; width: 12px; }
CSS
}
