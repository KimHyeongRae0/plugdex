CASE_DESC="ASSERT-01: with no built registry the SRC-01 gate refuses rather than reporting nothing wrong"
GATE="scripts/check-src.sh"
EXPECT_PATTERN="not built"
plant() {
  # Nothing planted on purpose. An unbuilt registry produces no listings to check, and a
  # gate that reads that as "no violations found" is the exact defect ASSERT-01 exists for.
  mkdir -p packages/registry
}
