관련 이슈: [#23 [G-02] 공개 API 표면 확정](https://github.com/Mineru98/graphqlite/issues/23) (통합 테스트 뒤 close)

모든 기능 원소(#13~#22)가 끝난 뒤 공개 API 표면을 확정했습니다. 팩토리·타입·에러 클래스·버전 상수를 export 하고, `graphqlite/async` 서브패스와 `.d.ts` 빌드를 정의했습니다. 참조는 `bindings/python/src/graphqlite/__init__.py`, `tests/test_connection.py`.

## 변경 내용
- `src/version.ts` (신규) — `VERSION`
- `src/async.ts` (신규) — `graphqlite/async` 진입점(동기 표면 re-export, worker_threads 오프로딩은 #29 예고)
- `src/index.ts` — 에러 계층 6종 + `VERSION` re-export
- `package.json` — `exports` 에 `./async`·`./package.json`, `build` 스크립트
- `tsconfig.build.json` (신규) — `emitDeclarationOnly` .d.ts 빌드
- `test/exports.test.ts` (신규) — 표면 검증 7종
- `test/smoke.test.ts` — 에러 계층·VERSION 반영

## 수용 기준
- Python `test_exports`/`test_version_exists` 대응 표면 검증 테스트
- **버전 상수 export**(`VERSION`, package.json 과 일치 강제)
- **`graphqlite/async` 서브패스를 package.json `exports` 에 정의**(실존 모듈)
- `tsc --noEmit` 통과 + **`.d.ts` 생성**(`tsconfig.build.json`, 22개)

## 검증
- `node --test` → 확장 있으면 200/200 통과
- `npx tsc --noEmit` → 무오류
- `npx tsc -p tsconfig.build.json` → `.d.ts` 22개 생성

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/23)
