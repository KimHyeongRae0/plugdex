import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { Cell } from './schema.js';
import { formatRate } from './stats.js';
import { percentOf, verdictFor } from './verdict.js';

/**
 * Synthetic cells throughout. The verdict fold is a set of properties, and a test that
 * read the live corpus would pass because today's data happens to have a shape, not
 * because the function holds the property.
 */
const arm = ({
  name,
  count,
  wroteCode = true,
  builds = 0,
  valid = true,
  gradedBuild = true,
}: {
  name: string;
  count: number;
  wroteCode?: boolean;
  builds?: number;
  valid?: boolean;
  gradedBuild?: boolean;
}): Cell[] =>
  Array.from({ length: count }, (_, index) => ({
    cell: `${name}-${String(index)}`,
    task: 't',
    arm: name,
    model: 'haiku',
    rep: index,
    valid,
    wroteCode,
    ...(gradedBuild ? { build: index < builds } : {}),
  }));

const baseline = arm({ name: 'baseline', count: 10, builds: 5 });

test('a pack that writes nothing is called silent, with its counts', () => {
  const verdict = verdictFor({
    packId: 'silent',
    cells: [...baseline, ...arm({ name: 'silent', count: 10, wroteCode: false })],
  });

  assert.equal(verdict.verdict, 'no-code');
  assert.deepEqual(verdict, { verdict: 'no-code', silent: 10, n: 10 });
});

test('the silent threshold is a floor, not a majority', () => {
  // 8 of 10 is the DESIGN.md condition exactly; 7 of 10 is a pack that mostly writes
  // nothing and is still not called silent. A threshold asserted only from above is a
  // threshold nobody has tested.
  const at = verdictFor({
    packId: 'p',
    cells: [
      ...baseline,
      ...arm({ name: 'p', count: 8, wroteCode: false }),
      ...arm({ name: 'p', count: 2, wroteCode: true, builds: 2 }),
    ],
  });

  const below = verdictFor({
    packId: 'p',
    cells: [
      ...baseline,
      ...arm({ name: 'p', count: 7, wroteCode: false }),
      ...arm({ name: 'p', count: 3, wroteCode: true, builds: 3 }),
    ],
  });

  assert.equal(at.verdict, 'no-code');
  assert.equal(below.verdict, 'build-rate');
});

test('a pack matching two conditions shows the higher-priority one', () => {
  // Detection precedes claim verification: a claim verdict on a pack that ships no code
  // grades the advertising of work that does not exist.
  const verdict = verdictFor({
    packId: 'silent',
    cells: [...baseline, ...arm({ name: 'silent', count: 10, wroteCode: false })],
    claims: [{ packId: 'silent', metric: 'tokens', claimed: 50, low: 10, high: 20 }],
  });

  assert.equal(verdict.verdict, 'no-code');
});

test('a claim inside its measured interval is reproduced, and does not fire', () => {
  const cells = [...baseline, ...arm({ name: 'p', count: 10, builds: 6 })];

  const inside = verdictFor({
    packId: 'p',
    cells,
    claims: [{ packId: 'p', metric: 'tokens', claimed: 15, low: 10, high: 20 }],
  });

  const outside = verdictFor({
    packId: 'p',
    cells,
    claims: [{ packId: 'p', metric: 'tokens', claimed: 50, low: 10, high: 20 }],
  });

  assert.equal(inside.verdict, 'build-rate');
  assert.equal(outside.verdict, 'claim-not-reproduced');
});

test('a claim exactly on the interval bound counts as reproduced', () => {
  // The bound is inclusive. A figure sitting on the edge of its own interval has not been
  // contradicted, and calling it "not reproduced" would be the site asserting more than
  // the measurement does.
  const verdict = verdictFor({
    packId: 'p',
    cells: [...baseline, ...arm({ name: 'p', count: 10, builds: 6 })],
    claims: [{ packId: 'p', metric: 'tokens', claimed: 20, low: 10, high: 20 }],
  });

  assert.equal(verdict.verdict, 'build-rate');
});

test('a claim about another pack is ignored', () => {
  const verdict = verdictFor({
    packId: 'p',
    cells: [...baseline, ...arm({ name: 'p', count: 10, builds: 6 })],
    claims: [{ packId: 'other', metric: 'tokens', claimed: 50, low: 10, high: 20 }],
  });

  assert.equal(verdict.verdict, 'build-rate');
});

