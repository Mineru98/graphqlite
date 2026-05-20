---
id: s7-migrate-transform-match-c-to
level: task
title: "S7: Migrate transform_match.c to sql_builder (fixes var-length alias bugs + OPTIONAL MATCH joins, ~37 TCK)"
short_code: "GQLITE-T-0261"
created_at: 2026-05-19T14:44:46.455771+00:00
updated_at: 2026-05-19T14:44:46.455771+00:00
parent: GQLITE-I-0043
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0043
---

# S7: Migrate transform_match.c to sql_builder (fixes var-length alias bugs + OPTIONAL MATCH joins, ~37 TCK)

## Parent Initiative

[[GQLITE-I-0043]]

## Objective

Hot path. `transform_match.c` is where the variable-length pattern SQL alias collisions (`ambiguous column name: n_3.id`, `no such column: _gql_default_alias_2.id`) live, and where the OPTIONAL MATCH JOIN-ON construction loses bound-var context. Migrating to `sql_builder` forces the alias-management and JOIN-ON code to use the builder's clause sections, which automatically resolves both bug classes. Net TCK gain estimated ~37 scenarios.

## Acceptance Criteria

- [ ] No deprecated-API warnings in transform_match.c.
- [ ] Var-length pattern TCK scenarios that errored with "no such column" / "ambiguous column name" pre-migration now pass (Match4 [1]/[5]/[7]; Match5 [19]/[21]/[23]/[28]/[29]; Match6 [15]; Match9 [1]–[5]/[9]).
- [ ] OPTIONAL MATCH bound-var scenarios that returned wrong row counts pre-migration now pass (Match7 [3]/[4]/[8]/[9]/[14]/[15]/[19]).
- [ ] `angreal test unit && angreal test functional` clean.
- [ ] TCK delta strictly positive (no regressions).

## Status Updates

### 2026-05-20 — Blocked on GQLITE-I-0043

S7–S12 (this task and siblings) target files inside the expression
dispatch tree (transform_match.c → transform_match's WHERE inside
the MATCH, but more importantly the expression-tree appendages all
share the `ctx->sql_buffer` scratchpad with `transform_expression`).
Migrating one file at a time breaks the interleave because
transform_expression writes to sql_buffer via append_sql throughout.

Per **GQLITE-I-0043** (transform_expression to string-returning API),
the right path is to migrate `transform_expression` itself first,
then the per-file work becomes mechanical.

For transform_match.c specifically: the WHERE-on-MATCH paths already
use `sql_where(ctx->unified_builder, ...)` (sql_builder typed
section), so the "fix var-length alias bugs + OPTIONAL MATCH joins"
benefit claimed by the spec is partially realized already. The
remaining append_sql calls inside transform_match.c are in the
expression-tree scratchpad path that I-0043 will rewrite.

**This task stays todo until I-0043 lands** OR until someone confirms
which subset of transform_match.c can be safely migrated standalone
(likely small — most of the file is already sql_builder-shaped).
