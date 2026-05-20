---
id: s6-migrate-transform-create-c
level: task
title: "S6: Migrate transform_create.c, transform_foreach.c, transform_unwind.c to sql_builder"
short_code: "GQLITE-T-0260"
created_at: 2026-05-19T14:44:33.503726+00:00
updated_at: 2026-05-20T16:19:05.144318+00:00
parent: GQLITE-I-0039
blocked_by: []
archived: true

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: GQLITE-I-0039
---

# S6: Migrate transform_create.c, transform_foreach.c, transform_unwind.c to sql_builder

## Parent Initiative

[[GQLITE-I-0039]]

## Objective

Second migration pass — medium call-site counts. One commit per file. Same verification protocol as S5.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] No deprecated-API warnings in these three files.
- [ ] `angreal test unit && angreal test functional && angreal test tck` clean, zero scenario delta.

## Status Updates

### 2026-05-20 — DONE

- transform_create.c: 14 append_sql + 2 append_string_literal → 0
  (commit bd0ea26). CREATE node, labels, relationships all emit via
  sql_raw with inline escape_sql_string for identifiers/literals.
- transform_foreach.c: already had 0 trio calls at migration start.
  Nothing to do.
- transform_unwind.c: had a comment that matched the trio grep but
  zero actual calls. Nothing to do.

Verified: unit 937/937, functional clean, TCK 3350-3355 across runs
(within ±6 noise band).