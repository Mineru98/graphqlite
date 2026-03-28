---
id: rec-15-normalize-dual-result-type
level: task
title: "REC-15: Normalize dual result type to single representation"
short_code: "GQLITE-T-0170"
created_at: 2026-03-28T13:59:40.511775+00:00
updated_at: 2026-03-28T13:59:40.511775+00:00
parent: GQLITE-I-0033
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0033
---

# REC-15: Normalize dual result type to single representation

## Objective

Normalize the dual result serialization paths (AGType vs legacy `data`) into a single representation with a backward-compatible shim. Addresses findings EVO-02, LEG-002 (Major).

**Depends on**: GQLITE-T-0168 (REC-09, consolidate extension files) and GQLITE-T-0169 (REC-14, transform globals).

## Affected Files

- `src/extension.c` -- `graphqlite_cypher_func()` result serialization
- New: extracted `cypher_result_to_json()` function

## What To Do

1. Extract result serialization logic from `graphqlite_cypher_func()` into a standalone `cypher_result_to_json()` function
2. Normalize toward AGType path as the single canonical representation
3. Make the legacy `data` path a thin shim that calls `cypher_result_to_json()` and reformats if needed
4. Add tests verifying both output formats still work

## Acceptance Criteria

- [ ] `cypher_result_to_json()` is a standalone, testable function
- [ ] AGType is the canonical internal representation
- [ ] Legacy `data` format still works via shim
- [ ] All existing tests pass with both result formats

## Effort Estimate

1 week

## Status Updates

*To be added during implementation*

