## [F-03] 에러 계층 (errors.ts) — 작업 리포트

코어가 던지는 `{"error":"...","code":"..."}` JSON 을 타입화된 예외 계층으로 매핑했습니다. Python 이 버리는 `code` 를 TS 는 클래스와 필드로 살립니다. UI 없는 로직 작업이라 증거는 테스트·타입 검사 출력으로 남깁니다.

### 생성 파일
```
bindings/typescript/src/errors.ts         # GraphQLiteError 계층 + graphQLiteErrorFrom 팩토리
bindings/typescript/test/errors.test.ts   # node:test 10개 케이스
```

### GQL_ERR_* 전수 조사 (`src/include/runtime/gql_error.h:17-22`)
| 코어 코드 | → TS 클래스 |
|---|---|
| `PARSE_ERROR` | `ParseError` (`Line N, Col M` → line/column) |
| `VALIDATION_ERROR` | `ValidationError` |
| `EXECUTION_ERROR` | `ExecutionError` |
| `MEMORY_ERROR` | `GraphQLiteError` (전용 서브클래스 없음, code 보존) |
| `INTERNAL_ERROR` | `GraphQLiteError` (동일) |
| `NOT_IMPLEMENTED` | `GraphQLiteError` (동일) |

미지의 코드도 `GraphQLiteError` 로 흡수하며 **throw 하지 않습니다**. 모든 에러가 원본 `query` 를 보존합니다.

### 검증 (Node v24.13.0 / npm 11.6.2)
```
$ npx tsc --noEmit
TypeScript: No errors found   # exit 0

$ npm test          # node --test
✔ maps the measured PARSE_ERROR payload to ParseError with line/column
✔ maps VALIDATION_ERROR to ValidationError
✔ maps EXECUTION_ERROR to ExecutionError
✔ known codes without a subclass fall back to base GraphQLiteError, code kept
✔ an unknown code is absorbed into the base class (never throws)
✔ a non-JSON raw string becomes a base error with the raw message and no code
✔ parseCoreError returns null for non-payload strings
✔ parseCoreError extracts error and optional code
✔ instanceof chain: ParseError → GraphQLiteError → Error
✔ ExtensionLoadError carries searchedPaths and a default code
ℹ tests 12 (errors 10 + smoke 2)   ℹ pass 12   ℹ fail 0
```

### 수용 기준 체크
- [x] 실측 `{"error":"Line 1, Col 10: ...","code":"PARSE_ERROR"}` → `ParseError { line:1, column:10 }`
- [x] `src/include/**` 의 `GQL_ERR_*` 6종 전수 조사 후 매핑 테이블 확정
- [x] 미지의 코드는 `GraphQLiteError` 폴백 (throw 안 함, 흡수)
- [x] 모든 에러가 원본 `query` 보존

### 스코프 메모
- `ExtensionLoadError` 는 여기(errors.ts)가 정본입니다. #2 의 `platform.ts` 최소본은 통합(#7) 시 이 정의를 import 하도록 재조정합니다.
- Python 언랩(`bindings/python/src/graphqlite/connection.py:151-176`)은 `sqlite3.Error(err_data["error"])` 로 code 를 버립니다 — 이 리그레션을 따라가지 않습니다.

### 참고
- 브랜치: `feat/3-issue-3`
- 커밋: `0ecbe01`