test('both sides of baseline return the same verdict, with both pairs of counts', () => {
  // This is the whole of DEC-016. A pack below baseline is not a different kind of
  // result; it is the same kind with different numbers, and the union says so.
  const above = verdictFor({
    packId: 'strong',
    cells: [...baseline, ...arm({ name: 'strong', count: 10, builds: 9 })],
  });

  const below = verdictFor({
    packId: 'weak',
    cells: [...baseline, ...arm({ name: 'weak', count: 10, builds: 1 })],
  });

  // The backend counts are zero on these fixtures because no fixture cell names a backend
  // domain — not because they are optional. A build-rate verdict always carries both pairs.
  assert.deepEqual(above, {
    verdict: 'build-rate',
    builds: 9,
    n: 10,
    baselineBuilds: 5,
    baselineN: 10,
    backendPasses: 0,
    backendN: 0,
    baselineBackendPasses: 0,
    baselineBackendN: 0,
  });
  assert.deepEqual(below, {
    verdict: 'build-rate',
    builds: 1,
    n: 10,
    baselineBuilds: 5,
    baselineN: 10,
    backendPasses: 0,
    backendN: 0,
    baselineBackendPasses: 0,
    baselineBackendN: 0,
  });
});

test('no verdict carries a precomputed rate', () => {
  // A percentage field would let a chip render a number without holding its denominator,
  // which is the one thing AC-3 exists to prevent. Enforced structurally rather than by
  // reviewing every component.
  const verdict = verdictFor({
    packId: 'p',
    cells: [...baseline, ...arm({ name: 'p', count: 10, builds: 6 })],
  });

  for (const field of ['rate', 'percent', 'percentage']) {
    assert.equal(field in verdict, false, `the verdict carries a ${field} field`);
  }
});

test('an ungraded outcome is skipped, not counted as a failure', () => {
  // The same rule rate_table follows in bench/harness/fisher.py. A cell nobody graded is
  // not evidence in either direction, and counting it as a failure would make a pack look
  // worse for having been measured less.
  const verdict = verdictFor({
    packId: 'p',
    cells: [
      ...baseline,
      ...arm({ name: 'p', count: 4, builds: 4 }),
      ...arm({ name: 'p', count: 6, gradedBuild: false }),
    ],
  });

  assert.deepEqual(verdict, {
    backendPasses: 0,
    backendN: 0,
    baselineBackendPasses: 0,
    baselineBackendN: 0,
    verdict: 'build-rate',
    builds: 4,
    n: 4,
    baselineBuilds: 5,
    baselineN: 10,
  });
});

test('the build rate is over code-producing cells only', () => {
  // The chip table states condition 3 as "the pass rate over its code-producing cells".
  // A cell in which the agent wrote nothing has no code to build; counting it as a build
  // failure would fold "produced nothing" into "produced something broken", and the first
  // of those already has its own verdict. Today's corpus happens to grade `build` only on
  // cells that wrote code, so the two poolings coincide there — which is exactly why this
  // is pinned here rather than left to be true by accident.
  const verdict = verdictFor({
    packId: 'p',
    cells: [
      ...baseline,
      ...arm({ name: 'p', count: 4, wroteCode: true, builds: 3 }),
      ...arm({ name: 'p', count: 6, wroteCode: false, builds: 0 }),
    ],
  });

  assert.equal(verdict.verdict, 'build-rate');
  assert.equal((verdict as { builds: number }).builds, 3);
  assert.equal((verdict as { n: number }).n, 4);
});

test('an unmeasured pack has no rate to render, not a rate of zero', () => {
  const verdict = verdictFor({ packId: 'ghost', cells: baseline });

  assert.deepEqual(verdict, { verdict: 'unmeasured' });
  assert.equal('n' in verdict, false);
  assert.equal('builds' in verdict, false);
});

test('a pack with only invalid cells is unmeasured, not silent', () => {
  // Invalid cells are cells the instrument threw out. Reading them as "wrote no code"
  // would turn a measurement failure into a verdict about the pack.
  const verdict = verdictFor({
    packId: 'p',
    cells: [...baseline, ...arm({ name: 'p', count: 10, wroteCode: false, valid: false })],
  });

  assert.equal(verdict.verdict, 'unmeasured');
});

test('a small denominator survives to the verdict', () => {
  // n=3 must arrive at the chip as 3. Rounding or dropping it is how a rate over three
  // cells comes to look like a rate over thirty.
  const verdict = verdictFor({
    packId: 'p',
    cells: [...baseline, ...arm({ name: 'p', count: 3, builds: 2 })],
  });

  assert.equal(verdict.verdict, 'build-rate');
  assert.equal((verdict as { n: number }).n, 3);
});

test('no input produces the struck verdict', () => {
  // DEC-016 removed "no detectable effect". Nothing reachable may name it.
  for (const builds of [0, 5, 10]) {
    const verdict = verdictFor({
      packId: 'p',
      cells: [...baseline, ...arm({ name: 'p', count: 10, builds })],
    });

    assert.equal(
      String(verdict.verdict).includes('detect'),
      false,
      `builds=${String(builds)} produced a detectability verdict`,
    );
  }
});

