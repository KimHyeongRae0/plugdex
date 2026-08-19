"""Serialises one installability record, in the one canonical form.

Split out of `record-installability.sh` for a reason the unit tests depend on: the exact
bytes a record has are a contract, not a formatting preference. `packages/registry`'s test
re-serialises every committed record through this module and requires the result to be
byte-identical, so a record whose canonical form drifted — a reordered key, a changed
indent, an un-redacted path — fails `verify.sh` offline.

It does not authenticate content, and saying so is the point: the check feeds a record's
own fields back through this module, so an edit that is itself canonical round-trips
unchanged. A flipped `outcome` survives it. Content is checked by INST-01, which installs
the pack again and compares what happens with what the record says — the only witness that
is not the record itself.

Every field is passed in from the environment by the recorder, and every one of those
values came off a command the recorder ran. This module invents nothing; it only decides
the shape.
"""

import json
import os
import re
import sys

# Two things in a CLI failure differ on every run and on every machine, and neither is
# part of the failure: the scratch config directory this recorder created, and the cache
# id the CLI minted for its clone. Left in, a committed record would change bytes each
# time it was regenerated, and the byte-identity test below would be testing the weather.
# They are replaced by fixed markers rather than deleted, so a reader can see that
# something stood there and the sentence still parses.
SCRATCH_ID = re.compile(r"temp_(github|local)_\d+_[A-Za-z0-9]+")

# The basename `record-installability.sh` gives its scratch directory. Checked for in
# the redacted output as a backstop; see `blocked()` for why the backstop exists.
SCRATCH_PREFIX = "plugdex-record."

CANONICAL = {"indent": 2, "sort_keys": True}


def env(name: str, *, required: bool = True) -> str:
    value = os.environ.get(name, "").strip()

    if required and not value:
        sys.exit(f"write-installability: {name} is empty — a record with a blank field is not a record")

    return value


def base() -> dict:
    return {
        "pack": env("PACK"),
        "repo": env("REPO"),
        "cliVersion": env("CLI_VERSION"),
        "attemptedAt": env("ATTEMPTED_AT"),
        "upstreamHead": env("UPSTREAM_HEAD"),
        "transport": env("TRANSPORT"),
    }


def installs() -> dict:
    record = base()
    record["outcome"] = "installs"

    # Optional on purpose: it is what the CLI printed beside the installed pack, and a
    # pack that declares no version still installs. A blocked pack has none at all, which
    # is why this lives on this variant only.
    version = env("VERSION", required=False)

    if version:
        record["installedVersion"] = version

    return record


def blocked() -> dict:
    record = base()
    record["outcome"] = "blocked"

    keys = [key for key in env("KEYS").split(",") if key]

    if not keys:
        sys.exit("write-installability: a blocked record needs the keys its failure named")

    record["signature"] = {"kind": env("KIND"), "keys": sorted(set(keys))}

    verbatim = open(env("VERBATIM_FILE"), encoding="utf-8").read().strip()

    if not verbatim:
        sys.exit("write-installability: a blocked record needs the error it is about")

    scratch = env("SCRATCH_DIR", required=False)

    if scratch:
        # Normalised before matching, and the match is REQUIRED to land. `mktemp -d
        # "$TMPDIR/..."` on a machine whose TMPDIR ends in a slash produces a path with a
        # doubled separator, which never string-matches the single-separator path the CLI
        # prints — so the first version of this redaction silently did nothing and left a
        # developer's absolute scratch path in a committed record. A redaction that can
        # quietly not happen is worse than none, because the record looks clean.
        verbatim = verbatim.replace(os.path.normpath(scratch), "<scratch>")

    # The replacement above is best-effort — a failure that never names the scratch
    # directory is perfectly ordinary, so requiring the path to appear would refuse
    # legitimate records. What is NOT optional is the outcome: no committed record may
    # carry this recorder's own temp directory. The first version of the redaction matched
    # on a path built from a TMPDIR ending in a slash, produced a doubled separator, never
    # matched the single-separator path the CLI printed, and silently left a developer's
    # absolute path in the record. So the check is on the result rather than on the input,
    # and it keys on the directory prefix this recorder chooses, which survives any
    # normalisation difference.
    if SCRATCH_PREFIX in verbatim:
        sys.exit(
            "write-installability: the recorder's scratch directory is still named in the "
            f"log after redaction (looked for {SCRATCH_PREFIX!r}) — refusing rather than "
            "committing an absolute local path into a record other people read"
        )

    record["verbatim"] = SCRATCH_ID.sub("<cache-id>", verbatim)

    return record


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"installs", "blocked"}:
        sys.exit("usage: write-installability.py (installs|blocked)")

    record = installs() if sys.argv[1] == "installs" else blocked()

    print(json.dumps(record, **CANONICAL))


if __name__ == "__main__":
    main()
