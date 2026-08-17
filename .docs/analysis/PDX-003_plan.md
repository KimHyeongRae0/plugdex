# PDX-003 Plan — Pack entries, marketplace generation, and SRC-01

- Ticket: `.docs/tickets/PDX-003_registry-pack-entries-and-marketplace-generation.md`
- Author: Opus 5 (main agent)
- Date: 2026-08-17

## 1. Goal & Context

plugdex claims to be a hub. Today it is a dataset with no way to install anything, and
the claim is unproven. This ticket builds `packages/registry`: one entry per listed pack,
a generated `.claude-plugin/marketplace.json`, and the SRC-01 gate that refuses an entry
which cannot say whose work it is.

Reading the upstream manifests changed the design, and the change is the point of the
ticket rather than a detail of it. A pack's own `.claude-plugin/plugin.json` declares
`author`, and often `repository`, `license`, and `homepage` — the *identity* half of what
SRC-01 demands. The other half cannot come from upstream by definition: stars at record
time, how the author asked to be listed, and the opt-out contact are facts about our
relationship with them, not about their code. **Attribution should therefore be derived from what the author published, not
retyped by us.** A hand-typed author field is our claim about someone; a derived one is
their own declaration, and it is the difference between a directory and a rumour.

Two things found while reading real manifests make this concrete:

- One consulted manifest declares no `repository` at all. SRC-01 must block it on upstream
  data alone, which means the design needs a curated-override path that is itself
  recorded — not a silent default.
- The pack commonly called "Karpathy's skills" declares a **different person** as its
  author. It is a third party's packaging of Karpathy's published `CLAUDE.md`. Listing it
  under Karpathy's name would be misattribution on the front page of a site whose entire
  pitch is provenance. SRC-01 exists for exactly this, and the scenario asserts it.

## 2. Scope Check

- **Ticket Scope.Allowed respected**: work is confined to `packages/registry/`, the
  generated `.claude-plugin/marketplace.json`, `scripts/check-src.sh`, one new step in
  `scripts/verify.sh`, golden cases under `tests/meta/cases/`, `tests/e2e/PDX-003-*.sh`,
  and `DESIGN.md` for the decisions this ticket produces. `registry` is already a
  registered package name (ST-02).
- **Ticket Scope.NotAllowed respected**:
  - No vendoring of pack **content**. Skills, hooks, and anything a user would execute
    stay upstream; entries carry an install source pointing at the author's repository
    (DEC-004). The one thing recorded here is each pack's `.claude-plugin/plugin.json`,
    verbatim, under `packages/registry/attribution/` with the commit it was read from.
    That is the author's declaration about themselves, and it exists so a reader can
    check our listing against their own words rather than trusting us. Vendoring ships
    someone's functionality; this ships their claim so ours can be audited. The ticket's
    NotAllowed now draws the line in those terms and DEC-011 records it, so the
    distinction is ruled rather than assumed.
  - No verdicts. This ticket produces `PackEntry` only. `PackVerdict` is derived from
    `@plugdex/data` by a pure function and belongs to the ticket that renders it
    (DATA-01).
  - No entry with a placeholder. A pack that cannot satisfy SRC-01 is not listed with a
    blank field; it is not listed.
  - Nothing published. Generation is local; publishing the marketplace, adding it to any
    account, or announcing it are separate instructed actions (CR-01).

