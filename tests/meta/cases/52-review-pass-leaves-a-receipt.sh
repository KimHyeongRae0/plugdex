CASE_DESC="REV-03: an approved review writes a committed receipt; the gate is not the only record that it happened"
GATE="scripts/agent-review.sh report .docs/analysis/PDX-999_report.md"
EXPECT_PATTERN="receipt written"
EXPECT_PASS=1
plant() {
  # The receipt exists because three goal audits in a row found the same gap: `.docs/state/`
  # and `.docs/scratch/` are gitignored, so on `main` the only evidence a review happened is
  # the review section itself — text inside the document it approves, validated by nothing.
  #
  # This case plants a minimally-approved report and asserts the receipt is written. The
  # negative side is case 17 and the review gate's own NEEDS_REVISION path, which never
  # reaches the receipt.
  mkdir -p .docs/analysis .docs/tickets .docs/state
  # STATE-01 gates the review on the stages before it, so the planted ticket carries them.
  # The case is about the receipt, not about stage order — case 17 covers the review gate's
  # own refusals.
  for stage in preflight plan-reviewed test-case red green; do
    printf '%s\t2026-01-01T00:00:00\n' "$stage" >> .docs/state/PDX-999.state
  done

  mkdir -p tests/e2e
  printf '#!/usr/bin/env bash\nexit 0\n' > tests/e2e/PDX-999-planted.sh
  chmod +x tests/e2e/PDX-999-planted.sh

  cat > .docs/tickets/PDX-999_planted.md <<'TICKET'
# PDX-999 — planted
TICKET

  cat > .docs/analysis/PDX-999_report.md <<'REPORT'
# PDX-999 Report — planted

## 4. Test Execution

### 4.0 Round log (mandatory — TDD)

| Round | Command | Result |
|---|---|---|
| 1 | planted --red | RED |
| 2 | planted | GREEN |

## 5. Non-Scriptable Verification (DEV-01)

| Item | Result | Notes |
|---|---|---|
| planted | N/A | this case is about the receipt, not about a rendered surface |

## 10. Agent Review

### Reviewer
- Model: planted-reviewer
- Reviewed at: 2026-01-01 00:00

### Verdict
- [x] APPROVED

### Rubric

| ID | Item | Verdict | Evidence |
|---|---|---|---|
| R1 | AC evidence | PASS | planted |
| R2 | TDD integrity | PASS | planted |
| R3 | Plan compliance | PASS | planted |
| R4 | Code match | PASS | planted |
| R5 | CR-01 compliance | PASS | planted |
| R6 | Language policy | PASS | planted |

### Comments
1. planted

## 11. Final Report Status

- Agent: APPROVED
- Human: planted
REPORT
}
