/**
 * Whether a listed pack installs — read from the records `scripts/record-installability.sh`
 * writes, never computed here.
 *
 * The catalogue's premise is that a claim is worth what its receipt is worth, and until
 * this module existed the listings carried a measured build rate beside an install button
 * with nothing in between able to say "this one does not install today". On 2026-08-18 an
 * upstream pack added a manifest field the CLI rejects, and the only two options the
 * repository had were a red gate forever or a green gate that lied.
 *
 * These records are also the only place that names what a reader actually receives. A
 * listing's figures describe the commit `packages/registry/attribution/<pack>/source.json`
 * fixes; the install command hands over the upstream's current HEAD. `upstreamHead` on
 * these records is that second artifact, recorded at the moment of the attempt.
 */

import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** Where the recorder writes, resolved from this module rather than from the caller's cwd. */
export const INSTALLABILITY_DIR = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'installability',
);

/** What a failure was, in the classifier's terms — the same terms the gate re-checks in. */
export interface InstallFailureSignature {
  readonly kind: string;
  readonly keys: readonly string[];
}

interface InstallabilityBase {
  readonly pack: string;
  readonly repo: string;
  readonly cliVersion: string;
  readonly attemptedAt: string;
  readonly upstreamHead: string;
  readonly transport: string;
}

/** The pack installed, and the CLI listed it afterwards. */
export interface InstallsRecord extends InstallabilityBase {
  readonly outcome: 'installs';
  /** What the CLI printed beside the installed pack. Absent when the pack declares none. */
  readonly installedVersion?: string;
}

/** The pack did not install, and the failure is named precisely enough to be re-checked. */
export interface BlockedRecord extends InstallabilityBase {
  readonly outcome: 'blocked';
  readonly signature: InstallFailureSignature;
  readonly verbatim: string;
}

export type InstallabilityRecord = InstallsRecord | BlockedRecord;

/** A record file that is not one, or one that says nothing the gate could act on. */
export class MalformedInstallabilityError extends Error {
  constructor({ file, reason }: { file: string; reason: string }) {
    super(`${file}: ${reason}`);
    this.name = 'MalformedInstallabilityError';
  }
}

const REQUIRED = [
  'pack',
  'repo',
  'cliVersion',
  'attemptedAt',
  'upstreamHead',
  'transport',
] as const;

const parseRecord = ({ raw, file }: { raw: unknown; file: string }): InstallabilityRecord => {
  if (typeof raw !== 'object' || raw === null) {
    throw new MalformedInstallabilityError({ file, reason: 'not a JSON object' });
  }

  const record = raw as Record<string, unknown>;

  for (const field of REQUIRED) {
    if (typeof record[field] !== 'string' || record[field] === '') {
      throw new MalformedInstallabilityError({ file, reason: `missing or empty '${field}'` });
    }
  }

  if (record['outcome'] === 'installs') {
    return record as unknown as InstallsRecord;
  }

  if (record['outcome'] !== 'blocked') {
    throw new MalformedInstallabilityError({
      file,
      reason: `unknown outcome ${JSON.stringify(record['outcome'])} — a record the gate cannot act on is refused rather than skipped`,
    });
  }

  const signature = record['signature'] as InstallFailureSignature | undefined;

  if (!signature || typeof signature.kind !== 'string' || signature.kind === '') {
    throw new MalformedInstallabilityError({
      file,
      reason: 'blocked record with no signature kind',
    });
  }

  if (!Array.isArray(signature.keys) || signature.keys.length === 0) {
    throw new MalformedInstallabilityError({
      file,
      reason: 'blocked record with no signature keys — nothing for the gate to re-check',
    });
  }

  if (typeof record['verbatim'] !== 'string' || record['verbatim'] === '') {
    throw new MalformedInstallabilityError({
      file,
      reason:
        'blocked record with no verbatim error — a blocked listing that cannot quote its own failure is an assertion, not a receipt',
    });
  }

  return record as unknown as BlockedRecord;
};

