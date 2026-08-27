## #71 해결 — nodeSimilarity topK 무시 분기 수정

**방향**: 실제 코드 수정 (A안). 분기 조건을 `topK>0`로 앞당겨 topK만 줘도 반영. 기존 threshold 케이스는 방출·동작 불변.

### 문제

nodeSimilarity의 4-way 인자 분기에서 2번 조건이 `threshold>0 && topK>0`이라, `topK`만 주고 `threshold===0`이면 분기 4(무인자 `nodeSimilarity()`)로 떨어져 topK가 조용히 무시됐습니다. 세 바인딩 동일. #32 재현 결함 추적 항목 8.

### 수정

분기 2 조건을 `topK>0`(threshold 무관)로 변경:

| 바인딩 | before | after |
| --- | --- | --- |
| TS `similarity.ts` | `else if (threshold > 0 && topK > 0)` | `else if (topK > 0)` |
| Python `similarity.py` | `elif threshold > 0 and top_k > 0:` | `elif top_k > 0:` |
| Rust `similarity.rs` | `_ if threshold > 0.0 && top_k > 0` | `_ if top_k > 0` |

방출 변화는 버그 케이스뿐:

| 입력 | before | after |
| --- | --- | --- |
| threshold>0, topK>0 | `(threshold, topK)` | `(threshold, topK)` (동일) |
| threshold>0, topK=0 | `(threshold)` | `(threshold)` (동일) |
| threshold=0, topK>0 | `()` (버그) | `(0, topK)` (**수정**) |
| 둘 다 0 | `()` | `()` (동일) |

코어(`graph_algorithms.c:581-618`)는 `nodeSimilarity(0, topK)`를 threshold=0·top_k=topK로 정상 처리합니다.

### 검증

- **TS** `similarity.test.ts`: **11 pass / 0 fail** — `branch 2 — topK ONLY (threshold 0) is honored → nodeSimilarity(0, topK)` 신규, 기존 threshold 분기 방출 불변
- **Rust** `integration.rs`: 신규 `test_node_similarity_topk_only` **1 pass** (실제 확장으로 `nodeSimilarity(0, 2)` 파싱·동작 실증)
- **Python**: `py_compile` 통과, 신규 `test_node_similarity_topk_only` (pytest 미설치로 실행 스킵)
- parity 시나리오의 nodeSimilarity는 무인자 호출뿐이라 방출 변화 케이스 미포함 → **parity 게이트 영향 없음**

### 후속 이슈 후보

코어에 별개 버그가 있습니다 — `nodeSimilarity(threshold, topK)`에서 **threshold가 무시**됩니다(`graph_algorithms.c` 608행 `else if`가 인자 2개일 때 스킵되어 threshold가 기본 0.0으로 고정). 코어(C) 변경이라 이번 #71 범위 밖으로 두었습니다. 별도 이슈로 다룰 후보입니다.
