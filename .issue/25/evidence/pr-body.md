관련 이슈: [#25 [I-02] CI ts-check 잡](https://github.com/Mineru98/graphqlite/issues/25) (통합 테스트 뒤 close)

`.github/workflows/ci.yml` 의 `python-check` 직후에 `ts-check` 잡(9 스텝)을 추가하고 6개 `needs:` 배열에 편입, Node 하한을 확정했습니다.

## 변경 내용
- `.github/workflows/ci.yml` — `ts-check` 잡(checkout→setup-node 22→apt→make extension→stage .so→npm ci→tsc→eslint→npm test) + `needs:` 6곳에 `ts-check`
- `bindings/typescript/package.json` — `engines.node` `>=22.13.0`, eslint devDeps, `lint` 스크립트
- `bindings/typescript/package-lock.json` — eslint 의존 반영(`npm ci`)
- `bindings/typescript/eslint.config.js` (신규) — typescript-eslint recommended
- `bindings/typescript/src/manager.ts` — 빈 인터페이스 → type alias (lint 1건 해소)

## 수용 기준
- **`needs:` 배열 6곳에 `ts-check` 추가**(full-build-unix·full-rust-tests·full-python-tests-linux·full-python-tests-macos·full-windows-tests·performance-tests) — TS 실패가 후속 잡을 막음
- **Node 하한 확정**: **`>=24.0.0`** — ts-check CI 를 node 22 로 돌리자 `npm test` 가 테스트의 `using g = graph()`(명시적 자원 관리, Node 24+) 구문을 파싱 못 해 실패. **CI 실측으로 하한이 Node 24 임을 확정**(CI `node-version: '24'`, 개발 검증 v24.13.0)

## 검증
- YAML 파싱 유효, ts-check 9스텝, needs 6곳 전부 ts-check 포함
- ts-check 명령 로컬 실증: `npm ci` OK / `npx tsc --noEmit` 무오류 / `npx eslint .` 통과 / `npm test` 200/200
- GitHub Actions 실제 실행은 push 후 CI 수행(로컬 불가)

## 증거
[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/25)
