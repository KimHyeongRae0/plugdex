# PDX-003 — Pack entries, marketplace generation, and SRC-01

- Status: DONE
- Created: 2026-08-17

## 1. Goal

Give plugdex its machine face. `packages/registry` holds one hand-curated `PackEntry`
per listed pack and generates `.claude-plugin/marketplace.json` from those entries, so
`claude plugin marketplace add` followed by `claude plugin install <pack>@plugdex`
installs a working pack from its author's own repository. SRC-01 becomes enforceable
here: an entry with no upstream link, no named author, or no recorded listing provenance
is a BLOCK, not a warning.

The hub function is the product's premise. If installation does not work end to end,
the positioning is dead — so this ticket proves it on a clean marketplace rather than
assuming it until launch.

## 2. Scope

### Allowed
- `packages/registry/` — the entries, the generator, its tests
- `.claude-plugin/marketplace.json` — generated output, committed so it is diffable
- `scripts/check-src.sh` — the SRC-01 gate
- `scripts/verify.sh` — one new step for SRC-01
- `tests/meta/cases/` — golden cases for the SRC-01 gate (GATE-01: a gate without a
  planted violation is untested)
- `tests/e2e/PDX-003-*.sh`
- `DESIGN.md` — decision log entries this ticket produces
- `scripts/check-structure.sh` — `registry` is already a registered package name; adjust
  only if `.claude-plugin/` needs admitting to the known-directory whitelist

### Not Allowed
- Vendoring anyone's pack **content**. Skills, hooks, prompts, and any file a user would
  execute stay in the author's repository; the registry points at it (DEC-004). Copying
  pack content here is out of bounds regardless of license, because it would make plugdex
  a mirror and put us between the author and their users.
  **An attribution manifest is not pack content.** A pack's `.claude-plugin/plugin.json`
  is the author's declaration about themselves — name, repository, license. Recording it
  verbatim under `packages/registry/attribution/` with the upstream commit it was read
  from is what lets a reader check our listing against the author's own words instead of
  trusting us. Vendoring ships someone's functionality; this ships their claim so ours can
  be audited against it. The distinction is recorded as a decision, not assumed
- Listing a pack whose author has asked not to be listed, or whose upstream cannot be
  named. An entry that cannot satisfy SRC-01 is not written with a placeholder — it is
  not written
- Deriving a verdict. `PackVerdict` comes from `packages/data` by a pure function and is
  never hand-typed (DATA-01). This ticket produces `PackEntry` only
- Rendering anything. The catalogue is PDX-004
- Publishing the marketplace, adding it to any account, or announcing it. Generation is
  local; every GitHub-external action needs its own instruction (CR-01)

## 3. Acceptance Criteria

- [x] AC-1: `PackEntry` carries, for every listed pack: a stable `packId`, display name,
      author, upstream repository URL, license, stars recorded with the date they were
      read, an install source, listing provenance, and an opt-out contact. Nothing is
      optional — a field that may be blank is a field SRC-01 cannot enforce
- [x] AC-2: the install source is `{"source": "github", "repo": "owner/repo"}`. The
      `{"source": "git", "url": ...}` form is **not supported** by the installed Claude
      Code and must fail the type, not merely be discouraged.
      **Asserted as a pair, because a negative compile check alone is green before the
      code exists** — a fixture that fails to compile because the module is missing proves
      nothing. The supported fixture must compile AND the unsupported one must fail. Before
      implementation both fail, which is the correct RED
- [x] AC-3: `pnpm --filter @plugdex/registry build` writes
      `.claude-plugin/marketplace.json` deterministically — running it twice produces a
      byte-identical file, and the scenario asserts that rather than eyeballing it
- [x] AC-4: **SRC-01 gate.** `scripts/check-src.sh` BLOCKs an entry missing an upstream
      link, a named author, or a recorded listing provenance. Proven by golden cases in
      `tests/meta/cases/`, one per missing field, replayed by `check-gates.sh`
- [x] AC-5: **the hub actually works.** `claude plugin marketplace add <local path to
      this repo>` accepts our generated manifest, and `claude plugin install <pack>@plugdex`
      produces a pack that appears in `claude plugin list`. Asserted on the listing, never
      on an exit code.
      **This requires network and that is the point.** The install source is
      `{"source": "github", ...}`, so a successful install clones from the author's own
      repository — it proves end-to-end delivery of a real pack from a real upstream. What
      the local-path marketplace does *not* prove is that our marketplace is addable
      remotely; that needs this repository to be public and belongs to the deploy ticket.
      The report states this limit in these terms rather than the reverse.
      Runs under a scratch `CLAUDE_CONFIG_DIR` so it never mutates the developer's real
      plugin configuration. Fails, with the reason recorded, when `claude` is absent, and
      fails on a network error — because a listed pack that no longer installs is a broken
      listing and this assertion is the thing that catches it. (Corrected in place per
      CLAIM-01: this clause first read "skips loudly ... only when `claude` is absent". The
      shipped scenario fails instead, which is strictly stronger, and the report's §8
      adjudication concluded the ticket's wording was the thing that was wrong. The AC now
      states what the gate actually enforces.)
- [x] AC-6: `packId` joins to `packages/data`. Every arm name that appears in the
      acceptance corpus and is not `baseline` either has a `PackEntry` or is listed in an
      explicit, commented exclusion set. An arm that is measured but unlisted, with no
      stated reason, is a BLOCK — that is how a measured pack silently vanishes from the
      catalogue
- [x] AC-7: `verify.sh` runs the SRC-01 gate, and `check-gates.sh` still catches every
      previously planted violation (no regression in the golden set)

## 4. Edge Cases & Error Handling

- An entry with a blank author → SRC-01 golden case → BLOCK
- An entry whose upstream is a bare owner/repo with no resolvable URL → SRC-01 golden
  case → BLOCK
- Two entries sharing a `packId` → unit test → generation throws rather than emitting a
  marketplace whose last-writer wins
- A pack with two `plugin.json` files → one measured pack ships a stub at the repository
  root and its real manifest under `.claude-plugin/`. Reading the wrong one yields a
  silently empty author. `.claude-plugin/plugin.json` is the canonical path and reading a
  root-level manifest is an error, not a fallback → unit test
- An arm measured in `packages/data` with no `PackEntry` and no exclusion → e2e AC-6
- `ponytail+superpowers` — a combination arm, not a listable pack → the exclusion set,
  with the reason written next to it rather than inferred
- Regenerating with no source change → e2e AC-3 asserts byte-identical output
- An author asks for removal after listing → not automatable; the opt-out contact field
  and the removal note in `README.md` are what make it answerable. Declared under DEV-01
  in the report, not silently skipped

## 5. E2E Mapping

- `tests/e2e/PDX-003-the-hub-installs.sh` — AC-1 through AC-7. The load-bearing
  assertion is AC-5: a real `claude plugin marketplace add` + `claude plugin install`
  against a local marketplace, asserting an installed pack rather than a zero exit code

## 6. References

- DESIGN.md §1 (two faces, one dataset), §3 (the hub alone is not defensible),
  Reference Map row PDX-003, §8 Phase A
- DEC-004 — the registry points at upstream repositories, never vendors them
- DEC-006 — unmeasured packs are listed and labelled
- DEC-008 — ticket slugs lead with their area
- CLAUDE.md — SRC-01, DATA-01, GATE-01, CR-01
- PDX-002 — `packages/data`, the join source for AC-6
