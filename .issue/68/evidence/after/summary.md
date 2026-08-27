# after — 자동 감지 주장 제거 (수정 후)

동작 변경 없음. 문서/주석만 진실에 맞춰 교정.

## 검증
- Python py_compile: OK (docstring 구문 정상)
- TS: 소스 무변경 — test/manager.test.ts:127 'query without a graphs list attaches nothing (no auto-detect)' 로 계약 이미 고정
- Rust cargo build --lib: (아래 결과 참조)

## 자동 감지 관련 주장이 남아있지 않은지 재확인
docs/src/reference/rust-api.md:236:fn query(&mut self, cypher: &str, graph_names: &[&str]) -> Result<CypherResult> // graph_names required; not auto-detected
docs/src/reference/python-api.md:20:| `extension_path` | str \| None | `None` | Path to the `.dylib`/`.so`/`.dll`; auto-detected if `None` |
docs/src/reference/python-api.md:37:| `extension_path` | str \| None | `None` | Path to extension; auto-detected if `None` |
docs/src/reference/python-api.md:54:| `entry_point` | str \| None | `None` | Extension entry point symbol; auto-detected if `None` |
docs/src/reference/python-api.md:196:| `extension_path` | str \| None | `None` | Path to extension; auto-detected if `None` |
docs/src/reference/python-api.md:544:| `extension_path` | str \| None | Path to extension; auto-detected if `None` |
docs/src/reference/python-api.md:556:| `query` | `manager.query(cypher: str, graphs: list[str] = None, params: dict = None) -> list` | Query across multiple graphs; name every graph to attach — omitting `graphs` (or `None`/empty) attaches nothing (no auto-detection) |
bindings/python/src/graphqlite/manager.py:42:            extension_path: Path to graphqlite extension (auto-detected if None)
bindings/python/src/graphqlite/manager.py:217:        There is no auto-detection: omitting ``graphs`` (or passing ``None`` or an
bindings/python/src/graphqlite/manager.py:227:                it (None/empty) attaches nothing — not auto-detected from the query
bindings/python/src/graphqlite/manager.py:404:        extension_path: Path to graphqlite extension (auto-detected if None)
bindings/rust/src/manager.rs:235:    /// There is no auto-detection: `graph_names` is required, and passing an
bindings/rust/src/manager.rs:242:    /// * `graph_names` - Graph names to attach (required; not auto-detected)