## 3. Steps

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | Declare the package | `packages/registry/package.json`, `packages/registry/tsconfig.json` | `@plugdex/registry`, same script set as `@plugdex/data`, depends on it for the AC-6 join |
| 2 | The entry type and its provenance discriminator | `packages/registry/src/schema.ts` | `PackEntry` with every SRC-01 field non-optional. Each attribution field is a tagged value — `{from: "upstream", value}` or `{from: "curated", value, why}` — so "we derived this" and "we asserted this" are different states in the type, not a convention |
| 3 | Read a pack's attribution manifest | `packages/registry/src/upstream.ts` | Parses each pack's recorded `.claude-plugin/plugin.json` under `packages/registry/attribution/`. **`.claude-plugin/plugin.json` is the canonical path and a root-level manifest is an error, not a fallback** — one measured pack ships a stub at its root, and reading it would yield a silently empty author. Reads a file, makes no network call, so *generation* stays deterministic and offline |
| 4 | The entries | `packages/registry/src/entries.ts` | One entry per measured arm. Curated values carry their `why`. The misattribution case is handled here explicitly and commented |
| 5 | Generate the marketplace | `packages/registry/src/generate.ts`, `.claude-plugin/marketplace.json` | Emits the `{name, owner, plugins[]}` shape the real manifests use, with each plugin's `source` as `{source: "github", repo: "owner/repo"}`. Sorted and stably serialized so regeneration is byte-identical |
| 6 | The SRC-01 gate | `scripts/check-src.sh`, `scripts/verify.sh` | BLOCKs a missing upstream link, a missing named author, or a curated value with no `why`. One new verify step |
| 7 | Golden cases for the gate | `tests/meta/cases/` | One planted violation per blocked condition. GATE-01: a gate with no planted violation is untested |
| 8 | The scenario | `tests/e2e/PDX-003-the-hub-installs.sh` | AC-1..AC-7, including the real install |

## 4. Risks

- **The install proof needs a marketplace that does not exist publicly yet** → the
  scenario adds the marketplace from a local path rather than a published repository, so
  nothing is published (CR-01). The first draft of this plan then claimed the assertion
  "needs no network", which was wrong in both directions and the review caught it: the
  install source is `{"source": "github", ...}`, so the install clones from the author's
  repository and **network is required**. What that buys is stronger than the plan
  originally claimed — a successful install proves end-to-end delivery of a real pack from
  a real upstream. What the local path does *not* prove is that our marketplace is
  addable remotely, which needs this repository public and belongs to the deploy ticket.
  The report states the limit in those terms.
- **The e2e mutates the developer's real plugin configuration** → it runs under a scratch
  `CLAUDE_CONFIG_DIR`, so adding a marketplace and installing a pack leave nothing behind.
  Without this, every local run would accumulate a `plugdex` marketplace in the real
  config.
- **AC-5 depends on a third party's repository staying reachable** → it does, and that is
  deliberate. A listed pack that no longer installs is a broken listing, and this is the
  assertion that catches it. A network error therefore fails rather than skips; only a
  missing `claude` binary skips, loudly and with the reason recorded.
- **`claude` may not be on PATH in CI** → the install assertion skips loudly with a
  recorded reason rather than passing silently. A skipped assertion that prints nothing is
  the failure mode this repository's gate self-test exists to prevent.
- **Vendored upstream manifests go stale** → they are a snapshot, and the entry records
  which commit of the upstream repository it was read from. Refreshing them is a
  deliberate edit, not a background sync. Stated as a limit, not solved here.
- **The join to `@plugdex/data` hard-codes an exclusion set** → AC-6 requires every
  measured arm to be listed or explicitly excluded with a reason. The combination arm is
  excluded because it is not an installable pack. `baseline` is excluded because it is the
  absence of a pack. Both reasons live next to the exclusion.
- **SRC-01 becomes a formality that always passes** → the golden cases are what stop
  that, and `check-gates.sh` replays them. If a case stops catching its violation, the
  gate is fixed, never the case.
- **A curated override becomes the easy path** → the `why` is required by the type and by
  the gate, so overriding costs a sentence that a reviewer reads. That is the intended
  friction.

## 5. Out of Scope

- Rendering. Cards, chips, and install buttons are PDX-004.
- Verdict derivation. PDX-004 owns the pure function from cells to a chip.
- Listing packs beyond the measured set. The top-N listing and the request queue are
  PDX-012, and doing it here would put unmeasured entries in before the shape is proven.
