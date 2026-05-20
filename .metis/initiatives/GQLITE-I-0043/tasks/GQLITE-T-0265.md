---
id: s11-migrate-transform-func-string
level: task
title: "S11: Migrate transform_func_string/math/path/entity/aggregate/graph/dispatch.c to sql_builder"
short_code: "GQLITE-T-0265"
created_at: 2026-05-19T14:45:21.456043+00:00
updated_at: 2026-05-19T14:45:21.456043+00:00
parent: GQLITE-I-0043
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0043
---

# S11: Migrate transform_func_string/math/path/entity/aggregate/graph/dispatch.c to sql_builder

## Parent Initiative

[[GQLITE-I-0043]]

## Objective

Per-category Cypher function transforms. Each file in its own commit. Care with `transform_func_aggregate.c` since aggregation interacts with implicit GROUP BY emission already done by `sql_builder`.

## Acceptance Criteria

- [ ] No deprecated-API warnings in any of these seven files.
- [ ] TCK delta zero across all commits.

## Status Updates

### 2026-05-20 — Subsumed by GQLITE-I-0043

These are the function-transform dispatch targets called by
`transform_func_dispatch.c` from inside transform_expression's
AST_NODE_FUNCTION_CALL handling. Per-file call counts:

| File                          | Trio calls |
| ----------------------------- | ---------: |
| transform_func_math.c         |         56 |
| transform_func_string.c       |         40 |
| transform_func_aggregate.c    |         40 |
| transform_func_entity.c       |         20 |
| transform_func_path.c         |         15 |
| transform_func_graph.c        |          7 |
| transform_func_dispatch.c     |          0 (dispatcher; clean) |

All write into the shared scratchpad. Migration plan lives in
**GQLITE-I-0043 Phase 3** (X3.2–X3.16), one per task with smallest
first.

**Recommendation:** archive this S11 wrapper task; the work is
covered by I-0043's per-file tasks when they get decomposed.
