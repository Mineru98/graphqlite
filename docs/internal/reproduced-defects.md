# 재현한 결함 추적 (Reproduced Defects)

> 원소 `X-02` (#32). TypeScript 바인딩은 **"Python 동작을 비일관성까지 그대로 재현"** 정책으로
> 구현했다. 그 과정에서 **의도적으로 재현한 결함들**을 잊지 않도록 여기에 기록한다.
> 각 항목은 개별 추적 이슈로 분리했다. **수정 시 Python·Rust·TS 세 바인딩을 함께 고쳐야
> parity(대조 하네스, #30)가 유지된다.**

이 문서는 구현이 아니라 **기록**이다. 아래 결함들은 버그가 아니라 *정책상 의도적으로 보존한*
동작이며, 코드에도 해당 지점마다 정직한 주석이 달려 있다.

## 바인딩 계층 (세 바인딩 공통)

| # | 결함 | 근거 (TS) | 추적 이슈 |
|---|------|-----------|-----------|
| 1 | ~~`astar` 가 `column_0` 언랩을 하지 않는다 — `shortestPath` 와 비대칭~~ **수정됨(#64)**: 세 바인딩 astar 가 이제 `column_0` 을 언랩한다 | `bindings/typescript/src/algorithms/paths.ts` astar | #64 |
| 2 | ~~`ALGO_COLUMN_NAMES` 가 snake_case(`pagerank()`)인데 실제 Cypher 는 camelCase(`pageRank(...)`)라 대부분 매칭되지 않는다~~ **수정됨(#65)** — 세 바인딩의 named 항목을 실제 camelCase 함수명으로 교정. `column_0` 이 항상 먼저 매칭되어 동작은 불변 | `bindings/typescript/src/algorithms/parsing.ts:16` | #65 |
| 3 | `sanitizeRelType` 이 두 벌 존재한다 (`utils` vs `bulk`) — 예약어 처리와 빈 문자열 결과가 다르다 | `bindings/typescript/src/utils.ts`, `src/graph/bulk.ts:321` | #66 |
| 4 | ~~`unloadGraph` 만 `nodes`/`edges` → `nodeCount`/`edgeCount` 키 rename 을 하지 않는다~~ **정리됨(#67)** — unloadGraph 도 remap 을 통과시켜 대칭화. 코어 unload 응답엔 `nodes`/`edges` 키가 없어 동작 불변 | `bindings/typescript/src/graph/cache.ts:59` | #67 |
| 5 | `GraphManager.query(graphs=None)` 의 자동 감지가 docstring 에만 있고 구현이 없다 | `bindings/typescript/src/manager.ts` | #68 |
| 6 | `namespace` 파라미터가 저장만 되고 어디서도 쓰이지 않는다 (dead parameter) | `bindings/typescript/src/graph/index.ts:113-119` | #69 |
| 7 | `upsertNode` 의 생성/갱신 경로가 `id` 덮어쓰기에서 비대칭이다 | `bindings/typescript/src/graph/nodes.ts:99-124` | #70 |
| 8 | ~~`nodeSimilarity` 에서 `topK` 만 주고 `threshold === 0` 이면 `topK` 가 조용히 무시된다~~ **수정됨(#71)** — 세 바인딩에서 분기 2 조건을 `topK>0` 로 앞당겨 `topK` 만 줘도 `nodeSimilarity(threshold, topK)` 를 방출. 기존 threshold 케이스는 방출·동작 불변 | `bindings/typescript/src/algorithms/similarity.ts` · `python/algorithms/similarity.py` · `rust/src/algorithms/similarity.rs` | #71 |

### 상세

1. **`astar` column_0 비대칭 — 수정됨(#64)** — 과거 `shortestPath`(dijkstra)는 결과 행의 `column_0` 래퍼를
   언랩했지만 `astar` 는 직접 필드 접근이라 코어가 결과를 `column_0` 에 담으면 default 를 반환했다.
   #64 에서 세 바인딩(Python·Rust·TS) 의 `astar` 가 `shortestPath` 와 동일하게 `column_0` 을 언랩하도록
   수정했다(없을 때 직접 접근 fallback 유지, `nodes_explored` 도 언랩된 객체에서 읽음). 이제
   `shortestPath`·`astar`·`apsp` 세 경로 모두 `column_0` 래퍼를 정상 처리한다.
2. **`ALGO_COLUMN_NAMES` 케이스 불일치** — 결과 컬럼 이름 매칭 테이블이 snake_case 인데 실제 방출되는
   Cypher 함수는 camelCase 라, 대부분의 알고리즘 결과가 이름 매칭에 실패한다.
3. **`sanitizeRelType` 두 벌** — `utils` 버전은 Cypher 예약어 검사가 있고 빈 결과가 `REL_`,
   `bulk` 버전은 예약어 검사가 없고 빈 결과가 `REL`. 합치면 동작이 바뀌므로 분리 유지 중.
4. **`unloadGraph` rename 누락** — `loadGraph`/`reloadGraph` 는 `remapCacheStatus` 로 키를 바꾸지만
   `unloadGraph` 는 raw 키(`nodes`/`edges`)를 그대로 반환한다.
5. **`GraphManager.query` 자동 감지 부재** — `graphs` 를 생략/빈 배열로 주면 `#attach` 가 호출되지 않아
   아무 그래프도 ATTACH 되지 않는다. docstring 만 자동 감지를 주장한다.
6. **`namespace` dead parameter** — 생성 시 `this.namespace` 에 저장되지만 어떤 쿼리에서도 쓰이지 않는다.
7. **`upsertNode` 생성/갱신 비대칭** — 생성은 `{id: nodeId, ...nodeData}` 라 `nodeData.id` 가 `nodeId` 를
   덮어쓰지만(나중 spread 승), 갱신은 `nodeData` 항목만 `SET` 하고 `id` 는 건드리지 않는다.
8. **`nodeSimilarity` topK 무시 — 수정됨(#71)** — 과거 인자 우선순위 분기 2 가 `threshold>0 && topK>0` 이라
   `threshold === 0 && topK > 0` 은 인자 없는 `nodeSimilarity()` 분기로 떨어져 `topK` 가 무시됐다. #71 에서
   세 바인딩의 분기 2 조건을 `topK>0` 로 바꿔 `topK` 만 줘도 `nodeSimilarity(threshold, topK)`(threshold 0 포함)
   를 방출하게 했다. 코어(`graph_algorithms.c`)는 `nodeSimilarity(0, topK)` 를 top_k 로 정상 처리한다. 기존
   threshold 케이스의 방출·동작은 불변이라 parity 게이트에 영향이 없다.

## 코어 제안

| # | 제안 | 추적 이슈 |
|---|------|-----------|
| 9 | **DDL 요약을 평문이 아니라 JSON 으로 반환**하면 세 바인딩 모두에 이롭다 | #72 |

현재 `Query executed successfully - nodes created: 1, relationships created: 0` 은 공식 계약이 아닌
사람용 문자열이라 각 바인딩이 best-effort 로 파싱하고 있다. JSON 반환은 코어(C) 변경이며 세 바인딩의
파싱 로직에 영향을 준다.

## 진행 방식

- 위 9개 항목은 각각 개별 이슈(#64~#72)로 분리해 추적한다.
- 실제 수정은 **세 바인딩을 함께** 고쳐야 하며, 수정 후 대조 하네스(#30, `scripts/parity-check.sh`)의
  해당 `allowlist` 항목을 함께 제거해 회귀를 막는다.
