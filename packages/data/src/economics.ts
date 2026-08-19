import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { parseAcceptanceRecord } from './load.js';
import type { AcceptanceCorpus } from './schema.js';
import { secondsOf } from './stats.js';

/**
 * The economics of a run, joined to the record that says what condition it ran under.
 *
 * `*.results.json` carries what each cell cost — money, turns, tokens, lines, wall clock —
 * and no environment fingerprint of its own, which is why this package has kept it outside
 * DATA-01 since PDX-002. The join is what changes that: a results record adopted by the
 * acceptance record whose `run` equals its `date` inherits that record's fingerprint, its
 * regime, and its withdrawal state, which is exactly the traceability it lacks alone.
 *
 * **No filename is consulted, by anything, ever** (DATA-02). Ten results files happen to
 * spell their condition in their names today and nothing checks that they do, because
 * nothing may: the condition is a field on a record, the withdrawal is a field on a record,
 * and a file called `as-shipped` whose record says `blocked` is a blocked run. That is the
 * defect this project shipped once already, one record type over.
 *
 * A results record no acceptance record claims is refused rather than skipped. A silent
 * skip would drop a run's costs out of every mean with nothing on the page to notice.
 */

/** Thrown when a results file is not a JSON object of the shape the harness writes. */
export class MalformedResultsRecordError extends Error {
  override readonly name = 'MalformedResultsRecordError';

  constructor({ file, detail }: { file: string; detail: string }) {
    super(`${file}: ${detail}`);
  }
}

/**
 * Thrown when a results record's `date` matches no acceptance record's `run`.
 *
 * Loudly, and by name: an orphan results record has no fingerprint, no regime and no
 * withdrawal state, so pooling it would put untraceable money into a published mean, and
 * dropping it quietly would leave a run's costs missing with nothing to notice. The fix is
 * to the data, so the failure names the orphan.
 */
export class OrphanResultsRecordError extends Error {
  override readonly name = 'OrphanResultsRecordError';

  constructor({ file, date }: { file: string; date: string }) {
    super(
      `${file}: date ${JSON.stringify(date)} matches no acceptance record's run — the rows ` +
        'carry no fingerprint, no regime and no withdrawal of their own, so they are ' +
        'refused rather than pooled',
    );
  }
}

/** One row of a results record: one cell's cost, as the harness measured it. */
type ResultsRow = {
  readonly arm: string;
  readonly cost: number | null;
  readonly turns: number | null;
  readonly outputTokens: number | null;
  readonly inputTokens: number | null;
  readonly cacheTokens: number | null;
  readonly loc: number | null;
  readonly seconds: number | null;
};

/**
 * One mean, with the number of rows that actually carried the value.
 *
 * `value` is null when no row in the pool measured it. That is different from zero and the
 * type keeps the two apart, so a caller has to decide what to render rather than being
 * handed a number that was never observed.
 */
export type Measured = {
  readonly value: number | null;
  readonly n: number;
};

/**
 * A measured mean folded to a number for arithmetic that must produce one anyway — a bar
 * width, a share denominator.
 *
 * It lives here rather than in a component because the fallback is a numeric literal, and
 * DATA-01 refuses those in site source. The gate is right to: the decision "an absent mean
 * contributes nothing to this total" is a claim about the data, and it belongs in the
 * package that owns the data rather than in whichever component happened to need it first.
 */
export const measuredOrZero = ({ measured }: { measured: Measured }): number => measured.value ?? 0;

/** How the tokens of one arm divide, as fractions of its total. */
export type TokenShares = {
  readonly output: number;
  readonly input: number;
  readonly cacheRead: number;
};

