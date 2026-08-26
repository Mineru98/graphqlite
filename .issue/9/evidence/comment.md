## [N-01] 노드 읽기·삭제 — 구현 리포트

노드 읽기·삭제 4종을 `Connection` 을 첫 인자로 받는 **순수 함수**(`src/graph/nodes.ts`)로 구현하고 `Graph` 파사드(#8)에 3줄 위임으로 붙였습니다. 참조는 `bindings/python/src/graphqlite/graph/nodes.py`. `upsertNode` 는 `hasNode` 의존이라 #10(N-02)로 분리했습니다.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| `hasNode`: 빈 결과→false, falsy `cnt`→false, 그 외 `Number(cnt)>0` | ✅ |
| `getNode`: `row.n` 가공 없이 반환(없으면 null) | ✅ `{id, labels, properties}` 그대로 |
| `getAllNodes(label)`: label 에 `assertIdentifier` 적용 | ✅ 보간 전 검증, 잘못된 label → `ValidationError` |
| `getAllNodes` 이중 파싱 (result 문자열→`JSON.parse`→`item.n`, 파싱 실패 무시 / 그 외 truthy `row.n`) | ✅ |
| 생성 Cypher 문자열 Python 동일 | ✅ mock 테스트로 문자열·파라미터 parity 검증 |

### 대상 메서드 / Cypher
| 메서드 | Cypher |
|---|---|
| `hasNode` | `MATCH (n {id: $id}) RETURN count(n) AS cnt` |
| `getNode` | `MATCH (n {id: $id}) RETURN n` |
| `deleteNode` | `MATCH (n {id: $id}) DETACH DELETE n` |
| `getAllNodes` | `MATCH (n:{label}) RETURN n` / `MATCH (n) RETURN n` (label 보간) |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
초기 getAllNodes  : []
hasNode('alice')  : true
hasNode('nobody') : false
getNode('alice')  : {"id":1,"labels":["Person"],"properties":{"id":"alice","name":"Alice"}}
getAllNodes('Person') 개수: 1
getAllNodes() 개수: 2
deleteNode 후 hasNode('alice'): false
잘못된 label      : ValidationError (assertIdentifier 거부)
```

### Before → After
- **Before** (`origin/main`): `src/graph/` 에 `index.ts` 뿐(nodes.ts 부재), 81 테스트 통과.
- **After**: `hasNode`/`getNode`/`deleteNode`/`getAllNodes` 공개 + Graph 위임, **91 테스트** — 확장 유 91/91, 무 82 통과+9 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/nodes.ts` (신규) — 순수 함수 4개(이중 파싱·assertIdentifier 포함)
- `src/graph/index.ts` — `nodes — #9` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 노드 함수 re-export
- `test/nodes.test.ts` (신규) — mock Cypher parity·이중 파싱 단위 + 게이트된 실제 확장 통합
- `test/smoke.test.ts` — 공개 표면 단언에 노드 함수 반영

### 증거 원본
- baseline: `.issue/9/evidence/before/state.txt`
- 테스트/타입체크: `.issue/9/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/9/evidence/after/behavior.txt`
