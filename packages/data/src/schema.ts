/**
 * Types for the acceptance records under `bench/data/runs/`.
 *
 * These describe what the measurement harness actually wrote, not what would be
 * convenient to consume. Where the harness emits a field only for one domain, the
 * field is optional here rather than filled with a default — an invented zero is a
 * number nobody can check (DATA-01).
 */

/**
 * The environment a run was graded in.
 *
 * `npmFingerprint` is required and non-optional on purpose. It is the sha256 prefix of
 * every installed package at grading time, and it is the only thing that distinguishes
 * a comparable run from an incomparable one. Two of this project's instrument failures
 * were undeclared packages silently changing a pass rate, so a record that cannot say
 * which environment produced it is not a record we will render.
 */
export type RunEnv = {
  /** Total installed npm packages at grading time. */
  readonly npmPackages: number;

  /** sha256 prefix over the sorted `name@version` list. The comparability key. */
  readonly npmFingerprint: string;

  /** Packages present on disk that no `package.json` declares. Non-empty means the run is suspect. */
  readonly npmExtraneous: readonly string[];

  /** Installed top-level packages that no manifest declares directly. */
  readonly npmUndeclaredToplevel: number;

  /** Every installed package as `name@version`. */
  readonly npmInstalled: readonly string[];

  /** The Node version the gates ran under. */
  readonly node: string;

  /** Absolute path to the Python interpreter that ran the gate. */
  readonly pythonGate: string;
};

/**
 * The condition a run executed under.
 *
 * `blocked` withheld Bash and appended a write-don't-run instruction; `as-shipped` gave
 * the agent the ticket and nothing else, with Bash allowed. The two are not variants of
 * one setting — they move the baseline build rate from 25% to 73%, so the condition
 * decides what almost every published figure means, and pooling them produces a rate that
 * describes neither. The union is closed on purpose: a near-miss like `Blocked` or
 * `as shipped` is a typo that would move a run between conditions, which is the failure
 * this type exists to make impossible.
 */
export type Regime = 'blocked' | 'as-shipped';

/** Why a cell was excluded from analysis. `null` when the cell is valid. */
export type InvalidReason = string | null;

/** Why the typecheck gate failed, when it did. */
export type TypecheckReason = 'missing-dep' | 'type-error' | null;

/**
 * One cell: one pack, on one task, at one model, for one repetition.
 *
 * Frontend and backend cells carry different gate fields — `typecheck` / `build` for
 * frontend, `import_ok` for backend — so those are optional. `valid` is not: an
 * invalid cell still occupies a slot in the design and dropping it silently would
 * change every denominator.
 */
export type Cell = {
  /** Unique id: `<task>__<arm>__<model>__<rep>`. */
  readonly cell: string;

  /** The ticket the agent was given. */
  readonly task: string;

  /** The pack under test. `baseline` is the no-pack control. */
  readonly arm: string;

  /** The model the cell ran on. */
  readonly model: string;

  /** Repetition index within the cell's condition. */
  readonly rep: number;

  /** False when the cell is excluded from analysis; `invalidReason` says why. */
  readonly valid: boolean;

  /** Present only on invalid cells. */
  readonly invalidReason?: InvalidReason;

  /** `null` on cells that never got far enough to have one. */
  readonly domain?: 'frontend' | 'backend' | null;

  /** How node_modules was provided: a shared fixture or a cell-local install. */
  readonly deps?: string;

  /** Whether the agent produced any code at all. The finding that matters most is a false here. */
  readonly wroteCode?: boolean;

  /** Paths the agent created. */
  readonly newFiles?: readonly string[];

  readonly nFrontendFiles?: number;
  readonly nBackendFiles?: number;

  /** Frontend gate: did the repository's own typecheck pass? */
  readonly typecheck?: boolean;
  readonly typecheckReason?: TypecheckReason;
  readonly typecheckOut?: string;

  /** Frontend gate: did the repository's own build pass? */
  readonly build?: boolean;
  readonly buildReason?: string | null;
  readonly buildOut?: string;

  /** Backend gate: did the delivered module import cleanly? */
  readonly importOk?: boolean;
  readonly importOut?: string;

  /**
   * Backend gate: did the delivered code import and introduce no new diagnostic?
   *
   * Named for what `bench/harness/acceptance.py:390` computes —
   * `bool(be_files and ok_import and not new_diags)` — rather than for what a reader might
   * assume a field called `passes` means. No test suite is executed for a backend cell, and
   * an earlier version of this comment said the delivered tests pass, which claimed a
   * stronger check than the one performed.
   */
  readonly passes?: boolean;

  /** Diagnostics the agent's change introduced, beyond those already present. */
  readonly nNewDiags?: number;
  readonly newDiags?: readonly string[];
};

