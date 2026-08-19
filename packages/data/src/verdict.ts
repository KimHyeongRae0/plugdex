import { domainSummary } from './aggregate.js';
import type { Cell } from './schema.js';

/**
 * A claim a pack's own documentation makes about itself, with the interval that tests it.
 *
 * The interval must arrive as a record, never as a value the caller computed. A verdict
 * that says a published claim was not reproduced is a statistical assertion, and one
 * assembled in a caller's head is exactly the un-derived figure this project refuses
 * everywhere else — it would launder the statistic DEC-016 just removed from the rate
 * verdict. No such record exists yet: `results.json` carries the claimed figures and no
 * environment fingerprint, so it sits outside `@plugdex/data` until the ticket that
 * brings it under DATA-01. Until then this input is empty on the live corpus and the
 * branch is exercised only by tests.
 */
export type PackClaim = {
  readonly packId: string;

  /** What the claim is about — `tokens`, `cost`, and so on. */
  readonly metric: string;

  /** The figure the pack publishes. */
  readonly claimed: number;

  /** The measured interval, inclusive, from the record that produced it. */
  readonly low: number;
  readonly high: number;
};

/**
 * What the catalogue can say about a pack, in the priority order DESIGN.md's chip table
 * fixes. The first matching condition wins.
 *
 * There are four members and the numbering skips 4. **Verdict 4, `no detectable effect`,
 * is struck** (DEC-016): rendering it requires deciding per pack whether a difference is
 * real, and this corpus cannot support that decision — DESIGN.md's own Bonferroni
 * threshold for four pack-vs-baseline tests is 0.0125 against a best nominal p of 0.0352.
 * Firing the chip at the nominal threshold republishes the ranking DEC-005 refused;
 * firing it at the corrected one makes every card assert a negative result, which is a
 * stronger claim still. So the card states two rates with two denominators and the reader
 * does the comparison. The gap in the numbering is deliberate: a reader comparing this
 * union against the design document should see where a chip was removed rather than a
 * silent renumbering.
 */
export type PackVerdict =
  NoCodeVerdict | ClaimNotReproducedVerdict | BuildRateVerdict | UnmeasuredVerdict;

/** Priority 1 — the pack produces no code when left alone. */
export type NoCodeVerdict = {
  readonly verdict: 'no-code';

  /** Cells in which the pack wrote nothing, over the valid cells it was given. */
  readonly silent: number;
  readonly n: number;
};

/** Priority 2 — the pack's own published figure falls outside the measured interval. */
export type ClaimNotReproducedVerdict = {
  readonly verdict: 'claim-not-reproduced';
  readonly metric: string;
  readonly claimed: number;
  readonly low: number;
  readonly high: number;
};

/**
 * Priority 3 — the pack produces code, and this is how much of it builds.
 *
 * Baseline's counts ride along rather than being fetched separately, so a chip cannot
 * render one rate without the other. There is no percentage field on purpose: a consumer
 * that wants a rate has to divide, which means it is holding the denominator at the
 * moment it renders the numerator (AC-3 by construction).
 *
 * **Both populations, or neither.** `builds` counts frontend cells, graded by whether the
 * repository's own build passed, and it always did — every build-graded cell in this corpus
 * is a frontend ticket, which the card did not say. The backend counts sit beside them now
 * rather than in a second call, so a consumer holding one domain's rate is holding the
 * other's at the same moment and cannot publish one as though it were the whole.
 */
export type BuildRateVerdict = {
  readonly verdict: 'build-rate';

  /** Frontend cells that built, over frontend cells a gate graded. */
  readonly builds: number;
  readonly n: number;
  readonly baselineBuilds: number;
  readonly baselineN: number;

  /** Backend cells that imported and added no new diagnostic, over backend cells a gate graded. */
  readonly backendPasses: number;
  readonly backendN: number;
  readonly baselineBackendPasses: number;
  readonly baselineBackendN: number;
};

/** Priority 5 — no cells for this pack. Not a rate of zero; the absence of a rate. */
export type UnmeasuredVerdict = {
  readonly verdict: 'unmeasured';
};

/**
 * The fraction of silent cells at which a pack is called silent.
 *
 * From DESIGN.md's chip table, which states the condition as "writes no code in ≥ 80% of
 * cells". It is a threshold on a description, not on an inference — it says what the
 * cells show, not whether the difference from another arm is real.
 */
const SILENT_FRACTION = 0.8;

/** The arm every pack is shown beside. */
const BASELINE_ARM = 'baseline';

