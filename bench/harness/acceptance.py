#!/usr/bin/env python3
"""Grade preserved cell workspaces on whether the delivered code actually builds.

The upstream harness scores a fixture task as correct like this:

    sc = {"correct": 1 if stats.get("total_loc", 0) > 0 else 0}   # run.py:303

"Correct" means a diff line exists. That cannot distinguish "ponytail finished in
24 lines" from "those 24 lines compile". This script measures the latter, using
only preserved workspaces, so it costs no API usage.

    Frontend   tsc -p tsconfig.build.json --noEmit   (strict, noUnusedLocals)
               vite build                            (only if typecheck passed)

    Backend    mypy app                              (strict; delta vs pristine)
               ruff check app                        (delta vs pristine)
               import smoke                          (runtime analogue of a bundle)

Scope. The task prompts carry no interface contract ("Add a date picker component
to the frontend"), so the agent chooses the component name, its location, and its
props. Whether the result is *correct as a date picker* cannot be graded
deterministically. What this measures is whether the code is alive. See
`gate_probes.py` for a measurement of exactly which defects this gate misses.

Usage:
    python3 acceptance.py <run_dir> [--regime blocked|as-shipped] [--workers 4]
                                    [--out acceptance.json]

Environment:
    DIC_FIXTURE   path to the seeded fixture repo (defaults to the vendored copy)
"""
import argparse, hashlib, json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# The fixture is an npm workspace (`workspaces: ["frontend"]`), so node_modules is
# hoisted to the template root. Cells therefore get the symlink at their root, not
# under frontend/.
FIXTURE_ROOT = Path(os.environ.get(
    "DIC_FIXTURE",
    ROOT / "arms/ponytail/benchmarks/agentic/fixtures/full-stack-fastapi-template"))
SHARED_NM = FIXTURE_ROOT / "node_modules"

BACKEND = FIXTURE_ROOT / "backend"
VENV_PY = Path(os.environ.get("DIC_VENV", ROOT / ".gate-venv")) / "bin" / "python"

TSC_TIMEOUT = 300
BUILD_TIMEOUT = 420
PY_TIMEOUT = 300

# Diagnostics the pristine fixture already emits. This is the delta gate's baseline;
# only diagnostics absent from it count as new defects. The pristine backend does not
# pass mypy (app/utils.py: "Returning Any from function declared to return str").
# Grading it absolutely marks every backend cell as failing and yields the false
# headline "the packs collapse on the backend".
BASELINE_CACHE = {}

# Cell directory names have the form `<task>__<arm>__<model>__<rep>`.
CELL_RE = re.compile(r"^(?P<task>[^_].*?)__(?P<arm>[^_]+)__(?P<model>[^_]+)__(?P<rep>\d+)$")


def parse_cell(name):
    """Split a cell directory name into (task, arm, model, rep), or None if it isn't one."""
    m = CELL_RE.match(name)

    if not m:
        return None

    return m.group("task"), m.group("arm"), m.group("model"), int(m.group("rep"))


def run_cmd(cwd, args, timeout):
    """Run a command and return (ok, combined output). A timeout counts as failure."""
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                           timeout=timeout, env={**os.environ, "CI": "1", "NO_COLOR": "1"})
        return p.returncode == 0, (p.stdout + p.stderr)[-4000:]
    except subprocess.TimeoutExpired:
        return False, f"[TIMEOUT after {timeout}s]"
    except Exception as e:
        return False, f"[{type(e).__name__}] {e}"


def classify(output):
    """Bucket a typecheck/build failure by cause."""
    if "[TIMEOUT" in output:
        return "timeout"
    if re.search(r"Cannot find module '(?!@/)", output) or "ERR_MODULE_NOT_FOUND" in output:
        return "missing-dep"
    if re.search(r"error TS\d+", output):
        return "type-error"
    if "Rollup failed to resolve" in output or "Could not resolve" in output:
        return "unresolved-import"
    return "other"


def link_node_modules(cell_dir):
    """Decide which dependency set grades this cell, and report which one it was.

    Under the `as-shipped` regime the agent has a shell and installs its own dependencies, so
    the cell already carries a real node_modules. That is the correct thing to grade against —
    declaring a dependency and installing it is itself a result. Overwriting it with the shared
    link would erase the difference between the two regimes.
    """
    nm = cell_dir / "node_modules"

    if nm.is_symlink():
        return "shared"

    if nm.exists():
        return "cell-local"

    nm.symlink_to(SHARED_NM, target_is_directory=True)

    return "shared"


