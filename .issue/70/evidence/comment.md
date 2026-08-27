## #70 해결 — upsertNode 생성/갱신 id 비대칭 대칭화

**방향**: 실제 코드 대칭화 (A안). `nodeId`가 항상 노드 `id`를 결정하도록 세 바인딩을 함께 수정. 정상 케이스는 동작 불변.

### 문제

`upsertNode(nodeId, nodeData)`가 노드 존재 여부에 따라 다른 `id`를 만들었습니다.

- **생성**: `{id: nodeId, ...nodeData}` → `nodeData.id`가 `nodeId`를 덮어씀(나중 spread 승)
- **갱신**: `nodeData` 전체를 SET → `nodeData.id`가 있으면 노드 id를 바꿈

즉 `upsertNode('alice', {id: 'bob'})`가 alice가 없으면 `bob` 노드를 만들고, 있으면 alice→bob으로 바꾸는 식으로 식별자가 요청과 어긋났습니다. #32 재현 결함 추적 항목 7.

### 수정 (세 바인딩 대칭화)

`nodeId`가 항상 이깁니다. 생성은 `{id: nodeId, ...(id 제외한 rest)}`, 갱신은 `id` 키를 SET에서 건너뜁니다.

| 바인딩 | 생성 | 갱신 |
| --- | --- | --- |
| TS `nodes.ts` | `{ id: nodeId, ...rest }` (rest는 nodeData−id) | `if (key === 'id') continue` |
| Python `nodes.py` | `{"id": node_id, **rest}` | `if k == "id": continue` |
| Rust `nodes.rs` | props의 `id` 키 skip, `id: node_id` 우선 | `if k == "id" { continue; }` |

### 검증

- **TS 단위 테스트** (`nodes-upsert.test.ts`): **8 pass / 0 fail** (확장 필요한 통합 1건 skip)
  - 신규 `create path: nodeData.id is ignored, nodeId wins`
  - 신규 `update path: nodeData.id is skipped, id is never reassigned`
  - 기존 정상 케이스(속성 순서 보존) 전부 통과
- **Rust 통합 테스트** (`integration.rs`): 신규 `test_graph_upsert_node_id_symmetry` 포함 **4 passed / 0 fail** (실제 확장으로 검증)
- **Python**: `py_compile` 통과, 신규 `test_upsert_node_id_symmetry` 추가 (pytest 미설치로 실행은 스킵)

### 정상 케이스 불변

`nodeData`에 `id`가 없는 정상 사용에서는 생성의 방출 Cypher 순서·동작이 그대로입니다. parity 시나리오(`scenarios.json`)의 upsertNode 호출도 nodeData에 id가 없어 **parity 게이트에 영향이 없습니다**.
