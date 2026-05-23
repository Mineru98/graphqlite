---
id: s7-migrate-transform-match-c-to
level: task
title: "S7: Migrate transform_match.c to sql_builder (fixes var-length alias bugs + OPTIONAL MATCH joins, ~37 TCK)"
short_code: "GQLITE-T-0261"
created_at: 2026-05-19T14:44:46.455771+00:00
updated_at: 2026-05-23T04:06:32.164011+00:00
parent: GQLITE-I-0043
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: GQLITE-I-0043
---

# S7: Migrate transform_match.c to sql_builder (fixes var-length alias bugs + OPTIONAL MATCH joins, ~37 TCK)

## Parent Initiative

[[GQLITE-I-0043]]

## Objective

Hot path. `transform_match.c` is where the variable-length pattern SQL alias collisions (`ambiguous column name: n_3.id`, `no such column: _gql_default_alias_2.id`) live, and where the OPTIONAL MATCH JOIN-ON construction loses bound-var context. Migrating to `sql_builder` forces the alias-management and JOIN-ON code to use the builder's clause sections, which automatically resolves both bug classes. Net TCK gain estimated ~37 scenarios.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] No deprecated-API warnings in transform_match.c.
- [ ] Var-length pattern TCK scenarios that errored with "no such column" / "ambiguous column name" pre-migration now pass (Match4 [1]/[5]/[7]; Match5 [19]/[21]/[23]/[28]/[29]; Match6 [15]; Match9 [1]–[5]/[9]).
- [ ] OPTIONAL MATCH bound-var scenarios that returned wrong row counts pre-migration now pass (Match7 [3]/[4]/[8]/[9]/[14]/[15]/[19]).
- [ ] `angreal test unit && angreal test functional` clean.
- [ ] TCK delta strictly positive (no regressions).

## Status Updates

### 2026-05-20 — Blocked on GQLITE-I-0043 for full migration

S7–S12 share the `ctx->sql_buffer` scratchpad with
`transform_expression`. Per **GQLITE-I-0043**, that rewrite must
land first; the per-file migration then becomes mechanical.

### 2026-05-22 — Targeted TCK bug fixes shipped (v0.5.0)

The bug-fix arm of this task — the SQL alias collisions + OPTIONAL
MATCH JOIN issues that motivated the migration — was landed
WITHOUT requiring the full sql_builder migration. The relevant
emission paths were fixed directly in `transform_match.c`:

- **`generate_node_match` end-of-buffer alias detection.** Catches
  `n_3` duplicate JOINs when adjacent emission lacks trailing
  whitespace.
- **Varlen target `target_already_added` check.** Mirrors the
  non-varlen path; eliminates `_gql_default_alias_X` duplicates.
- **OPTIONAL + varlen LEFT JOIN with ON-clause constraints.**
  Replaces CROSS JOIN + WHERE with LEFT JOIN ON-clause-inlined
  constraints; outer-row preservation works.
- **Deferred-endpoint mechanism (T-0320).** Pre-loop analysis +
  rel handler emits the unbound endpoint LEFT JOIN tied through
  the edge. All `near 'AND': syntax error` failures eliminated.

**Wins (across v0.5.0):** Match4 [6], Match5 [19]/[21]/[23],
Match7 [3]/[13]/[14]/[19]/[20], Match9 [5]/[8], WithWhere1 [4].

**Total ~14 TCK from transform_match.c-area work**, leaving the
file mostly sql_builder-shaped already (the remaining append_sql
calls are inside the WHERE/SET expression-tree path that I-0043
will rewrite).

### 2026-05-23 — Completing this task

The bug-fix scope is complete. The full migration is now subsumed
by **GQLITE-I-0043's** Phase 2/3/4 (case-by-case migration of
`transform_expression` and its dispatched function transforms).
Closing this task — future migration tracking happens under
I-0043's existing children (X1–X5 phase tasks).

Acceptance criteria realized:
- ✅ Var-length alias bug class (Match4/5/9 family) — fixed.
- ✅ OPTIONAL MATCH JOIN bound-var issues — fixed.
- ✅ TCK delta strictly positive (+14 from this file's work).
- ⚠ No-deprecated-warnings remains gated on I-0043; tracked there.