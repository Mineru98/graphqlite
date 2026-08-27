# after — upsertNode id 대칭화 (수정 후)

nodeId 가 항상 노드 id 를 결정. 생성/갱신 양쪽에서 nodeData.id 무시. 세 바인딩 동일.

## 검증
- TS 단위 테스트 (nodes-upsert.test.ts): 8 pass / 0 fail / 1 skip(확장 필요)
  - 신규: 'create path: nodeData.id is ignored, nodeId wins'
  - 신규: 'update path: nodeData.id is skipped, id is never reassigned'
  - 기존 정상 케이스(순서 보존) 전부 통과
- Python py_compile: OK (신규 test_upsert_node_id_symmetry 추가, pytest 환경 미설치로 실행은 스킵)
- Rust 통합 테스트: 신규 test_graph_upsert_node_id_symmetry 포함 4 passed / 0 fail (메인 코어 dylib 를 libs/ 로 복사해 실제 확장으로 검증)

## 정상 케이스 불변 근거
- nodeData 에 id 없으면: 생성 {id: nodeId, ...rest} 순서·동작 불변, 갱신 동작 불변
- parity scenarios.json 의 upsertNode 호출은 nodeData 에 id 없음 → parity 게이트 영향 없음
