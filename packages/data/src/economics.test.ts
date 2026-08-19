import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { loadEconomics, OrphanResultsRecordError } from './economics.js';
import { loadAcceptanceRecords } from './load.js';

/** One environment for every fixture record: the loader refuses a mixed corpus. */
const ENV = {
  npm_fingerprint: 'fixture-fingerprint',
  npm_undeclared_toplevel: 0,
  npm_packages: 1,
  npm_extraneous: [],
  npm_installed: [],
  node: 'v22.0.0',
  python_gate: '/usr/bin/python3',
};

const row = ({ arm, cost, tokens }: { arm: string; cost: number; tokens: number }) => ({
  task: 'tmpl-fe-one',
  arm,
  model: 'haiku',
  cost,
  turns: 10,
  total_loc: 20,
  duration_ms: 40000,
  out_tokens: tokens,
  in_tokens: tokens,
  cache_tokens: tokens * 2,
});

/**
 * A corpus whose filenames contradict its records, on purpose.
 *
 * The file called `as-shipped` holds a `blocked` record and the file called `blocked` holds
 * an `as-shipped` one. Every published figure has to follow the records; a join that read
 * the names would put both runs in the wrong condition and nothing downstream could tell.
 */
const plantCorpus = (): string => {
  const dir = mkdtempSync(join(tmpdir(), 'plugdex-economics-'));

  const write = ({ name, body }: { name: string; body: unknown }): void => {
    writeFileSync(join(dir, name), JSON.stringify(body), 'utf8');
  };

  write({
    name: '20260101-000000-as-shipped-run.acceptance.json',
    body: { run: '20260101-000000', regime: 'blocked', env: ENV, cells: [] },
  });
  write({
    name: '20260101-000000-as-shipped-run.results.json',
    body: { date: '20260101-000000', results: [row({ arm: 'pack', cost: 0.1, tokens: 100 })] },
  });

  write({
    name: '20260102-000000-blocked-run.acceptance.json',
    body: { run: '20260102-000000', regime: 'as-shipped', env: ENV, cells: [] },
  });
  write({
    name: '20260102-000000-blocked-run.results.json',
    body: { date: '20260102-000000', results: [row({ arm: 'other', cost: 9, tokens: 900 })] },
  });

  write({
    name: '20260103-000000-blocked-withdrawn.acceptance.json',
    body: {
      run: '20260103-000000',
      regime: 'blocked',
      env: ENV,
      withdrawn: { reason: 'instrument failure', recorded_at: '2026-01-03T00:00:00+00:00' },
      cells: [],
    },
  });
  write({
    name: '20260103-000000-blocked-withdrawn.results.json',
    body: { date: '20260103-000000', results: [row({ arm: 'pack', cost: 5, tokens: 500 })] },
  });

  return dir;
};

test('the join follows the records, and the filenames decide nothing (DATA-02)', () => {
  const dir = plantCorpus();
  const corpus = loadAcceptanceRecords({ dir, regime: 'blocked' });
  const economics = loadEconomics({ dir, corpus });

  assert.deepEqual(
    economics.runs,
    ['20260101-000000'],
    'the run whose file is named as-shipped and whose record says blocked is in the blocked pool',
  );
  assert.deepEqual(
    economics.arms.map((entry) => entry.arm),
    ['pack'],
    'the run whose file is named blocked and whose record says as-shipped stays out',
  );
});

test('a withdrawn run leaves the default pool by its own record, not by anyone remembering', () => {
  const dir = plantCorpus();
  const pooled = loadEconomics({ dir, corpus: loadAcceptanceRecords({ dir, regime: 'blocked' }) });

  assert.equal(pooled.rows, 1);
  assert.equal(
    pooled.arms[0]?.cost.value,
    0.1,
    'the withdrawn run cost five dollars a cell and is absent',
  );

  const withEverything = loadEconomics({
    dir,
    corpus: loadAcceptanceRecords({ dir, regime: 'blocked', includeWithdrawn: true }),
  });

  assert.equal(withEverything.rows, 2, 'asked for explicitly, the withdrawn run is there');
});

test('every arm carries the denominator its means were taken over, and shares that are fractions', () => {
  const dir = plantCorpus();
  const economics = loadEconomics({
    dir,
    corpus: loadAcceptanceRecords({ dir, regime: 'blocked' }),
  });
  const [arm] = economics.arms;

  assert.equal(arm?.econN, 1);
  assert.equal(arm?.seconds.value, 40);
  assert.equal(arm?.loc.value, 20);

  const shares = Object.values(arm?.shares ?? {});

  assert.equal(shares.length, 3);
  assert.ok(
    Math.abs(shares.reduce((sum, share) => sum + share, 0) - 1) < 1e-9,
    'the shares are fractions of the arm total, so the site multiplies nothing by a hundred',
  );
});

test('a results record no acceptance record claims is refused, by name', () => {
  // Loudly, because it carries no fingerprint, no regime and no withdrawal of its own.
  // Skipping it quietly would drop a run's money out of every published mean with nothing
  // on the page to notice.
  const dir = plantCorpus();

  writeFileSync(
    join(dir, '20260104-000000-orphan.results.json'),
    JSON.stringify({
      date: '20260104-000000',
      results: [row({ arm: 'pack', cost: 1, tokens: 10 })],
    }),
    'utf8',
  );

  const corpus = loadAcceptanceRecords({ dir, regime: 'blocked' });

  assert.throws(
    () => loadEconomics({ dir, corpus }),
    (error: unknown) =>
      error instanceof OrphanResultsRecordError && error.message.includes('20260104-000000'),
  );
});

test('a row that measured nothing is absent from the mean rather than averaged in as zero', () => {
  // Nine of the live corpus's 441 result rows carry no economics at all, three of them
  // baseline's. Read as zeros they pulled baseline's mean wall clock from 47.03s to 45.29s
  // — far enough to change which points the Pareto chart drew. The mean is over the rows
  // that measured something, and it says how many those were.
  const dir = mkdtempSync(join(tmpdir(), 'plugdex-econ-absent-'));

  try {
    writeFileSync(
      join(dir, '20260101-000000.acceptance.json'),
      JSON.stringify({ run: '20260101-000000', regime: 'blocked', env: ENV, cells: [] }),
    );
    writeFileSync(
      join(dir, '20260101-000000.results.json'),
      JSON.stringify({
        date: '20260101-000000',
        results: [
          { arm: 'a', cost: 0.2, turns: 10, duration_ms: 40_000, total_loc: 20 },
          { arm: 'a' },
        ],
      }),
    );

    const economics = loadEconomics({
      dir,
      corpus: loadAcceptanceRecords({ dir, regime: 'blocked' }),
    });
    const [arm] = economics.arms;

    assert.equal(arm?.econN, 2, 'both rows are in the pool');
    assert.equal(arm?.econMissing, 1, 'and one of them measured nothing');
    assert.equal(arm?.cost.value, 0.2, 'the mean is over the row that measured, not both');
    assert.equal(arm?.cost.n, 1, 'and it carries the denominator it was taken over');
    assert.equal(arm?.seconds.value, 40);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
