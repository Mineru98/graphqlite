---
id: rec-14-migrate-static-transform
level: task
title: "REC-14: Migrate static transform globals into per-query context"
short_code: "GQLITE-T-0169"
created_at: 2026-03-28T13:59:39.599156+00:00
updated_at: 2026-03-28T13:59:39.599156+00:00
parent: GQLITE-I-0033
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0033
---

# REC-14: Migrate static transform globals into per-query context

## Objective

Migrate static/global transform state into a `cypher_transform_context` struct, extract duplicated helpers, and add formal buffer management. Addresses findings COR-004, EVO-01, SEC-009, LEG-003, LEG-004, LEG-008 (Critical aggregate).

## Affected Files

- `src/backend/transform/` -- multiple files using static globals
- New: `src/backend/transform/transform_helpers.c` (extracted shared code)

## What To Do

### Phase 1: Counters (1 week)
1. Create `cypher_transform_context` struct
2. Move `with_cte_counter`, `prop_join_counter`, `reduce_counter`, `unwind_cte_counter` into the context
3. Thread context through all transform functions

### Phase 2: Buffers + Extraction (1 week)
4. Move `pending_prop_joins` and `id_ref_buf` into the context
5. Add formal `push_buffer()` / `pop_buffer()` API for nested transform scopes
6. Extract duplicate `transform_expression_to_string()` implementations into `transform_helpers.c`

## Acceptance Criteria

- [ ] No static/global mutable state remains in transform layer
- [ ] `cypher_transform_context` passed through all transform call chains
- [ ] `push_buffer()` / `pop_buffer()` API exists and is used
- [ ] `transform_expression_to_string()` exists in exactly one place
- [ ] All unit and functional tests pass
- [ ] No new compiler warnings

## Effort Estimate

1-2 weeks (Phase 1: 1 week, Phase 2: 1 week)

## Status Updates

*To be added during implementation*

