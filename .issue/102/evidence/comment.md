## Summary

The TypeScript bulk insert path now prepares each static SQL statement once per bulk call instead of once per row or property. Prepared-statement execution was extracted into `bulk-sql.ts`, and repeated relationship-type sanitization is cached for the duration of each call. Public package exports, transaction and rollback semantics, property-type routing, endpoint lookup behavior, and the C core remain unchanged.

Implementation commit: `7ecda7ae198a665308f6d8970c7b1e35bd40cc1e`; validation-gate cleanup commit: `c5a56155`

## Performance comparison

| Dataset / metric | Before (ms) | After (ms) | Change |
| --- | ---: | ---: | ---: |
| 5K/10K TypeScript build | 124.161 | 47.127 | **-62.0%** |
| 5K/10K TypeScript / fastest peer | 3.264x | 1.223x | **Within the 1.25x target** |
| 5K/10K scan | 8.165 | 7.750 | **-5.1%** |
| 5K/10K PageRank | 8.616 | 7.525 | **-12.7%** |
| 5K/10K BFS | 7.337 | 5.387 | **-26.6%** |
| 20K/40K TypeScript build | 518.563 | 194.956 | **-62.4%** |
| 20K/40K TypeScript / fastest peer | 3.337x | 1.240x | **Within the 1.25x target** |
| 20K/40K scan | 31.150 | 29.667 | **-4.8%** |
| 20K/40K PageRank | 31.990 | 28.268 | **-11.6%** |
| 20K/40K BFS | 27.512 | 20.577 | **-25.2%** |

Measurement conditions: macOS arm64, Node v25.9.0, Python 3.14.4, Rust 1.95.0, one warm-up followed by the median of five measured runs. Both before and after runs used the same `graphqlite.dylib` with SHA-256 `231b2477efb6d498920389013566c6d5aefb2e3643e6845d7b53834bddeaed8b`. Result counts matched across all three bindings for every operation. Raw outputs are stored under `.issue/102/evidence/before/` and `.issue/102/evidence/after/`.

## Changed files

- `bindings/typescript/src/graph/bulk-sql.ts` — adds prepared-statement bundles and execution helpers for nodes, edges, and properties
- `bindings/typescript/src/graph/bulk.ts` — reuses statements and sanitized relationship types within each bulk call
- `bindings/typescript/test/bulk.test.ts` — adds regression coverage proving static SQL preparation does not scale with input size
- `bindings/typescript/test/paths.test.ts` — aligns the stale integration expectation with the real A* path returned since #64
- `bindings/typescript/src/graph/nodes.ts` — removes an unused destructuring binding while still excluding `nodeData.id`

## Verification

- `test/bulk.test.ts`: 16/16 passed
- Full `npm test`: 225 tests, 218 passed, 7 skipped, 0 failed
- `npm run typecheck`: passed
- Full `npm run lint`: passed
- `npm run build`: passed
- Results and Cypher parity: 0 mismatches for Python↔TypeScript and Rust↔TypeScript
- Pure LOC for changed TypeScript files: 212 / 154 / 216, all below 250
- `src/index.ts` hash matches `origin/main`, confirming no public package export changes
- No C, Python, or Rust source files changed

## Remaining issues

- No unresolved items remain within the scope of #102.