test('a rate never appears without its denominator, and never without its population', () => {
  assert.equal(formatRate({ hits: 5, n: 20, population: 'frontend' }), '25% n=20 (frontend)');
  assert.equal(formatRate({ hits: 8, n: 11, population: 'backend' }), '73% n=11 (backend)');
});

test('an empty denominator has no rate, and does not quietly become zero percent', () => {
  // Returning "0% n=0" would state a measurement that was never made, which is the
  // failure DATA-01 exists to prevent — one level down from the site.
  assert.throws(() => formatRate({ hits: 0, n: 0, population: 'frontend' }), RangeError);
  assert.throws(() => percentOf({ hits: 0, n: 0 }), RangeError);
  assert.throws(() => percentOf({ hits: 1, n: -1 }), RangeError);
});

test('percentOf rounds the same way the formatted rate does', () => {
  for (const [hits, n] of [
    [5, 20],
    [8, 11],
    [16, 22],
    [1, 3],
  ] as const) {
    assert.equal(
      formatRate({ hits, n, population: 'frontend' }),
      `${String(percentOf({ hits, n }))}% n=${String(n)} (frontend)`,
    );
  }
});

test('a build-rate verdict carries both populations, so a card cannot publish one alone', () => {
  // The defect PDX-005 fixes, as a property: every build-graded cell in the live corpus is
  // a frontend ticket, and the backend cells carry their own gate. A verdict that held only
  // the frontend counts let a card render them as the whole result, so both arrive together
  // or the verdict is not a build rate.
  const cells: Cell[] = [
    ...arm({ name: 'baseline', count: 4, builds: 2 }).map((cell) => ({
      ...cell,
      domain: 'frontend' as const,
    })),
    ...arm({ name: 'pack', count: 4, builds: 3 }).map((cell) => ({
      ...cell,
      domain: 'frontend' as const,
    })),
    // Backend cells: no `build` at all, graded by `passes`, and one of them carries
    // `importOk` without a passing test — the shape the doc comment refuses to grade on.
    {
      cell: 'be-0',
      task: 'be',
      arm: 'pack',
      model: 'haiku',
      rep: 0,
      valid: true,
      domain: 'backend' as const,
      wroteCode: true,
      importOk: true,
      passes: true,
    },
    {
      cell: 'be-1',
      task: 'be',
      arm: 'pack',
      model: 'haiku',
      rep: 1,
      valid: true,
      domain: 'backend' as const,
      wroteCode: true,
      importOk: true,
      passes: false,
    },
    {
      cell: 'be-2',
      task: 'be',
      arm: 'baseline',
      model: 'haiku',
      rep: 0,
      valid: true,
      domain: 'backend' as const,
      wroteCode: true,
      importOk: true,
      passes: false,
    },
  ];

  const verdict = verdictFor({ packId: 'pack', cells });

  assert.equal(verdict.verdict, 'build-rate');

  if (verdict.verdict !== 'build-rate') return;

  assert.deepEqual(
    {
      builds: verdict.builds,
      n: verdict.n,
      backendPasses: verdict.backendPasses,
      backendN: verdict.backendN,
      baselineBackendPasses: verdict.baselineBackendPasses,
      baselineBackendN: verdict.baselineBackendN,
    },
    {
      builds: 3,
      n: 4,
      backendPasses: 1,
      backendN: 2,
      baselineBackendPasses: 0,
      baselineBackendN: 1,
    },
  );
});

test('the backend rate counts backend cells, not every cell carrying a passes field', () => {
  // `passes` is recorded on frontend cells too in the live corpus. Counting the field
  // rather than the domain reported 12/35 where the backend tickets say 7/15, which is a
  // rate over a population that is mostly the other domain.
  const cells: Cell[] = [
    {
      cell: 'fe-0',
      task: 'fe',
      arm: 'pack',
      model: 'haiku',
      rep: 0,
      valid: true,
      domain: 'frontend' as const,
      wroteCode: true,
      build: false,
      passes: true,
    },
    {
      cell: 'be-0',
      task: 'be',
      arm: 'pack',
      model: 'haiku',
      rep: 0,
      valid: true,
      domain: 'backend' as const,
      wroteCode: true,
      passes: false,
    },
  ];

  const verdict = verdictFor({ packId: 'pack', cells });

  assert.equal(verdict.verdict, 'build-rate');

  if (verdict.verdict !== 'build-rate') return;

  assert.equal(verdict.backendN, 1, 'the frontend cell carrying `passes` is not a backend cell');
  assert.equal(verdict.backendPasses, 0);
});
