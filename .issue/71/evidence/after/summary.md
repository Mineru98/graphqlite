# after — nodeSimilarity topK 분기 수정 (수정 후)

분기 2 조건을 topK>0 로 앞당김. topK 만 줘도 nodeSimilarity(threshold, topK) 방출. 세 바인딩 동일.

## 검증
- TS 단위 테스트 (similarity.test.ts): 11 pass / 0 fail
  - 'branch 2 — topK ONLY (threshold 0) is honored → nodeSimilarity(0, topK)'
  - 기존 branch 2/3 (threshold 케이스) 방출 불변
- Python: py_compile, 신규 test_node_similarity_topk_only (pytest 미설치로 실행 스킵)
- Rust: 신규 test_node_similarity_topk_only 1 passed (메인 코어 dylib 를 libs/ 로 복사해 실제 확장으로 nodeSimilarity(0, topK) 파싱·동작 실증)

## parity 영향 없음
- scenarios.json 의 nodeSimilarity 는 무인자 호출뿐 → 방출 변화 케이스(topK-only) 미포함
