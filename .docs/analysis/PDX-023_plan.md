# PDX-023 Plan — registry: a listing states whether it installs, and the claim is measured

- Ticket: `.docs/tickets/PDX-023_registry-a-listing-states-whether-it-installs.md`
- Author: Fable 5 (Claude Code subagent)
- Date: 2026-08-19 (revised against the amended ticket: site half split to PDX-024; revised again after review round 1 — see §9.0)

## 1. Goal & Context

`main` (62d76dd) is red, and the failure is external: upstream `JuliusBrussee/caveman`
commit `902eba3` (2026-08-18, its fix for its own issue #855) added an `agents` array to
`.claude-plugin/plugin.json`, and the Claude Code CLI rejects that manifest —
`Validation errors: agents: Invalid input`. Measured before this plan and cited as given:
the rejection reproduces on CLI 2.1.233 (the version every `results.json` under
`bench/data/runs/` records under its `claude` key) **and** on 2.1.234, so it is not a CLI
regression and pinning the CLI does not fix it. CI run 32191050962 is the red run.

The install proof (`tests/e2e/PDX-003-the-hub-installs.sh` AC-5) caught this within a
day, which is that assertion working as designed. What the catalogue lacks is a way to
*say* it: a listing today carries a measured verdict and an install button, and nothing
in between can express "this pack does not currently install". The only states available
are a red gate forever or a green gate that lies.

Two measured facts sharpen the design, both taken as given rather than re-derived here:

1. **Exactly one of five listings is blocked.** A real
   `claude plugin marketplace add` + `claude plugin install` was run for all five packs,
   each in a fresh scratch `CLAUDE_CONFIG_DIR`, CLI pinned to 2.1.233, with the same
   HTTPS rewrite the existing scenario uses: caveman BLOCKED (the `agents` validation
   error), karpathy / mattpocock / ponytail / superpowers all INSTALL. The ticket's
   "every pack blocked at once" edge case is hypothetical, not current.
2. **The current AC-5 is order-dependent, and only luck made it useful.** It installs
   `plugins[0]` — the packId-sorted first entry, which happens to be `caveman`
   alphabetically. Had the broken pack sorted second, the gate would be green today with
   a broken listing behind it. That is an argument for asserting every listing that does
   not depend on the caveman incident at all.

There is a second gap the ticket names: **the install button does not hand over the
artifact the figures describe.** `packages/registry/attribution/caveman/source.json`
records commit
`27d5a3981a347890211bb1bf2439e5c821a63bc9`, readAt 2026-08-17; the generated `marketplace.json` install source is
`{"source":"github","repo":"JuliusBrussee/caveman"}` — HEAD. Those were the same
artifact for one day. Closing the gap by pinning is not available: the marketplace
`github` source accepts a `ref` key, but it is passed to git as a **branch** — a full
commit SHA fails with `fatal: Remote branch 27d5a39... not found in upstream origin`
(measured directly). Tags and branches resolve; commit SHAs do not, and the ticket's
Not-Allowed forbids calling a mutable tag "the measured version". So the gap is
disclosed, not closed.

**The split, per the amended ticket's AC-3.** This ticket builds the fact and its
enforcement: a generated, per-pack **installability record** (CLI version, date,
upstream commit at the attempt, verbatim error when blocked) and a gate that requires
every recorded state to **reproduce** — a blocked pack that installs again FAILS, so
"blocked" is never a route to green. Publishing the fact to the reader — card state,
counts line, measured-commit and HEAD-may-differ disclosures in the install dialog — is
**PDX-024**, because `main` at 62d76dd has no `packages/site` and the branch that does
(PDX-004) is red *because of this incident*: making the site display a precondition of
un-redding `main` would make the two tickets wait on each other. The record ships here;
the rendering ships there; §3's Handover subsection names everything PDX-024 inherits so
nothing is lost in the seam.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: steps touch `packages/registry/src/*`,
  `packages/registry/installability/*.json` (new, generated),
  `scripts/record-installability.sh` + `scripts/check-installability.sh` (now
  explicitly Allowed — the amendment this plan's first draft flagged, accepted),
  `docs/WORKFLOW.md`, `tests/e2e/PDX-003-the-hub-installs.sh`,
  `tests/e2e/PDX-023-the-record-reproduces.sh` (named by the ticket's own §5),
  `tests/meta/cases/`, and `DESIGN.md`. `packages/data/**` is NOT touched — §6.5 D1 records why the record does
  not belong there. `packages/site/**` is NOT touched — out of scope per AC-3.
  `CLAUDE.md` is NOT touched: SRC-01's text is about attribution and opt-out and gains
  no new fact from this ticket.
- **Ticket Scope.NotAllowed respected**:
  - **caveman is not delisted** — its entry, measured figures, and attribution all
    stay; the rewritten PDX-003 scenario pins the pack **by name** as listed (the
    `KNOWN_MISATTRIBUTED` precedent), so a quiet delisting fails the gate (AC-5).
  - **AC-5 of PDX-003 is strictly strengthened, never weakened**: the rewritten
    assertion covers every listing instead of the sorted-first one, and a recorded
    failure must *reproduce* — every outcome other than exact agreement with the record
    FAILS, including the blocked-pack-now-installs branch.
  - **Nothing under `bench/**` is touched and nothing is re-measured.** The
    installability record is a registry fact about delivery, not a benchmark figure.
  - **No mutable tag is pinned as the measured version.** No `ref` is emitted at all;
    the HEAD-vs-measured-commit disclosure is PDX-024's to render, with the measured
    reason recorded in the handover.
  - No GitHub-external action (CR-01): marketplace adds are local-path only, the
    recorder runs in a scratch `CLAUDE_CONFIG_DIR`, and the upstream-notification
    question is decided in §6.5 D6 as a recommendation to the user, never an action.

**Sequencing — resolved, no longer a risk.** The first draft of this plan recommended
"merge PDX-004, then rebase" and named a split as fallback. The recommendation was
circular — PDX-004 cannot merge while its CI is red, and its CI is red because of the
incident this ticket fixes — so the fallback is taken: this ticket lands first from
`main` at 62d76dd and un-reds the lineage; PDX-004 then rebases onto a green `main`;
PDX-024 publishes the fact on the site PDX-004 provides. The decision is the ticket's
AC-3, not a plan preference.

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | The record type | `packages/registry/src/schema.ts` | `InstallabilityRecord`: `packId`, `cliVersion`, `attemptedAt` (ISO instant), `upstreamCommit` (full SHA at the attempt, from `git ls-remote <repo> HEAD`), `transport` (`ssh` \| `https`), and `outcome` as a **discriminated union** — `{ outcome: 'installs' }` or `{ outcome: 'blocked'; error: { verbatim: string; signature: { kind: 'manifest-validation'; keys: readonly string[] } } }`. A blocked record without a verbatim error or with empty `keys` is unrepresentable in the type and refused by the reader — an unclassified failure must never look like a classified one. The `installs` variant additionally carries an **optional** `installedVersion`, parsed from `claude plugin list`'s `Version:` line when present (optional because a blocked pack has no version to carry, so it cannot sit on the union). Why it belongs on the record at all: this ticket exists because the artifact the figures describe and the artifact the button installs came apart, and this field is the only one on the record that names the latter |
| 2 | The reader and the join | `packages/registry/src/installability.ts`, `packages/registry/src/index.ts` | `readInstallability({ packId })` reading `packages/registry/installability/<packId>.json` (module-relative, like `ATTRIBUTION_DIR`), throwing `MissingInstallabilityError` on absence and `MalformedInstallabilityError` on shape violations (two names, so a test can prove which fired); `installabilityFor` covering every entry, exported — this export is the API PDX-024 renders from. `entries.ts` is untouched: the join is by `packId` at read time, the same shape the attribution join uses |
| 3 | The recorder | `scripts/record-installability.sh` | AC-1's script. Per pack (or `--all`): fresh scratch `CLAUDE_CONFIG_DIR`, `claude plugin marketplace add <repo root>`, `claude plugin install <pack>@plugdex` with the existing SSH→HTTPS retry, `claude --version`, `git ls-remote https://github.com/<repo> HEAD`. Success additionally verified as the token `<pack>@plugdex` present in `claude plugin list` before an `installs` record is written — an exit code alone asserts nothing (the existing AC-5's own lesson) — and the list entry's `Version:` line, when present, is captured as the optional `installedVersion`. On failure it runs **the shared classifier (step 3a)** over the captured log; **if the classifier yields no signature the recorder refuses to write anything and exits non-zero naming the reason** — fail closed, because a blocked record the gate cannot re-check is a green gate waiting to happen. Output: sorted-keys JSON, 2-space indent, trailing newline, written to temp + `mv` so a death mid-write leaves no partial record. `--out <dir>` override so the scenario can exercise it in a sandbox. Sentinel on every path, including `RECORDED <pack> outcome=... keys=...` naming what it wrote (ASSERT-01) |
| 3a | The shared classifier | `scripts/lib/install-signature.py` | One implementation, two callers — the round-1 fix. Reads an install log, prints `SIGNATURE kind=manifest-validation keys=<sorted,comma-joined>` when it can classify (today: the CLI's `Validation errors:` segment, one key per `<key>: <message>` pair) and exits non-zero printing `UNCLASSIFIED <reason>` otherwise — its "cannot classify" is an output, never silence (ASSERT-01). The recorder (step 3) calls it to write `signature`; the gate (step 5) calls it to verify reproduction, so the two can never disagree about what an error means and the match-width question does not exist. It lives under `scripts/lib/` beside `gate-log.sh` because `check-gates.sh` sandboxes are built by `cp -R scripts` — the whole tree, `lib/` included — so a golden case exercises the same classifier bytes the live gate runs |
| 4 | The records | `packages/registry/installability/*.json` (5 files, generated by step 3, never edited) | One run of `record-installability.sh --all` during stage 6. Expected content per the measured input: four `installs`, caveman `blocked` with `keys: ["agents"]` — expected, not asserted here (PLAN-01); the recorder writes what it measures on the day it runs, and ticket AC-5 is worded so a healed upstream is a different record, not a failed criterion |
| 5 | The gate | `scripts/check-installability.sh` | INST-01, the reproduction check, specified in full below this table; reproduction is judged by the step-3a classifier, never by a pattern of the gate's own. Lives under `scripts/` so `check-gates.sh` sandboxes can replay it. Requires network and a real (or planted) `claude`; it is invoked by the PDX-003 e2e, **not** by `verify.sh` — verify stays offline |
| 6 | AC-5 rewritten | `tests/e2e/PDX-003-the-hub-installs.sh` | The first-pack install is replaced by one invocation of `scripts/check-installability.sh`; the scenario asserts the gate exits 0 AND that its output carries a per-pack sentinel for **every** plugin in `marketplace.json` (count equality, floor ≥ 1), AND that `caveman` is present among the listed entries by name — the anti-delisting pin ticket AC-5 requires. The header comment's contract is updated to its stronger form: a listed pack whose *recorded state* stops reproducing is a broken listing. Missing `claude` and network failure still FAIL loudly — the existing policy, kept verbatim |
| 7 | Golden cases | `tests/meta/cases/` (6 files; numbers derived at implementation — next free after 38) | Each case plants `marketplace.json` + records + a `bin/claude` shim and runs the gate via `GATE='PATH="$PWD/bin:$PATH" scripts/check-installability.sh'` (plant() and the gate run are separate subshells, so PATH rides inside the GATE string). Construction table below — each trips exactly one lettered rule. The dodge case (ticket AC-4) is the one that matters: record says blocked, shim installs fine, gate must BLOCK with INST-01c |
| 8 | Offline shape tests + the ticket scenario | `packages/registry/src/registry.test.ts`, `tests/e2e/PDX-023-the-record-reproduces.sh` | *Unit* (runs inside `verify.sh` via `pnpm test`): every entry joins a record and every record joins an entry (total both ways); blocked records carry non-empty verbatim + non-empty keys; dates parse; `cliVersion` non-empty; each record file re-serializes byte-identically under the recorder's canonical form — a hand-edited record with drifted key order fails, which is DATA-01's "nothing hand-typed" made checkable offline. *Scenario* (thin, fully offline; ticket §5 names this file): asserts the built registry exports the records (node probe, sentinel), proves the recorder behaviourally against planted `bin/claude` + `bin/git` shims in a `mktemp -d` sandbox via `--out` — unclassifiable failure → refuses and writes nothing; `agents` validation failure → blocked record with `keys:["agents"]`; clean install with `<pack>@plugdex` listed → `installs` record, `installedVersion` captured when the shim prints a `Version:` line — and feeds the classifier the round-1 counterexample log directly: `Validation errors: custom-agents: Invalid input` must yield `keys:["custom-agents"]`, not `["agents"]` (the width fix asserted at its source) |
| 9 | Docs and the decision | `DESIGN.md`, `docs/WORKFLOW.md` | DESIGN.md decision log gains the entry (next free number, expected DEC-020 — PDX-004 still holds 016–018 on its branch and now lands *after* this ticket, so the log briefly skips again exactly as DEC-019 did; the PDX-017 precedent, cited in the entry): *a listing's install state is a generated, reproducible record — a blocked record must keep failing the same way, or the gate fails*. WORKFLOW.md §3 gains the INST-01 row and §4 the two script rows. DESIGN.md also notes install state is orthogonal to the verdict-chip priority table (caveman keeps its priority-2 chip; blocked-ness is a delivery fact, not a measurement verdict), and the roadmap names PDX-024 as the publication ticket **and pins it ahead of PDX-014 (deploy)** — the handover's no-live-audience premise, made an ordering rather than an assumption |

**INST-01 — the gate, specified exactly.**

Inputs: `.claude-plugin/marketplace.json`, `packages/registry/installability/*.json`,
`claude` from `PATH`. One scratch `CLAUDE_CONFIG_DIR`, one `marketplace add` from the
repository root (CR-01 — nothing remote is added), then one install attempt per listed
plugin, each captured to its own log. Bash + python3 like the sibling gates; no node
dist required, so a sandbox with planted files exercises the real code path.

Per-pack verdict, all four behavioural branches explicit:

| Record says | Attempt result | Verdict |
|---|---|---|
| `installs` | installs AND the token `<pack>@plugdex` appears in `claude plugin list` | pass |
| `installs` | anything else | **INST-01b** — a recorded-installable pack does not install |
| `blocked` | install FAILS and the classifier yields the recorded signature | pass (the recorded failure reproduces) |
| `blocked` | install SUCCEEDS | **INST-01c** — the dodge: blocked must not be a route to green; the failure message names `./scripts/record-installability.sh <pack>` as the refresh path |
| `blocked` | install fails but the classifier yields a different signature — or none | **INST-01d** — a different defect than the recorded one (or one the classifier cannot name); the record is stale in the other direction |

Structural rules: **INST-01a** — a listed plugin with no record, or a record for no
listed plugin (the join must be total both ways); **INST-01e** — a record the check
cannot act on (unknown `outcome` value, blocked with empty `verbatim` or empty `keys`,
missing required field) BLOCKs rather than being skipped, so a malformed record can
never thin the coverage silently. A failed `marketplace add` is a hard failure before
any per-pack check (our own manifest is broken; no per-pack verdict is meaningful). A
blocked pack must additionally be *absent* — no `<pack>@plugdex` token — from
`claude plugin list`, so a half-installed state passes neither branch; the token is
pinned as `<pack>@plugdex` in both branches because the gate's one shared config dir
accumulates up to five list entries, and a bare-name substring over an accumulated list
is the same defect class the round-1 blocker named. One more sentence the gate's header
carries: `cliVersion`, `attemptedAt`, and `upstreamCommit` are dated snapshot fields
that legitimately drift and are **not** re-verified by the gate — said explicitly so a
reader does not mistake them for checked claims.

**The reproduction check, exactly — one classifier, two callers.** A blocked record's
failure "reproduces" when the fresh install (a) exits non-zero, (b) produces a
**non-empty** log, and (c) `scripts/lib/install-signature.py` — the same classifier the
recorder used to write the record — yields the same `kind` and the same key set
(compared sorted, exact string equality per key; a superset such as `agents`+`hooks` is
a mismatch, not a partial match). The gate carries no match pattern of its own, so the
match-width question stops existing: whatever the classifier calls the fresh failure
either equals the stored signature or it does not, and a fresh failure the classifier
cannot classify is INST-01d, never a pass — the recorder's fail-closed refusal is
thereby the gate's refusal too. This replaces the first draft's `grep -wF` key match,
which review round 1 broke with a counterexample worth recording: `-w` treats
punctuation as a word boundary, so `Validation errors: custom-agents: Invalid input`
*matched* a record with `keys: ["agents"]` (verified by running the grep) — a genuinely
different manifest defect reading as reproduction, the exact green-direction
impersonation D3 rejects. The draft's "`agents` does not match `subagents`" claim was
true for the prefix case and false for the hyphenated-superkey case, and the corrected
behaviour is pinned by its own golden case below. Rewording tolerance now lives in the
classifier alone: today it parses the CLI's `Validation errors:` segment, and a future
phrasing it cannot parse makes it refuse, INST-01d fires, and the gate is red until the
classifier is extended and the record refreshed — the fail-closed direction, and because
both sides share the one implementation, extending it moves recorder and gate together;
they cannot drift apart. The empty capture stays closed by construction (ASSERT-01):
condition (b) plus the classifier's no-silent-verdict contract means silence is never a
signature.

**The CI budget, from the measured number rather than a guess.** Measured basis: one
successful warm install (ponytail, marketplace already added, developer machine,
2026-08-19) took **2 seconds**. The gate performs one marketplace add plus five installs
in a single scratch config dir, so the expected added wall clock is on the order of tens
of seconds, not minutes. The slow case is a cold clone of a large upstream working tree
(caveman's carries dozens of top-level directories), and the measurement was not taken
on the CI runner — both caveats carried into the gate's header comment. **Decision:
assert all five listings, no cap.** At this cost the flake-surface argument buys nothing
worth the coverage it would spend; the old scenario's first-pack pick *was* a cap — an
accidental, order-dependent one — and this ticket removes it. Because nothing is capped,
there is no lost coverage to record anywhere, which is the cleanest way to satisfy "no
silent caps". If the roster ever grows enough for this to hurt (~30 packs per the
PDX-012 roadmap), the cap decision gets its own ticket with its coverage ledger — not a
quiet constant in this gate.

**Golden-case construction — each trips exactly one rule.**

| Case | Plants | Trips | Why the others stay green |
|---|---|---|---|
| the dodge (ticket AC-4) | 1-plugin marketplace, record `blocked` (keys `["agents"]`), shim: `plugin install` exits 0 and `plugin list` shows the pack | INST-01c | join total (a); no `installs` record exists (b); the install did not fail (d); record well-formed (e) |
| recorded-installable fails | record `installs`, shim: install exits 1 printing a clone error | INST-01b | no blocked record (c, d); join total (a) |
| wrong signature | record `blocked` keys `["agents"]`, shim: install exits 1 printing `Validation errors: hooks: Invalid input` | INST-01d | the install did fail (not c); key mismatch is the only defect |
| superkey impersonation (the round-1 counterexample, pinned) | record `blocked` keys `["agents"]`, shim: install exits 1 printing `Validation errors: custom-agents: Invalid input` | INST-01d | the classifier yields `keys:["custom-agents"]` ≠ `["agents"]`; the install did fail (not c); join total (a); record well-formed (e) — the case that would have passed under `grep -wF` and must BLOCK now |
| missing record | 1-plugin marketplace, empty records dir, shim irrelevant | INST-01a | nothing else is reachable — a is checked first |
| clean pass (`EXPECT_PASS=1`) | one `installs` pack whose shim installs and lists, one `blocked` pack whose shim fails with the recorded key + `Invalid input` | `EXPECT_PATTERN="INST-01 PASS"` | both branches of the reproduction logic exercised on their green sides |

Precedence stated in the script (the DATA-02 pattern): a pack tripping INST-01a or
INST-01e is skipped by the behavioural checks, so each planted violation trips exactly
one rule and `EXPECT_PATTERN` proves what it appears to prove.

### Handover to PDX-024 — what the split defers, named so nothing is silently lost

Everything below was in this plan's first draft as steps 9–11 and moves to PDX-024
whole. This ticket ships the data and the API (`installabilityFor`, plus the existing
`readSource`); PDX-024 is rendering-only against them.

1. **Card install state** (`PackCard.astro`): a blocked pack's card keeps its verdict
   chip, figures, and attribution (CLAIM-01) and gains an install-state marker — text +
   shape, never colour alone (DESIGN.md §5) — with the record's `attemptedAt`.
2. **The counts line** (`index.astro`): "N of M listings currently install", computed
   from the records at build time (DATA-01 — computed, never typed). The state stays
   strictly per-listing: no code path filters the card list on it, which is what makes
   the ticket's all-blocked edge case render a full catalogue with a 0-of-M count
   rather than an empty page. That edge case transfers to PDX-024 with this item.
3. **The measured-commit disclosure** (`InstallDialog.astro`): every dialog names the
   commit the figures were measured against (short SHA + `readAt` from the pack's
   attribution `source.json` via `readSource`) and states plainly that the command
   installs the upstream's current HEAD, which may differ — with the measured reason
   pinning is unavailable (marketplace `ref` resolves as a git branch; a full SHA
   fails `Remote branch ... not found`) recorded in the component comment, not just in
   this plan.
4. **The blocked-state disclosure** (`InstallDialog.astro`): attempted date, CLI
   version, and the verbatim error in a terminal-styled block; the install command
   stays visible and copyable — the reader is told, not managed.
5. **The site scenario** (`tests/e2e/PDX-024-*.sh`): over built `dist/`, per entry
   derived from the built registry (never hard-coded): dialog contains the short SHA
   equal to the pack's `source.json` commit read at run time; blocked cards contain
   marker AND figures AND attribution; counts line equals the record-derived N-of-M;
   card count equals entry count regardless of state; `caveman` pinned by name on the
   card side as well.
6. **DEV-01 checklist rows**: the blocked marker reads as a warning without colour;
   the disclosure block at 360px; dark mode; keyboard reach of the dialog — real
   browser, per the standing policy.

Until PDX-024 lands, the fact is in the repository and not on the site — the ticket's
AC-3 states the gap deliberately. The window has no live audience: the site is not
deployed (PDX-014 has not landed), so no reader sees an undisclosed install button in
the interim. That premise is pinned rather than assumed: **PDX-024 lands before
PDX-014 (deploy)** — the site must never publish a plain install button for a pack the
repository already knows does not install — and step 9's roadmap edit writes the
ordering into DESIGN.md so the no-live-audience claim cannot silently expire.

## 4. Risks

- **The split's own residual** (replaces the first draft's sequencing risk — the split
  is now the ticket's AC-3, decided because "merge PDX-004 first" was circular: PDX-004's
  CI is red *because of this incident*) → the recorded fact is unpublished until
  PDX-024, and PDX-024 depends on PDX-004 rebasing green. Bounded: no deployed site
  exists yet, and the handover above is the complete inventory, so the seam loses
  nothing — it only sequences it. Landing order: PDX-023 → PDX-004 (rebase) → PDX-024.
- **Upstream heals between recording and GREEN (or between GREEN and CI)** → INST-01c
  fires, by design. This is flake-shaped but it is the *correct* red: the record is
  stale. Mitigation: re-run the recorder, commit the refreshed record (post-GREEN: as a
  `PDX-023: follow-up` commit per CLAUDE.md). The failure message names the exact
  command. Ticket AC-5 is already worded for this world: it asserts the record exists
  and reproduces, not that it says `blocked`. Note that caveman's history makes healing
  plausible — `902eba3` was itself a fix for its issue #855, and the author is active.
- **The CLI rewords its validation output** → the shared classifier is the only
  place rewording lands: a phrasing it cannot parse makes it refuse, INST-01d fires,
  and the gate is red until the classifier is extended and the record refreshed.
  Fail-closed by construction, and a classifier extension reaches recorder and gate
  together — the two sides cannot drift apart, because there are no two sides.
- **Five real installs add network flake to every regression run** → budgeted honestly
  in §3 from the measured 2-second install; failure-not-skip is the standing policy
  (the existing AC-5 comment, kept). Accepted: a catalogue whose install proof is
  optional is the product not working.
- **The recorder writes a wrong record and the gate then defends the wrong record** →
  the recorder never types anything: version, date, commit, and error text are all
  captured from the commands it runs, an `installs` outcome additionally requires the
  pack in `claude plugin list`, and an unclassifiable failure is refused rather than
  approximated. The offline re-serialization test (step 8) means a hand edit after the
  fact cannot survive `verify.sh`.

## 5. Out of Scope

- **`packages/site/**` — all reader-facing publication.** PDX-024, per ticket AC-3;
  the complete inventory is §3's Handover subsection.
- **Pinning installs to the measured commit.** Not available through the marketplace
  schema (`ref` is a branch, SHA fails — measured), and pinning to a mutable tag is
  ticket-forbidden. If the CLI ever accepts a commit SHA, closing the gap for real is
  its own ticket.
- **Opening the upstream issue on `JuliusBrussee/caveman`.** Recommended (§6.5 D6),
  GitHub-external, user-only (CR-01).
- **Any `bench/**` change or re-measurement**; the installability record is not a
  benchmark figure and does not enter any analysis pool (no DATA-02 surface: nothing
  about it governs which cells a figure is computed over).
- **An install-state history timeline.** The record carries its latest attempt; prior
  states live in git history of a generated file.
- **A calendar-driven re-record cadence.** §6.5 D8 records who owns re-checking and
  why a schedule, if ever wanted, is an ops-runbook ticket.

## 6. Rules / Decisions Applied

- **LANG-01** — this plan and every artifact it commissions are English-only.
- **DATA-01** — nothing hand-typed: the recorder captures rather than types; the
  offline re-serialization test makes a hand edit fail `verify.sh`; the values PDX-024
  will render flow from these generated records through the built registry.
- **CLAIM-01** — caveman keeps its listing, measured figures, and attribution; the
  blocked state is additive disclosure, not a retraction. §6.5 D5 records why a state
  flip is a record refresh, not a CLAIM-01 withdrawal.
- **SRC-01** — untouched in text and in gate; the new record sits beside attribution,
  it does not modify it.
- **ASSERT-01** — recorder and gate print sentinels on every path; reproduction
  requires a non-empty log and a positive classifier verdict (a signature must be
  produced, never inferred from silence — the classifier prints `UNCLASSIFIED`, not
  nothing); the
  rewritten AC-5 requires per-pack sentinel count == plugin count, floor ≥ 1; the thin
  scenario floors every derived list it reads.
- **PLAN-01** — the measured inputs above (SHAs `902eba3` / `27d5a39...`, CLI
  2.1.233/234, CI run 32191050962, the five-pack probe, the 2-second install) are cited
  as given with their provenance; everything volatile that must hold at run time (which
  packs are blocked, golden-case numbers, the DEC number) is derived by the scenarios
  or at write time, not restated as prose.
- **GATE-01** — the new gate ships with six golden cases, both polarities, including the round-1 counterexample pinned as its own case.
- **CR-01** — no commit/push/issue/PR from the cycle; marketplace adds are local-path
  only; the upstream issue is a recommendation.
- **DEV-01** — this ticket ships no UI, so the report's Non-Scriptable Verification
  checklist is explicitly N/A row by row (declared, not skipped); the real checklist
  transfers to PDX-024 with the handover.
- DESIGN.md decisions honoured: **DEC-004** (point, never vendor), **DEC-011** (the
  recorded manifest + commit is what makes PDX-024's measured-commit disclosure
  possible at all), **DEC-012** (the `InstallSource` union is untouched; no `ref` is
  emitted), **DEC-014** (attribution derivation untouched).
- **Produced by this ticket**: the DEC entry in step 9 (expected DEC-020; number
  verified against the log at write time — the log skips 016–018 until PDX-004 lands,
  the DEC-019 precedent exactly).

## 6.5 Design Decisions

**D1 — the record lives in `packages/registry`, not `packages/data`.** The ticket allows
`packages/data` "only if the record type belongs there". It does not: `packages/data` is
the measurement corpus — cells, fingerprints, regimes — whose records enter analysis
pools under DATA-02 discipline. An installability record is a registry operational fact
about the *listing*, joined by `packId` exactly like the attribution records already
under `packages/registry/attribution/`. Putting it beside them keeps "facts about the
listing" in one package and keeps the analysis loaders unable to even see it.

**D2 — reproduction is required, in both directions.** The design constraint is that the
gate ends up stricter, and the mechanism is symmetry: `installs` must install, `blocked`
must fail *with the recorded signature*, and every other combination — including the
comfortable one where a blocked pack quietly heals — is red. Recording a pack as blocked
therefore buys exactly one thing: a green gate *while the recorded failure is still
true*, verified on every run. There is no state a maintainer can write into a record
that exempts a pack from being exercised.

**D3 — the signature is the classifier's verdict, not a grep width.** The first draft
matched the recorded key with `grep -wF` and argued the width was right; review round 1
produced the counterexample that ends the argument — `-w` treats `-` as a word
boundary, so a `custom-agents` failure reproduced an `agents` record. Tuning the
pattern (anchoring at key position) would only move the boundary; the fix removes the
second implementation instead: the recorder's classifier is the gate's classifier,
reproduction is signature equality, and an unclassifiable fresh failure is a mismatch.
The first draft's other rejections stand and are now unreachable rather than merely
declined: whole-string matching (brittle-red on the first reword) and
failure-class-only matching (impersonation-green) both required the gate to own a
pattern, and it no longer owns one.

**D4 — every listing is asserted; the cap is removed, not tuned.** From the measured
2-second install, five installs cost seconds; the old first-pack assertion was an
accidental cap whose order-dependence nearly hid this very incident (caveman happens to
sort first). No cap means no coverage-loss ledger to maintain. The cap question returns,
with its ledger, only if the roster grows toward PDX-012's ~30.

**D5 — a state flip is a record refresh, not a CLAIM-01 withdrawal.** CLAIM-01 protects
published *measurement verdicts*. The install state is a dated operational observation
that carries its own `attemptedAt` and changes when the world does; the record file is
generated, committed, and diffable, so its history is the git history of a receipt, not
a retracted claim. What CLAIM-01 does govern here — and the plan honours — is that the
blocked pack's *measured figures* stay published unchanged.

**D6 — disclosure satisfies the reader-facing duty; notifying upstream is recommended,
not performed.** plugdex's duties to authors under SRC-01 are attribution and opt-out,
and its duty to readers is honesty about what the button does — the record (here) and
the dialog (PDX-024) meet both. But the project has already decided (PDX-013, a launch
blocker) that findings about a pack are told to its author, and "your latest commit made
your pack uninstallable on the current CLI" is the most actionable finding this project
will ever hold — upstream fixed #855 and almost certainly does not know the fix broke
CLI installs on 2.1.233/2.1.234. So: **recommend** the user open an issue on
`JuliusBrussee/caveman` reporting that `902eba3`'s `agents` array fails CLI validation,
with the verbatim error and both tested CLI versions. Opening it is GitHub-external,
forbidden without the user's explicit instruction (CR-01), so the plan and report
recommend and stop.

**D7 — the reproduction check lives in a script, so the golden set can reach it.** The
dodge (ticket AC-4) must be pinned by a golden case, golden cases replay gates from a
sandbox copy of `scripts/` only, and a network-dependent check becomes testable offline
the moment the CLI is a PATH lookup: cases plant a `bin/claude` shim and prefix PATH
inside the GATE string. The shared classifier rides along for free: the sandbox is built by `cp -R scripts`, which includes `scripts/lib/`, so a case exercises the same classifier bytes the live gate runs. No env-var backdoor is added to the gate itself.

**D8 — re-checking over time is owned here, structurally, not by PDX-024.** The
reproduction gate runs inside PDX-003's scenario, so every full regression run re-checks
all five install states against reality — re-checking is continuous by construction, at
the cadence the suite runs, and a rotted `installs` record goes red the next time anyone
runs it. What nothing does is re-run the *recorder* unprompted: a record refresh is
event-driven (the gate goes red and names the command). PDX-024 owns only rendering the
record and its `attemptedAt`, so a reader can judge the snapshot's age; if a
calendar-driven refresh is ever wanted, that is an ops-runbook ticket in PDX-011's
territory, not a rider on either of these.

## 7. Test Plan (mandatory — TDD)

**The ticket scenario.** The ticket's §5 names
`tests/e2e/PDX-023-the-record-reproduces.sh` and itself records why an earlier draft's
no-scenario declaration was wrong (`check-test-case.sh` globs by ticket id;
`test-loop.sh --red` needs the ticket's own scenario to FAIL), so the flag this plan
carried is resolved and dropped — no ticket edit is needed. The scenario is where
AC-1's recorder-and-classifier proofs live: they fit neither the golden set's
gate-replay shape nor the network-bound PDX-003 scenario.

- **E2E scenario files**: `tests/e2e/PDX-003-the-hub-installs.sh` (AC-5 rewritten in
  place) and `tests/e2e/PDX-023-the-record-reproduces.sh` (thin, offline, per above).
- **Global RED** (stage 5): `verify.sh` PASSes and the PDX-023 scenario FAILs — today
  `packages/registry/installability/` does not exist, `grep -rn installability
  packages/registry/src/` is empty, and neither script exists under `scripts/`. Each is
  a distinct FAIL branch with its own message. (`test-loop.sh --red` does not run the
  full regression, so PDX-003's currently-red AC-5 does not block the RED gate.)
- **Global GREEN** (stage 7): `verify.sh` PASSes (including the new offline unit tests
  and the five new golden cases via `check-gates.sh`), the PDX-023 scenario PASSes, and
  the full regression (`./scripts/e2e.sh`) PASSes — which *includes* the rewritten
  PDX-003 scenario performing five real installs against the committed records. GREEN
  on this ticket is what returns `main`'s lineage to green (ticket AC-5).

**Per-AC: the assertion, the command that produces it, and where it lives.**

| AC | Where | RED today because | GREEN asserts (assertion + command) |
|---|---|---|---|
| AC-1 (record exists, generated) | `packages/registry/src/registry.test.ts` (offline, in `verify.sh` via `pnpm test`) + the PDX-023 scenario | no record, no reader, no recorder, no classifier | *Unit*: entries↔records join total both ways; blocked records carry non-empty `verbatim` + `keys`; dates parse; each file re-serializes byte-identically under the canonical form (`pnpm --filter @plugdex/registry test`). *Scenario (recorder proven behaviourally, offline, via `bin/claude` + `bin/git` shims and `--out` into `mktemp -d`)*: unclassifiable failure → recorder exits non-zero and writes nothing; `Validation errors: agents: Invalid input` → written record is `blocked` with `keys:["agents"]` and non-empty verbatim; install + `<pack>@plugdex` in list → `installs` record with `installedVersion` when the shim prints `Version:`. *Classifier (direct)*: the round-1 counterexample log yields `keys:["custom-agents"]`, not `["agents"]`. All sentinel-checked (`./tests/e2e/PDX-023-the-record-reproduces.sh`) |
| AC-2 (every listing, reproduction required) | `tests/e2e/PDX-003-the-hub-installs.sh` rewritten AC-5, delegating to `scripts/check-installability.sh` | AC-5 installs only `plugins[0]`, and today that install fails red with no record to check against | the gate exits 0 with one per-pack sentinel per marketplace plugin, count-equal and ≥ 1; each pack's verdict is the exact-agreement branch of the INST-01 table (`./scripts/check-installability.sh`, invoked by `./tests/e2e/PDX-003-the-hub-installs.sh`; network + real CLI, failure never skips) |
| AC-3 (the split, stated) | documentation, not code | n/a — there is no RED for a statement | satisfied by the ticket's own AC-3 text and §3's Handover subsection naming every deferred item; the plan reviewer checks the inventory is complete against this plan's first draft (steps 9–11), and the report repeats the pointer. No scenario asserts it, and none should — asserting prose is how a gate becomes paperwork |
| AC-4 (the dodge, pinned) | `tests/meta/cases/` (6 cases, §3 construction table; numbers derived at implementation) | `check-installability.sh` does not exist; no case names it | `./scripts/check-gates.sh` replays: blocked-but-installs → BLOCK `INST-01c`; installable-but-fails → BLOCK `INST-01b`; wrong signature (`hooks` vs `agents`) → BLOCK `INST-01d`; superkey impersonation (`custom-agents` vs `agents`, the round-1 counterexample) → BLOCK `INST-01d`; missing record → BLOCK `INST-01a`; clean two-pack corpus → PASS with `INST-01 PASS`. Each case trips exactly one rule (precedence stated in the gate) |
| AC-5 (green, caveman listed not delisted) | the stage-7 gate itself + the rewritten PDX-003 scenario | `main`'s lineage is red at PDX-003 AC-5 (CI run 32191050962) | `./scripts/verify.sh` exits 0 and `./scripts/e2e.sh` (full regression) exits 0 on this branch as cut from 62d76dd; caveman's presence, figures, and attribution are pinned by name in the rewritten scenario; what its record *says* is whatever the recorder measured — the criterion asserts existence + reproduction, exactly as the amended ticket words it |

- **Unit tests** (step 8): enumerated under AC-1 above; all offline, all inside
  `verify.sh`, so record shape can never depend on the network to be enforced.
- **Ticket edge cases mapped**: network down → the gate FAILS (kept policy; AC-2 row);
  upstream self-heals → INST-01c (golden case + live gate); reworded error, same cause →
  the key+class signature (D3; the `wrong signature` golden case proves the inverse
  direction); all-blocked page → transfers to PDX-024 with handover item 2 (the
  record side has no page to assert).

## 8. Feature Tags

- `registry` — the record, its reader, the generated files, the marketplace contract
- `harness` — a new gate with golden cases; every later ticket inherits INST-01

## 8.5 References Consulted (REF-01)

DESIGN.md's Reference Map has no PDX-023 row (`check-references.sh` will report nothing
required), so per the PDX-017 precedent the references actually used are recorded
voluntarily. The PDX-003 row's mapped references (`marketplace.schema.json`,
`plugin.json`, `plugin marketplace add`) are the nearest mapped set and their live
behaviour was re-measured for this ticket rather than re-read as documents; those
measurements are rows here.

| Reference | Consulted | Note |
|---|---|---|
| `.docs/tickets/PDX-023_...md` (as amended, re-read twice) | Y (2026-08-19) | New AC-3 (split to PDX-024), AC-4/AC-5 renumbering, `scripts/**` + `docs/WORKFLOW.md` Allowed; §5 now names `PDX-023-the-record-reproduces.sh` and records its earlier no-scenario error itself, so the plan's structural flag is resolved and dropped |
| `tests/e2e/PDX-003-the-hub-installs.sh` | Y (2026-08-19) | AC-5's first-pack pick (`plugins[0]` — caveman sorts first), its SSH→HTTPS retry, sentinel discipline, and the failure-not-skip network policy this plan keeps |
| `scripts/check-test-case.sh` + `scripts/test-loop.sh` usage | Y (2026-08-19) | The stage-4 glob (`tests/e2e/<ID>-*.sh`) and stage-5 RED contract — the basis of the earlier structural flag, now satisfied by the ticket-named scenario |
| `packages/registry/src/schema.ts` / `upstream.ts` / `generate.ts` | Y (2026-08-19) | The `Attributed` / `ManifestSource` / module-relative-dir patterns the record reader mirrors; DEC-012's one-member union untouched; generation stays offline |
| `packages/registry/attribution/*/source.json` (5) | Y (2026-08-19) | Each carries `commit` + `readAt` — PDX-024's measured-commit disclosure needs no new data, only rendering; caveman's is `27d5a39...`, readAt 2026-08-17 |
| CLI/marketplace behaviour (measured, cited as given) | Y (2026-08-19) | `902eba3` `agents` rejection on 2.1.233 AND 2.1.234 (not a CLI regression); `ref` resolves as a git branch, full SHA fails `Remote branch ... not found`; five-pack probe: caveman blocked, four install; one warm install = 2 s |
| `DESIGN.md` — DEC-004/011/012/014, §5, chip table, decision-log format | Y (2026-08-19) | DEC-011 is what makes the measured-commit disclosure possible; DEC-012 forbids widening the source union; chip priorities untouched; log ends at DEC-019 → expected DEC-020, skipping 016–018 exactly as DEC-019's precedent did |
| `CLAUDE.md` / `docs/WORKFLOW.md` | Y (2026-08-19) | DATA-01/02, SRC-01, CLAIM-01, ASSERT-01, PLAN-01, GATE-01, REV-02, follow-up-commit convention; `check-gates.sh` sandboxes copy `scripts/` only (verified in the runner source), which fixes where the gate must live |
| `.docs/analysis/PDX-017_plan.md` | Y (2026-08-19) | Shape and depth template; the scope-amendment and golden-case-construction-table precedents; the DEC-number-skip precedent step 9 cites |
| `feat/pdx-004-...` branch tree (`InstallDialog.astro`, `PackCard.astro`) | Y (2026-08-19) | Confirms `packages/site` has zero tracked files on `main` at 62d76dd — the fact the ticket's AC-3 now states — and names the exact components the PDX-024 handover targets |
| `tests/meta/lib.sh` + case 34 + `scripts/check-gates.sh` runner | Y (2026-08-19) | Case anatomy (`GATE`/`plant`/`EXPECT_PATTERN`), the eval'd GATE string that lets a case prefix PATH for the `claude`/`git` shims, and the one-rule-per-case discipline |

### 9.0 What round 1 of this review found

One blocker, verified by execution, and five notes folded in rather than argued with.

- **The blocker (P4): the signature's key match was green-direction wide.** `grep -wF`
  treats punctuation as a word boundary, so `Validation errors: custom-agents: Invalid
  input` *reproduced* a record with `keys: ["agents"]` — a different manifest defect
  impersonating the recorded one, the exact failure D3 claimed to reject (and the
  draft's "`agents` does not match `subagents`" sentence was true for the prefix case
  only). Fixed by the reviewer's stronger option, not by tuning the width: reproduction
  is now defined as *the recorder's own classifier over the fresh log yields the same
  `(kind, keys)`* — one shared implementation (`scripts/lib/install-signature.py`, step
  3a) invoked by recorder and gate alike, so the match-width question no longer exists,
  a keys-superset drift is a mismatch, and the recorder's refusal to classify is the
  gate's refusal too. The counterexample is pinned as its own golden case (sixth), and
  the scenario feeds the classifier that exact log directly.
- **Folded notes**: the `claude plugin list` token is pinned as `<pack>@plugdex` in
  both the installs-presence and blocked-absence branches (the shared config dir
  accumulates entries, so bare-name width is the blocker's defect class again); the
  `installs` variant gains an **optional** `installedVersion` — the only field that
  names the artifact the button actually delivered, which is this ticket's founding
  gap; the gate header states that `cliVersion` / `attemptedAt` / `upstreamCommit` are
  dated snapshot fields the gate does not re-verify; the handover and step 9 pin
  PDX-024 ahead of PDX-014 (deploy) so the no-live-audience premise cannot silently
  expire; and the stale ticket-§5 conflict flag is dropped — the ticket's own §5 now
  names the scenario and records the correction itself, so no ticket edit is needed.

## 9. Agent Review (round 2)

Round 2 under REV-02: the job is to confirm round 1's fixes, not to reopen design.
Every revision claim was checked against the plan text; every environmental claim
(sandbox copy semantics, the round-1 grep counterexample, python3 availability, the
Reference Map) was re-verified at the shell, not taken from §9.0.

### Reviewer
- Model: Fable 5 (Claude Code subagent)
- Reviewed at: 2026-08-19 07:49

### Verdict
- [x] APPROVED_WITH_NOTES

### Round-1 fix confirmation

The round-1 blocker (P4: `grep -wF` key match; `Validation errors: custom-agents:
Invalid input` reproduced a `keys: ["agents"]` record — re-verified by running the
grep, it still matches) is fixed, and fixed structurally rather than by tuning:

1. **The shared classifier closes the hole; it does not relocate it.** Parsing now
   lives in exactly one place — `scripts/lib/install-signature.py` (step 3a) — invoked
   by the recorder (step 3: "runs the shared classifier (step 3a)") and by the gate
   (step 5: "reproduction is judged by the step-3a classifier, never by a pattern of
   the gate's own"). The round-1 defect was *matching a stored key against raw log
   text*, where `-w`'s punctuation boundary let a hyphenated superkey impersonate.
   The new shape is *extraction then set equality*: the classifier extracts keys from
   the `Validation errors:` segment ("one key per `<key>: <message>` pair") and the
   gate compares sorted key sets with exact string equality per key, superset =
   mismatch (§3 reproduction spec). A `custom-agents` log therefore extracts to
   `custom-agents` and cannot equal `["agents"]` — there is no substring or boundary
   step left for the defect to live in. The behaviour is pinned three ways: the
   reproduction spec, the scenario feeding the counterexample log to the classifier
   directly (step 8 / AC-1 row), and golden case 4 ("superkey impersonation"). The
   parse is specified to the level a plan can honestly reach (segment, pair shape,
   output form `SIGNATURE kind=... keys=<sorted,comma-joined>`, `UNCLASSIFIED` +
   non-zero otherwise); the residual — the extraction regex itself — is exactly what
   the pinned golden case checks at report stage. Confirmed closed.
2. **Fail-closed holds on both sides.** Recorder: an unclassifiable failure → refuses
   to write, exits non-zero naming the reason (step 3). Gate: the blocked-branch pass
   requires a *positive* classifier verdict equal to the stored signature; "different
   signature — or none" is INST-01d by the verdict table, an `installs` record's
   non-clean outcome is INST-01b, a blocked record with empty verbatim/keys is
   unrepresentable in the type and INST-01e at the gate. No path lets an
   unclassifiable fresh log reach pass.
3. **Sandbox reachability verified at the shell.** `scripts/check-gates.sh:75` is
   `cp -R scripts "$SB/scripts"` — the whole tree, `scripts/lib/` included
   (`gate-log.sh` already lives there and rides today); cases execute as
   `( cd "$SB" && eval "$GATE" )` (check-gates.sh:125), cwd = sandbox root, so
   `scripts/lib/install-signature.py` resolves under both cwd-relative and
   `$0`-relative lookup. python3 comes from inherited PATH (the case PATH prefix
   prepends `bin/` without clearing it; sibling precedent
   `check-data-universe.sh:306`), matching the plan's "Bash + python3 like the
   sibling gates".
4. **Nothing round 1 approved is broken by the restructure.** Offline/online
   boundary: the gate is invoked by the PDX-003 e2e only, never `verify.sh` (step 5);
   the classifier is pure text parsing; golden cases and the PDX-023 scenario run on
   planted shims, offline. ASSERT-01: the classifier's "cannot classify" is printed
   output (`UNCLASSIFIED`), never silence; reproduction requires a non-empty log plus
   a positive verdict; recorder `RECORDED` sentinels and the gate's count-equal
   per-pack sentinels stand. Strictness: all five INST-01a–e branches intact, and
   classifier set-equality is strictly narrower than the grep it replaces.

All five folded notes confirmed present in the plan text: `<pack>@plugdex` token
pinned in both list branches (INST-01 spec), optional `installedVersion` on the
`installs` variant only (step 1), snapshot fields declared not-re-verified in the
gate header (INST-01 spec), PDX-024 pinned ahead of PDX-014 (step 9 + Handover), and
the ticket-§5 flag dropped (§7; the ticket's own §5 names the scenario).

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | §2 maps every touched path to ticket Scope.Allowed; `packages/data` excluded with reasoning (D1), `bench/**` and delisting untouched; §7 table covers AC-1..AC-5 each with a home |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | Steps 1–3a, 5–6, 9 touch 1–2 files; step 4 (5 generated records, one recorder run) and step 7 (6 homogeneous golden cases) are single-artifact batches round 1 already accepted |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | PASS | §6 honours DEC-004/011/012/014 explicitly; no `ref` emitted (DEC-012); expected DEC-020 cites the DEC-019 skip precedent; chip priority table untouched |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | Round-1 FAIL fixed: shared classifier (step 3a) replaces `grep -wF`, counterexample pinned as golden case 4 AND fed to the classifier directly in `tests/e2e/PDX-023-the-record-reproduces.sh`; §7 has per-AC RED/GREEN with commands |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | §4 lists five risks each with mitigation (incl. CLI rewording → classifier refusal → INST-01d, fail-closed); §5 is explicit, six items |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | `./scripts/check-language.sh` PASS on this tree (run 2026-08-19). An earlier draft of this row cited a grep whose pattern spelled out a Hangul character range, and the gate blocked the review that asserted the gate passes — LANG-01 has no allowlist, and a rule with an exception for quoting itself would not be one |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | `grep -n 'PDX-023' DESIGN.md` → no Reference Map row, so nothing is required; §8.5 records eleven references voluntarily with Y + dated notes (PDX-017 precedent) |

### Comments

Notes for the report stage — none is design-fatal; per REV-02 they ride rather than
opening a round 3.

1. **Multi-key error format, now measured (coordinator input, 2026-08-19).** A
   manifest breaking two fields at once produces one line, comma-separated pairs:
   `Validation errors: hooks: Invalid input, agents: Invalid input` — and the key
   order follows neither the manifest nor the alphabet. The classifier must split
   pairs on `, ` and handle N keys, and its `keys=<sorted,comma-joined>` output
   contract is thereby load-bearing, not cosmetic — sorting at the classifier is what
   makes the gate's set-equality order-proof. The plan's set-sorted comparison
   already absorbs this (which is why it is a note); the report should show the
   implemented classifier handles the measured two-key sample, ideally as an added
   or extended golden/scenario input — none of the six planned cases currently
   plants a multi-key log.
2. **Stale case count in §7 Global GREEN**: "the five new golden cases" — step 7 and
   the AC-4 row both say six (the pinned counterexample is the sixth). Prose-only
   inconsistency; correct in passing at implementation.
3. **Classifier path resolution is unspecified** (cwd-relative vs `$0`-relative).
   Both work under the two verified invocation contexts (repo root; sandbox root via
   `cd "$SB"`), so this is robustness, not correctness: prefer resolving relative to
   the gate's own dirname at implementation.
4. **Local-path marketplace source measured viable** (`"source": "./badpack"`
   relative to the marketplace root; traversal refused): a cheaper substrate for any
   future live-CLI proof of the classifier against a real `claude`. The planned
   `bin/claude` shims remain right for the golden cases — they test the gate, not
   the CLI — so this is recorded as an option, not a change request.

### Blockers (only if NEEDS_REVISION)

None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (round 2, 2026-08-19 — round-1 blocker confirmed fixed; 4 notes ride to the report stage per REV-02)
- Human: _(pending)_
