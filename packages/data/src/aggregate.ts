import { readFileSync } from 'node:fs';

import { domainOf, gradeCell, stateLabel } from './grade.js';
import type { CellState, Domain } from './grade.js';
import type { Cell } from './schema.js';
import { wilson } from './stats.js';
import type { Interval } from './stats.js';

/** The order the four states are drawn in inside one square: outcomes first, absence last. */
const STATE_ORDER: readonly CellState[] = ['built', 'failed', 'no-code', 'ungraded', 'invalid'];

/** A rate over one population: the counts, and the interval they actually support. */
export type RateSummary = {
  readonly hits: number;
  readonly n: number;

  /** `null` when nothing was graded. An interval over no cell is not zero, it is absent. */
  readonly wilson: Interval | null;
};

/**
 * The rate as a fraction, or `null` when nothing was graded.
 *
 * Exists so a component can size a bar without dividing. `hits / n` written in site source
 * is a figure computed in the site — the bar's length is something a reader perceives and
 * compares — and it passes the DATA-01 source scanner only because the scale it multiplies
 * by is layout vocabulary. Returning the fraction here leaves the component with one
 * multiplication whose product is a width, which is the line the plan drew.
 */
export const rateFraction = ({ summary }: { summary: RateSummary }): number | null =>
  summary.n > 0 ? summary.hits / summary.n : null;

/** One leaderboard row, before the economics are joined to it. */
export type ArmSummary = RateSummary & {
  readonly arm: string;

  /** Valid cells in which the agent wrote nothing at all. */
  readonly silent: number;

  /** Valid cells the arm was given. */
  readonly valid: number;

  /** Every cell the arm was given, valid or not. */
  readonly cells: number;
};

/** One spoke of a small multiple: the rate on one ticket, and which gate graded it. */
export type TaskSummary = RateSummary & {
  readonly task: string;
  readonly domain: Domain | null;
};

/** One mark: a repetition, its state, and the identity a reader can ask about. */
export type CellMark = {
  readonly cell: string;
  readonly state: CellState;
  readonly arm: string;
  readonly task: string;
  readonly model: string;
  readonly rep: number;
  readonly domain: Domain | null;
  readonly invalidReason: string | null;
};

/** One square of the grid: an arm on a ticket, with one mark per repetition. */
export type GridSquare = {
  readonly arm: string;
  readonly task: string;
  readonly marks: readonly CellMark[];
};

/** What the grid is over, so a page can state the corpus rather than assert it. */
export type GridTotals = {
  readonly cells: number;
  readonly valid: number;
  readonly squares: number;
  readonly arms: number;
  readonly tasks: number;
};

/** The whole grid, and the totals a reader can check it against. */
export type CellGrid = {
  readonly squares: readonly GridSquare[];
  readonly totals: GridTotals;
};

/** Every arm the corpus holds, in the order the records introduce them. */
export const armOrder = ({ cells }: { cells: readonly Cell[] }): readonly string[] => [
  ...new Set(cells.map((cell) => cell.arm)),
];

/** Every task the corpus holds, in the order the records introduce them. */
export const taskOrder = ({ cells }: { cells: readonly Cell[] }): readonly string[] => [
  ...new Set(cells.map((cell) => cell.task)),
];

/** Counts a set of already-selected cells, skipping everything no gate graded. */
const rateOver = ({ cells }: { cells: readonly Cell[] }): RateSummary => {
  let hits = 0;
  let n = 0;

  for (const cell of cells) {
    const state = gradeCell({ cell });

    if (state !== 'built' && state !== 'failed') continue;

    n += 1;
    if (state === 'built') hits += 1;
  }

  return { hits, n, wilson: n > 0 ? wilson({ hits, n }) : null };
};

/**
 * The rate of one arm on one domain.
 *
 * The two domains are never folded together and no function here will do it: they are
 * graded by different gates over different tickets, and a single number spanning both
 * would describe neither. AC-2's disclosure is this function existing separately.
 */
export const domainSummary = ({
  cells,
  arm,
  domain,
}: {
  cells: readonly Cell[];
  arm: string;
  domain: Domain;
}): RateSummary =>
  rateOver({
    cells: cells.filter((cell) => cell.arm === arm && domainOf({ cell }) === domain),
  });

/**
 * One arm's leaderboard row.
 *
 * The rate is the **frontend build rate** — the headline the catalogue has published since
 * PDX-004, now named rather than implied. The backend rate is its own function and its own
 * column, because the two are not one population.
 */
