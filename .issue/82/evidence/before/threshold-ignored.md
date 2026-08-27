# before — 2-인자 threshold 무시 (수정 전, baseline 실측)

graph_algorithms.c:613 블록이 top_k(arg1)만 읽고 threshold(arg0)를 안 읽음:
```c
if (count >= 2 && !source_id) { params.top_k = resolve_int_arg(items[1], ...); }
```

실측 (수정 전 dylib):
- nodeSimilarity(0.6, 100) → 10쌍 (threshold 무시, all-pairs 전부)
- nodeSimilarity(0.4, 100) → 10쌍 (threshold 무시)
