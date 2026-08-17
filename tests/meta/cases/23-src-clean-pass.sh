CASE_DESC="SRC-01: a fully attributed listing passes — the gate does not false-positive"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="SRC-01 PASS"
EXPECT_PASS=1
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'x', displayName: 'x',
  author: { from: 'upstream', value: 'Jesse Vincent' },
  upstreamRepo: { from: 'upstream', value: 'obra/superpowers' },
  license: { from: 'upstream', value: 'MIT' },
  stars: { count: 272966, readAt: '2026-08-17' },
  installSource: { source: 'github', repo: 'obra/superpowers' },
  listingProvenance: { how: 'measured', note: 'measured in this project' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => 'Jesse Vincent';
export const readManifest = () => ({ author: { name: 'Jesse Vincent' } });
export const readSource = () => ({ repo: 'obra/superpowers', commit: 'b36e082', path: '.claude-plugin/plugin.json', readAt: '2026-08-17', stars: 272966 });
JS
}
