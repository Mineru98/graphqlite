## [F-05] 이스케이프·식별자 검증 (utils.ts) — 작업 리포트

Cypher 조립용 이스케이프·직렬화 헬퍼를 Python 과 바이트 단위 동일하게 이식하고, **식별자 검증(`assertIdentifier`)을 신규 추가**했습니다. UI 없는 로직 작업이라 증거는 테스트·타입 검사 출력으로 남깁니다.

### 생성 파일
```
bindings/typescript/src/utils.ts         # CYPHER_RESERVED, escapeString, sanitizeRelType, formatProps, assertIdentifier
bindings/typescript/test/utils.test.ts   # node:test 18개 (Python 이식 9 + AC 특화 9)
```

### Python 대조 (`bindings/python/src/graphqlite/utils.py`)
- `CYPHER_RESERVED`: **실제 63개**를 그대로 복사. (이슈 본문의 "72"는 부정확 — 호환성 원칙상 Python 실제 세트를 따름)
- `escapeString`: 순차 치환 `\`→`\\`, `'`→`\'`, `"`→`\"`, `\n`/`\r`/`\t`→공백. Python 과 바이트 동일.
- `sanitizeRelType`: **`/[\p{L}\p{N}_]/u`(유니코드)** 사용 — Python `isalnum()` 이 유니코드 인식이라 ASCII 정규식으로 옮기면 CJK 가 깨짐. 실측 일치: `관계`→`관계`, `123abc`→`REL_123abc`, `match`→`REL_match`, `CREATE`→`REL_CREATE`.
- `formatProps`: str→이스케이프, bool→`true`/`false`, null→`null`, **그 외 raw 보간(이스케이프 없음)**. 분기 순서 보존.
- **신규** `assertIdentifier(value, kind)`: `/^[\p{L}_][\p{L}\p{N}_]*$/u` 아니면 `ValidationError`(errors.ts) — 주입 방어. 유효 식별자(라틴/CJK/underscore)는 하나도 거부 안 함.

### 검증 (Node v24.13.0 / npm 11.6.2)
```
$ npx tsc --noEmit
TypeScript: No errors found   # exit 0

$ npm test          # node --test
ℹ tests 50 (utils 18 + result 11 + errors 10 + platform 9 + smoke 2)
ℹ pass 50   ℹ fail 0
```

### 수용 기준 체크
- [x] Python `test_graph.py` 유틸 테스트 9종 이식·통과
- [x] `sanitizeRelType` 이 `/[\p{L}\p{N}_]/u` 사용 — `sanitizeRelType('관계')==='관계'` Python 일치
- [x] `formatProps` 가 문자열·불리언·null 외 값을 이스케이프 없이 raw 보간
- [x] `assertIdentifier` 가 유효 식별자를 하나도 거부 안 함 (라틴/CJK/underscore 통과, 주입형만 거부)

### 스코프 메모
- `assertIdentifier` 는 `errors.ts`(#3, main 병합됨)의 `ValidationError` 를 import 합니다 — 첫 정상 크로스모듈 참조. 이 원소가 차단하던 #9·#11·#13·#22 의 선수 조건이 풀립니다.

### 참고
- 브랜치: `feat/5-issue-5`
- 커밋: `86a3cac`
