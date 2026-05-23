---
id: a3-match6-undirected-double-count
level: task
title: "A3: Match6 undirected double-count — each undirected edge matches forward + backward"
short_code: "GQLITE-T-0327"
created_at: 2026-05-23T10:54:13.351553+00:00
updated_at: 2026-05-23T10:54:13.351553+00:00
parent: GQLITE-I-0044
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0044
---

# A3: Undirected MATCH double-count

## Parent Initiative

[[GQLITE-I-0044]] — Phase A quick win #3.

## Objective

Undirected MATCH patterns like `(a)--(b)` return 2× expected rows
because each undirected edge matches the OR of forward + backward
directions, and each direction independently contributes a row.

## Repro

```cypher
CREATE (a:A)-[:T]->(b:B);
MATCH (a:A)--(b:B) RETURN a, b;
```

**Expected:** 1 row (the single edge).
**Actual:** 2 rows (same edge matched both ways via the OR clause).

## Affected scenarios

- Match6 [10] Named path with alternating directed/undirected
  relationships (expected 1 got 3).
- Match6 [11] Multiple alternating directed/undirected
  (expected 1 got 8).
- Match6 [12] Path with multiple bidirectional rels
  (expected 4 got 8).
- Match6 [13] Path with both directions (expected 2 got 4).
- Possibly Match6 [8] (non-existent path with multiple directions —
  expected 0 got 2).

Estimated **+3-5 TCK** (some Match6 failures have other root
causes like relationship-uniqueness that this won't fix).

## Implementation plan

1. Inspect `transform_match.c` rel handler for the undirected
   emission. Currently produces something like:
   ```sql
   (edge.source_id = a.id AND edge.target_id = b.id)
   OR
   (edge.source_id = b.id AND edge.target_id = a.id)
   ```
   For a single physical edge `a→b`, this clause is true under
   the FIRST disjunct AND ALSO under the second (when matched
   reverse, but the underlying edge row is the same). Each
   match of the disjunct produces a row.

2. Cypher semantics: undirected MATCH should produce ONE row per
   underlying edge, regardless of direction. The two-way match
   is a property of the PATTERN match, not a row multiplier.

3. Fix approach A: use a single ON clause that's symmetric in
   a sortable way:
   ```sql
   ((edge.source_id = a.id AND edge.target_id = b.id) OR
    (edge.source_id = b.id AND edge.target_id = a.id))
   AND <something that prevents double-counting>
   ```
   Possibilities for the dedup:
   - `(LEAST(a.id, b.id) = LEAST(edge.source_id, edge.target_id)
      AND GREATEST(a.id, b.id) = GREATEST(...))` — enforce canonical
     ordering.
   - `DISTINCT` at the outer SELECT level — heavy hammer.
   - Restructure the JOIN to ensure each edge row produces one
     pattern row.

4. Fix approach B: split into two non-overlapping cases via the
   AST — emit two ON clauses with mutually exclusive conditions
   (e.g. forward XOR reverse, where reverse implies source > target
   or some canonical tie-break).

5. Verify the fix doesn't break SELF-loops (an edge `a-->a`
   matches `(a)--(a)` ONCE, not twice).

## Acceptance Criteria

- [ ] Match6 [10]/[11]/[12]/[13] pass.
- [ ] `(a)--(b)` returns the same row count as
  `(a)-->(b) UNION (a)<--(b)` deduplicated, NOT 2×.
- [ ] Self-loops match exactly once.
- [ ] No regression on existing undirected/directed scenarios.
- [ ] `angreal test unit && angreal test functional` clean.

## Affected files

- `src/backend/transform/transform_match.c` — rel handler
  undirected emission (the `!rel->left_arrow && !rel->right_arrow`
  branch).

## Effort

S-M — single edit point, but the dedup strategy needs to handle
self-loops and bidirectional-but-distinct-edges (a→b AND b→a
between same nodes is two real edges, both should match).

## Status Updates

*To be added during implementation.*
