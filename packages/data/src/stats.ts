/**
 * Intervals and figure formatting.
 *
 * Two jobs, and they are the same job seen from either end. A rate over twenty cells is
 * not a point, it is an interval, and a page that prints the point without the interval
 * has published a precision it does not have. And every token a reader reads — a rate, an
 * interval, a mean, an axis tick label — is produced here rather than in a component,
 * because DATA-01 forbids a typed figure in site source and the conversions all need a
 * literal. Keeping them next to the records leaves the site's figure path free of numeric
 * literals entirely, which is what makes the gate absolute instead of negotiable.
 *
 * Nothing here decides which records a figure is computed over; that is DATA-02's half,
 * and it lives on the records.
 */

/**
 * The standard-normal quantile the interval is computed at.
 *
 * Two-sided, at the conventional level: the value below is the 0.975 quantile of the
 * standard normal distribution, so 0.95 of the mass falls inside. It is pinned as a named
 * constant rather than written at each call site because a quantile silently changed is a
 * published interval silently changed, and nothing downstream could detect it.
 */
const Z = 1.959963984540054;

/** Percent has a hundred parts. Named so the conversion is not a bare literal. */
const PERCENT_SCALE = 100;

/** Milliseconds in a second, for records that measure duration the way a clock does. */
const MILLISECONDS_PER_SECOND = 1000;

/** Digits after the point on a money figure — a cell costs cents, so cents are not enough. */
const MONEY_DIGITS = 4;

/** Digits after the point on a mean that is not money. One is what the sample supports. */
const MEAN_DIGITS = 1;

/** Where a thousands separator goes. */
const GROUPING = /\B(?=(\d{3})+(?!\d))/g;

/** A closed interval on the unit line, as fractions rather than percentages. */
export type Interval = {
  readonly lo: number;
  readonly hi: number;
};

/** One axis tick: where it sits as a fraction of the axis, and what it says. */
export type AxisTick = {
  readonly fraction: number;
  readonly label: string;
};

/** The two populations this corpus grades, each by its own gate. */
export type Population = 'frontend' | 'backend';

/**
 * The 95% Wilson score interval for `hits` successes out of `n`.
 *
 * The score interval rather than the normal approximation, because the approximation is
 * wrong in exactly the region this corpus lives in: at n around twenty and p near zero or
 * one it produces bounds outside `[0, 1]`, and a published interval reaching past 100% is
 * a figure that discredits the page carrying it. The score interval is asymmetric near the
 * ends by construction, which is the honest shape.
 *
 * @throws {RangeError} `n` is zero or negative — an empty denominator has no interval, and
 * returning `[0, 0]` would state a measurement that was never taken.
 */
export const wilson = ({ hits, n }: { hits: number; n: number }): Interval => {
  if (n <= 0) {
    throw new RangeError(`an interval needs a denominator, got n=${String(n)}`);
  }

  const p = hits / n;
  const zSquared = Z * Z;
  const denominator = 1 + zSquared / n;

  const centre = (p + zSquared / (2 * n)) / denominator;
  const margin = (Z / denominator) * Math.sqrt((p * (1 - p)) / n + zSquared / (4 * n * n));

  return { lo: Math.max(0, centre - margin), hi: Math.min(1, centre + margin) };
};

/** A whole-number percentage of a fraction already in `0..1`. */
const percentOfFraction = ({ fraction }: { fraction: number }): number =>
  Math.round(fraction * PERCENT_SCALE);

/**
 * A rate as a reader meets one: the percentage, its denominator, and the population it is
 * a rate over.
 *
 * `population` is required rather than optional, and it is baked into the returned string
 * rather than left to the caller to mention. A build rate over twenty frontend cells that
 * does not say `frontend` is honest arithmetic and a misleading sentence, which is exactly
 * the defect PDX-005 exists to fix — so the honest path is made total by the type system
 * and dropping the population means not rendering the rate at all.
 *
 * @throws {RangeError} `n` is zero or negative.
 */
export const formatRate = ({
  hits,
  n,
  population,
}: {
  hits: number;
  n: number;
  population: Population;
}): string => {
  if (n <= 0) {
    throw new RangeError(`a rate needs a denominator, got n=${String(n)}`);
  }

  return `${String(percentOfFraction({ fraction: hits / n }))}% n=${String(n)} (${population})`;
};

