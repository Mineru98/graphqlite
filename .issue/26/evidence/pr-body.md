관련 이슈: [#26 [I-03] npm 배포 파이프라인](https://github.com/Mineru98/graphqlite/issues/26) (통합 테스트 뒤 close)

`.github/workflows/release.yml` 에 npm 배포 3잡을 추가하고 플랫폼 서브패키지 5개 + `.gitignore` 를 갖췄습니다. 플랫폼별 바이너리는 `optionalDependencies` 로 분리(esbuild 방식).

## 변경 내용
- `.github/workflows/release.yml` — `build-npm-packages`(needs build-and-test, 5 매트릭스) → `publish-npm-platforms`(needs build-npm-packages) → `publish-npm-main`(needs publish-npm-platforms)
- `bindings/typescript/npm/{darwin-arm64,darwin-x64,linux-x64,linux-arm64,win32-x64}/package.json` (5 신규, os/cpu/files)
- `.gitignore` — `bindings/typescript/dist/`·`bindings/typescript/npm/*/graphqlite.*`

## 수용 기준
- `build-wheels` 대칭 **`build-npm-packages`**(needs build-and-test)
- **발행 순서 강제**: 플랫폼 5 → 메인, `publish-npm-platforms` → `publish-npm-main` needs 고정
- 릴리스 매트릭스 5조합 이미 커버 → 매트릭스 확장 불필요
- `.gitignore` 에 dist/·npm/*/graphqlite.* 추가
- `npm pack --dry-run` 으로 바이너리 포함 확인(+CI 스텝이 `--json` 강제 검증)

## 검증
- YAML 유효, 잡 needs 순서(build-npm-packages→platforms→main) 확인
- `npm pack --dry-run`: `@graphqlite/darwin-arm64` 타르볼에 `graphqlite.dylib` 포함(634kB, 압축 257kB)
- 5 서브 package.json JSON·os/cpu/files 유효, `.gitignore` check-ignore 확인
- 실제 npm publish 는 태그 push 시 CI 수행(NPM_TOKEN) — 로컬 발행 안 함(정직하게 명시)

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/26)
