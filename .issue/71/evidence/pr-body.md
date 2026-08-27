관련 이슈: [#71 nodeSimilarity에서 topK만 주고 threshold===0이면 topK가 조용히 무시된다](https://github.com/Mineru98/graphqlite/issues/71) (통합 테스트 뒤 close)

## 배경

nodeSimilarity의 4-way 인자 분기에서 2번 조건이 `threshold>0 && topK>0`이라, `topK`만 주고 `threshold===0`이면 분기 4(무인자 `nodeSimilarity()`)로 떨어져 topK가 조용히 무시됐습니다. 세 바인딩 동일. #32 재현 결함 추적 항목 8.

## 방향

세 바인딩의 분기 2 조건을 `topK>0`(threshold 무관)로 앞당깁니다(A안). topK만 줘도 `nodeSimilarity(threshold, topK)`를 방출. 코어가 `nodeSimilarity(0, topK)`를 top_k로 정상 처리함을 확인했고, 기존 threshold 케이스는 방출·동작이 불변입니다.

## 변경 내용

| 바인딩 | before → after |
| --- | --- |
| TS `similarity.ts` | `else if (threshold > 0 && topK > 0)` → `else if (topK > 0)` |
| Python `similarity.py` | `elif threshold > 0 and top_k > 0:` → `elif top_k > 0:` |
| Rust `similarity.rs` | `_ if threshold > 0.0 && top_k > 0` → `_ if top_k > 0` |

방출 변화는 버그 케이스(threshold=0, topK>0: `()` → `(0, topK)`)뿐입니다.

## 검증

- **TS** `similarity.test.ts`: **11 pass / 0 fail** (신규 topK-only 방출 검증, 기존 threshold 분기 불변)
- **Rust** `integration.rs`: 신규 `test_node_similarity_topk_only` **1 pass** (실제 확장으로 `nodeSimilarity(0, 2)` 파싱·동작 실증)
- **Python**: `py_compile` 통과, 신규 `test_node_similarity_topk_only` (pytest 미설치로 실행 스킵)
- parity 시나리오의 nodeSimilarity는 무인자 호출뿐 → parity 게이트 영향 없음

## 증거

[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/71#issuecomment-5441146771)

## 참고 — 후속 이슈 후보

코어 `nodeSimilarity(threshold, topK)`에서 threshold가 무시되는 별개 버그를 발견했습니다(`graph_algorithms.c`). 코어(C) 변경이라 이번 범위 밖 — 별도 이슈로 다룰 후보입니다.
