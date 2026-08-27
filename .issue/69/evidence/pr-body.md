관련 이슈: [#69 namespace 파라미터가 저장만 되고 어디서도 쓰이지 않는다 (dead parameter)](https://github.com/Mineru98/graphqlite/issues/69) (통합 테스트 뒤 close)

## 배경

`namespace`는 생성 시 인스턴스에 저장되지만 어떤 쿼리에서도 쓰이지 않습니다(dead parameter). 그런데 Python docstring이 "Optional namespace for **isolating graphs**"라며 격리 기능을 주장하고 있었습니다. #32 재현 결함 추적 항목 6.

- TypeScript: 이미 정직하게 문서화("stored but never used ... dead parameter", `index.ts:96-102`, `typescript-api.md:180-182`)
- Rust: `namespace` 개념 자체가 없음
- Python: 거짓 격리 주장 잔존

## 방향

파라미터를 **구현하지도 제거하지도 않고**, Python docstring·참조 문서의 거짓 격리 주장만 "stored, unused (dead parameter)"로 정정합니다. **동작·API 불변.** (#68에서 고른 것과 같은 문서 정직화 방향)

## 변경 내용

- `bindings/python/src/graphqlite/graph/__init__.py` — `Graph.__init__` / `graph()` factory docstring 교정
- `docs/src/reference/python-api.md` — `namespace` 표 설명 교정
- `docs/internal/reproduced-defects.md` — 항목 6을 "문서 교정됨(#69)"으로 갱신
- TypeScript / Rust: 변경 없음

## 검증

- Python: `py_compile` 통과 (docstring 구문 정상). 코드 로직 무변경.
- 실제 docstring/API에서 `isolating graphs` 거짓 주장 재검색 결과 **0건**.
- TS/Rust 무변경.

## 증거

[전후 리포트 보기](https://github.com/Mineru98/graphqlite/issues/69#issuecomment-5440705172)
