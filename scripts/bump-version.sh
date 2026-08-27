#!/usr/bin/env bash
#
# bump-version.sh — GraphQLite 버전 진실의 원천을 한 번에 동기화한다.
#
# 버전 소스:
#   1. bindings/python/src/graphqlite/__init__.py   __version__
#   2. bindings/rust/Cargo.toml                     [package] version
#   3. bindings/rust/Cargo.lock                     graphqlite 패키지 블록 version
#   4. bindings/typescript/package.json             version
#   5. bindings/typescript/package.json             optionalDependencies["@graphqlite/*"] 5핀
#   6. bindings/typescript/src/version.ts           export const VERSION
#   7. bindings/typescript/package-lock.json        root version + packages[""].version
#
# 사용법:
#   scripts/bump-version.sh <version>          # 8곳을 <version> 으로 갱신
#   scripts/bump-version.sh --check <version>  # 8곳이 전부 <version> 인지 검증 (CI 게이트)
#
# --check 는 불일치가 하나라도 있으면 exit 1, 전부 일치하면 exit 0.
# 릴리스 워크플로우가 `태그(vX.Y.Z) == 파일 버전` 검증에 쓴다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PY_INIT="$ROOT/bindings/python/src/graphqlite/__init__.py"
CARGO_TOML="$ROOT/bindings/rust/Cargo.toml"
CARGO_LOCK="$ROOT/bindings/rust/Cargo.lock"
TS_PKG="$ROOT/bindings/typescript/package.json"
TS_VERSION_TS="$ROOT/bindings/typescript/src/version.ts"
TS_LOCK="$ROOT/bindings/typescript/package-lock.json"

# optionalDependencies 에 핀되는 플랫폼 서브패키지
SUBPACKAGES=(darwin-arm64 darwin-x64 linux-x64 linux-arm64 win32-x64)

usage() {
  cat >&2 <<'EOF'
usage:
  bump-version.sh <version>          8곳 버전을 <version> 으로 갱신
  bump-version.sh --check <version>  8곳이 전부 <version> 인지 검증 (불일치 시 exit 1)

<version> 은 semver (예: 1.2.3, 1.2.3-rc.1). 선행 'v' 는 붙이지 않는다.
EOF
  exit 2
}

validate_semver() {
  local v="$1"
  if ! printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'; then
    echo "error: '$v' 은 유효한 semver 가 아닙니다 (예: 1.2.3)" >&2
    exit 2
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "error: 파일을 찾을 수 없습니다: $1" >&2
    exit 3
  fi
}

# ---- 현재 값 읽기 --------------------------------------------------------

