## [I-03] npm 배포 파이프라인 — 구현 리포트

`.github/workflows/release.yml` 에 npm 배포 3잡(build-npm-packages → publish-npm-platforms → publish-npm-main)을 추가하고, 플랫폼 서브패키지 5개와 `.gitignore` 를 갖췄습니다. 플랫폼별 바이너리는 `optionalDependencies` 로 분리(esbuild 방식).

> 화면 없는 CI 인프라 원소라 증거는 명령 출력입니다.

### 수용 기준 대조

| 수용 기준 | 결과 |
| --- | --- |
| `build-wheels` 와 대칭인 **`build-npm-packages`**(`needs: build-and-test`) | ✅ 5 매트릭스, 아티팩트 다운로드→npm 패키지 조립 |
| **발행 순서 강제** (플랫폼 5 → 메인) | ✅ `publish-npm-platforms`(needs build-npm-packages) → `publish-npm-main`(needs publish-npm-platforms). needs 로 고정 |
| 릴리스 매트릭스가 이미 5조합 커버 → 매트릭스 확장 불필요 | ✅ build-and-test 의 아티팩트 5종을 그대로 소비(확장 없음) |
| `.gitignore` 에 `bindings/typescript/dist/`·`bindings/typescript/npm/*/graphqlite.*` | ✅ 바이너리·dist 무시, package.json 은 추적(check-ignore 확인) |
| `npm pack --dry-run` 으로 바이너리 포함 확인 | ✅ `@graphqlite/darwin-arm64` 타르볼에 `graphqlite.dylib` 포함(+CI 스텝이 `--json` 으로 강제 검증) |

### 동작 실증

```text
발행 순서(needs): build-npm-packages(needs build-and-test)
  → publish-npm-platforms(needs build-npm-packages, if tag)
    → publish-npm-main(needs publish-npm-platforms, if tag)

npm pack --dry-run (@graphqlite/darwin-arm64):
  graphqlite.dylib 634.2kB + package.json 434B, total 2 files, 압축 257kB   ← 바이너리 포함

5개 플랫폼 서브패키지 (os/cpu 불일치는 npm이 조용히 skip):
  @graphqlite/darwin-arm64  darwin/arm64  graphqlite.dylib
  @graphqlite/darwin-x64    darwin/x64    graphqlite.dylib
  @graphqlite/linux-x64     linux/x64     graphqlite.so
  @graphqlite/linux-arm64   linux/arm64   graphqlite.so
  @graphqlite/win32-x64     win32/x64     graphqlite.dll

.gitignore: bindings/typescript/dist/ , bindings/typescript/npm/*/graphqlite.* → 무시. package.json 추적.
```

### 아티팩트 → npm 키 매핑 (release.yml build-and-test 실측)
`graphqlite-linux-x86_64.so`→linux-x64, `-linux-aarch64.so`→linux-arm64, `-macos-arm64.dylib`→darwin-arm64, `-macos-x86_64.dylib`→darwin-x64, `-windows-x86_64.dll`→win32-x64. `@graphqlite/<키>@0.7.0` 는 #23 에서 메인 `optionalDependencies` 에 이미 존재하며 `platform.ts getPlatformKey` 와 일치.

### 한계 (정직하게)
실제 `npm publish` 는 태그(`v*`) push 시 GitHub Actions 가 `NPM_TOKEN` 시크릿으로 수행합니다. 로컬에선 (a) YAML 유효성·잡 needs 순서, (b) 5 서브 package.json JSON·os/cpu/files, (c) `npm pack --dry-run` 바이너리 포함, (d) `.gitignore` 반영까지 검증했고 **실제 발행은 하지 않았습니다**(파이프라인 정의).

### Before → After
- **Before** (`origin/main` `bf29e7f`): release.yml 에 npm 잡 부재, npm/*/package.json 부재.
- **After**: npm 배포 3잡 + 5 서브패키지 + .gitignore 편입.

### 변경 파일
- `.github/workflows/release.yml` — build-npm-packages·publish-npm-platforms·publish-npm-main 3잡
- `bindings/typescript/npm/{darwin-arm64,darwin-x64,linux-x64,linux-arm64,win32-x64}/package.json` (5 신규)
- `.gitignore` — dist/·npm/*/graphqlite.* 추가

### 증거 원본
- baseline: `.issue/26/evidence/before/state.txt`
- release 검증: `.issue/26/evidence/after/release-verify.txt`, `after/subpackages.txt`, `after/npm-pack.txt`, `after/gitignore.txt`
- 동작 실증: `.issue/26/evidence/after/behavior.txt`
