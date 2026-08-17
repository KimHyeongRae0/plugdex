# <PDX-###> Plan — <Title>

- Ticket: `.docs/tickets/<PDX-###>_<slug>.md`
- Author: <agent/model>
- Date: YYYY-MM-DD

## 1. Goal & Context

<What this ticket achieves; current state; why now.>

## 2. Scope Check

- Ticket Scope.Allowed respected: <how>
- Ticket Scope.NotAllowed respected: <how>

## 3. Steps

Keep steps small (1–3 files per step).

| # | Step | Files | Notes |
|---|---|---|---|
| 1 | ... | ... | ... |

## 4. Risks

- <risk> → <mitigation>

## 5. Out of Scope

- <explicitly deferred items>

## 6. Rules / Decisions Applied

- LANG-01 (English-only artifacts; no allowlist)
- DESIGN.md decision references (§n): <...>
- DESIGN.md decision log (DEC-###): <...>

## 7. Test Plan (mandatory — TDD)

- E2E scenario file(s): `tests/e2e/<PDX-###>-<slug>.sh`
- RED condition: <what must FAIL before implementation, and why>
- GREEN condition: <what must PASS after implementation>
- Unit tests: <added or not, with reasoning>

## 8. Feature Tags

- <tags mapping this ticket to regression scenarios>

## 8.5 References Consulted (REF-01)

Per DESIGN.md, Reference Map: before a mapped ticket's step, open each required reference
and record it here as `Y (date) — one-line note`. `check-references.sh` (and rubric
row P7) BLOCK a mapped ticket whose required references are missing or un-Y'd.
Tickets on the REF-01 exemption list (e.g. PDX-001) record a single N/A row.

| Reference | Consulted | Note |
|---|---|---|
| <required reference name> | Y (YYYY-MM-DD) / N/A | <one line> |

## 9. Agent Review

_(placeholder — review not yet written)_

### Reviewer
- Model:
- Reviewed at:

### Verdict
- [ ] APPROVED
- [ ] APPROVED_WITH_NOTES
- [ ] NEEDS_REVISION

### Rubric

Every row must be scored PASS / FAIL / N/A with one line of concrete evidence.
Any FAIL row requires verdict NEEDS_REVISION (the gate rejects APPROVED + FAIL).

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| P1 | Scope fidelity: the plan stays inside the ticket's Scope.Allowed / NotAllowed and addresses every AC | | |
| P2 | Step granularity: steps touch 1-3 files each and are independently verifiable | | |
| P3 | Decision consistency: no conflict with the DESIGN.md decision log | | |
| P4 | Test plan: concrete e2e file(s) with explicit RED and GREEN conditions covering each AC | | |
| P5 | Risk coverage: risks, mitigations, and Out of Scope are explicit | | |
| P6 | Language policy: the plan and referenced artifacts are English-only (LANG-01) | | |
| P7 | References consulted: the plan's References Consulted section shows the ticket's required references actually opened (Y + note), or the ticket is on the REF-01 exemption list | | |

### Comments
1.

### Blockers (only if NEEDS_REVISION)
-

## 10. Final Plan Status

- Agent: _(pending)_
- Human: _(pending)_
