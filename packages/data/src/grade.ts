import type { Cell } from './schema.js';

/**
 * What one cell shows, as a closed union.
 *
 * `ungraded` is not a failure and not a success: a valid cell in which the agent wrote
 * code and no gate recorded a result is not evidence in either direction. It is skipped
 * from every rate, which is the rule `rate_table` follows in `bench/harness/fisher.py`,
 * kept identical on purpose so the two halves of this project cannot answer the same
 * question differently.
 */
export type CellState = 'invalid' | 'no-code' | 'built' | 'failed' | 'ungraded';

/** The two populations this corpus grades, each by the gate its domain has. */
export type Domain = 'frontend' | 'backend';

/**
 * Grades one cell by the gate its own domain carries.
 *
 * The frontend gate is `build`: the repository's own build, run over what the agent
 * delivered. The backend gate is `passes`, which `bench/harness/acceptance.py:390` computes
 * as `bool(be_files and ok_import and not new_diags)` — the delivered code imports and adds
 * no new lint or type diagnostic. **No test suite runs for a backend cell.** An earlier
 * version of this file called it "the delivered tests" in both the prose and the label
 * below, and the label reached 102 rendered elements before a reader of the harness caught
 * it. The field is called `passes`, and a reader supplies the stronger meaning unless the
 * label refuses to.
 *
 * **Why `passes` and not `import_ok`.** The backend records also carry whether the module
 * imported cleanly, and on this corpus that field is true for every arm without exception
 * — a ceiling, and a ceiling grades nothing. Using it as the backend gate would publish a
 * hundred per cent for every pack and report that as agreement rather than as an
 * instrument that cannot discriminate.
 *
 * Order is the meaning. An invalid cell is invalid whatever else it carries; a cell in
 * which nothing was written has no code to grade, and folding it into the failures would
 * merge "produced nothing" with "produced something broken", which are different findings
 * with different consequences.
 */
export const gradeCell = ({ cell }: { cell: Cell }): CellState => {
  if (cell.valid !== true) return 'invalid';

  if (cell.wroteCode !== true) return 'no-code';

  const outcome =
    cell.domain === 'frontend' ? cell.build : cell.domain === 'backend' ? cell.passes : undefined;

  if (outcome === undefined || outcome === null) return 'ungraded';

  return outcome === true ? 'built' : 'failed';
};

/** The domain a cell was graded under, or `null` when the record does not say. */
export const domainOf = ({ cell }: { cell: Cell }): Domain | null =>
  cell.domain === 'frontend' || cell.domain === 'backend' ? cell.domain : null;

/** What each state says, in the words the legend and the drawer use. */
const STATE_LABELS: Readonly<Record<CellState, string>> = {
  built: 'built',
  failed: 'did not build',
  'no-code': 'wrote no code',
  invalid: 'invalid cell',
  ungraded: 'no gate result',
};

/** One state, as a reader reads it. Kept here so the legend types no word of its own. */
export const stateLabel = ({ state }: { state: CellState }): string => STATE_LABELS[state];

/** Which gate decided a state, named. `null` when no domain is recorded. */
export const graderLabel = ({ domain }: { domain: Domain | null }): string =>
  domain === 'frontend'
    ? 'the frontend gate: the repository build'
    : domain === 'backend'
      ? 'the backend gate: imports, and adds no new diagnostic'
      : 'no gate — the record names no domain';
