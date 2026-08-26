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
