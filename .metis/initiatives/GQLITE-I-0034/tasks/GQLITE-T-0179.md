---
id: call-subquery-integration-tests
level: task
title: "CALL subquery integration tests and openCypher compliance"
short_code: "GQLITE-T-0179"
created_at: 2026-03-29T01:05:18.723369+00:00
updated_at: 2026-03-29T01:05:18.723369+00:00
parent: GQLITE-I-0034
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0034
---

# CALL subquery integration tests and openCypher compliance

## Parent Initiative

[[GQLITE-I-0034]]

## Objective

Build comprehensive integration tests for CALL subquery covering basic usage, WITH import, UNION branches, nested CALL, error cases, and binding tests.

## Affected Files

- `tests/functional/` (new SQL-based functional tests)
- `bindings/python/tests/` (Python binding tests)
- `bindings/rust/tests/` (Rust binding tests)

## Implementation Notes

- Functional SQL tests should cover:
  - Basic `CALL { MATCH (n) RETURN n }`
  - WITH import: `MATCH (a) CALL { WITH a SET a.x = 1 }`
  - UNION branches: `CALL { query1 UNION query2 }`
  - Nested CALL: `CALL { CALL { ... } }`
  - Write operations inside CALL (MERGE, CREATE, SET, DELETE)
- Error case tests:
  - `CALL` without braces (parse error)
  - Empty `CALL { }` (parse error or empty result)
  - Referencing outer variable not imported via WITH (scope error)
  - UNION column name mismatch
- Python and Rust binding tests should verify CALL works through the extension API
- Verify behavior against openCypher spec sections 3 and 6.5

## Acceptance Criteria

- [ ] Functional tests cover all CALL variants listed above
- [ ] Error cases produce clear, correct error messages
- [ ] Python binding tests pass for CALL subquery
- [ ] Rust binding tests pass for CALL subquery
- [ ] All existing tests continue to pass (no regressions)

## Effort Estimate

1 day

## Status Updates

*To be added during implementation*