def npm_inventory():
    """Every top-level package actually installed in the shared node_modules, as `name@version`.

    The frontend verdict depends on this list. Whether `import { Command } from "cmdk"` is a
    failure to declare a dependency or a clean compile is decided here. Mid-experiment this list
    changed (2026-08-16 00:38, four packages appeared that no package.json declares) and the same
    task flipped from 4/12 passing to 12/12. Every result file therefore carries this fingerprint,
    and results with different fingerprints are never compared.
    """
    names = []

    for d in sorted(SHARED_NM.iterdir()) if SHARED_NM.is_dir() else []:
        if d.name.startswith("."):
            continue

        scoped = d.name.startswith("@")

        for e in (sorted(d.iterdir()) if scoped else [d]):
            pkg = e / "package.json"

            if not pkg.is_file():
                continue

            prefix = f"{d.name}/" if scoped else ""

            try:
                names.append(f"{prefix}{e.name}@{json.loads(pkg.read_text()).get('version', '?')}")
            except (json.JSONDecodeError, OSError):
                names.append(f"{prefix}{e.name}@unreadable")

    return sorted(names)


def declared_deps():
    """Every dependency the fixture's package.json files declare.

    The difference between this and what is installed is the set of packages that exist
    without anyone asking for them. That difference is how instrument failure 15 was
    caught — four packages installed into the shared node_modules mid-experiment, which
    moved a task from 4/12 passing to 12/12 and nearly shipped as a reproduction.

    Instrument failure 19: this function and the `npm_undeclared_toplevel` count it feeds
    were dropped when the harness was ported into this repository. Every one of the ten
    committed records carries that field and the ported grader could not produce it, so
    the grader had silently stopped being able to reproduce its own published data — and
    had lost the detector for the failure that forced a run to be withdrawn.
    """
    out = set()

    for rel in ("package.json", "frontend/package.json"):
        f = FIXTURE_ROOT / rel

        if not f.is_file():
            continue

        try:
            blob = json.loads(f.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue

        for key in ("dependencies", "devDependencies"):
            out |= set(blob.get(key) or {})

    return out


def python_gate_versions():
    """What the backend gate actually is, or why it is not there.

    Instrument failure 18: `environment()` recorded the venv as a path string and nothing
    else. A run graded with the venv missing produced byte-identical `npm_fingerprint`,
    every mypy and ruff diagnostic silently empty, and `import_ok` False on every backend
    cell — indistinguishable, in the stored record, from a clean run. A fingerprint that
    cannot tell "the gate passed" from "the gate was not installed" is not a fingerprint.
    """
    if not VENV_PY.exists():
        return {"python_gate_present": False, "mypy": None, "ruff": None}

    return {"python_gate_present": True,
            "mypy": run_cmd(BACKEND, [str(VENV_PY), "-m", "mypy", "--version"], 60)[1].strip(),
            "ruff": run_cmd(BACKEND, [str(VENV_PY), "-m", "ruff", "--version"], 60)[1].strip()}


def environment():
    """Fingerprint of the grading environment, stored with every result file."""
    inv = npm_inventory()
    _, ls_out = run_cmd(FIXTURE_ROOT, ["npm", "ls", "--depth=99"], 120)
    extraneous = sorted({m.group(1) for m in re.finditer(r"([@\w./-]+@[\d][^\s]*) extraneous", ls_out)})

    declared = declared_deps()
    undeclared = sorted(n for n in inv if n.rsplit("@", 1)[0] not in declared)

    return {"npm_packages": len(inv),
            "npm_fingerprint": hashlib.sha256("\n".join(inv).encode()).hexdigest()[:16],
            "npm_extraneous": extraneous,
            "npm_undeclared_toplevel": len(undeclared),
            "npm_installed": inv,
            "node": run_cmd(FIXTURE_ROOT, ["node", "--version"], 30)[1].strip(),
            "python_gate": str(VENV_PY),
            **python_gate_versions()}


SKIP_DIRS = {".git", "node_modules", "dist", ".venv", ".venv-gate",
             "__pycache__", ".ruff_cache", ".mypy_cache"}


def changed_files(cell_dir):
    """Return files the agent created **or modified**.

    `_fixture_files.json` is a list of seeded *paths* with no hashes, so comparing
    against it alone finds new files and misses edits. Backend tasks append routes to
    the existing `items.py`, which made 43 of 85 backend cells register as "wrote no
    code". Content is therefore compared against the pristine fixture directly.

    A cell that wrote nothing leaves the workspace pristine and so passes every gate
    for free. "Passed because it works" and "passed because it did nothing" must stay
    distinguishable.
    """
    manifest = cell_dir / "_fixture_files.json"

    if not manifest.exists():
        return None

    seeded = set(json.loads(manifest.read_text(encoding="utf-8")))
    out = []

    for p in cell_dir.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP_DIRS for part in p.relative_to(cell_dir).parts):
            continue

        rel = str(p.relative_to(cell_dir)).replace("\\", "/")

        if rel.startswith("_claude") or rel == "_fixture_files.json":
            continue

        if rel not in seeded:
            out.append(rel)
            continue

        origin = FIXTURE_ROOT / rel

        try:
            if origin.is_file() and origin.read_bytes() != p.read_bytes():
                out.append(rel)
        except OSError:
            continue

    return sorted(out)


