---
id: s14-migrate-add-pending-prop-join
level: task
title: "S14: Migrate add_pending_prop_join callers to sql_builder CTE-prepend"
short_code: "GQLITE-T-0268"
created_at: 2026-05-19T14:45:44.941646+00:00
updated_at: 2026-05-19T14:45:44.941646+00:00
parent: GQLITE-I-0039
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0039
---

# S14: Migrate add_pending_prop_join callers to sql_builder CTE-prepend

## Parent Initiative

[[GQLITE-I-0039]]

## Objective

Update every `add_pending_prop_join` call site to use the new `sql_builder` API from S13. After this task, `pending_prop_joins` is read-only on the context (writes go through the builder).

## Acceptance Criteria

- [ ] All `add_pending_prop_join` call sites migrated.
- [ ] `get_pending_prop_joins` returns NULL / empty for every test.
- [ ] TCK delta zero.

## Status Updates

### 2026-05-20 — Blocked on S13

Three writers + one reader of pending_prop_joins (per the S2
inventory, GQLITE-T-0256):
- writer: transform_func_aggregate.c:200
- writers/readers: transform_with.c:215, 486, 488, 491
- writer/reader: transform_return.c:37-55, 136, 479
- callers of prepend_cte_to_sql: cypher_transform.c:401, 539, 732,
  744; executor_match.c:121; executor_call_subquery.c:187;
  executor_merge_pipeline.c:83

Migration is mechanical once S13 lands. Independent of the
expression-tree work (I-0043). Could be the next concrete piece of
forward motion when someone resumes.
