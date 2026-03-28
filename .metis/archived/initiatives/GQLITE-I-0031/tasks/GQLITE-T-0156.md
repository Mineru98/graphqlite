---
id: rec-01-sql-injection-escape-audit
level: task
title: "REC-01: SQL injection escape audit pass"
short_code: "GQLITE-T-0156"
created_at: 2026-03-28T13:59:10.767898+00:00
updated_at: 2026-03-28T22:44:59.668041+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: true

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-01: Escape special characters in Cypher identifiers for correct SQL generation

## Objective

Apply `escape_sql_string()` to all callsites that interpolate Cypher identifiers (labels, relationship types, property names, graph names) into generated SQL. This is a **correctness fix** — labels like `O'Brien`, relationship types with special characters, and property names with quotes should produce valid SQL. The secondary benefit is defense-in-depth against injection if Cypher is ever exposed as a standalone API.

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

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] Injection vector tests added for all 4 callsite groups
- [ ] All identified callsites in `cypher_transform.c`, `transform_match.c`, `transform_expr_ops.c`, `transform_func_entity.c` use `escape_sql_string()`
- [ ] All 770 unit tests pass
- [ ] All functional tests pass
- [ ] No new compiler warnings

## Effort Estimate

1-2 days

## Status Updates

### 2026-03-28: Implementation complete

**12 callsites fixed across 3 files:**
1. `cypher_transform.c` (4 sites): varlen CTE relationship types
2. `transform_match.c` (5 sites): label joins + edge type conditions
3. `transform_expr_ops.c` (3 sites): property names in json_extract paths

**Multi-graph prefix** deferred — SQL identifier injection, not string literal. Different handling needed.

**Verified:** `O'Brien` labels and `HAS'REL` relationship types work. 921 unit + 43 functional tests pass.