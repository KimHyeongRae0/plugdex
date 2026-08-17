import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import type { AcceptanceCorpus, AcceptanceRecord, Cell, RunEnv } from './schema.js';

/**
 * Thrown when a record carries no environment fingerprint.
 *
 * This is a refusal, not a warning. A figure whose environment is unknown cannot be
 * traced, and DATA-01 says an untraceable figure does not reach the site.
 */
export class MissingFingerprintError extends Error {
  override readonly name = 'MissingFingerprintError';

  constructor({ file }: { file: string }) {
    super(`${file}: no env.npm_fingerprint — the run cannot be traced to an environment`);
  }
}

/**
 * Thrown when a record does not report how many installed packages nothing declared.
 *
 * Instrument failure 15 was caught by that count: four packages appeared in the shared
 * `node_modules` mid-experiment and moved a task from 4/12 passing to 12/12. Instrument
 * failure 19 then dropped the detector from the ported grader, and this loader defaulted
 * the missing field to `0` — so a record with no detector read as an environment with
 * nothing undeclared, which is the strongest possible claim rather than the absence of
 * one. Absent and clean are not the same reading, so the loader refuses.
 */
export class MissingEnvironmentAuditError extends Error {
  override readonly name = 'MissingEnvironmentAuditError';

  constructor({ file }: { file: string }) {
    super(
      `${file}: no env.npm_undeclared_toplevel — the record cannot say whether its ` +
        `environment was audited, and a missing audit must not read as a clean one`,
    );
  }
}

/**
 * Thrown when the loaded set spans more than one environment.
 *
 * Records from different environments are not comparable, and the failure mode is
 * silent: the union looks like one bigger sample. Two of this project's instrument
 * failures were exactly that, so the loader refuses rather than unions.
 */
export class MixedEnvironmentError extends Error {
  override readonly name = 'MixedEnvironmentError';

  constructor({ fingerprints }: { fingerprints: readonly string[] }) {
    super(
      `records span ${String(fingerprints.length)} environments (${fingerprints.join(', ')}) — ` +
        'they are not comparable and will not be unioned',
    );
  }
}

/** Thrown when a file is not a JSON object with the acceptance record's shape. */
export class MalformedRecordError extends Error {
  override readonly name = 'MalformedRecordError';

  constructor({ file, detail }: { file: string; detail: string }) {
    super(`${file}: ${detail}`);
  }
}

/** True for a plain JSON object, excluding arrays and null. */
const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/**
 * Reads `env`, requiring the fingerprint.
 *
 * Everything else is carried through as the harness wrote it; the two enforced fields
 * are the ones whose absence would otherwise be read as good news.
 */
const parseEnv = ({ raw, file }: { raw: unknown; file: string }): RunEnv => {
  if (!isObject(raw)) {
    throw new MalformedRecordError({ file, detail: 'env is not an object' });
  }

  const fingerprint = raw['npm_fingerprint'];

  if (typeof fingerprint !== 'string' || fingerprint.length === 0) {
    throw new MissingFingerprintError({ file });
  }

  const undeclared = raw['npm_undeclared_toplevel'];

  if (typeof undeclared !== 'number') {
    throw new MissingEnvironmentAuditError({ file });
  }

  return {
    npmPackages: typeof raw['npm_packages'] === 'number' ? raw['npm_packages'] : 0,
    npmFingerprint: fingerprint,
    npmExtraneous: Array.isArray(raw['npm_extraneous']) ? (raw['npm_extraneous'] as string[]) : [],
    npmUndeclaredToplevel: undeclared,
    npmInstalled: Array.isArray(raw['npm_installed']) ? (raw['npm_installed'] as string[]) : [],
    node: typeof raw['node'] === 'string' ? raw['node'] : '',
    pythonGate: typeof raw['python_gate'] === 'string' ? raw['python_gate'] : '',
  };
};

/**
 * Maps one cell from the harness's snake_case to the package's camelCase.
 *
 * Optional fields are omitted rather than defaulted. `exactOptionalPropertyTypes` is on,
 * so an absent gate result stays absent and a consumer has to decide what it means,
 * instead of reading a fabricated `false`.
 */
