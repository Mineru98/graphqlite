---
id: rec-08-migrate-graph-api-to
level: task
title: "REC-08: Migrate Graph API to parameterized queries (Python + Rust)"
short_code: "GQLITE-T-0163"
created_at: 2026-03-28T13:59:25.509553+00:00
updated_at: 2026-03-28T13:59:25.509553+00:00
parent: GQLITE-I-0032
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0032
---

# REC-08: Migrate Graph API to parameterized queries (Python + Rust)

## Objective

Eliminate SQL injection risk in the Python and Rust Graph API layers by replacing f-string / format-string SQL interpolation with parameterized queries. Addresses finding API-001 (Critical).

## Affected Files

- `python/graphqlite/graph/nodes.py` -- all query-building methods
- `python/graphqlite/graph/edges.py` -- all query-building methods
- `python/graphqlite/queries.py` -- query helpers
- Rust bindings (equivalent graph query methods)

## What To Do

1. Audit every SQL query in `nodes.py`, `edges.py`, and `queries.py` for f-string interpolation
2. Rewrite each to use `?` parameter placeholders with value tuples
3. Apply the same pattern to Rust binding query methods
4. Add tests with adversarial input (e.g., label names containing `'; DROP TABLE`)

## Acceptance Criteria

- [ ] No f-string or format-string SQL interpolation remains in Python graph API
- [ ] No format! SQL interpolation remains in Rust graph API
- [ ] All Python and Rust tests pass
- [ ] Injection test cases added and passing

## Effort Estimate

3-5 days

## Status Updates

*To be added during implementation*

