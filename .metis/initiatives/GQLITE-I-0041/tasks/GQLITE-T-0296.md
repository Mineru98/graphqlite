---
id: c11-repeat-variant-collapse-for
level: task
title: "C11: Repeat variant collapse for execute_match_* (8 variants → canonical set)"
short_code: "GQLITE-T-0296"
created_at: 2026-05-19T14:49:38.711488+00:00
updated_at: 2026-05-20T16:19:32.691578+00:00
parent: GQLITE-I-0041
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: GQLITE-I-0041
---

# C11: Repeat variant collapse for execute_match_* (8 variants → canonical set)

## Parent Initiative

[[GQLITE-I-0041]]

## Objective

Same exercise as C8–C10 but for the 8 MATCH variants. Canonical signature pattern mirrors merge (single function with optional input/output var_map). This is the prerequisite for C12.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] Canonical `execute_match_*` function set defined (likely one for read-only MATCH, one for MATCH-into-varmap).
- [ ] Every caller migrated.
- [ ] Old variants deleted.
- [ ] `bind_match_clause_into_varmap` supports ALL MATCH shapes including relationship-only patterns (currently a known gap).
- [ ] Build green, TCK delta zero.

## Status Updates

### 2026-05-19 — partial; spec assumption revisited

**Partial collapse landed (commit 076652d):**
`execute_multi_match_create_query` / `_with_varmap` (2 variants) →
single canonical `execute_multi_match_create_query(executor, query,
create, result, **out_var_map)` with NULL-passable out. Decl + body
updated in executor_match.c; caller in query_dispatch.c migrated.

**Spec finding — the broader 8-variant claim doesn't hold:**

Inspected the actual `execute_match_*` family in
`src/include/executor/executor_internal.h`:

- `execute_match_clause` — basic 3-arg
- `execute_match_return_query` — adds `cypher_return *`
- `execute_match_create_query` — adds `cypher_create *`
- `execute_match_create_return_query` — adds both
- `execute_match_set_query` — adds `cypher_set *`
- `execute_match_delete_query` — adds `cypher_delete *`
- `execute_match_merge_query` — adds `cypher_merge *`
- `execute_match_remove_query` — adds `cypher_remove *`

These are **per-clause-combination handlers, NOT signature variants
of the same logical operation**. Each takes a different downstream
clause argument and runs different SQL. Collapsing them into one
"canonical" signature would either:
- require a tagged-union argument (worse for type safety), or
- require a generic `ast_list *post_match_clauses` (worse for
  callers that want to assert on clause type).

Conclusion: the initiative's "8 variants → canonical" framing
applied only to the `_with_varmap` pair (which IS just a signature
variant — out_var_map vs not). The rest are intentional API
surface and should stay.

**What this means for C12:** C12's prerequisite "C11 (canonical
execute_match_*) completed" needs reinterpretation. The actual
prerequisite is for `bind_match_clause_into_varmap` to handle every
MATCH shape — that's an internal-helper improvement, not a public
variant collapse. The C12 task description already calls this out
(relationship-only patterns missing); the fix needs to live there,
not here.

### Recommended status

This task is effectively **done for the variant case (multi_match_create)**
and **rejected for the broader 8-variant case (they're not variants)**.
Worth marking completed with this finding in the status. The
`bind_match_clause_into_varmap` extension lives in C12 (T-0297).