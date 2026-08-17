/**
 * The machine face: `.claude-plugin/marketplace.json`, generated from the entries.
 *
 * Generation is deterministic and offline. Entries are sorted by `packId` and serialized
 * with a fixed indent, so regenerating on an unchanged tree produces a byte-identical
 * file — which is what lets the scenario assert determinism instead of trusting it, and
 * what makes the committed output diffable rather than churning.
 *
 * No network call happens here. The install *source* points at GitHub, but resolving it
 * is `claude plugin install`'s job at install time, not generation's.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { entries } from './entries.js';
import type { InstallSource, PackEntry } from './schema.js';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..', '..', '..');

export const MARKETPLACE_PATH = join(REPO_ROOT, '.claude-plugin', 'marketplace.json');

interface MarketplacePlugin {
  readonly name: string;
  readonly source: InstallSource;
  readonly description: string;
}

export interface Marketplace {
  readonly name: string;
  readonly owner: { readonly name: string; readonly url: string };
  readonly plugins: readonly MarketplacePlugin[];
}

/**
 * The description a consumer sees in `claude plugin` output.
 *
 * It names the author rather than the pack, because the listing's whole claim is about
 * whose work this is, and it says so where a reader is actually looking.
 */
const describe = ({ entry }: { entry: PackEntry }): string =>
  `${entry.displayName} by ${entry.author.value} — measured by plugdex`;

/** The manifest, built from the entries in a stable order. */
export const buildMarketplace = (): Marketplace => ({
  name: 'plugdex',
  owner: { name: 'plugdex', url: 'https://github.com/KimHyeongRae0/plugdex' },
  plugins: [...entries]
    .sort((a, b) => a.packId.localeCompare(b.packId))
    .map((entry) => ({
      name: entry.packId,
      source: entry.installSource,
      description: describe({ entry }),
    })),
});

/** Writes the manifest. Returns what it wrote, so a caller can assert on it. */
export const writeMarketplace = (): string => {
  const serialized = `${JSON.stringify(buildMarketplace(), null, 2)}\n`;

  mkdirSync(dirname(MARKETPLACE_PATH), { recursive: true });
  writeFileSync(MARKETPLACE_PATH, serialized, 'utf8');

  return serialized;
};