/**
 * Why a run was pulled out of the default analysis pool, and when that was decided.
 *
 * A withdrawal is a claim about the instrument, so it is recorded rather than performed.
 * The alternative the project used until now was a filename prefix matched in one
 * analysis script, which meant the fact governing every published figure lived where no
 * type could reach it, no gate could check it, and the other half of the codebase could
 * not see it at all — DEC-005, committed a second time. `reason` is required because a
 * withdrawal with no stated reason is a deletion wearing a field.
 */
export type Withdrawal = {
  /** Why the run is not comparable to the others. Never empty. */
  readonly reason: string;

  /** When the withdrawal was decided, ISO 8601 with offset. */
  readonly recordedAt: string;

  /** Where the reasoning is written out, when it is written out somewhere. */
  readonly reference?: string;
};

/** One graded run: its id, the environment it was graded in, and its cells. */
export type AcceptanceRecord = {
  /** The run id — the `YYYYMMDD-HHMMSS` timestamp the harness stamped. */
  readonly run: string;

  readonly env: RunEnv;

  /**
   * The condition the run executed under. Required, and never defaulted.
   *
   * It lived in the filename until PDX-017 — `"as-shipped" in name`, evaluated in one
   * Python function that the TypeScript half of this project could not see. The ten names
   * happened to encode it correctly and nothing checked that they did, which is the same
   * shape as the withdrawal defect one field over (DEC-015, DEC-019). Making it optional
   * with a default would restore exactly that behaviour with somewhere to hide, so a
   * record that does not say is refused rather than assumed.
   */
  readonly regime: Regime;

  readonly cells: readonly Cell[];

  /**
   * Present only on a withdrawn run. Absent means the run is in the default pool —
   * the field is never written as `null` or as an empty object to mean "kept", because
   * a reader has to be able to tell an unwithdrawn run from an unfinished record.
   */
  readonly withdrawn?: Withdrawal;
};

/**
 * A loaded corpus: every record, plus the single fingerprint they all share.
 *
 * There is one fingerprint by construction — {@link MixedEnvironmentError} is thrown
 * otherwise — so consumers can compare across records without re-deriving it.
 */
export type AcceptanceCorpus = {
  readonly records: readonly AcceptanceRecord[];

  /** The environment fingerprint common to every loaded record. */
  readonly fingerprint: string;

  /** Every cell across every record, in load order. */
  readonly cells: readonly Cell[];

  /**
   * Every withdrawn record in scope, whichever withdrawal view was asked for.
   *
   * What was pulled is a property of the corpus, not of the caller's question, so this
   * list does not change between the default and pooled views. A consumer that reports a
   * figure can therefore say what was left out without loading the directory twice, and a
   * corpus that silently dropped a run is distinguishable from one that never had it.
   *
   * A `regime` filter does narrow it, because that option changes which runs are in scope
   * at all rather than how an in-scope run is reported — a blocked-regime figure that
   * disclosed an as-shipped withdrawal would be naming an exclusion from a pool it never
   * described.
   */
  readonly withdrawnRecords: readonly AcceptanceRecord[];
};
