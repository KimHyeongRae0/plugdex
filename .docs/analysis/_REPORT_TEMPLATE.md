# <PDX-###> Report — <Title>

- Ticket: `.docs/tickets/<PDX-###>_<slug>.md`
- Plan: `.docs/analysis/<PDX-###>_plan.md`
- Author: <agent/model>
- Date: YYYY-MM-DD

## 1. Summary

<What changed, in 3–6 sentences.>

## 2. Files Changed

| File | Change |
|---|---|
| ... | ... |

## 3. Plan Compliance

| Plan step | Done | Deviation (if any) |
|---|---|---|
| 1 | ✅/❌ | ... |

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

| Round | Command | Result |
|---|---|---|
| 1 | `./scripts/test-loop.sh <PDX-###> --red` | verify PASS / e2e FAIL → RED OK |
| 2 | `./scripts/test-loop.sh <PDX-###>` | ... |

### 4.1 Final GREEN evidence

- check-test-case: PASS
- verify (language + structure + gates + typecheck + lint + test + build): PASS
- ticket e2e: PASS
- regression (`e2e.sh` all): PASS

## 5. Non-Scriptable Verification (DEV-01)

Behavior that no gate can verify. Check every relevant item via the mandated tool
(agent-browser for studio UI), or mark it N/A with a reason — non-scriptable
behavior is declared, never silently skipped. Everything scriptable stays in §4,
not here.

| Item | Result | Notes |
|---|---|---|
| Studio visual quality (agent-browser screenshot review) | PASS / FAIL / N/A | ... |
| CI workflow executes on the runner (declared, not run locally) | PASS / FAIL / N/A | ... |
| <ticket-specific non-scriptable behavior> | PASS / FAIL / N/A | ... |

## 6. Regression Check

<What full-suite run was done; anything flaky; anything skipped and why.>

## 7. Rules Verification

- LANG-01: `./scripts/check-language.sh` PASS
- Decision conformance (DESIGN.md decision log DEC-###): <...>

## 8. Risks / Notes

- <follow-ups, known limitations>

## 9. CR-01 Compliance

- No commit / push / issue / PR / merge / release performed without explicit user
  instruction during this ticket: YES / NO (explain)

## 10. Agent Review

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
| R1 | AC evidence: every ticket AC is verified with reproducible gate/command output, and non-scriptable behavior is declared in the Non-Scriptable Verification section (checked via the mandated tool or explicit N/A), never silently skipped | | |
| R2 | TDD integrity: the round log records a real RED (e2e FAIL) before GREEN | | |
| R3 | Plan compliance: deviations from the approved plan are disclosed and justified | | |
| R4 | Code match: Files Changed is accurate and claimed rules/decisions are reflected in the code | | |
| R5 | CR-01 compliance: no commit/push/issue/PR/merge/release without explicit user instruction | | |
| R6 | Language policy: all changed artifacts are English-only (LANG-01) | | |

### Comments
1.

### Blockers (only if NEEDS_REVISION)
-

## 11. Final Report Status

- Agent: _(pending)_
- Human: _(pending)_
