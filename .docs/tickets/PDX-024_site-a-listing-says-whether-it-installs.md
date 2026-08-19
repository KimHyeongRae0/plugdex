# PDX-024 — site: a listing says whether it installs

- Status: TODO
- Created: 2026-08-20

## 1. Goal

The repository knows something the site does not say. `packages/registry/installability/`
holds a generated record per listing, written only by a real install into a scratch config
directory, and `caveman.json` records `"outcome": "blocked"` with the verbatim CLI error —
while `README.md:70` and `CLAUDE.md:18` tell a reader that
`claude plugin marketplace add plugdex` "makes every listed pack installable by name" and the
site's card and install dialog say nothing at all. PDX-023 made the fact exist and stated in
its own AC-3 that publishing it was a separate ticket. This is that ticket, and it has been
cited as a dependency in eleven places — including `DESIGN.md:174`, which pins it **ahead of
PDX-014 (deploy)** — without ever being written. Deploying a catalogue whose front door
advertises an install that its own committed receipt says fails is the one thing this project
exists to object to.

This ticket publishes the record. It does not re-run an install, does not change what INST-01
checks, and does not remove a blocked pack from the catalogue — the measurement happened and
stays published (CLAIM-01); what is added is that the reader is told the current upstream does
not install.

## 2. Scope

### Allowed
- `packages/site/**` — the card state, the counts line, the install dialog's measured-commit
  and upstream-HEAD disclosure
- `packages/registry/src/index.ts` — only if an export needed for rendering is missing;
  `installabilityFor` and `loadInstallabilityRecords` already exist
  (`packages/registry/src/installability.ts:160`, `:128`)
- `tests/e2e/PDX-024-*.sh`
- `README.md`, `CLAUDE.md` — the two sentences that currently overstate installability

### Not Allowed
- Running an install, or writing anything under `packages/registry/installability/`. Those
  records are written by `scripts/record-installability.sh` and by nothing else
- Changing INST-01 or any of INST-01a–f. This ticket renders the record; it does not decide
  what makes one valid
- Removing, hiding, or down-ranking a blocked listing's card, figures or attribution. DEC-021
  is explicit that a blocked pack keeps all three
- Changing the verdict chip. Install state is a delivery fact, not a measurement verdict —
  `caveman` keeps its priority-2 chip (DESIGN.md, PDX-023 step 9)
- Pinning the install command to the measured commit. DEC-022 records that this is not
  available: the marketplace `github` source passes `ref` to git as a **branch**, and a full
  SHA fails with `fatal: Remote branch ... not found in upstream origin`. The gap is
  disclosed, not closed
- Any figure typed rather than derived (DATA-01)

## 3. Acceptance Criteria

- [ ] AC-1: **every card states its install state**, derived from `installabilityFor` rather
      than from a list in site source, and a listing with no record renders as an explicit
      absence rather than as installable. The default on missing data must not be the
      flattering one.
- [ ] AC-2: **a blocked listing says so where the install action is**, not only somewhere on
      the page. A reader who reaches the install dialog without scrolling past a banner must
      still be told. The recorded `verbatim` CLI error is available to read — a claim of
      breakage with the receipt attached, the same standard every figure on this site meets.
- [ ] AC-3: **the counts line is derived**: how many listings install, how many are blocked,
      as of when. `attemptedAt` is in each record; the line names the date of the oldest
      attempt it summarises, because a mixed-age summary presented as current is a figure
      without its denominator.
- [ ] AC-4: **DEC-022's gap is disclosed in the install dialog**: the button installs upstream
      **HEAD**, the figures describe the measured commit, and those may differ. Both the
      measured commit and the recorded `upstreamHead` are shown, and for a pack that installs,
      the `installedVersion` the CLI printed.
- [ ] AC-5: **`README.md:70` and `CLAUDE.md:18` stop overstating.** Both currently say the
      marketplace makes *every* listed pack installable by name; `caveman` is listed
      (`.claude-plugin/marketplace.json:9`) and blocked. Corrected under CLAIM-01 with the
      previous wording, its date and its cause kept readable. *(This AC overlaps PDX-033
      AC-1.1 by design — whichever ticket lands first satisfies it, and the second one's
      report records that it was already closed rather than doing it twice.)*
- [ ] AC-6: **an e2e asserts the states over built output, both directions**, and fails on an
      empty selection (ASSERT-01): a blocked listing renders its blocked state and its
      verbatim error, an installing listing renders neither, and a scenario that selects zero
      cards FAILs rather than passing vacuously. This project has produced the vacuous-pass
      shape seven times.
- [ ] AC-7: **the site never claims an install state it did not read.** A grep over site
      source finds no hardcoded pack id in an install-state expression — the same
      source-side discipline DATA-01 applies to figures, applied to this fact, because a
      hand-maintained list of which packs work is exactly how the site would drift from the
      record it is supposed to publish.

## 4. Edge Cases & Error Handling

- A listing has no installability record → AC-1's explicit absence. `loadInstallabilityRecords`
  throws `MissingInstallabilityError`; the page must not render "installs" on a throw.
- A record is malformed → `MalformedInstallabilityError` is a separate class from the missing
  case (PDX-023 built two names so a test can prove which fired); the scenario asserts which.
- A blocked pack starts installing again → not this ticket's to detect (INST-01c FAILs the
  gate), but the page must not cache a stale state: the render reads the record at build time
  and the counts line names its date, per AC-3.
- All five listings install → the counts line still renders, with zero blocked, rather than
  disappearing. A disclosure that vanishes when the news is good is a disclosure a reader
  learns to distrust.
- The blocked card's figures are mistaken for withdrawn → AC-2's wording separates "this
  measurement happened" from "this pack currently installs"; DEC-021 requires both to stay.

## 5. E2E Mapping

- `tests/e2e/PDX-024-a-listing-says-whether-it-installs.sh` — over built output: every card
  carries a state attribute; `caveman` renders blocked with its verbatim error reachable;
  the other four render installing; the counts line re-derives from
  `packages/registry/installability/*.json` including its date; the install dialog carries
  the measured commit, the recorded `upstreamHead` and the HEAD-vs-measured sentence; a
  zero-card selection FAILs the scenario.

## 6. References

- DEC-021 (install state is a generated record; a blocked record must keep failing the same
  way), DEC-022 (the measured artifact and the installed artifact differ, and the gap is
  disclosed), CLAIM-01, DATA-01, ASSERT-01, INST-01a–f
- `.docs/tickets/PDX-023_registry-a-listing-states-whether-it-installs.md` AC-3 — the split
  that created this ticket, and the list of what it inherits
- `.docs/analysis/PDX-023_plan.md` §3 Handover, and step 2 — `installabilityFor` is named
  there as "the API PDX-024 renders from"
- Blocks `PDX-014` (deploy), per `DESIGN.md:174`
- Overlaps `PDX-033` AC-1.1 on the README/CLAUDE sentences
