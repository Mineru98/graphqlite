관련 이슈: [#21 [B-01] 배치 연산](https://github.com/Mineru98/graphqlite/issues/21) (통합 테스트 뒤 close)

`upsertNodesBatch`/`upsertEdgesBatch` 를 `src/graph/batch.ts` 에 순수 함수(Connection 첫 인자)로 구현하고 `Graph` 파사드에 위임했습니다. Cypher 를 직접 만들지 않는 **순수 루프**입니다. 참조는 `bindings/python/src/graphqlite/graph/batch.py`.

## 변경 내용
- `src/graph/batch.ts` (신규) — `upsertNodesBatch` / `upsertEdgesBatch`
- `src/graph/index.ts` — `batch — #21` 삽입 지점에 위임 메서드 2개
- `src/index.ts` — 함수·타입 re-export
- `test/batch.test.ts` (신규) — mock 수용 기준 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

## 수용 기준
- 각 항목마다 `upsertNode`/`upsertEdge` 호출하는 단순 루프
- **원자성 없음** — 중간 실패 시 앞 항목 커밋된 채 남음(트랜잭션 미포장, Python 재현)
- **`upsertEdgesBatch` 는 `edgeId` 미전달** → 배치로 parallel edge 생성 불가
- 입력 튜플 배열 `[nodeId, props, label][]` / `[source, target, props, relType][]`

## 검증
- `node --test` → 확장 있으면 183/183 통과
- `npx tsc --noEmit` → 무오류

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/21)
