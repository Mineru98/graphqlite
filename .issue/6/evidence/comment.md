## [F-06] 알고리즘 결과 파서 (algorithms/parsing.ts) — 작업 리포트

알고리즘 결과의 `[{"column_0":[...]}]` 한 겹 래핑을 벗기는 파서를 Python 에서 이식했습니다. UI 없는 로직 작업이라 증거는 테스트·타입 검사 출력으로 남깁니다.

### 생성 파일
```
bindings/typescript/src/algorithms/parsing.ts         # ALGO_COLUMN_NAMES, extractAlgoArray, safeFloat/safeInt, 파서 4종
bindings/typescript/test/algorithms-parsing.test.ts   # node:test 11개
```

### Python 대조 (`bindings/python/src/graphqlite/algorithms/_parsing.py`)
- `ALGO_COLUMN_NAMES` 13개 **순서 그대로** 복사.
- **의도된 불일치 보존**: 목록은 snake(`pagerank()`, `degree_centrality()`)인데 실제 질의는 camel(`pageRank(...)`)이라 대부분 매칭 안 되고 `column_0` 이 걸림. **"고치지 않고" 그대로 복사**하고 코드 주석으로 의도·후속 개선 이슈를 명시 (고치면 언랩 동작이 바뀜).
- `extractAlgoArray`: 행이 정확히 1개일 때만 컬럼명 순서로 훑어 배열 언랩, 아니면 입력 그대로.
- 미사용 파서 3종(`parseScoreResult`/`parseCommunityResult`/`parseComponentResult`)도 표면 동일성 위해 이식 (Python 에 정의만, 호출부 없음).
- `safeFloat`/`safeInt`: null·변환 실패 시 기본값. `safeInt` 는 Python `int()` 재현(float 절삭, `'1.5'` 문자열은 실패→기본값).

### 검증 (Node v24.13.0 / npm 11.6.2)
```
$ npx tsc --noEmit
TypeScript: No errors found   # exit 0

$ npm test          # node --test
ℹ tests 43 (parsing 11 + result 11 + errors 10 + platform 9 + smoke 2)
ℹ pass 43   ℹ fail 0
```
> utils.ts(#5, PR #37)는 아직 main 미병합이라 이 워크트리 기준 테스트 수에 미포함됩니다.

### 수용 기준 체크
- [x] `ALGO_COLUMN_NAMES` snake↔camel 불일치를 "고치지 않고" 이식 (주석·개선 이슈 참조)
- [x] 미사용 파서 3종 이식 (표면 동일성)
- [x] `safeFloat`/`safeInt` 가 null·변환 실패 시 기본값 반환

### 스코프 메모
- 이 원소는 #15·#16·#17·#18·#19·#20(알고리즘 6종)의 선수 조건을 풉니다.

### 참고
- 브랜치: `feat/6-issue-6`
- 커밋: `dcaac6f`
