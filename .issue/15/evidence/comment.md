## [A-01] 중심성 알고리즘 5종 (centrality.ts) — 구현 리포트

중심성 알고리즘 5종을 `Connection` 첫 인자 순수 함수(`src/algorithms/centrality.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. **알고리즘 계열은 파라미터 바인딩 없이 전부 문자열 보간**입니다. 참조는 `bindings/python/src/graphqlite/algorithms/centrality.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 전부 `extractAlgoArray` 를 거친다 | ✅ |
| **`pagerank` 만 `score !== null` 조건 추가** (나머지는 `nodeId !== null` 만 검사) | ✅ 비대칭 재현 |
| `degreeCentrality` 키: `nodeId`/`userId`/`inDegree`/`outDegree`/`degree` | ✅ safeInt |
| 나머지 키: `nodeId`/`userId`/`score` | ✅ safeFloat |
| `betweenness`/`closeness` 별칭 제공 | ✅ |
| 숫자 인자는 보간되므로 유한수 검증 추가 | ✅ NaN/Infinity/비수 → `ValidationError` |

### 대상 5종 / Cypher
| 메서드 | Cypher |
|---|---|
| `pagerank(0.85, 20)` | `RETURN pageRank({damping}, {iterations})` |
| `degreeCentrality()` | `RETURN degreeCentrality()` |
| `betweennessCentrality()` | `RETURN betweennessCentrality()` |
| `closenessCentrality()` | `RETURN closenessCentrality()` |
| `eigenvectorCentrality(100)` | `RETURN eigenvectorCentrality({iterations})` |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0 / 삼각형 그래프 a→b→c→a)

```text
pagerank()[0]                  {"nodeId":"1","userId":"a","score":0.3333333433}
degreeCentrality()[0] (키)      {"nodeId":"1","userId":"a","inDegree":1,"outDegree":1,"degree":2}
betweennessCentrality() 개수     3
closenessCentrality() 개수       3
eigenvectorCentrality() 개수     3
betweenness===betweennessCentrality true
pagerank(NaN) 검증               ValidationError
```

### Before → After
- **Before** (`origin/main`): `src/algorithms/` 에 parsing.ts 뿐(centrality.ts 부재), 129 테스트 통과.
- **After**: 5종+별칭 2 공개 + Graph 위임, **138 테스트** — 확장 유 138/138, 무 122 통과+16 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/algorithms/centrality.ts` (신규) — 순수 함수 5종 + 별칭 2(문자열 보간·비대칭 필터·유한수 검증)
- `src/graph/index.ts` — `centrality — #15` 삽입 지점에 위임 메서드 7개(5종 + 별칭 2)
- `src/index.ts` — 함수·타입 re-export
- `test/centrality.test.ts` (신규) — mock 보간·비대칭·키·검증·별칭 단위 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/15/evidence/before/state.txt`
- 테스트/타입체크: `.issue/15/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/15/evidence/after/behavior.txt`
