---
id: with-variable-import-into-call
level: task
title: "WITH variable import into CALL subquery scope"
short_code: "GQLITE-T-0177"
created_at: 2026-03-29T01:05:16.452673+00:00
updated_at: 2026-03-29T01:05:16.452673+00:00
parent: GQLITE-I-0034
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0034
---

# WITH variable import into CALL subquery scope

## Parent Initiative

[[GQLITE-I-0034]]

## Objective

Implement WITH-based variable import so that a CALL subquery can reference outer-scope variables by listing them in a leading WITH clause.

## Affected Files

- `src/backend/transform/cypher_transform.c`
- `src/backend/executor/query_dispatch.c`

## Implementation Notes

- When a CALL subquery starts with `WITH var1, var2`, those identifiers must resolve to variables from the outer scope rather than being treated as new bindings
- In the transform layer: map outer aliases to inner column references so the generated SQL correctly references the outer CTE columns
- In the executor layer: pass matched variable IDs (node/edge IDs) from the outer result row into the inner execution context
- Variables not listed in WITH must not be accessible inside the subquery (scope isolation)
- WITH expressions (e.g., `WITH a, a.name AS n`) should also be supported

## Acceptance Criteria

- [ ] `MATCH (a) CALL { WITH a SET a.touched = true }` correctly modifies node a
- [ ] Variables not imported via WITH are not visible inside the subquery
- [ ] WITH expressions like `WITH a, a.name AS n` work correctly
- [ ] Errors are raised for references to outer variables not listed in WITH

## Effort Estimate

1-2 days

## Status Updates

*To be added during implementation*