def cell_died(cell_dir):
    """Return a reason string if the agent never actually ran, else None.

    The upstream harness records cells killed by a session limit or an auth failure as
    `valid=True` with `cost=0, turns=1, LOC=0, 0.4s`. Aggregating those produces the
    plausible and false conclusion that every pack wrote no code — in one run this hit
    72 of 165 cells. The CLI reports the failure as `is_error` / `terminal_reason`
    rather than the `error` key the harness checks, so this reads it directly.

    Instrument failure 17: a cell killed on the runner's 300s cap leaves a zero-byte
    result json, which parsed as a JSONDecodeError and was recorded as
    `unparseable-result-json` — a corrupt-data story for what is really a censored
    observation. All 9 dead cells in the corpus carried that wrong label. The
    distinction matters because the two have opposite consequences: malformed output is
    noise, while a timeout is a right-tail cut that lands preferentially on the arms and
    tasks that take longest, so it biases the comparison rather than merely shrinking it.
    The runner already writes the marker; the grader simply never read it.
    """
    j = cell_dir / "_claude.json"
    stderr = cell_dir / "_claude.stderr.txt"

    # Read the kill marker before anything else. A killed cell is diagnosed by why it
    # died, not by the state of the file it did not get to finish writing.
    if stderr.exists() and b"[KILLED after" in stderr.read_bytes():
        return "killed-on-cell-timeout"

    if not j.exists():
        return "no-result-json"

    # An empty file is a cell that produced nothing, not a cell that produced garbage.
    # Letting json.loads report it hides which of the two happened.
    if j.stat().st_size == 0:
        return "empty-result-json"

    try:
        d = json.loads(j.read_text(encoding="utf-8"))
    except Exception:
        return "unparseable-result-json"

    if d.get("is_error"):
        return f"{d.get('terminal_reason') or 'error'}: {str(d.get('result') or '')[:80]}"
    if (d.get("total_cost_usd") or 0) <= 0 or (d.get("num_turns") or 0) <= 1:
        return "no-work (cost=0 or turns<=1)"

    return None


# ---------------------------------------------------------------------------
# Backend gate (mypy strict + ruff + import smoke), delta against the pristine repo
# ---------------------------------------------------------------------------

# Line numbers shift as the agent edits, so a diagnostic is identified by
# (file, code, message) only.
MYPY_RE = re.compile(
    r"^(?P<file>[^:]+):\d+:(?:\d+:)? (?P<sev>error|note): (?P<msg>.*?)(?:  \[(?P<code>[a-z-]+)\])?$")
# Modern ruff's default output is multi-line and does not match `file:line:col: CODE msg`,
# which silently parsed as zero diagnostics — unused imports, the single most common
# frontend failure, were being counted as clean. `--output-format concise` is required.
RUFF_RE = re.compile(r"^(?P<file>[^:]+):\d+:\d+: (?P<code>[A-Z]+\d+) (?:\[\*\] )?(?P<msg>.*)$")


def parse_diags(output, kind):
    """Build a line-number-independent set of diagnostics from mypy/ruff output."""
    rx = MYPY_RE if kind == "mypy" else RUFF_RE
    out = set()

    for ln in output.splitlines():
        m = rx.match(ln.strip())

        if not m:
            continue
        if kind == "mypy" and m.group("sev") != "error":
            continue

        out.add((kind, m.group("file"), m.group("code") or "", m.group("msg")))

    return out


