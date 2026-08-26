## [F-02] 확장 경로 해석 (platform.ts) — 작업 리포트

Python `_platform.py` 와 같은 우선순위로 확장 바이너리 경로를 해석하는 `platform.ts` 를 구현했습니다. UI 가 없는 로직 작업이라 증거는 스크린샷 대신 **테스트·타입 검사 출력**으로 남깁니다.

### 생성 파일
```
bindings/typescript/src/platform.ts         # 경로 해석 로직 + ExtensionLoadError
bindings/typescript/test/platform.test.ts   # node:test 9개 케이스
```

### 구현 요약
- `getExtensionName`: darwin→`.dylib`, linux→`.so`, win32→`.dll`, 그 외 throw
- `getExtensionSearchPaths`: `env(GRAPHQLITE_EXTENSION_PATH)` → 내장 `@graphqlite/<platform>/graphqlite.<ext>` → 개발 빌드 `<repo>/build/…` → `/usr/local/lib` → `/usr/lib`
- `findExtension`: **`fs.existsSync` 로 먼저 존재 확인** 후 반환, 전부 실패하면 탐색 경로 목록을 담은 `ExtensionLoadError` — dlopen 중복 확장자(`/x.dylib.dylib`) 원문이 새어나가지 않음
- Windows `.dll` 포함 (Python 테스트 헬퍼의 `.dll` 누락 결함은 따라가지 않음)

### 검증 (Node v24.13.0 / npm 11.6.2)
```
$ npx tsc --noEmit
# TSC_EXIT=0 (에러 0)

$ npm test          # node --test
✔ getExtensionName maps each platform to its filename
✔ getExtensionName throws on an unsupported platform
✔ win32 search paths use .dll (Python helper omission is not followed)
✔ getPlatformKey combines platform and arch
✔ GRAPHQLITE_EXTENSION_PATH takes highest priority
✔ system paths come last, in /usr/local/lib then /usr/lib order
✔ findExtension short-circuits on an existing explicit path
✔ findExtension throws ExtensionLoadError listing searched paths
✔ findExtension with a missing explicit path throws with that path
ℹ tests 11 (platform 9 + 기존 smoke 2)   ℹ pass 11   ℹ fail 0
```

### 수용 기준 체크
- [x] `fs.existsSync` 로 먼저 존재 확인 후 반환
- [x] 전부 실패 시 탐색 경로 목록을 담은 `ExtensionLoadError` throw
- [x] Windows `.dll` 경로 포함 (Python 헬퍼 결함 미추종)
- [x] 플랫폼 매핑 darwin→`.dylib`, linux→`.so`, win32→`.dll`

### 스코프 메모
- `ExtensionLoadError` 는 본래 `errors.ts`(#3)의 몫이라, 크로스 의존을 피해 `platform.ts` 에 최소 정의했습니다. #3/#7 통합 시 `GraphQLiteError` 계층으로 재조정 예정입니다.
- 선수 조건 #1(스캐폴딩)은 이 작업 전에 main 에 병합됐고, 그 위에서 구현·검증했습니다.

### 참고
- 브랜치: `feat/2-issue-2`
- 커밋: `e69c2e7`
