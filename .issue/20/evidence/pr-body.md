관련 이슈: [#20 [A-06] 유사도 (nodeSimilarity/knn/triangleCount)](https://github.com/Mineru98/graphqlite/issues/20) (통합 테스트 뒤 close)

유사도·군집 알고리즘 3종을 `Connection` 첫 인자 순수 함수(`src/algorithms/similarity.ts`)로 구현하고 `Graph` 파사드에 위임했습니다. **이 모듈만 `extractAlgoArray` 를 쓰지 않고 결과를 직접 순회**합니다. 참조는 `bindings/python/src/graphqlite/algorithms/similarity.py`.

## 변경 내용
- `src/algorithms/similarity.ts` (신규) — `nodeSimilarity` / `knn` / `triangleCount` + 별칭 `triangles`
- `src/graph/index.ts` — `similarity — #20` 삽입 지점에 위임 메서드 4개
- `src/index.ts` — 함수·타입 re-export
- `test/similarity.test.ts` (신규) — mock 수용 기준 + 게이트된 실제 확장
- `test/smoke.test.ts` — 공개 표면 단언에 반영

## 수용 기준
- **`extractAlgoArray` 미사용** — CypherResult 직접 순회(코어의 column_0 래핑 언랩 안 함 → 실제 코어에선 빈 결과, Python 비일관성 재현)
- `nodeSimilarity` **4갈래 분기**(우선순위), **`topK` 만 주고 threshold===0 이면 topK 무시**(분기 4)
- `nodeSimilarity` 키 `node1`/`node2`/`similarity`(둘 다 not-null), `knn` 키 `neighbor`/`similarity`/`rank`
- `triangleCount` 키 `nodeId`/`userId`/`triangles`/`clusteringCoefficient`(camelCase — 이슈 명시 + components.ts 컨벤션), 별칭 `triangles`
- 문자열 인자 `escapeString`

## 검증
- `node --test` → 확장 있으면 179/179 통과
- `npx tsc --noEmit` → 무오류

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/20)
