"""The one classifier, read by both the recorder and the gate.

Reads an install log on stdin. Prints `SIGNATURE kind=<kind> keys=<sorted,comma-joined>`
and exits 0 when it can name the failure; prints `UNCLASSIFIED <reason>` and exits 1 when
it cannot. It never exits silently, because a refusal nobody can read is indistinguishable
from a crash, and the callers treat those two differently (ASSERT-01).

Why one implementation rather than two. `scripts/record-installability.sh` writes a
blocked listing's signature and `scripts/check-installability.sh` later re-checks that the
same failure still happens. If those two carried separate notions of what an error *is*,
they would drift, and the gate would be re-checking a claim the recorder never made. The
first draft of this design had the gate matching the recorded key with `grep -wF`; plan
review round 1 broke it with a measured counterexample — `-w` treats a hyphen as a word
boundary, so `Validation errors: custom-agents: Invalid input` matched a record whose key
was `agents`, and a genuinely different manifest defect read as a reproduction. Sharing
one classifier deletes the question rather than tuning the answer: whatever this file
calls the fresh failure either equals the stored signature or it does not.

What it parses today, and where that came from. The Claude Code CLI reports a rejected
plugin manifest as a `Validation errors:` segment of `<key>: <message>` pairs, comma
separated, on one line. Both shapes are measured rather than assumed — a single-key
failure from the live `caveman` listing, and a two-key failure produced by installing a
manifest with two broken fields:

    Validation errors: agents: Invalid input
    Validation errors: hooks: Invalid input, agents: Invalid input

The second is why keys are sorted before they are printed: the CLI emitted `hooks` before
`agents`, which is neither the manifest's order nor alphabetical, so an unsorted signature
would compare unequal to itself across runs.

Everything else is UNCLASSIFIED, and that is a feature. A failure this file cannot name is
one the gate cannot re-check, so the recorder refuses to write a record for it and the
gate refuses to call it a reproduction. The fail-closed direction is red, never green, and
extending the parse moves both callers at once because there is only one of them.
"""

import re
import sys

KIND_MANIFEST_VALIDATION = "manifest-validation"

# The segment runs to the end of its line. `re.MULTILINE` so a log whose validation
# segment is followed by more output still matches, and the capture stops at the newline
# rather than swallowing whatever came after.
VALIDATION_SEGMENT = re.compile(r"Validation errors:[ \t]*(?P<body>[^\n]+)", re.MULTILINE)

# A key is what precedes the first colon of a pair. Restricting the shape keeps a message
# that happens to contain a comma from being read as another key: `agents` and
# `custom-agents` are both legal, `Invalid input` is not.
KEY = re.compile(r"^[A-Za-z0-9_.-]+$")


def refuse(reason: str) -> None:
    """Say why, then exit non-zero. Silence is never a verdict."""
    print(f"UNCLASSIFIED {reason}")
    raise SystemExit(1)


def classify(log: str) -> tuple[str, list[str]]:
    """Name the failure in `log`, or refuse."""
    if not log.strip():
        refuse("the log is empty — an install that failed producing no output says nothing")

    match = VALIDATION_SEGMENT.search(log)

    if match is None:
        refuse("no 'Validation errors:' segment — this failure is not a rejected manifest")

    body = match.group("body").strip()

    if not body:
        refuse("the validation segment is empty")

    keys = []

    for pair in body.split(", "):
        key = pair.split(":", 1)[0].strip()

        if not KEY.match(key):
            refuse(f"unreadable key in the validation segment: {key!r}")

        keys.append(key)

    if not keys:
        refuse("the validation segment named no keys")

    return KIND_MANIFEST_VALIDATION, sorted(set(keys))


def main() -> None:
    kind, keys = classify(sys.stdin.read())

    print(f"SIGNATURE kind={kind} keys={','.join(keys)}")


if __name__ == "__main__":
    main()
