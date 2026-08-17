CASE_DESC="ST-04: analysis file not PDX-###_plan.md / PDX-###_report.md"
GATE="scripts/check-structure.sh"
EXPECT_PATTERN="ST-04"
plant() { echo "x" > .docs/analysis/PDX-900_notes.md; }