/** Every record on disk, keyed by pack id. Throws rather than skipping what it cannot read. */
export const loadInstallabilityRecords = ({
  dir = INSTALLABILITY_DIR,
}: { dir?: string } = {}): Readonly<Record<string, InstallabilityRecord>> => {
  const files = readdirSync(dir)
    .filter((name) => name.endsWith('.json'))
    .sort();

  const records: Record<string, InstallabilityRecord> = {};

  for (const file of files) {
    const record = parseRecord({
      raw: JSON.parse(readFileSync(join(dir, file), 'utf8')),
      file,
    });

    if (record.pack !== file.replace(/\.json$/, '')) {
      throw new MalformedInstallabilityError({
        file,
        reason: `record names pack '${record.pack}' — the filename is not the fact (DATA-02)`,
      });
    }

    records[record.pack] = record;
  }

  return records;
};

/** The records, loaded once at module load so consumers read data rather than run IO. */
export const installabilityRecords = loadInstallabilityRecords();

/** One pack's record, or undefined when nothing has measured it yet. */
export const installabilityFor = ({
  packId,
}: {
  packId: string;
}): InstallabilityRecord | undefined => installabilityRecords[packId];

/**
 * The three states a listing can be in, as one value the site cannot get wrong.
 *
 * `installabilityFor` returns `undefined` for a pack nothing has measured, and `undefined`
 * read as a boolean is `false` — which on a page about whether things install would render
 * the flattering answer by accident. Narrowing here, once, in the package that owns the
 * record, means no component re-derives it and the `installs` branch is reachable only from
 * an `InstallsRecord`.
 *
 * The short forms are produced here too. DATA-01 blocks a typed literal in site source and
 * reads a digit inside a rendered expression as a figure, so `{record.upstreamHead.slice(0, 7)}`
 * written in a template does not survive the gate — verified against the gate's own regex
 * during PDX-024's plan review. A truncation is a figure's presentation, so it belongs where
 * the figure does.
 */
export type InstallState =
  | { readonly state: 'installs'; readonly record: InstallsRecord; readonly shortHead: string }
  | { readonly state: 'blocked'; readonly record: BlockedRecord; readonly shortHead: string }
  | { readonly state: 'unmeasured' };

/** How many characters of a commit a reader can compare at a glance. */
const SHORT_SHA_LENGTH = 7;

/** A commit, shortened for reading. Named here so no template performs the slice. */
export const shortCommit = ({ commit }: { commit: string }): string =>
  commit.slice(0, SHORT_SHA_LENGTH);

/** One pack's install state, total over the three cases. */
export const installStateFor = ({
  packId,
  records = installabilityRecords,
}: {
  packId: string;
  records?: Readonly<Record<string, InstallabilityRecord>>;
}): InstallState => {
  const record = records[packId];

  if (record === undefined) {
    return { state: 'unmeasured' };
  }

  const shortHead = shortCommit({ commit: record.upstreamHead });

  return record.outcome === 'installs'
    ? { state: 'installs', record, shortHead }
    : { state: 'blocked', record, shortHead };
};

/** What the counts line states, and the date it is honest about. */
export type InstallabilitySummary = {
  readonly installs: number;
  readonly blocked: number;
  /**
   * The **oldest** attempt in the set, not the newest.
   *
   * A summary presented as current while its oldest member is a year stale is a figure
   * without its denominator. On the live corpus every record was written inside one
   * two-minute window, so the two are the same calendar date and a date-level comparison
   * cannot tell them apart — which is why the field carries the full timestamp and the
   * scenario asserts against it rather than against a rendered date.
   */
  readonly oldestAttemptedAt: string;
  readonly attemptedOn: string;
};

/** Where the date ends and the time begins in an ISO timestamp. */
const ISO_DATE_LENGTH = 10;

/** The summary of a given set of records — the seam a test can hand a planted directory. */
export const summariseInstallability = ({
  records,
}: {
  records: Readonly<Record<string, InstallabilityRecord>>;
}): InstallabilitySummary => {
  const all = Object.values(records);

  if (all.length === 0) {
    throw new RangeError(
      'a summary needs at least one record — an empty set has no oldest attempt',
    );
  }

  const stamps = all.map((record) => record.attemptedAt).sort();
  const oldestAttemptedAt = stamps[0] as string;

  return {
    installs: all.filter((record) => record.outcome === 'installs').length,
    blocked: all.filter((record) => record.outcome === 'blocked').length,
    oldestAttemptedAt,
    attemptedOn: oldestAttemptedAt.slice(0, ISO_DATE_LENGTH),
  };
};

/** The summary of the records on disk. */
export const installabilitySummary = (): InstallabilitySummary =>
  summariseInstallability({ records: installabilityRecords });