export const armSummary = ({ cells, arm }: { cells: readonly Cell[]; arm: string }): ArmSummary => {
  const mine = cells.filter((cell) => cell.arm === arm);
  const valid = mine.filter((cell) => cell.valid === true);
  const rate = domainSummary({ cells, arm, domain: 'frontend' });

  return {
    arm,
    ...rate,
    silent: valid.filter((cell) => cell.wroteCode === false).length,
    valid: valid.length,
    cells: mine.length,
  };
};

/** One arm's rate on one ticket, with the domain whose gate decided it. */
export const taskSummary = ({
  cells,
  arm,
  task,
}: {
  cells: readonly Cell[];
  arm: string;
  task: string;
}): TaskSummary => {
  const onTask = cells.filter((cell) => cell.task === task);
  const domain = onTask.map((cell) => domainOf({ cell })).find((value) => value !== null) ?? null;

  return {
    task,
    domain,
    ...rateOver({ cells: onTask.filter((cell) => cell.arm === arm) }),
  };
};

/**
 * Every cell of the corpus, one mark per repetition, arranged as arm x ticket squares.
 *
 * Nothing is aggregated away and no square carries a verdict of its own: three repetitions
 * that disagree are drawn as three marks that disagree, because a majority over three is a
 * number with no interval and the disagreement is the finding.
 */
export const cellGrid = ({ cells }: { cells: readonly Cell[] }): CellGrid => {
  const arms = armOrder({ cells });
  const tasks = taskOrder({ cells });
  const squares: GridSquare[] = [];

  for (const arm of arms) {
    for (const task of tasks) {
      const marks = cells
        .filter((cell) => cell.arm === arm && cell.task === task)
        .map((cell) => ({
          cell: cell.cell,
          state: gradeCell({ cell }),
          arm: cell.arm,
          task: cell.task,
          model: cell.model,
          rep: cell.rep,
          domain: domainOf({ cell }),
          invalidReason: cell.invalidReason ?? null,
        }))
        .sort((left, right) => STATE_ORDER.indexOf(left.state) - STATE_ORDER.indexOf(right.state));

      if (marks.length === 0) continue;

      squares.push({ arm, task, marks });
    }
  }

  return {
    squares,
    totals: {
      cells: cells.length,
      valid: cells.filter((cell) => cell.valid === true).length,
      squares: squares.length,
      arms: arms.length,
      tasks: tasks.length,
    },
  };
};

/** How many invalid cells each ticket carries, and how many cells it holds in all. */
export type InvalidByTask = {
  readonly task: string;
  readonly invalid: number;
  readonly cells: number;
};

/**
 * The invalid cells, per ticket, worst first.
 *
 * A quarter of this corpus is invalid and the cause is one instrument failure clustered on
 * a handful of tickets, so a page that reported only the total would let a reader assume it
 * was spread evenly — which would make every column look equally trustworthy.
 */
export const invalidByTask = ({ cells }: { cells: readonly Cell[] }): readonly InvalidByTask[] =>
  taskOrder({ cells })
    .map((task) => {
      const onTask = cells.filter((cell) => cell.task === task);

      return {
        task,
        invalid: onTask.filter((cell) => cell.valid !== true).length,
        cells: onTask.length,
      };
    })
    .sort((left, right) => right.invalid - left.invalid);

/**
 * One mark, as a screen reader hears it.
 *
 * The grid draws three hundred and twelve controls whose whole content is a shape, so
 * without this every one of them is an unnamed button. The identity comes off the record;
 * nothing here is authored except the punctuation between the fields.
 */
export const formatCellLabel = ({ mark }: { mark: CellMark }): string =>
  `${mark.arm} on ${mark.task}, ${mark.model}, repetition ${String(mark.rep)} — ` +
  stateLabel({ state: mark.state });

/** One shape of work in the corpus: a task-id family paired with a domain. */
export type CorpusShape = {
  readonly shape: string;
  readonly tasks: number;
  readonly cells: number;
};

/** What the corpus actually covers, counted rather than described. */
export type CorpusInventory = {
  readonly tasks: number;
  readonly shapes: readonly CorpusShape[];
  /** The distinct task-id families. A consistency check against the cited fixture, not a claim. */
  readonly families: readonly string[];
};

/** `tmpl-fe-datepicker` → `tmpl-fe`. Two segments, because the third is the task. */
const SHAPE = /^([a-z]+)-([a-z]+)-/;

/**
 * The corpus inventory, derived from the cells it is handed.
 *
 * **What this does not do is the point.** It counts tasks, shapes and cells. It does not
 * decide how many fixtures the corpus used: no cell carries that, and an earlier design
 * inferred it from how many `tmpl-` families the task ids happened to show — which would have
 * made a rename inside one fixture publish "two repositories". DEC-019 already records the
 * rule that broke: a filename is not the fact. `families` is exported so a caller can check
 * the ids against the fixture its documentation names, and say so when they disagree.
 */
