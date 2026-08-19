# PDX-023 — registry: a listing states whether it installs, and the claim is measured

- Status: TODO
- Created: 2026-08-19

## 1. Goal

On 2026-08-18 the upstream `caveman` repository added an `agents` array to its
`.claude-plugin/plugin.json` (commit `902eba3`, fixing its own issue #855). The Claude
Code CLI rejects that field — `Validation errors: agents: Invalid input` — on the version
this project measures with (2.1.233) and on the current one (2.1.234) alike, so a pack
this catalogue lists stopped installing, and `main` has been red since. The install proof
caught it within a day, which is the scenario working exactly as its own comment says it
should: "a listed pack that stops installing is a broken listing."

Two facts follow, and the second is the larger one.

First, the catalogue has no way to say this. A listing carries a measured build rate and
an install button, and nothing between them can express "this pack does not currently
install" — so the only options today are a red gate forever or a green gate that lies.

Second, **the install button does not hand the reader the artifact the figures describe.**
`packages/registry/attribution/caveman/source.json` fixes the pack at commit `27d5a39`,
read 2026-08-17; `marketplace.json` installs `JuliusBrussee/caveman` at HEAD. Those were
the same artifact for one day. A catalogue whose premise is that a claim is worth what its
receipt is worth cannot publish a rate about one commit and install another, and this
ticket is where that gap stops being invisible.

## 2. Scope

### Allowed
- `packages/registry/**` — the installability record, its schema, and the manifest it emits
- `packages/data/**` — only if the record type belongs there
- `scripts/**` — the recorder that performs the installs, and the reproduction gate the
  golden set replays (a golden case can only replay a gate that lives here)
- `docs/WORKFLOW.md` — the new gate's row
- `tests/e2e/PDX-003-the-hub-installs.sh` — AC-5 becomes an assertion over every listing
- `tests/e2e/PDX-023-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision entry; `CLAUDE.md` if SRC-01's text needs the new fact

### Not Allowed
- Delisting `caveman`, or any pack, to make a gate green
- Weakening AC-5 so that a failed install can pass
- `bench/**` — no re-measurement
- Pinning the install source to a mutable tag and calling it the measured version

## 3. Acceptance Criteria

- [ ] AC-1: every listed pack carries an installability record — the CLI version used, the
      date, the upstream commit at the attempt, and, when it failed, the verbatim error.
      No field is hand-typed: the record is written by a script that performs a real
      `claude plugin marketplace add` + `claude plugin install` in a scratch
      `CLAUDE_CONFIG_DIR`.
- [ ] AC-2: the e2e's AC-5 asserts **every** listing, not the first one: a pack recorded as
      installable must install, and a pack recorded as blocked must fail **with the
      recorded error signature**. Any other outcome — including a blocked pack that now
      installs — FAILS. Marking a pack blocked must not be a way to make a red gate green,
      and this criterion is what makes that structurally true.
- [ ] AC-3: **the reader-facing half is PDX-024, and this is why.** `main` at 62d76dd
      has no `packages/site` — the site exists only on the unmerged PDX-004 branch, whose
      own CI is red because of the incident this ticket fixes. Making the site display a
      precondition of un-redding `main` would make the two tickets wait on each other, so
      the split is a sequencing fact rather than a scope preference. PDX-024 carries the
      card state, the counts line, the measured commit in the install dialog, and the
      disclosure that the command installs upstream HEAD — which may differ, because the
      marketplace's `github` source resolves `ref` as a git branch and a full commit SHA
      fails with "Remote branch ... not found in upstream origin" (measured). This ticket
      records the fact; PDX-024 publishes it. Until then the fact is in the repository and
      not on the site, and that gap is stated here rather than left to be discovered.
- [ ] AC-4: a golden case plants an installability record whose claimed failure does not
      reproduce and asserts the gate BLOCKs — the dodge in AC-2, pinned.
- [ ] AC-5: `./scripts/verify.sh` stays green and the full regression returns to green on
      `main`, with `caveman` listed and its figures and attribution intact rather than
      removed. What the record says on landing day is whatever the recorder measures that
      day: the assertion is that the record exists and reproduces, not that it says
      `blocked` — upstream may heal, and a criterion that forbids that would be a
      criterion asking the world to stay broken.

## 4. Edge Cases & Error Handling

- The network is unavailable → the scenario FAILS rather than skipping; an unproven
  install is not a pass (the existing AC-5 comment, kept).
- A pack's upstream fixes itself between the record and the run → AC-2's "blocked pack
  that now installs" branch fires, and the record is refreshed rather than the gate
  loosened.
- The error text changes wording but not cause → the signature matched is the validation
  field and the failing manifest key, not the whole string, so a reworded CLI message does
  not read as a different defect. The chosen signature must be written down.
- Every pack blocked at once → the page must not render as an empty catalogue; the state
  is per-listing and the counts say how many.

## 5. E2E Mapping

- `tests/e2e/PDX-003-the-hub-installs.sh` — AC-2, extended from one pack to all
- `tests/meta/cases/<n>-registry-installability-*.sh` — AC-4
- `tests/e2e/PDX-023-the-record-reproduces.sh` — the recorder's own proofs, run offline
  against a planted `claude` shim: a record it cannot classify is refused rather than
  approximated, and a record whose claimed failure does not reproduce is caught. An earlier
  draft of this section declared that this ticket ships no scenario of its own, on the
  argument that its assertions live in PDX-003's rewritten AC-5. That was wrong in a way
  worth recording: `check-test-case.sh` globs by ticket id and `test-loop.sh --red` needs
  this ticket's own scenario to FAIL before implementation, so the declaration would have
  made stages 4 and 5 unrunnable — a ticket cannot opt out of the TDD gate by describing
  the absence nicely
- PDX-024 carries the site scenario

## 6. References

- Upstream `JuliusBrussee/caveman@902eba3` (2026-08-18) and its issue #855
- `packages/registry/attribution/caveman/source.json` — commit `27d5a39`, read 2026-08-17
- DEC-011 (a recorded manifest needs the commit that fixes it), SRC-01, CLAIM-01
- CI run 32191050962, the first red `main`-lineage e2e caused from outside this repository
