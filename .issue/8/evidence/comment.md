## [G-01] Graph 파사드 골격 — 구현 리포트

`Connection`(#7)을 감싸는 얇은 `Graph` 파사드의 **골격만** 만들었습니다. Python 은 12개 믹스인 다중상속이지만, TS 는 각 기능 모듈이 `Connection` 을 첫 인자로 받는 순수 함수를 export 하고 `Graph` 가 3줄로 위임하는 구조입니다. 위임 메서드 본체와 캐시 4종(#14)은 이후 원소가 채웁니다.

> 화면 없는 라이브러리 원소라 증거는 스크린샷이 아니라 **명령 출력**입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| `namespace` 는 저장만 하고 쿼리에 쓰지 않음 (Python dead param) | ✅ `readonly namespace` 로 저장, Cypher 에 전혀 전달 안 함 |
| `using g = graph(':memory:')` 자동 해제 | ✅ `[Symbol.dispose]()` → `close()`, tsconfig `lib` 에 `ESNext.Disposable` 추가로 타입체크 통과 |
| 위임 메서드 자리를 Python `Graph` MRO 순서 주석으로 고정 | ✅ nodes→edges→queries→batch→centrality→community→components→paths→traversal→similarity 삽입 지점 주석(각 원소 이슈 번호 표기) |

### 공개 표면
- 생성자 `(dbPath = ':memory:', { namespace = 'default', extensionPath })` — Python 위치 인자 대신 **옵션 객체**
- `connection` getter, `close()`, `[Symbol.dispose]`
- 팩토리 `graph(dbPath, options)`
- 확장 해석은 `connect()`(#7)가 내부에서 `findExtension` 하므로 파사드는 위임만

### 동작 실증 (실제 확장 `build/graphqlite.dylib`, Node v24.13.0)

```text
graph() 반환         : Graph 인스턴스
namespace 저장       : "tenant-a"
connection getter    : Connection
namespace 무시 쿼리  : [{"n.name":"Alice"}] (namespace 는 SQL 에 안 쓰임)
close() 동작         : 이후 execute 차단됨 (닫힘 확인)
using 자동 해제      : 블록 종료 후 connection 닫힘 (Symbol.dispose 동작)
```

### Before → After
- **Before** (`origin/main`): `src/graph/` 부재, index 는 connection 표면만, 73 테스트 통과.
- **After**: `graph`/`Graph` 공개 표면 추가, **81 테스트** — 확장 있으면 81/81 통과, 없으면 73 통과 + 8 게이트 skip(빌드 없어도 통과), `tsc --noEmit` 무오류(`using`/`Symbol.dispose` 포함).

### 변경 파일
- `src/graph/index.ts` (신규) — `Graph` 파사드 + `graph()` 팩토리 + MRO 삽입 지점 주석
- `src/index.ts` — `graph`/`Graph`/`GraphOptions` re-export
- `test/graph-init.test.ts` (신규) — 구조 + 게이트된 실제 확장 동작 테스트(namespace/using/close)
- `test/smoke.test.ts` — 공개 표면 단언에 `Graph`/`graph` 반영
- `tsconfig.json` — `lib` 에 `ESNext.Disposable` 추가(`using`/`Symbol.dispose` 타입체크, 추가만)

### 증거 원본
- 상태 baseline: `.issue/8/evidence/before/state.txt`
- 테스트/타입체크: `.issue/8/evidence/after/tests.txt`, `after/typecheck.txt`
- 동작 실증: `.issue/8/evidence/after/behavior.txt`
