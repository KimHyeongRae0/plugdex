# PDX-001 — Port the gate harness and point it at plugdex

- Status: DONE
- Created: 2026-08-17

## 1. Goal

Stand up the repository with the orangerail 9-stage gate harness ported in full and
re-pointed at plugdex, so that every subsequent ticket is decided by a script exit code
rather than a judgement. The bootstrap is done when `./scripts/verify.sh` passes on a
tree that contains no product code yet, and `./scripts/check-gates.sh` proves each
ported gate still catches the violation it was written for.

## 2. Scope

### Allowed
- `scripts/` — the ported gate scripts, re-pointed (PDX ids, plugdex env vars, our registries)
- `tests/meta/` — the golden set, re-pointed and adjusted where a case tested a rule we changed
- `.github/` — issue and PR templates, CI
- `CLAUDE.md`, `DESIGN.md`, `README.md`, `docs/WORKFLOW.md`, `LICENSE`
- root manifests: `package.json`, `pnpm-workspace.yaml`, `tsconfig*.json`, lint/format config
- `.docs/` skeleton and the three document templates

### Not Allowed
- `packages/` — no product code in this ticket. The workspace stays empty and
  `verify.sh` runs in empty-workspace mode
- Any GitHub-external action beyond creating the repository the user asked for (CR-01)
- Inventing new gates. DATA-01, CLAIM-01 and SRC-01 are specified in `docs/WORKFLOW.md`
  §3.1 and land with their own tickets, each with an e2e scenario and a golden case

## 3. Acceptance Criteria

- [ ] AC-1: `./scripts/verify.sh` exits 0 on the bootstrap tree, with Node steps
      WARN-skipped in empty-workspace mode
- [ ] AC-2: `./scripts/check-gates.sh` exits 0 — both clean-tree baselines pass and every
      case in `tests/meta/cases/` is caught by the right rule
- [ ] AC-3: `./scripts/check-language.sh` BLOCKs Hangul in `DESIGN.md`, proving LANG-01
      carries no allowlist (golden case 11 asserts this)
- [ ] AC-4: no identifier from the port source survives — zero matches for `ONT-`,
      `orangerail`, `ontogate`, `ORANGERAIL_`, `ONTOGATE_` in tracked files
- [ ] AC-5: `scripts/check-structure.sh` enforces the plugdex registry (`site`, `data`,
      `registry`) and rejects an unregistered package directory
- [ ] AC-6: `scripts/check-references.sh` carries the plugdex Reference Map and it matches
      the table in `DESIGN.md` §6
- [ ] AC-7: `CLAUDE.md`, `DESIGN.md` and `docs/WORKFLOW.md` describe plugdex's rules,
      layout and packages — not the port source's

## 4. Edge Cases & Error Handling

- A gate script that lost its teeth in the rename → covered by `check-gates.sh`, which
  copies the current `scripts/` tree into each sandbox, so a broken detector fails
  immediately rather than passing silently
- A golden case whose rule changed meaning (case 11 tested an allowlist plugdex does not
  have) → rewritten to assert the opposite, never deleted
- Empty workspace with no `packages/*/package.json` → `verify.sh` skips Node steps with a
  loud warning rather than failing or silently passing

## 5. E2E Mapping

- `tests/e2e/PDX-001-harness-is-repointed.sh` — asserts the harness answers to plugdex:
  no port-source identifiers remain in tracked files, the package registry is the plugdex
  one, LANG-01 has no allowlist, and the Reference Map matches DESIGN.md

## 6. References

- Exempt from REF-01: the port source (orangerail) is itself the reference
- `docs/WORKFLOW.md` §3, §3.1 — the rule set this bootstrap installs
- `DESIGN.md` DEC-001, DEC-002 — why the harness was ported and why LANG-01 lost its allowlist