def backend_baseline():
    """Compute the pristine backend's diagnostic baseline once and cache it."""
    if "backend" in BASELINE_CACHE:
        return BASELINE_CACHE["backend"]

    _, out_m = run_cmd(BACKEND, [str(VENV_PY), "-m", "mypy", "app"], PY_TIMEOUT)
    _, out_r = run_cmd(
        BACKEND, [str(VENV_PY), "-m", "ruff", "check", "--output-format", "concise", "app"], PY_TIMEOUT)
    base = parse_diags(out_m, "mypy") | parse_diags(out_r, "ruff")
    BASELINE_CACHE["backend"] = base

    return base


def score_backend(cell_dir, new_files):
    """Grade a cell's backend with the delta gate.

    Diagnostics already present in the pristine repo are excluded; only new ones count.
    The import smoke test is the runtime analogue of the frontend's `vite build`.
    """
    be = cell_dir / "backend"
    be_files = [f for f in (new_files or []) if f.startswith("backend/")]

    if not be.is_dir():
        return None

    base = backend_baseline()

    _, out_m = run_cmd(be, [str(VENV_PY), "-m", "mypy", "app"], PY_TIMEOUT)
    _, out_r = run_cmd(
        be, [str(VENV_PY), "-m", "ruff", "check", "--output-format", "concise", "app"], PY_TIMEOUT)
    new_diags = (parse_diags(out_m, "mypy") | parse_diags(out_r, "ruff")) - base

    ok_import, out_i = run_cmd(
        be, [str(VENV_PY), "-c", "import app.main; assert 'runs/' in app.main.__file__"], PY_TIMEOUT)

    return {"wrote_code": bool(be_files), "n_backend_files": len(be_files),
            "new_diags": sorted(new_diags)[:40], "n_new_diags": len(new_diags),
            "import_ok": ok_import, "import_out": None if ok_import else out_i[-1200:],
            "passes": bool(be_files and ok_import and not new_diags)}


def score_cell(cell_dir):
    """Grade one cell with the gate that matches its domain."""
    parsed = parse_cell(cell_dir.name)

    if not parsed:
        return None

    task, arm, model, rep = parsed
    died = cell_died(cell_dir)

    if died:
        return {"cell": cell_dir.name, "task": task, "arm": arm, "model": model, "rep": rep,
                "valid": False, "invalid_reason": died}

    if task.startswith("tmpl-be-"):
        new_files = changed_files(cell_dir)
        rec = score_backend(cell_dir, new_files)
        return {"cell": cell_dir.name, "task": task, "arm": arm, "model": model, "rep": rep,
                "valid": True, "domain": "backend", "new_files": new_files, **(rec or {})}

    fe = cell_dir / "frontend"

    if not fe.is_dir():
        return {"cell": cell_dir.name, "task": task, "arm": arm, "model": model, "rep": rep,
                "wrote_code": False, "typecheck": None, "build": None, "reason": "no-frontend-dir"}

    new_files = changed_files(cell_dir)
    fe_files = [f for f in (new_files or []) if f.startswith("frontend/")]

    deps = link_node_modules(cell_dir)

    ok_tsc, out_tsc = run_cmd(fe, ["npx", "tsc", "-p", "tsconfig.build.json", "--noEmit"], TSC_TIMEOUT)
    rec = {"cell": cell_dir.name, "task": task, "arm": arm, "model": model, "rep": rep,
           "valid": True, "domain": "frontend", "deps": deps, "wrote_code": bool(fe_files),
           "new_files": new_files, "n_frontend_files": len(fe_files),
           "typecheck": ok_tsc, "typecheck_reason": None if ok_tsc else classify(out_tsc),
           "typecheck_out": None if ok_tsc else out_tsc[-1200:]}

    if not ok_tsc:
        rec.update({"build": False, "build_reason": "skipped-typecheck-failed", "passes": False})
        return rec

    ok_build, out_build = run_cmd(fe, ["npx", "vite", "build"], BUILD_TIMEOUT)
    rec.update({"build": ok_build, "build_reason": None if ok_build else classify(out_build),
                "build_out": None if ok_build else out_build[-1200:],
                "passes": bool(ok_build and fe_files)})

    return rec


REGIMES = ("blocked", "as-shipped")


