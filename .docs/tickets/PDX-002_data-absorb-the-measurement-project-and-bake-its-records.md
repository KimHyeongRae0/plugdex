# PDX-002 — Absorb the measurement project and bake its records

- Status: TODO
- Created: 2026-08-17

## 1. Goal

Fold the standalone measurement repository (`does-it-compile`) into plugdex as
`bench/`, with its git history intact, and add `packages/data` — the typed, baked
records the site and the registry both read. After this ticket there is one repository,
one history, and one place a published figure can be traced to; DATA-01 becomes
checkable rather than aspirational, because the fingerprint and the page that renders it
are versioned together.

## 2. Scope

### Allowed
- `bench/` — the measurement project imported by `git subtree add`, paths and history preserved
- `packages/data/` — the first workspace package: typed loaders over `bench/data/`
- root workspace manifests — `package.json`, `pnpm-lock.yaml`: admitting the first package
  is what takes `verify.sh` out of empty-workspace mode, so they are in scope
- `README.md` — AC-7 requires it; the original scope omitted it while an AC demanded it
- `scripts/check-structure.sh` — ST-07 already admits `bench`; adjust only if the import needs it
- `tests/e2e/PDX-002-*.sh`, `tests/meta/cases/` — the scenario and any golden case this adds
- `DESIGN.md`, `CLAUDE.md` — layout sections, if the import changes them

### Not Allowed
- Squashing, rebasing, or re-authoring the imported history. The `PREREGISTRATION-2.md`
  commit timestamp (2026-08-16 08:37:16 +0900) precedes the runs it predicts (09:27
  onward); that ordering is the evidence the preregistration is real, and a rewrite
  destroys it
- Copying the preserved cell workspaces (~10 GB). Only the published subset moves
- Changing any recorded number. This ticket moves records; it does not re-measure
- Deleting the source repository. It is archived after the import, never removed

## 3. Acceptance Criteria

**Record universe (fixes the ambiguity in the first draft of AC-3).** The imported
`bench/data/runs/` holds three schemas, and only one of them is a fingerprinted record:

| Path | Schema | Count | In `packages/data`? |
|---|---|--:|---|
| `bench/data/runs/*.acceptance.json` | `{run, env, cells}` | 8 | **Yes.** These carry `env.npm_fingerprint` |
| `bench/data/runs/*.results.json` | runner output | 9 | **No.** No fingerprint field; the runner gained that stamp after these were written |
| `bench/data/gate-limits.json` | probe results | 1 | **No.** A third schema, not a run, and **not in `runs/`** — `data/runs/` holds exactly 17 files, all acceptance or results |

"Published record" below means an acceptance record. Cost and token figures live only in
`results.json`, so the first ticket that needs them must resolve how a fingerprint-less
file satisfies DATA-01; that is named here so the contradiction is inherited explicitly
rather than discovered later.

- [ ] AC-1: the import is taken from the **current** source tip, and its history arrives
      whole. At least four commits are reachable — `63735e6`, `869b7de`, `5d3ba47`,
      `d63ff3b` — with their original author dates. Asserted through the graft merge's
      second parent, not `git log -- bench/`: `git subtree add` grafts commits whose own
      trees hold files at the root, so a pathspec-filtered log correctly shows only the
      merge.
      **Staleness is asserted semantically, not only by count.** A clone still at
      `5d3ba47` would satisfy every other criterion while silently dropping the
      `PREREGISTRATION.md` correction that says the fingerprint fixes postdate the
      published runs — the exact provenance statement this ticket exists to preserve. The
      scenario therefore also requires that sentence to be present in the imported tree,
      which survives future commits in a way a pinned SHA would not
- [ ] AC-2: the `PREREGISTRATION-2.md` commit date is strictly earlier than the earliest
      round-two run file, both sides compared in `+0900`, the timezone every timestamp
      here is recorded in.
      **Round-two membership is derived, not globbed, and the derivation is over run ids
      rather than paths.** A run id is the `YYYYMMDD-HHMMSS` prefix of a filename; a run
      is round two if and only if its id is absent from the set of run ids in the
      preregistration commit's tree. Two weaker derivations were tried and rejected:
      a `20260816-*` date glob sweeps in `20260816-010513` and `20260816-020247`, which
      are round-one runs recorded before that commit; and "files introduced by a later
      commit" misclassifies `20260815-225842-frontend-withdrawn-different-prompt` and
      `20260816-020247-frontend`, which are round-one files that a later commit renamed.
      Only the run-id set difference yields the correct six
- [ ] AC-3: `packages/data` exports every acceptance record with its `npm_fingerprint`,
      and `npm_fingerprint` is a required field of the record type, so a record without
      one fails typecheck rather than surfacing at render time
- [ ] AC-4: every `bench/data/runs/*.acceptance.json` carries the same fingerprint
      (`4b140e75d7dc1828`); a file with a different one is reported, not silently mixed.
      **Known limit, deferred deliberately**: the withdrawn run
      (`20260815-225842-frontend-withdrawn-different-prompt`) carries that same
      fingerprint, because it was withdrawn for a different prompt and the fingerprint
      encodes only the environment. The loader therefore cannot distinguish withdrawn from
      live data; that distinction is CLAIM-01's job and lands with the withdrawal register
- [ ] AC-5: `./scripts/verify.sh` passes **and its output does not contain the
      empty-workspace warning** — Node steps run for real (typecheck, lint, test, build).
      Asserted, because `verify.sh` also exits 0 while skipping them
- [ ] AC-6: LANG-01 passes over `bench/` — the imported artifacts are English
- [ ] AC-7: `README.md` describes one project. Anchored to text that exists today: the
      Status paragraph currently reads "The measurement harness and its data exist; the
      catalogue is being built ticket by ticket", which describes two things standing
      apart. After this ticket that sentence is gone and no wording implies a separate
      measurement repository

## 4. Edge Cases & Error Handling

- Import brings root files (`README.md`, `PREREGISTRATION.md`) that collide with ours →
  the subtree prefix keeps them under `bench/`, so no root file is overwritten; the
  structure gate's root whitelist is unchanged
- A run file whose fingerprint differs from the rest → surfaced as a typed
  `MixedEnvironment` error at load, never averaged in. This is the exact failure that
  produced instrument failure 15
- The workspace stops being empty, so `verify.sh` leaves empty-workspace mode → covered
  by AC-5; the Node steps must actually pass, not skip

## 5. E2E Mapping

- `tests/e2e/PDX-002-records-are-traceable.sh` — one assertion per acceptance criterion:
  the imported history survived with original dates (AC-1); the preregistration commit
  precedes the earliest *derived* round-two run file (AC-2); the loader refuses a
  synthetic fingerprint-less record (AC-3); every acceptance file shares one fingerprint
  (AC-4); `verify.sh` output carries no empty-workspace warning (AC-5); `check-language.sh`
  passes with `bench/` present (AC-6); the two-projects sentence is gone from README (AC-7)

## 6. References

- REF-01 required: `acceptance.json` · `PREREGISTRATION` · `gate-limits`
- `DESIGN.md` §4.2 — the three questions the records have to answer
- `docs/WORKFLOW.md` §3.1 — DATA-01, the rule this ticket makes enforceable
