# PDX-035 — docs: the corpus says what it actually covers

- Status: TODO
- Created: 2026-08-20

## 1. Goal

The site says every pack "was run against real tickets in a real repository". That is true and
it is read as something much wider than what happened. Measured 2026-08-20 from
`tasks.py` in the harness repository and from `bench/data/runs/`:

- **All 14 tasks live in one repository** — the `full-stack-fastapi-template` fixture. The
  harness has exactly one fixture directory.
- **They have two shapes.** Six are (date picker,
  colour picker, command palette, dropzone, form wizard, star rating). Six are (duplicate, search, count, archive, bulk delete, CSV export), plus a
  uniqueness constraint and a daily count.
- **Every prompt is one sentence with no interface contract** (`"open": True` in the task
  table), which is a deliberate design choice and also a scope fact.
- **There is no mobile or client-app work, and no design work.** Zero cells of either.

So what the corpus supports is: *does this pack help an agent add a React component or a
FastAPI endpoint to this particular template, unattended.* That is a real and defensible
finding. It is not "does this pack help with real tickets", and the difference is exactly the
kind of unnamed condition this project has withdrawn three published claims over.

This ticket does not add tasks. It makes the page say what the corpus is, in the same place
it states the rate — the same discipline `formatRate` applies to a denominator, applied to
the task set. PDX-036 is the ticket that widens coverage; this one stops the current claim
from being read wider than it is, and it can land today.

## 2. Scope

### Allowed
- `packages/site/**` — the coverage statement, derived from the records, with tests
- `packages/data/**` — if deriving the task inventory needs an export
- `README.md`, `bench/README.md` — the same statement in the same words
- `tests/e2e/PDX-035-*.sh`

### Not Allowed
- Adding, removing or re-running any task. This ticket changes what the page says about the
  corpus it already has
- Weakening the finding into vagueness. "A variety of tasks" is not the fix; the fix is
  naming the two shapes and the single fixture
- Deleting the existing sentence. CLAIM-01: the previous wording, its date and its cause stay
  readable
- Any figure typed rather than derived (DATA-01) — the task count and the domain split are
  figures

## 3. Acceptance Criteria

- [ ] AC-1: **The task inventory is derived, not typed.** The count of tasks, the split by
      domain, and the number of distinct fixtures come from the records; a task added to the
      corpus changes the sentence without anyone editing it.
- [ ] AC-2: **The coverage statement sits with the headline rate**, not in a footnote or a
      methodology page one click away. A reader who sees `73% n=22 (frontend)` must be able to
      see what the 22 were in the same view.
- [ ] AC-3: **The two shapes are named.** "Six component-addition tasks and six
      endpoint-addition tasks, all in one full-stack template repository" — or whatever the
      records then say. Naming the shape is what stops "real tickets" being read as "any
      ticket".
- [ ] AC-4: **What is absent is stated as absent**: no mobile or client-app tasks, no design
      tasks, no task in a second repository. An absence a reader has to infer from a list is
      an absence most readers will not notice.
- [ ] AC-5: **CLAIM-01 record.** The previous wording, the date, the cause (this audit) and
      the replacement are reachable from the surface that carried the claim.
- [ ] AC-6: **An e2e asserts the statement against the records**, re-deriving the counts
      independently, and FAILs on an empty selection (ASSERT-01).
- [ ] AC-7: **The external-validity limit is stated once, plainly**: these results predict
      behaviour on this fixture's kind of work, and nothing has measured whether they transfer.
      Stated as the limit it is, without apologising for the corpus that exists.
- [ ] AC-8: **The page ends in a decision, not only in a distribution.** An outside review of
      the live site on 2026-08-20 scored it 6.5/10 and named this as one of three lost points:
      Refusing a
      composite index is right and it is not a reason to hand the reader a chart and stop. The
      page states, derived from the same records: which arm (if any) clears the baseline's
      interval on frontend work, that **no pack is distinguishable from baseline on backend
      work**, and what the cost of the one that does clear is. Every clause must be a
      consequence of the records, so a corpus change rewrites the recommendation instead of
      outdating it. No weights, no score, no ordering the corpus does not support.
- [ ] AC-9: **The figure groups what it cannot separate.** The same review found the ranked
      bars read as a league table despite the intervals: DEC-027 argued the drawn interval makes the
      overlap the most visible thing; an outside reader says the visual structure wins over the
      argument. Arms whose intervals overlap the baseline's are rendered as one group that the
      corpus cannot tell apart, with the separation stated where it exists. **Membership is
      derived from the intervals, never assigned**, and the e2e re-derives it — a hand-kept
      grouping would be the composite index this project refuses, wearing a layout.

## 4. Edge Cases & Error Handling

- A task is added in a second fixture → AC-1's derivation must report two fixtures, not
  silently keep saying one. The e2e plants a second fixture id in a scratch copy and asserts
  the sentence moves.
- The domain split changes → the sentence is derived, so it follows; the e2e re-derives rather
  than matching a fixed string.
- The statement is read as an apology rather than a scope note → AC-7 fixes the register: the
  corpus is small and it is honest about what it covers, which is the opposite of a weakness
  to hedge around.

## 5. E2E Mapping

- `tests/e2e/PDX-035-the-corpus-says-what-it-covers.sh` — over built output: the coverage
  statement exists in the same section as the headline rate; its counts re-derive from
  `bench/data/runs/`; the absences named in AC-4 are present as text; a planted second fixture
  changes the derived sentence; a zero-task selection FAILs rather than passing vacuously.

## 6. References

- CLAIM-01, DATA-01, DEC-020 (one named condition), ASSERT-01
- `tasks.py` in the harness repository — the task table and its `open` flag
- `bench/data/runs/` — the domain split, 181 frontend and 102 backend cells
- `DEC-005`, `DEC-025`, `DEC-027` — the ordering decisions AC-9 revisits. DEC-027 is six
  hours old at the time of writing and AC-9 does not overturn it: the interval stays drawn,
  and the grouping is what the interval *means*, derived from it rather than asserted beside it
- The 2026-08-20 outside review (Codex, given the rendered text of both pages and the task
  inventory): 6.5/10, three lost points — benchmark scope stated too late and too weakly, the
  leaderboard visual outrunning the weak-ordering message, and no decision sentence
- Related: `PDX-036` (widening coverage), `PDX-033` (the other published claims)
