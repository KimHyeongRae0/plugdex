#!/usr/bin/env python3
"""Measure what the acceptance gates cannot detect.

The gates in `acceptance.py` answer "does this compile". Reporting that as "does this
work" would be false. This script establishes exactly where the boundary is, by
injecting known defects into the pristine fixture and recording which gates fire.

Why it matters. In an empirical study of SWE-bench, 7.8% of patches judged to solve an
issue were functionally incorrect, and 50% of the incorrect patches were regressions
that broke unrelated functionality (arXiv 2503.15223). That is why the standard
practice pairs FAIL_TO_PASS (did it fix the thing) with PASS_TO_PASS (did it break
anything else). This script shows what still leaks through even with PASS_TO_PASS
wired in — the repository's own 60-test suite runs on every probe here.

Each probe injects one defect, runs every gate, and restores the file. `expect_caught`
is written before the run. Predictions that fail are recorded as failed.

Requires a Postgres instance for the backend test suite; see REPRODUCE.md.

Usage:
    python3 gate_probes.py [--out gate-limits.json]

Environment:
    DIC_FIXTURE   path to the seeded fixture repo
    PGHOST_ADDR / PGPORT_NUM   database the backend tests run against
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = Path(os.environ.get(
    "DIC_FIXTURE",
    ROOT / "arms/ponytail/benchmarks/agentic/fixtures/full-stack-fastapi-template"))
BACKEND = FIXTURE / "backend"
FRONTEND = FIXTURE / "frontend"
VENV_PY = BACKEND / ".venv-gate" / "bin" / "python"

DB_ENV = {"POSTGRES_SERVER": os.environ.get("PGHOST_ADDR", "127.0.0.1"),
          "POSTGRES_PORT": os.environ.get("PGPORT_NUM", "55432"),
          "POSTGRES_USER": "postgres", "POSTGRES_PASSWORD": "changethis", "POSTGRES_DB": "app"}


def run(cwd, args, timeout=420, env_extra=None):
    """Run a command and return (ok, output)."""
    env = {**os.environ, "CI": "1", "NO_COLOR": "1", **(env_extra or {})}

    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
        return p.returncode == 0, (p.stdout + p.stderr)[-3000:]
    except subprocess.TimeoutExpired:
        return False, f"[TIMEOUT {timeout}s]"


MYPY_BASELINE = None


def mypy_diags(output):
    """Line-number-independent set of mypy diagnostics."""
    out = set()

    for ln in output.splitlines():
        m = re.match(r"^([^:]+):\d+: error: (.*)$", ln.strip())

        if m:
            out.add((m.group(1), m.group(2)))

    return out


def backend_gates():
    """Run the four backend gates and report which ones pass.

    mypy is compared as a **delta** because the pristine fixture already emits one
    error. Comparing counts instead leaks syntax errors: on a parse failure mypy stops
    with `errors prevented further checking` and reports exactly one error, matching
    the baseline count and scoring as clean.
    """
    global MYPY_BASELINE
    ok_m, out_m = run(BACKEND, [str(VENV_PY), "-m", "mypy", "app"])
    ok_r, _ = run(BACKEND, [str(VENV_PY), "-m", "ruff", "check", "--output-format", "concise", "app"])
    ok_i, _ = run(BACKEND, [str(VENV_PY), "-c", "import app.main"])
    ok_t, _ = run(BACKEND, [str(VENV_PY), "-m", "pytest", "tests", "-q"], env_extra=DB_ENV)

    diags = mypy_diags(out_m)

    if MYPY_BASELINE is None:
        MYPY_BASELINE = diags

    mypy_clean = ok_m or not (diags - MYPY_BASELINE)

    return {"mypy": mypy_clean, "ruff": ok_r, "import": ok_i, "pytest": ok_t}


def frontend_gates():
    """Run the two frontend gates (typecheck, bundle build)."""
    ok_t, _ = run(FRONTEND, ["npx", "tsc", "-p", "tsconfig.build.json", "--noEmit"])

    if not ok_t:
        return {"typecheck": False, "build": False}

    ok_b, _ = run(FRONTEND, ["npx", "vite", "build"])

    return {"typecheck": True, "build": ok_b}


# (id, domain, defect, target file, anchor, replacement, prediction written before the run)
PROBES = [
    ("be-type-error", "backend", "type mismatch (returns int where str is declared)",
     "app/utils.py", "def generate_password_reset_token(email: str) -> str:",
     "def generate_password_reset_token(email: str) -> str:\n"
     "    if email == '__probe__':\n        return 1  # probe: wrong return type\n", True),

    ("be-owner-filter", "backend", "owner filter dropped from the list query — other users' rows leak",
     "app/api/routes/items.py",
     ".where(Item.owner_id == current_user.id)\n            .order_by", ".order_by", False),

    ("be-sort-flip", "backend", "sort direction reversed (newest-first becomes oldest-first)",
     "app/api/routes/items.py", "col(Item.created_at).desc()", "col(Item.created_at).asc()", False),

    ("be-off-by-one", "backend", "page size off by one (limit becomes limit - 1)",
     "app/api/routes/items.py", ".offset(skip).limit(limit)", ".offset(skip).limit(limit - 1)", False),

    ("be-syntax-error", "backend", "syntax error (file does not parse) — regression check for the delta gate",
     "app/utils.py", "def generate_password_reset_token(email: str) -> str:",
     "def generate_password_reset_token(email: str -> str:\n", True),

    ("be-swallow-404", "backend", "missing item returns None instead of raising 404",
     "app/api/routes/items.py",
     'raise HTTPException(status_code=404, detail="Item not found")', "return None", False),
]

FE_PROBES = [
    ("fe-render-nothing", "frontend", "component renders nothing (early null return)",
     "src/components/Common/NotFound.tsx", "const NotFound = () => {",
     "const NotFound = () => {\n  if (true) return null\n", False),

    ("fe-type-error", "frontend", "type mismatch (number assigned to string)",
     "src/__probe.tsx", None,
     "export const Probe = ({ n }: { n: number }) => {\n  const s: string = n\n  return <div>{s}</div>\n}\n", True),
]


def apply_probe(path, old, new):
    """Apply a probe and return the original contents. A None anchor writes a new file."""
    if old is None:
        if path.exists():
            original = path.read_text(encoding="utf-8")
            path.write_text(new, encoding="utf-8")
            return original

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(new, encoding="utf-8")

        return None

    original = path.read_text(encoding="utf-8")

    if old not in original:
        raise RuntimeError(f"probe anchor not found in {path.name}")

    path.write_text(original.replace(old, new, 1), encoding="utf-8")

    return original


def restore(path, original):
    """Undo a probe."""
    if original is None:
        path.unlink(missing_ok=True)
        return

    path.write_text(original, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="gate-limits.json")
    a = ap.parse_args()

    print("measuring baseline...", flush=True)
    base_be = backend_gates()
    base_fe = frontend_gates()
    print(f"  backend {base_be}\n  frontend {base_fe}", flush=True)

    if not all(base_be.values()) or not all(base_fe.values()):
        sys.exit("the pristine fixture does not pass its own gates; probes are meaningless "
                 "against a broken baseline")

    results = []

    for pid, domain, desc, rel, old, new, expect in PROBES + FE_PROBES:
        root = BACKEND if domain == "backend" else FRONTEND
        path = root / rel

        try:
            original = apply_probe(path, old, new)
        except (RuntimeError, OSError) as e:
            print(f"  {pid:20} skipped ({e})", flush=True)
            continue

        try:
            gates = backend_gates() if domain == "backend" else frontend_gates()
        finally:
            restore(path, original)

        caught_by = [g for g, ok in gates.items() if not ok]
        caught = bool(caught_by)
        results.append({"id": pid, "domain": domain, "defect": desc, "file": rel,
                        "gates": gates, "caught": caught, "caught_by": caught_by,
                        "predicted_caught": expect, "prediction_held": caught == expect})
        mark = "caught" if caught else "MISSED"
        flag = "" if caught == expect else "   <- prediction failed"
        print(f"  {pid:20} {mark:7} {caught_by or '(passed every gate)'}{flag}", flush=True)

    after_be = backend_gates()
    after_fe = frontend_gates()
    clean = all(after_be.values()) and all(after_fe.values())
    print(f"\nrestore check: backend {after_be} / frontend {after_fe} -> "
          f"{'clean' if clean else 'DIRTY, results invalid'}")

    caught_n = sum(1 for r in results if r["caught"])
    out = {"baseline": {"backend": base_be, "frontend": base_fe},
           "restored_clean": clean,
           "summary": {"probes": len(results), "caught": caught_n, "missed": len(results) - caught_n},
           "probes": results}
    Path(a.out).write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"wrote {a.out} — {caught_n} of {len(results)} probes caught, "
          f"{len(results) - caught_n} passed every gate")


if __name__ == "__main__":
    main()
