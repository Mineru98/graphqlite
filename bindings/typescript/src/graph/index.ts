// The Graph facade — a thin front over the driver connection.
//
// Python composes Graph from 12 mixins via multiple inheritance
// (bindings/python/src/graphqlite/graph/__init__.py). Mirroring that in TS
// makes the types messy and, worse, funnels every feature into one Graph file —
// a parallel-development bottleneck. Instead each feature module exports **pure
// functions** taking a Connection first, and Graph delegates in three lines:
//
//   // src/graph/nodes.ts
//   export function hasNode(conn: Connection, nodeId: string): boolean { ... }
//   // here
//   hasNode(nodeId: string) { return hasNode(this.#conn, nodeId); }
//
// This element (G-01) is the **skeleton only**. Delegation methods and the cache
// helpers (load/unload/reload — those land with C-01 #14) are added by later
// elements at the marked insertion points below.
import { connect, type Connection, type ConnectionOptions } from '../connection.ts';
import type { CypherValue } from '../result.ts';
import { hasNode, getNode, deleteNode, getAllNodes } from './nodes.ts';

export interface GraphOptions extends ConnectionOptions {
  /**
   * Namespace label for the graph. **Stored but never used in queries** — this
   * is a dead parameter in the Python binding too, reproduced here verbatim so
   * the three bindings share one surface. Do not thread it into Cypher.
   */
  namespace?: string;
}

/**
 * High-level graph interface for GraphQLite. Wraps a {@link Connection} and, in
 * later elements, delegates node/edge/query/algorithm calls to pure feature
 * functions. Disposable via `using` (see {@link graph}).
 */
export class Graph {
  readonly #conn: Connection;

  /** The namespace passed at construction. Not used by any query (see {@link GraphOptions.namespace}). */
  readonly namespace: string;

  constructor(dbPath: string = ':memory:', options: GraphOptions = {}) {
    const { namespace = 'default', ...connectionOptions } = options;
    this.#conn = connect(dbPath, connectionOptions);
    this.namespace = namespace;
  }

  /** The underlying driver connection. */
  get connection(): Connection {
    return this.#conn;
  }

  /** Close the database connection. */
  close(): void {
    this.#conn.close();
  }

  /** Enables `using g = graph(...)` — disposes by closing the connection. */
  [Symbol.dispose](): void {
    this.close();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Delegation insertion points — Python Graph MRO order.
  // Each later element adds ONLY its own three-line delegations here, in place,
  // so the facade stays diff-friendly and merge conflicts stay local.
  //
  //   nodes       — #9  [N-01] 노드 읽기·삭제  ← 아래 구현됨
  //   edges       — #11 [E-01] 엣지 읽기·삭제
  //   queries     — #13 [Q-01] 그래프 조회 8종 (queries.ts)
  //   batch       — (batch ops)                     [+ cache 4종 → #14 C-01]
  //   centrality  — #15 [A-01] 중심성 알고리즘 5종
  //   community   — #16 [A-02] 커뮤니티 탐지
  //   components  — #17 [A-03] 연결 요소 (WCC/SCC)
  //   paths       — #18 [A-04] 경로 알고리즘 (dijkstra/astar/apsp)
  //   traversal   — #19 [A-05] 순회 (BFS/DFS)
  //   similarity  — #20 [A-06] 유사도 (nodeSimilarity/knn/triangleCount)
  // ──────────────────────────────────────────────────────────────────────────

  // ── nodes — #9 [N-01] ──────────────────────────────────────────────────────
  /** Whether a node with the given `id` exists. */
  hasNode(nodeId: string): boolean {
    return hasNode(this.#conn, nodeId);
  }

  /** Fetch a node by `id`, or `null` if none (returned unmodified). */
  getNode(nodeId: string): CypherValue | null {
    return getNode(this.#conn, nodeId);
  }

  /** Delete a node and its relationships. */
  deleteNode(nodeId: string): void {
    deleteNode(this.#conn, nodeId);
  }

  /** All nodes, optionally filtered by `label` (validated as an identifier). */
  getAllNodes(label?: string): CypherValue[] {
    return getAllNodes(this.#conn, label);
  }
}

/**
 * Create a new {@link Graph}. Factory matching the style of `connect()`.
 *
 * @param dbPath  Path to a database file, or `:memory:` (the default).
 * @param options `namespace` (stored, unused) and connection/extension options.
 */
export function graph(dbPath: string = ':memory:', options: GraphOptions = {}): Graph {
  return new Graph(dbPath, options);
}
