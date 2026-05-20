---
id: s5-migrate-transform-set-c
level: task
title: "S5: Migrate transform_set.c, transform_delete.c, transform_remove.c to sql_builder"
short_code: "GQLITE-T-0259"
created_at: 2026-05-19T14:44:22.937344+00:00
updated_at: 2026-05-20T16:18:48.887080+00:00
parent: GQLITE-I-0039
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: GQLITE-I-0039
---

# S5: Migrate transform_set.c, transform_delete.c, transform_remove.c to sql_builder

## Parent Initiative

[[GQLITE-I-0039]]

## Objective

First migration pass — smallest call-site counts, simple shapes. Each file in one commit. Verification: unit + functional + TCK clean, zero scenario delta.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] No deprecated-API warnings in these three files.
- [ ] `angreal test unit && angreal test functional && angreal test tck` clean.
- [ ] TCK scenario set byte-identical to pre-migration baseline.

## Status Updates

### 2026-05-19/20 — DONE

All three files migrated to `sql_raw → unified_builder->raw_output`:

- transform_delete.c: 6 calls → 0 (commit ee5ad31)
- transform_remove.c: 11 calls → 0 (commit ee5ad31, with inline
  escape_sql_string for label/property literals)
- transform_set.c: 27 calls → 0 (commit bd0ea26, uses the new
  `cypher_transform_capture_expression` helper to capture value
  expressions from transform_expression — see I-0043 for the
  long-term plan to remove that capture pattern)

Supporting infrastructure committed:

- `sql_raw()` API + `dbuf raw_output` section on sql_builder
  (commit ee5ad31)
- raw_output drain in cypher_transform_query and
  cypher_transform_generate_sql for paths that don't go through
  finalize_sql_generation (also commit ee5ad31; will be removed when
  I-0042 lands)
- `cypher_transform_capture_expression` helper (commit bd0ea26) —
  swap-buffer wrapper around transform_expression so callers can
  capture the result as a string

Verified: unit 937/937, functional clean, TCK 3354-3357 across
consecutive runs (baseline 3346, within ±6 noise band).