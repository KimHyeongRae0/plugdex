CASE_DESC="REF-01: a mapped ticket (PDX-002) plan missing its required references is blocked"
GATE="scripts/check-references.sh .docs/analysis/PDX-002_plan.md"
EXPECT_PATTERN="REF-01"
plant() { plant_plan_doc PDX-002 "x" APPROVED; }
