---
id: unwind-param-only-works-for-return
level: task
title: "UNWIND $param only works for RETURN, not write paths (CREATE/MERGE/SET)"
short_code: "GQLITE-T-0183"
created_at: 2026-03-30T12:11:40.003909+00:00
updated_at: 2026-03-30T12:11:40.003909+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/backlog"
  - "#bug"


exit_criteria_met: false
initiative_id: NULL
---

# UNWIND $param only works for RETURN, not write paths (CREATE/MERGE/SET)

## Objective

Extend UNWIND to support parameterized lists and item property access in write paths (CREATE, MERGE, SET), not just RETURN.

## Backlog Item Details

### Type
- [x] Bug - Production issue that needs fixing

### Priority
- [x] P1 - High (important for user experience)

### Impact Assessment
- **Affected Users**: Anyone doing batch ingestion via `UNWIND $param` — the most common data loading pattern in Cypher
- **GitHub Issue**: #49
- **Reproduction**:
  ```sql
  -- Test 1: RETURN works fine
  SELECT cypher('UNWIND $items AS item RETURN item', '{"items": [1, 2, 3]}');
  -- Result: [{"item":1},{"item":2},{"item":3}]  OK

  -- Test 2: CREATE+SET hard errors
  SELECT cypher('UNWIND $items AS item CREATE (n:Node) SET n.id = item.id, n.name = item.name',
                '{"items": [{"id": "a", "name": "Alpha"}, {"id": "b", "name": "Beta"}]}');
  -- Error: "UNWIND+CREATE currently only supports list literals"

  -- Test 3: MERGE creates 1 node instead of 2, item.id is NULL
  SELECT cypher('UNWIND $items AS item MERGE (n:Node2 {id: item.id})',
                '{"items": [{"id": "x"}, {"id": "y"}]}');
  SELECT cypher('MATCH (n:Node2) RETURN n.id ORDER BY n.id');
  -- Result: [{"n.id": null}]  (1 node, NULL id)

  -- Test 4: Even literal UNWIND loses item value in SET
  SELECT cypher('UNWIND ["a", "b"] AS item CREATE (n:Node3) SET n.id = item');
  SELECT cypher('MATCH (n:Node3) RETURN n.id ORDER BY n.id');
  -- Result: [{"n.id":null},{"n.id":null}]
  ```
- **Expected vs Actual**:
  - Test 2: should create 2 nodes with properties, instead hard errors on `AST_NODE_PARAMETER`
  - Test 3: should create 2 nodes with `id: "x"` and `id: "y"`, creates 1 with NULL
  - Test 4: should set `n.id` to `"a"` and `"b"`, both NULL

## Acceptance Criteria

- [ ] `UNWIND $param AS item CREATE (n:Label) SET n.prop = item.prop` works with parameterized lists
- [ ] `UNWIND $param AS item MERGE (n:Label {id: item.id})` iterates all items and resolves `item.id`
- [ ] `UNWIND [literal] AS item CREATE (n:Label) SET n.id = item` propagates bound item value into SET
- [ ] `UNWIND $param AS item RETURN item` continues to work (already passing)
- [ ] New regression tests for all four cases

## Implementation Notes

### Technical Approach
Three separate code paths need fixing:
1. **CREATE dispatcher** (`query_dispatch.c`): UNWIND+CREATE checks for `AST_NODE_LIST` and rejects `AST_NODE_PARAMETER`. Needs to accept parameters and use `json_each(:param)` like the RETURN path does.
2. **MERGE dispatcher**: accepts parameters but iterates only once instead of per-item, and `item.id` resolves to NULL. Needs per-item iteration.
3. **Foreach binding system**: doesn't propagate bound item values into SET expressions, even with literal lists. The UNWIND variable binding needs to flow through to the SET transform.

## Status Updates

*Confirmed reproducible on v0.4.1 (2026-03-30)*