---
id: transform-generate-sql-from-call
level: task
title: "Transform: generate SQL from CALL subquery inner clauses"
short_code: "GQLITE-T-0175"
created_at: 2026-03-29T01:05:14.217884+00:00
updated_at: 2026-03-29T01:05:14.217884+00:00
parent: GQLITE-I-0034
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0034
---

# Transform: generate SQL from CALL subquery inner clauses

## Parent Initiative

[[GQLITE-I-0034]]

## Objective

Transform CALL subquery AST nodes into valid SQL by generating inner SQL from the subquery's clauses within a nested transform context.

## Affected Files

- `src/backend/transform/cypher_transform.c`

## Implementation Notes

- Add `AST_NODE_CALL_SUBQUERY` case in `cypher_transform_query()`'s clause switch
- Create a nested transform context for the inner clauses so inner variables do not leak into the outer scope
- Outer variables imported via the leading `WITH` clause become column references from the outer CTE
- Each UNION branch in the subquery should be transformed independently and combined with SQL UNION
- The generated SQL should be a lateral subquery or CTE that joins against the outer result set

## Acceptance Criteria

- [ ] `MATCH (a) CALL { WITH a MATCH (b) RETURN b } RETURN b` generates valid, executable SQL
- [ ] Inner variables are scoped correctly and do not collide with outer names
- [ ] Multiple UNION branches each produce valid SQL joined by UNION
- [ ] Existing transform tests still pass

## Effort Estimate

2-3 days

## Status Updates

*To be added during implementation*