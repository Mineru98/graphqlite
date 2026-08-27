## [B-01] 배치 연산 — 구현 리포트

`upsertNodesBatch`/`upsertEdgesBatch` 를 `src/graph/batch.ts` 에 순수 함수(Connection 첫 인자)로 구현하고 `Graph` 파사드에 위임했습니다. Cypher 를 직접 만들지 않는 **순수 루프**입니다. 참조는 `bindings/python/src/graphqlite/graph/batch.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 각 항목마다 `upsertNode`/`upsertEdge` 호출하는 단순 루프 | ✅ Cypher 직접 생성 없음 |
| **원자성 없음** — 중간 실패 시 앞 항목 커밋된 채 남음 | ✅ 2번째 실패해도 1번째 CREATE 잔존, 트랜잭션 미포장 |
| **`upsertEdgesBatch` 는 `edgeId` 미전달** → parallel edge 불가 | ✅ MERGE 쿼리에 `{id:$eid}` 없음, 재배치해도 엣지 수 유지 |
| 입력 튜플 배열 `[nodeId, props, label][]` / `[source, target, props, relType][]` | ✅ 타입 `NodeBatchItem` / `EdgeBatchItem` |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
upsertNodesBatch 3건 → 노드 3
upsertEdgesBatch 2건 → 엣지 2
같은 a→b 재배치 → 엣지      2          (edgeId 미전달 → parallel edge 안 생김)
2번째 항목 실패: boom
1번째 CREATE 실행됨?        true       (원자성 없음 — 롤백 안 함)
2번째 CREATE 실행됨?        false
edge MERGE 쿼리            MATCH (a {id: $src}), (b {id: $tgt}) MERGE (a)-[r:KNOWS]->(b)
eid 파라미터               null       (undefined → parallel edge 불가)
```

### Before → After
- **Before** (`origin/main` `55452f0`): batch.ts 부재, 179 테스트 통과.
- **After**: 2종 공개 + Graph 위임, **183 테스트** — 확장 有 183/183, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/batch.ts` (신규) — 순수 루프 2종(원자성 없음·edgeId 미전달)
- `src/graph/index.ts` — `batch — #21` 삽입 지점에 위임 메서드 2개
- `src/index.ts` — 함수·타입 re-export
- `test/batch.test.ts` (신규) — mock 위임·순서·원자성 없음·edgeId 미전달 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/21/evidence/before/state.txt`
- 테스트/타입체크: `.issue/21/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/21/evidence/after/behavior.txt`
