---
id: startnode-r-endnode-r-return
level: task
title: "startNode(r)/endNode(r) return integer IDs and collide column aliases"
short_code: "GQLITE-T-0181"
created_at: 2026-03-30T12:11:37.126169+00:00
updated_at: 2026-03-30T12:11:37.126169+00:00
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

# startNode(r)/endNode(r) return integer IDs and collide column aliases

## Objective

Fix `startNode(r)` and `endNode(r)` so they return node data instead of raw integer IDs, and generate unique column aliases when both appear in the same `RETURN` clause.

## Backlog Item Details

### Type
- [x] Bug - Production issue that needs fixing

### Priority
- [ ] P1 - High (important for user experience)

### Impact Assessment
- **Affected Users**: Anyone using `startNode(r)` / `endNode(r)` in queries
- **GitHub Issue**: #50
- **Reproduction**:
  ```sql
  SELECT cypher('CREATE (a:Person {name: "Alice"})-[:KNOWS]->(b:Person {name: "Bob"})');
  -- Bare call returns integer IDs instead of nodes:
  SELECT cypher('MATCH ()-[r:KNOWS]->() RETURN startNode(r) AS sn, endNode(r) AS en');
  -- Result: [{"sn":1,"en":2}]
  
  -- Both in same RETURN collide on column alias "name":
  SELECT cypher('MATCH ()-[r:KNOWS]->() RETURN startNode(r).name, endNode(r).name');
  -- Result: [{"name":"Alice","name":"Bob"}]  (duplicate JSON key)
  ```
- **Expected vs Actual**:
  - Bare: should return node objects/maps, returns raw `source_id`/`target_id` integers
  - Property access: should produce distinct column names (`startNode(r).name`, `endNode(r).name`), instead both alias to `name` causing JSON key collision. Only one value survives in most parsers.

## Acceptance Criteria

- [ ] `startNode(r)` / `endNode(r)` return node property maps (not integer IDs)
- [ ] `RETURN startNode(r).name, endNode(r).name` produces two distinct columns with correct values
- [ ] Column aliases include the function call context (e.g., `startNode(r).name` not just `name`)
- [ ] Existing `startNode`/`endNode` tests continue to pass
- [ ] New regression tests added covering both-in-same-RETURN case

## Implementation Notes

### Technical Approach
- Bare `startNode(r)` currently maps directly to `source_id` from the edges table. Needs a join back to the nodes table to return node data.
- `transform_property_access()` (in `transform_expr_ops.c`) handles the property access case but appears to use a shared buffer/alias, causing the second call to overwrite the first when both appear in the same RETURN.

## Status Updates

*Confirmed reproducible on v0.4.1 (2026-03-30)*