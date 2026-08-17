import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import {
  loadAcceptanceRecords,
  MalformedRecordError,
  MissingEnvironmentAuditError,
  MissingFingerprintError,
  MixedEnvironmentError,
} from './load.js';

/**
 * The refusal paths are exercised against synthetic records, never against the real
 * corpus. Today's eight files all agree; a test that only reads them would pass because
 * the data happens to be well-formed, not because the loader enforces anything.
 */
const buildRecord = ({
  run,
  fingerprint,
  audited = true,
}: {
  run: string;
  fingerprint: string | null;
  audited?: boolean;
}) => ({
  run,
  env: {
    npm_packages: 2,
    ...(fingerprint === null ? {} : { npm_fingerprint: fingerprint }),
    npm_extraneous: [],
    ...(audited ? { npm_undeclared_toplevel: 0 } : {}),
    npm_installed: ['a@1.0.0', 'b@2.0.0'],
    node: 'v22.14.0',
    python_gate: '/tmp/python',
  },
  cells: [
    {
      cell: `t__baseline__haiku__0`,
      task: 't',
      arm: 'baseline',
      model: 'haiku',
      rep: 0,
      valid: true,
      domain: 'frontend',
      wrote_code: true,
      typecheck: false,
      typecheck_reason: 'type-error',
    },
  ],
});

/** Writes the given records into a fresh directory and returns its path. */
const plantCorpus = ({
  records,
}: {
  records: readonly { run: string; fingerprint: string | null; audited?: boolean }[];
}): string => {
  const dir = mkdtempSync(join(tmpdir(), 'plugdex-data-'));

  for (const spec of records) {
    writeFileSync(
      join(dir, `${spec.run}.acceptance.json`),
      JSON.stringify(buildRecord(spec)),
      'utf8',
    );
  }

  return dir;
};

test('a single-environment corpus loads and exposes its fingerprint', () => {
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123' },
      { run: '20260816-094325', fingerprint: 'abc123' },
    ],
  });

  const corpus = loadAcceptanceRecords({ dir });

  assert.equal(corpus.records.length, 2);
  assert.equal(corpus.fingerprint, 'abc123');
  assert.equal(corpus.cells.length, 2);
});

test('snake_case fields are mapped, and absent ones stay absent', () => {
  const dir = plantCorpus({ records: [{ run: '20260816-092732', fingerprint: 'abc123' }] });

  const [cell] = loadAcceptanceRecords({ dir }).cells;

  assert.equal(cell?.wroteCode, true);
  assert.equal(cell?.typecheckReason, 'type-error');

  // The synthetic cell carries no backend gate, so the field must not be invented.
  assert.equal('importOk' in (cell ?? {}), false);
});

test('a record with no fingerprint is refused', () => {
  const dir = plantCorpus({ records: [{ run: '20260816-092732', fingerprint: null }] });

  assert.throws(() => loadAcceptanceRecords({ dir }), MissingFingerprintError);
});

test('a corpus spanning two environments is refused rather than unioned', () => {
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123' },
      { run: '20260816-094325', fingerprint: 'def456' },
    ],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), MixedEnvironmentError);
});

test('a malformed file is refused, not skipped', () => {
  const dir = plantCorpus({ records: [{ run: '20260816-092732', fingerprint: 'abc123' }] });
  writeFileSync(join(dir, '20260816-999999.acceptance.json'), '{ not json', 'utf8');

  assert.throws(() => loadAcceptanceRecords({ dir }), MalformedRecordError);
});

test('an empty directory is an error, not an empty corpus', () => {
  const dir = plantCorpus({ records: [] });

  assert.throws(() => loadAcceptanceRecords({ dir }), MalformedRecordError);
});

test('a record with no environment audit is refused, not read as clean', () => {
  const dir = plantCorpus({
    records: [{ run: '20260816-092732', fingerprint: 'abc123', audited: false }],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), MissingEnvironmentAuditError);
});

test('every committed record reports its environment audit', () => {
  // The synthetic tests above prove the loader refuses. This one proves the corpus is
  // still loadable under that rule, which is what would have caught instrument failure
  // 19: the grader stopped emitting the field while ten records already carried it.
  const corpus = loadAcceptanceRecords({ dir: '../../bench/data/runs' });

  assert.ok(corpus.records.length > 0, 'the committed corpus is empty');

  for (const record of corpus.records) {
    assert.equal(
      typeof record.env.npmUndeclaredToplevel,
      'number',
      `${record.run} carries no environment audit`,
    );
  }
});
