## #72 해결 — DDL 요약을 평문이 아니라 JSON으로 반환

**방향**: 전체 구현(A안). C 코어가 구조화 JSON을 반환하고, 세 바인딩이 이를 곧장 파싱. TS는 하위호환 폴백 유지.

### 문제

코어(`src/extension.c:399`)가 RETURN 없는 수정 쿼리에 대해 사람용 평문(`Query executed successfully - nodes created: %d, relationships created: %d`)을 반환했습니다. 공식 계약이 아니라 바인딩이 best-effort 정규식으로 파싱 중이었습니다. #32 재현 결함 추적 코어 제안 항목 9.

### 수정

**코어**가 JSON 객체를 반환하도록 변경:

```c
snprintf(response, sizeof(response),
    "{\"nodes_created\":%d,\"relationships_created\":%d}",
    result->nodes_created, result->relationships_created);
```

JSON 객체(`{`)는 RETURN row set(`[`)과 구분되어, 바인딩이 통계를 구조화 row로 파싱합니다.

| 바인딩 | 처리 |
| --- | --- |
| TS `result.ts` | `parseMutationSummary`를 JSON 우선으로 전환 + **평문 정규식 폴백 유지**(하위호환). `normalizeCypherResult`는 이미 객체를 row로 파싱 |
| Python | DDL 통계 전용 파서가 없어 JSON을 자동으로 구조화 row로 파싱 (소스 무변경, 개선) |
| Rust | `from_json`이 JSON 객체를 row로 파싱 (소스 무변경, 개선) |

### 검증

- **C 코어 재빌드**: `make extension` 성공. ⚠️ **bison 3+ 필요** — 시스템 bison 2.3은 `%code` 지시자를 지원 안 함(brew bison 3.8.2 사용).
- **end-to-end (실제 재빌드된 코어)**: `CREATE (n:Person {...})` 실행 →
  ```
  DDL rows : [{"nodes_created":1,"relationships_created":0}]
  columns  : ["nodes_created","relationships_created"]
  ```
- **TS** `result.test.ts`: **12 pass / 0 fail** (신규 JSON 파싱 케이스 + 기존 평문 폴백 테스트)
- **Rust**: `cargo test` **285 passed / 0 fail** (새 코어 dylib) — 기존 동작 불변
- **Python**: `py_compile` (pytest 미설치)

### 하위호환

`parseMutationSummary`가 JSON 우선·평문 폴백이라 pre-#72 문자열도 계속 파싱됩니다. DDL 쿼리의 `cypher()` 반환 형태는 `{result:"평문"}` → `{nodes_created,relationships_created}`로 바뀌지만, 대부분의 DDL은 반환값을 쓰지 않습니다.

### 참고

이 수정은 코어 재빌드가 필요하므로 CI/빌드 환경에 **bison 3+**가 요구됩니다.
