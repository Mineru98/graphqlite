# after — 2-인자 threshold 적용 (수정 후, 실측)

613 블록에 threshold(arg0) 읽기 한 줄 추가:
```c
if (count >= 2 && !source_id) {
    params.threshold = resolve_double_arg(items[0], ...);  // 추가
    params.top_k     = resolve_int_arg(items[1], ...);
}
```

실측 (수정 후 dylib):
- nodeSimilarity(0.6, 100) → 1쌍 (a-b, sim=1.0) ✓
- nodeSimilarity(0.4, 100) → 3쌍 (a-b·a-c·b-c) ✓

## 참고 — 오진 정정
초기 검증에서 threshold 필터가 1-인자에서도 미작동으로 보였으나, 이는 결과가 {column_0:[...]} 래퍼로 감싸진 것을 .length(바깥=1)로 세는 테스트 버그였다. column_0 내부로 세면 필터는 정상 작동한다.
