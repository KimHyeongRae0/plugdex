# PDX-025 — site: the methodology page

- Status: TODO
- Created: 2026-08-19

## 1. Goal

A reader can see our numbers and cannot see how they were produced. Every benchmark site
worth trusting answers that in one place: what a single measurement is, what was fixed,
what varied, how many repetitions, what was thrown away and why. Ours answers it in
`bench/REPRODUCE.md`, `bench/PREREGISTRATION*.md` and in the environment fingerprint on
every record — none of which the site links to or renders.

This ticket publishes what the repository already holds. It measures nothing new. The
absence is the whole defect: a catalogue whose pitch is "a claim is worth what its receipt
is worth" currently ships the claims and keeps the receipts in a directory.

## 2. Scope

### Allowed
- `packages/site/**` — the methodology route and the navigation entry that reaches it
- `packages/data/**` — reading the environment facts off the records, with tests
- `tests/e2e/PDX-025-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision this ticket takes

### Not Allowed
- `bench/**` — no re-measurement and no rewriting of the preregistrations
- Any environment fact typed into the page rather than read from a record (DATA-01)
- Claiming a control this project did not exercise — see AC-4

## 3. Acceptance Criteria

- [ ] AC-1: the page states what one cell is, in the terms `bench/REPRODUCE.md` already
      uses: one headless Claude Code session in an isolated copy of a seeded repository,
      with the workspace preserved so grading can be re-run offline. The invocation shape is
      shown.
- [ ] AC-2: the environment table is **read from the records, not typed**. Every value is
      derived at build time and every one of these is asserted to be identical across all
      ten runs, which is the fact worth publishing: agent `Claude Code CLI 2.1.233`, runtime
      `node v22.14.0`, dependency-tree fingerprint `4b140e75d7dc1828` over 256 installed
      packages. If a future run disagrees, the page shows the disagreement rather than the
      first value.
- [ ] AC-3: the two conditions are defined side by side with what differs between them —
      `blocked` (Bash disallowed, a no-run instruction appended) and `as-shipped` (Bash
      allowed, ticket only) — and each carries its run count (7 and 3) and its cell count.
      The page states that they are never averaged, and links the measured consequence: the
      per-cell economics differ by roughly 3-4x between them.
- [ ] AC-4: **what we did not control is stated as plainly as what we did.** Temperature,
      max output tokens and system prompt are the CLI's defaults and were not set by this
      project; there is no contamination analysis; the two models are named with their exact
      ids (`claude-haiku-4-5-20251001` on 8 runs, `claude-sonnet-4-6` on 2) and the page says
      the corpus is not balanced across them. A reviewer must be able to check each of these
      sentences against the records or the harness.
- [ ] AC-5: repetitions are reported as measured rather than as intended: 3 repetitions for
      141 of the 164 measured combinations, 1 for 22, 2 for 1. The page says why the ragged
      ones exist rather than rounding them to "three".
- [ ] AC-6: exclusions are on the page — the one withdrawn run with its reason and date
      (CLAIM-01), and the invalid cells with their dominant cause (74 of 83 are one session
      limit hit mid-run, clustered on frontend tickets).
- [ ] AC-7: preregistration precedence is shown as a fact a reader can verify, not asserted:
      the page links the preregistrations and states that the imported history makes their
      authorship provably earlier than the runs they predict, naming the command that shows
      it.
- [ ] AC-8: every claim on the page is either derived from a record at build time or links
      to the file that contains it. A prose sentence carrying a figure that is neither is a
      violation of this criterion.
- [ ] AC-9: DEV-01 — real browser, 360px reflow, dark mode, and the environment table
      readable at 360px without the page body scrolling sideways.

## 4. Edge Cases & Error Handling

- The records disagree about an environment value → the page renders both with their run
  ids. Rendering the first one and calling it "the environment" is the defect this
  criterion exists to prevent.
- A record carries a value that is a local absolute path → it is not rendered. The
  `python_gate` field currently holds a developer's home directory, which is a fact about a
  machine rather than about the measurement, and publishing it would leak a path while
  telling a reader nothing. Recorded here rather than silently skipped.
- A future run adds a third condition → the page derives the condition list from the
  records, so it appears without an edit.

## 5. E2E Mapping

- `tests/e2e/PDX-025-the-methodology-is-derived.sh` — AC-1 through AC-8 over built output,
  with a planted-record fixture proving AC-2's disagreement path and the absolute-path
  refusal
- `tests/e2e/PDX-025-the-methodology-looks-right.sh` — AC-9

## 6. References

- `bench/REPRODUCE.md`, `bench/PREREGISTRATION.md`, `-2`, `-3`, `bench/DERIVATIONS.md`
- `artificialanalysis.ai/methodology/intelligence-benchmarking` — the disclosure shape this
  page follows: repetitions per evaluation, fixed parameters, the code environment, retry
  and exclusion handling, and a limitations section. What it discloses and we cannot is
  noted in AC-4; what we disclose and it does not — one dependency fingerprint identical
  across every run, and every raw cell published — is the reason this page is worth having
