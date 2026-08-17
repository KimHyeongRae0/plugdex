CASE_DESC="ST-02: packages/ dir that is not a registered package (site|data|registry)"
GATE="scripts/check-structure.sh"
EXPECT_PATTERN="ST-02"
plant() { mkdir -p packages/webapp; }
