## #82 해결 — nodeSimilarity(threshold, topK) 2-인자에서 threshold 적용

**방향**: 코어(C) 한 곳 수정. 바인딩 변경 불필요.

### 문제

`nodeSimilarity(threshold, topK)` 2-인자(숫자) 호출에서 `threshold`(arg0)가 무시되고 기본값 `0.0`으로 고정돼, 임계값 필터가 걸리지 않고 top_k만 적용됐습니다.

### 원인

`src/backend/executor/graph_algorithms.c`의 `count >= 2 && !source_id` 블록(2-인자 숫자 경로)이 `top_k`(arg1)만 읽고 `threshold`(arg0)를 읽지 않았습니다. `608` `else if (count >= 1)`은 `count >= 2`일 때 스킵되므로, 2-인자 숫자 호출에서 threshold가 어디서도 읽히지 않았습니다.

### 수정

해당 블록에 threshold(arg0) 읽기 한 줄 추가:

```c
if (count >= 2 && !source_id) {
    params.threshold = resolve_double_arg(items[0], ...);  // 추가
    params.top_k     = resolve_int_arg(items[1], ...);
}
```

`source_id`가 잡힌 경우(문자열 pair)는 이 블록에 들어오지 않으므로 pair 쿼리에 영향 없습니다.

### 검증 (실측, before → after)

| 호출 | 수정 전 | 수정 후 | 기대 |
| --- | ---: | ---: | ---: |
| `nodeSimilarity(0.6, 100)` | 10쌍 (threshold 무시) | **1쌍** (a-b) | 1 |
| `nodeSimilarity(0.4, 100)` | 10쌍 (threshold 무시) | **3쌍** (a-b·a-c·b-c) | 3 |

- baseline은 수정을 되돌려 재빌드해 실측(10쌍, threshold 무시 확인).
- 코어 재빌드: `make extension` (**bison 3+ 필요**).
- Rust `cargo test`: **287 passed / 0 fail** (수정본 코어) — 회귀 없음.
- 바인딩 코드 변경 없음 — 코어 한 곳 수정으로 세 바인딩 모두 이롭다.

### 참고

1-인자 `nodeSimilarity(threshold)`와 무인자는 원래도 정상이었습니다(608행 else-if). 이번 수정은 2-인자 경로에 한정됩니다. (`{column_0:[...]}` 래퍼 안의 실제 쌍 수로 검증)

관련: #71, #32
