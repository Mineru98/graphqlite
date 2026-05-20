---
id: executor-finalize-sequencing
level: initiative
title: "Executor finalize-sequencing refactor — defer SQL serialization until all clauses transformed"
short_code: "GQLITE-I-0042"
created_at: 2026-05-20T14:19:21.169084+00:00
updated_at: 2026-05-20T14:19:21.169084+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: false

tags:
  - "#initiative"
  - "#phase/discovery"


exit_criteria_met: false
estimated_complexity: L
initiative_id: executor-finalize-sequencing
---

# Executor finalize-sequencing refactor

## Context

Discovered 2026-05-19/20 during the I-0039 sql_builder migration. The
per-clause executor handlers (`handle_match_set`, `handle_match_delete`,
`handle_match_remove`, `handle_match_create`, etc. in
`src/backend/executor/query_dispatch.c`) interleave **transform** and
**execute** at clause boundaries:

```
handle_match_set(query):
  1. transform_match_clause(ctx, match)         # populates unified_builder
  2. (transform_return_clause calls finalize    # only when RETURN present)
  3. transform_set_clause(ctx, set)             # writes DIRECTLY to ctx->sql_buffer via append_sql
  4. sqlite3_prepare_v2(ctx->sql_buffer, ...)   # executes the assembled SQL
```

This worked when both MATCH and SET wrote to `ctx->sql_buffer`. The
I-0039 migration moved DML emitters (set/delete/remove/create) to
`sql_raw → unified_builder->raw_output`. To keep the existing handlers
working, we added a "drain" step in `cypher_transform_query` /
`cypher_transform_generate_sql` that lifts `raw_output` into
`sql_buffer` before prepare. That works but leaves
`finalize_sql_generation` being called in TWO places:

1. Inside `transform_return_clause` (mid-flow, when RETURN is processed)
2. Effectively at the end via the new drain step

