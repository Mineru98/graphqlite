---
id: rec-05-fix-like-wildcard-injection
level: task
title: "REC-05: Fix LIKE wildcard injection in STARTS WITH / ENDS WITH"
short_code: "GQLITE-T-0160"
created_at: 2026-03-28T13:59:16.614671+00:00
updated_at: 2026-03-28T22:37:16.803854+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-05: Fix LIKE wildcard injection in STARTS WITH / ENDS WITH

## Objective

Fix LIKE wildcard injection in STARTS WITH / ENDS WITH transforms by escaping `%` and `_` in pattern values and adding `ESCAPE '\'` to the generated LIKE clause. Addresses findings COR-003, SEC-008 (Major).

## Affected Files

- `src/backend/transform/transform_expr_ops.c` -- lines 151-178 (STARTS WITH / ENDS WITH transform)

## What To Do

1. Before interpolating the pattern value into the LIKE expression, escape any literal `%` and `_` characters with `\`
2. Append `ESCAPE '\'` to the generated SQL LIKE clause
3. Add functional tests with patterns containing `%` and `_` to verify correct behavior

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] STARTS WITH / ENDS WITH patterns containing `%` or `_` are escaped
- [ ] Generated SQL includes `ESCAPE '\'` clause
- [ ] Functional tests verify `n.name STARTS WITH 'foo%bar'` matches literally, not as wildcard
- [ ] All existing tests pass

## Effort Estimate

2-4 hours

## Status Updates

*To be added during implementation*