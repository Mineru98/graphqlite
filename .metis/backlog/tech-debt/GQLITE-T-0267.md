---
id: s13-add-typed-cte-prepend-section
level: task
title: "S13: Add typed CTE-prepend section to sql_builder API"
short_code: "GQLITE-T-0267"
created_at: 2026-05-19T14:45:37.924593+00:00
updated_at: 2026-05-19T14:45:37.924593+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/backlog"


exit_criteria_met: false
initiative_id: NULL
---

# S13: Add typed CTE-prepend section to sql_builder API

## Parent Initiative

GQLITE-I-0039 (archived — moved to backlog 2026-05-20)

## Objective

Add a typed "pending CTE / prepend" clause section to `sql_builder` so `pending_prop_joins` has a target API to migrate into. Section needs the same prepend semantics as today's manual splicing — placed BEFORE any user-written CTEs, then the existing CTE section, then SELECT.

## Acceptance Criteria

- [ ] `sql_builder` has a new typed section for pre-CTE prepends (signature documented in sql_builder.h).
- [ ] Unit tests cover the prepend semantics + ordering relative to user CTEs.
- [ ] Existing callers unaffected (additive change).

## Status Updates

### 2026-05-20 — Still valid, prerequisite for S14-S15

This task is independent of the I-0042/I-0043 work and can be done
standalone. It adds infrastructure for the eventual
`pending_prop_joins` migration without requiring expression-tree
changes.

Suggested when picked up:
- Add a `dynamic_buffer pre_cte;` (or similar) section to
  sql_builder
- Update sql_builder_to_string to emit pre_cte before cte before
  select
- Add `sql_pre_cte(b, name, query)` API to write into it
- Unit tests in test_sql_builder.c

Then S14 can migrate add_pending_prop_join callers to use it.
