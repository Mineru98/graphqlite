---
id: s10-migrate-transform-expr-ops-c
level: task
title: "S10: Migrate transform_expr_ops.c, transform_expr_predicate.c to sql_builder"
short_code: "GQLITE-T-0264"
created_at: 2026-05-19T14:45:13.767085+00:00
updated_at: 2026-05-19T14:45:13.767085+00:00
parent: GQLITE-I-0043
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0043
---

# S10: Migrate transform_expr_ops.c, transform_expr_predicate.c to sql_builder

## Parent Initiative

[[GQLITE-I-0043]]

## Objective

Expression-level transforms. These power BINARY_OP, NOT, NULL_CHECK, and predicate evaluation across every clause. Care needed around the `_gql_in`, `_gql_bool`, `_gql_eq` helper-UDF call patterns.

## Acceptance Criteria

- [ ] No deprecated-API warnings in either file.
- [ ] Three-valued logic test cases unchanged; `angreal test` triad clean.
- [ ] TCK delta zero.

## Status Updates

### 2026-05-20 — Subsumed by GQLITE-I-0043

These files are **the core of the expression-tree scratchpad
ecosystem** — transform_expr_ops.c (167 trio calls) and
transform_expr_predicate.c (48 trio calls) implement the binary-op /
NOT / NULL_CHECK / EXISTS / list-predicate dispatch that
transform_expression recurses into.

They cannot be migrated standalone — the recursive calls into
transform_expression and back share the ctx->sql_buffer scratchpad.
The migration is subsumed by **GQLITE-I-0043** Phase 2 (migrate
transform_expression cases) + Phase 3 (migrate function-transform
dispatch).

**Recommendation:** archive this task; the work is fully covered by
I-0043 tasks X2.5 (BINARY_OP), X2.6 (FUNCTION_CALL dispatch), and
their predicate equivalents.
