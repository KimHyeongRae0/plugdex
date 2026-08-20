# PDX-035 — docs: the corpus says what it actually covers

- Status: TODO
- Created: 2026-08-20

## 1. Goal

The site says every pack "was run against real tickets in a real repository". That is true and
it is read as something much wider than what happened. Measured 2026-08-20 from
`tasks.py` in the harness repository and from `bench/data/runs/`:

- **All 12 tasks in the corpus run against one fixture**, and the fixture is already named
  with a commit and a licence: `tiangolo/full-stack-fastapi-template @ cd83fc1` (v0.10.0,
  MIT) — `bench/REPRODUCE.md:27`, `bench/README.md:24`. *(Corrected after plan review round 1:
  an earlier draft said "14 tasks". Fourteen are **defined** in the harness's task table; two
  of them, `tmpl-be-bulkdelete` and `tmpl-be-duplicate`, were never run. The corpus holds 12,
  and a count of what was defined is not a count of what was measured.)*
- **They have two shapes.** Six `tmpl-fe-*` tasks each say *Add a `<X>` component to the
  frontend* — colour picker, command palette, date picker, dropzone, star rating, form wizard.
  Six `tmpl-be-*` tasks each say *Add an endpoint that `<Y>`*, or state a constraint on one —
  archive, count, CSV export, daily count, search, unique title. *(Corrected after plan review
  round 2: this bullet previously listed `duplicate` and `bulk delete` among the backend six,
  which are two of the tasks the bullet above says were defined and never run, and it listed
  eight items under the word "Six".)*
- **Every prompt is one sentence with no interface contract** (`"open": True` in the task
  table), which is a deliberate design choice and also a scope fact.
- **There is no mobile or client-app work, and no design work.** Zero cells of either.
- **The published pool is 127 frontend and 102 backend cells** — the `blocked` regime, valid
  and non-withdrawn, which is what every figure on the site counts (DEC-020). *(Corrected
  after plan review round 1: an earlier draft said 181 frontend, which is the both-regimes
  total. Quoting a pooled count while the page publishes one condition is the exact defect
  DEC-020 exists to prevent, made in the ticket that exists to name conditions.)*

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
- `DESIGN.md` — the decision row AC-9 owes, because grouping the arms changes the ground
  DEC-027 stood on and a decision changed outside the log is a decision nobody can audit
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
- [ ] AC-5: **CLAIM-01 record, reachable from the surface that carried the claim.** The
      sentence lives on the landing page (`index.astro`, the masthead paragraph and the
      `<meta name="description">` beside it), so a record placed only in `README.md` satisfies
      nobody: the landing page links `/`, `/analysis` and its own anchors, and a site reader
      cannot reach a repository file from it. Plan review round 1 caught this — the e2e row as
      first written would have passed while no reader could get there. The correction is
      published **on the site**, with the previous wording, its date, its cause and its
      replacement, and linked from the corrected sentence. `README.md` carries the same record
      for a reader who arrives at the repository instead.
- [ ] AC-6: **An e2e asserts the statement against the records**, re-deriving the counts
      independently, and FAILs on an empty selection (ASSERT-01).
- [ ] AC-7: **The external-validity limit is stated once, plainly**: these results predict
      behaviour on this fixture's kind of work, and nothing has measured whether they transfer.
      Stated as the limit it is, without apologising for the corpus that exists.
- [ ] AC-8: **The page ends in a decision, not only in a distribution.** An outside review of
      the live site on 2026-08-20 scored it 6.5/10 and named this as one of three lost points:
      the site is honest but weak at supporting a decision, because a visitor came to decide
      and leaves with a distribution. Refusing a
      composite index is right and it is not a reason to hand the reader a chart and stop. The
      page states, derived from the same records: which arm (if any) clears the baseline's
      interval on frontend work, that **no pack is distinguishable from baseline on backend
      work**, and what the cost of the one that does clear is. Every clause must be a
      consequence of the records, so a corpus change rewrites the recommendation instead of
      outdating it. No weights, no score, no ordering the corpus does not support.
