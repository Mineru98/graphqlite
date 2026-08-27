#!/usr/bin/env python3
"""Normalize + compare the Python and TS parity runner outputs (#30 [V-01]).

Reads the two JSON documents produced by run_python.py and run-ts.ts, normalizes
both with the *same* canonicalization so cosmetic differences collapse (the
bindings differ only in key casing — TS camelCase vs Python snake_case), then
compares every scenario/step. Genuine value or behavior divergences fail the
gate (exit 1) with a report naming the scenario, step, method, args, and both
sides' values. Intended divergences listed in allowlist.json are reported but do
not fail.

Normalization (results mode):
  * dict keys camelCase -> snake_case (recursively), then sorted
  * floats rounded to 1e-6
  * arrays canonically sorted (row order across bindings is not meaningful)

Cypher mode compares the ordered list of emitted Cypher calls (query string +
params) element-by-element (order IS meaningful there); param dicts are
normalized like values.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

_CAMEL_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")
FLOAT_NDIGITS = 6


def to_snake(key: str) -> str:
    return _CAMEL_BOUNDARY.sub("_", key).lower()


def normalize(value, sort_lists: bool = True):
    """Canonicalize a value for cross-binding comparison."""
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        # Compare numbers by value, not representation: Python safe_float yields
        # 1.0 where JS safeFloat yields 1 for the same score. Coerce every
        # non-bool number to a rounded float so int-vs-float noise collapses
        # while genuine value differences still surface. (-0.0 -> 0.0.)
        return round(float(value), FLOAT_NDIGITS) + 0.0
    if isinstance(value, dict):
        norm = {to_snake(k): normalize(v, sort_lists) for k, v in value.items()}
        return dict(sorted(norm.items()))
    if isinstance(value, list):
        items = [normalize(v, sort_lists) for v in value]
        if sort_lists:
            items.sort(key=lambda x: json.dumps(x, sort_keys=True, ensure_ascii=False))
        return items
    return value


def canon(value) -> str:
    return json.dumps(value, sort_keys=True, ensure_ascii=False)


def comparable_results(step: dict) -> tuple:
    if step.get("status") == "error":
        err = step.get("error") or {}
        return ("error", err.get("type"))
    return ("ok", canon(normalize(step.get("value"))))


def comparable_cypher(step: dict) -> str:
    calls = step.get("cypher") or []
    # Order matters: normalize each call but preserve the call sequence.
    norm = [
        {"query": c.get("query"), "params": normalize(c.get("params"))}
        for c in calls
    ]
    return canon(norm)


def load_allowlist(path: str, mode: str) -> dict:
    data = json.loads(Path(path).read_text())
    allowed = {}
    for entry in data.get("allow", []):
        modes = entry.get("modes", ["results", "cypher"])
        if mode in modes:
            allowed[entry["id"]] = entry.get("reason", "")
    return allowed


def index_steps(doc: dict) -> dict:
    idx = {}
    for scenario in doc.get("scenarios", []):
        for step in scenario.get("steps", []):
            idx[(scenario["id"], step["id"])] = step
    return idx


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare Python vs TS parity output")
    parser.add_argument("--python", required=True)
    parser.add_argument("--ts", required=True)
    parser.add_argument("--mode", choices=["results", "cypher"], default="results")
    parser.add_argument(
        "--allowlist",
        default=str(Path(__file__).with_name("allowlist.json")),
    )
    args = parser.parse_args()

    py_doc = json.loads(Path(args.python).read_text())
    ts_doc = json.loads(Path(args.ts).read_text())
    allowlist = load_allowlist(args.allowlist, args.mode)

    py_idx = index_steps(py_doc)
    ts_idx = index_steps(ts_doc)

    all_keys = list(dict.fromkeys(list(py_idx) + list(ts_idx)))

    matched = 0
    allowlisted = 0
    mismatches = []

    for key in all_keys:
        scenario_id, step_id = key
        dotted = f"{scenario_id}.{step_id}"
        py_step = py_idx.get(key)
        ts_step = ts_idx.get(key)

        if py_step is None or ts_step is None:
            side = "TS" if py_step is not None else "Python"
            if dotted in allowlist:
                allowlisted += 1
                continue
            mismatches.append({
                "scenario": scenario_id, "step": step_id,
                "method": (py_step or ts_step or {}).get("method"),
                "args": (py_step or ts_step or {}).get("args"),
                "reason": f"missing on {side} side",
                "python": py_step, "ts": ts_step,
            })
            continue

        if args.mode == "cypher":
            py_cmp = comparable_cypher(py_step)
            ts_cmp = comparable_cypher(ts_step)
        else:
            py_cmp = comparable_results(py_step)
            ts_cmp = comparable_results(ts_step)

        if py_cmp == ts_cmp:
            matched += 1
            continue

        if dotted in allowlist:
            allowlisted += 1
            continue

        mismatches.append({
            "scenario": scenario_id, "step": step_id,
            "method": py_step.get("method"), "args": py_step.get("args"),
            "python": _display(py_step, args.mode),
            "ts": _display(ts_step, args.mode),
        })

    _report(args.mode, matched, allowlisted, mismatches, allowlist)
    return 1 if mismatches else 0


def _display(step: dict, mode: str):
    if mode == "cypher":
        return step.get("cypher")
    if step.get("status") == "error":
        return {"error": step.get("error")}
    return {"value": normalize(step.get("value"))}


def _report(mode, matched, allowlisted, mismatches, allowlist) -> None:
    print("=" * 72)
    print(f"GraphQLite parity report — mode: {mode}")
    print("=" * 72)
    print(f"  matched (identical)   : {matched}")
    print(f"  allowlisted (skipped) : {allowlisted}")
    print(f"  mismatches (failures) : {len(mismatches)}")
    if allowlist:
        print("  allowlist entries active for this mode:")
        for k, reason in allowlist.items():
            print(f"    - {k}: {reason}")
    if not mismatches:
        print("\nRESULT: PASS — all scenarios agree (allowlisted divergences aside).")
        return
    print("\nRESULT: FAIL — divergences found:\n")
    for m in mismatches:
        print("-" * 72)
        print(f"  scenario : {m['scenario']}")
        print(f"  step     : {m['step']}")
        print(f"  method   : {m.get('method')}")
        print(f"  input    : {json.dumps(m.get('args'), ensure_ascii=False)}")
        if "reason" in m:
            print(f"  reason   : {m['reason']}")
        print(f"  python   : {json.dumps(m.get('python'), ensure_ascii=False)}")
        print(f"  ts       : {json.dumps(m.get('ts'), ensure_ascii=False)}")
    print("-" * 72)


if __name__ == "__main__":
    raise SystemExit(main())
