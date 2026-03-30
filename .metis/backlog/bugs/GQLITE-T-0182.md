---
id: call-subquery-merge-resolves-inner
level: task
title: "CALL subquery MERGE resolves inner variables to outer scope (self-referencing relationships)"
short_code: "GQLITE-T-0182"
created_at: 2026-03-30T12:11:38.377823+00:00
updated_at: 2026-03-30T12:11:38.377823+00:00
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

# CALL subquery MERGE resolves inner variables to outer scope (self-referencing relationships)

## Objective

Fix variable scoping in CALL subqueries so that inner `MATCH` variables are not resolved to outer-scope variables when used in write operations (`MERGE`, `CREATE`).

## Backlog Item Details

### Type
- [x] Bug - Production issue that needs fixing

### Priority
- [x] P1 - High (important for user experience)

### Impact Assessment
- **Affected Users**: Anyone using CALL subqueries with write operations that reference both outer and inner variables
- **GitHub Issue**: #51
- **Reproduction**:
  ```sql
  SELECT cypher('CREATE (c:Co {id: "acme"})');
  SELECT cypher('CREATE (d:Dep {id: "eng"})');
  SELECT cypher('MATCH (c:Co {id: "acme"}) CALL { With c MATCH (d:Dep {id: "eng"}) MERGE (c)-[:HAS]->(d) }');
  SELECT cypher('MATCH (a)-[:HAS]->(b) RETURN a.id, labels(a) AS al, b.id, labels(b) AS bl');
  -- Result: [{"a.id":"acme","al":"[\"Co\"]","b.id":"acme","bl":"[\"Co\"]"}]
  -- Self-loop: Company linked to itself instead of to the Department
  ```
- **Expected vs Actual**:
  - Expected: `b.id: "eng"`, `bl: ["Dep"]` — relationship from Company to Department
  - Actual: `b.id: "acme"`, `bl: ["Co"]` — self-referencing relationship on Company. The inner `d` from `MATCH (d:Dep)` resolves to outer `c`.

## Acceptance Criteria

- [ ] `CALL { WITH c MATCH (d:Label) MERGE (c)-[:REL]->(d) }` creates relationship to `d`, not a self-loop on `c`
- [ ] Inner MATCH variables are scoped correctly and do not collide with outer/imported variables
- [ ] Read-only CALL subqueries continue to work (already passing)
- [ ] CALL with UNION branches also correctly scopes inner variables
- [ ] New regression tests covering write operations inside CALL with both outer and inner variables

## Implementation Notes

### Technical Approach
- The CALL executor generates SQL for the inner block. Read path scope isolation works correctly. The bug is specific to write operations: when `MERGE` inside `CALL` resolves `d`, it looks up the variable in the outer scope (where only `c` exists) instead of the inner scope (where `d` was just matched).
- Variable lookup for write targets needs to check inner `MATCH` bindings before falling back to outer scope.

## Status Updates

*Confirmed reproducible on v0.4.1 (2026-03-30)*