read_py()   { perl -ne 'if (/__version__\s*=\s*"([^"]+)"/) { print $1; exit }' "$PY_INIT"; }
read_cargo_toml() { perl -ne 'if (/^version\s*=\s*"([^"]+)"/) { print $1; exit }' "$CARGO_TOML"; }
read_cargo_lock() {
  awk '
    prev == "name = \"graphqlite\"" && /^version = / {
      line = $0
      sub(/^version = "/, "", line)
      sub(/".*$/, "", line)
      print line
      exit
    }
    { prev = $0 }
  ' "$CARGO_LOCK"
}
read_ts_version() { jq -r '.version' "$TS_PKG"; }
read_ts_pin()     { jq -r --arg k "@graphqlite/$1" '.optionalDependencies[$k] // ""' "$TS_PKG"; }
read_ts_const()   { perl -ne "if (/export const VERSION = '([^']+)'/) { print \$1; exit }" "$TS_VERSION_TS"; }
read_ts_lock_root() { jq -r '.version' "$TS_LOCK"; }
read_ts_lock_pkg()  { jq -r '.packages[""].version // ""' "$TS_LOCK"; }

# ---- 갱신 ---------------------------------------------------------------

update_all() {
  local v="$1"

  # 1. python __version__
  perl -i -pe 's/(__version__\s*=\s*")[^"]*(")/${1}'"$v"'${2}/' "$PY_INIT"

  # 2. Cargo.toml [package] version (라인 시작 version 만 매치; 의존성 version 은 인라인이라 제외)
  perl -i -pe 's/^(version\s*=\s*")[^"]*(")/${1}'"$v"'${2}/ if $. > 0 && /^version\s*=/' "$CARGO_TOML"

  # 3. Cargo.lock graphqlite 블록 version (name 라인 바로 다음 version)
  local tmp_lock
  tmp_lock="$(mktemp)"
  awk -v v="$v" '
    prev == "name = \"graphqlite\"" && /^version = / { sub(/"[^"]*"/, "\"" v "\"") }
    { print; prev = $0 }
  ' "$CARGO_LOCK" > "$tmp_lock"
  mv "$tmp_lock" "$CARGO_LOCK"

  # 4 & 5. package.json version + optionalDependencies 핀
  local tmp_pkg
  tmp_pkg="$(mktemp)"
  jq --arg v "$v" '
    .version = $v
    | (.optionalDependencies // {}) |= with_entries(
        if (.key | startswith("@graphqlite/")) then .value = $v else . end
      )
  ' "$TS_PKG" > "$tmp_pkg"
  mv "$tmp_pkg" "$TS_PKG"

  # 6. src/version.ts VERSION 상수 (exports.test.ts 가 package.json 과 일치를 검증)
  perl -i -pe "s/(export const VERSION = ')[^']*(')/\${1}$v\${2}/" "$TS_VERSION_TS"

  # 7. package-lock.json 의 self version 2곳 (root + packages[""]); npm ci 정합성 유지
  local tmp_lock2
  tmp_lock2="$(mktemp)"
  jq --arg v "$v" '.version = $v | .packages[""].version = $v' "$TS_LOCK" > "$tmp_lock2"
  mv "$tmp_lock2" "$TS_LOCK"
}

# ---- 검증 ---------------------------------------------------------------

# 각 위치를 "라벨\t실제값" 으로 출력
collect() {
  printf 'python  __init__.py\t%s\n' "$(read_py)"
  printf 'rust    Cargo.toml\t%s\n'  "$(read_cargo_toml)"
  printf 'rust    Cargo.lock\t%s\n'  "$(read_cargo_lock)"
  printf 'ts      package.json version\t%s\n' "$(read_ts_version)"
  local p
  for p in "${SUBPACKAGES[@]}"; do
    printf 'ts      @graphqlite/%s\t%s\n' "$p" "$(read_ts_pin "$p")"
  done
  printf 'ts      src/version.ts VERSION\t%s\n' "$(read_ts_const)"
  printf 'ts      package-lock.json root\t%s\n' "$(read_ts_lock_root)"
  printf 'ts      package-lock.json pkg\t%s\n'  "$(read_ts_lock_pkg)"
}

check_all() {
  local expected="$1"
  local mismatch=0
  local total=0
  local label value

  while IFS=$'\t' read -r label value; do
    total=$((total + 1))
    if [ "$value" = "$expected" ]; then
      printf '  ok    %-32s %s\n' "$label" "$value"
    else
      printf '  DIFF  %-32s %s (기대: %s)\n' "$label" "$value" "$expected"
      mismatch=$((mismatch + 1))
    fi
  done < <(collect)

  echo ""
  if [ "$mismatch" -ne 0 ]; then
    echo "✗ $total 곳 중 $mismatch 곳이 $expected 과 일치하지 않습니다" >&2
    return 1
  fi
  echo "✓ 버전 소스 $total 곳 모두 $expected 로 동기화되어 있습니다"
  return 0
}

# ---- 진입점 -------------------------------------------------------------

main() {
  [ "$#" -ge 1 ] || usage

  require_file "$PY_INIT"
  require_file "$CARGO_TOML"
  require_file "$CARGO_LOCK"
  require_file "$TS_PKG"
  require_file "$TS_VERSION_TS"
  require_file "$TS_LOCK"

  if [ "$1" = "--check" ]; then
    [ "$#" -eq 2 ] || usage
    validate_semver "$2"
    check_all "$2"
    return
  fi

  [ "$#" -eq 1 ] || usage
  case "$1" in
    -*) usage ;;
  esac
  validate_semver "$1"

  echo "버전을 $1 로 갱신합니다..."
  update_all "$1"
  echo ""
  check_all "$1"
}

main "$@"
