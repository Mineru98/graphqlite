## [I-02] CI ts-check 잡 — 구현 리포트

`.github/workflows/ci.yml` 의 `python-check` 직후에 `ts-check` 잡(9 스텝)을 추가하고, 6개 `needs:` 배열에 편입해 TS 실패가 후속 잡을 실제로 막게 했습니다. Node 하한도 확정했습니다.

> 화면 없는 CI 인프라 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| **`needs:` 배열 6곳에 `ts-check` 추가** | ✅ full-build-unix·full-rust-tests·full-python-tests-linux·full-python-tests-macos·full-windows-tests·performance-tests **전부** ts-check 포함(YAML 파싱으로 검증) |
| **Node 버전 하한 실측 확정** | ✅ `engines.node` `>=22.5.0`(F-01 잠정) → **`>=24.0.0`**. **CI 실측으로 확정**(아래) |

### ts-check 잡 (python-check 직후, 9 스텝)
```text
checkout@v4 → setup-node@v4(node 22) → apt(bison flex libsqlite3-dev)
→ make extension → mkdir+cp build/graphqlite.so → npm ci → npx tsc --noEmit → npx eslint . → npm test
```

### 로컬 실증 (CI가 GitHub에서 돌릴 명령을 동일하게 실행)
```text
npm ci            OK (lockfile 동기화)
npx tsc --noEmit  무오류
npx eslint .      통과 (No issues)
npm test          200/200
YAML 파싱         잡 13개, ts-check 9스텝, needs 6곳 전부 ts-check 포함
```

### Node 하한 결정 근거 — CI 실측으로 확정
처음엔 문서 기반으로 `>=22.13.0`(node:sqlite `loadExtension`/`allowExtension` 의 22.x LTS 백포트)을 잠정 설정하고 ts-check CI 를 **node 22** 로 돌렸습니다. **그 CI 잡이 실패**했습니다:
```text
ts-check › npm test → SyntaxError: Unexpected identifier 'g'   (exit 1)
```
테스트가 쓰는 **`using g = graph(...)`(명시적 자원 관리)** 구문은 **Node 24 부터 무플래그 지원**됩니다. node 22 는 이를 파싱하지 못합니다(앞 스텝 make extension·npm ci·tsc·eslint 는 전부 통과). 즉 **CI 가 "Node 하한 실측"을 실제로 수행**해, 하한이 22.13.0 이 아니라 **Node 24** 임을 증명했습니다.
→ `engines.node` **`>=24.0.0`**, CI `node-version: '24'`. (개발 검증도 v24.13.0.)
바인딩은 `[Symbol.dispose]` 로 `using g = graph()` 를 문서화된 사용법으로 제공하므로, 그 사용법이 동작하는 Node 24 가 정직한 하한입니다.

### eslint 도입 (step 8 `npx eslint .` 가 실제 통과하도록)
step 8 은 동작하는 eslint 설정을 전제합니다. 리포지토리에 eslint 설정·devDep 이 없어, 최소 구성을 추가했습니다:
- `eslint.config.js` (flat, typescript-eslint recommended, `dist`/`node_modules`/`npm` 무시)
- `package.json` devDeps `eslint ^9`·`typescript-eslint ^8` + `lint` 스크립트, `package-lock.json` 갱신(`npm ci` 동작)
- `src/manager.ts`: 빈 인터페이스 `GraphManagerOptions extends ConnectionOptions {}` → `type GraphManagerOptions = ConnectionOptions` (typescript-eslint `no-empty-object-type` 1건 해소, 의미 동일)

이슈 범위(`ci.yml`)를 넘어서지만, `npx eslint .` 스텝이 **레드로 항상 실패하는 죽은 스텝**이 되지 않게 하려는 최소 확장입니다.

### 한계 (정직하게)
GitHub Actions 실제 실행은 push 후 CI 가 수행하며 로컬에서 재현 불가합니다. 여기선 (a) YAML 유효성·구조·needs 편입을 파싱으로, (b) ts-check 의 각 명령(npm ci/tsc/eslint/test)을 로컬에서 동일하게 실행해 검증했습니다. Node 22 실측은 CI 잡이 담당합니다.

### Before → After
- **Before** (`origin/main` `a49bde6`): ci.yml 에 ts-check 부재, needs 배열 6곳 4개-체크, engines `>=22.5.0`, eslint 설정 전무.
- **After**: ts-check 잡(node 24) + needs 6곳 편입, engines `>=24.0.0`(CI 실측), eslint 설정·통과.

### 변경 파일
- `.github/workflows/ci.yml` — ts-check 잡(9스텝) + needs 6곳
- `bindings/typescript/package.json` — engines `>=22.13.0`, eslint devDeps, lint 스크립트
- `bindings/typescript/package-lock.json` — eslint 의존 반영(npm ci)
- `bindings/typescript/eslint.config.js` (신규)
- `bindings/typescript/src/manager.ts` — 빈 인터페이스 → type alias (lint)

### 증거 원본
- baseline: `.issue/25/evidence/before/state.txt`
- ci 검증: `.issue/25/evidence/after/ci-verify.txt`, `after/checks.txt`
- 동작 실증: `.issue/25/evidence/after/behavior.txt`