The sequencing assumes finalize-then-append-DML works. To get to the
final I-0039 target ("no `append_sql` left, all output through
`unified_builder`"), the executor must change the contract:

> **All clauses transform first → finalize ONCE → execute.**

Today's interleaving prevents this because some handlers prepare/execute
intermediate SQL between transform stages (notably the pre-SET MATCH
in `handle_match_set` and the per-row CALL outer-MATCH in
`handle_call_subquery`).

## Goals

- **G1**: Every `handle_*` function in `query_dispatch.c` (and its
  satellites `executor_call_subquery.c`, `executor_merge_pipeline.c`)
  follows the same contract: transform all clauses → finalize → prepare
  → execute. No interleaved transform/execute.
- **G2**: `finalize_sql_generation` becomes idempotent and is called
  once at the boundary between transform and execute. No transform
  function calls it internally (`transform_return_clause:483` and
  `transform_return_clause:674` become caller-side responsibility).
- **G3**: The `drain raw_output → sql_buffer` shim added during I-0039
  S5+S6 is removed. `unified_builder` becomes the sole assembly point;
  `sql_buffer` is filled exactly once by the finalize call.
- **G4**: Zero TCK regression. Current pass count is the floor.

## Non-Goals

- Migrating `transform_expression` and its dispatched function
  transforms (that's GQLITE-I-0043).
- Removing `ctx->sql_buffer` entirely (depends on I-0043).
- Changing `sql_builder`'s API.

## Detailed Design

### Current handler shape (problematic)

`handle_match_set` in `query_dispatch.c:696`:

```c
if (match_count > 1) {
    // multi-MATCH: binds via bind_match_clause_into_varmap (prepares
    // and executes intermediate SQL to capture node IDs!)
    rc = execute_set_operations(executor, set, ms_vars, result);
} else {
    rc = execute_match_set_query(executor, match, set, result);
}
// Then if RETURN: re-runs MATCH+RETURN.
```

`bind_match_clause_into_varmap` (in `executor_match.c:780`) does:
1. Create a fresh transform_context
2. transform_match_clause
3. finalize_sql_generation
4. sqlite3_prepare_v2 + step (reads node IDs back)
5. cypher_transform_free_context

So **each handler is already doing transform+execute per clause**. The
fix is to consolidate this into a single transform-all-then-execute
flow.

### Target handler shape

```c
int handle_match_set_v2(executor, query, result, flags) {
    cypher_transform_context *ctx = cypher_transform_create_context(db);
    transform_single_query_sql(ctx, query);   // all clauses → unified_builder
    finalize_sql_generation(ctx);             // ONCE
    prepend_cte_to_sql(ctx);

    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(db, ctx->sql_buffer, ...);
    // execute, collect counts
    sqlite3_finalize(stmt);
    cypher_transform_free_context(ctx);
    result->success = true;
    return 0;
}
```

The tricky part: handlers that need INTERMEDIATE result data (e.g.
`handle_match_set` for the C12 pre-SET var_map capture, or
`handle_match_delete` for synthesize_delete_return) need to keep their
intermediate prepare/step. Those become **two-pass** handlers:

```c
// Pass 1: transform MATCH alone, prepare, step, capture intermediate
// Pass 2: transform DML+RETURN against captured intermediate, finalize, execute
```

The two-pass pattern is acceptable because the intermediate result is
genuinely needed (you can't write MATCH+SET+RETURN as one SQL statement
that preserves the pre-SET node identity).

### Idempotent finalize

`finalize_sql_generation` currently:

```c
if (!ctx->in_union) {
    ctx->sql_size = 0;
    ctx->sql_buffer[0] = '\0';
}
char *assembled = sql_builder_to_string(ctx->unified_builder);
append_sql(ctx, "%s", assembled);
```

After being called once, `sql_builder_to_string` returns NULL on the
second call (because it consumes the typed dbufs). To make idempotent:

- Add a `b->finalized` check: if true, return 0 immediately.
- Reset the flag in `sql_builder_reset`.
- Callers that need to re-finalize after additional sql_select calls
  must explicitly reset.

### Caller-side finalize

Move the two `finalize_sql_generation(ctx)` calls in
`transform_return.c` (lines 483, 674) up to `transform_single_query_sql`
or `cypher_transform_query`. transform_return_clause becomes
purely-additive on unified_builder.

### Drain-shim removal

Once finalize is called at the boundary, the raw_output drain in
`cypher_transform_query:545` and `cypher_transform_generate_sql:710`
becomes unnecessary — `sql_builder_to_string` already includes
raw_output in its output.

## Alternatives Considered

- **Keep current interleaving; just make the drain robust.** Rejected
  — fragile shim, blocks I-0043, doesn't get us to "no append_sql".
- **Rewrite the executor entirely (one big handler).** Rejected — too
  much risk; the per-pattern dispatch already works well.
- **Per-handler refactor, no shared contract.** Rejected — drifts to
  N different sequencing models, hard to reason about.

## Implementation Plan

### Phase 1 — Make finalize idempotent

- **E1**: Add `b->finalized` short-circuit in `sql_builder_to_string`.
  Add reset behavior. Update unit tests for sql_builder.

### Phase 2 — Caller-side finalize

- **E2**: Move the two `finalize_sql_generation` calls from
  `transform_return.c` to `transform_single_query_sql` (end of clause
  loop). Verify TCK = 0.
- **E3**: Move the equivalent calls in `cypher_transform_query` to a
  single canonical location. Remove the drain shim.

### Phase 3 — Two-pass handlers

- **E4**: `handle_match_delete` — extract intermediate-MATCH step into
  a helper; consolidate transform-then-execute for the DELETE phase.
- **E5**: `handle_match_set` — same. The C12 pre-SET var_map capture
  becomes Pass 1 (MATCH-only), SET+RETURN becomes Pass 2.
- **E6**: `handle_match_remove` — same.
- **E7**: `handle_call_subquery` (executor_call_subquery.c) — already
  multi-pass; refactor to use the canonical two-pass helpers.
- **E8**: `handle_match_merge`, `handle_merge_with_pipeline` — same.

### Phase 4 — Verify and clean

- **E9**: Full TCK regression run. Compare baseline pass set
  byte-for-byte.
- **E10**: Audit `bind_match_clause_into_varmap` and similar helpers
  to see if their per-call transform context can be replaced with the
  caller's now-shared ctx.

## Exit Criteria

- [ ] `finalize_sql_generation` callable safely N times.
- [ ] No `finalize_sql_generation` calls inside `transform_*_clause`
      functions; only at the transform/execute boundary.
- [ ] No `raw_output` drain code in `cypher_transform_query` /
      `cypher_transform_generate_sql`.
- [ ] Every `handle_match_*` function follows: transform-all →
      finalize-once → execute (possibly in two passes for
      intermediate-data needs).
- [ ] TCK pass count ≥ baseline at initiative start.
- [ ] `angreal test unit && angreal test functional` clean.

## Operational Notes

- This initiative is the prerequisite for **GQLITE-I-0043**
  (transform_expression rewrite). Without idempotent finalize and
  caller-side sequencing, the expression API rewrite has no clean
  contract to land against.
- Two-pass handlers will add a small per-query overhead (one extra
  transform_context create/free). Acceptable — these are write paths,
  not read-hot.
- The C12 pre-SET var_map capture (GQLITE-T-0297) currently lives in
  a deferred state because the existing single-pass `bind_match_clause`
  helper can't carry the intermediate state through to RETURN
  projection. This initiative fixes that by making the two-pass
  pattern canonical.
- Estimated total effort: **3–5 days**. Largest risk: handlers with
  subtle interleavings (e.g. handle_call_subquery, handle_merge_with_pipeline).