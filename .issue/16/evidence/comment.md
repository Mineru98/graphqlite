## [A-02] 커뮤니티 탐지 (community.ts) — 구현 리포트

커뮤니티 탐지 2종을 `Connection` 첫 인자 순수 함수(`src/algorithms/community.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. `leidenCommunities` 는 Python 전용 의존성 때문에 이식하지 않고 스텁으로 처리했습니다. 참조는 `bindings/python/src/graphqlite/algorithms/community.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **`communityDetection` 은 `nodeId`·`community` 둘 다 검사, `louvain` 은 `nodeId` 만** (비대칭) | ✅ |
| 반환 키: `nodeId`, `userId`, `community` | ✅ safeInt |
| **`leidenCommunities` 미이식** (Python 전용 graspologic). `Graph` 스텁이 `UnsupportedOperationError`(사유 안내) | ✅ code `UNSUPPORTED_OPERATION` |

### 대상 / Cypher
| 메서드 | Cypher | 필터 |
|---|---|---|
| `communityDetection(10)` | `RETURN labelPropagation({iterations})` | nodeId!=null **AND community!=null** |
| `louvain(1.0)` | `RETURN louvain({resolution})` | nodeId!=null |
| `leidenCommunities` | (미이식) | `UnsupportedOperationError` throw |

알고리즘 계열이라 숫자 인자는 파라미터 바인딩 없이 문자열 보간되며, 보간 전 **유한수 검증**을 합니다(#15 와 동일).

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0 / 두 클러스터 a↔b, c↔d)

```text
communityDetection()[0]          {"nodeId":"1","userId":"a","community":0}
communityDetection() 개수          4
louvain() 개수                     4
leidenCommunities()              UnsupportedOperationError (code=UNSUPPORTED_OPERATION)
communityDetection(NaN) 검증       ValidationError
```

### Before → After
- **Before** (`origin/main`): `src/algorithms/` 에 centrality/parsing 뿐(community.ts 부재), 138 테스트 통과.
- **After**: 2종 공개 + Graph 위임 + leiden 스텁, **145 테스트** — 확장 유 145/145, 무 128 통과+17 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/algorithms/community.ts` (신규) — 순수 함수 2종(비대칭 필터·유한수 검증)
- `src/errors.ts` — `UnsupportedOperationError`(code `UNSUPPORTED_OPERATION`) 추가
- `src/graph/index.ts` — `community — #16` 삽입 지점에 위임 2개 + `leidenCommunities()` 스텁
- `src/index.ts` — 함수·타입 + `UnsupportedOperationError` re-export
- `test/community.test.ts` (신규) — mock 보간·비대칭·키·검증 + leiden throw + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/16/evidence/before/state.txt`
- 테스트/타입체크: `.issue/16/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/16/evidence/after/behavior.txt`
