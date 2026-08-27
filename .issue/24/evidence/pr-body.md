관련 이슈: [#24 [I-01] Makefile · angreal 통합](https://github.com/Mineru98/graphqlite/issues/24) (통합 테스트 뒤 close)

TS 바인딩을 기존 빌드·테스트 파이프라인에 편입했습니다. `Makefile` 7개 삽입 지점 + `.angreal/task_test.py` 의 `ts` 커맨드.

## 변경 내용
- `Makefile` — `TS_BINDINGS_DIR`, `install-bundled-ts`(npm/<plat>/ 복사), `test-ts`(extension·install-bundled-ts 의존), `test-bindings` 에 test-ts, MAKECMDGOALS 필터·더미타깃 `ts`, `.PHONY`, `help`
- `.angreal/task_test.py` — `name="ts"` 커맨드 + `test_ts()`(test_python 스타일 subprocess), `test_bindings` 본문에 `test_ts` 호출

## 수용 기준
- **`test-ts` 는 `install-bundled-ts` 에 의존**(Rust 처럼 바이너리 복사, Python 은 `extension` 만 — 비대칭 재현)
- `make test ts`(node --test 200/200), `make test bindings`(체인에 test-ts 포함) 동작
- 확장 미빌드 시 자동 빌드(Makefile `extension` 의존 / angreal `ensure_extension_built`)

## 검증
- `make -n test ts` / `make -n test bindings` → 레시피·체인 확인
- `node --test`(test-ts 최종 레시피) → 200/200
- `install-bundled-ts` → `bindings/typescript/npm/darwin-arm64/graphqlite.dylib`
- `angreal test ts`: angreal **미설치 환경**이라 직접 실행 불가 → ast 문법·구조 검증(정직하게 명시). C 확장 처음부터 재빌드는 환경 bison(`%code` 미지원) 제약으로 프리빌트 dylib 사용.

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/24)
