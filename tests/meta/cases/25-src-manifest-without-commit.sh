CASE_DESC="SRC-01f: a recorded manifest with no source commit is blocked — an audit with no fixed point"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="SRC-01f"
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'x', displayName: 'x',
  author: { from: 'curated', value: 'A', why: 'stated' },
  upstreamRepo: { from: 'curated', value: 'o/r', why: 'stated' },
  license: { from: 'curated', value: 'MIT', why: 'stated' },
  stars: { count: 1, readAt: '2026-08-17' },
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => '';
export const readManifest = () => ({});
export const readSource = () => ({ repo: 'o/r', commit: '', path: 'p', readAt: '2026-08-17', stars: 1 });
JS
}
