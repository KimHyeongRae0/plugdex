CASE_DESC="SRC-01b: an attribution field that is a bare string rather than a tagged value is blocked"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="SRC-01b"
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'x', displayName: 'x',
  author: 'Some Person',
  upstreamRepo: { from: 'curated', value: 'o/r', why: 'stated' },
  license: { from: 'curated', value: 'MIT', why: 'stated' },
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => '';
export const readManifest = () => ({});
JS
}
