## [I-01] Makefile · angreal 통합 — 구현 리포트

TS 바인딩을 기존 빌드·테스트 파이프라인에 편입했습니다. `Makefile` 에 7개 삽입 지점(조사로 확정), `.angreal/task_test.py` 에 `ts` 커맨드 + `test_bindings` 호출을 추가했습니다.

> 화면 없는 인프라 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **`test-ts` 는 `install-bundled-ts` 에 의존**(Rust 처럼 바이너리 복사 필요, Python 은 build/ 런타임 탐색이라 `extension` 만 — 비대칭) | ✅ `make -n test ts` 가 `install-bundled-ts`(npm 복사) → `node --test` 순서로 전개 |
| `make test ts`, `make test bindings`, `angreal test ts` 동작 | ✅ `make test ts` 의 최종 레시피 `node --test` → **200/200**, `make test bindings` 체인에 test-ts 포함. `angreal test ts` 는 문법·구조 검증(angreal 미설치 환경, 아래 명시) |
| 확장 미빌드 시 자동 빌드 | ✅ Makefile 은 `extension` 의존, angreal 은 `ensure_extension_built` 가드 |

### 동작 실증

```text
$ make -n test ts        # test-ts → install-bundled-ts → node --test
  mkdir -p bindings/typescript/npm/darwin-arm64
  cp build/graphqlite.dylib bindings/typescript/npm/darwin-arm64/graphqlite.dylib
  echo "Running TypeScript binding tests..."
  cd bindings/typescript && node --test

$ make -n test bindings  # 체인에 test-ts 포함
  Running Rust binding tests... / Running Python binding tests... / Running TypeScript binding tests...
  cd bindings/typescript && node --test

$ (test-ts 최종 레시피) node --test
  tests 200 / pass 200 / fail 0 / skipped 0

install-bundled-ts 산출물: bindings/typescript/npm/darwin-arm64/graphqlite.dylib   (platform.ts getPlatformKey 규칙)

task_test.py: name="ts" 커맨드 + test_ts() + test_bindings 본문에 test_ts(verbose=verbose) 호출 (ast 파싱 OK)
```

### Makefile 삽입 지점 (7종)
1. `PYTHON_BINDINGS_DIR` 다음 → `TS_BINDINGS_DIR = bindings/typescript`
2. `install-bundled` 직후 → `install-bundled-ts`(UNAME_S/UNAME_M 분기, 대상 `$(TS_BINDINGS_DIR)/npm/<platform>-<arch>/graphqlite.<ext>`)
3. `test-ts: extension install-bundled-ts` → `cd $(TS_BINDINGS_DIR) && node --test`
4. `test-bindings: test-rust test-python` → `test-ts` 추가
5. `MAKECMDGOALS` 필터에 `ts` 분기 + 더미 타깃 줄에 `ts`
6. `.PHONY` 에 `test-ts ts install-bundled-ts`
7. `help` echo 블록에 `make test ts` 한 줄

### angreal 실행 검증 한계 (정직하게)
`angreal` 이 이 환경에 **미설치**되어 `angreal test ts` 를 직접 실행하지 못했습니다. 대신 `.angreal/task_test.py` 를 ast 로 파싱해 문법·구조(커맨드 정의, test_bindings 호출)를 검증했고, `test_python` 과 동일한 `subprocess.run(["node","--test"], cwd=ts_dir)` 스타일(run_make 아님)을 따릅니다.

또한 워크트리에서 C 확장을 **처음부터 재빌드**하는 전체 경로(`make test ts` 완주)는 이 환경의 오래된 `bison`(`%code` 미지원)에 막힙니다 — 제 변경과 무관한 기존 툴체인 한계라, 메인 저장소의 프리빌트 `build/graphqlite.dylib` 로 레시피(make -n)·실제 테스트·install-bundled-ts 복사부를 검증했습니다.

### Before → After
- **Before** (`origin/main` `8bdd5e4`): Makefile·task_test.py 에 TS 관련 전무, `bindings/typescript/npm/` 부재.
- **After**: TS 가 빌드·테스트 파이프라인에 편입, `make test ts`/`make test bindings` 동작, angreal `ts` 커맨드 추가.

### 변경 파일
- `Makefile` — 7개 삽입 지점(TS_BINDINGS_DIR·install-bundled-ts·test-ts·test-bindings·필터·PHONY·help)
- `.angreal/task_test.py` — `ts` 커맨드 + `test_bindings` 에 `test_ts` 호출

### 증거 원본
- baseline: `.issue/24/evidence/before/state.txt`
- 레시피/테스트: `.issue/24/evidence/after/make-recipes.txt`, `after/tests.txt`, `after/install-bundled-ts.txt`
- angreal 검증: `.issue/24/evidence/after/angreal.txt`
- 동작 실증: `.issue/24/evidence/after/behavior.txt`
