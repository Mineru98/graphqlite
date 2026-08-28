// TypeScript binding benchmark for #86 — binding-layer overhead measurement.
//
// Drives the graphqlite TypeScript binding (bindings/typescript/src) through a
// fixed set of operations against a fresh in-memory graph, timing each op with
// performance.now(). Emits a single JSON document on stdout so benchmarks/run.sh
// can collect it alongside the Python and Rust legs.
//
// IMPORTANT: all three language benchmarks share the *same* C core
// (src/extension.c) via the same staged dylib (GRAPHQLITE_EXTENSION_PATH). These
// numbers are NOT core algorithm speed — they measure the per-binding overhead
// layered on top of that shared core: bulk-insert strategy, value
// escaping/marshalling, per-call round-trips, and result parsing.
//
// Ops (each: 1 warm-up run discarded, then --repeats measured runs, fresh
// :memory: graph per run): build / lookup / scan / pagerank / bfs.
//
// Run via node >=24 (native TS type-stripping + node:sqlite), same as the parity
// runner. The extension is resolved by the binding through GRAPHQLITE_EXTENSION_PATH.
//
//   node bench.ts [--nodes 5000] [--edges 10000] [--repeats 3] [--lookups 2000]

import { arch, platform, release } from 'node:os';
import {
  graph,
  type Graph,
  insertGraphBulk,
  type BulkNodeItem,
  type BulkEdgeItem,
} from '../../bindings/typescript/src/index.ts';

// Deterministic dataset multiplier — shared across the Python/TS/Rust runners so
// every binding builds the byte-identical graph.
const EDGE_K = 3;

interface OpResult {
  name: string;
  ms_median: number;
  ms_min: number;
  runs: number;
  count: number;
}

function parseArgs(argv: string[]): {
  nodes: number;
  edges: number;
  repeats: number;
  lookups: number;
} {
  const opts = { nodes: 5000, edges: 10000, repeats: 3, lookups: 2000 };
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    const val = argv[i + 1];
    if (key === '--nodes' && val !== undefined) (opts.nodes = Number(val)), i++;
    else if (key === '--edges' && val !== undefined) (opts.edges = Number(val)), i++;
    else if (key === '--repeats' && val !== undefined) (opts.repeats = Number(val)), i++;
    else if (key === '--lookups' && val !== undefined) (opts.lookups = Number(val)), i++;
  }
  return opts;
}

function buildDataset(nNodes: number, nEdges: number): {
  nodes: BulkNodeItem[];
  edges: BulkEdgeItem[];
} {
  const nodes: BulkNodeItem[] = new Array(nNodes);
  for (let i = 0; i < nNodes; i++) {
    nodes[i] = [`n${i}`, { val: i }, 'N'];
  }
  const edges: BulkEdgeItem[] = new Array(nEdges);
  for (let i = 0; i < nEdges; i++) {
    edges[i] = [`n${i % nNodes}`, `n${(i * EDGE_K + 1) % nNodes}`, {}, 'E'];
  }
  return { nodes, edges };
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1]! + sorted[mid]!) / 2 : sorted[mid]!;
}

function round4(x: number): number {
  return Math.round(x * 1e4) / 1e4;
}

// Run `setup` (untimed) then time `run` for 1 warm-up + `repeats` runs. `run`
// returns a "count" (result size / op count) used as a cross-language sanity
// check. The warm-up run (r === 0) is discarded.
function measure(
  name: string,
  repeats: number,
  setup: () => Graph,
  run: (g: Graph) => number,
  teardown: (g: Graph) => void,
): OpResult {
  const times: number[] = [];
  let count = 0;
  for (let r = 0; r <= repeats; r++) {
    const ctx = setup();
    const t0 = performance.now();
    count = run(ctx);
    const t1 = performance.now();
    teardown(ctx);
    if (r > 0) times.push(t1 - t0);
  }
  return {
    name,
    ms_median: round4(median(times)),
    ms_min: round4(Math.min(...times)),
    runs: times.length,
    count,
  };
}

function main(): void {
  const { nodes: nNodes, edges: nEdges, repeats, lookups: nLookups } = parseArgs(
    process.argv.slice(2),
  );
  const { nodes, edges } = buildDataset(nNodes, nEdges);
  const lookupIds: string[] = new Array(nLookups);
  for (let i = 0; i < nLookups; i++) lookupIds[i] = `n${i % nNodes}`;
  const seed = 'n0';

  const fresh = (): Graph => graph(':memory:');
  const loaded = (): Graph => {
    const g = graph(':memory:');
    insertGraphBulk(g.connection, nodes, edges);
    return g;
  };
  const close = (g: Graph): void => g.close();

  const ops: OpResult[] = [];

  // build — bulk insert path (fresh empty graph, time only the insert)
  ops.push(
    measure(
      'build',
      repeats,
      fresh,
      (g) => insertGraphBulk(g.connection, nodes, edges).nodesInserted,
      close,
    ),
  );

  // lookup — L individual getNode round-trips (total time)
  ops.push(
    measure(
      'lookup',
      repeats,
      loaded,
      (g) => {
        let hits = 0;
        for (const id of lookupIds) {
          if (g.getNode(id) !== null) hits++;
        }
        return hits;
      },
      close,
    ),
  );

  // scan — full result marshalling
  ops.push(measure('scan', repeats, loaded, (g) => g.query('MATCH (n) RETURN n.id').length, close));

  // pagerank
  ops.push(measure('pagerank', repeats, loaded, (g) => g.pagerank(0.85, 20).length, close));

  // bfs
  ops.push(measure('bfs', repeats, loaded, (g) => g.bfs(seed).length, close));

  const out = {
    binding: 'typescript',
    env: {
      node: process.version,
      v8: process.versions.v8,
      platform: `${platform()}-${release()}`,
      machine: arch(),
    },
    params: { nodes: nNodes, edges: nEdges, repeats, lookups: nLookups },
    ops,
  };
  process.stdout.write(JSON.stringify(out) + '\n');
}

main();
