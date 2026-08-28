# TS 바인딩 3자(Python·Rust) 동작 동등성 검증 루브릭

> 목적: 신규 개발한 **TypeScript 인터페이스**가 이미 검증된 **Python·Rust** 바인딩과
> *동일하게 동작*하는지를, 주관 판단이 아니라 재현 가능한 채점표로 판정한다.
> TS를 피험 대상(subject-under-test), Python·Rust를 기준(reference)으로 삼는다.
>
> 관련 선행 자산: `scripts/parity-check.sh`, `bindings/typescript/test/parity/`
> (`scenarios.json`·`run-ts.ts`·`run_python.py`·`compare.py`·`allowlist.json`) — 현재 **Python↔TS 2자**만 커버.
> 상위 설계 문서: `docs/internal/typescript-bindings-design.md`, `docs/internal/reproduced-defects.md`.

---

## 0. 배경 사실 (근거 확인 완료)

- 세 바인딩은 모두 **동일한 C 코어**(`src/extension.c`)에 Cypher 문자열을 던지는 얇은 래퍼다.
  따라서 "동작 동등성"의 인과적 뿌리는 **각 바인딩이 코어로 방출하는 Cypher 문자열/파라미터**다.
  최근 수정 커밋 #82/#71/#70/#65/#64/#67은 전부 이 방출·언랩 계층의 바인딩 간 불일치였다.
- **명명 규약이 3자 모두 다르다** → 정규화 없이는 값 비교 불가.
  - TS: camelCase + 옵션객체 (`nodeSimilarity` 한정), 반환 키 camelCase
  - Python: snake_case + 기본값 위치인자, 반환 dict snake_case
  - Rust: snake_case + `Option<&str>` + **기본값 없는 전량 위치인자**, serde 기본 직렬화(snake_case)
- **TS는 Python 동작을 의도적으로 미러링**(알려진 비일관성까지 재현)한다. Rust는 독립 구현이며
  **parity 하네스 밖**이다 → 이번 루브릭의 최우선 선행 과제는 **Rust 레그(run_rust) 추가**.
- **의도된 발산은 이미 문서화**되어 있다 (`allowlist.json`, 6건). 3자 확장 시 재정의·확장 필요.

---

## 1. 평가 차원(Dimensions)과 가중치

