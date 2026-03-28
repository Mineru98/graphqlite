---
id: rec-16-runtime-observability
level: task
title: "REC-16: Runtime observability callback and structured version function"
short_code: "GQLITE-T-0171"
created_at: 2026-03-28T13:59:41.882297+00:00
updated_at: 2026-03-28T13:59:41.882297+00:00
parent: GQLITE-I-0033
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0033
---

# REC-16: Runtime observability callback and structured version function

## Objective

Add runtime observability: callback-based logging, version introspection, EXPLAIN support for algorithms, and cleanup of debug artifacts. Addresses findings OPS-002, OPS-006, OPS-008, API-013 (Major).

## Affected Files

- `src/extension.c` -- register new `graphqlite_version()` function, logging callback API
- `src/backend/graph/` -- algorithm query functions (EXPLAIN support)
- Various files with `fflush(stdout)` and `CYPHER_DEBUG` conditionals

## What To Do

1. Add `graphqlite_log_func` callback API that replaces compile-time `CYPHER_DEBUG` `fprintf` calls
2. Register `graphqlite_version()` SQL function returning JSON: `{"version": "0.3.9", "schema_version": 1, "status": "ok"}`
3. Add EXPLAIN support for graph algorithm queries (return the generated SQL plan)
4. Remove unconditional `fflush(stdout)` calls scattered through the codebase

## Acceptance Criteria

- [ ] `graphqlite_log_func` callback can be registered and receives log messages
- [ ] `SELECT graphqlite_version()` returns valid JSON with version info
- [ ] EXPLAIN prefix on algorithm queries returns SQL plan
- [ ] No unconditional `fflush(stdout)` remains
- [ ] `CYPHER_DEBUG` compile flag still works but routes through callback
- [ ] All tests pass

## Effort Estimate

3-5 days

## Status Updates

*To be added during implementation*

