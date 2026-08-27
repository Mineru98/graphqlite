관련 이슈: [#19 [A-05] 순회 (BFS/DFS)](https://github.com/Mineru98/graphqlite/issues/19) (통합 테스트 뒤 close)

`bfs`/`dfs` 순회 2종을 `Connection` 첫 인자 순수 함수(`src/algorithms/traversal.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. 참조는 `bindings/python/src/graphqlite/algorithms/traversal.py`.

## 변경 내용
- `src/algorithms/traversal.ts` (신규) — `bfs` / `dfs` + 별칭 `breadthFirstSearch` / `depthFirstSearch`
- `src/graph/index.ts` — `traversal — #19` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 함수·타입 re-export
- `test/traversal.test.ts` (신규) — mock 수용 기준 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

## 수용 기준
- **`maxDepth < 0` 만 무제한**, `maxDepth === 0` 은 `bfs('x', 0)` (흔한 착각 지점)
- `.toList()` → `extractAlgoArray`, 각 행 `parseTraversalResult`, `null` 제외
- 반환 키 `user_id`/`depth`/`order` — 이슈 본문 `userId` 표기는 파서 계약(`parseTraversalResult`)과 Python 일관성에 따라 `user_id`로 재현(리포트에 명시)
- `startId` 는 `escapeString` 통과

## 검증
- `node --test` → 확장 있으면 167/167 통과
- `npx tsc --noEmit` → 무오류

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/19)
