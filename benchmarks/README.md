# GraphQLite binding benchmarks (#86)

A reproducible harness that runs the **same** set of operations through all three
language bindings — **Python, Rust, TypeScript** — against the **same** compiled
C-core dylib, and prints a comparison table.

## What this actually measures (read this first)

All three bindings are thin wrappers over the **same** C core (`src/extension.c`),
loaded from the **same** dylib via `GRAPHQLITE_EXTENSION_PATH`. So this benchmark
**does not** measure core algorithm speed — the core is identical byte-for-byte
across the three legs. It measures the **binding-layer overhead** each language
adds on top of that shared core:

- **bulk-insert strategy** (`build`) — how the binding drives the raw-SQL bulk path.
- **per-call round-trip cost** (`lookup`) — the fixed overhead of 2,000 individual
  `getNode` calls, each a full Cypher `MATCH` round-trip into the core.
- **result marshalling** (`scan`) — turning a full result set into native
  lists/dicts/objects.
- **algorithm-result parsing** (`pagerank`, `bfs`) — the core does the work; the
  binding parses the returned rows.

For **SQL-core-level** performance (the C engine itself, independent of any
binding) see `tests/performance/RESULTS.md` — that is a different axis and not
comparable to the numbers here.

## Operations

Each op runs on a **fresh `:memory:` graph**, with **1 warm-up run discarded**,
then `--repeats` measured runs; the reported value is the **median** (with min).
Timing uses `time.perf_counter` (Python), `performance.now()` (TS), and
`std::time::Instant` (Rust).

| op | what it does | timed region |
|----|--------------|--------------|
| `build`    | `insertGraphBulk` of N nodes + E edges (deterministic seed) | the bulk insert |
| `lookup`   | `getNode` × L individual round-trips                        | total for all L calls |
| `scan`     | `MATCH (n) RETURN n.id` returning all rows                  | query + full marshalling |
| `pagerank` | `pagerank(0.85, 20)`                                        | whole op |
| `bfs`      | `bfs(seed)` full traversal                                  | whole op |

The dataset is index-seeded and identical across all three bindings:
node id `n{i}` with `{val: i}` (label `N`); edge `i` goes `n{i%N} → n{(i*3+1)%N}`
(rel `E`). Each runner also reports a per-op result **count**, which
`run.sh` cross-checks across bindings as a correctness guard.

## Running

```bash
# 1. Build the C extension (requires bison 3+; on macOS: brew install bison)
PATH="$(brew --prefix bison)/bin:$PATH" make extension    # -> build/graphqlite.dylib

# 2. Run all three legs and print the comparison table
bash benchmarks/run.sh                                    # defaults: 5000 / 10000 / 3
bash benchmarks/run.sh --nodes 20000 --edges 40000 --repeats 5 --lookups 5000
```

`run.sh` stages the dylib exactly like `scripts/parity-check.sh`: it resolves
`build/graphqlite.dylib` (then the staged CI artifact), exports
`GRAPHQLITE_EXTENSION_PATH`, copies it into the Python package's bundled path,
reuses/creates the `/tmp/gqlite-parity-venv` editable install, and builds Rust
with `cargo run --release --no-default-features` so it loads the **env dylib**
instead of its embedded extension. If a leg fails to build/run, `run.sh` prints
the error, **excludes** that leg from the table, and continues with the rest — it
never fabricates numbers.

Each leg can also be run directly (it prints JSON on stdout):

```bash
export GRAPHQLITE_EXTENSION_PATH="$PWD/build/graphqlite.dylib"
python benchmarks/python/bench.py --nodes 5000 --edges 10000 --repeats 3
node   benchmarks/ts/bench.ts     --nodes 5000 --edges 10000 --repeats 3
( cd benchmarks/rust && cargo run --release --no-default-features -- --nodes 5000 --edges 10000 --repeats 3 )
```

Per-leg JSON shape:

```json
{
  "binding": "python",
  "env": { "python": "3.14.4", "platform": "..." },
  "params": { "nodes": 5000, "edges": 10000, "repeats": 3, "lookups": 2000 },
  "ops": [ { "name": "build", "ms_median": 38.2, "ms_min": 38.0, "runs": 3, "count": 5000 }, ... ]
}
```

## Caveats

- **Not core speed.** Same C core across all three legs — this is binding overhead only.
- **Machine-dependent.** Absolute numbers vary by CPU, OS, and toolchain versions.
  Compare *within a single run* on *one machine*; do not compare across machines.
- **Different build profiles by design.** Python is interpreted (CPython), TS runs
  under V8's JIT, Rust is compiled `--release`. The profile of each leg is recorded
  in the output header — this is a real-world "how fast is each binding as you'd
  actually ship it" comparison, not an apples-to-apples microbenchmark of one language.
- **`lookup` is a total, not per-call.** It is the wall time of all L round-trips;
  divide by L for the per-call cost.
- **Warm-up + median** dampen JIT/allocator/cache warm-up noise but do not remove
  it entirely; use `--repeats` to taste.
