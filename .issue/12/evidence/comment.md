## [E-02] upsertEdge — 구현 리포트

`upsertEdge` 를 **MERGE 기반**(`hasEdge`/`hasNode` 미호출)으로 `src/graph/edges.ts` 에 추가하고 `Graph` 파사드에 위임했습니다. 참조는 `bindings/python/src/graphqlite/graph/edges.py:58-119`. E-01(#11)과 같은 파일이라 순차 진행했습니다.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 속성 있으면 쿼리 2회, 없으면 1회 | ✅ |
| SET 은 값 바인딩·프로퍼티 키만 보간, **단일 쿼리**로 묶음(노드 upsert 의 N 왕복과 다름) | ✅ `SET r.k = $v0, r.k1 = $v1` |
| 양쪽 노드 없으면 MATCH 실패로 조용히 no-op, **예외 없음** | ⚠️ **바인딩 계약(예외 없음)은 충족.** 아래 코어 주의 참고 |
| 기본 relType `"RELATED"` | ✅ |
| 프로퍼티 키에 `assertIdentifier` | ✅ MERGE 전에 선검증 → 잘못된 키면 빈 엣지도 안 생김, `ValidationError` |
| 생성 Cypher 문자열 Python 동일 | ✅ mock parity |

### 코어 동작 주의 (정직한 보고)
수용 기준의 "노드 없으면 no-op" 은 표준 Cypher 의 MATCH-실패-no-op 을 전제합니다. **이 빌드의 코어(`build/graphqlite.dylib`)는 그 시맨틱을 구현하지 않아**, 노드가 없어도 관계를 생성합니다(예: `alice→ghost` 요청 시 `alice→alice` 자기루프가 생김). 바인딩은 Python 과 **동일한 Cypher 를 그대로 전달**하므로 충실하며, 바인딩 레벨의 보장은 "예외를 던지지 않는다" 입니다(MERGE 기반이라 존재 검사 없음). no-op 여부는 코어 책임이라 코어가 표준화되면 자동으로 no-op 이 됩니다. 테스트는 이 사실을 반영해 바인딩 계약(예외 없음)만 단언합니다.

### 분기 / Cypher
- **Step1 MERGE** — edgeId 없음: `MATCH (a {id: $src}), (b {id: $tgt}) MERGE (a)-[r:{TYPE}]->(b)` / 있음: `... MERGE (a)-[r:{TYPE} {id: $eid}]->(b)`
- **Step2 SET** (속성 있을 때만): `MATCH (a {id: $src})-{relMatch}->(b {id: $tgt}) SET r.k0 = $v0, ...`

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
생성 후 getEdge   : {"id":1,"type":"KNOWS","startNode":1,"endNode":2,"properties":{"since":2020}}
생성 후 엣지 수   : 1 (속성 있음 → 쿼리 2회)
재upsert 후 since : 2021 / 엣지 수: 1 (중복 안 생김)
속성없는 upsert 후: 2 개 (FOLLOWS 추가)
잘못된 키         : ValidationError
노드 없을 때 예외 없음: 예외 안 던짐(바인딩 계약 충족)
```

### Before → After
- **Before** (`origin/main`): `edges.ts` 에 `upsertEdge` 부재, 107 테스트 통과.
- **After**: `upsertEdge` 공개 + Graph 위임, **114 테스트** — 확장 유 114/114, 무 101 통과+13 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/edges.ts` — `upsertEdge` 추가(MERGE 2분기·단일 SET·키 선검증)
- `src/graph/index.ts` — edges 블록에 `upsertEdge` 위임
- `src/index.ts` — `upsertEdge` re-export
- `test/edges-upsert.test.ts` (신규) — mock 분기·Cypher parity·단일 SET·검증 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 `upsertEdge` 반영

### 증거 원본
- baseline: `.issue/12/evidence/before/state.txt`
- 테스트/타입체크: `.issue/12/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/12/evidence/after/behavior.txt`