/** One arm's mean cost per cell, over the rows the join put in the pool. */
export type ArmEconomics = {
  readonly arm: string;

  /** Rows pooled. A mean with no denominator is not a mean. */
  readonly econN: number;

  /**
   * Rows in the pool the harness recorded no transcript economics for. Published beside
   * the means because it is the difference between the row count and what the thinnest of
   * them is actually over.
   */
  readonly econMissing: number;

  readonly cost: Measured;
  readonly turns: Measured;
  readonly outputTokens: Measured;
  readonly inputTokens: Measured;
  readonly cacheTokens: Measured;
  readonly loc: Measured;
  readonly seconds: Measured;
  readonly shares: TokenShares;
};

/** The joined economics of one condition. */
export type Economics = {
  readonly arms: readonly ArmEconomics[];

  /** Rows pooled across every arm. */
  readonly rows: number;

  /** The runs whose rows are in the pool, by run id. */
  readonly runs: readonly string[];
};

/** True for a plain JSON object, excluding arrays and null. */
const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/** A numeric field, or `null` when the harness did not write one. */
const numberAt = ({ raw, key }: { raw: Record<string, unknown>; key: string }): number | null => {
  const value = raw[key];

  // Absent is not zero. Nine of this corpus's 441 result rows carry no economics at all,
  // and they are not spread evenly — three are baseline's. Folding them in as measured
  // zeros pulled baseline's mean wall clock from 47.03s to 45.29s, which was enough to
  // change what the Pareto chart drew: with the honest mean, ponytail dominates baseline
  // outright and the frontier has one member, not two. A missing measurement is missing,
  // and the mean below is over the rows that have one.
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
};

/** Wall clock in seconds, or null when the row never recorded one. */
const millisecondsOf = ({ raw }: { raw: Record<string, unknown> }): number | null => {
  const milliseconds = numberAt({ raw, key: 'duration_ms' });

  return milliseconds === null ? null : secondsOf({ milliseconds });
};

/** Reads one results row, requiring only the arm it belongs to. */
const parseRow = ({ raw, file }: { raw: unknown; file: string }): ResultsRow => {
  if (!isObject(raw)) {
    throw new MalformedResultsRecordError({ file, detail: 'results contains a non-object entry' });
  }

  const arm = raw['arm'];

  if (typeof arm !== 'string') {
    throw new MalformedResultsRecordError({ file, detail: 'a results row names no arm' });
  }

  return {
    arm,
    cost: numberAt({ raw, key: 'cost' }),
    turns: numberAt({ raw, key: 'turns' }),
    outputTokens: numberAt({ raw, key: 'out_tokens' }),
    inputTokens: numberAt({ raw, key: 'in_tokens' }),
    cacheTokens: numberAt({ raw, key: 'cache_tokens' }),
    loc: numberAt({ raw, key: 'total_loc' }),
    seconds: millisecondsOf({ raw }),
  };
};

/** The mean of a field over the rows of one arm. Zero rows never reach here. */
const meanOf = ({
  rows,
  pick,
}: {
  rows: readonly ResultsRow[];
  pick: (row: ResultsRow) => number | null;
}): Measured => {
  const present = rows.map(pick).filter((value): value is number => value !== null);

  if (present.length === 0) {
    return { value: null, n: 0 };
  }

  return {
    value: present.reduce((sum, value) => sum + value, 0) / present.length,
    n: present.length,
  };
};

/**
 * Every `*.results.json` in `dir`, joined to the corpus and pooled per arm.
 *
 * A row is in the pool when the acceptance record it joins to is in `corpus.records` —
 * which is how the regime filter and the withdrawal exclusion arrive here without this
 * function deciding either of them. The corpus decided; this reads the decision.
 *
 * Two separate questions, and reading the second through the first is what shipped the
 * defect this comment now spells out.
 *
 * **Which rows are in the pool**: every joined row, invalid cells included, and the page
 * says so — the money was spent whether or not the cell was later invalidated, and a mean
 * over the survivors would report the run as cheaper than it was.
 *
 * **What a mean is taken over**: the rows in that pool which actually carry the field. A
 * row that recorded no cost did not cost nothing, so each mean arrives as a `Measured`
 * carrying its own `n`, and `econMissing` says how many of the pool were silent. The two
 * numbers differ for four of six arms on the live corpus.
 *
 * @throws {OrphanResultsRecordError} a results record's `date` matches no acceptance record
 * @throws {MalformedResultsRecordError} a results file is not a well-formed record
 */
