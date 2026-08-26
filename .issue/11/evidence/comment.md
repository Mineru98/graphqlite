## [E-01] 엣지 읽기·삭제 — 구현 리포트

엣지 읽기·삭제 4종을 `Connection` 첫 인자 **순수 함수**(`src/graph/edges.ts`)로 구현하고 `Graph` 파사드(#8)에 위임했습니다. #9(노드)와 대칭 구조입니다. 참조는 `bindings/python/src/graphqlite/graph/edges.py`. `upsertEdge` 는 같은 파일이라 #12(E-02)로 순차 진행합니다.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 노드 id 는 `$src`/`$tgt` 바인딩, `relType` 만 `sanitizeRelType` 후 보간 | ✅ `relPattern = relType ? ':'+sanitizeRelType(relType) : ''` |
| `hasEdge` 파싱은 `hasNode` 와 동일 | ✅ 빈→false, falsy `cnt`→false, 그 외 `Number(cnt)>0` |
| `getEdge` 빈 결과→null, 아니면 `row.r` 그대로 | ✅ |
| `getAllEdges` 는 `toList()` 가공 없이 반환 (키 `source`/`target`/`r`) | ✅ |

### 대상 / Cypher
| 메서드 | Cypher |
|---|---|
| `hasEdge` | `MATCH (a {id: $src})-[r{relPattern}]->(b {id: $tgt}) RETURN count(r) AS cnt` |
| `getEdge` | `... RETURN r` |
| `deleteEdge` | `... DELETE r` |
| `getAllEdges` | `MATCH (a)-[r]->(b) RETURN a.id AS source, b.id AS target, r` |

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
hasEdge('alice','bob')          : true
hasEdge('alice','bob','KNOWS')  : true
hasEdge('bob','alice') (방향성)  : false
getEdge('alice','bob')          : {"id":1,"type":"KNOWS","startNode":1,"endNode":2,"properties":{"since":2020}}
getAllEdges()                   : [{"source":"alice","target":"bob","r":{"id":1,"type":"KNOWS",...,"properties":{"since":2020}}}]
deleteEdge 후 hasEdge           : false
```

### Before → After
- **Before** (`origin/main`): `src/graph/` 에 `index.ts`+`nodes.ts`(edges.ts 부재), 99 테스트 통과.
- **After**: `hasEdge`/`getEdge`/`deleteEdge`/`getAllEdges` 공개 + Graph 위임, **107 테스트** — 확장 유 107/107, 무 96 통과+11 게이트 skip, `tsc --noEmit` 무오류.

### 변경 파일
- `src/graph/edges.ts` (신규) — 순수 함수 4개(relPattern·sanitizeRelType 포함)
- `src/graph/index.ts` — `edges — #11` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 엣지 함수 re-export
- `test/edges.test.ts` (신규) — mock Cypher parity·relType sanitize·파싱 단위 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 엣지 함수 반영

### 증거 원본
- baseline: `.issue/11/evidence/before/state.txt`
- 테스트/타입체크: `.issue/11/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/11/evidence/after/behavior.txt`
