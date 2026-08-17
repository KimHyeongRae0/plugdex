CASE_DESC="SRC-01a: a listing with no opt-out contact is blocked"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="SRC-01a"
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'x', displayName: 'x',
  author: { from: 'curated', value: 'A', why: 'stated' },
  upstreamRepo: { from: 'curated', value: 'o/r', why: 'stated' },
  license: { from: 'curated', value: 'MIT', why: 'stated' },
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: '',
}];
export const declaredAuthor = () => '';
export const readSource = () => ({ repo: 'o/r', commit: 'abc', path: 'p', readAt: '2026-08-17', stars: 1 });
export const readManifest = () => ({});
JS
}