| #  | 차원 | 무엇을 보는가 | 가중치 | 게이트 |
|----|------|--------------|-------|--------|
| D1 | API 표면 매핑 완전성 | Python·Rust의 모든 공개 메서드가 TS에 대응(또는 allowlist에 의도적 누락으로 문서화)되는가; 인자 순서·옵셔널·기본값·반환 shape 매핑이 맞는가 | 15% | 필수 |
| D2 | 반환값 동등성 (results) | 정규화 후 반환값이 3자 동일 (수치 동등·행순서 무시) | 25% | **하드 게이트** |
| D3 | 방출 Cypher 동등성 (cypher) | 코어로 나가는 쿼리 문자열+파라미터가 3자 동일 (순서 유의) | 25% | **하드 게이트** |
| D4 | 오류 의미론 동등성 | 동일 입력→동일 오류 부류/발생 지점; 오류 타입 매핑표; 의도적 발산 문서화 | 15% | 필수 |
| D5 | 경계·엣지·회귀 케이스 | 공통 엣지셋 + **과거 수정 버그 6종 회귀 잠금** | 15% | 필수 |
| D6 | 상태·캐시·수명주기 | load/unload/reload 캐시 remap(#67), 다중 그래프 매니저, 커넥션 수명 | 5% | 권장 |

> D2·D3이 하드 게이트인 이유: 이 둘이 곧 "동일 동작"의 조작적 정의다.
> 나머지 차원은 이 둘이 **왜** 일치/불일치하는지를 설명·보강한다.

---

## 2. 차원별 채점 기준(Rubric levels)

각 차원을 **0(Fail) / 1(Partial) / 2(Pass) / 3(Exemplary)** 4단계로 채점한다.

### D1 — API 표면 매핑 완전성
- **3** 공유 공개 API 100%가 Appendix A 매핑표에 존재하고, 각 항목의 (인자순서·옵셔널·기본값·반환키)
  대응이 코드 인용과 함께 명시. 미대응은 전부 allowlist에 사유와 함께 등재.
- **2** 100% 매핑되나 일부 항목의 기본값/옵셔널 의미 대조가 서술 수준(코드 인용 없음).
- **1** 매핑 누락 항목이 있으나 allowlist 미등재.
- **0** 매핑표 부재 또는 미매핑 다수.

*판정 포인트*: TS 옵션객체 ↔ Python 기본값인자 ↔ Rust 전량 위치인자의 **기본값 의미가 일치**하는가.
예: `nodeSimilarity` 인자 미지정 시 세 바인딩 모두 `threshold=0, topK=0` 경로로 수렴(#71/#82 회귀 지점).

### D2 — 반환값 동등성 (results 모드) — 하드 게이트
- **3** 전 시나리오 정규화 후 완전 일치, allowlist 발산 각각에 재현 근거 첨부.
- **2** 완전 일치하나 allowlist 사유가 빈약.
- **1** 미등재 불일치 1건 이상.
- **0** 미등재 불일치 다수 또는 러너 크래시.

**정규화 규약(필수 고정, `compare.py` 규약 그대로 3자 적용)**:
dict 키 camelCase→snake_case 후 정렬 · float 1e-6 반올림 · int/float 노이즈 합치기(`round(float(x),6)`)
· 배열은 정준 정렬(행순서 무의미) · 오류 스텝은 `("error", 오류타입)`으로만 비교(메시지 제외).

### D3 — 방출 Cypher 동등성 (cypher 모드) — 하드 게이트
- **3** 방출 쿼리 시퀀스(문자열+파라미터)가 순서까지 3자 일치, allowlist 발산(예: louvain `1.0` vs `1`)만 예외.
- **2** 일치하나 스파이(spy) 캡처 범위 한계가 문서화 안 됨.
- **1** 미등재 문자열 불일치 1건 이상.
- **0** 캡처 실패/미구현.

*주의*: bulk 계열은 raw SQL이라 Cypher 방출이 없음 → cypher 모드에서 3자 공집합이 정상.

### D4 — 오류 의미론 동등성
- **3** 동일 입력에 대해 (오류 부류, 발생 시점) 3자 일치. 오류 타입 매핑표
  (`ValidationError`↔`ValidationError`↔`Error::Validation` 등) 존재. 의도적 발산(F-05: TS는 코어 도달
  전 검증, Python/Rust는 코어 파스에러)은 allowlist에 등재.
- **2** 부류는 일치하나 발생 시점(코어 전/후) 대조 미서술.
- **1** 미문서화 오류 발산.
- **0** 오류 시 러너 비정상 종료 또는 오류 표면 불명.

### D5 — 경계·엣지·회귀 케이스
**회귀 잠금 필수 6종** (각각 전용 시나리오 스텝으로 고정):
1. `astar` 단일 컬럼 `column_0` 언랩 (#64)
2. `ALGO_COLUMN_NAMES` camelCase 교정 (#65)
3. `unloadGraph` 캐시 상태 remap 일관 (#67)
4. `upsertNode` id의 생성/갱신 대칭 (#70)
5. `nodeSimilarity` **topK만** 지정 (#71)
6. `nodeSimilarity` **threshold만** 지정 / `(threshold, topK)` 2인자 (#82)

- **3** 6종 회귀 전부 + 공통 엣지셋(빈 그래프·없는 노드·self-loop·중복 upsert·null 프로퍼티·유니코드 id·따옴표 이스케이프) 3자 통과.
- **2** 회귀 6종 통과, 공통 엣지셋 일부 누락.
- **1** 회귀 6종 중 누락 존재.
- **0** 회귀 케이스 미포함.

### D6 — 상태·캐시·수명주기
- **3** load/unload/reload 후 캐시 상태·재조회 결과 3자 일치, 다중 그래프 매니저 동작 대조 포함.
- **2** 단일 그래프 수명주기만 대조.
- **1/0** 미포함/불일치.

---

## 3. 최종 판정 게이트(Grade)

```
전제(선행 필수): Rust 러너(run_rust) 추가로 하네스가 3자 대조 가능해야 채점 시작.
                 미충족 시 = INCOMPLETE (등급 산정 불가)

A (합격/머지 가능): D2 = 3  AND  D3 = 3  (allowlist 발산 외 불일치 0)
                    AND D1,D4,D5 ≥ 2
                    AND 가중 총점 ≥ 90%
B (조건부):         D2·D3 하드게이트 통과, 그러나 D1/D4/D5 중 하나가 1 → 사유 명시 후 후속 이슈
C (재작업):         하드게이트(D2·D3)에 미등재 불일치 1건 이상
FAIL:              러너 크래시 / 매핑표 부재 / 회귀 6종 미포함
```

**가중 총점** = Σ(차원점수/3 × 가중치). 하드게이트(D2·D3) 미통과 시 총점과 무관하게 최대 C.
**피험 축**: TS가 피험이므로 최소 **TS↔Python** + **TS↔Rust** 두 게이트를 각각 통과해야 A.

---

## 4. 평가 방법 — 하네스 확장(선행 과제)

현 자산을 재사용하고 **Rust 레그만 추가**한다. TS/Python/Rust가 *같은* `scenarios.json`을 소비하고
*같은* JSON 스키마로 출력하면 `compare.py`가 그대로 3자를 처리한다.

공통 출력 스키마:
```
{ binding, mode, scenarios: [ { id, group, steps: [ { id, method, args,
  status: "ok"|"error", value?, error?: {type,message}, cypher?: [{query,params}] } ] } ] }
```

1. **`run_rust`** (신규, `bindings/rust/examples/parity_runner.rs`): `scenarios.json`을 읽어 fixture로
   in-memory 그래프 구성 → 각 스텝을 Rust `Graph` 메서드로 디스패치 → results/cypher 모드 JSON을 stdout으로.
   `run-ts.ts`의 `DISPATCH` 어댑터 구조를 1:1로 미러링(옵션객체 대신 위치인자 매핑).
   Cypher 스파이는 `Connection::cypher` 경로 래핑. 실행: `cargo run --example parity_runner -- --mode <m>`.
   (참고 선례: `bindings/rust/examples/tck_runner.rs`)
2. **`compare.py`를 N-way로**: 현 pairwise를 (TS↔Python, TS↔Rust) 두 번 돌리거나 3열 리포트로 확장.
3. **`allowlist.json` 확장**: 각 엔트리에 `bindings` 필드 추가(어느 쌍에 적용되는지). §5의 신규 발산 후보 반영.
4. **`parity-check.sh`에 Rust 러너 빌드/실행 단계** 추가, 동일 dylib를 `GRAPHQLITE_EXTENSION_PATH`로 공유.

---

## 5. 3자 확장 시 신규 검토가 필요한 발산 후보

기존 allowlist 6건(louvain 포맷, bulk float/int, F-05 식별자 검증 2건, leiden/rustworkx) 외에,
Rust 레그를 붙이면 **새로 표면화될 가능성이 있는 발산**:

| 후보 | 내용 | 처리 방향 |
|------|------|----------|
| 스칼라 래핑 컬럼명 | 스칼라가 배열로 올 때 Rust는 `"value"`(`result.rs`), TS/Python은 `"result"`로 감쌈 | results 정규화에서 흡수되는지 확인; 아니면 allowlist(TS↔Rust) |
| DDL summary shape | TS는 `parseMutationSummary`→`{nodesCreated,relationshipsCreated,raw}` 전용 API; Python/Rust는 result 계층에서 JSON을 단일 row로 암묵 파싱 | 시나리오에서 비교 대상 값을 무엇으로 잡을지 정의(요약 키만 비교) |
| stats 키 | TS `nodeCount/edgeCount`, Python/Rust `node_count/edge_count` | camelCase→snake_case 정규화로 흡수(확인) |
| GraphManager 명명 | Rust `open`은 생성자, 그래프 열기는 `open_graph`; 다수 메서드 `&mut self` | run_rust 디스패치 어댑터에서 매핑 |
| bulk 컨테이너 | Map(TS) / dict(Python) / HashMap(Rust) — 반환값은 동일, 컨테이너만 상이 | JSON 직렬화 시 객체로 평탄화(현 run-ts 규약과 동일) |
| label 기본값 | `upsertNode` label 기본값이 TS/Python은 `"Entity"`, Rust는 필수 인자(기본 없음) | scenarios가 항상 label을 명시하므로 무해; D1에 기록 |

---

## 6. 커버리지 요구(합격 최소선)

- 공유 공개 API 각 카테고리(노드/엣지 CRUD, 쿼리, 중심성, 커뮤니티, 컴포넌트, 경로, 순회, 유사도, 통계, bulk) **≥ 1 시나리오**.
- **회귀 6종 전부** (D5).
- **오류 표면 ≥ 3종** (없는 노드, 잘못된 식별자[F-05], 파스에러).
- Appendix A 매핑표에 등장하지 않는 공개 메서드가 있으면 D1 감점.

---

## 7. 증거 산출물(repo 이슈-증거 관례 준수)

각 실행마다 하나의 리포트로:
`parity report (mode=results)` + `parity report (mode=cypher)` 콘솔 출력(TS↔Python, TS↔Rust 각각),
사용 dylib 해시, `scenarios.json`/`allowlist.json` 스냅샷, 차원별 채점표, 최종 등급.

---

## Appendix A — 공유 공개 API 매핑표 (핵심 발췌)

명명/시그니처 대조. 전체 목록은 `bindings/*/src`의 각 모듈에서 확정하며, 아래는 판정 포인트가 있는 항목.

| 기능 | TypeScript | Python | Rust | 비고 |
|------|-----------|--------|------|------|
| upsertNode | `upsertNode(id, data, label='Entity')` | `upsert_node(id, data, label='Entity')` | `upsert_node(id, props, label)` (label 필수) | #70 id 생성/갱신 대칭; TS만 F-05 식별자 검증 |
| getNode/hasNode/deleteNode | camelCase | snake_case | snake_case | — |
| getAllNodes | `getAllNodes(label?)` | `get_all_nodes(label=None)` | `get_all_nodes(Option)` | 잘못된 label: TS ValidationError vs 코어 파스에러(F-05) |
| upsertEdge | `upsertEdge(from,to,data,type?,...)` | `upsert_edge(...)` | `upsert_edge(...)` | — |
| stats | `stats() -> {nodeCount,edgeCount}` | `stats() -> {node_count,edge_count}` | `stats() -> GraphStats{node_count,edge_count}` | 키 정규화로 수렴 |
| query | `query(cypher, params?)` | `query(cypher, params=None)` | `query(cypher, &[names])` | — |
| pagerank | `pagerank(damping?, iters?)` | `pagerank(damping, max_iter)` | `pagerank(damping, iters)` | 기본값 유무 대조 |
| eigenvectorCentrality | `(maxIter?)` | `(max_iter)` | `(max_iter)` | — |
| communityDetection/louvain | camelCase | snake_case | snake_case | louvain cypher 포맷 `1.0`vs`1`(allowlist) |
| shortestPath | `shortestPath(a,b,{weightProp})` | `shortest_path(a,b,weight_prop=...)` | `shortest_path(...)` | column_0 언랩 |
| astar | `astar(a,b,{latProp,lonProp})` | `astar(...)` | `astar(...)` | #64 column_0 언랩 |
| bfs/dfs | `bfs(a,{maxDepth})` | `bfs(a, max_depth=...)` | `bfs(...)` | — |
| **nodeSimilarity** | **옵션객체** `nodeSimilarity({node1,node2,threshold,topK})` | **위치인자** `node_similarity(n1=None,n2=None,threshold=0.0,top_k=0)` | **위치인자** `node_similarity(Option,Option,f64,i32)` | **가장 큰 표면 차이**; 4-way 분기 수렴(#71/#82) |
| knn | `knn(id,{k})` | `knn(id,k=10)` | `knn(id,k)` | k 기본값 유무 |
| triangleCount | `triangleCount()` | `triangle_count()` | `triangle_count()` | — |
| DDL summary | `parseMutationSummary` 전용 API | result 계층 암묵 파싱 | result 계층 암묵 파싱 | §5 shape 발산 |
| bulk insert | `Map` 반환 | `dict` 반환 | `HashMap` 반환 | 값 동일; 1.0→int JS 퀴크(allowlist) |
| leidenCommunities | `UnsupportedOperationError` | graspologic 의존 | (없음) | allowlist |
| toRustworkx | (없음) | rustworkx 의존 | (없음) | allowlist |

---

## Appendix B — 실행 명령

```bash
make extension                              # C 확장 빌드(build/graphqlite.dylib)
scripts/parity-check.sh --mode results      # TS↔Python 값 대조 (현재)
scripts/parity-check.sh --mode cypher       # TS↔Python 방출 Cypher 대조 (현재)
# 확장 후:
cargo run --example parity_runner -- --mode results   # (신규) Rust 레그
```
