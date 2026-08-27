## [M-01] GraphManager — 구현 리포트

여러 그래프를 관리하는 `GraphManager`(9 메서드) + 팩토리 `graphs(basePath)` 를 `src/manager.ts` 에 구현했습니다. 디렉터리 + 그래프당 `.db` 파일 + 크로스 그래프 질의는 in-memory 코디네이터(`connect(':memory:')`)에 `ATTACH DATABASE` 하는 구조입니다. 참조는 `bindings/python/src/graphqlite/manager.py`.

> 화면 없는 라이브러리 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| 생성자가 `basePath` 를 `mkdirSync(recursive)` 생성 | ✅ 중첩 경로도 생성 |
| **`query()` 는 ATTACH 전 열린 모든 그래프 `commit()`** | ✅ 커밋 후 ATTACH → 코디네이터가 최신 데이터 확인 |
| `ATTACH ... AS {name}` 보간 → 이름 `assertIdentifier('graph')` + **경로 디렉터리 이탈 검사** | ✅ `../escape`·`bad/name` → `ValidationError`(Python은 `../x` 허용, TS는 차단) |
| ATTACH `"already in use"` 무시, 나머지 전파 | ✅ 정규식 매칭 후 무시/rethrow |
| **`query(graphs)` 생략 시 아무것도 ATTACH 안 함** | ✅ auto-detect 미구현(Python docstring 과 달리 코드 없음) 그대로 재현 |
| `create` 중복 / `open`·`drop`·`query` 부재 에러, `open` 실패에 `"Available:"` + 목록 | ✅ `GRAPH_EXISTS` / `GRAPH_NOT_FOUND` + `Available: ['products', 'social']` |
| `open` 캐시 재사용 | ✅ 동일 인스턴스 반환 |
| `drop` = close → DETACH(무시) → 파일 삭제 | ✅ 순서 유지 |
| `close()` = 모든 그래프 + 코디네이터 닫기 | ✅ |

### 이식 시 유의 — double-close 관대화
Python `sqlite3.close()` 는 두 번 호출해도 무해하지만 `node:sqlite` 는 "database is not open" 을 던집니다. 사용자가 넘겨받은 그래프를 닫은 뒤 `gm.close()`/`query()`(커밋 루프)를 호출하면 이미 닫힌 커넥션을 건드립니다. Python 의 관대한 동작을 재현하려고 close 와 커밋 루프에서 "not open" 오류를 삼킵니다(그 외 오류는 전파). 회귀 테스트 포함.

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0, 임시 디렉터리)

```text
basePath 재귀 생성         true
list() 정렬               ["products","social"]
open 캐시 재사용          true
query(commit→attach→run)  [{"one":1}]        (열린 social 커밋 후 ATTACH → 코디네이터에서 실행)
query(graphs 생략)        [{"answer":42}]    (attach 안 함 — auto-detect 미구현 재현)
open 부재 에러            GRAPH_NOT_FOUND / Available: ['products', 'social']
create 중복 에러          GRAPH_EXISTS
이름 검증(../escape)       ValidationError    (디렉터리 이탈 거부 — Python은 ../x 허용)
이름 검증(bad/name)        ValidationError    (assertIdentifier)
drop 후 목록              ["social"]         (close→DETACH 무시→파일 삭제)
```

### Before → After
- **Before** (`origin/main` `09a71e9`): manager.ts 부재, 183 테스트 통과.
- **After**: `GraphManager` + `graphs` 공개, **193 테스트** — 확장 有 193/193, `tsc --noEmit` 무오류.

### 변경 파일
- `src/manager.ts` (신규) — GraphManager 9 메서드 + 팩토리(이름 검증·이탈 검사·commit-before-ATTACH·already-in-use 무시·double-close 관대화)
- `src/index.ts` — `GraphManager`·`graphs`·타입 re-export
- `test/manager.test.ts` (신규) — pure 이름 검증 + 게이트된 실제 확장 10종
- `test/smoke.test.ts` — 공개 표면 단언에 반영

### 증거 원본
- baseline: `.issue/22/evidence/before/state.txt`
- 테스트/타입체크: `.issue/22/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/22/evidence/after/behavior.txt`
