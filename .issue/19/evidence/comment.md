## [A-05] 순회 (BFS/DFS) — 구현 리포트

`bfs`/`dfs` 순회 2종을 `Connection` 첫 인자 순수 함수(`src/algorithms/traversal.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. 참조는 `bindings/python/src/graphqlite/algorithms/traversal.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **`maxDepth < 0` 만 무제한**, `maxDepth === 0` 은 `bfs('x', 0)` | ✅ `bfs('a',{maxDepth:0})` → `["a"]` (시작 노드만), 기본 `-1` → 전체 |
| `.toList()` → `extractAlgoArray` | ✅ 코어의 `column_0` 배열 언랩 |
| 각 행 `parseTraversalResult`, `null` 제외 | ✅ `user_id` 없는 행 제거 |
| 반환 키 | ✅ `["user_id","depth","order"]` (아래 주의 참조) |
| `startId` 는 `escapeString` 통과 | ✅ `bfs("x'y")` 예외 없이 `[]` |
| 별칭 `breadthFirstSearch` / `depthFirstSearch` | ✅ 동일 함수 참조 |

### 반환 키 결정 — `user_id` (이슈 본문 `userId` 표기와의 조정)
이슈 본문은 반환 키를 `userId`로 적었지만, 수용 기준이 **"각 행은 `parseTraversalResult`로 처리"** 를 명시합니다. 그 파서(#6에서 병합, `parsing.ts:164`)와 Python 참조는 모두 **`user_id`**(snake_case)를 반환합니다. 파서 계약과 Python 일관성을 따라 `user_id`로 재현했습니다.

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0 / a→b→c→d 경로 그래프)

```text
bfs('a') 무제한               ["a","b","c","d"]
dfs('a') 무제한               ["a","b","c","d"]
bfs('a',{maxDepth:0})         ["a"]            (0은 무제한 아님 — 흔한 착각 지점 재현)
bfs('a',{maxDepth:1})         ["a","b"]
bfs 반환 키                   ["user_id","depth","order"]
bfs 첫 행                     {"user_id":"a","depth":0,"order":0}
breadthFirstSearch===bfs      true
depthFirstSearch===dfs        true
bfs("x'y") escape 안전        []
```

### Before → After
- **Before** (`origin/main` `57559b7`): `src/algorithms/` 에 traversal.ts 부재, 158 테스트 통과.
- **After**: `bfs`/`dfs` + 별칭 2 공개 + Graph 위임, **167 테스트** — 확장 有 167/167, `tsc --noEmit` 무오류.

### 변경 파일
- `src/algorithms/traversal.ts` (신규) — 순수 함수 2종 + 별칭 2 (maxDepth 경계·escapeString)
- `src/graph/index.ts` — `traversal — #19` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 함수·타입 re-export
- `test/traversal.test.ts` (신규) — mock 수용 기준(maxDepth 경계·null 제외·escape·별칭) + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/19/evidence/before/state.txt`
- 테스트/타입체크: `.issue/19/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/19/evidence/after/behavior.txt`
