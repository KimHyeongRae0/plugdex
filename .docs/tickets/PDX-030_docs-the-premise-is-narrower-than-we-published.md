# PDX-030 — docs: the premise is narrower than we published

- Status: SUPERSEDED by PDX-033 (2026-08-20)
- Created: 2026-08-19

> **Superseded in whole by `.docs/tickets/PDX-033_docs-every-published-claim-is-true-in-one-pass.md`.**
> The premise correction is one of eight claims that share `README.md`, `CLAUDE.md`,
> `DESIGN.md`, `bench/README.md` and `bench/DERIVATIONS.md`. Correcting them in four
> separate cycles means four plan reviews, four report reviews and a merge conflict between
> each pair over the same four files — and it leaves a reader who arrives mid-sequence with a
> half-corrected story. The ACs below are carried into PDX-033 AC-1.6, AC-2 and AC-9; nothing
> here is dropped. Kept unedited for the record of what was scoped and when.

## 1. Goal

This project's opening sentence is false, and correcting it makes the project stronger.

`bench/README.md:6-8`, `CLAUDE.md:10-11`, `README.md:10` and `DESIGN.md:18` all say the pack
authors' headline numbers are, *"in every published benchmark we could find, measured
**without checking that the delivered code compiles**."* Published benchmarks of agent
configurations exist, and they grade with **executed tests**, which is strictly stronger than
compilation. Two were verified directly for this ticket:

- **SkillsBench** — *Benchmarking How Well Agent Skills Work Across Diverse Tasks*,
  `arxiv.org/abs/2602.12670`. 87 tasks across 8 domains, 18 model-harness configurations,
  matched no-Skills / curated-Skills conditions, graded by **deterministic verifiers**. Its
  object is "structured packages of procedural knowledge that augment LLM agents at inference
  time" — which is a description of the thing this catalogue lists.
- **Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?**,
  `arxiv.org/abs/2602.11988`. SWE-bench tasks plus novel repository issues, graded by task
  resolution.

A third was reported by the same research pass and is **not yet independently verified**:
*Do Context Files Help Coding Agents?*, `arxiv.org/html/2607.27250` (17 tasks, 3 repos, 288
runs, "pass iff all gold tests pass"). AC-1 requires it to be opened before it is cited.

**The claim that survives is narrower and still ours.** No published work measures
**behaviour-norm packs** — ponytail, superpowers, caveman, Karpathy's `CLAUDE.md`, Matt
Pocock's skills — with an execution-based oracle. SkillsBench measures curated procedural
skills; the AGENTS.md work measures repository context files. That gap is real, this
repository is still the only thing in it, and saying so accurately costs nothing.

**And the correction brings corroboration.** The AGENTS.md paper's finding is that context
files *"do not generally improve task success rates, while increasing inference cost by over
20% on average"*. That is independently the shape of this project's own result: packs move
lines, tokens and cost, and do not move correctness. A premise correction that arrives with
external confirmation of the finding is a better artifact than the overreach it replaces.

**Second, smaller correction in the same area.** `bench/harness/derive_d001.py:86,188`
computes Fisher exact over a **pool of cells**, so three repetitions of one task enter as
three independent observations. `bench/PREREGISTRATION-2.md:84-86` states the correct unit —
*"the unit of inference is the task, not the cell"* — but scopes that rule to cost and
duration, so this is a gap rather than a violation of a written commitment; the ticket says
so rather than overstating it. Nothing on the site renders a p-value, so no live figure
moves; `bench/DERIVATIONS.md` is what needs the caveat.

## 2. Scope

### Allowed
- `bench/README.md`, `README.md`, `CLAUDE.md`, `DESIGN.md` — the premise, corrected in place
- `bench/DERIVATIONS.md` — the clustering caveat and the related-work note
- `packages/site/**` — if any rendered text carries the premise, with tests
- `tests/e2e/PDX-030-*.sh`
- `.docs/references/` — the read-and-dated record of each cited work

### Not Allowed
- Deleting the original sentence. CLAIM-01: the previous wording, its date and its cause stay
  readable
- Citing any work that has not been opened and dated by whoever writes the citation. The
  research pass that found these read some of them through summaries, and a citation this
  project cannot vouch for is the defect it exists to object to
- Re-measuring anything. No cell runs; this ticket changes sentences and adds references
- Weakening the narrow claim into a vague one ("few benchmarks check") to avoid naming what
  was wrong

## 3. Acceptance Criteria

- [ ] AC-1: **every cited work is opened, dated and recorded** in `.docs/references/` with
      its title, identifier, what it grades with, what it measures, and one line on why it
      does or does not cover behaviour-norm packs. A citation whose source could not be
      opened is either dropped or labelled unverified in the text itself — never cited
      plainly.
- [ ] AC-2: **the premise is corrected in all four places** with one shared wording, and an
      e2e asserts the old sentence appears nowhere except inside a correction block. Four
      files drifting apart is how the original claim survived this long in three copies.
- [ ] AC-3: **the correction is a CLAIM-01 record**: previous wording, date, cause (this
      ticket's research pass), and replacement, all reachable by a reader.
- [ ] AC-4: **the corroboration is stated as corroboration, with its limits.** The AGENTS.md
      result concerns context files rather than behaviour packs, so it supports the shape of
      our finding without being a replication of it, and the text says which it is.
- [ ] AC-5: **the clustering caveat lands in `bench/DERIVATIONS.md`**: the Fisher figures
      pool repetitions of the same task as independent observations, the preregistration's
      task-unit rule was written for cost and duration, and no site figure depends on either.
      Stated as a known limitation with the recomputation left to a ticket, not silently
      fixed in prose.
- [ ] AC-6: **the site's own claim, if it carries one, matches the corrected premise** and
      is asserted over built output rather than over source.

## 4. Edge Cases & Error Handling

- A cited paper is later retracted or revised → the reference record carries the date it was
  read, so a reader can tell what was true when. This is the same discipline the pack
  attribution records already use for stars.
- The narrow claim is itself falsified later by a benchmark that does measure behaviour packs
  with an oracle → that is a CLAIM-01 correction, and this ticket's structure is what makes
  it cheap. Anticipated rather than hoped against.
- A reader reads the corroboration as "so the packs are useless" → the text states what was
  measured and over what, and that a null on success with a real effect on cost is a finding
  about deployment economics rather than a verdict on any pack.

## 5. E2E Mapping

- `tests/e2e/PDX-030-the-premise-is-one-sentence.sh` — AC-2, AC-3, AC-6: the corrected
  wording is identical across all four files and the built site, the old sentence survives
  only inside a correction block, and the CLAIM-01 record is reachable
- `tests/e2e/PDX-030-every-citation-was-read.sh` — AC-1, AC-4, AC-5: every identifier cited
  in prose has a dated record in `.docs/references/`, every record names what its work grades
  with, and an unverified citation is labelled as one

## 6. References

- `arxiv.org/abs/2602.12670` — SkillsBench; verified 2026-08-19
- `arxiv.org/abs/2602.11988` — Evaluating AGENTS.md; verified 2026-08-19
- `arxiv.org/html/2607.27250` — Do Context Files Help Coding Agents?; **not yet verified**
- `bench/PREREGISTRATION-2.md:84-86` — the task-unit rule and its stated scope
- `bench/harness/derive_d001.py:86,188` — the pooled Fisher computation
- CLAIM-01 in `CLAUDE.md` — the rule this ticket is an instance of
- PDX-028, PDX-029 — the two gate tickets; this one touches no gate and can run beside them
