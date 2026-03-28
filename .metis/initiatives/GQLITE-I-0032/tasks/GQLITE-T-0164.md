---
id: rec-10-single-pass-result
level: task
title: "REC-10: Single-pass result enumeration and O(n) JSON serialization"
short_code: "GQLITE-T-0164"
created_at: 2026-03-28T13:59:26.821059+00:00
updated_at: 2026-03-28T13:59:26.821059+00:00
parent: GQLITE-I-0032
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0032
---

# REC-10: Single-pass result enumeration and O(n) JSON serialization

## Objective

Replace count-then-read double pass in `build_query_results()` with single-pass incremental realloc, and replace O(n^2) `strcat` JSON assembly with offset-based `snprintf`. Addresses findings PERF-001, PERF-002 (Major).

**Depends on**: GQLITE-T-0157 (REC-02) for `buffer_size` type change to `size_t`.

## Affected Files

- `src/backend/executor/executor_match.c` -- `build_query_results()` lines 270-284
- `src/extension.c` -- `graphqlite_cypher_func()` JSON string concatenation

## What To Do

1. In `build_query_results()`, remove the initial count query; instead, start with an estimated allocation and grow with incremental `realloc` as rows are read
2. In `graphqlite_cypher_func()`, replace `strcat` loop with an `offset` variable and `snprintf(buf + offset, remaining, ...)` pattern
3. Benchmark before/after with a query returning 1000+ rows

## Acceptance Criteria

- [ ] `build_query_results()` uses single-pass row reading with incremental realloc
- [ ] JSON assembly uses offset-based writes instead of `strcat`
- [ ] All unit and functional tests pass
- [ ] No performance regression on small result sets

## Effort Estimate

1-2 days

## Status Updates

*To be added during implementation*

