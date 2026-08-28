#!/usr/bin/env bash
#
# run.sh — #86 cross-binding benchmark harness (Python / Rust / TypeScript).
#
# Runs the SAME set of operations (build / lookup / scan / pagerank / bfs)
# through all three language bindings against the SAME staged C-core dylib, then
# prints a comparison markdown table on stdout.
#
# CAVEAT: the three bindings share one C core (src/extension.c) loaded from one
# dylib (GRAPHQLITE_EXTENSION_PATH). This table therefore compares *binding-layer
# overhead* (bulk strategy, marshalling, per-call round-trips, result parsing) —
# NOT core algorithm speed. It is also machine-dependent. See benchmarks/README.md.
#
# Extension staging mirrors scripts/parity-check.sh: the dylib source is
# $GQLITE_EXT_DYLIB, else the first existing of
#   1. <repo>/build/graphqlite.dylib                                 (make extension)
#   2. <repo>/bindings/typescript/npm/darwin-arm64/graphqlite.dylib  (staged CI artifact)
# It is exported as GRAPHQLITE_EXTENSION_PATH (honored by all three bindings) and
# copied into the Python package's bundled search path. Rust builds with
# --no-default-features so it too loads the env dylib (not its embedded copy).
#
# Usage:
#   bash benchmarks/run.sh [--nodes 5000] [--edges 10000] [--repeats 3] [--lookups 2000]
set -euo pipefail

NODES=5000
EDGES=10000
REPEATS=3
LOOKUPS=2000
while [[ $# -gt 0 ]]; do
  case "$1" in
    --nodes)   NODES="${2:?}"; shift 2 ;;
    --edges)   EDGES="${2:?}"; shift 2 ;;
    --repeats) REPEATS="${2:?}"; shift 2 ;;
    --lookups) LOOKUPS="${2:?}"; shift 2 ;;
    --nodes=*)   NODES="${1#*=}"; shift ;;
    --edges=*)   EDGES="${1#*=}"; shift ;;
    --repeats=*) REPEATS="${1#*=}"; shift ;;
    --lookups=*) LOOKUPS="${1#*=}"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV="${GQLITE_PARITY_VENV:-/tmp/gqlite-parity-venv}"
PYBIN="${PYTHON:-python3}"

echo ">> GraphQLite binding benchmark" >&2
echo ">> repo: $ROOT" >&2
echo ">> params: nodes=$NODES edges=$EDGES repeats=$REPEATS lookups=$LOOKUPS" >&2

# ── 1. Resolve + stage the extension dylib ────────────────────────────────────
resolve_dylib() {
  if [[ -n "${GQLITE_EXT_DYLIB:-}" ]]; then echo "$GQLITE_EXT_DYLIB"; return 0; fi
  local candidates=(
    "$ROOT/build/graphqlite.dylib"
    "$ROOT/bindings/typescript/npm/darwin-arm64/graphqlite.dylib"
  )
  for c in "${candidates[@]}"; do [[ -f "$c" ]] && { echo "$c"; return 0; }; done
  echo ""; return 1
}

DYLIB="$(resolve_dylib || true)"
if [[ -z "$DYLIB" || ! -f "$DYLIB" ]]; then
  echo "ERROR: extension dylib not found. Set GQLITE_EXT_DYLIB or run 'make extension'." >&2
  exit 3
fi
export GRAPHQLITE_EXTENSION_PATH="$DYLIB"
if command -v shasum >/dev/null 2>&1; then
  DYLIB_SHA="$(shasum -a 256 "$DYLIB" | awk '{print $1}')"
else
  DYLIB_SHA="$(sha256sum "$DYLIB" | awk '{print $1}')"
fi
echo ">> extension: $DYLIB" >&2
echo ">> sha256:    $DYLIB_SHA" >&2

# Stage into the Python package's bundled search path (_platform.py candidate #1).
PY_PKG_DIR="$ROOT/bindings/python/src/graphqlite"
cp -f "$DYLIB" "$PY_PKG_DIR/graphqlite.dylib"

# ── 2. Python venv + editable install ─────────────────────────────────────────
if [[ ! -d "$VENV" ]]; then
  echo ">> creating venv: $VENV" >&2
  "$PYBIN" -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
if ! python -c "import graphqlite" >/dev/null 2>&1; then
  echo ">> pip install -e bindings/python" >&2
  pip install -q --disable-pip-version-check -e "$ROOT/bindings/python"
fi

# ── 3. TypeScript deps (best effort — the binding has no runtime deps) ─────────
TS_DIR="$ROOT/bindings/typescript"
if [[ ! -d "$TS_DIR/node_modules" && -f "$TS_DIR/package-lock.json" ]]; then
  echo ">> npm ci (typescript bindings)" >&2
  ( cd "$TS_DIR" && npm ci --silent ) || echo ">> npm ci failed (continuing; binding has no runtime deps)" >&2
fi

# ── 4. Run all three runners ──────────────────────────────────────────────────
PY_OUT="$(mktemp -t gqlite-bench-py.XXXXXX.json)"
TS_OUT="$(mktemp -t gqlite-bench-ts.XXXXXX.json)"
RS_OUT="$(mktemp -t gqlite-bench-rs.XXXXXX.json)"
PY_LOG="$(mktemp -t gqlite-bench-py.XXXXXX.log)"
TS_LOG="$(mktemp -t gqlite-bench-ts.XXXXXX.log)"
RS_LOG="$(mktemp -t gqlite-bench-rs.XXXXXX.log)"
trap 'rm -f "$PY_OUT" "$TS_OUT" "$RS_OUT" "$PY_LOG" "$TS_LOG" "$RS_LOG"' EXIT

