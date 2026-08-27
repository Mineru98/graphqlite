관련 이슈: [#70 upsertNode의 생성/갱신 경로가 id 덮어쓰기에서 비대칭](https://github.com/Mineru98/graphqlite/issues/70) (통합 테스트 뒤 close)

## 배경

`upsertNode(nodeId, nodeData)`가 노드 존재 여부에 따라 다른 `id`를 만드는 데이터 정합성 버그가 있었습니다.

- 생성: `{id: nodeId, ...nodeData}` → `nodeData.id`가 `nodeId`를 덮어씀
- 갱신: `nodeData` 전체를 SET → `nodeData.id`가 있으면 노드 id를 바꿈

#32 재현 결함 추적 항목 7.

## 방향

세 바인딩을 대칭화합니다(A안). `nodeId`가 항상 노드 `id`를 결정 — 생성은 id를 제외한 나머지만 병합, 갱신은 id 키를 SET에서 건너뜁니다. `nodeData`에 id가 없는 정상 케이스는 **동작·방출 Cypher 불변**.

## 변경 내용

| 바인딩 | 생성 | 갱신 |
| --- | --- | --- |
| TS `nodes.ts` | `{ id: nodeId, ...rest }` (rest = nodeData−id) | `if (key === 'id') continue` |
| Python `nodes.py` | `{"id": node_id, **rest}` | `if k == "id": continue` |
| Rust `nodes.rs` | props의 `id` skip, `id: node_id` 우선 | `if k == "id" { continue; }` |

## 검증

- **TS** `nodes-upsert.test.ts`: **8 pass / 0 fail** (신규 create·update 대칭 테스트 포함)
- **Rust** `integration.rs`: 신규 `test_graph_upsert_node_id_symmetry` 포함 **4 pass / 0 fail** (실제 확장으로 검증)
- **Python**: `py_compile` 통과, 신규 `test_upsert_node_id_symmetry` 추가 (pytest 미설치로 실행 스킵)
- parity 시나리오는 nodeData에 id가 없어 대칭화 후에도 결과 불변 → parity 게이트 영향 없음

## 증거

[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/70#issuecomment-5440952718)
