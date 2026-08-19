"""INST-01a and INST-01e — the structural half of the installability gate.

Prints one `PACK <name>` line per listing when everything joins and every record is usable,
and exits non-zero naming the violation otherwise. The behavioural half of the gate reads
those lines, so a structural failure stops the sweep before any install runs: a verdict
about a listing whose record is missing or unreadable would be a verdict about nothing.

Both directions of the join are checked. A listing with no record is the obvious hole; a
record for a pack nobody lists is the one that hides, because it looks like coverage.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

RECORDS = Path(os.environ["RECORDS"])
MARKETPLACE = Path(os.environ["MARKETPLACE"])
CLASSIFIER = Path(__file__).with_name("install-signature.py")

REQUIRED = ("pack", "repo", "cliVersion", "attemptedAt", "upstreamHead", "transport")

problems: list[str] = []

manifest = json.loads(MARKETPLACE.read_text(encoding="utf-8"))
listed = sorted(plugin["name"] for plugin in manifest.get("plugins", []))

# The repo a record names is derivable from the manifest, so a forged one is checkable
# offline and there is no reason to leave it unchecked. Report review round 2 changed a
# record's repo to `someone/else-entirely` and watched the whole gate pass, because nothing
# compared the two.
listed_repo = {}

for plugin in manifest.get("plugins", []):
    source = plugin.get("source") or {}
    listed_repo[plugin["name"]] = source.get("repo", "") if isinstance(source, dict) else ""

if not listed:
    sys.exit("INST-01a: the marketplace lists no plugins — refusing to pass over an empty set")

recorded = {}

for path in sorted(RECORDS.glob("*.json")):
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except Exception as error:
        problems.append(f"INST-01e: {path.name} is not readable JSON — {error}")
        continue

    if not isinstance(record, dict):
        problems.append(f"INST-01e: {path.name} is not a JSON object")
        continue

    name = record.get("pack")

    if name != path.stem:
        problems.append(
            f"INST-01e: {path.name} records pack {name!r} — the filename is not the fact (DATA-02)"
        )
        continue

    missing = [field for field in REQUIRED if not record.get(field)]

    if missing:
        problems.append(f"INST-01e: {path.name} is missing {', '.join(missing)}")
        continue

    if record.get("repo") != listed_repo.get(name):
        problems.append(
            f"INST-01e: {path.name} names repo {record.get('repo')!r} while the manifest lists "
            f"{listed_repo.get(name)!r} for this pack — a record about a different repository "
            "than the one a reader installs from is not a record about this listing"
        )
        continue

    outcome = record.get("outcome")

    if outcome == "installs":
        recorded[name] = record
        continue

    if outcome != "blocked":
        problems.append(
            f"INST-01e: {path.name} has outcome {outcome!r}, which this gate cannot act on — "
            "refused rather than skipped, so a malformed record never thins the sweep"
        )
        continue

    signature = record.get("signature") or {}
    keys = signature.get("keys")

    if not signature.get("kind") or not isinstance(keys, list) or not keys:
        problems.append(
            f"INST-01e: {path.name} is blocked with no usable signature — there is nothing "
            "for the gate to re-check, and an unre-checkable blocked record is a permanent "
            "excuse rather than a measurement"
        )
        continue

    if not record.get("verbatim"):
        problems.append(f"INST-01e: {path.name} is blocked and does not quote its own failure")
        continue

    # The record has to agree with itself: classify the failure it quotes and require the
    # answer to be the signature it carries. This is free — the classifier is right there —
    # and it closes a hole round 2 demonstrated by pairing an `agents` signature with a
    # verbatim quoting a `hooks` failure. Neither field was checkable alone; together they
    # are, because the classifier is the function that relates them.
    classified = subprocess.run(
        ["python3", str(CLASSIFIER)],
        input=record["verbatim"],
        capture_output=True,
        text=True,
    )

    if classified.returncode != 0:
        problems.append(
            f"INST-01e: {path.name} quotes a failure the classifier cannot name "
            f"({(classified.stdout or '').strip()}) — the gate could never reproduce it"
        )
        continue

    expected = f"SIGNATURE kind={signature['kind']} keys={','.join(sorted(keys))}"

    if classified.stdout.strip() != expected:
        problems.append(
            f"INST-01e: {path.name} disagrees with itself — its quoted failure classifies as "
            f"[{classified.stdout.strip()[len('SIGNATURE '):]}] but its signature says "
            f"[{expected[len('SIGNATURE '):]}]"
        )
        continue

    recorded[name] = record

unmeasured = [name for name in listed if name not in recorded]
unlisted = [name for name in sorted(recorded) if name not in listed]

if unmeasured:
    problems.append(f"INST-01a: listed with no usable record: {', '.join(unmeasured)}")

if unlisted:
    problems.append(f"INST-01a: recorded but not listed: {', '.join(unlisted)}")

if problems:
    for problem in problems:
        print(f"  x {problem}", file=sys.stderr)

    sys.exit(1)

for name in listed:
    print(f"PACK {name}")
