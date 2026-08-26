// GraphQLite TypeScript bindings — public entry point.
//
// The driver-facing round-trip (`connect`, `wrap`, `Connection`) lands here with
// F-07 (#7). Higher-level surfaces (`graph()`, `graphs()`) arrive in later
// elements; see docs/internal/typescript-bindings-design.md §6.
export {
  connect,
  wrap,
  Connection,
  type ConnectOptions,
  type ConnectionOptions,
} from './connection.ts';
export { graph, Graph, type GraphOptions } from './graph/index.ts';
export { hasNode, getNode, deleteNode, getAllNodes, upsertNode } from './graph/nodes.ts';
export { hasEdge, getEdge, deleteEdge, getAllEdges } from './graph/edges.ts';