- Author notification. PDX-013, and a launch blocker there rather than here.
- Publishing or announcing the marketplace (CR-01).

## 6. Rules / Decisions Applied

- SRC-01 — the rule this ticket makes enforceable
- DATA-01 — respected by producing no verdict here
- GATE-01 — every new gate condition gets a planted violation
- ASSERT-01 — every assertion in this scenario reads a value a subprocess produced, so
  each one emits a sentinel and an empty capture fails; this is the rule the review's
  first blocker made necessary
- CR-01 — generation is local; publication is a separate instruction
- LANG-01 — English-only, no allowlist
- PLAN-01 — this plan names where facts live rather than copying counts and SHAs into
  prose; the scenario derives them
- DEC-003 (three packages), DEC-004 (point upstream, never vendor the pack itself),
  DEC-006 (unmeasured packs are listed and labelled — honoured by deferring the unmeasured
  set to PDX-012 rather than faking it here)
- DESIGN.md §3 — the hub alone is not defensible, which is why SRC-01 is a gate

## 7. Test Plan (mandatory — TDD)

- **E2E scenario file**: `tests/e2e/PDX-003-the-hub-installs.sh`
- **RED condition** (before step 1): `verify.sh` PASSes and the scenario FAILs, and every
  assertion FAILs for the reason it names rather than by accident. Under ASSERT-01 this is
  a property of the whole file, not of two special cases: before step 1 nothing under
  `packages/registry/dist/` exists, so every `node --input-type=module` block exits
  non-zero with its diagnostics on a stderr the scenario discards, and every variable those
  blocks fill is the empty string. Any assertion phrased as "empty means nothing was wrong"
  therefore reports a pass in exactly the state it is supposed to reject.
  - Each subprocess prints a sentinel on the success path — a report object for the
    field checks, an explicit `OK` for the boolean ones — and the assertion first requires
    the capture to be non-empty, naming "the package is not built" as the failure.
  - AC-3's determinism check must not pass vacuously: with no generator both runs produce
    nothing and "byte-identical" is trivially true, so non-emptiness is asserted first.
  - AC-6's join must fail for the right reason. Before implementation there are no
    entries, so every measured arm is unlisted — the assertion must report that as the
    failure, not crash on a missing module.
  - **Attribution** must fail rather than pass. Its check collects mismatches and treats an
    empty collection as agreement; with no built package the collection is empty because
    the import failed, and the review found it printing a passing checkmark on today's
    tree. It is the assertion the plan calls the one that makes SRC-01 more than paperwork,
    so it is the one least able to afford a vacuous pass.
  - The RED run is evidence, not assertion: `./scripts/test-loop.sh PDX-003 --red` must
    show every assertion in the FAIL column, and a row that passes before any code exists
    is a defect in the assertion rather than a head start.
- **GREEN condition**: `verify.sh` PASSes with the new SRC-01 step, the scenario PASSes
  all assertions including the real `claude plugin install`, `check-gates.sh` catches
  every planted violation including the new ones, and the full regression PASSes so
  PDX-001 and PDX-002 still hold.
