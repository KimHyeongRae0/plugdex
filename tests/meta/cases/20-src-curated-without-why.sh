CASE_DESC="SRC-01c: a curated attribution value with no stated reason is blocked"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="SRC-01c"
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'x', displayName: 'x',
  author: { from: 'curated', value: 'A', why: '' },
  upstreamRepo: { from: 'curated', value: 'o/r', why: 'stated' },
  license: { from: 'curated', value: 'MIT', why: 'stated' },
  stars: { count: 1, readAt: '2026-08-17' },
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => '';
export const readSource = () => ({ repo: 'o/r', commit: 'abc', path: 'p', readAt: '2026-08-17', stars: 1, receipt: { starsCommand: 'gh api repos/o/r --jq .stargazers_count', readAt: '2026-08-17T00:00:00Z', fullName: 'o/r', forks: 0 } });
export const readManifest = () => ({});
JS
}