export const loadEconomics = ({
  dir,
  corpus,
}: {
  dir: string;
  corpus: AcceptanceCorpus;
}): Economics => {
  const names = readdirSync(dir).sort();

  const universe = new Set(
    names
      .filter((name) => name.endsWith('.acceptance.json'))
      .map((name) => {
        const file = join(dir, name);

        return parseAcceptanceRecord({ text: readFileSync(file, 'utf8'), file }).run;
      }),
  );

  const pooled = new Set(corpus.records.map((record) => record.run));
  const rows: ResultsRow[] = [];
  const runs: string[] = [];

  for (const name of names.filter((candidate) => candidate.endsWith('.results.json'))) {
    const file = join(dir, name);
    let raw: unknown;

    try {
      raw = JSON.parse(readFileSync(file, 'utf8'));
    } catch (error) {
      throw new MalformedResultsRecordError({ file, detail: `not valid JSON (${String(error)})` });
    }

    if (!isObject(raw)) {
      throw new MalformedResultsRecordError({ file, detail: 'top level is not an object' });
    }

    const date = raw['date'];

    if (typeof date !== 'string' || date.length === 0) {
      throw new MalformedResultsRecordError({
        file,
        detail: 'no date — the record cannot be joined to the run that produced it',
      });
    }

    if (!universe.has(date)) {
      throw new OrphanResultsRecordError({ file, date });
    }

    if (!pooled.has(date)) continue;

    const results = raw['results'];

    if (!Array.isArray(results)) {
      throw new MalformedResultsRecordError({ file, detail: 'results is missing or not an array' });
    }

    runs.push(date);

    for (const entry of results) rows.push(parseRow({ raw: entry, file }));
  }

  const arms = [...new Set(rows.map((row) => row.arm))].map((arm) => {
    const mine = rows.filter((row) => row.arm === arm);

    const outputTokens = meanOf({ rows: mine, pick: (row) => row.outputTokens });
    const inputTokens = meanOf({ rows: mine, pick: (row) => row.inputTokens });
    const cacheTokens = meanOf({ rows: mine, pick: (row) => row.cacheTokens });
    const total = (outputTokens.value ?? 0) + (inputTokens.value ?? 0) + (cacheTokens.value ?? 0);

    return {
      arm,
      econN: mine.length,
      // Rows the harness recorded no transcript economics for. `cost` stands for the set
      // because every field taken from the transcript — money, turns, tokens, wall clock —
      // is absent together on those rows. `loc` is not one of them: it is counted off the
      // delivered files afterwards and is present even where the transcript is not, so on
      // this corpus `loc.n` exceeds the others by exactly this count. Per-metric `n` on
      // each mean is the number to read; this is the deepest of them.
      econMissing: mine.length - meanOf({ rows: mine, pick: (row) => row.cost }).n,
      cost: meanOf({ rows: mine, pick: (row) => row.cost }),
      turns: meanOf({ rows: mine, pick: (row) => row.turns }),
      outputTokens,
      inputTokens,
      cacheTokens,
      loc: meanOf({ rows: mine, pick: (row) => row.loc }),
      seconds: meanOf({ rows: mine, pick: (row) => row.seconds }),
      shares:
        total > 0
          ? {
              output: (outputTokens.value ?? 0) / total,
              input: (inputTokens.value ?? 0) / total,
              cacheRead: (cacheTokens.value ?? 0) / total,
            }
          : { output: 0, input: 0, cacheRead: 0 },
    };
  });

  return { arms, rows: rows.length, runs };
};