- **Scenario assertions**, one per acceptance criterion:
  - AC-1 — every entry has all SRC-01 fields, each tagged `upstream` or `curated`
  - AC-2 — every emitted install source is the `github`/`repo` form, **and** the type
    rejects the `git`/`url` form. Asserted as a pair: the supported fixture must compile
    and the unsupported one must fail. A lone negative compile check is green before the
    code exists — the fixture fails to compile because the module is missing, not because
    the type rejected it, which is the same fake-RED class PDX-002 hit. The review's second
    blocker was that this paragraph existed and the scenario did not implement it: it
    checked the emitted JSON only, so "must fail the type" had no artifact that could fail.
    The pair is two fixtures under `packages/registry/test/fixtures/`, both compiled with
    `tsc --noEmit`, and the assertion requires the first to exit 0 and the second non-zero.
    Checking the emitted JSON as well is kept, because a type stops enforcing anything once
    the JSON is written
  - AC-3 — generate twice, byte-identical, and the output is non-empty
  - AC-4 — `check-src.sh` BLOCKs each planted violation
  - AC-5 — `claude plugin marketplace add` against a local path, then
    `claude plugin install`, then the pack appears in the installed list. Asserted on the
    listing, not on the exit code
  - AC-6 — every arm in `@plugdex/data` that is not `baseline` is either listed or in the
    commented exclusion set. **Derived from the corpus at runtime**, never a hard-coded
    arm list, so a future measured arm cannot be silently dropped
  - AC-7 — `verify.sh` runs SRC-01 and the golden set is unregressed
  - **Attribution** — the pack whose upstream manifest names a different author than its
    common name is listed under the name its manifest declares. This is the assertion
    that makes SRC-01 more than paperwork
- **Unit tests**: yes, `packages/registry/src/*.test.ts`. The generator's determinism and
  the upstream/curated discrimination are unit-level properties; the e2e proves the hub
  works end to end and should not also be the place a serializer is tested.

## 8. Feature Tags

- `registry` — entries, generation, SRC-01; regression scenario `PDX-003-*`
- `data` — the AC-6 join reads `@plugdex/data`, so a change to its shape breaks this
  ticket's scenario

## 8.5 References Consulted (REF-01)

Per DESIGN.md, Reference Map: PDX-003 requires `marketplace.schema.json`, `plugin.json`,
`plugin marketplace add`.

| Reference | Consulted | Note |
|---|---|---|
| marketplace.schema.json | Y (2026-08-17) | Read two real `.claude-plugin/marketplace.json` files from installed packs. Shape is `{name, owner: {name, url\|email}, description, plugins: [{name, source, description, category, keywords}]}`; `metadata.version` appears in one and not the other, so it is optional. Our generator emits the common subset and nothing speculative |
| plugin.json | Y (2026-08-17) | Read the manifests of two listed packs. Both declare `author`, `license`, `version`; one declares `repository` and `homepage` and the other declares neither. This is what moved the design from hand-curated entries to upstream-derived with a recorded override — and it is why the override path exists at all |
| plugin marketplace add | Y (2026-08-17) | Verified earlier against a scratch marketplace that `{"source": "github", "repo": "owner/repo"}` resolves and installs, and that `{"source": "git", "url": ...}` is rejected by the installed Claude Code version. AC-2 encodes the supported form in the type so the unsupported one cannot be written |

## 9. Agent Review

Round 1 (Fable 5, 2026-08-17 16:45) returned **NEEDS_REVISION** with P1 and P4 FAIL, and
every finding was a design defect rather than a stale fact — which is what REV-02 intends
round 1 to be for.

**AC-5 was internally contradictory.** The plan claimed the assertion "needs no network"
while installing a pack whose source is `{"source": "github", ...}`, which clones from the
author's repository. Both cannot be true. The stated limit was also backwards: a
successful github-source install *does* prove GitHub delivery; what a local-path
marketplace fails to prove is that our marketplace is addable remotely. AC-5 now requires
network, says why that is a feature rather than a cost, and runs under a scratch
`CLAUDE_CONFIG_DIR` so it stops mutating the developer's real configuration.

**AC-2's negative compile check was green on today's tree** — a fixture that fails to
compile because the module does not exist proves nothing about the type. Now asserted as a
pair, so the pre-implementation state is honestly RED.

**Step 3 contradicted the plan's own scope statement.** It stored copies of each pack's
manifest while §2 claimed no pack content is copied. Resolved by ruling the distinction
rather than arguing around it: pack *content* — skills, hooks, anything executable — stays
upstream, and a pack's `plugin.json` is an attribution record, the author's declaration
about themselves, kept verbatim so a reader can audit our listing against it. The ticket's
NotAllowed now draws that line and DEC-011 records it.