- [ ] AC-9: **The figure groups what it cannot separate — in three tiers, not two.** The same
      outside review found the ranked bars still read as a league table despite the intervals:
      a ranked bar chart says "this one won" at a glance, whatever the whiskers show. Arms are
      rendered in **three** groups, and the third is why: **clears** the baseline's interval
      outright, **overlaps** it, or **has no interval at all**.
      *Corrected after plan review round 1, which found the two-way version live-wrong today:*
      `superpowers` has zero graded frontend cells, so its Wilson interval is `null`. Under a
      binary "overlaps or does not", it does not overlap — and lands beside `ponytail`, the one
      arm that actually clears (`[0.518, 0.868]` against baseline's `[0.112, 0.469]`). The pack
      that writes no code would have been shown in the same tier as the only pack that beats
      the baseline, on the page whose whole purpose is not to mislead. The zero/all guard would
      not have caught it: four of six arms are grouped either way.
      **Membership is derived from the intervals, never assigned**, and the e2e re-derives all
      three tiers — a hand-kept grouping would be the composite index this project refuses,
      wearing a layout.
- [ ] AC-10: **DEC-027's ground is amended on the record, not in a commit message.** DEC-027
      permitted the ordered landing figure on the stated ground that drawing the interval makes
      the overlap the most visible thing in it. AC-9's premise is that this is not enough — an
      outside reader reports the ranked form wins over the drawn interval. That is a change to
      the ground a decision stands on, so `DESIGN.md` gains a row saying what changed, what
      evidence changed it, and which of DEC-027's conditions still hold. The interval stays
      drawn; the grouping is the same claim made structurally rather than argued.

## 4. Edge Cases & Error Handling

- A task is added in a second fixture → AC-1's derivation must report two fixtures, not
  silently keep saying one — **but the page must not infer the count from ids.** Plan review
  round 1 killed the derivation this edge case was written for: renaming one task inside a
  fixture would have made the page claim two repositories, which DEC-019 forbids. The fixture
  is cited from `bench/REPRODUCE.md`; the ids are a consistency check that FAILs and names
  both sides on disagreement. *(Corrected after report review round 1, which found this
  paragraph still mandating the killed design.)*
- The domain split changes → the sentence is derived, so it follows; the e2e re-derives rather
  than matching a fixed string.
- The statement is read as an apology rather than a scope note → AC-7 fixes the register: the
  corpus is small and it is honest about what it covers, which is the opposite of a weakness
  to hedge around.

## 5. E2E Mapping

- `tests/e2e/PDX-035-the-corpus-says-what-it-covers.sh` — over built output: the coverage
  statement exists in the same section as the headline rate; its counts re-derive from
  `bench/data/runs/`; the absences named in AC-4 are present as text; the fixture is quoted
  from `bench/REPRODUCE.md` rather than asserted by the page about itself, and a disagreement
  between the task ids and that citation FAILs naming both sides; a zero-task selection FAILs
  rather than passing vacuously.

## 6. References

- CLAIM-01, DATA-01, DEC-020 (one named condition), ASSERT-01
- `tasks.py` in the harness repository — the task table and its `open` flag
- `bench/data/runs/` — the domain split: **127 frontend and 102 backend cells** in the
  published pool. 181 is the both-regimes frontend total (127 blocked + 54 as-shipped) and is
  withdrawn from this ticket under CLAIM-01
- `DEC-005`, `DEC-025`, `DEC-027` — the ordering decisions AC-9 revisits. DEC-027 is six
  hours old at the time of writing and AC-9 does not overturn it: the interval stays drawn,
  and the grouping is what the interval *means*, derived from it rather than asserted beside it
- The 2026-08-20 outside review (Codex, given the rendered text of both pages and the task
  inventory): 6.5/10, three lost points — benchmark scope stated too late and too weakly, the
  leaderboard visual outrunning the weak-ordering message, and no decision sentence
- Related: `PDX-036` (widening coverage), `PDX-033` (the other published claims)
