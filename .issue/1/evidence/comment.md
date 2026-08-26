## [F-01] TypeScript 패키지 스캐폴딩 — 작업 리포트

`bindings/{python,rust}` 와 형제 위치에 `bindings/typescript` 패키지 골격을 만들었습니다. UI가 없는 스캐폴딩 작업이라 증거는 스크린샷 대신 **명령 출력**으로 남깁니다.

### 생성 파일
```
bindings/typescript/
├── package.json          # name graphqlite, version 0.7.0, type module,
│                         #   engines.node >=22.5.0, optionalDependencies 5개, node:test 러너
├── tsconfig.json         # NodeNext ESM, strict, noEmit
├── .eslintrc             # 최소 TS 린트 설정
├── package-lock.json     # npm ci 재현성 확보 (커밋됨)
├── src/index.ts          # 빈 export 자리표시자
└── test/smoke.test.ts    # node:test + node:assert 스모크 테스트
```

### Before (변경 전)
```
$ ls bindings/
python  rust
$ ls bindings/typescript
ls: bindings/typescript: No such file or directory
```

### After (수용 기준 검증)
환경: Node v24.13.0 / npm 11.6.2

```
$ npm ci
added 3 packages, and audited 4 packages in 496ms
found 0 vulnerabilities
# CI_EXIT=0

$ npx tsc --noEmit
# TSC_EXIT=0  (에러 0건)

$ npm test          # node --test
✔ scaffolding is in place (0.265ms)
✔ index module has no runtime exports yet (0.542ms)
ℹ tests 2   ℹ pass 2   ℹ fail 0
```

### 수용 기준 체크
- [x] `npm ci && npx tsc --noEmit && npm test` 로컬 통과
- [x] `bindings/python`, `bindings/rust` 와 형제 위치에 생성
- [x] `engines.node` 잠정 `>=22.5.0` (실제 하한은 #25 CI 에서 확정)

### 설계 정합
- 반환 포맷 정규화(`result.ts`)·에러 계층(`errors.ts`)·경로 해석(`platform.ts`)은 이 이슈가 차단하는 후속 원소(#2~#6)의 몫이라 골격만 둡니다. 설계 문서 §11 Phase 1 범위와 일치합니다.
- optionalDependencies(`@graphqlite/*@0.7.0`)는 아직 레지스트리에 없지만 optional 특성상 `npm ci`가 조용히 건너뛰어 설치가 깨지지 않음을 실측했습니다.

### 참고
- 브랜치: `feat/1-issue-1`
- 커밋: `55d4cff`
