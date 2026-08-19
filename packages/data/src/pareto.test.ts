import assert from 'node:assert/strict';
import { test } from 'node:test';

import { paretoFrontier } from './pareto.js';

test('the frontier keeps what nothing beats on both axes at once', () => {
  const members = paretoFrontier({
    points: [
      { id: 'cheap-bad', x: 1, y: 0.2 },
      { id: 'middle', x: 2, y: 0.5 },
      { id: 'dominated', x: 3, y: 0.4 },
      { id: 'dear-good', x: 4, y: 0.7 },
    ],
  });

  assert.deepEqual(
    members.map((point) => point.id),
    ['cheap-bad', 'middle', 'dear-good'],
  );
});

test('a tie on x is one position on the chart, not a vertical segment', () => {
  // Two arms at the same cost are the same x. Keeping both would draw a line straight up,
  // which a reader reads as a trade-off between two things that cost the same.
  const members = paretoFrontier({
    points: [
      { id: 'worse-at-the-same-cost', x: 2, y: 0.3 },
      { id: 'better-at-the-same-cost', x: 2, y: 0.6 },
      { id: 'dearer', x: 5, y: 0.9 },
    ],
  });

  assert.deepEqual(
    members.map((point) => point.id),
    ['better-at-the-same-cost', 'dearer'],
  );
  assert.equal(new Set(members.map((point) => point.x)).size, members.length);
});

test('one dominating point is a frontier of one, and the caller draws no line', () => {
  // The live wall-clock chart: one arm is best on both axes, so there is no trade-off to
  // draw. The page owes the reader that sentence rather than an empty chart.
  const members = paretoFrontier({
    points: [
      { id: 'dominant', x: 1, y: 0.9 },
      { id: 'slower-and-worse', x: 2, y: 0.4 },
      { id: 'slowest-and-worst', x: 3, y: 0.1 },
    ],
  });

  assert.deepEqual(
    members.map((point) => point.id),
    ['dominant'],
  );
  assert.ok(members.length < 2, 'fewer than two members means nothing to draw a line through');
});

test('a frontier over no point is refused rather than returned empty', () => {
  assert.throws(() => paretoFrontier({ points: [] }), RangeError);
});
