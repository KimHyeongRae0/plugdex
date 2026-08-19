import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  armOrder,
  armSummary,
  cellGrid,
  domainSummary,
  invalidByTask,
  taskOrder,
  taskSummary,
} from './aggregate.js';
import type { Cell } from './schema.js';

/**
 * Synthetic cells throughout. An aggregate tested against the live corpus passes because
 * today's records happen to have a shape, not because the function holds the property.
 */
const cellOf = ({
  arm,
  task,
  rep,
  extra = {},
}: {
  arm: string;
  task: string;
  rep: number;
  extra?: Partial<Cell>;
}): Cell =>
  ({
    cell: `${task}__${arm}__haiku__${String(rep)}`,
    task,
    arm,
    model: 'haiku',
    rep,
    valid: true,
    ...extra,
  }) as Cell;

const frontend = ({ arm, rep, build }: { arm: string; rep: number; build: boolean }): Cell =>
  cellOf({ arm, task: 'tmpl-fe-one', rep, extra: { domain: 'frontend', wroteCode: true, build } });

const backend = ({ arm, rep, passes }: { arm: string; rep: number; passes: boolean }): Cell =>
  cellOf({
    arm,
    task: 'tmpl-be-one',
    rep,
    extra: { domain: 'backend', wroteCode: true, importOk: true, passes },
  });

const corpus: readonly Cell[] = [
  frontend({ arm: 'pack', rep: 0, build: true }),
  frontend({ arm: 'pack', rep: 1, build: false }),
  frontend({ arm: 'pack', rep: 2, build: false }),
  backend({ arm: 'pack', rep: 0, passes: true }),
  backend({ arm: 'pack', rep: 1, passes: true }),
  cellOf({
    arm: 'pack',
    task: 'tmpl-fe-one',
    rep: 3,
    extra: { valid: false, invalidReason: 'session limit' },
  }),
  cellOf({ arm: 'quiet', task: 'tmpl-fe-one', rep: 0, extra: { wroteCode: false } }),
  cellOf({ arm: 'quiet', task: 'tmpl-be-one', rep: 0, extra: { wroteCode: false } }),
];

test('the two domains are counted separately and never folded into one number', () => {
  const front = domainSummary({ cells: corpus, arm: 'pack', domain: 'frontend' });
  const back = domainSummary({ cells: corpus, arm: 'pack', domain: 'backend' });

  assert.deepEqual({ hits: front.hits, n: front.n }, { hits: 1, n: 3 });
  assert.deepEqual({ hits: back.hits, n: back.n }, { hits: 2, n: 2 });
});

test("an arm's leaderboard row is its frontend rate, with the silence beside it", () => {
  const summary = armSummary({ cells: corpus, arm: 'pack' });

  assert.deepEqual(
    {
      hits: summary.hits,
      n: summary.n,
      silent: summary.silent,
      valid: summary.valid,
      cells: summary.cells,
    },
    { hits: 1, n: 3, silent: 0, valid: 5, cells: 6 },
  );
  assert.notEqual(summary.wilson, null);
});

test('an arm with no graded cell has no rate and no interval — not a rate of zero', () => {
  const summary = armSummary({ cells: corpus, arm: 'quiet' });

  assert.deepEqual({ hits: summary.hits, n: summary.n }, { hits: 0, n: 0 });
  assert.equal(summary.wilson, null, 'an interval over nothing is absent, not [0, 0]');
  assert.deepEqual({ silent: summary.silent, valid: summary.valid }, { silent: 2, valid: 2 });
});

test('a per-ticket summary names the gate that graded it', () => {
  const front = taskSummary({ cells: corpus, arm: 'pack', task: 'tmpl-fe-one' });
  const back = taskSummary({ cells: corpus, arm: 'pack', task: 'tmpl-be-one' });

  assert.equal(front.domain, 'frontend');
  assert.equal(back.domain, 'backend');
  assert.deepEqual({ hits: front.hits, n: front.n }, { hits: 1, n: 3 });
});

test("a ticket's domain is read off the corpus, not off the arm that happened to write nothing", () => {
  // `quiet` produced no code, so none of its own cells names a domain. The ticket still
  // has one, and a summary that returned null here would leave the counts table unable to
  // say which gate the column is under.
  assert.equal(taskSummary({ cells: corpus, arm: 'quiet', task: 'tmpl-be-one' }).domain, 'backend');
});

test('the grid draws one mark per repetition and never a majority', () => {
  const grid = cellGrid({ cells: corpus });
  const square = grid.squares.find(
    (candidate) => candidate.arm === 'pack' && candidate.task === 'tmpl-fe-one',
  );

  assert.notEqual(square, undefined);
  assert.equal(square?.marks.length, 4, 'three graded repetitions and one invalid cell');
  assert.deepEqual(
    square?.marks.map((mark) => mark.state),
    ['built', 'failed', 'failed', 'invalid'],
  );
  assert.equal(square?.marks.at(-1)?.invalidReason, 'session limit');
});

test('the grid reports the corpus it is over, so the page states rather than asserts it', () => {
  const grid = cellGrid({ cells: corpus });

  assert.deepEqual(grid.totals, { cells: 8, valid: 7, squares: 4, arms: 2, tasks: 2 });
  assert.equal(
    grid.squares.reduce((sum, square) => sum + square.marks.length, 0),
    grid.totals.cells,
    'every cell is drawn exactly once',
  );
});

test('the corpus order is the order the records introduce it, not an alphabet', () => {
  assert.deepEqual(armOrder({ cells: corpus }), ['pack', 'quiet']);
  assert.deepEqual(taskOrder({ cells: corpus }), ['tmpl-fe-one', 'tmpl-be-one']);
});

test('the invalid cells are reported per ticket, worst first', () => {
  const [worst] = invalidByTask({ cells: corpus });

  assert.equal(worst?.task, 'tmpl-fe-one');
  assert.deepEqual({ invalid: worst?.invalid, cells: worst?.cells }, { invalid: 1, cells: 5 });
});
