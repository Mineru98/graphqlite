---
id: with-scope-shadowing-where-after
level: task
title: "WITH scope shadowing: WHERE after WITH should see both pre- and post-WITH names"
short_code: "GQLITE-T-0324"
created_at: 2026-05-23T05:18:00.000000+00:00
updated_at: 2026-05-23T05:18:00.000000+00:00
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

# WITH scope: WHERE-after-WITH should see both scopes

## Discovered

2026-05-22 during v0.5.0 work. Observed while triaging
WithWhere7 [3].

## Repro

```cypher
CREATE ({name2: 'A'}), ({name2: 'B'}), ({name2: 'C'});

MATCH (a)
WITH a.name2 AS name
WHERE name = 'B' OR a.name2 = 'C'
RETURN *;
```

**Expected:** 2 rows — name='B' and name='C'. (The WHERE attached
to a WITH clause sees BOTH the WITH's output scope AND the
pre-WITH scope for the inner pattern of `a`.)
**Actual:** error `Unknown variable in property access: a`. Our
transform treats `a` as out-of-scope after WITH and rejects it.

## Cypher spec note

Per the Cypher language reference, the WHERE that follows a WITH
clause is evaluated with access to BOTH the pre-WITH variables
AND the post-WITH names. This is a small but real spec carve-out
— specifically for WITH's filter, not for clauses after the
WITH boundary. After WITH, downstream clauses only see WITH's
output names.

Our implementation models the strict post-WITH scope rule for
ALL of WITH (including its own WHERE), which is too strict.

## Proposed fix

In `transform_with.c`:

1. When processing the WHERE attached to a WITH, push the
   pre-WITH variable context onto the var_ctx so identifier
   resolution sees both scopes.
2. Pop the pre-WITH scope before downstream clauses run, so
   subsequent MATCH/RETURN/SET only see the WITH output.

This is a localized scope-window inside the WITH-WHERE handler.

## Affected scenarios

- WithWhere7 [3] "WHERE sees both, variable bound before but
  not after WITH and variable bound after but not before WITH".
- Possibly other WithWhere scenarios with similar shapes.

## Acceptance Criteria

- [ ] WithWhere7 [3] passes.
- [ ] WHERE-after-WITH can reference both pre- and post-WITH
  names.
- [ ] WITH's downstream MATCH/RETURN does NOT see pre-WITH
  names (preserve strict scope there).
- [ ] No regression on existing WITH tests.

## Affected files

- `src/backend/transform/transform_with.c`
- `src/backend/transform/transform_variables.c` (if a scope
  push/pop helper needs to be added).

## Notes

Subtle scope rule. Worth a small ADR or design note to
document the precise scope-window so future readers don't
re-impose the strict-post-WITH rule by accident.

Estimated effort: M.
