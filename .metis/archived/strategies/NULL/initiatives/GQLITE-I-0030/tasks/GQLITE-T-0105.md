---
id: register-json-get-json-keys-json
level: task
title: "Register json_get, json_keys, json_type as Cypher helper functions"
short_code: "GQLITE-T-0105"
created_at: 2026-02-07T16:48:24.623940+00:00
updated_at: 2026-02-07T19:39:46.793751+00:00
parent: GQLITE-I-0030
blocked_by: []
archived: true

tags:
  - "#task"
  - "#phase/completed"


exit_criteria_met: false
strategy_id: NULL
initiative_id: GQLITE-I-0030
---

# Register json_get, json_keys, json_type as Cypher helper functions

## Parent Initiative

[[GQLITE-I-0030]] — Native JSON/Map/List Properties + Nested Access

## Objective

Register `json_get()`, `json_keys()`, and `json_type()` as Cypher-callable functions in the function dispatch table. These provide explicit fallback access to JSON operations when dot/bracket syntax is insufficient or when users want to inspect JSON structure.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] `json_get(n.metadata, 'name')` returns the value at the given key (translates to `json_extract(expr, '$.key')`)
- [ ] `json_get(n.metadata, '$.nested.path')` passes through paths starting with `$` directly
- [ ] `json_keys(n.metadata)` returns the keys of a JSON object (translates to SQLite `json_group_array()` over `json_each()`)
- [ ] `json_type(n.metadata)` returns the JSON type as a string (translates to SQLite `json_type()`)
- [ ] Functions registered in `transform_func_dispatch.c` dispatch table
- [ ] Arity validation: `json_get` requires 2 args, `json_keys` and `json_type` require 1 arg
- [ ] `angreal test unit` and `angreal test functional` pass

## Implementation Notes

### Files to Modify

| File | Changes |
|------|---------|
| `src/backend/transform/transform_func_dispatch.c` | Add 3 entries to `dispatch_table[]` array |
| `src/backend/transform/transform_func_dispatch.c` (or new file) | Implement `transform_json_get_function()`, `transform_json_keys_function()`, `transform_json_type_function()` |
| `src/include/transform/transform_functions.h` | Add declarations for the 3 new handlers |

### Technical Approach

These are thin wrappers around SQLite JSON1 functions:

- `json_get(expr, path)` → `json_extract(<transformed_expr>, '$.' || path)` or `json_extract(<transformed_expr>, path)` if path starts with `$`
- `json_keys(expr)` → could use `(SELECT json_group_array(key) FROM json_each(<transformed_expr>))` or just `json_each` directly
- `json_type(expr)` → `json_type(<transformed_expr>)`

Follow the existing function handler pattern (e.g., `transform_type_function`, `transform_keys_function`) — each takes a `transform_context *ctx` and argument list, validates arity, transforms arguments, and emits SQL.

### Dependencies

Depends on GQLITE-T-0103 (property access must include JSON arm so `n.metadata` resolves correctly as a function argument).

## Status Updates

### Session 1 — Implementation Complete

**Function implementations** — `transform_func_list.c`:
- `transform_json_get_function()` — `json_get(expr, path)` → `json_extract(expr, '$.path')`
  - String literal paths starting with `$` are passed through directly
  - Simple key names get `$.` prepended
  - Non-literal paths use `'$.' || path` string concatenation
- `transform_json_keys_function()` — `json_keys(expr)` → `(SELECT json_group_array(key) FROM json_each(expr))`
- `transform_json_type_function()` — `json_type(expr)` → `json_type(expr)`

All three validate arity and use `transform_expression()` for argument transformation.

**Header declarations** — `transform_functions.h`:
- Added declarations in new "JSON functions" section

**Dispatch table** — `transform_func_dispatch.c`:
- Registered both snake_case and camelCase variants:
  - `json_get` / `jsonGet` → `transform_json_get_function`
  - `json_keys` / `jsonKeys` → `transform_json_keys_function`
  - `json_type` / `jsonType` → `transform_json_type_function`

**Test results:** 770/770 unit tests pass, all functional tests pass (0 failures)