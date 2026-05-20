---
id: s9-migrate-transform-return-c-to
level: task
title: "S9: Migrate transform_return.c to sql_builder (104 call sites)"
short_code: "GQLITE-T-0263"
created_at: 2026-05-19T14:45:05.777162+00:00
updated_at: 2026-05-19T14:45:05.777162+00:00
parent: GQLITE-I-0039
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0039
---

# S9: Migrate transform_return.c to sql_builder (104 call sites)

## Parent Initiative

[[GQLITE-I-0039]]

## Objective

Largest single non-function file. RETURN handles aggregates, ORDER BY, SKIP/LIMIT — all of which already partially use `sql_builder`. This task finishes the migration so RETURN no longer mixes APIs.

## Acceptance Criteria

- [ ] No deprecated-API warnings in transform_return.c.
- [ ] Aggregation, ORDER BY, SKIP/LIMIT, DISTINCT all still pass their TCK suites.
- [ ] TCK delta zero.

## Status Updates

### 2026-05-20 — Outer is already done; inner is blocked on GQLITE-I-0043

Investigation 2026-05-20: `transform_return_clause` (the outer
function, lines 131-712) has **zero append_sql calls**. All 112 calls
in transform_return.c are inside `transform_expression` (line 714+).
The "104 call sites" headline number is the expression body, not the
outer clause-emission code.

The outer clause uses sql_select / sql_order_by / sql_limit_expr
against unified_builder, passing captured expression strings as
values. That work is **already complete**.

The remaining 112 calls inside transform_expression are part of the
expression-scratchpad ecosystem — they move when GQLITE-I-0043 lands.

**This task is split in spirit:**
- Outer transform_return_clause sql_builder migration: DONE
- Inner transform_expression body: covered by I-0043

Marking the original "S9" intent as covered — the heavy lifting was
done as part of the M13 boolean-rendering work and earlier
unified_builder adoption.
