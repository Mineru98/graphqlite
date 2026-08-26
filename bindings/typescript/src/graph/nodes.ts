// Node read/delete operations as pure functions.
//
// Each takes a Connection first so Graph can delegate in three lines (see
// graph/index.ts). Mirrors bindings/python/src/graphqlite/graph/nodes.py. The
// write side (`upsertNode`) depends on `hasNode` and lands with N-02 (#10).
import type { Connection } from '../connection.ts';
import { assertIdentifier } from '../utils.ts';
import type { CypherValue } from '../result.ts';

/**
 * Whether a node with the given `id` property exists.
 *
 * Parses defensively (matches nodes.py:26-29): empty result → false, a falsy
 * `cnt` → false, otherwise `Number(cnt) > 0`.
 */
export function hasNode(conn: Connection, nodeId: string): boolean {
  const result = conn.cypher('MATCH (n {id: $id}) RETURN count(n) AS cnt', { id: nodeId });
  if (result.length === 0) {
    return false;
  }
  const cnt = result[0]?.['cnt'];
  return cnt ? Number(cnt) > 0 : false;
}

/**
 * Fetch a node by its `id` property, or `null` if none. The `n` cell is returned
 * **unmodified** ({@link CypherValue}, the `{id, labels, properties}` shape) —
 * no reshaping, matching nodes.py:41-47.
 */
export function getNode(conn: Connection, nodeId: string): CypherValue | null {
  const result = conn.cypher('MATCH (n {id: $id}) RETURN n', { id: nodeId });
  if (result.length === 0) {
    return null;
  }
  return result[0]?.['n'] ?? null;
}

/** Delete a node and its relationships (`DETACH DELETE`). */
export function deleteNode(conn: Connection, nodeId: string): void {
  conn.cypher('MATCH (n {id: $id}) DETACH DELETE n', { id: nodeId });
}

/**
 * All nodes, optionally filtered by `label`. The label is **interpolated** into
 * the Cypher (not a bound param), so it is validated with {@link assertIdentifier}
 * first — a bad label raises `ValidationError`.
 *
 * The parse is deliberately dual-path (mirrors nodes.py:108-120): when a row
 * carries a string `result` key it is JSON-parsed and each `item.n` collected —
 * **parse failures are silently ignored** — otherwise a truthy `row.n` is
 * collected directly. Dropping this fallback yields an empty array for certain
 * result shapes (the raw-string wrapping from result.ts).
 */
export function getAllNodes(conn: Connection, label?: string): CypherValue[] {
  let result;
  if (label) {
    assertIdentifier(label, 'label');
    result = conn.cypher(`MATCH (n:${label}) RETURN n`);
  } else {
    result = conn.cypher('MATCH (n) RETURN n');
  }

  const nodes: CypherValue[] = [];
  for (const row of result) {
    const raw = row['result'];
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          for (const item of parsed) {
            if (item && typeof item === 'object' && 'n' in item) {
              nodes.push(item.n as CypherValue);
            }
          }
        }
      } catch {
        // Silently ignore non-JSON — matches Python's bare `except`.
      }
    } else if (row['n']) {
      nodes.push(row['n']);
    }
  }
  return nodes;
}
