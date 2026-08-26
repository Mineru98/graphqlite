## [F-04] 결과 정규화 (result.ts) — 작업 리포트

`cypher()` 의 비균일 반환값(①행집합 ②노드객체 ③알고리즘 ④DDL 평문)을 흡수하는 `CypherResult` 정규화 계층을 구현했습니다. UI 없는 로직 작업이라 증거는 테스트·타입 검사 출력으로 남깁니다.

### 생성 파일
```
bindings/typescript/src/result.ts         # CypherResult + normalizeCypherResult + parseMutationSummary
bindings/typescript/test/result.test.ts   # node:test 11개 케이스
```

### Python 분기 대조 (`connection.py:162-192`)
| 입력 | → CypherResult |
|---|---|
| `null` / null 행 | 빈 결과 |
| list-of-dict (①②③) | `data`, columns = `keys(data[0])` |
| **스칼라 리스트 `[1,2,3]`** | **`[{result: "[1,2,3]"}]` (원본 문자열 보존)** |
| 단일 dict | `[data]`, columns = keys |
| 비-JSON 평문(④) | `[{result: raw}]` |

**스칼라/비-JSON 폴백을 "정리"하지 않고 원본 그대로 감쌉니다** — `getAllNodes` 등이 이 계약에 의존합니다.

### API
- `CypherResult`: 배열형(`length`/`result[0]`/`for..of`) + `toList()` + `columns` — 알고리즘 모듈이 두 방식을 섞어 씀
- `parseMutationSummary(raw)`: ④ 를 `{nodesCreated, relationshipsCreated, raw}` 로 best-effort 구조화, **실패해도 예외 없이 0 + raw 보존**

### 검증 (Node v24.13.0 / npm 11.6.2)
```
$ npx tsc --noEmit
TypeScript: No errors found   # exit 0

$ npm test          # node --test
ℹ tests 32 (result 11 + errors 10 + platform 9 + smoke 2)
ℹ pass 32   ℹ fail 0
```

### 수용 기준 체크
- [x] `CypherResult` 배열형(`length`/인덱싱/`Symbol.iterator`) + `toList()`
- [x] `columns` 접근자
- [x] ④ → `MutationSummary { nodesCreated, relationshipsCreated, raw }`
- [x] ④ 파싱 실패가 예외 안 됨 (카운트 0 + raw 보존)
- [x] 빈 결과 / `null` 행 → 빈 `CypherResult`

### 스코프 메모
- Python 이 비-JSON 에서 하던 `Error`/`{"error"` 접두 raise 는 여기서 하지 않습니다 — 에러 판별·throw 는 `errors.ts`(#3)+`connection.ts`(#7)의 몫. `result.ts` 는 결과 형태 정규화 단일 책임입니다.

### 참고
- 브랜치: `feat/4-issue-4`
- 커밋: `6396349`
