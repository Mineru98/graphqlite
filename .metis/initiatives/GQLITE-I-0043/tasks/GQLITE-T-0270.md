---
id: s16-define-transform-output-sub
level: task
title: "S16: Define transform_output sub-struct; move unified_builder into it"
short_code: "GQLITE-T-0270"
created_at: 2026-05-19T14:45:57.146381+00:00
updated_at: 2026-05-19T14:45:57.146381+00:00
parent: GQLITE-I-0043
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0043
---

# S16: Define transform_output sub-struct; move unified_builder into it

## Parent Initiative

[[GQLITE-I-0043]]

## Objective

Introduce `typedef struct { sql_builder *builder; ... } transform_output;` and replace `cypher_transform_context.unified_builder` with `transform_output *output`. All callers shift from `ctx->unified_builder` to `ctx->output->builder`.

## Acceptance Criteria

- [ ] `transform_output` struct defined and used as the canonical handle.
- [ ] `cypher_transform_context` no longer exposes `unified_builder` as a top-level field.
- [ ] All callers updated.
- [ ] TCK delta zero.

## Status Updates

### 2026-05-20 — Blocked on GQLITE-I-0043

This task wants to extract the output-related fields from
cypher_transform_context into a `transform_output` sub-struct. The
fields involved are `unified_builder` (immediate target) plus
`sql_buffer` / `sql_size` / `sql_capacity` (legacy buffer that
I-0043 deletes).

Cleanest order:
1. GQLITE-I-0043 deletes ctx->sql_buffer/size/capacity entirely
2. Then this task moves unified_builder into a sub-struct (or just
   renames it — at that point the context only has the one output
   field, no need for a sub-struct)

In other words: if I-0043 lands cleanly, this task may become a
trivial rename or be archived as unnecessary cleanup. Worth
revisiting after I-0043.
