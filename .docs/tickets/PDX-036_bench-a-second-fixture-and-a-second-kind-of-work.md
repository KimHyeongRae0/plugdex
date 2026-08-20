# PDX-036 — bench: a second fixture, and a second kind of work

- Status: TODO
- Created: 2026-08-20

## 1. Goal

Every result this project publishes comes from one repository. The harness has exactly one
fixture — a full-stack FastAPI + React template — and inside it the fourteen tasks have two
shapes: *"Add a `<X>` component to the frontend"* and *"Add an endpoint that `<Y>`"*. There is
no mobile or client-app work, no design work, no refactor, no debugging, no test authoring,
and no change that spans an architecture rather than a file.

PDX-035 makes the site say that. This ticket makes it less true, which is the only thing that
actually widens what the results support. Two additions, and the order matters because the
second is harder to make honest than the first.

**A second fixture, of a different kind: a client application.** A build gate transfers
without argument — a mobile or desktop client either compiles and bundles or it does not, and
that is the same oracle this project already trusts. What it buys is the ability to say
whether a pack's effect survives a change of repository, which nothing here has ever tested.
An effect confined to one codebase is the same shape of finding as an effect confined to one
regime, and DEC-020 already refuses to pool across the second.

**A second kind of judgement: UI defects, not UI taste.** "Is this design good" is not a
question a build can answer, and NOLLM-01 forbids the obvious shortcut of asking a model. But
a large part of what makes a delivered interface bad **is** machine-checkable: contrast below
the WCAG floor, a body that scrolls horizontally at 360px, a control with no accessible name,
a focus state that never becomes visible, a dialog that traps or loses focus. Those are
execution-graded, reproducible, and exactly the checks this project already runs against its
own site. Grading a pack on them measures whether it leaves a usable interface behind — a
question its users have and nobody answers.

The distinction is the whole ticket: **UI defects are measurable; UI taste is not, and this
project does not get to pretend otherwise.**

## 2. Scope

### Allowed
- The harness repository's fixture directory and task table — a second fixture and its tasks
- `bench/harness/acceptance.py` — a client build gate, and the UI-defect gate
- `bench/data/runs/**` — the new cells
- `bench/README.md`, `bench/PREREGISTRATION-4.md` — the design, recorded before the run
- `packages/data/**`, `packages/site/**` — rendering a corpus with more than one fixture

### Not Allowed
- Running before the preregistration is committed. Method commitment 1: classification and
  predictions land before execution or they can be fitted to the result
- Any subjective quality score, human or model. NOLLM-01, and the reason it exists: a rating
  nobody can reproduce is the self-reported number this project was built to replace
- Grading UI defects with a tool that has not been negative-controlled. Method commitment 2:
  a gate that has not been shown to fail on broken code is not evidence that code works
- Pooling results across fixtures into one rate. The second fixture is a second condition
  until something shows the two agree, and DEC-020 is the precedent
- Re-running or re-grading the existing corpus. That belongs to PDX-026 and PDX-028

## 3. Acceptance Criteria

- [ ] AC-1: **A second fixture exists, is a client application, and is seeded reproducibly.**
      Its provenance is recorded the way the first one's is: repository, commit, and the date
      it was read. `run.py`'s seed filter is fixed first — PDX-028 AC-2b records that
      `ignore_patterns("build", …)` matches basenames at any depth and silently strips
      `backend/app/email-templates/build/` from every cell today. A second fixture seeded
      through the same filter would inherit the same class of defect.
- [ ] AC-2: **The client build gate is negative-controlled before it grades anything.** It
      passes the pristine fixture, catches an injected type error, catches an injected missing
      import, catches a deliberately broken bundle, and returns to clean when each probe is
      removed. Recorded as `gate_probes.py` already records the first fixture's.
- [ ] AC-3: **The UI-defect gate grades only what it can reproduce**, and the list is closed
      and written down: contrast against the WCAG floor, horizontal overflow at a stated
      viewport, accessible names on interactive elements, a visible focus state, and dialog
      focus behaviour. Each check names the standard it applies and the viewport it applies it
      at. Anything not on this list is not graded, and the page says the list is not "UI
      quality".
- [ ] AC-4: **The UI-defect gate is negative-controlled per check.** Every check plants its own
      violation and must catch it, and must return clean when the violation is removed. A
      check that has never been seen to fire is not evidence — this project has produced seven
      instances of an assertion that passed on empty output.
- [ ] AC-5: **Results are reported per fixture and never pooled**, with the shared arms and
      tasks matched, until a stated test shows the two fixtures agree. If they disagree, that
      is the finding and it is published as one: an effect that does not survive a change of
      repository is not an effect of the pack.
- [ ] AC-6: **The preregistration commits the predictions before the run**, including the
      direction expected for each arm on the new fixture and what result would falsify the
      hypothesis that pack effects transfer across repositories.
- [ ] AC-7: **The site renders a multi-fixture corpus without inventing a total.** Every rate
      names its fixture the way it already names its population and its condition. PDX-005's
      sweep — a percentage outside an element that declares its denominator fails — extends to
      cover the fixture.
- [ ] AC-8: **The cost is stated before the run and reported after.** The existing corpus took
      hundreds of paid cells; this doubles the fixtures. The preregistration carries the
      estimate and the report carries the actual, because a benchmark that hides its own cost
      is withholding a figure a reader needs to judge how often it can be repeated.

## 4. Edge Cases & Error Handling

- The client fixture's build is slow enough to dominate the run → AC-8's estimate is the place
  that surfaces it before it is discovered at hour six.
- A UI-defect check is flaky across renders → it does not ship. A check whose verdict changes
  without the code changing measures the renderer, not the delivery.
- A pack writes no client code at all → the same distinction PDX-031 draws: silence is a
  behaviour, not a failure, and it is reported as an activation result rather than a build
  result.
- The two fixtures agree exactly → still reported per fixture, because one agreement is not a
  demonstration that effects transfer; it is one observation that they did here.
- The UI-defect gate is read as a design verdict → AC-3's closed list and the page's own
  wording exist for this. If a reader can mistake "no WCAG violations" for "good design", the
  wording has failed.

## 5. E2E Mapping

- `tests/e2e/PDX-036-a-second-fixture.sh` — the fixture's provenance record exists and is
  complete; the client build gate's negative controls all fire and clear; every UI-defect check
  fires on its planted violation and clears on removal; no published rate pools two fixtures;
  every rendered rate names its fixture; and the scenario FAILs if either fixture contributes
  zero cells, so a half-loaded corpus cannot pass vacuously.

## 6. References

- `PDX-035` — states the current coverage; this ticket changes it
- `PDX-028` AC-2b — the seed filter that must be fixed before a second fixture inherits it
- `PDX-031` — the activation-versus-behaviour distinction the client fixture will need
- `DEC-020` — one named condition, never a pooled rate; the precedent AC-5 follows
- NOLLM-01, ASSERT-01, method commitments 1 and 2 in `bench/README.md`
- The 2026-08-20 outside review of the live site, which named hidden benchmark scope as the
  single thing most likely to lose a skeptical reader