ARGS=(--nodes "$NODES" --edges "$EDGES" --repeats "$REPEATS" --lookups "$LOOKUPS")
PY_OK=1; TS_OK=1; RS_OK=1

echo ">> [python] running" >&2
if ! python "$SCRIPT_DIR/python/bench.py" "${ARGS[@]}" >"$PY_OUT" 2>"$PY_LOG"; then
  PY_OK=0; echo ">> [python] FAILED (see log below)" >&2; cat "$PY_LOG" >&2
fi

echo ">> [typescript] running" >&2
if ! node "$SCRIPT_DIR/ts/bench.ts" "${ARGS[@]}" >"$TS_OUT" 2>"$TS_LOG"; then
  TS_OK=0; echo ">> [typescript] FAILED (see log below)" >&2; cat "$TS_LOG" >&2
fi

echo ">> [rust] building + running (cargo --release --no-default-features)" >&2
if ! ( cd "$SCRIPT_DIR/rust" && cargo run --quiet --release --no-default-features -- "${ARGS[@]}" ) >"$RS_OUT" 2>"$RS_LOG"; then
  RS_OK=0; echo ">> [rust] FAILED (see log below)" >&2; cat "$RS_LOG" >&2
fi

# ── 5. Combine + render comparison table ──────────────────────────────────────
UNAME_M="$(uname -m)"
UNAME_S="$(uname -s)"
if command -v sw_vers >/dev/null 2>&1; then
  OS_DESC="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
else
  OS_DESC="$(uname -sr)"
fi

RUSTC_VER="$(rustc --version 2>/dev/null | sed 's/(.*)//; s/^rustc //; s/ *$//' || echo unknown)"

BENCH_META="{\"nodes\":$NODES,\"edges\":$EDGES,\"repeats\":$REPEATS,\"lookups\":$LOOKUPS,\
\"dylib\":\"$DYLIB\",\"dylib_sha256\":\"$DYLIB_SHA\",\
\"machine\":\"$UNAME_M\",\"os\":\"$OS_DESC\",\"kernel\":\"$UNAME_S\",\"rustc\":\"$RUSTC_VER\",\
\"py_ok\":$PY_OK,\"ts_ok\":$TS_OK,\"rs_ok\":$RS_OK}" \
PY_OUT="$PY_OUT" TS_OUT="$TS_OUT" RS_OUT="$RS_OUT" \
python - <<'PY'
import json, os

def load(path, ok):
    if not ok:
        return None
    try:
        with open(path) as f:
            data = f.read().strip()
        return json.loads(data) if data else None
    except Exception:
        return None

meta = json.loads(os.environ["BENCH_META"])
py = load(os.environ["PY_OUT"], meta["py_ok"])
ts = load(os.environ["TS_OUT"], meta["ts_ok"])
rs = load(os.environ["RS_OUT"], meta["rs_ok"])

legs = [("Python", py), ("TypeScript", ts), ("Rust", rs)]
present = [(name, d) for name, d in legs if d is not None]

# Ordered op list (union, preserving the canonical order).
ORDER = ["build", "lookup", "scan", "pagerank", "bfs"]
def op_map(d):
    return {o["name"]: o for o in d.get("ops", [])} if d else {}
maps = {name: op_map(d) for name, d in legs}

def ver(d, keys):
    if not d:
        return "n/a"
    env = d.get("env", {})
    return " ".join(str(env.get(k)) for k in keys if env.get(k) is not None)

print("## Benchmark results — binding-layer overhead (shared C core)\n")
print(f"- Machine: `{meta['machine']}` ({meta['kernel']}), OS: {meta['os']}")
print(f"- Dataset: {meta['nodes']} nodes, {meta['edges']} edges, "
      f"{meta['lookups']} lookups; repeats={meta['repeats']} (median of {meta['repeats']}, 1 warm-up discarded)")
print(f"- Extension dylib: `{os.path.basename(meta['dylib'])}` sha256 `{meta['dylib_sha256']}`")
print(f"- Python: {ver(py, ['python','implementation'])} | "
      f"Node: {ver(ts, ['node'])} (V8 {ver(ts, ['v8'])}) | "
      f"Rust: rustc {meta.get('rustc','unknown')} ({ver(rs, ['profile'])} build)")
missing = [name for name, d in legs if d is None]
if missing:
    print(f"- **Legs that FAILED (excluded):** {', '.join(missing)}")
print()

print("### Median time per op (ms; lower is faster)\n")
header = "| op | " + " | ".join(f"{name} (ms)" for name, _ in legs) + " |"
sep = "|----|" + "|".join(["------"] * len(legs)) + "|"
print(header)
print(sep)
for op in ORDER:
    cells = []
    for name, _ in legs:
        o = maps[name].get(op)
        cells.append(f"{o['ms_median']:.3f}" if o else "—")
    print(f"| {op} | " + " | ".join(cells) + " |")
print()

# Sanity: result counts should agree across bindings (same shared core + dataset).
print("### Result-size sanity check (count per op; should match across bindings)\n")
print(header.replace("(ms)", "(count)"))
print(sep)
for op in ORDER:
    cells = []
    for name, _ in legs:
        o = maps[name].get(op)
        cells.append(str(o["count"]) if o else "—")
    print(f"| {op} | " + " | ".join(cells) + " |")
print()
print("_Note: op values are the median of N measured runs (warm-up discarded); "
      "`lookup` is the TOTAL wall time for all individual round-trips, not per call. "
      "The three bindings share one C core, so differences reflect binding-layer "
      "overhead (marshalling, round-trips, bulk strategy), not core algorithm speed._")
PY