/**
 * The denominator of a figure whose percentage is printed beside it.
 *
 * The interval string carries no denominator of its own — it is two bounds, not a rate —
 * so the element that prints it prints this next to it. Every percentage on the page then
 * sits in an element that also names its `n` and its population, with no element assembling
 * that phrase out of typed characters.
 */
export const formatDenominator = ({
  n,
  population,
}: {
  n: number;
  population: Population;
}): string => `n=${String(n)} (${population})`;

/** An interval as two percentages: `11% - 47%`. */
export const formatIntervalPercent = ({ lo, hi }: Interval): string =>
  `${String(percentOfFraction({ fraction: lo }))}% - ${String(percentOfFraction({ fraction: hi }))}%`;

/** A count over a count: `5/20`. Not a rate — no division is performed. */
export const formatCountOverCount = ({ hits, n }: { hits: number; n: number }): string =>
  `${String(hits)}/${String(n)}`;

/** A thousands-separated whole number. */
const grouped = ({ value }: { value: number }): string =>
  String(Math.round(value)).replace(GROUPING, ',');

/** Money, to the fraction of a cent a single cell actually costs. */
export const formatMoney = ({ usd }: { usd: number }): string => `$${usd.toFixed(MONEY_DIGITS)}`;

/** Wall clock, in whole seconds. */
export const formatSeconds = ({ seconds }: { seconds: number }): string =>
  `${grouped({ value: seconds })}s`;

/** A token count, grouped so a reader can compare two of them at a glance. */
export const formatTokens = ({ count }: { count: number }): string => grouped({ value: count });

/** A mean number of turns, at the precision a sample of this size supports. */
export const formatTurns = ({ turns }: { turns: number }): string => turns.toFixed(MEAN_DIGITS);

/** A mean line count. Lines are whole things. */
export const formatLoc = ({ loc }: { loc: number }): string => grouped({ value: loc });

/** Milliseconds as seconds, for records that measure duration the way a clock does. */
export const secondsOf = ({ milliseconds }: { milliseconds: number }): number =>
  milliseconds / MILLISECONDS_PER_SECOND;

/**
 * A task id as a column heading.
 *
 * The records prefix every task with the template family it came from. That prefix is the
 * same on all of them, so printing it twelve times across a heading row spends the width a
 * narrow viewport does not have and tells a reader nothing.
 */
export const formatTaskLabel = ({ task }: { task: string }): string => task.replace(/^tmpl-/, '');

/** The graded-cell count under a small multiple, as a phrase. */
export const formatGradedCells = ({
  count,
  population,
}: {
  count: number;
  population: Population;
}): string => `${String(count)} graded ${population} cells`;

/** An axis tick label as a bare number of percentage points: the axis title carries the unit. */
export const formatPercentTick = ({ value }: { value: number }): string =>
  String(percentOfFraction({ fraction: value }));

/** An axis tick label in money. */
export const formatMoneyTick = ({ value }: { value: number }): string =>
  formatMoney({ usd: value });

/** An axis tick label in seconds. */
export const formatSecondsTick = ({ value }: { value: number }): string =>
  formatSeconds({ seconds: value });

/**
 * Evenly spaced ticks from zero to `max`, each with the label a reader reads.
 *
 * The labels are produced here rather than by a loop in a component for the same reason
 * every other figure is: a tick label is a number a reader reads off the page, and a
 * component that formats one has typed a figure. The positions come back as fractions of
 * the axis so the caller multiplies them by a length it names, and no site expression
 * contains a scale factor.
 *
 * @throws {RangeError} `count` is not positive — an axis with no interval has no ticks.
 */
export const axisTicks = ({
  max,
  count,
  format,
}: {
  max: number;
  count: number;
  format: (input: { value: number }) => string;
}): readonly AxisTick[] => {
  if (count <= 0) {
    throw new RangeError(`an axis needs at least one interval, got count=${String(count)}`);
  }

  return Array.from({ length: count + 1 }, (_unused, index) => {
    const fraction = index / count;

    return { fraction, label: format({ value: max * fraction }) };
  });
};

/**
 * A domain as a column tag.
 *
 * Two letters because it sits under twelve columns on a table a narrow viewport already
 * has to scroll; the section heading spells both domains out.
 */
