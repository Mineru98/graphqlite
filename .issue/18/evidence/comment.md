## [A-04] 경로 알고리즘 (dijkstra/astar/apsp) — 구현 리포트

경로 알고리즘 3종을 `Connection` 첫 인자 순수 함수(`src/algorithms/paths.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. **비일관성이 가장 많은 원소**라 비대칭 4종을 Python 그대로 재현했습니다. 참조는 `bindings/python/src/graphqlite/algorithms/paths.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 실측: 코어는 셋 다 `column_0` 로 감싼다
`dijkstra`/`astar`/`apsp` 모두 `[{ "column_0": ... }]` 형태로 반환. 이 사실이 비대칭 2를 드러냅니다.

### 수용 기준 대조 (비대칭 4종)

| 수용 기준 | 결과 |
| --- | --- |
| **`shortestPath` 만 큰따옴표**, 나머지 작은따옴표 | ✅ `dijkstra("a","b","w")` / `astar('a','b',...)` |
| **`shortestPath` 만 `column_0` 언랩, `astar` 는 직접 접근** | ✅ astar 는 언랩 안 해 **이 코어 형태에선 기본값 반환**(Python 비일관성 유지) |
| `astar` 의 `latProp`/`lonProp` 은 보간 → `assertIdentifier` | ✅ 잘못된 값 → `ValidationError` |
| **`apsp` 만 `.toList()` → `extractAlgoArray`** | ✅ (column_0 배열 언랩되어 정상 동작) |
| `shortestPath` 기본값 `{path:[], distance:null, found:false}` | ✅ |
| `astar` 기본값 `{..., nodesExplored:0}` | ✅ `nodes_explored`→`nodesExplored`, safeInt |
| `apsp` 키 `source`/`target`/`distance` (둘 다 not-null) | ✅ safeFloat |
| source/target 은 `escapeString` 통과 | ✅ 따옴표 이스케이프 |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0 / a→b→c 가중 그래프)

```text
shortestPath(a,c,{weightProp:w})   {"path":["a","b","c"],"distance":2,"found":true}
  (큰따옴표 + column_0 언랩 → 경로 반환)
astar(a,c)                         {"path":[],"distance":null,"found":false,"nodesExplored":0}
  (작은따옴표 + 언랩 X → 기본값, Python 비일관성 재현)
allPairsShortestPath() 개수          3
  apsp()[0]                        {"source":"a","target":"b","distance":1}
dijkstra===shortestPath            true
astar 잘못된 latProp                 ValidationError
```

> **astar 의 빈 결과는 버그가 아니라 재현**입니다. Python astar 는 `column_0` 를 언랩하지 않아 이 코어(래핑 반환)에서 기본값을 돌려줍니다. 바인딩은 그 비일관성을 그대로 재현하며, 코어가 언랩된 형태를 주면 자동으로 필드를 채웁니다(mock 테스트로 검증).

### Before → After
- **Before** (`origin/main`): `src/algorithms/` 에 paths.ts 부재, 149 테스트 통과.
- **After**: 3종+별칭 3 공개 + Graph 위임, **158 테스트** — 확장 유 158/158, 무 139 통과+19 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/algorithms/paths.ts` (신규) — 순수 함수 3종 + 별칭 3(비대칭 4종·escape·assertIdentifier)
- `src/graph/index.ts` — `paths — #18` 삽입 지점에 위임 메서드 6개
- `src/index.ts` — 함수·타입 re-export
- `test/paths.test.ts` (신규) — mock 비대칭 4종·인용부호·언랩·escape·검증 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/18/evidence/before/state.txt`
- 테스트/타입체크: `.issue/18/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/18/evidence/after/behavior.txt`
