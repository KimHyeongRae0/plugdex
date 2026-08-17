# plugdex

**The hub for agent behaviour packs — with the build receipts.**

Ponytail, superpowers, caveman, Karpathy's `CLAUDE.md`, Matt Pocock's skills, and
whatever ships next week. Browse them in one place, install them with one command, and
see what actually happened when we ran them.

Every pack in the catalogue advertises a headline: less code, fewer tokens, lower cost.
Those are real measurements. They are also, in every published benchmark we could find,
measured **without checking that the delivered code compiles**. plugdex runs each pack
against real tickets in a real repository, builds the code it delivers with that
repository's own build configuration, and publishes the result beside the listing —
including the exact ticket sent, the diff produced, and the compiler output verbatim.

Some of what that turns up:

- Roughly **half the delivered code does not build**, across two domains and two
  independent gate stacks.
- One widely installed pack **produces no code at all** in an unattended session — it
  classifies the ticket, asks a clarifying question, and stops. In 68 of 69 valid cells,
  across two models and two tool policies.
- A published token-reduction headline **did not reproduce**; the measured confidence
  interval excludes it.

## Two faces, one dataset

| | |
|---|---|
| **the site** | a browsable catalogue — one card per pack, a verdict chip, an install button, and a receipt behind every number |
| **the registry** | a generated Claude Code marketplace, so `claude plugin marketplace add plugdex` makes every listed pack installable by name |

The registry points at each pack's own repository. plugdex indexes; it does not vendor
anyone's code.

## Status

Early. The catalogue is being built ticket by ticket on top of measurements that are
already in this repository: [`bench/`](bench/) holds the harness and every graded run,
imported with its history intact so a preregistration still provably precedes the runs
it predicts. Numbers on the site are traceable to a fingerprinted run or they are not on
the site (DATA-01).

## Withdrawals

Claims this project has published and then retracted stay reachable, with the original
number, the cause, and what replaced it (CLAIM-01). A benchmark that only shows its wins
is a brochure.

## Development

Work here runs a 9-stage gate cycle — ticket, plan, cross review, test first, implement,
verify, report, cross review — where "done" means a script exited zero.

- [`CLAUDE.md`](CLAUDE.md) — project instructions and rules
- [`DESIGN.md`](DESIGN.md) — normative spec, reference designs, decision log
- [`docs/WORKFLOW.md`](docs/WORKFLOW.md) — the full workflow spec

```bash
./scripts/install-hooks.sh   # once per clone
./scripts/verify.sh          # the whole gate stack
./scripts/check-gates.sh     # the test for the gates
```

## Listing or removing a pack

Every listing names its author and links upstream (SRC-01). If you wrote a pack and want
it listed, corrected, or removed, open an issue — a removal request is honoured without
argument.

## License

MIT
