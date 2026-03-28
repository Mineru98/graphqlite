---
id: rec-17-api-consistency-fixes
level: task
title: "REC-17: API consistency fixes across Python and Rust bindings"
short_code: "GQLITE-T-0172"
created_at: 2026-03-28T13:59:42.956995+00:00
updated_at: 2026-03-28T13:59:42.956995+00:00
parent: GQLITE-I-0033
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0033
---

# REC-17: API consistency fixes across Python and Rust bindings

## Objective

Normalize API inconsistencies across Rust, Python, and SQLite layers. Addresses findings API-003, API-005, API-006, API-007, API-008, API-010 (Major/Minor).

## Affected Files

- **Rust**: `rust/src/` -- `get_all_edges()`, `get_all_nodes()` return types; `CacheStatus` string
- **Python**: `python/graphqlite/` -- duplicate `_find_extension()`, algorithm name mapping, `node_data` naming
- **SQLite**: `src/extension.c` -- function registration

## What To Do

### Rust
1. Normalize `get_all_edges()` / `get_all_nodes()` to return consistent types (both should return `Vec<T>` or equivalent)
2. Replace `CacheStatus` string with a proper enum

### Python
3. Delete the duplicate `_find_extension()` function (keep one canonical version)
4. Add algorithm name mapping documentation
5. Rename `node_data` parameter/field to `props` for consistency

### SQLite
6. Register `gql_` prefixed aliases (`gql_query`, `gql_validate`) alongside existing `cypher()` and `cypher_validate()`

## Acceptance Criteria

- [ ] Rust return types are consistent across node/edge query methods
- [ ] `CacheStatus` is an enum, not a string
- [ ] Single `_find_extension()` in Python codebase
- [ ] `node_data` renamed to `props` in Python API
- [ ] `gql_query()` and `gql_validate()` registered as SQL function aliases
- [ ] All tests pass across all three layers

## Effort Estimate

2-4 days

## Status Updates

*To be added during implementation*

