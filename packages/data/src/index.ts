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
  MixedEnvironmentError,
  UnreasonedWithdrawalError,
} from './load.js';

export type {
  AcceptanceCorpus,
  AcceptanceRecord,
  Cell,
  InvalidReason,
  RunEnv,
  TypecheckReason,
  Withdrawal,
} from './schema.js';