/**
 * Counts the cells of one arm that the frontend gate could grade.
 *
 * A cell whose outcome is absent was never graded and is not evidence either way, so it
 * is skipped rather than counted as a failure — the same rule `rate_table` follows in
 * `bench/harness/fisher.py`, kept identical on purpose so the two halves of this project
 * cannot answer the same question differently.
 *
 * Unchanged by PDX-005, deliberately. This is the rule the catalogue has published since
 * PDX-004 and the figures it produces do not move; what moves is that the card now says
 * which population they are over. `build` is the frontend gate and no backend cell records
 * one, so this counts frontend cells whether or not it says the word — which is exactly
 * the silence AC-2 fixes, and fixing the disclosure is not the same as re-grading the
 * corpus.
 */
const buildCounts = ({ cells, arm }: { cells: readonly Cell[]; arm: string }) => {
  let builds = 0;
  let n = 0;

  for (const cell of cells) {
    if (cell.arm !== arm) continue;

    // Code-producing cells only, as the chip table states the condition. A cell in which
    // the agent wrote nothing has no code to build, and counting it as a build failure
    // would fold "produced nothing" into "produced something broken" — two different
    // findings, and the first one already has its own verdict.
    if (cell.wroteCode !== true) continue;

    if (cell.build === undefined || cell.build === null) continue;

    n += 1;
    if (cell.build === true) builds += 1;
  }

  return { builds, n };
};

/**
 * Counts the cells of one arm that the backend gate could grade.
 *
 * Domain-scoped, and it has to be: `passes` is recorded on frontend cells too, so counting
 * the field alone would report a backend rate over a population that is mostly frontend —
 * 12/35 where the backend tickets say 7/15. The grader in `grade.ts` reads each cell's own
 * domain, which is the only place that distinction is written down.
 */
const backendCounts = ({ cells, arm }: { cells: readonly Cell[]; arm: string }) =>
  domainSummary({ cells, arm, domain: 'backend' });

/**
 * Derives what the catalogue may say about one pack.
 *
 * Pure, and total over the verdicts it can return: every input yields a member of the
 * union, so a card can never be asked to render nothing. Nothing here is authored — each
 * field is a count taken off the cells it was given, which is what lets DATA-01 hold at
 * the component boundary: a chip renders fields of this object or it renders nothing.
 *
 * `claims` is optional and empty on the live corpus; see {@link PackClaim}.
 */
export const verdictFor = ({
  packId,
  cells,
  claims = [],
}: {
  packId: string;
  cells: readonly Cell[];
  claims?: readonly PackClaim[];
}): PackVerdict => {
  const valid = cells.filter((cell) => cell.arm === packId && cell.valid === true);

  if (valid.length === 0) {
    return { verdict: 'unmeasured' };
  }

  // Priority 1. Detection precedes claim verification: "it does nothing unattended" is
  // the fact that decides an install on its own, while grading the advertising of work
  // that does not exist tells a reader less.
  const silent = valid.filter((cell) => cell.wroteCode === false).length;

  if (silent / valid.length >= SILENT_FRACTION) {
    return { verdict: 'no-code', silent, n: valid.length };
  }

  // Priority 2.
  const claim = claims.find((entry) => entry.packId === packId);

  if (claim !== undefined && (claim.claimed < claim.low || claim.claimed > claim.high)) {
    return {
      verdict: 'claim-not-reproduced',
      metric: claim.metric,
      claimed: claim.claimed,
      low: claim.low,
      high: claim.high,
    };
  }

  // Priority 3. Baseline's counts come from the same cell set the pack's do, so the two
  // rates on a card are always over the same corpus.
  const pack = buildCounts({ cells, arm: packId });
  const baseline = buildCounts({ cells, arm: BASELINE_ARM });
  const packBackend = backendCounts({ cells, arm: packId });
  const baselineBackend = backendCounts({ cells, arm: BASELINE_ARM });

  return {
    verdict: 'build-rate',
    builds: pack.builds,
    n: pack.n,
    baselineBuilds: baseline.builds,
    baselineN: baseline.n,
    backendPasses: packBackend.hits,
    backendN: packBackend.n,
    baselineBackendPasses: baselineBackend.hits,
    baselineBackendN: baselineBackend.n,
  };
};

/** The same ratio as a whole-number percentage, for callers assembling their own phrase. */
export const percentOf = ({ hits, n }: { hits: number; n: number }): number => {
  if (n <= 0) {
    throw new RangeError(`a percentage needs a denominator, got n=${String(n)}`);
  }

  return Math.round((hits / n) * 100);
};