Three ride-alongs applied: one measured pack ships a stub `plugin.json` at its root with
the real one under `.claude-plugin/`, so the canonical path is now specified and a
root-level read is an error rather than a fallback; §1 overstated "the exact fields SRC-01
demands", since stars, listing provenance, and opt-out contact can never come from
upstream; and the review confirmed the misattribution finding and the exclusion set
against the corpus itself.

Round 2 (Fable 5, 2026-08-17) returned **NEEDS_REVISION** with two blockers, both found
by *executing* the staged scenario rather than reading it — which is why they were not
visible in round 1.

**The Attribution assertion was GREEN on today's tree.** Its node block imports
`./packages/registry/dist/index.js`, which does not exist before step 1. The import throws,
the diagnostics go to a stderr the scenario discards, the mismatch list is the empty
string, and `[[ -n "$MISMATCH" ]]` takes the else branch and prints a passing checkmark for
a check that never ran. The assertion the plan calls "the one that makes SRC-01 more than
paperwork" was the one asserting nothing.

**AC-2's paired compile check did not exist.** The ticket's AC-2 and §7 of this plan both
specify a pair — the supported fixture compiles, the unsupported one does not — and the
staged scenario checked only the emitted JSON. A requirement written in two places and
implemented in none is not a stricter test than one that was never written down.

Both are fixed in §7 above, and the first is now a project rule rather than a patch.
ASSERT-01 was added to `CLAUDE.md` and `docs/WORKFLOW.md` in this cycle: an assertion never
passes on empty output; a subprocess whose output an assertion reads emits a sentinel, and
an empty capture fails. This is the sixth instance of that exact shape in this project —
PDX-002's AC-7 grep and its timezone comparison, both blockers here, the grader reporting
zero mypy diagnostics when the python gate was absent, and the loader reading a missing
environment audit as a clean one. Fixing the sixth instance individually would have left
the seventh to be found by whoever trusted it.

**Round 3 is taken under REV-02's exception**, which permits a third round when round 2
raises a new blocker, with the reason stated. Round 2 raised two, neither of them a
restatement of a round-1 finding, and both were the class of defect that reads as a pass.
The scope of round 3 is those two fixes and the rule that generalises them; anything else
still outstanding rides to the report stage.

Round 3 (Fable 5, 2026-08-17) returned **APPROVED_WITH_NOTES** with no blockers. Both
round-2 blockers are resolved in spec, and the reviewer verified the claim §7 makes rather
than accepting it: an assertion-by-assertion RED walk against the staged draft plus this
plan's §7, pre-implementation, put every one of AC-1..AC-7 and Attribution in the FAIL
column, each for the reason it names — including AC-4, which exits 127 because
`check-src.sh` does not exist yet, and AC-7, which passes only on a positive grep match and
so is ASSERT-01-safe by construction.

Four findings ride to the report stage under REV-02 rather than spending a fourth round.
None is a pre-implementation defect; all four are about behaviour once the code exists:

1. **Attribution has a GREEN-time vacuity the sentinel does not close.** A report of
   `{checked: 0, bad: []}` passes having verified nothing — reachable if every author is
   tagged `curated`, since the check skips non-`upstream` entries. The sentinel must carry
   a checked-count of at least 1, or the known-misattribution pack must be asserted
   independently of its tag. §7 pins the pack but not the tag.
2. **AC-5's skip semantics are ambiguous.** The ticket says the assertion "skips loudly"
   when `claude` is absent; the staged draft's skip also sets `FAILED=1`, which makes skip
   and fail identical. Conservative, but the report must state which is intended.
3. **AC-4's failure message names the wrong cause pre-implementation.** It reports "SRC-01
   BLOCKs the registry" when the actual cause is a missing script. It fails safely, but
   not "for the reason it names", which is the standard §7 sets.
4. **AC-3's determinism check mutates a tracked file.** It regenerates `marketplace.json`
   in place and restores the original only on the diff-fail branch, so a build that dies
   mid-write leaves the tracked file corrupted.

