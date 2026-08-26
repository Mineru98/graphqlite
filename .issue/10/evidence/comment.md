## [N-02] upsertNode — 구현 리포트

`upsertNode` 를 `hasNode`(#9)로 분기하는 순수 함수로 `src/graph/nodes.ts` 에 추가하고 `Graph` 파사드에 위임했습니다. 참조는 `bindings/python/src/graphqlite/graph/nodes.py:49-79`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **비대칭 재현** — 생성은 `{id: nodeId, ...nodeData}` 라 `nodeData.id` 가 `nodeId` 덮어씀 / 갱신은 `nodeData` 만 SET 해 `id` 그대로 | ✅ |
| 기본 label `"Entity"` | ✅ |
| label·프로퍼티 키에 `assertIdentifier` | ✅ 잘못된 값 → `ValidationError` |
| 갱신은 항목 수만큼 쿼리(N 왕복, 묶지 않음) | ✅ mock 으로 2항목 → 2쿼리 검증 |
| 생성 Cypher 문자열 Python 동일 | ✅ mock parity |

### 분기 / Cypher
- **없음** → `CREATE (n:{label} {formatProps({id, ...nodeData})})` (params 없이 전부 보간)
- **존재** → 항목마다 `MATCH (n {id: $id}) SET n.{key} = $val RETURN n` (key 보간, val 바인딩)

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
생성 후 getNode      : {"id":1,"labels":["Person"],"properties":{"id":"alice","name":"Alice","age":30}}
갱신 후 getNode      : {"id":1,"labels":["Person"],"properties":{"id":"alice","name":"Alice","age":31}} (age 만 변경, name 유지)
비대칭 hasNode('bob')       : false
비대칭 hasNode('BOB_OVERRIDE'): true (nodeData.id 가 nodeId 덮어씀)
잘못된 label         : ValidationError
```

### Before → After
- **Before** (`origin/main`): `nodes.ts` 에 `upsertNode` 부재(주석 언급만), 91 테스트 통과.
- **After**: `upsertNode` 공개 + Graph 위임, **99 테스트** — 확장 유 99/99, 무 89 통과+10 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/nodes.ts` — `upsertNode` 추가(비대칭 분기·assertIdentifier·formatProps)
- `src/graph/index.ts` — nodes 블록에 `upsertNode` 위임
- `src/index.ts` — `upsertNode` re-export
- `test/nodes-upsert.test.ts` (신규) — mock 분기·Cypher parity·비대칭·N 왕복·검증 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 `upsertNode` 반영

### 증거 원본
- baseline: `.issue/10/evidence/before/state.txt`
- 테스트/타입체크: `.issue/10/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/10/evidence/after/behavior.txt`
