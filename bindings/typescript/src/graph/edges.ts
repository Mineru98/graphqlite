// Edge read/delete operations as pure functions.
//
// Each takes a Connection first so Graph can delegate in three lines (see
// graph/index.ts). Mirrors bindings/python/src/graphqlite/graph/edges.py. The
// write side (`upsertEdge`) shares this file and lands with E-02 (#12).
import type { Connection } from '../connection.ts';
import { sanitizeRelType } from '../utils.ts';
import type { CypherRow, CypherValue } from '../result.ts';

/**
 * The `[r{...}]` relationship pattern. When a `relType` is given it is sanitized
 * (never validated/thrown — {@link sanitizeRelType} coerces to a safe token) and
 * interpolated as `:TYPE`; otherwise the pattern is bare `[r]`. Node ids are
 * always bound (`$src`/`$tgt`), never interpolated.
 */
function relPattern(relType?: string): string {
  return relType ? `:${sanitizeRelType(relType)}` : '';
}

/**
 * Whether an edge exists between two nodes (optionally of a given type). Parses
 * like {@link import('./nodes.ts').hasNode}: empty → false, falsy `cnt` → false,
 * else `Number(cnt) > 0` (mirrors edges.py:31-34).
 */
export function hasEdge(
  conn: Connection,
  sourceId: string,
  targetId: string,
  relType?: string,
): boolean {
  const result = conn.cypher(
    `MATCH (a {id: $src})-[r${relPattern(relType)}]->(b {id: $tgt}) RETURN count(r) AS cnt`,
    { src: sourceId, tgt: targetId },
  );
  if (result.length === 0) {
    return false;
  }
  const cnt = result[0]?.['cnt'];
  return cnt ? Number(cnt) > 0 : false;
}

/** Fetch the edge between two nodes, or `null` if none. `r` is returned unmodified. */
export function getEdge(
  conn: Connection,
  sourceId: string,
  targetId: string,
  relType?: string,
): CypherValue | null {
  const result = conn.cypher(
    `MATCH (a {id: $src})-[r${relPattern(relType)}]->(b {id: $tgt}) RETURN r`,
    { src: sourceId, tgt: targetId },
  );
  if (result.length === 0) {
    return null;
  }
  return result[0]?.['r'] ?? null;
}

/** Delete the edge(s) between two nodes (optionally of a given type). */
export function deleteEdge(
  conn: Connection,
  sourceId: string,
  targetId: string,
  relType?: string,
): void {
  conn.cypher(`MATCH (a {id: $src})-[r${relPattern(relType)}]->(b {id: $tgt}) DELETE r`, {
    src: sourceId,
    tgt: targetId,
  });
}

/**
 * All edges as `{ source, target, r }` rows. The `toList()` result is returned
 * **unmodified** (mirrors edges.py:145-148); callers depend on those exact keys.
 */
export function getAllEdges(conn: Connection): CypherRow[] {
  const result = conn.cypher('MATCH (a)-[r]->(b) RETURN a.id AS source, b.id AS target, r');
  return result.toList();
}