const parseCell = ({ raw, file }: { raw: unknown; file: string }): Cell => {
  if (!isObject(raw)) {
    throw new MalformedRecordError({ file, detail: 'cells contains a non-object entry' });
  }

  const { cell, task, arm, model, rep, valid } = raw;

  if (typeof cell !== 'string' || typeof task !== 'string' || typeof arm !== 'string') {
    throw new MalformedRecordError({ file, detail: `cell is missing cell/task/arm` });
  }

  if (typeof model !== 'string' || typeof rep !== 'number' || typeof valid !== 'boolean') {
    throw new MalformedRecordError({ file, detail: `${cell}: missing model/rep/valid` });
  }

  const optional: Record<string, unknown> = {};
  const carry = ({ from, to }: { from: string; to: string }): void => {
    if (from in raw) optional[to] = raw[from];
  };

  carry({ from: 'invalid_reason', to: 'invalidReason' });
  carry({ from: 'domain', to: 'domain' });
  carry({ from: 'deps', to: 'deps' });
  carry({ from: 'wrote_code', to: 'wroteCode' });
  carry({ from: 'new_files', to: 'newFiles' });
  carry({ from: 'n_frontend_files', to: 'nFrontendFiles' });
  carry({ from: 'n_backend_files', to: 'nBackendFiles' });
  carry({ from: 'typecheck', to: 'typecheck' });
  carry({ from: 'typecheck_reason', to: 'typecheckReason' });
  carry({ from: 'typecheck_out', to: 'typecheckOut' });
  carry({ from: 'build', to: 'build' });
  carry({ from: 'build_reason', to: 'buildReason' });
  carry({ from: 'build_out', to: 'buildOut' });
  carry({ from: 'import_ok', to: 'importOk' });
  carry({ from: 'import_out', to: 'importOut' });
  carry({ from: 'passes', to: 'passes' });
  carry({ from: 'n_new_diags', to: 'nNewDiags' });
  carry({ from: 'new_diags', to: 'newDiags' });

  return { cell, task, arm, model, rep, valid, ...optional } as Cell;
};

/** Parses one acceptance file. Throws rather than returning a partial record. */
export const parseAcceptanceRecord = ({
  text,
  file,
}: {
  text: string;
  file: string;
}): AcceptanceRecord => {
  let raw: unknown;

  try {
    raw = JSON.parse(text);
  } catch (error) {
    throw new MalformedRecordError({ file, detail: `not valid JSON (${String(error)})` });
  }

  if (!isObject(raw)) {
    throw new MalformedRecordError({ file, detail: 'top level is not an object' });
  }

  const run = raw['run'];

  if (typeof run !== 'string') {
    throw new MalformedRecordError({ file, detail: 'run id is missing or not a string' });
  }

  const cells = raw['cells'];

  if (!Array.isArray(cells)) {
    throw new MalformedRecordError({ file, detail: 'cells is missing or not an array' });
  }

  return {
    run,
    env: parseEnv({ raw: raw['env'], file }),
    cells: cells.map((entry) => parseCell({ raw: entry, file })),
  };
};

/**
 * Loads every `*.acceptance.json` in `dir` as one comparable corpus.
 *
 * Only acceptance files are read. `*.results.json` carries no fingerprint and
 * `gate-limits.json` is a different schema; both are excluded by the record universe
 * rather than by convenience, so a figure that needs them has to resolve its own
 * DATA-01 story rather than inherit one quietly.
 *
 * @throws {MissingFingerprintError} a record has no `env.npm_fingerprint`
 * @throws {MixedEnvironmentError} the loaded records span more than one fingerprint
 * @throws {MalformedRecordError} a file is not a well-formed acceptance record
 */
export const loadAcceptanceRecords = ({ dir }: { dir: string }): AcceptanceCorpus => {
  const files = readdirSync(dir)
    .filter((name) => name.endsWith('.acceptance.json'))
    .sort();

  const records = files.map((name) => {
    const file = join(dir, name);

    return parseAcceptanceRecord({ text: readFileSync(file, 'utf8'), file });
  });

  const fingerprints = [...new Set(records.map((record) => record.env.npmFingerprint))].sort();

  if (fingerprints.length > 1) {
    throw new MixedEnvironmentError({ fingerprints });
  }

  const fingerprint = fingerprints[0];

  if (fingerprint === undefined) {
    throw new MalformedRecordError({ file: dir, detail: 'no acceptance records found' });
  }

  return {
    records,
    fingerprint,
    cells: records.flatMap((record) => record.cells),
  };
};
