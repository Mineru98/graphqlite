관련 이슈: [#22 [M-01] GraphManager](https://github.com/Mineru98/graphqlite/issues/22) (통합 테스트 뒤 close)

여러 그래프를 관리하는 `GraphManager`(9 메서드) + 팩토리 `graphs(basePath)` 를 `src/manager.ts` 에 구현했습니다. 디렉터리 + 그래프당 `.db` + 크로스 그래프 질의는 in-memory 코디네이터에 `ATTACH DATABASE`. 참조는 `bindings/python/src/graphqlite/manager.py`.

## 변경 내용
- `src/manager.ts` (신규) — `GraphManager` (`list`/`exists`/`create`/`open`/`openOrCreate`/`drop`/`query`/`querySql`/`close`) + 팩토리 `graphs`
- `src/index.ts` — re-export
- `test/manager.test.ts` (신규) — pure 이름 검증 + 게이트된 실제 확장 10종
- `test/smoke.test.ts` — 공개 표면 단언에 반영

## 수용 기준
- 생성자가 `basePath` 재귀 생성
- **`query()` 는 ATTACH 전 열린 모든 그래프 `commit()`**
- 이름 `assertIdentifier('graph')` + **경로 디렉터리 이탈 검사**(Python 은 `../x` 허용 — TS 는 차단)
- ATTACH `"already in use"` 무시, 나머지 전파
- **`query(graphs)` 생략 시 ATTACH 안 함**(auto-detect 미구현 재현, 문서에 명시)
- `create` 중복 / 부재 대상 에러(`GRAPH_EXISTS`/`GRAPH_NOT_FOUND`), `open` 실패에 `"Available:"` 목록
- `open` 캐시 재사용, `drop` = close→DETACH(무시)→삭제, `close()` = 전부 닫기
- double-close 관대화(Python sqlite3 대응, node:sqlite 는 던지므로 "not open" 삼킴)

## 검증
- `node --test` → 확장 있으면 193/193 통과
- `npx tsc --noEmit` → 무오류

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/22)
