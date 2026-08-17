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
  installSource: { source: 'github', repo: 'o/r' },
  listingProvenance: { how: 'measured', note: 'n' },
  optOutContact: 'https://example.com/opt-out',
}];
export const declaredAuthor = () => 'forrestchang';
export const readManifest = () => ({ author: { name: 'forrestchang' } });
JS
}
