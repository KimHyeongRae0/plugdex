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

import type { Attributed, ManifestSource, StarsAtRecordTime, UpstreamManifest } from './schema.js';

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

/** Where a recorded manifest was read from, including the commit that fixes it. */
export const readSource = ({ packId }: { packId: string }): ManifestSource => {
  const path = join(ATTRIBUTION_DIR, packId, 'source.json');

  try {
    return JSON.parse(readFileSync(path, 'utf8')) as ManifestSource;
  } catch {
    throw new MissingManifestError({ packId });
  }
};

/** The star count recorded alongside the manifest, with the date it was read. */
export const recordedStars = ({ packId }: { packId: string }): StarsAtRecordTime => {
  const source = readSource({ packId });

  return { count: source.stars, readAt: source.readAt };
};

/** `https://github.com/owner/repo` and friends reduced to `owner/repo`. */
const toOwnerRepo = (repository: string): string =>
  repository
    .replace(/^git\+/, '')
    .replace(/\.git$/, '')
    .replace(/^(https?:\/\/)?(www\.)?github\.com[/:]/, '');

/**
 * An `upstream`-tagged field, **derived from the manifest** rather than asserted next to
 * it.
 *
 * An earlier version took the value from the caller and only checked it was non-empty,
 * which meant an `upstream` tag proved nothing except that somebody had typed something.
 * The tag's whole meaning is "the author declared this", so the value is now read out of
 * their declaration. Where they declared nothing, this throws and the caller must publish
 * a `curated` value carrying its reason.
 *
 * @throws {MissingManifestError} the manifest declares nothing for this field
 */
export const fromUpstream = ({
  packId,
  field,
}: {
  packId: string;
  field: 'author' | 'repository' | 'license';
}): Attributed => {
  const manifest = readManifest({ packId });

  const raw =
    field === 'author'
      ? declaredAuthor({ manifest })
      : field === 'repository'
        ? (manifest.repository ?? '')
        : (manifest.license ?? '');

  if (raw.length === 0) {
    throw new MissingManifestError({ packId });
  }

  return { from: 'upstream', value: field === 'repository' ? toOwnerRepo(raw) : raw };
};
