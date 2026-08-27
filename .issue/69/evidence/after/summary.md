# after — namespace 격리 거짓 주장 제거 (수정 후)

동작·API 변경 없음. Python docstring·참조 문서만 정직화. TS/Rust 무변경.

## 검증
- py_compile: OK
- 실제 docstring/API 에서 'isolating graphs' 거짓 주장 0건 (reproduced-defects.md 의 2건은 교정 이력 설명 문맥)
- TS: 이미 정직 (index.ts:96-102, typescript-api.md:180-182) — 무변경
- Rust: namespace 개념 없음 — 무변경
