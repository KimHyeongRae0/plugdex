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
  MissingRegimeError,
  MixedEnvironmentError,
  UnknownRegimeError,
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

  /**
   * Written verbatim, and `null` means "omit the key entirely" so a spec can plant the
   * record shape that has no regime at all.
   *
   * A fixture may default; the parser may not. Every spec that is not about the regime
   * gets `blocked` so it keeps testing what it was written to test — PDX-017 made the
   * field required, which would otherwise have turned every one of these into a regime
   * test by accident.
   */
  regime?: unknown;

  /** Cells to write, when a test needs more than the single default cell. */
  cells?: readonly Record<string, unknown>[];
};

const buildRecord = ({
  run,
  fingerprint,
  audited = true,
  withdrawn,
  regime = 'blocked',
  cells,
}: RecordSpec) => ({
  run,
  ...(withdrawn === undefined ? {} : { withdrawn }),
  ...(regime === null ? {} : { regime }),
  env: {
    npm_packages: 2,
    ...(fingerprint === null ? {} : { npm_fingerprint: fingerprint }),
    npm_extraneous: [],
    ...(audited ? { npm_undeclared_toplevel: 0 } : {}),
    npm_installed: ['a@1.0.0', 'b@2.0.0'],
    node: 'v22.14.0',
    python_gate: '/tmp/python',
  },
  cells: cells ?? [
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

/*
 * The regime — PDX-017. It is the second run-level fact this package moved out of a
 * filename and onto the record, and the tests below are synthetic throughout so none of
 * them depends on which runs happen to exist. The single exception is the committed-corpus
 * partition at the end, which is there precisely to catch a corpus the parser accepts and
 * the two views then disagree about.
 */

test('filtering by regime returns only that condition, and no filter returns both', () => {
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123', regime: 'blocked' },
      { run: '20260816-094958', fingerprint: 'abc123', regime: 'as-shipped' },
    ],
  });

  const blocked = loadAcceptanceRecords({ dir, regime: 'blocked' });
  const asShipped = loadAcceptanceRecords({ dir, regime: 'as-shipped' });
  const both = loadAcceptanceRecords({ dir });

  assert.deepEqual(
    blocked.records.map((record) => record.run),
    ['20260816-092732'],
  );

  assert.deepEqual(
    asShipped.records.map((record) => record.run),
    ['20260816-094958'],
  );

  assert.equal(both.records.length, 2);
  assert.equal(blocked.cells.length + asShipped.cells.length, both.cells.length);
});

test('a record with no regime is refused rather than read as blocked', () => {
  const dir = plantCorpus({
    records: [{ run: '20260816-092732', fingerprint: 'abc123', regime: null }],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), MissingRegimeError);
});

test('a near-miss regime value is refused — no trimming, no case folding', () => {
  // Four values in one test on purpose: a parser that trimmed or lowercased would pass
  // three of them and fail only the empty string, which would read as a mostly-working
  // parser rather than as the defect it is.
  for (const value of ['Blocked', 'as shipped', 'blocked ', '']) {
    const dir = plantCorpus({
      records: [{ run: '20260816-092732', fingerprint: 'abc123', regime: value }],
    });

    assert.throws(
      () => loadAcceptanceRecords({ dir }),
      UnknownRegimeError,
      `regime ${JSON.stringify(value)} was accepted`,
    );
  }
});

test('a regime no record carries returns an empty corpus, never a fallback to everything', () => {
  const dir = plantCorpus({
    records: [{ run: '20260816-092732', fingerprint: 'abc123', regime: 'blocked' }],
  });

  const corpus = loadAcceptanceRecords({ dir, regime: 'as-shipped' });

  assert.equal(corpus.records.length, 0);
  assert.equal(corpus.cells.length, 0);
  assert.equal(corpus.fingerprint, 'abc123');
});

test('regime and withdrawal are independent facts, and neither exempts the other', () => {
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123', regime: 'as-shipped' },
      {
        run: '20260816-094958',
        fingerprint: 'abc123',
        regime: 'as-shipped',
        withdrawn: reasoned,
      },
    ],
  });

  const corpus = loadAcceptanceRecords({ dir, regime: 'as-shipped' });

  assert.deepEqual(
    corpus.records.map((record) => record.run),
    ['20260816-092732'],
  );

  assert.deepEqual(
    corpus.withdrawnRecords.map((record) => record.run),
    ['20260816-094958'],
  );

  assert.equal(corpus.withdrawnRecords[0]?.regime, 'as-shipped');
});

test('a malformed record outside the asked-for regime still refuses the corpus', () => {
  // The narrowing happens after every record is parsed, so the refusals do not depend on
  // the question asked. A filter that could hide a broken record would make this loader
  // report a clean corpus to one caller and a broken one to another.
  const dir = plantCorpus({
    records: [
      { run: '20260816-092732', fingerprint: 'abc123', regime: 'blocked' },
      { run: '20260816-094958', fingerprint: 'abc123', regime: 'nonsense' },
    ],
  });

  assert.throws(() => loadAcceptanceRecords({ dir, regime: 'blocked' }), UnknownRegimeError);
});

test('a record missing both the fingerprint and the regime fails on the fingerprint', () => {
  // The check order is load-bearing: `tests/e2e/PDX-002-records-are-traceable.sh` AC-3
  // plants exactly this record and requires MissingFingerprintError by name. Pinned here
  // so the order cannot drift out from under a scenario in another directory.
  const dir = plantCorpus({
    records: [{ run: '20260816-092732', fingerprint: null, regime: null }],
  });

  assert.throws(() => loadAcceptanceRecords({ dir }), MissingFingerprintError);
});

test('the committed corpus partitions into exactly its two regimes', () => {
  const dir = '../../bench/data/runs';
  const everything = loadAcceptanceRecords({ dir });
  const blocked = loadAcceptanceRecords({ dir, regime: 'blocked' });
  const asShipped = loadAcceptanceRecords({ dir, regime: 'as-shipped' });

  assert.ok(blocked.cells.length > 0, 'no committed record ran blocked');
  assert.ok(asShipped.cells.length > 0, 'no committed record ran as-shipped');

  assert.equal(
    blocked.cells.length + asShipped.cells.length,
    everything.cells.length,
    'a record is in neither regime or in both',
  );
});
