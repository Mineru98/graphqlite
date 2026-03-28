---
id: rec-01-sql-injection-escape-audit
level: task
title: "REC-01: SQL injection escape audit pass"
short_code: "GQLITE-T-0156"
created_at: 2026-03-28T13:59:10.767898+00:00
updated_at: 2026-03-28T13:59:10.767898+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-01: SQL injection escape audit pass

## Objective

Apply `escape_sql_string()` to all callsites that interpolate user-controlled strings into SQL, closing 5 architecture review findings (SEC-001, SEC-002, SEC-003, SEC-004, COR-006). Add injection vector tests before applying fixes.

## Affected Files

- `src/backend/transform/cypher_transform.c` (lines 762, 770, 796, 804) -- varlen CTE relationship type names
- `src/backend/transform/transform_match.c` (lines 761, 948, 1047) -- MATCH label join predicates
- `src/backend/transform/cypher_transform.c` (line 185), `transform_expr_ops.c` (line 418), `transform_func_entity.c` (lines 105, 156, 283) -- multi-graph table prefix construction
- `src/backend/transform/transform_expr_ops.c` (lines 323-325, 332-335, 409) -- property names in json_extract path arguments

## What To Do

1. Write functional tests that demonstrate injection through each of the 4 callsite groups (label names with SQL metacharacters, property names with quotes, etc.)
2. Wrap each identified callsite with `escape_sql_string()` before interpolation into SQL
3. Verify all existing unit and functional tests still pass
4. Verify the new injection vector tests now pass (injections blocked)

## Acceptance Criteria

- [ ] Injection vector tests added for all 4 callsite groups
- [ ] All identified callsites in `cypher_transform.c`, `transform_match.c`, `transform_expr_ops.c`, `transform_func_entity.c` use `escape_sql_string()`
- [ ] All 770 unit tests pass
- [ ] All functional tests pass
- [ ] No new compiler warnings

## Effort Estimate

1-2 days

## Status Updates

*To be added during implementation*