## [F-07] cypher() 왕복 (connection.ts) — 구현 리포트

`node:sqlite` 로 확장을 로드하고 `cypher()` UDF 를 왕복하는 드라이버 접촉면을 `src/connection.ts` 한 파일에 가뒀습니다. 참조 구현은 `bindings/python/src/graphqlite/connection.py`, 결과/에러/경로는 각각 `result.ts`(#4)·`errors.ts`(#3)·`platform.ts`(#2)에 위임합니다.

> 이 작업은 화면이 없는 라이브러리 원소라, 증거는 스크린샷이 아니라 **명령 출력·측정값**입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 빈 객체 `{}` 는 `SELECT cypher(?)` 무파라미터 경로 | ✅ `params != null && Object.keys(params).length > 0` 로 판정 (Python falsy-`{}` 분기와 동일) |
| 로드 후 `graphqlite_test()` 검증, `"successfully"` 없으면 실패 | ✅ 대소문자 무시 포함 검사, 없으면 `GraphQLiteError` throw |
| `ExperimentalWarning` **한 건만** 삼킴 + env 로 원복 | ✅ `GRAPHQLITE_SHOW_EXPERIMENTAL_WARNING=1` 로 원복 |
| `connect`/`wrap`/`close`/`execute`/`commit`/`rollback` 제공 | ✅ 전부 구현 |
| 에러는 F-03 계층으로 매핑 | ✅ 던져진 드라이버 에러 + 인밴드 `{"error":...}` 셀 모두 `graphQLiteErrorFrom` 로 승격 |

### 실측으로 확정한 이식 포인트 3가지

1. **확장자 이중화 방지** — `node:sqlite` 의 `loadExtension()` 은 플랫폼 접미사를 자동으로 덧붙입니다. `findExtension()` 이 돌려준 `graphqlite.dylib` 를 그대로 넘기면 `graphqlite.dylib.dylib` 로 dlopen 실패. Python 의 `Path.stem` 처럼 접미사를 **떼고** 넘깁니다.
2. **`$param` 은 SQLite 바인딩이 아니라 JSON 문자열** — `SELECT cypher(?, ?)` 에 `(query, JSON.stringify(params))` 로 왕복. 이식의 핵심.
3. **경고는 정적 import 의 링크 단계에서 발생** — 모듈 본문 코드로는 못 막습니다. `process.emitWarning` 오버라이드(env 가드·1회성)를 **먼저 설치**하고 `node:sqlite` 를 **동적 `await import`** 로 로드해야 억제됩니다.

### Before → After

**Before** (`origin/main`): `connection.ts` 부재, `index.ts` 는 런타임 export 없음, 61 테스트 통과.

**After**: 공개 표면 `connect`/`wrap`/`Connection` 추가, 전체 **73 테스트 통과 / 0 실패**, `tsc --noEmit` 무오류.

실제 확장(`build/graphqlite.dylib`, Node v24.13.0) 왕복:

```text
graphqlite_test 검증 통과 → connect() 성공
CREATE       : Query executed successfully - nodes created: 1, relationships created: 0
MATCH all    : [{"n.name":"Alice"}]
MATCH $param : [{"n.name":"Alice"}]
빈객체 {}    : [{"n.name":"Alice"}] (cypher(?) 무파라미터 경로)
에러 매핑    : ParseError / code=PARSE_ERROR / line=1 / col=1
```

경고 억제 실증 (fresh 프로세스에서 모듈 import 시 stderr):

```text
## 기본 (억제 ON)
(SQLite ExperimentalWarning 출력 없음 — 억제 성공)

## GRAPHQLITE_SHOW_EXPERIMENTAL_WARNING=1 (원복)
(node:XXXXX) ExperimentalWarning: SQLite is an experimental feature and might change at any time
```

### 변경 파일
- `src/connection.ts` (신규) — 확장 로더 + `cypher()` 왕복 + `connect`/`wrap`/`Connection`
- `src/index.ts` — F-07 공개 표면 re-export
- `test/connection.test.ts` (신규) — mock 주입 단위 테스트 + 서브프로세스 경고 억제 테스트 + 게이트된 실제 확장 통합 테스트
- `test/smoke.test.ts` — F-01 "export 없음" 단언을 새 공개 표면 기준으로 갱신

### 증거 원본
- 상태 baseline: `.issue/7/evidence/before/state.txt`
- 테스트/타입체크: `.issue/7/evidence/after/tests.txt`, `after/typecheck.txt`
- 왕복: `.issue/7/evidence/after/roundtrip.txt`
- 경고 억제: `.issue/7/evidence/after/warning-suppression.txt`
