## [G-02] 공개 API 표면 확정 — 구현 리포트

모든 기능 원소(#13~#22)가 끝난 뒤 공개 API 표면을 확정했습니다. `graph`/`connect`/`wrap`/`graphs` 팩토리 + 모든 타입·에러 클래스 + 버전 상수를 export 하고, `graphqlite/async` 서브패스와 `.d.ts` 빌드를 정의했습니다. 참조는 `bindings/python/src/graphqlite/__init__.py`(`__version__`, `__all__`), `tests/test_connection.py`(`test_exports`).

> 화면 없는 메타/설정 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| Python `test_exports`/`test_version_exists` 에 대응하는 표면 검증 테스트 | ✅ `test/exports.test.ts` (팩토리·클래스·에러 계층·VERSION·서브패스) |
| **버전 상수 export** | ✅ `VERSION = "0.7.0"` (package.json `version` 과 일치, 테스트로 강제) |
| **`graphqlite/async` 서브패스를 package.json `exports` 에 정의** | ✅ `"./async": "./src/async.ts"` + 실존 모듈(동기 표면 re-export, worker_threads 오프로딩은 #29 예고) |
| `tsc --noEmit` 통과 + **`.d.ts` 생성** | ✅ noEmit 무오류, `tsconfig.build.json` 로 `.d.ts` **22개** 생성 |

### 동작 실증 (Node v24.13.0)

```text
VERSION                   "0.7.0"
package.json version      "0.7.0" (VERSION과 일치: true)
exports 필드              {".":"./src/index.ts","./async":"./src/async.ts","./package.json":"./package.json"}
팩토리 typeof             connect:function wrap:function graph:function graphs:function
에러 클래스 export        true   (GraphQLiteError/ParseError/ValidationError/ExecutionError/UnsupportedOperationError/ExtensionLoadError)
graphqlite/async 표면 동일 true
공개 export 총 개수        66
```

`.d.ts` 생성(발췌): `dist/index.d.ts`, `dist/version.d.ts`, `dist/async.d.ts`, `dist/manager.d.ts` … 총 22개.

### 설계 메모
- **버전 단일 출처 아님**: `src/version.ts` 의 `VERSION` 과 `package.json` `version` 을 각각 두되, `exports.test.ts` 가 둘의 일치를 강제해 드리프트를 막습니다(Python 도 문자열 리터럴 `__version__`).
- **async 서브패스는 정직한 placeholder**: 이 원소는 서브패스 *매핑을 정의*하는 범위입니다. `src/async.ts` 는 실존·타입체크되는 모듈로 현재는 동기 표면을 re-export 하며, worker_threads 오프로딩은 #29 에서 이 진입점을 채웁니다. 소비자는 지금 import 경로를 옮겨 두면 #29 이후 재편집 없이 비동기 이점을 얻습니다.

### Before → After
- **Before** (`origin/main` `503173f`): version.ts/async.ts/exports.test.ts/tsconfig.build.json 부재, exports 는 `.` 만, 193 테스트.
- **After**: 버전·에러 계층·async 서브패스 공개, `.d.ts` 빌드, **200 테스트** — 확장 有 200/200, `tsc --noEmit` 무오류.

### 변경 파일
- `src/version.ts` (신규) — `VERSION`
- `src/async.ts` (신규) — `graphqlite/async` 진입점(동기 표면 re-export, #29 예고)
- `src/index.ts` — 에러 계층 6종 + `VERSION` re-export
- `package.json` — `exports` 에 `./async`·`./package.json`, `build` 스크립트
- `tsconfig.build.json` (신규) — `emitDeclarationOnly` .d.ts 빌드
- `test/exports.test.ts` (신규) — 표면 검증 7종
- `test/smoke.test.ts` — 에러 계층·VERSION 반영

### 증거 원본
- baseline: `.issue/23/evidence/before/state.txt`
- 테스트/타입체크/d.ts: `.issue/23/evidence/after/tests.txt`, `after/typecheck.txt`, `after/dts.txt`
- 동작 실증: `.issue/23/evidence/after/behavior.txt`
