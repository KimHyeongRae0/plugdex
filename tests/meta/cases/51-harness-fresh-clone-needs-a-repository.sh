CASE_DESC="fresh-clone gate: a directory that is not a git repository FAILs rather than reporting a clean verify"
GATE="scripts/check-fresh-clone.sh"
EXPECT_PATTERN="not a committed ref"
plant() {
  # `check-fresh-clone.sh` exists because verify passed on a tree carrying build output an
  # empty checkout does not have. Its own failure mode is the same shape one level up: a
  # gate that cannot obtain the tree it is supposed to check must say so, not report that
  # it found nothing wrong. The sandbox is not a git repository, so there is no ref to
  # clone and the gate has to refuse.
  #
  # This is the only assertion the golden-set model can host for this gate — replaying the
  # passing path would mean cloning and installing a full pnpm workspace inside a case,
  # which the sandbox is not built for. That limit is recorded in DESIGN.md rather than
  # left to be rediscovered.
  :
}
