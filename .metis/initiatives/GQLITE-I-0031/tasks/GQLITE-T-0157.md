---
id: rec-02-fix-integer-overflow-and
level: task
title: "REC-02: Fix integer overflow and unchecked realloc in result serialization"
short_code: "GQLITE-T-0157"
created_at: 2026-03-28T13:59:12.520341+00:00
updated_at: 2026-03-28T13:59:12.520341+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-02: Fix integer overflow and unchecked realloc in result serialization

## Objective

Fix integer overflow risk and unchecked realloc in the result serialization path. Addresses findings COR-001, COR-002, SEC-005, SEC-006 (all Critical).

## Affected Files

- `src/extension.c` -- `graphqlite_cypher_func()` lines 157-170, 233-243: `buffer_size` declared as `int`
- `src/bundled_init.c` -- same pattern duplicated
- `src/backend/executor/cypher_executor.c` -- lines 301-304: `realloc` result assigned directly without temp pointer check

## What To Do

1. Change `buffer_size` from `int` to `size_t` in `graphqlite_cypher_func()` in both `extension.c` and `bundled_init.c`
2. In `cypher_executor.c:301-304`, store `realloc()` result in a temp pointer; only assign to the real pointer on success; on failure, free original and return error
3. Audit for any other `realloc` calls in the codebase that follow the same unsafe pattern

## Acceptance Criteria

- [ ] `buffer_size` is `size_t` in both `extension.c` and `bundled_init.c`
- [ ] All `realloc` calls use temp pointer pattern (no direct assignment)
- [ ] No new compiler warnings with `-Wall -Wextra`
- [ ] All unit and functional tests pass

## Effort Estimate

2 days

## Status Updates

*To be added during implementation*