# PDX-031 — bench: an arm proves its treatment activated

- Status: TODO
- Created: 2026-08-19

## 1. Goal

**One published arm never received its treatment, and we reported its null as a finding
about the pack.**

`mattpocock-skills` ships as a plugin whose entire treatment is 25 **model-invoked** skills:
its `.claude-plugin/plugin.json` declares `skills` and no `hooks`, so nothing enters the
agent's context except a listing the model may choose to call. Counting `Skill` tool-use
blocks across the preserved Claude Code transcripts for every cell in the corpus —
reproduced independently for this ticket with a script written from scratch:

| arm | cells | cells that invoked any skill |
|---|--:|--:|
| baseline | 82 | 6 |
| caveman | 48 | 7 |
| karpathy | 78 | 4 |
| **mattpocock** | **69** | **0** |
| ponytail | 80 | 1 |
| superpowers | 81 | 64 |

Every invocation outside superpowers is the **built-in** `run` skill, which the runner's own
`BLOCKED_BUILTIN_SKILLS` denies. superpowers' 64 are `superpowers:brainstorming`. So
**mattpocock invoked nothing, ever, in 69 cells.** That arm measured baseline plus a longer
skill listing in the system prompt.

`bench/README.md:134` says *"Two packs with very large followings showed no measurable
reduction at all."* Those two nulls are not the same kind of null:

- **karpathy** is delivered by `--append-system-prompt`, not as a plugin, so its text was
  provably in context in 78 of 78 cells. That is a real null **for that text**, though it is
  also not how the pack's author ships it — the upstream declares a `skills` entry.
- **mattpocock** is a null for a treatment that never fired. It is not evidence about the
  pack at all.

The finding underneath is more interesting than the one we published: **model-invoked skills
do not fire on one-sentence tickets in a headless session.** That is worth publishing. What
is not defensible is a card that reads as a verdict on a pack.

## 2. Scope

### Allowed
- `packages/data/**`, `packages/site/**` — an activation field per cell, published, with tests
- `bench/data/runs/**` — an activation record derived from the preserved transcripts; no
  re-measurement, no new agent invocation
- `bench/harness/` — the deriving script, committed and re-runnable
- `bench/README.md`, `bench/DERIVATIONS.md` — the CLAIM-01 correction
- `tests/e2e/PDX-031-*.sh`, `tests/meta/cases/`
- `DESIGN.md` — the decision, and the rule if one is added

### Not Allowed
- Deleting the mattpocock arm or its card. The measurement happened; what changes is what it
  is said to mean (CLAIM-01, SRC-01)
- Re-running any cell against a live model
- Any activation claim not derived from a transcript. "The plugin was installed" is not
  activation; the existing corpus proves installation and disproves activation
- Publishing an activation rate without saying what counts as activation for that arm — the
  arms deliver by different channels and one threshold cannot cover them

## 3. Acceptance Criteria

- [ ] AC-1: **every cell carries a derived activation record**: which channel the arm uses
      (`hook`, `appended-system-prompt`, `model-invoked-skill`), whether the treatment was
      present in context, and whether it was invoked. Derived from the preserved transcripts
      by a committed script, never typed.
- [ ] AC-2: **an arm whose treatment never activated is labelled on the site**, in the same
      view as its rate, in words a reader cannot miss. The rate is not deleted and not
      recomputed; it is annotated with what it measured.
- [x] ~~AC-3: the two kinds of null are separated in `bench/README.md` under CLAIM-01.~~
      **Absorbed by PDX-033 AC-1.8**, which rewrites `bench/README.md` in one pass. AC-2
      above is **not** absorbed and stays here: it labels the arm on the site beside its rate,
      which renders the derived activation field AC-1 produces, and PDX-033 writes no derived
      field.
- [ ] AC-4: **activation is verified for every arm, both directions.** The positive controls
      already exist in the transcripts and must be asserted rather than assumed: ponytail's
      marker text in its cells, superpowers' subagent marker, caveman's verbatim ruleset, and
      the combination arm carrying both. An arm whose activation cannot be established fails
      the check rather than defaulting to activated.
- [ ] AC-5: **activation becomes a precondition, not a postscript.** A future run records
      activation per cell as it goes, and a run whose arm shows zero activations is reported
      as an instrument failure at the time rather than discovered by audit afterwards.
- [ ] AC-6: **the delivery-channel mismatch is disclosed per arm.** Where this benchmark
      delivers a pack differently from how its author ships it — karpathy injected as an
      appended system prompt while upstream declares a skill — the card says so, because a
      reader comparing packs is entitled to know the channel differed.

## 4. Edge Cases & Error Handling

- A transcript is missing for a cell → activation is `unknown` and the cell is excluded from
  activation rates with its reason, never counted as activated or as not.
- An arm activates in some cells and not others → the rate is per cell, and the arm's summary
  says how many. A binary arm-level flag would hide exactly the gradient this ticket exists
  to surface.
- A skill fires but is the blocked built-in `run` → not activation of the pack. The check
  distinguishes pack-namespaced skills from built-ins, which is the distinction that turns
  "6 baseline cells used a skill" into "0 baseline cells received a treatment".
- Publishing an activation rate makes an arm look better or worse → not a consideration. The
  direction here happens to be unflattering to a published sentence of ours.

## 5. E2E Mapping

- `tests/e2e/PDX-031-activation-is-derived.sh` — AC-1, AC-4, AC-6: per-cell activation
  derived from transcripts, positive controls asserted for all four verifiable arms, an arm
  with unestablishable activation failing rather than defaulting
- `tests/e2e/PDX-031-a-null-says-which-kind.sh` — AC-2, AC-3: the site labels the
  never-activated arm beside its rate, and the corrected README claim carries its previous
  reading

## 6. References

- The preserved transcripts under the user's Claude Code project directory — the source for
  every count in §1, re-derivable by the script AC-1 commits
- `bench/README.md:134` — the sentence this ticket corrects
- `mattpocock-skills/.claude-plugin/plugin.json` — `skills`, no `hooks`
- SRC-01, CLAIM-01 in `CLAUDE.md`
- PDX-032 — the regime ticket; both re-frame published claims and should land together so a
  reader sees one corrected story rather than two
