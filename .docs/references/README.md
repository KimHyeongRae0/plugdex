# References

What this project has actually opened, and what each one grades with.

The rule is REF-01's, applied to a claim about a literature: a citation this project cannot
vouch for is not made plainly. Each entry below records the date it was opened, what the work
grades with, and one line on whether it covers **behaviour-norm packs** — the category
plugdex's surviving premise is about. A work that could not be opened is listed as unopened
rather than cited.

**What the premise claims and what these entries support.** `README.md`, `bench/README.md`,
`CLAUDE.md` and `DESIGN.md` say no published work grades behaviour-norm packs by whether the
delivered code builds. Every entry here grades *generated or patched code* by execution — that
is the point: execution-based grading is standard practice for code benchmarks, which is why
the earlier, wider claim ("in every published benchmark we could find, measured without
checking that the delivered code compiles") was false. What none of them does is apply that
oracle to a **pack that changes an agent's behaviour**, which is the narrow claim that
survives.

**This is not a systematic survey.** It is a record of what was read. The premise is stated as
"we found no published work", not "no published work exists", and that wording is load-bearing.

| Work | Opened | Grades with | Covers behaviour-norm packs? |
|---|---|---|---|
| SWE-bench / SWE-bench Verified — `swebench/harness/grading.py`, https://github.com/SWE-bench/SWE-bench | 2026-08-20 | `resolved` requires `FAIL_TO_PASS == 1.0` **and** `PASS_TO_PASS == 1.0`; PASS_TO_PASS exists so "existing functionality is properly maintained" (https://ar5iv.labs.arxiv.org/html/2310.06770) | No — it grades patches to real issues, not a pack installed alongside an agent |
| Commit0 — https://arxiv.org/html/2412.01769v1 | 2026-08-20 | ships ruff and type checking as **feedback to the model**, then states performance is measured "only by the pass rate of these unit tests" | No — from-scratch library generation, no pack under test |
| SecureAgentBench — https://arxiv.org/html/2509.22097v1 | 2026-08-20 | implements a new-SAST-warning delta and deliberately demotes it: a new warning marks a patch "suspicious", not failed; correctness is the repo's own suite | No |
| EvalPlus — https://arxiv.org/abs/2305.01210 | 2026-08-20 | strengthened test suites alone; reports pass@1 dropping by up to **19.3 points** | No |
| VeriCoder — https://arxiv.org/html/2504.15659 | 2026-08-20 | reports GPT-4o at 100% syntax accuracy and 69% functional correctness | No |
| EnvBench — https://arxiv.org/html/2503.14443v1 | 2026-08-20 | pyright `reportMissingImports == 0` plus build exit 0 — the one precedent that accepts an import-level oracle, and it grades *environment setup*, where resolving imports **is** the goal | No |

**Not opened, and therefore not cited anywhere in this repository**: the marketing pages of
the packs themselves. Their headline numbers are quoted from the packs' own READMEs and are
tagged as such in `packages/registry/attribution/`, which is a different thing from a
published benchmark and is not evidence for or against the premise.