Finding 1 is the one to carry forward deliberately: it is ASSERT-01's own blind spot. The
rule stops an assertion passing on *empty* output; it does not stop one passing on output
that is well-formed and describes zero work. A sentinel proves the subprocess ran, not that
it checked anything.

### Reviewer
- Model: Fable 5 (claude-fable-5)
- Reviewed at: 2026-08-17 18:05

### Verdict
- [ ] APPROVED
- [x] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

Every row must be scored PASS / FAIL / N/A with one line of concrete evidence.
Any FAIL row requires verdict NEEDS_REVISION (the gate rejects APPROVED + FAIL).

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | PASS | §3 steps touch only ticket-Allowed paths; §7 carries one assertion per AC-1..AC-7 plus Attribution; every NotAllowed item is answered in §2 |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | PASS | 8 steps, at most 2 files each, every step naming its own verifiable artifact (package manifest, schema, gate script, golden case, scenario) |
| P3 | Decision consistency: no conflict with DESIGN.md decisions or the decision log | PASS | The round-1 DEC-004 tension is ruled by DEC-011 and mirrored in the ticket's NotAllowed and §2; DEC-003/005/006 respected — no verdicts, no rendering, unmeasured set deferred to PDX-012 |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | PASS | Both round-2 blockers resolved in spec — Attribution sentinel with non-empty-capture-first, and the AC-2 fixture pair under `packages/registry/test/fixtures/` compiled with `tsc --noEmit`; an assertion-by-assertion RED walk put all eight in the FAIL column pre-implementation |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | PASS | Eight risks each with a mitigation, including the network-required inversion from round 1; Out of Scope names the owning ticket for each exclusion |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | PASS | Hangul-range grep over the plan and the ticket returned 0 matches in both; full read of plan, ticket, and the staged scenario found no non-English text |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | PASS | §8.5 rows match `check-references.sh` exactly (`marketplace.schema.json`, `plugin.json`, `plugin marketplace add`), all Y with dated notes that visibly drove design changes |

### Comments
1. Round-2 blocker 1 (Attribution vacuous pass) is resolved in spec: every subprocess prints
   a sentinel on the success path and every assertion requires a non-empty capture before
   any content check, naming "the package is not built" as the failure.
2. Round-2 blocker 2 (AC-2 pair specified but unimplemented) is resolved in spec: the plan
   now names the artifact that was missing — two fixtures compiled with `tsc --noEmit`, the
   first required to exit 0 and the second non-zero — with the emitted-JSON check retained
   because a type stops enforcing anything once the JSON is written.
3. ASSERT-01 is correctly stated and correctly applied: `CLAUDE.md` and `docs/WORKFLOW.md`
   carry the same rule, and the plan applies it as a whole-file property of the scenario
   rather than as two patches, which is the generalisation the rule exists for.
4. The RED claim was verified rather than accepted. Pre-implementation: AC-1 empty capture,
   AC-2 positive fixture cannot compile, AC-3 non-emptiness checked first, AC-4 exits 127 on
   the missing `check-src.sh`, AC-5 empty pack name, AC-6 empty capture, AC-7 no positive
   grep match, Attribution empty capture — eight FAILs, no vacuous pass available.
5. PLAN-01 holds: the plan states where facts live rather than restating counts, SHAs, or
   file inventories, and the six ASSERT-01 instances are fixed history rather than volatile
   facts.
6. Four non-blocking findings ride to the report stage; they are listed above with finding 1
   flagged as ASSERT-01's own blind spot. Per REV-02 the report must repeat the round-3
   justification.

### Blockers (only if NEEDS_REVISION)
- None.

## 10. Final Plan Status

- Agent: APPROVED_WITH_NOTES (Fable 5, 2026-08-17, round 3 — 0 blockers; 4 findings ride to the report stage per REV-02)
- Human: _(pending)_
