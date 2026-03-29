---
id: executor-outer-row-iteration-and
level: task
title: "Executor: outer-row iteration and inner query dispatch for CALL"
short_code: "GQLITE-T-0176"
created_at: 2026-03-29T01:05:15.428614+00:00
updated_at: 2026-03-29T01:05:15.428614+00:00
parent: GQLITE-I-0034
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0034
---

# Executor: outer-row iteration and inner query dispatch for CALL

## Parent Initiative

[[GQLITE-I-0034]]

## Objective

Add executor support for CALL subquery: detect the clause, iterate over outer-row results, and dispatch the inner subquery per row.

## Affected Files

- `src/include/executor/query_patterns.h`
- `src/backend/executor/query_dispatch.c`

## Implementation Notes

- Add `CLAUSE_CALL` flag to the clause bitmask in `query_patterns.h`
- Add detection of `AST_NODE_CALL_SUBQUERY` in `analyze_query_clauses()`
- Implement a pattern handler that iterates outer MATCH results and executes the inner subquery for each row, passing bound variable IDs
- Model the implementation on the existing `handle_merge_with_pipeline` pattern for variable passing between execution stages
- Handle both read (RETURN) and write (MERGE/SET/DELETE) inner subqueries

## Acceptance Criteria

- [ ] `MATCH (c) CALL { WITH c MERGE (c)-[:REL]->(d {name: 'x'}) }` executes correctly and creates the relationship
- [ ] Inner subquery receives correct variable bindings from each outer row
- [ ] Read-returning CALL subqueries propagate results to the outer query
- [ ] No double-free or leak on inner execution context teardown

## Effort Estimate

2-3 days

## Status Updates

*To be added during implementation*