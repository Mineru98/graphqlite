## #69 해결 — namespace dead parameter 격리 거짓 주장 제거

**방향**: 파라미터를 구현하지도 제거하지도 않고, Python docstring·참조 문서의 거짓 격리 주장만 제거 (C안). **동작·API 불변.**

### 문제

`namespace`는 생성 시 인스턴스에 저장되지만 어떤 쿼리에서도 쓰이지 않습니다(dead parameter). 그런데 Python docstring이 "Optional namespace for **isolating graphs**"라며 격리 기능을 주장하고 있었습니다. #32 재현 결함 추적 항목 6.

세 바인딩 현황:

| 바인딩 | namespace | 문서 정직성 |
| --- | --- | --- |
| TypeScript | 저장, 미사용 | **이미 정직** — "stored but never used ... dead parameter" (`index.ts:96-102`, `typescript-api.md:180-182`) |
| Python | 저장, 미사용 | **거짓** — "isolating graphs" |
| Rust | 개념 없음 | 해당 없음 |

### before → after

| 위치 | before | after |
| --- | --- | --- |
| `python/graph/__init__.py:76` (`Graph.__init__`) | `namespace: Optional namespace for isolating graphs` | `Stored on the instance but never used by any query (dead parameter...). Does not isolate graphs.` |
| `python/graph/__init__.py:213` (`graph()`) | 동일 | 동일 교정 |
| `python-api.md:195` | `Graph namespace identifier` | `Stored ... never used by any query (dead parameter; does not isolate graphs)` |
| `reproduced-defects.md` 항목 6 | 미해결 | ~~취소선~~ + **문서 교정됨(#69)** |

### 검증

- **Python**: `py_compile` 통과 (docstring 구문 정상). 코드 로직 무변경.
- **TypeScript**: 소스·문서 무변경 (이미 정직).
- **Rust**: namespace 개념 없음 — 무변경.
- **잔여 거짓 주장 재검색**: 실제 docstring/API에서 `isolating graphs` **0건**. (reproduced-defects.md의 2건은 교정 이력을 설명하는 문맥)

### 후속

이 항목은 세 바인딩 공통 결함이라 parity allowlist에 없습니다. 수정 불필요. namespace를 실제 격리 기능으로 만들거나 API에서 제거하는 것은 파괴적/기능 추가라 이번 범위 밖으로 두었습니다(이슈에서 C안 선택).
