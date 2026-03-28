---
id: rec-03-check-function-registration
level: task
title: "REC-03: Check function registration return values in extension init"
short_code: "GQLITE-T-0158"
created_at: 2026-03-28T13:59:13.846973+00:00
updated_at: 2026-03-28T22:33:16.659802+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/active"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-03: Check function registration return values in extension init

## Objective

Check return value of every `sqlite3_create_function()` call in `sqlite3_graphqlite_init()` and handle failures by freeing `connection_cache` and returning an error. Addresses findings OPS-001, COR-009 (Critical).

## Affected Files

- `src/extension.c` -- `sqlite3_graphqlite_init()` lines 611-641
- `src/bundled_init.c` -- same init function duplicated

## What To Do

1. Wrap each `sqlite3_create_function()` call with an `if (rc != SQLITE_OK)` check
2. On failure: free `connection_cache`, return `rc` (propagating the SQLite error)
3. Apply identical fix to `bundled_init.c`

## Acceptance Criteria

## Acceptance Criteria

- [ ] Every `sqlite3_create_function` call in both files has its return value checked
- [ ] On failure, `connection_cache` is freed and error code is returned
- [ ] All unit and functional tests pass

## Effort Estimate

2-4 hours

## Status Updates

*To be added during implementation*