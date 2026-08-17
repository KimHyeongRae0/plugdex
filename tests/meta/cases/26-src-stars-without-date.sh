CASE_DESC="SRC-01a: a star count with no date it was read is blocked — a claim with no expiry"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="stars"
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'x', displayName: 'x',
  author: { from: 'curated', value: 'A', why: 'stated' },
  upstreamRepo: { from: 'curated', value: 'o/r', why: 'stated' },
  license: { from: 'curated', value: 'MIT', why: 'stated' },
  stars: { count: 42 },
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => '';
export const readManifest = () => ({});
export const readSource = () => ({ repo: 'o/r', commit: 'abc', path: 'p', readAt: '2026-08-17', stars: 42, receipt: { starsCommand: 'gh api repos/o/r --jq .stargazers_count', readAt: '2026-08-17T00:00:00Z', fullName: 'o/r', forks: 0 } });
JS
}
