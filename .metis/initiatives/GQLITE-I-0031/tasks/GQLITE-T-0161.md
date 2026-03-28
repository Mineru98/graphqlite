---
id: rec-06-make-create-return-silent
level: task
title: "REC-06: Make CREATE...RETURN silent discard an explicit error"
short_code: "GQLITE-T-0161"
created_at: 2026-03-28T13:59:18.040583+00:00
updated_at: 2026-03-28T13:59:18.040583+00:00
parent: GQLITE-I-0031
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0031
---

# REC-06: Make CREATE...RETURN silent discard an explicit error

## Objective

Make `CREATE...RETURN` produce an explicit error instead of silently succeeding with no output. Addresses findings COR-005 (Major), API-002 (Critical).

## Affected Files

- `src/backend/executor/query_dispatch.c` -- clause validation / forbidden mask logic

## What To Do

1. Add `CLAUSE_RETURN` to the forbidden clause mask for the CREATE execution path in `query_dispatch.c`
2. Return a specific, descriptive error message (e.g., "RETURN clause is not supported with CREATE")
3. Add functional tests confirming `CREATE (n:Foo {name:'bar'}) RETURN n` returns an error

## Acceptance Criteria

- [ ] `CREATE...RETURN` queries return an explicit error message
- [ ] `CREATE` without RETURN still works correctly
- [ ] Functional test added for `CREATE...RETURN` error case
- [ ] All existing tests pass

## Effort Estimate

2-4 hours

## Status Updates

*To be added during implementation*

