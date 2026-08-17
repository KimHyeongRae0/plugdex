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

/**
 * Thrown when two entries claim the same `packId`.
 *
 * The emitted manifest is keyed by name, so a duplicate would not be an error at
 * generation and a silent last-writer-wins at install: one listing would quietly stand in
 * for another, which on a provenance site means installing one author's work from a page
 * about someone else's.
 */
export class DuplicatePackIdError extends Error {
  override readonly name = 'DuplicatePackIdError';

  constructor({ packId }: { packId: string }) {
    super(`${packId}: two entries share this packId — the emitted manifest would keep only one`);
  }
}

/**
 * The manifest, built from the entries in a stable order.
 *
 * `from` defaults to the real listings and exists so the duplicate guard can be tested
 * against the function that enforces it. A test that rebuilds the check on its own inputs
 * proves the test, not the code.
 *
 * @throws {DuplicatePackIdError} two entries share a `packId`
 */
export const buildMarketplace = ({
  from = entries,
}: { from?: readonly PackEntry[] } = {}): Marketplace => ({
  name: 'plugdex',
  owner: { name: 'plugdex', url: 'https://github.com/KimHyeongRae0/plugdex' },
  plugins: [...from]
    .sort((a, b) => a.packId.localeCompare(b.packId))
    .map((entry, index, sorted) => {
      if (index > 0 && sorted[index - 1]?.packId === entry.packId) {
        throw new DuplicatePackIdError({ packId: entry.packId });
      }

      return {
        name: entry.packId,
        source: entry.installSource,
        description: describe({ entry }),
      };
    }),
});

/**
 * Writes the manifest. Returns what it wrote, so a caller can assert on it.
 *
 * `to` exists so a caller can regenerate somewhere else. The determinism check needs a
 * second copy to compare against, and generating over the tracked file to get one means a
 * generator that dies mid-write leaves the committed manifest corrupted — a round-3 review
 * finding, and one that the earlier restore-on-failure branch did not actually close.
 */
export const writeMarketplace = ({ to = MARKETPLACE_PATH }: { to?: string } = {}): string => {
  const serialized = `${JSON.stringify(buildMarketplace(), null, 2)}\n`;

  mkdirSync(dirname(to), { recursive: true });
  writeFileSync(to, serialized, 'utf8');

  return serialized;
};
