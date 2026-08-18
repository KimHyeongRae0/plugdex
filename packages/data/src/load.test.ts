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
  UnreasonedWithdrawalError,
} from './load.js';

/**
 * The refusal paths are exercised against synthetic records, never against the real
 * corpus. Today's eight files all agree; a test that only reads them would pass because
 * the data happens to be well-formed, not because the loader enforces anything.
 */
type RecordSpec = {
  run: string;
  fingerprint: string | null;
  audited?: boolean;

  /**
   * Written to the record verbatim, so a test can plant shapes the type would reject.
   * That is the point: the loader is the thing being tested, and the records it reads
   * are JSON somebody wrote by hand.
   */
  withdrawn?: unknown;
};

const buildRecord = ({ run, fingerprint, audited = true, withdrawn }: RecordSpec) => ({
  run,
  ...(withdrawn === undefined ? {} : { withdrawn }),
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
const plantCorpus = ({ records }: { records: readonly RecordSpec[] }): string => {
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

const reasoned = {
  reason: 'planted: the run carried a different prompt',
  recorded_at: '2026-08-17T00:00:00+09:00',
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

test('a withdrawn record is excluded from the default view and listed beside it', () => {
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123' },
      { run: '20260816-094325', fingerprint: 'abc123', withdrawn: reasoned },
    ],
  });

  const corpus = loadAcceptanceRecords({ dir });

  assert.deepEqual(
    corpus.records.map((record) => record.run),
    ['20260816-092732'],
  );
  assert.equal(corpus.cells.length, 1);
  assert.deepEqual(
    corpus.withdrawnRecords.map((record) => record.run),
    ['20260816-094325'],
  );
  assert.equal(corpus.withdrawnRecords[0]?.withdrawn?.reason, reasoned.reason);
  assert.equal(corpus.withdrawnRecords[0]?.withdrawn?.recordedAt, reasoned.recorded_at);
});

test('includeWithdrawn pools the withdrawn record and still lists it', () => {
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123' },
      { run: '20260816-094325', fingerprint: 'abc123', withdrawn: reasoned },
    ],
  });

  const corpus = loadAcceptanceRecords({ dir, includeWithdrawn: true });

  assert.equal(corpus.records.length, 2);
  assert.equal(corpus.cells.length, 2);

  // What was withdrawn is a property of the corpus, not of the question asked of it.
  assert.deepEqual(
    corpus.withdrawnRecords.map((record) => record.run),
    ['20260816-094325'],
  );
});

test('a withdrawal with no reason is refused', () => {
  const dir = plantCorpus({
    records: [
      {
        run: '20260816-092732',
        fingerprint: 'abc123',
        withdrawn: { recorded_at: '2026-08-17T00:00:00+09:00' },
      },
    ],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), UnreasonedWithdrawalError);
});

test('a withdrawal whose reason is only whitespace is refused', () => {
  const dir = plantCorpus({
    records: [
      {
        run: '20260816-092732',
        fingerprint: 'abc123',
        withdrawn: { reason: '   ', recorded_at: '2026-08-17T00:00:00+09:00' },
      },
    ],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), UnreasonedWithdrawalError);
});

test('an explicit null withdrawal is refused, not read as absent', () => {
  // `.get("withdrawn")` in Python reads null and absent the same way, so this shape is
  // where the two loaders would silently part company. Both refuse it; the DATA-02 gate
  // and golden case 33 keep it that way.
  const dir = plantCorpus({
    records: [{ run: '20260816-092732', fingerprint: 'abc123', withdrawn: null }],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), UnreasonedWithdrawalError);
});

test('a withdrawal with no recorded_at is refused', () => {
  const dir = plantCorpus({
    records: [{ run: '20260816-092732', fingerprint: 'abc123', withdrawn: { reason: 'because' } }],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), UnreasonedWithdrawalError);
});

test('a corpus whose every run is withdrawn loads empty rather than falling back', () => {
  // The tempting bug is a loader that notices it excluded everything and quietly pools
  // the lot rather than returning nothing. An empty result is a result; it is also not
  // the same thing as an empty directory, which still refuses one test above.
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123', withdrawn: reasoned },
      { run: '20260816-094325', fingerprint: 'abc123', withdrawn: reasoned },
    ],
  });

  const corpus = loadAcceptanceRecords({ dir });

  assert.equal(corpus.records.length, 0);
  assert.equal(corpus.cells.length, 0);
  assert.equal(corpus.fingerprint, 'abc123');
  assert.equal(corpus.withdrawnRecords.length, 2);
});

test('a withdrawn record from another environment still refuses the corpus', () => {
  // Withdrawal is not an exemption from the environment invariant. Narrowing the corpus
  // until it looks consistent is exactly the failure the fingerprint check exists to stop.
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123' },
      { run: '20260816-094325', fingerprint: 'def456', withdrawn: reasoned },
    ],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), MixedEnvironmentError);
});

test('the committed corpus partitions into exactly its two views', () => {
  const dir = '../../bench/data/runs';
  const defaultView = loadAcceptanceRecords({ dir });
  const pooled = loadAcceptanceRecords({ dir, includeWithdrawn: true });

  assert.ok(defaultView.cells.length > 0, 'the default view is empty');
  assert.ok(defaultView.withdrawnRecords.length > 0, 'no committed record is withdrawn');

  const withdrawnCells = defaultView.withdrawnRecords.reduce(
    (total, record) => total + record.cells.length,
    0,
  );

  assert.equal(defaultView.cells.length + withdrawnCells, pooled.cells.length);

  for (const record of defaultView.withdrawnRecords) {
    assert.ok(
      (record.withdrawn?.reason ?? '').trim().length > 0,
      `${record.run} is withdrawn with no reason`,
    );
  }
});