export const corpusInventory = ({ cells }: { cells: readonly Cell[] }): CorpusInventory => {
  const tasks = new Set<string>();
  const byShape = new Map<string, { tasks: Set<string>; cells: number }>();

  /*
   * Valid cells only, because that is what every rate on the page is over.
   *
   * `armSummary` counts `cell.valid === true`, so a coverage sentence counting the whole
   * corpus would describe a different pool than the figures it sits beside — 204 frontend
   * cells against rates taken over 127. A scope note whose denominator disagrees with the
   * denominators it is explaining is the defect this ticket exists to remove, committed in
   * the sentence meant to remove it.
   */
  for (const cell of cells.filter((entry) => entry.valid === true)) {
    tasks.add(cell.task);

    const match = SHAPE.exec(cell.task);

    if (match === null) continue;

    const shape = `${match[1] as string}-${match[2] as string}`;
    const entry = byShape.get(shape) ?? { tasks: new Set<string>(), cells: 0 };

    entry.tasks.add(cell.task);
    entry.cells += 1;
    byShape.set(shape, entry);
  }

  return {
    tasks: tasks.size,
    shapes: [...byShape.entries()]
      .map(([shape, entry]) => ({ shape, tasks: entry.tasks.size, cells: entry.cells }))
      .sort((left, right) => left.shape.localeCompare(right.shape)),
    families: [
      ...new Set([...byShape.keys()].map((shape) => shape.split('-')[0] as string)),
    ].sort(),
  };
};

/** Where an arm sits relative to the baseline's interval — three outcomes, not two. */
export type SeparationTier = 'clears' | 'overlaps' | 'unmeasured';

/**
 * The tier an arm belongs to, decided by the intervals and nothing else.
 *
 * **`unmeasured` is its own outcome and that is the whole design.** An arm with no graded
 * cell has no interval, and a two-way "overlaps or does not" reads that absence as *does
 * not* — which on the live corpus put `superpowers` (n=0, no interval) in the same tier as
 * `ponytail`, the one arm whose interval clears the baseline's. The pack that writes no code
 * would have been shown beside the only pack that beats installing nothing. Plan review round
 * 1 caught it before any of this was written, which is the reason the null case is tested
 * first here rather than falling through to an else.
 *
 * A tier is a statement about intervals, not a rank: it says whether this corpus can tell an
 * arm apart from the baseline, and nothing about how two arms in the same tier compare.
 */
export const separationTier = ({
  summary,
  baseline,
}: {
  summary: ArmSummary;
  baseline: ArmSummary;
}): SeparationTier => {
  if (summary.wilson === null || baseline.wilson === null) {
    return 'unmeasured';
  }

  return summary.wilson.lo > baseline.wilson.hi ? 'clears' : 'overlaps';
};

/** The fixture a run was graded against, as its own documentation states it. */
export type Fixture = {
  readonly repo: string;
  readonly commit: string;
};

/** The row `bench/REPRODUCE.md` writes the fixture on. */
const FIXTURE_ROW = /\|\s*Fixture\s*\|\s*`([^`]+)`\s*@\s*`([^`]+)`/;

/** A record file that does not state the fixture the site is about to publish. */
export class MissingFixtureError extends Error {
  constructor({ file }: { file: string }) {
    super(
      `${file} states no fixture — the site cites this file rather than inferring provenance ` +
        `from task ids, so an absent row is a missing fact and not a default`,
    );
    this.name = 'MissingFixtureError';
  }
}

/**
 * The fixture, read from the file that documents it.
 *
 * Cited rather than derived. No cell carries a fixture, and the alternative considered and
 * rejected was counting task-id families: rename one task inside a fixture and that count
 * becomes two, so the page would state "two repositories" on the strength of a string
 * convention. DEC-019 — a filename is not the fact — and `corpusInventory().families` exists
 * so a caller can check the ids against this and report a disagreement rather than silently
 * preferring either.
 *
 * @throws {MissingFixtureError} the file names no fixture. Publishing provenance nobody
 * recorded is worse than publishing none.
 */
export const readFixture = ({ file }: { file: string }): Fixture => {
  const match = FIXTURE_ROW.exec(readFileSync(file, 'utf8'));

  if (match === null) {
    throw new MissingFixtureError({ file });
  }

  return { repo: match[1] as string, commit: match[2] as string };
};
