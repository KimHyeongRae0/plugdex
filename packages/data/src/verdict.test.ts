import assert from 'node:assert/strict';
import { test } from 'node:test';

import type { Cell } from './schema.js';
import { verdictFor } from './verdict.js';

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

  assert.deepEqual(above, {
    verdict: 'build-rate',
    builds: 9,
    n: 10,
    baselineBuilds: 5,
    baselineN: 10,
  });
  assert.deepEqual(below, {
    verdict: 'build-rate',
    builds: 1,
    n: 10,
    baselineBuilds: 5,
    baselineN: 10,
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
