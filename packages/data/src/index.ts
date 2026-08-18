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

export { verdictFor, formatRate, percentOf } from './verdict.js';

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
