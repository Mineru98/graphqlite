---
id: delete-return-ordering-type-r
level: task
title: "DELETE+RETURN ordering: type(r) returns NULL after DELETE r"
short_code: "GQLITE-T-0321"
created_at: 2026-05-23T05:15:00.000000+00:00
updated_at: 2026-05-23T05:15:00.000000+00:00
parent:
blocked_by: []
archived: false

tags:
  - "#task"
  - "#bug"
  - "#phase/backlog"


exit_criteria_met: false
initiative_id: NULL
---

# DELETE+RETURN ordering: type(r) returns NULL after DELETE r

## Discovered

2026-05-22 during v0.5.0 work. Observed while triaging Return2 [14].

## Repro

```cypher
CREATE ()-[:T]->();
MATCH ()-[r]->()
DELETE r
RETURN type(r);
```

**Expected:** 1 row with `type(r) = 'T'`.
**Actual:** 0 rows (or row with NULL — currently 0 rows).

## Root cause

DELETE runs before RETURN captures the projection. By the time
`type(r)` is evaluated, `r` has been removed and the type lookup
returns NULL/empty.

Per Cypher spec, DELETE+RETURN should capture the projection
values BEFORE the delete is committed. The "snapshot what's about
to be deleted" semantics. Other Cypher impls (Neo4j) keep a frozen
copy of the bindings across the DELETE.

## Proposed fix

Two options:

1. **Snapshot projection BEFORE delete**: in `executor_delete.c` /
   `query_dispatch.c` for `MATCH+DELETE+RETURN` patterns, evaluate
   the RETURN projection using the pre-delete variable_map, then
   apply DELETE, then yield the cached projection rows.
2. **Delay delete to post-projection**: alternative ordering —
   project first, delete after. Same end state. Either works.

Implementation likely lives in the `handle_match_delete_return`
(or similar) dispatch handler. Current path probably calls
delete then projects from the post-delete var_map.

## Affected scenarios

- Return2 [14] "Do not fail when returning type of deleted relationships"
- Likely Return2 [15]/[16]/[17] family (deleted node properties/labels)
- May affect similar `MATCH … DELETE r RETURN r.prop` patterns.

## Acceptance Criteria

- [ ] Return2 [14] passes.
- [ ] `MATCH (n) DELETE n RETURN n.name` returns the pre-delete name.
- [ ] Functional regression test in `tests/functional/`.
- [ ] No regression on existing DELETE tests.

## Affected files

- `src/backend/executor/query_dispatch.c` — dispatch handler.
- `src/backend/executor/executor_delete.c` — DELETE execution.
- `src/backend/executor/executor_result_project.c` — projection.

## Notes

Sibling of T-0253 (DeletedEntityAccess runtime error) — that one
is about ERRORING when accessing a deleted entity. This one is
about CORRECTLY accessing a SOON-to-be-deleted entity in the
same query's RETURN.
