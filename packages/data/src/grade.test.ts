import assert from 'node:assert/strict';
import { test } from 'node:test';

import { domainOf, gradeCell } from './grade.js';
import type { Cell } from './schema.js';

/** A cell with only what the loader requires; every gate field is supplied per test. */
const cellOf = ({ extra }: { extra: Partial<Cell> }): Cell =>
  ({
    cell: 'tmpl-x__pack__haiku__0',
    task: 'tmpl-x',
    arm: 'pack',
    model: 'haiku',
    rep: 0,
    valid: true,
    ...extra,
  }) as Cell;

test('an invalid cell is invalid whatever else it carries', () => {
  const state = gradeCell({
    cell: cellOf({ extra: { valid: false, wroteCode: true, domain: 'frontend', build: true } }),
  });

  assert.equal(state, 'invalid');
});

test('a cell in which nothing was written is not a build failure', () => {
  assert.equal(gradeCell({ cell: cellOf({ extra: { wroteCode: false } }) }), 'no-code');
  assert.equal(gradeCell({ cell: cellOf({ extra: {} }) }), 'no-code');
});

test('a frontend cell is graded by the build', () => {
  assert.equal(
    gradeCell({ cell: cellOf({ extra: { wroteCode: true, domain: 'frontend', build: true } }) }),
    'built',
  );
  assert.equal(
    gradeCell({ cell: cellOf({ extra: { wroteCode: true, domain: 'frontend', build: false } }) }),
    'failed',
  );
});

test('a backend cell is graded by import plus a clean diagnostic count, not by import alone', () => {
  // `import_ok` is true for every arm on this corpus — a ceiling that cannot distinguish
  // anything — so a cell that imports and fails its tests is a failure, not a success.
  assert.equal(
    gradeCell({
      cell: cellOf({
        extra: { wroteCode: true, domain: 'backend', importOk: true, passes: false },
      }),
    }),
    'failed',
  );
  assert.equal(
    gradeCell({
      cell: cellOf({ extra: { wroteCode: true, domain: 'backend', importOk: true, passes: true } }),
    }),
    'built',
  );
});

test('a cell no gate graded is skipped rather than counted against the arm', () => {
  assert.equal(
    gradeCell({ cell: cellOf({ extra: { wroteCode: true, domain: 'frontend' } }) }),
    'ungraded',
  );
  assert.equal(
    gradeCell({ cell: cellOf({ extra: { wroteCode: true, domain: 'backend' } }) }),
    'ungraded',
  );
});

test('a cell whose record names no domain has no gate, so it is ungraded', () => {
  // Not a failure: the record does not say which gate applies, and picking one would be
  // this package inventing the fact that decides the figure.
  assert.equal(
    gradeCell({ cell: cellOf({ extra: { wroteCode: true, domain: null, build: false } }) }),
    'ungraded',
  );
  assert.equal(domainOf({ cell: cellOf({ extra: { domain: null } }) }), null);
  assert.equal(domainOf({ cell: cellOf({ extra: { domain: 'backend' } }) }), 'backend');
});
