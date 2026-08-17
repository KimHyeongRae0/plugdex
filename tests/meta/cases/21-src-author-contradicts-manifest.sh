CASE_DESC="SRC-01d: an upstream-tagged author that the pack's own manifest contradicts is blocked"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="SRC-01d"
plant() {
  mkdir -p packages/registry/dist
  cat > packages/registry/dist/index.js <<'JS'
export const entries = [{
  packId: 'karpathy', displayName: 'andrej-karpathy-skills',
  author: { from: 'upstream', value: 'Andrej Karpathy' },
  upstreamRepo: { from: 'curated', value: 'o/r', why: 'stated' },
  license: { from: 'curated', value: 'MIT', why: 'stated' },
  stars: { count: 1, readAt: '2026-08-17' },
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => 'forrestchang';
export const readSource = () => ({ repo: 'o/r', commit: 'abc', path: 'p', readAt: '2026-08-17', stars: 1, receipt: { starsCommand: 'gh api repos/o/r --jq .stargazers_count', readAt: '2026-08-17T00:00:00Z', fullName: 'o/r', forks: 0 } });
export const readManifest = () => ({ author: { name: 'forrestchang' } });
JS
}
