## [A-06] 유사도 (nodeSimilarity/knn/triangleCount) — 구현 리포트

유사도·군집 알고리즘 3종을 `Connection` 첫 인자 순수 함수(`src/algorithms/similarity.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. 참조는 `bindings/python/src/graphqlite/algorithms/similarity.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 핵심 비대칭 — 이 모듈만 `extractAlgoArray` 를 쓰지 않는다
Python `SimilarityMixin` 은 `for row in result` 로 CypherResult 를 **직접 순회**합니다(다른 알고리즘은 `extractAlgoArray(result.to_list())`). 코어가 결과를 `{column_0: [...]}` 로 감싸므로, 언랩하지 않는 직접 순회는 실제 코어에서 **빈 결과**를 냅니다. 바인딩은 이 비일관성을 그대로 재현합니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **`extractAlgoArray` 미사용** — 직접 순회 | ✅ `for (const row of conn.cypher(q))`, 언랩 형태만 파싱·`column_0` 래핑은 `[]` |
| **`topK` 만 + `threshold===0` → topK 무시**(분기 4) | ✅ `nodeSimilarity({topK:5})` → `RETURN nodeSimilarity()` |
| `nodeSimilarity` 4갈래 분기(우선순위) | ✅ 아래 실증 [1]~[4] |
| `nodeSimilarity` 키 `node1`/`node2`/`similarity`, 둘 다 not-null | ✅ safeFloat, 한쪽 null 행 제외 |
| `knn(nodeId, k=10)` → `RETURN knn('{id}', {k})`, 키 `neighbor`/`similarity`/`rank` | ✅ safeFloat/safeInt, neighbor not-null |
| `triangleCount()` 키 `nodeId`/`userId`/`triangles`/`clusteringCoefficient`, 별칭 `triangles` | ✅ camelCase(아래 주의) |
| 문자열 인자 `escapeString` | ✅ 따옴표 이스케이프 |

### 반환 키 결정 — triangleCount 는 camelCase
Python 은 snake_case(`node_id`, `clustering_coefficient`)지만, 이 모듈은 공유 파서를 쓰지 않고 직접 파싱하며 **이슈가 camelCase 를 명시**하고 `components.ts`(`nodeId`/`userId`) TS 컨벤션과 일치합니다. 따라서 `nodeId`/`userId`/`triangles`/`clusteringCoefficient` 로 구현했습니다. (#19 traversal 이 `user_id` 였던 것은 공유 파서 `parseTraversalResult` 계약 때문으로, 상황이 다릅니다.)

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
4갈래 분기 쿼리:
  [1] RETURN nodeSimilarity('a', 'b')      (node1 && node2 — threshold/topK 있어도 우선)
  [2] RETURN nodeSimilarity(0.3, 5)        (threshold>0 && topK>0)
  [3] RETURN nodeSimilarity(0.3)           (threshold>0)
  [4] RETURN nodeSimilarity()              (topK만 → 무시)
직접 순회 — 언랩 형태      [{"node1":"a","node2":"b","similarity":0.5}]
직접 순회 — column_0 래핑  []              (extractAlgoArray 미사용 → 빈 결과)
triangleCount 반환 키      ["nodeId","userId","triangles","clusteringCoefficient"]
triangleCount 첫 행        {"nodeId":"1","userId":"a","triangles":2,"clusteringCoefficient":0.33}
triangles===triangleCount  true
실제 확장 nodeSimilarity() []              (코어 래핑 → 직접 순회 빈 결과, Python 비일관성 재현)
```

### Before → After
- **Before** (`origin/main` `562fdb6`): similarity.ts 부재, 167 테스트 통과.
- **After**: 3종+별칭 1 공개 + Graph 위임, **179 테스트** — 확장 有 179/179, `tsc --noEmit` 무오류.

### 변경 파일
- `src/algorithms/similarity.ts` (신규) — 순수 함수 3종 + 별칭 1 (4갈래 분기·직접 순회·escapeString)
- `src/graph/index.ts` — `similarity — #20` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 함수·타입 re-export
- `test/similarity.test.ts` (신규) — mock 수용 기준(4갈래·topK 무시·직접 순회·키·escape·별칭) + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/20/evidence/before/state.txt`
- 테스트/타입체크: `.issue/20/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/20/evidence/after/behavior.txt`
