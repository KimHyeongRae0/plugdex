/**
 * The listings.
 *
 * One entry per measured arm. Every attribution field is derived from the pack's own
 * recorded manifest where the manifest declares it, and `curated` with a stated reason
 * where it does not — so a reader can tell our claim from the author's at a glance.
 *
 * The arm ids here are the ids the measurement corpus uses, not the names the manifests
 * use, because AC-6 joins these against the arms actually measured. A pack whose listing
 * id drifted from its arm id would vanish from the catalogue while still being measured.
 */
import type { PackEntry } from './schema.js';
import { declaredAuthor, fromUpstream, readManifest } from './upstream.js';

const OPT_OUT = 'https://github.com/KimHyeongRae0/plugdex/issues/new?labels=opt-out';

/** An `upstream`-tagged author read from the pack's own manifest. */
const upstreamAuthor = ({ packId }: { packId: string }) =>
  fromUpstream({ packId, value: declaredAuthor({ manifest: readManifest({ packId }) }) });

export const entries: readonly PackEntry[] = [
  {
    packId: 'ponytail',
    displayName: 'ponytail',
    author: upstreamAuthor({ packId: 'ponytail' }),
    // The manifest declares no `repository`. The value below is the repository the
    // measured copy was cloned from, which is our identification of it, not theirs.
    upstreamRepo: {
      from: 'curated',
      value: 'DietrichGebert/ponytail',
      why: 'the pack manifest declares no repository field; this is the origin the measured copy was cloned from',
    },
    license: {
      from: 'curated',
      value: 'unstated',
      why: 'the pack manifest declares no license; we do not infer one on the author behalf',
    },
    installSource: { source: 'github', repo: 'DietrichGebert/ponytail' },
    listingProvenance: {
      how: 'measured',
      note: 'listed because it was measured in this project; the author was not consulted before listing',
    },
    optOutContact: OPT_OUT,
  },
  {
    packId: 'superpowers',
    displayName: 'superpowers',
    author: upstreamAuthor({ packId: 'superpowers' }),
    upstreamRepo: fromUpstream({ packId: 'superpowers', value: 'obra/superpowers' }),
    license: fromUpstream({ packId: 'superpowers', value: 'MIT' }),
    installSource: { source: 'github', repo: 'obra/superpowers' },
    listingProvenance: {
      how: 'measured',
      note: 'listed because it was measured in this project; the author was not consulted before listing',
    },
    optOutContact: OPT_OUT,
  },
  {
    packId: 'caveman',
    displayName: 'caveman',
    author: upstreamAuthor({ packId: 'caveman' }),
    upstreamRepo: {
      from: 'curated',
      value: 'JuliusBrussee/caveman',
      why: 'the pack manifest declares no repository field; this is the origin the measured copy was cloned from',
    },
    license: {
      from: 'curated',
      value: 'unstated',
      why: 'the pack manifest declares no license; we do not infer one on the author behalf',
    },
    installSource: { source: 'github', repo: 'JuliusBrussee/caveman' },
    listingProvenance: {
      how: 'measured',
      note: 'listed because it was measured in this project; the author was not consulted before listing',
    },
    optOutContact: OPT_OUT,
  },
  {
    // Commonly referred to as "Karpathy's skills". Its own manifest names a different
    // author, and the repository it is distributed from belongs to a third party as well.
    // It is a packaging of Andrej Karpathy's published CLAUDE.md, not his pack, so the
    // listed author is the one the manifest declares and the common name appears only as
    // a note. This is the case the Attribution assertion exists for.
    packId: 'karpathy',
    displayName: 'andrej-karpathy-skills',
    author: upstreamAuthor({ packId: 'karpathy' }),
    upstreamRepo: {
      from: 'curated',
      value: 'multica-ai/andrej-karpathy-skills',
      why: 'the pack manifest declares no repository field; this is the origin the measured copy was cloned from, and it belongs to neither the packager named in the manifest nor the author of the source CLAUDE.md',
    },
    license: fromUpstream({ packId: 'karpathy', value: 'MIT' }),
    installSource: { source: 'github', repo: 'multica-ai/andrej-karpathy-skills' },
    listingProvenance: {
      how: 'measured',
      note: 'listed because it was measured in this project; commonly called "Karpathy\'s skills", which its own manifest contradicts',
    },
    optOutContact: OPT_OUT,
  },
  {
    packId: 'mattpocock',
    displayName: 'mattpocock-skills',
    author: upstreamAuthor({ packId: 'mattpocock' }),
    upstreamRepo: fromUpstream({ packId: 'mattpocock', value: 'mattpocock/skills' }),
    license: fromUpstream({ packId: 'mattpocock', value: 'MIT' }),
    installSource: { source: 'github', repo: 'mattpocock/skills' },
    listingProvenance: {
      how: 'measured',
      note: 'listed because it was measured in this project; the author was not consulted before listing',
    },
    optOutContact: OPT_OUT,
  },
];

/**
 * Measured arms that are deliberately not listings, each with the reason.
 *
 * AC-6 requires every measured arm to be either listed or in here with a stated reason.
 * The alternative — letting an unlisted arm be silently absent — is how a future measured
 * pack disappears from the catalogue without anything failing.
 */
export const excludedArms: Readonly<Record<string, string>> = {
  'ponytail+superpowers':
    'a combination of two listed packs rather than a distributable pack; it has no manifest, no repository, and nothing to install',
};
