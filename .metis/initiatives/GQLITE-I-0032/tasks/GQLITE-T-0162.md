---
id: rec-07-scale-guards-for-node
level: task
title: "REC-07: Scale guards for node similarity and dynamic hash table sizing"
short_code: "GQLITE-T-0162"
created_at: 2026-03-28T13:59:24.132761+00:00
updated_at: 2026-03-28T22:55:19.446959+00:00
parent: GQLITE-I-0032
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/active"


exit_criteria_met: false
initiative_id: GQLITE-I-0032
---

# REC-07: Scale guards for node similarity and dynamic hash table sizing

## Objective

Add scale guards to prevent O(N^2) memory blowup in graph similarity and replace fixed hash table size with dynamic sizing. Addresses findings PERF-007, SEC-014, PERF-005.

## Affected Files

- `src/backend/graph/graph_algo_similarity.c` -- line 206 (O(N^2) allocation)
- `src/backend/graph/graph_algorithms.c` -- line 93 (`HASH_TABLE_SIZE` constant)

## What To Do

1. Add a hard limit check (5000 nodes) before the O(N^2) allocation in `graph_algo_similarity.c:206`; return a clear error if exceeded
2. Replace the `HASH_TABLE_SIZE` compile-time constant with `next_prime(node_count * 2)` in `graph_algorithms.c:93`
3. Share the `next_prime()` helper with GQLITE-T-0159 if implemented there first

## Acceptance Criteria

## Acceptance Criteria

- [ ] Similarity functions reject graphs exceeding 5000 nodes with a descriptive error
- [ ] Hash table size is dynamically computed from node count
- [ ] Existing graph algorithm tests pass
- [ ] No memory issues under normal workloads

## Effort Estimate

4-8 hours

## Status Updates

*To be added during implementation*