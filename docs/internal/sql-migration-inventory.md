# SQL Generation API Migration Inventory (I-0039 S1–S3)

Snapshot taken at the start of the I-0039 migration (2026-05-19). Goal:
collapse the three coexisting SQL-output APIs in
`src/backend/transform/` into one (`sql_builder`).

## S1 — `append_sql` family call sites

Total: **977** calls across the legacy trio
(`append_sql` / `append_identifier` / `append_string_literal`).

Per file (highest first):

| File                                 | Calls |
| ------------------------------------ | ----: |
| `transform_func_temporal.c`          |   283 |
| `transform_expr_ops.c`               |   167 |
| `transform_return.c`                 |   112 |
| `transform_func_math.c`              |    56 |
| `transform_expr_predicate.c`         |    48 |
| `transform_func_string.c`            |    40 |
| `transform_func_aggregate.c`         |    40 |
| `transform_func_list.c`              |    38 |
| `transform_func_geo.c`               |    38 |
| `transform_func_typeconv.c`          |    28 |
| `transform_set.c`                    |    27 |
| `transform_func_entity.c`            |    20 |
| `transform_create.c`                 |    16 |
| `transform_func_path.c`              |    15 |
| `transform_func_json.c`              |    14 |
| `transform_remove.c`                 |    11 |
| `cypher_transform.c`                 |    11 |
| `transform_func_graph.c`             |     7 |
| `transform_delete.c`                 |     6 |

Notes:
- `transform_func_temporal.c` dominates because of the EMIT/EMIT_TIME_BASE
  macros expanded across the truncate/duration code paths. The macros
  internally call `append_sql`. Migration must keep the macro abstraction
  or inline the SQL emission.
- The five small files (`transform_set`, `transform_delete`,
  `transform_remove`, `transform_create`, `transform_func_graph`,
  `transform_delete`) total ~73 calls — natural first migration batch
  (S5–S6 of the initiative).

## S2 — `pending_prop_joins` writes & invariants

Three writers, three readers, one CTE-prepend invariant.

**Writers / readers** (file:line):

- `transform_return.c:55`  — `add_pending_prop_join()` impl
- `transform_return.c:45`  — `get_pending_prop_joins()` impl
- `transform_return.c:50`  — `get_pending_prop_joins_len()` impl
- `transform_return.c:37`  — `reset_pending_prop_joins()` impl
- `transform_return.c:{136,479}` — resets after consuming
- `transform_func_aggregate.c:200` — `add_pending_prop_join(ctx, …)`
- `transform_with.c:{215,486,488,491}` — read + reset across WITH boundary

**Prepend invariant**: `prepend_cte_to_sql(ctx)` runs at end of
transformation and splices the accumulated pending joins as CTEs onto
the front of the SQL buffer. Defined in `cypher_transform.c:280`.
Called from:

- `cypher_transform.c:{401,539,732,744}` (main transform entry points)
- `executor_match.c:121`
- `executor_call_subquery.c:187`
- `executor_merge_pipeline.c:83`

**Invariant**: pending joins emitted by `add_pending_prop_join` must
appear as CTE statements at the front of the final SQL; the rest of
the query (SELECT/FROM/WHERE) references them by alias. The order of
adds is preserved; duplicates are not deduplicated (callers are
expected not to add duplicates).

## S3 — Capability gap analysis

`sql_builder` already exposes the API needed to cover the legacy trio:

| Legacy shape                              | sql_builder API                                     | Status |
| ----------------------------------------- | --------------------------------------------------- | ------ |
| `append_sql(ctx, "SELECT %s …", expr)`    | `sql_select(b, expr, alias)`                        | ✓      |
| `append_sql(ctx, "FROM %s %s", t, a)`     | `sql_from(b, table, alias)`                         | ✓      |
| `append_sql(ctx, "WHERE %s", cond)`       | `sql_where(b, cond)`                                | ✓      |
| `append_sql(ctx, " AND %s", more_cond)`   | `sql_where(b, cond)` (appends with AND)             | ✓      |
| `append_sql(ctx, "LEFT JOIN … ON …")`     | `sql_join(b, SQL_JOIN_LEFT, t, a, on)` /            | ✓      |
|                                           | `sql_join_raw(b, raw)`                              |        |
| `append_sql(ctx, "GROUP BY %s", expr)`    | `sql_group_by(b, expr)`                             | ✓      |
| `append_sql(ctx, "ORDER BY %s%s", e, d)`  | `sql_order_by(b, expr, desc)`                       | ✓      |
| `append_sql(ctx, "LIMIT %d OFFSET %d")`   | `sql_limit(b, lim, off)` / `sql_limit_expr(...)`    | ✓      |
| `append_identifier(ctx, name)`            | identifiers folded into other API surfaces; for     | partial|
|                                           | raw appends use `dbuf_appendf(&b->scratch, …)`      |        |
| `append_string_literal(ctx, value)`       | `escape_sql_string(value)` returns malloc'd literal;| ✓      |
|                                           | feed into existing setters                          |        |
| `append_sql(ctx, "WITH cte AS (…)")`      | `sql_cte(b, name, query, recursive)`                | ✓      |
| `add_pending_prop_join(ctx, sql)`         | **GAP** — needs `sql_builder` CTE-prepend section   | gap    |
|                                           | (see S13 of I-0039)                                 |        |
| INSERT/UPDATE/DELETE shapes               | `write_builder_*` API in sql_builder.{c,h}          | ✓      |

**Remaining gaps:** only the pending_prop_joins CTE-prepend. Adding a
typed CTE-prepend section to `sql_builder` (S13) closes the last gap;
all 977 trio calls can otherwise migrate to existing `sql_builder`
APIs.

**The macro abstraction in transform_func_temporal.c (EMIT,
EMIT_TIME_BASE, EMIT_HH/MM/SS)** is currently `append_sql`-based.
During migration these macros should be rewritten to call into
`sql_builder`'s SQL accumulator (`dbuf_appendf(&b->select, …)` or
equivalent typed setter), or replaced with helper inline functions
that accept a `sql_builder *`.

## S4 — Deprecation status

`append_sql`, `append_identifier`, `append_string_literal` are marked
`__attribute__((deprecated))` in `src/include/transform/cypher_transform.h`
as of the I-0039 S4 commit. New code attempting to use them generates
a compile-time warning; existing call sites warn but continue to
compile so the per-file migration (S5–S12) can be done incrementally
without breaking the build.

## Migration order (recap from I-0039)

1. **S5** — `transform_set.c`, `transform_delete.c`, `transform_remove.c`
   (44 calls combined — smallest batch)
2. **S6** — `transform_create.c`, `transform_foreach.c`,
   `transform_unwind.c` (16 + foreach + unwind)
3. **S7** — `transform_match.c` (high call count, hot path; also fixes
   varlen alias + OPTIONAL MATCH bugs per the initiative spec, ~37 TCK)
4. **S8** — `transform_with.c`
5. **S9** — `transform_return.c` (112 calls)
6. **S10** — `transform_expr_ops.c` (167 calls),
   `transform_expr_predicate.c` (48 calls)
7. **S11** — `transform_func_string/math/path/entity/aggregate/graph.c`
   (~180 calls combined)
8. **S12** — `transform_func_temporal.c` (283 calls — largest single
   file; the EMIT macro family needs `sql_builder`-aware variants),
   `transform_func_list/geo/json/typeconv.c` (~118 calls).

Each migration commit must show zero TCK scenario delta and clean
unit + functional runs.
