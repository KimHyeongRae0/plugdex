CASE_DESC="LANG-01 has no allowlist: Korean in DESIGN.md — the one file the lineage exempted — still BLOCKs"
GATE="scripts/check-language.sh"
EXPECT_PATTERN="LANG-01"
plant() { printf '# DESIGN\n\n%s\n' "$(hangul)" > DESIGN.md; }
