/**
 * Reading a pack's own declaration about itself.
 *
 * DEC-011: a pack's `plugin.json` is recorded here; its content is not. Vendoring ships
 * someone's functionality, while recording their manifest ships their declaration, which
 * is what makes our listing auditable against their own words.
 *
 * `.claude-plugin/plugin.json` is the canonical path and a root-level manifest is an
 * error rather than a fallback. One measured pack ships a stub `{"name":"ponytail"}` at
 * its repository root alongside the real manifest, and reading the stub yields a silently
 * empty author — a listing that names nobody while looking like it named someone.
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import type { UpstreamManifest } from './schema.js';

const HERE = dirname(fileURLToPath(import.meta.url));

/** Where the recorded manifests live, resolved from this module rather than from cwd. */
export const ATTRIBUTION_DIR = join(HERE, '..', 'attribution');

/** Thrown when a pack claims an upstream-derived field with no manifest to derive it from. */
export class MissingManifestError extends Error {
  override readonly name = 'MissingManifestError';

  constructor({ packId }: { packId: string }) {
    super(
      `${packId}: no recorded attribution manifest — an upstream-tagged field must quote ` +
        `a declaration, and there is none to quote`,
    );
  }
}

/**
 * The recorded manifest for a pack.
 *
 * @throws {MissingManifestError} the pack has no recorded manifest
 */
export const readManifest = ({ packId }: { packId: string }): UpstreamManifest => {
  const path = join(ATTRIBUTION_DIR, packId, 'plugin.json');

  try {
    return JSON.parse(readFileSync(path, 'utf8')) as UpstreamManifest;
  } catch {
    throw new MissingManifestError({ packId });
  }
};

/**
 * The author a manifest declares, as a plain name.
 *
 * Returns an empty string when the manifest declares none. The caller decides what that
 * means; this function does not invent a name, because inventing one is the failure it
 * exists to prevent.
 */
export const declaredAuthor = ({ manifest }: { manifest: UpstreamManifest }): string => {
  const { author } = manifest;

  if (typeof author === 'string') {
    return author;
  }

  return author?.name ?? '';
};

/**
 * An `upstream`-tagged field, refusing to produce one when the manifest is silent.
 *
 * A field the author never declared cannot be tagged as their declaration. Where we still
 * want to publish a value, it is `curated` and it carries its reason.
 *
 * @throws {MissingManifestError} the manifest declares nothing for this field
 */
export const fromUpstream = ({ packId, value }: { packId: string; value: string }) => {
  if (value.length === 0) {
    throw new MissingManifestError({ packId });
  }

  return { from: 'upstream', value } as const;
};
