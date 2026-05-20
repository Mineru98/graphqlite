---
id: s12-migrate-transform-func-list-c
level: task
title: "S12: Migrate transform_func_list.c to sql_builder (432 call sites — depends on I-0040 M8-M11)"
short_code: "GQLITE-T-0266"
created_at: 2026-05-19T14:45:29.948736+00:00
updated_at: 2026-05-19T14:45:29.948736+00:00
parent: GQLITE-I-0043
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0043
---

# S12: Migrate transform_func_list.c to sql_builder (432 call sites — depends on I-0040 M8-M11)

## Parent Initiative

[[GQLITE-I-0043]]

## Objective

Largest single file in the migration. Strongly preferred to do AFTER I-0040 M8-M11 splits this file into temporal/geo/json/typeconv/list_core (each ~500 LOC) — migrating four small files is reviewable; migrating one 1,979-LOC file is not. Each post-split file migrated in its own commit.

## Acceptance Criteria

- [ ] I-0040 M8-M11 completed first.
- [ ] No deprecated-API warnings in any of the post-split files.
- [ ] TCK delta zero across all commits.

## Status Updates

### 2026-05-20 — Subsumed by GQLITE-I-0043

I-0040 M8-M11 dependency is **satisfied** (transform_func_list.c
was split into temporal / geo / json / typeconv / list-core during
the structural-debt push). Per-file call counts post-split:

| File                          | Trio calls |
| ----------------------------- | ---------: |
| transform_func_temporal.c     |        285 |
| transform_func_list.c (core)  |         38 |
| transform_func_geo.c          |         38 |
| transform_func_typeconv.c     |         28 |
| transform_func_json.c         |         14 |

But all of these are part of the expression-tree scratchpad and
need GQLITE-I-0043 first.

**Recommendation:** archive this task; covered by I-0043 per-file
tasks. Note that transform_func_temporal.c is the **biggest single
migration target** in the codebase (285 calls + heavy use of
EMIT/EMIT_TIME_BASE macros that themselves wrap append_sql). Its
migration alone is a significant piece of work.
