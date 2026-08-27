#!/usr/bin/env bash
#
# parity-check.sh — #30 [V-01] Python <-> TS 동작 대조 게이트
#
# Runs the shared parity scenarios (bindings/typescript/test/parity/scenarios.json)
# through BOTH the Python and TypeScript bindings, normalizes the outputs, and
# fails (exit 1) on any un-allowlisted divergence — naming the method + input.
#
# Modes:
#   --mode results  (default) : compare each method's normalized return value.
#   --mode cypher             : compare the Cypher query strings (+ params) each
#                               binding emits to the C core. This captures ONLY
#                               what flows through Connection.cypher (every
#                               node/edge/query/algorithm method routes through
#                               it); it does not capture lower-level SQL, and a
#                               method that throws before reaching the core
#                               (e.g. TS identifier validation) emits nothing.
#                               Useful because a query-string diff pinpoints the
#                               cause faster than a result diff.
#
# The C core is never modified or rebuilt here — this only drives the two
# language bindings against an already-built extension.
#
# Extension staging (never hardcoded in binding source — injected here only):
#   The dylib source path is taken from $GQLITE_EXT_DYLIB. If unset it is
#   resolved to the first that exists:
#     1. <repo>/build/graphqlite.dylib          (canonical `make extension` output)
#     2. <repo>/bindings/typescript/npm/darwin-arm64/graphqlite.dylib  (staged CI artifact)
#   It is then (a) exported as GRAPHQLITE_EXTENSION_PATH (honored by both
#   bindings) and (b) copied to the Python package's bundled search location
#   (bindings/python/src/graphqlite/graphqlite.dylib, i.e. _platform.py path #1).
#
set -euo pipefail

MODE="results"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-results}"; shift 2 ;;
    --mode=*)
      MODE="${1#*=}"; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" != "results" && "$MODE" != "cypher" ]]; then
  echo "Invalid --mode: $MODE (expected 'results' or 'cypher')" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARITY_DIR="$ROOT/bindings/typescript/test/parity"
VENV="${GQLITE_PARITY_VENV:-/tmp/gqlite-parity-venv}"
PYBIN="${PYTHON:-python3}"

echo ">> GraphQLite parity check (mode=$MODE)"
echo ">> repo: $ROOT"

# ── 1. Resolve + stage the extension dylib ────────────────────────────────────
resolve_dylib() {
  if [[ -n "${GQLITE_EXT_DYLIB:-}" ]]; then
    echo "$GQLITE_EXT_DYLIB"; return 0
  fi
  local candidates=(
    "$ROOT/build/graphqlite.dylib"
    "$ROOT/bindings/typescript/npm/darwin-arm64/graphqlite.dylib"
  )
  for c in "${candidates[@]}"; do
    [[ -f "$c" ]] && { echo "$c"; return 0; }
  done
  echo ""; return 1
}

DYLIB="$(resolve_dylib || true)"
if [[ -z "$DYLIB" || ! -f "$DYLIB" ]]; then
  echo "ERROR: extension dylib not found. Set GQLITE_EXT_DYLIB or build with 'make extension'." >&2
  exit 3
fi
export GRAPHQLITE_EXTENSION_PATH="$DYLIB"
echo ">> extension: $DYLIB"

# Stage into the Python package's bundled search path (_platform.py candidate #1).
PY_PKG_DIR="$ROOT/bindings/python/src/graphqlite"
cp -f "$DYLIB" "$PY_PKG_DIR/graphqlite.dylib"
echo ">> staged Python bundled dylib: $PY_PKG_DIR/graphqlite.dylib"

# ── 2. Python venv + editable install ─────────────────────────────────────────
if [[ ! -d "$VENV" ]]; then
  echo ">> creating venv: $VENV"
  "$PYBIN" -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"

if ! python -c "import graphqlite" >/dev/null 2>&1; then
  echo ">> pip install -e bindings/python"
  pip install -q --disable-pip-version-check -e "$ROOT/bindings/python"
fi

# ── 3. TypeScript deps ────────────────────────────────────────────────────────
TS_DIR="$ROOT/bindings/typescript"
if [[ ! -d "$TS_DIR/node_modules" ]]; then
  echo ">> npm ci (typescript bindings)"
  ( cd "$TS_DIR" && npm ci --silent )
fi

# ── 4. Run both runners ───────────────────────────────────────────────────────
PY_OUT="$(mktemp -t gqlite-parity-py.XXXXXX.json)"
TS_OUT="$(mktemp -t gqlite-parity-ts.XXXXXX.json)"
trap 'rm -f "$PY_OUT" "$TS_OUT"' EXIT

echo ">> running Python runner"
python "$PARITY_DIR/run_python.py" --mode "$MODE" > "$PY_OUT"

echo ">> running TypeScript runner"
( cd "$TS_DIR" && node "$PARITY_DIR/run-ts.ts" --mode "$MODE" ) > "$TS_OUT"

# ── 5. Compare + report ───────────────────────────────────────────────────────
echo ">> comparing"
set +e
python "$PARITY_DIR/compare.py" --mode "$MODE" --python "$PY_OUT" --ts "$TS_OUT"
STATUS=$?
set -e

exit $STATUS
