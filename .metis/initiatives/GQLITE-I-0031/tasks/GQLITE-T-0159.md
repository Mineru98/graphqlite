---
id: rec-04-add-hash-table-termination
level: task
title: "REC-04: Add hash table termination guard in CSR graph load"
short_code: "GQLITE-T-0159"
created_at: 2026-03-28T13:59:15.179129+00:00
updated_at: 2026-03-28T22:34:44.535861+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/active"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-04: Add hash table termination guard in CSR graph load

## Objective

Prevent infinite loop in the open-addressing hash table used by `csr_graph_load()` by adding a probe count guard and sizing the table dynamically. Addresses findings COR-007, SEC-013 (Critical).

## Affected Files

- `src/backend/graph/graph_algorithms.c` -- `csr_graph_load()` lines 93, 104-111

## What To Do

1. Replace the fixed `HASH_TABLE_SIZE` constant with `next_prime(node_count * 2)` to ensure load factor stays below 0.5
2. Add a probe counter to the open-addressing loop (lines 104-111); break and return error after `table_size` probes
3. Implement `next_prime()` helper if not already present

## Acceptance Criteria

## Acceptance Criteria

- [ ] Hash table size is computed dynamically based on node count
- [ ] Probe loop has a maximum iteration guard
- [ ] Existing graph algorithm tests pass
- [ ] No infinite loop possible regardless of input data

## Effort Estimate

2-4 hours

## Status Updates

*To be added during implementation*