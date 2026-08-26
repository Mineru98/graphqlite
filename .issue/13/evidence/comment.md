## [Q-01] 그래프 조회 8종 (queries.ts) — 구현 리포트

그래프 조회 8종을 `Connection` 첫 인자 **순수 함수**(`src/graph/queries.ts`)로 구현하고 `Graph` 파사드(#8)에 위임했습니다. 참조는 `bindings/python/src/graphqlite/graph/queries.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **`getNodeEdges` 는 `[source, target, props][]` 튜플 배열** (다른 메서드와 형태 다름, TS `[string, string, Record<string, unknown>][]`) | ✅ |
| **`stats()` 는 카운트 쿼리 2회**, `cnt` → `nodeCount`/`edgeCount` rename | ✅ |
| `getEdgesByType` 의 `relType` 은 `sanitizeRelType` 후 보간 | ✅ |
| `query(cypher, params)` 는 사용자 문자열 가공 없이 전달 | ✅ |
| 나머지는 `$id` 바인딩 | ✅ |

### 대상 8종 / Cypher
| 메서드 | Cypher | 파싱 |
|---|---|---|
| `nodeDegree` | `MATCH (n {id: $id})-[r]-() RETURN count(r) AS degree` | 빈→0 |
| `getNeighbors` | `MATCH (n {id: $id})-[]-(m) RETURN DISTINCT m` | truthy `m` |
| `getNodeEdges` | `MATCH (n {id: $id})-[r]-(m) RETURN n.id AS source, m.id AS target, r` | **튜플 배열** |
| `getEdgesFrom` | `MATCH (a {id: $id})-[r]->(b) RETURN ...` | `toList()` |
| `getEdgesTo` | `MATCH (a)-[r]->(b {id: $id}) RETURN ...` | `toList()` |
| `getEdgesByType` | `MATCH (a {id: $id})-[r:{TYPE}]->(b) RETURN ...` | `toList()` |
| `stats` | 쿼리 2회 | 키 rename |
| `query` | 사용자 원문 | `toList()` |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
nodeDegree('alice')                2
getNeighbors('alice') 개수           2
getNodeEdges('alice') (튜플)         [["alice","carol",{...FOLLOWS...}],["alice","bob",{...KNOWS...,"since":2020}]]
getEdgesFrom('alice') 개수           2
getEdgesTo('bob') 개수               1
getEdgesByType('alice','KNOWS')    1
stats()                            {"nodeCount":3,"edgeCount":2}
query(원문 전달)                       [{"id":"alice"},{"id":"bob"},{"id":"carol"}]
```

### Before → After
- **Before** (`origin/main`): `src/graph/` 에 `edges/index/nodes`(queries.ts 부재), 114 테스트 통과.
- **After**: 8종 공개 + Graph 위임, **123 테스트** — 확장 유 123/123, 무 109 통과+14 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/queries.ts` (신규) — 순수 함수 8개(튜플·stats 2쿼리·sanitize·passthrough)
- `src/graph/index.ts` — `queries — #13` 삽입 지점에 위임 메서드 8개
- `src/index.ts` — 8개 함수 re-export
- `test/queries.test.ts` (신규) — mock Cypher parity·튜플·stats·sanitize·passthrough 단위 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 8종 반영

### 증거 원본
- baseline: `.issue/13/evidence/before/state.txt`
- 테스트/타입체크: `.issue/13/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/13/evidence/after/behavior.txt`
