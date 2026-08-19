import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  axisTicks,
  formatCountOverCount,
  formatDenominator,
  formatGradedCells,
  formatIntervalPercent,
  formatLoc,
  formatMeasured,
  formatMoney,
  formatMoneyTick,
  formatPercentTick,
  formatRate,
  formatSeconds,
  formatSecondsTick,
  formatShortfall,
  formatTaskLabel,
  formatTokens,
  formatTurns,
  secondsOf,
  wilson,
} from './stats.js';

/** The interval this project's own prototype published for the baseline arm. */
const TOLERANCE = 1e-3;

test('the interval is the Wilson score interval, at the value the page publishes', () => {
  const { lo, hi } = wilson({ hits: 5, n: 20 });

  assert.ok(Math.abs(lo - 0.1119) < TOLERANCE, `lo was ${String(lo)}`);
  assert.ok(Math.abs(hi - 0.4687) < TOLERANCE, `hi was ${String(hi)}`);
});

test('the interval is asymmetric at the ends, which is why it is not the normal approximation', () => {
  const none = wilson({ hits: 0, n: 20 });
  const all = wilson({ hits: 20, n: 20 });

  // The normal approximation collapses to a point at both ends and reaches outside [0, 1]
  // just inside them. The score interval does neither.
  assert.equal(none.lo, 0);
  assert.ok(none.hi > 0, 'zero out of twenty is not certainty');
  assert.ok(all.lo < 1, 'twenty out of twenty is not certainty either');
  assert.equal(all.hi, 1);
});

test('an interval over no cell is refused rather than returned as zero to zero', () => {
  assert.throws(() => wilson({ hits: 0, n: 0 }), RangeError);
  assert.throws(() => wilson({ hits: 0, n: -1 }), RangeError);
});

test('every formatter prints the figure a reader reads, and nothing else', () => {
  assert.equal(formatIntervalPercent({ lo: 0.1119, hi: 0.4687 }), '11% - 47%');
  assert.equal(formatCountOverCount({ hits: 5, n: 20 }), '5/20');
  assert.equal(formatDenominator({ n: 20, population: 'frontend' }), 'n=20 (frontend)');
  assert.equal(formatMoney({ usd: 0.0853 }), '$0.0853');
  assert.equal(formatSeconds({ seconds: 47.4 }), '47s');
  assert.equal(formatTokens({ count: 181982 }), '181,982');
  assert.equal(formatTurns({ turns: 12.34 }), '12.3');
  assert.equal(formatLoc({ loc: 23.6 }), '24');
  assert.equal(formatTaskLabel({ task: 'tmpl-fe-datepicker' }), 'fe-datepicker');
  assert.equal(
    formatGradedCells({ count: 20, population: 'frontend' }),
    '20 graded frontend cells',
  );
  assert.equal(secondsOf({ milliseconds: 38012 }), 38.012);
});

test('a rate carries its denominator and its population, or it is not produced at all', () => {
  assert.equal(formatRate({ hits: 16, n: 22, population: 'frontend' }), '73% n=22 (frontend)');
  assert.equal(formatRate({ hits: 7, n: 15, population: 'backend' }), '47% n=15 (backend)');
  assert.throws(() => formatRate({ hits: 0, n: 0, population: 'backend' }), RangeError);
});

test('axis tick labels are produced here, as bare numbers on a percentage axis', () => {
  // The axis title carries the unit. A scale mark is not a rate, so it does not get to
  // look like one — which is what keeps the page-wide "a percentage carries its
  // denominator" rule exemption-free.
  const ticks = axisTicks({ max: 1, count: 4, format: formatPercentTick });

  assert.deepEqual(
    ticks.map((tick) => tick.label),
    ['0', '25', '50', '75', '100'],
  );
  assert.deepEqual(
    ticks.map((tick) => tick.fraction),
    [0, 0.25, 0.5, 0.75, 1],
  );
});

test('a money axis and a seconds axis label themselves through their own formatters', () => {
  assert.deepEqual(
    axisTicks({ max: 0.4, count: 2, format: formatMoneyTick }).map((tick) => tick.label),
    ['$0.0000', '$0.2000', '$0.4000'],
  );
  assert.deepEqual(
    axisTicks({ max: 60, count: 2, format: formatSecondsTick }).map((tick) => tick.label),
    ['0s', '30s', '60s'],
  );
});

test('an axis with no interval has no ticks and says so', () => {
  assert.throws(() => axisTicks({ max: 1, count: 0, format: formatPercentTick }), RangeError);
});

test('a mean nothing measured prints as an absence, and never reaches its formatter', () => {
  // The defect this pins is not cosmetic. An unmeasured mean rendered through a money
  // formatter prints `$0.0000`, which a reader reads as "this arm cost nothing" — the same
  // absence-read-as-zero that moved the wall-clock chart before the loader was corrected.
  let formatterCalls = 0;

  const format = ({ value }: { value: number }): string => {
    formatterCalls += 1;

    return formatMoney({ usd: value });
  };

  assert.equal(formatMeasured({ measured: { value: null, n: 0 }, format }), '--');
  assert.equal(formatterCalls, 0, 'the formatter is not handed a substituted zero');

  assert.equal(formatMeasured({ measured: { value: 0.0849, n: 52 }, format }), '$0.0849');
  assert.equal(formatterCalls, 1);
});

test('a mean says what it fell short by, and says nothing when it did not', () => {
  // The live shape this pins: on the published corpus baseline's cost mean is over 52 of its
  // 54 pooled rows while its lines-of-code mean is over all 54, because the two rows that
  // recorded no money still recorded their diff. One denominator per row would therefore be
  // false of four of the five economics columns, which is why the shortfall is per figure.
  assert.equal(formatShortfall({ measured: { value: 0.0849, n: 52 }, pool: 54 }), 'n=52/54');
  assert.equal(
    formatShortfall({ measured: { value: 143, n: 54 }, pool: 54 }),
    null,
    'a mean over the whole pool prints no denominator — a caveat on every cell is one a reader stops seeing',
  );
  assert.equal(
    formatShortfall({ measured: { value: null, n: 0 }, pool: 54 }),
    null,
    'an absent mean is already rendered as an absence; a shortfall beside it would qualify a figure that is not there',
  );
});
