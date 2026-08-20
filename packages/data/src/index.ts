/**
 * `@plugdex/data` — the typed reading of the measurement records in `bench/`.
 *
 * Every figure the site and the registry publish comes from here. Nothing in this
 * package computes a statistic that is not already in a record; it parses, it refuses
 * what it cannot trace, and it stops there.
 */

export {
  loadAcceptanceRecords,
  parseAcceptanceRecord,
  MalformedRecordError,
  MissingFingerprintError,
  MissingEnvironmentAuditError,
  MissingRegimeError,
  UnknownRegimeError,
  MixedEnvironmentError,
  UnreasonedWithdrawalError,
} from './load.js';

export { verdictFor, percentOf } from './verdict.js';
export { corpusInventory, MissingFixtureError, readFixture, separationTier } from './aggregate.js';
export type { CorpusInventory, CorpusShape, Fixture, SeparationTier } from './aggregate.js';

export { gradeCell, domainOf, graderLabel, stateLabel } from './grade.js';

export type { CellState, Domain } from './grade.js';

export {
  armOrder,
  armSummary,
  formatCellLabel,
  cellGrid,
  domainSummary,
  invalidByTask,
  rateFraction,
  taskOrder,
  taskSummary,
} from './aggregate.js';

export type {
  ArmSummary,
  CellGrid,
  CellMark,
  GridSquare,
  GridTotals,
  InvalidByTask,
  RateSummary,
  TaskSummary,
} from './aggregate.js';

export {
  axisTicks,
  formatAbsent,
  formatMeasured,
  formatCountOverCount,
  formatDomainLabel,
  formatDenominator,
  formatGradedCells,
  formatIntervalPercent,
  formatLoc,
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

export type { AxisTick, Interval, Population } from './stats.js';
export { formatCoverage, SCOPE_WITHDRAWAL } from './stats.js';
export type { ClaimWithdrawal } from './stats.js';

export {
  loadEconomics,
  measuredOrZero,
  MalformedResultsRecordError,
  OrphanResultsRecordError,
} from './economics.js';

export type { ArmEconomics, Economics, TokenShares } from './economics.js';

export { paretoFrontier } from './pareto.js';

export type { ParetoPoint } from './pareto.js';

export type {
  AcceptanceCorpus,
  AcceptanceRecord,
  Cell,
  InvalidReason,
  Regime,
  RunEnv,
  TypecheckReason,
  Withdrawal,
} from './schema.js';

export type {
  BuildRateVerdict,
  ClaimNotReproducedVerdict,
  NoCodeVerdict,
  PackClaim,
  PackVerdict,
  UnmeasuredVerdict,
} from './verdict.js';
