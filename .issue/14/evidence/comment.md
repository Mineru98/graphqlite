## [C-01] 그래프 캐시 4종 (cache.ts) — 구현 리포트

그래프 캐시 제어 4종을 `Connection` 첫 인자 순수 함수(`src/graph/cache.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. 다른 그래프 모듈과 달리 **Cypher 가 아니라 raw SQL 스칼라 함수를 `execute()` 로** 호출합니다. 참조는 `bindings/python/src/graphqlite/graph/__init__.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| `cypher()` 를 거치지 않고 `execute()` 로 직접 호출 | ✅ mock 으로 execute() SQL·cypher() 미호출 검증 |
| **`loadGraph`/`reloadGraph` 만** `nodes`→`nodeCount`, `edges`→`edgeCount` rename. **`unloadGraph` 는 rename 안 함** (Python 비대칭 재현, 개선은 X-02) | ✅ |
| 행이 없으면 빈 객체로 처리 | ✅ |

### 대상 4종 / SQL
| 메서드 | SQL | 후처리 |
|---|---|---|
| `loadGraph` | `SELECT gql_load_graph()` | JSON 파싱 + rename |
| `unloadGraph` | `SELECT gql_unload_graph()` | JSON 파싱만 |
| `reloadGraph` | `SELECT gql_reload_graph()` | JSON 파싱 + rename |
| `graphLoaded` | `SELECT gql_graph_loaded()` | `loaded` 키 기본 false → boolean |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
graphLoaded() 초기             false
loadGraph() (rename O)       {"status":"loaded","nodeCount":2,"edgeCount":1}
graphLoaded() load 후         true
reloadGraph() (rename O)     {"status":"reloaded","previous_nodes":2,"previous_edges":1,"nodeCount":2,"edgeCount":1}
unloadGraph() (rename X)     {"status":"unloaded"}
graphLoaded() unload 후       false
```
→ load/reload 는 `nodeCount`/`edgeCount` 로 rename, unload 는 그대로. reload 의 `previous_nodes`/`previous_edges` 는 rename 대상이 아니라 원형 유지(Python 과 동일).

### Before → After
- **Before** (`origin/main`): `src/graph/` 에 cache.ts 부재, 123 테스트 통과.
- **After**: 4종 공개 + Graph 위임, **129 테스트** — 확장 유 129/129, 무 114 통과+15 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/cache.ts` (신규) — `execute()` 기반 4종(비대칭 rename·no-row 처리)
- `src/graph/index.ts` — `cache — #14` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 4개 함수 + `CacheStatus` 타입 re-export
- `test/cache.test.ts` (신규) — mock execute·cypher 미호출·비대칭 remap·no-row 단위 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 4종 반영

### 증거 원본
- baseline: `.issue/14/evidence/before/state.txt`
- 테스트/타입체크: `.issue/14/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/14/evidence/after/behavior.txt`