export const formatDomainLabel = ({ domain }: { domain: 'frontend' | 'backend' | null }): string =>
  domain === 'frontend' ? 'fe' : domain === 'backend' ? 'be' : '--';

/** The absence of a figure, printed where a figure would have gone. */
export const formatAbsent = (): string => '--';

/**
 * One measured mean, rendered — or the absent marker when nothing in the pool carried it.
 *
 * This exists so a caller cannot accidentally print a mean over an empty set. Nine of this
 * corpus's 441 result rows carry no economics at all, and an earlier version of the loader
 * read those absences as zeros, which pulled four arms' means toward the floor and changed
 * what the wall-clock chart drew. The type now forces the decision here, once, in the
 * package that owns the figures rather than in each component that shows one.
 */
export const formatMeasured = ({
  measured,
  format,
}: {
  measured: { readonly value: number | null; readonly n: number };
  format: (input: { value: number }) => string;
}): string => (measured.value === null ? formatAbsent() : format({ value: measured.value }));

/**
 * How far a mean's denominator falls short of the pool it was taken from — or `null` when
 * it does not fall short.
 *
 * A mean printed beside a pool size a reader assumes it was taken over is a quiet lie when
 * some rows carried no measurement, and the shortfall is not uniform across an arm's
 * metrics: on this corpus baseline's cost mean is over 52 rows while its lines-of-code mean
 * is over all 54, because the two rows that recorded no money still recorded their diff.
 * So the shortfall is per figure, never per row of the table, and the figures that were
 * taken over the whole pool say nothing rather than repeating the denominator six times.
 */
export const formatShortfall = ({
  measured,
  pool,
}: {
  measured: { readonly value: number | null; readonly n: number };
  pool: number;
}): string | null =>
  measured.value === null || measured.n >= pool ? null : `n=${String(measured.n)}/${String(pool)}`;

/**
 * What the corpus covers, as a reader meets it.
 *
 * Every number a reader reads is produced here rather than in a component, for the reason
 * DATA-01 exists: a count assembled in markup is a typed figure, and the gate reads a digit
 * inside a rendered expression as one. The fixture is passed in rather than derived — it is
 * cited from `bench/REPRODUCE.md`, because no cell records it and inferring it from task-id
 * prefixes would let a rename publish a claim about provenance (DEC-019).
 */
export const formatCoverage = ({
  inventory,
  fixture,
}: {
  inventory: {
    readonly tasks: number;
    readonly shapes: readonly {
      readonly shape: string;
      readonly tasks: number;
      readonly cells: number;
    }[];
  };
  fixture: { readonly repo: string; readonly commit: string };
}): string => {
  const shapes = inventory.shapes
    .map((shape) => `${String(shape.tasks)} ${shape.shape} (${String(shape.cells)} cells)`)
    .join(', ');

  return (
    `${String(inventory.tasks)} tasks, all in one repository — ` +
    `${fixture.repo} at ${fixture.commit}. ${shapes}.`
  );
};

/**
 * A claim this project published and then retracted.
 *
 * Named `ClaimWithdrawal` rather than `Withdrawal`: this package already has the second, and
 * it means a withdrawn *run* — an instrument failure excluded from the corpus. A retracted
 * claim and a discarded run are different objects and sharing a name would let a reader of
 * either think they had met the other.
 *
 * A withdrawal is a record, not a paragraph. It carries the date it was made, and DATA-01 is
 * right to block that date being typed into markup: a date a reader reads is a figure, and
 * the rule has no exemption for one that happens to be about our own mistake. Keeping the
 * record here means the page renders it the same way it renders a rate.
 */
export type ClaimWithdrawal = {
  readonly id: string;
  readonly withdrawnOn: string;
  readonly previously: string;
  readonly cause: string;
};

/** The scope claim withdrawn by PDX-035. */
export const SCOPE_WITHDRAWAL: ClaimWithdrawal = {
  id: 'withdrawal-scope',
  withdrawnOn: '2026-08-20',
  previously: 'run against real tickets in a real repository',
  cause:
    'nobody had counted. The scope was discoverable from the analysis page and from the ' +
    'records, and never stated beside the headline where a reader forms an impression.',
};