def resolve_regime(run_dir, flag):
    """The condition this run executed under, from the flag or from the run's own results.

    Refused rather than defaulted. The writer is the one place a wrong regime enters the
    corpus with nothing to contradict it, and the reader (`fisher.py`, `@plugdex/data`)
    now requires the field — so a record written without one is a record this project's
    own loader refuses. It is resolved before any grading work starts: a condition that
    cannot be established is a reason not to begin, not a reason to stop halfway through
    with a directory full of scored cells.
    """
    if flag is not None:
        if flag not in REGIMES:
            sys.exit(f"--regime {flag!r} is not one of {', '.join(REGIMES)}")

        return flag

    # Exactly `results.json`, not a glob. A `*results.json` pattern would let a stale
    # sibling — a copy, a timestamped variant — outrank the run's own file and decide the
    # condition, which is a filename choosing a governing fact by another route.
    candidate = run_dir / "results.json"

    if candidate.is_file():
        try:
            parsed = json.loads(candidate.read_text(encoding="utf-8"))
        except Exception as error:
            sys.exit(f"{candidate.name} is not readable JSON ({error}) — "
                     f"pass --regime {'|'.join(REGIMES)} instead of guessing")

        if not isinstance(parsed, dict):
            sys.exit(f"{candidate.name} is valid JSON but not an object "
                     f"({type(parsed).__name__}), so it carries no regime — "
                     f"pass --regime {'|'.join(REGIMES)} instead of guessing")

        recorded = parsed.get("regime")

        if recorded is not None:
            if recorded not in REGIMES:
                sys.exit(f"{candidate.name} records regime {recorded!r}, "
                         f"which is not one of {', '.join(REGIMES)}")

            return recorded

    sys.exit(f"no regime for {run_dir.name}\n"
             f"pass --regime {'|'.join(REGIMES)}, or write it into the run's results.json\n"
             f"the loader requires it, and a guessed regime silently relabels the run")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--out", default=None)
    ap.add_argument("--regime", default=None,
                    help="the condition this run executed under; "
                         "read from the run's results.json when omitted")
    a = ap.parse_args()

    run_dir = Path(a.run_dir).resolve()

    # Before anything else, including the fixture checks below: an unestablished regime
    # means this run cannot produce a loadable record, so nothing is graded.
    regime = resolve_regime(run_dir, a.regime)

    cells = sorted(d for d in run_dir.iterdir() if d.is_dir() and parse_cell(d.name))

    if not SHARED_NM.is_dir():
        sys.exit(f"shared node_modules not found at {SHARED_NM}\n"
                 f"run `npm install` in the fixture first (see REPRODUCE.md)")

    # Backend grading without the venv does not fail loudly — mypy and ruff simply produce
    # nothing, which reads as a clean cell. Stop instead: a missing gate is an ungraded
    # run, not a passing one (instrument failure 18).
    if any(d.name.startswith("tmpl-be-") for d in cells) and not VENV_PY.exists():
        sys.exit(f"python gate not found at {VENV_PY}\n"
                 f"this run has backend cells and grading them without mypy/ruff would "
                 f"record zero diagnostics as a pass — set DIC_VENV (see REPRODUCE.md)")

    print(f"{len(cells)} cells, {a.workers} workers", flush=True)
    out = []

    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        for rec in ex.map(score_cell, cells):
            if rec is None:
                continue

            out.append(rec)

            if rec.get("valid") is False:
                mark = f"DEAD({rec['invalid_reason'][:34]})"
            elif not rec.get("wrote_code"):
                mark = "NO-CODE"
            elif rec.get("passes"):
                mark = "PASS"
            else:
                mark = f"FAIL({rec.get('typecheck_reason') or rec.get('build_reason')})"

            print(f"  {rec['cell']:52} {mark}", flush=True)

    env = environment()
    dest = Path(a.out) if a.out else run_dir / "acceptance.json"
    dest.write_text(json.dumps({"run": run_dir.name, "regime": regime, "env": env,
                                "cells": out},
                               indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nwrote {dest} ({len(out)} cells)")
    print(f"environment npm={env['npm_fingerprint']} ({env['npm_packages']} pkgs, "
          f"extraneous={len(env['npm_extraneous'])})")

    if env["npm_extraneous"]:
        print("WARNING: packages are installed that no package.json declares. This grading "
              f"cannot be compared with a different fingerprint -> {env['npm_extraneous']}")


if __name__ == "__main__":
    main()
