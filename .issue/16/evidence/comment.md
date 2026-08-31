## Implementation report: structured diagnostics and non-executing validation

Issue #16 is implemented in commit `2627ef3bdec50ccac36c7819a25687b248a4a954`.

### Result

| Acceptance requirement | Evidence |
| --- | --- |
| Parse errors show line/column and a clear reason | A multiline parse failure returns `PARSE_ERROR`, line 2, column 7, and `unexpected end of file`. A scanner failure now reports column 9 instead of 0. |
| `validate()` returns errors without executing | `RETURN NOT 1` returns a structured `VALIDATION_ERROR`; validating `CREATE (:Issue16Probe)` leaves the node count at 0. |
| Rust exposes parser errors as a structured type | Added public `ValidationResult` and `ValidationDiagnostic`, plus `Connection::validate()` and `Graph::validate()`. |
| Invalid-syntax tests | Added parser-location, functional SQL, and Rust end-to-end regression coverage. |

### What changed

- Preserved scanner error columns across the parser bridge.
- Upgraded SQL `cypher_validate(query)` from parse-only checking to parse plus static semantic validation.
- Added stable `PARSE_ERROR` / `VALIDATION_ERROR` codes and safe JSON escaping.
- Added typed, additive Rust validation APIs that return invalid queries as data rather than executing them.
- Documented the SQL and Rust surfaces and removed `GQLITE-T-0192` from the known-gap list.

Capability metadata is intentionally not duplicated in this change. The repository tracks dialect version and supported-feature metadata separately as issue #17 / `GQLITE-T-0100`.

### Verification

- Native extension build: pass.
- CUnit: 948/948 tests and 5,627/5,627 assertions passed.
- Issue regression SQL: 24/24 hard assertions passed.
- Rust bundled-extension suite: 14 unit + 248 integration + 26 documentation tests passed; 10 existing tests were intentionally ignored.
- Rust non-bundled suite against the new extension: pass with the same unit/integration result.
- Clippy with warnings denied, changed-file formatting, and whitespace checks: pass.

### Evidence files

- Before behavior: `.issue/16/evidence/before/validation.txt`
- After behavior: `.issue/16/evidence/after/validation.txt`
- Verification summary: `.issue/16/evidence/after/tests.txt`
