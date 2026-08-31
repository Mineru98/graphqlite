## 작업 요약

TypeScript bulk insert가 행·속성마다 수행하던 정적 SQL `prepare()`를 bulk 호출당 한 번으로 제한했습니다. prepared statement 실행부는 `bulk-sql.ts`로 분리했고, 반복 관계 타입 sanitization도 호출 범위 캐시로 줄였습니다. 공개 package export, 트랜잭션/rollback, property type routing, endpoint lookup 동작과 C 코어는 변경하지 않았습니다.

구현 커밋: `7ecda7ae198a665308f6d8970c7b1e35bd40cc1e`

## 성능 비교

| 데이터셋 / 지표 | 전 (ms) | 후 (ms) | 변화 |
| --- | ---: | ---: | ---: |
| 5K/10K TS build | 124.161 | 47.377 | **-61.8%** |
| 5K/10K TS / 최속 타 언어 | 3.264x | 1.238x | **목표 1.25x 이내** |
| 5K/10K scan | 8.165 | 8.051 | **-1.4%** |
| 5K/10K PageRank | 8.616 | 7.662 | **-11.1%** |
| 5K/10K BFS | 7.337 | 5.538 | **-24.5%** |
| 20K/40K TS build | 518.563 | 195.503 | **-62.3%** |
| 20K/40K TS / 최속 타 언어 | 3.337x | 1.245x | **목표 1.25x 이내** |
| 20K/40K scan | 31.150 | 29.807 | **-4.3%** |
| 20K/40K PageRank | 31.990 | 28.808 | **-9.9%** |
| 20K/40K BFS | 27.512 | 20.697 | **-24.8%** |

측정 조건: macOS arm64, Node v25.9.0, Python 3.14.4, Rust 1.95.0, 각 1회 warm-up 후 5회 중앙값. 전후 모두 동일한 `graphqlite.dylib` SHA-256 `231b2477efb6d498920389013566c6d5aefb2e3643e6845d7b53834bddeaed8b`를 사용했습니다. 모든 연산의 결과 count가 세 바인딩에서 일치했습니다. 원본은 `.issue/102/evidence/before/`와 `.issue/102/evidence/after/`에 있습니다.

## 변경 파일

- `bindings/typescript/src/graph/bulk-sql.ts` — node/edge/property prepared statement 묶음과 실행 helper 추가
- `bindings/typescript/src/graph/bulk.ts` — bulk 호출 범위 statement·관계 타입 캐시 재사용
- `bindings/typescript/test/bulk.test.ts` — 입력 크기와 무관한 정적 SQL prepare 횟수 회귀 테스트 추가

## 검증

- `test/bulk.test.ts`: 16/16 통과
- `npm run typecheck`: 통과
- 변경 파일 ESLint: 통과
- `npm run build`: 통과
- parity results/cypher: Python↔TS, Rust↔TS 모두 mismatch 0으로 통과
- 변경 TypeScript 파일 pure LOC: 212 / 154 / 216으로 모두 250 이하
- `src/index.ts` 해시가 `origin/main`과 동일해 공개 package export 무변경 확인
- C/Python/Rust 소스 무변경 확인

## 선행 게이트 상태

- 전체 `npm test`는 변경하지 않은 `test/paths.test.ts`의 기존 기대값 불일치 1건으로 실패하며, `origin/main`에서도 동일 dylib로 같은 실패를 재현했습니다. 벌크 관련 테스트는 모두 통과합니다.
- 전체 `npm run lint`는 변경하지 않은 `src/graph/nodes.ts:109`의 기존 `_ignoredId` 미사용 오류 1건으로 실패합니다. 변경 파일 lint는 통과합니다.
- programming no-excuse 검사기는 프로젝트 TypeScript 5.x에 없는 TypeScript 7 `unstable/*` API를 요구해 실행할 수 없었습니다. 타입 검사·ESLint·빌드는 통과했습니다.

## 남은 이슈

- #102 범위 내 미해결 항목 없음. 위 선행 게이트 2건은 별도 정리가 필요합니다.
