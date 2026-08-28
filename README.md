
# GraphQLite

<p align="center">
    <img src="docs/assets/logo.png" alt="GraphQLite" width="256">
</p>

An SQLite extension that adds graph database capabilities using the Cypher query language.

Store and query graph data directly in SQLite—combining the simplicity of a single-file, zero-config embedded database with Cypher's expressive power for modeling relationships.

## Installation

```bash
brew install graphqlite       # macOS/Linux (Homebrew)
pip install graphqlite        # Python
cargo add graphqlite          # Rust
npm install graphqlite        # TypeScript / Node.js
```

## Quick Start

```python
from graphqlite import Graph

g = Graph(":memory:")
g.upsert_node("alice", {"name": "Alice", "age": 30}, label="Person")
g.upsert_node("bob", {"name": "Bob", "age": 25}, label="Person")
g.upsert_edge("alice", "bob", {"since": 2020}, rel_type="KNOWS")

# Query with Cypher
results = g.query("MATCH (a:Person)-[:KNOWS]->(b) RETURN a.name, b.name")

# Built-in graph algorithms
g.pagerank()
g.louvain()
g.dijkstra("alice", "bob")
```

The same API is available in **TypeScript / Node.js** (requires Node.js 24+):

```typescript
import { graph } from "graphqlite";

const g = graph(":memory:");
g.upsertNode("alice", { name: "Alice", age: 30 }, "Person");
g.upsertNode("bob", { name: "Bob", age: 25 }, "Person");
g.upsertEdge("alice", "bob", { since: 2020 }, "KNOWS");

// Query with Cypher
const results = g.query("MATCH (a:Person)-[:KNOWS]->(b) RETURN a.name, b.name");

// Built-in graph algorithms
g.pagerank();
g.louvain();
g.dijkstra("alice", "bob");

g.close();
```

### TypeScript / Node.js Binding

The TypeScript binding targets Node.js 24+ and exposes the graph API with
camelCase method names and option objects. It uses the same compiled C core as
the Python and Rust bindings.

The cross-binding parity check exercises the TypeScript, Python, and Rust
implementations against the same scenarios and shared extension. Run both
checks with:

```bash
bash scripts/parity-check.sh --mode results
bash scripts/parity-check.sh --mode cypher
```

The normal scenarios currently agree across all three bindings, with a small
documented allowlist for intentional differences. TypeScript-specific behavior
to keep in mind:

- `leidenCommunities()` and `toRustworkx()` are not available in the TypeScript
  binding because they depend on Python-only packages.
- TypeScript validates interpolated identifiers and finite numeric arguments
  before sending a query to the core.
- JavaScript has one `number` type, so a bulk value such as `1.0` is stored as
  an integer, unlike Python and Rust.
- `getNodeEdges()` returns `[source, target, relationship]` tuples, matching
  Python; Rust returns object rows in a `CypherResult`.

## Features

- **Cypher queries** — MATCH, CREATE, MERGE, SET, DELETE, WITH, UNWIND, RETURN
- **Graph algorithms** — PageRank, Louvain, Dijkstra, BFS/DFS, connected components, and more
- **Zero configuration** — Works with any SQLite database, no server required
- **Multiple bindings** — Python, Rust, TypeScript/Node.js, and raw SQL interfaces

## openCypher Conformance

GraphQLite is validated against the official [openCypher Technology Compatibility
Kit (TCK)](https://github.com/opencypher/openCypher) — the canonical conformance
suite for the Cypher query language. Current coverage:

| Area | Scenarios | Passing |
|------|-----------|---------|
| **Overall** | **3,876** | **97.7%** |
| Expressions (temporal, lists, maps, comparison, literals, …) | 2,599 | 98.0% |
| Clauses (MATCH, WITH, MERGE, CREATE, SET, DELETE, UNWIND, …) | 1,247 | 97.2% |
| Use cases (triadic selection, subgraph counting) | 30 | 100% |

Run it yourself with `angreal test tck`. The remaining gaps are tracked in
[`docs/testing/semantic-coverage-matrix.md`](docs/testing/semantic-coverage-matrix.md)
and concentrate in a few deep areas (DST-aware timezone arithmetic, nested
existential subqueries, multi-row MERGE). Booleans, strings, null handling,
CREATE/SET/DELETE/REMOVE, UNION, and SKIP/LIMIT are at 100%.

## Performance

GraphQLite ships a re-runnable cross-binding benchmark that runs the **same**
operations through the **Python, TypeScript, and Rust** bindings against the
**same** compiled C-core dylib. Run it yourself with `bash benchmarks/run.sh`
(see [`benchmarks/README.md`](benchmarks/README.md)).

> **Caveat — this is binding-layer overhead, not core speed.** All three bindings
> are thin wrappers over the identical C core (`src/extension.c`), loaded from the
> same dylib. This table therefore compares the overhead each language adds on top
> of that shared core (bulk-insert strategy, value marshalling, per-call
> round-trips, result parsing) — **not** the speed of the core algorithms
> themselves. Numbers are machine-dependent; compare only within a single run.

Median time per op — **lower is faster** (median of 3 measured runs, 1 warm-up
discarded, fresh in-memory graph per run):

| op | Python (ms) | TypeScript (ms) | Rust (ms) |
|----|-------------|-----------------|-----------|
| `build` — bulk insert 5,000 nodes + 10,000 edges | 38.23 | 100.73 | 38.17 |
| `lookup` — 2,000 individual `getNode` round-trips (total) | 6880.83 | 5801.68 | 6053.62 |
| `scan` — `MATCH (n) RETURN n.id`, 5,000 rows marshalled | 7.48 | 7.46 | 7.08 |
| `pagerank` — `pagerank(0.85, 20)` | 9.48 | 7.23 | 9.66 |
| `bfs` — traversal from a seed node | 6.72 | 6.20 | 5.91 |

`lookup` is the **total** wall time for all 2,000 round-trips (≈3 ms each — each
`getNode` is a full Cypher `MATCH` into the core), not a per-call figure.

**Measurement environment**

- Machine: Apple Silicon `arm64` (Darwin), macOS 26.5
- Dataset: 5,000 nodes / 10,000 edges (deterministic seed), 2,000 lookups; `repeats=3`
- Extension dylib `graphqlite.dylib`, sha256 `71b59280cc4922f8992cf9f8af06db2d7df5df38faa627f0e445ffa4da06ad5b`
- Python 3.14.4 (CPython) · Node.js v24.13.0 (V8 13.6.233.17) · Rust rustc 1.95.0 (`--release`)

This is deliberately separate from the **SQL-core-level** performance suite
(`tests/performance/RESULTS.md`), which measures the C engine itself independent
of any language binding — a different axis, not comparable to the table above.

## Documentation

**[Full Documentation](https://colliery-io.github.io/graphqlite/)** — Tutorials, how-to guides, and API reference

## Examples

```bash
# SQL tutorials
sqlite3 < examples/sql/01_getting_started.sql

# GraphRAG with HotpotQA dataset
cd examples/llm-graphrag
uv sync && uv run python ingest.py
uv run python rag.py "Were Scott Derrickson and Ed Wood of the same nationality?"
```

## License

[MIT](LICENSE)
