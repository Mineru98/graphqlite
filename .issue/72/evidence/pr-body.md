관련 이슈: [#72 DDL 요약을 평문이 아니라 JSON으로 반환 (코어 제안)](https://github.com/Mineru98/graphqlite/issues/72) (통합 테스트 뒤 close)

## 배경

코어(`src/extension.c:399`)가 RETURN 없는 수정 쿼리에 대해 사람용 평문(`Query executed successfully - nodes created: %d, relationships created: %d`)을 반환했습니다. 공식 계약이 아니라 바인딩이 best-effort 정규식으로 파싱 중이었습니다. #32 재현 결함 추적 코어 제안 항목 9.

## 변경 내용

- **`src/extension.c`** — 수정 쿼리 통계를 JSON 객체 `{"nodes_created":N,"relationships_created":M}`로 반환. JSON 객체(`{`)는 RETURN row set(`[`)과 구분됩니다.
- **TS `result.ts`** — `parseMutationSummary`를 JSON 우선으로 전환 + **평문 정규식 폴백 유지**(하위호환). `result.test.ts`에 JSON 파싱 테스트 추가.
- **Python / Rust** — DDL 통계 전용 파서가 없어 JSON을 자동으로 구조화 row로 파싱 (소스 무변경, 개선).

## 검증

- **C 코어 재빌드**: `make extension` 성공. ⚠️ **bison 3+ 필요** (시스템 bison 2.3은 `%code` 미지원, brew bison 3.8.2 사용).
- **end-to-end**: 재빌드된 코어로 `CREATE` 실행 → `[{"nodes_created":1,"relationships_created":0}]` 반환 확인.
- **TS** `result.test.ts`: **12 pass / 0 fail** (신규 JSON 케이스 + 기존 평문 폴백)
- **Rust**: `cargo test` **285 passed / 0 fail** (새 코어 dylib) — 기존 동작 불변
- **Python**: `py_compile` (pytest 미설치)

## 하위호환 / 주의

- `parseMutationSummary`가 JSON 우선·평문 폴백이라 pre-#72 문자열도 계속 파싱됩니다.
- DDL 쿼리의 `cypher()` 반환 형태가 `{result:"평문"}` → `{nodes_created,relationships_created}`로 바뀜(breaking). 대부분 DDL은 반환값 미사용.
- **CI/빌드 환경에 bison 3+가 필요**합니다(코어 재빌드).

## 증거

[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/72#issuecomment-5441347905)
