## #68 해결 — query graphs 자동 감지 거짓 주장 제거

**방향**: 자동 감지를 구현하지 않고, 문서/주석을 진실에 맞춰 교정 (A안). **동작 불변.**

### 문제

`GraphManager.query(graphs=None)`(또는 빈 배열)은 어떤 그래프도 ATTACH하지 않는데, Python docstring·Rust doc·참조 문서가 "자동 감지"를 주장하고 있었습니다. #32 재현 결함 추적 항목 5.

세 바인딩 중 **TypeScript는 이미 정직**하게(`manager.ts:173-175`, `typescript-api.md`) 문서화하고 있었고, `test/manager.test.ts:127`에 `query without a graphs list attaches nothing (no auto-detect)` 계약 테스트까지 있었습니다. 거짓 주장은 Python·Rust 쪽에만 남아 있었습니다.

### before → after

| 위치 | before | after |
| --- | --- | --- |
| `python/manager.py:222` | `graphs: ... (auto-detected from query if None)` | `graphs 생략(None/empty) 시 attach 없음 — not auto-detected` |
| `python/manager.py:215` | `Graphs are automatically attached...` | 명시적 attach + "There is no auto-detection" 문단 |
| `rust/manager.rs:233` | `Graphs are automatically attached...` | `graph_names` 필수 + "There is no auto-detection" |
| `python-api.md:556` | ``graphs=None` queries all` | 명시 필수, 생략 시 attach 없음 (no auto-detection) |
| `rust-api.md:236` | `graphs: Option<&[&str]>, params: ...` | `graph_names: &[&str]` (실제 signature, not auto-detected) |
| `reproduced-defects.md` 항목 5 | 미해결 | ~~취소선~~ + **문서 교정됨(#68)** |

### 변경 diff

```diff
--- a/bindings/python/src/graphqlite/manager.py
+++ b/bindings/python/src/graphqlite/manager.py
@@ query() docstring
-        Uses the FROM clause syntax to query across multiple graphs.
-        Graphs are automatically attached to the coordinator connection.
+        Uses the FROM clause syntax to query across multiple graphs. The named
+        graphs are attached to the coordinator connection before the query runs.
+
+        There is no auto-detection: omitting ``graphs`` (or passing ``None`` or an
+        empty list) attaches nothing, ...
@@ Args
-            graphs: List of graph names to attach (auto-detected from query if None)
+            graphs: Graph names to attach. Required to reach any graph; omitting
+                it (None/empty) attaches nothing — not auto-detected from the query
```

(전체 diff: `bindings/rust/src/manager.rs`, `docs/*` 포함 5 files, +22/-11)

### 검증

- **Python**: `py_compile` 통과 (docstring 구문 정상). *pytest 환경 미설치로 실행은 불가하나 코드 로직 무변경.*
- **Rust**: `cargo build --lib` 성공(exit 0) — doc comment 변경이 doctest를 깨지 않음.
- **TypeScript**: 소스 무변경. 자동 감지 부재 계약 테스트가 이미 존재(`manager.test.ts:127`).
- **잔여 거짓 주장 재검색**: `auto-detect`/`automatically attach`/`queries all` 중 "자동 감지 있음" 주장 **0건**. 남은 매치는 교정된 부정문 또는 무관한 `extension_path` 자동감지.

### 후속

parity allowlist(`bindings/typescript/test/parity/allowlist.json`)에는 이 항목이 없습니다 — 세 바인딩 공통 결함이라 Python↔TS divergence가 아니기 때문. 수정 불필요.
