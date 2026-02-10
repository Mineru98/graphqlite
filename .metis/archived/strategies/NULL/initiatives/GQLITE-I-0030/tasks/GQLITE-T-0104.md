---
id: route-map-list-literals-to-json
level: task
title: "Route map/list literals to JSON storage in SET and CREATE paths"
short_code: "GQLITE-T-0104"
created_at: 2026-02-07T16:48:23.312954+00:00
updated_at: 2026-02-07T19:39:46.005224+00:00
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

# Route map/list literals to JSON storage in SET and CREATE paths

## Parent Initiative

[[GQLITE-I-0030]] — Native JSON/Map/List Properties + Nested Access

## Objective

When a user writes `SET n.metadata = {name: 'x', labels: {a: 'b'}}` or `CREATE (n:Node {tags: [1, 2, 3]})`, detect the map/list literal value and store it as `PROP_TYPE_JSON` instead of defaulting to TEXT. This requires changes in both the transform layer (SQL generation targets the JSON table) and the executor layer (AST map/list serialization to JSON strings).

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] `SET n.prop = {key: 'val'}` generates SQL targeting `node_props_json` instead of `node_props_text`
- [ ] `SET n.prop = [1, 2, 3]` generates SQL targeting `node_props_json`
- [ ] `CREATE (n:Node {metadata: {name: 'x'}})` stores `metadata` in `node_props_json`
- [ ] `CREATE (n:Node {tags: [1, 2, 3]})` stores `tags` in `node_props_json`
- [ ] Nested maps work: `{name: 'x', labels: {a: 'b'}}` stores as valid JSON `{"name":"x","labels":{"a":"b"}}`
- [ ] Edge properties also route to JSON: `SET r.config = {timeout: 30}`
- [ ] Scalar properties continue to use their existing typed tables (no regression)
- [ ] `angreal test unit` and `angreal test functional` pass

## Implementation Notes

### Files to Modify

| File | Changes |
|------|---------|
| `src/backend/transform/transform_set.c` | In `generate_property_update()`, detect `AST_NODE_MAP` and `AST_NODE_LIST` value expressions, target `node_props_json`/`edge_props_json` |
| `src/backend/executor/executor_set.c` | In `execute_set_operations()`, serialize AST map/list to JSON string using `json_builder`, call `cypher_schema_set_*_property()` with `PROP_TYPE_JSON` |
| `src/backend/executor/executor_create.c` | In property handling during node/edge creation, detect map/list values and store as `PROP_TYPE_JSON` |

### Technical Approach

**Transform layer:** `generate_property_update()` currently checks `value_expr->type == AST_NODE_LITERAL` and switches on literal type. Add checks for `AST_NODE_MAP` and `AST_NODE_LIST` before the literal check. When detected, set `prop_table = "node_props_json"` (or `edge_props_json`). The value expression is already transformed to `json_object(...)` or `json_array(...)` by `transform_expression()` in `transform_return.c`, so the INSERT value will be valid JSON.

**Executor layer:** For the direct executor path (non-transform), use the existing `json_builder` (`src/backend/executor/json_builder.c`) to serialize AST map/list nodes to JSON strings recursively. Handle nested maps, mixed types, and list-of-maps.

### Dependencies

Depends on GQLITE-T-0102 (JSON tables must exist).

## Status Updates

### Session 1 — Implementation Complete

**Core helper function** — `executor_helpers.c`:
- Added `serialize_ast_to_json(ast_node *expr)` — recursively serializes AST_NODE_MAP/LIST to JSON strings
- Uses `json_builder` for safe string building with proper JSON escaping
- Handles nested maps, lists, and all literal types (string, int, real, bool, null)
- Declared in `executor_internal.h` for cross-module use
- Fixed `get_param_value()` to return `PROP_TYPE_JSON` (was `PROP_TYPE_TEXT`) for array/object JSON parameters

**Executor CREATE** — `executor_create.c`:
- Source node properties: added MAP/LIST detection before LITERAL case, serializes and stores as PROP_TYPE_JSON
- Target node properties: same pattern
- Edge properties: same pattern  
- All 3 param handling blocks also updated with PROP_TYPE_JSON case

**Executor SET** — `executor_set.c`:
- Added MAP/LIST handling before PARAMETER case in `execute_set_operations()`
- Handles both node and edge SET with proper error reporting
- JSON string is freed after use via `continue` to skip the generic set path
- Parameter handling also updated with PROP_TYPE_JSON case

**Transform SET** — `transform_set.c`:
- Added `is_json` flag in `generate_property_update()` for AST_NODE_MAP/LIST detection
- Routes to `node_props_json` table (transform layer only handles nodes for SET)
- Value expression is already converted to `json_object()`/`json_array()` by `transform_expression()`

**Test results:** 770/770 unit tests pass, all functional tests pass (0 failures)