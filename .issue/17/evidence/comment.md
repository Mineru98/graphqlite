## [A-03] 연결 요소 (WCC/SCC) — 구현 리포트

연결 요소 2종을 `Connection` 첫 인자 순수 함수(`src/algorithms/components.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. 참조는 `bindings/python/src/graphqlite/algorithms/components.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 둘 다 `extractAlgoArray` 거치고 `nodeId !== null` 행만 수집 | ✅ |
| 반환 키: `nodeId`, `userId`, `component` | ✅ safeInt |
| 별칭이 동일 함수를 가리킨다 | ✅ `wcc`/`connectedComponents`→weakly, `scc`→strongly |

### 대상 / Cypher
| 메서드 | Cypher | 별칭 |
|---|---|---|
| `weaklyConnectedComponents()` | `RETURN wcc()` | `wcc`, `connectedComponents` |
| `stronglyConnectedComponents()` | `RETURN scc()` | `scc` |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0 / 두 클러스터 a↔b, c↔d)

```text
weaklyConnectedComponents() 노드수        4
  → 서로 다른 component 수                  2
wcc()[0]                               {"nodeId":"1","userId":"a","component":0}
wcc===weaklyConnectedComponents        true
connectedComponents===wcc              true
stronglyConnectedComponents() 노드수      4
scc===stronglyConnectedComponents      true
```
→ 두 클러스터가 서로 다른 component 번호(2개)로 나뉘고, 별칭 3개가 모두 원 함수와 동일 결과.

### Before → After
- **Before** (`origin/main`): `src/algorithms/` 에 centrality/community/parsing 뿐(components.ts 부재), 145 테스트 통과.
- **After**: 2종+별칭 3 공개 + Graph 위임, **149 테스트** — 확장 유 149/149, 무 131 통과+18 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/algorithms/components.ts` (신규) — 순수 함수 2종 + 별칭 3
- `src/graph/index.ts` — `components — #17` 삽입 지점에 위임 메서드 5개
- `src/index.ts` — 함수·타입 re-export
- `test/components.test.ts` (신규) — mock Cypher parity·nodeId 필터·키·별칭 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/17/evidence/before/state.txt`
- 테스트/타입체크: `.issue/17/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/17/evidence/after/behavior.txt`
