---
id: add-json-property-tables-and-prop
level: task
title: "Add JSON property tables and PROP_TYPE_JSON to schema layer"
short_code: "GQLITE-T-0102"
created_at: 2026-02-07T16:48:20.530169+00:00
updated_at: 2026-02-07T19:39:45.317694+00:00
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

# Add JSON property tables and PROP_TYPE_JSON to schema layer

## Parent Initiative

[[GQLITE-I-0030]] — Native JSON/Map/List Properties + Nested Access

## Objective

Add `PROP_TYPE_JSON` to the property type enum and create `node_props_json` / `edge_props_json` tables in the schema layer. Wire up the schema manager's set/get/delete property functions to handle JSON values. This is the foundation that all other tasks depend on.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] `PROP_TYPE_JSON` (value 4) added to `property_type` enum in `cypher_schema.h`
- [ ] DDL constants defined for `node_props_json` and `edge_props_json` tables
- [ ] Tables created with `json_valid(value)` CHECK constraint and composite PK `(node_id/edge_id, key_id)`
- [ ] Indexes created on `(key_id, value, node_id/edge_id)` matching existing property table pattern
- [ ] `cypher_schema_set_node_property()` handles `PROP_TYPE_JSON` — binds value as TEXT
- [ ] `cypher_schema_set_edge_property()` handles `PROP_TYPE_JSON` — binds value as TEXT
- [ ] Property delete/cleanup functions include the new JSON tables
- [ ] `cypher_schema_property_type_name()` returns `"JSON"` for `PROP_TYPE_JSON`
- [ ] `angreal test unit` passes — no regressions
- [ ] New CUnit tests verify JSON property round-trip (set + get)

## Implementation Notes

### Files to Modify

| File | Changes |
|------|---------|
| `src/include/executor/cypher_schema.h` | Add `PROP_TYPE_JSON = 4` to enum, add DDL/index string constants |
| `src/backend/executor/cypher_schema.c` | Add DDL execution in `create_tables()`, add `PROP_TYPE_JSON` cases to set/get/delete functions, add JSON tables to cleanup loops |

### Technical Approach

Follow the exact pattern used by the existing four property types. The JSON tables mirror `node_props_text` / `edge_props_text` structurally (TEXT value column) but add a `CHECK(json_valid(value))` constraint. The `set_*_property` functions bind the value as `sqlite3_bind_text()` for `PROP_TYPE_JSON`.

### Dependencies

None — this is the foundational task.

## Status Updates

### Session 1 — Implementation Complete

**Files modified:**
- `src/include/executor/cypher_schema.h` — Added `PROP_TYPE_JSON = 4` to enum, added 4 extern DDL/index constants
- `src/backend/executor/cypher_schema.c` — Added all changes:
  - DDL for `node_props_json` and `edge_props_json` with `CHECK(json_valid(value))`
  - Index constants (key_id + node_id/edge_id — no value in index since JSON can be large)
  - Table creation in `create_tables()`
  - Index creation in `create_indexes()`
  - `PROP_TYPE_JSON` case in `set_node_property()` and `set_edge_property()` — binds as TEXT
  - JSON tables added to cleanup loops in both set functions (5 tables instead of 4)
  - JSON tables added to delete functions for both nodes and edges
  - `property_type_name()` returns `"JSON"` for `PROP_TYPE_JSON`

**Test results:**
- `angreal build extension` — clean compile, no warnings
- `angreal test unit` — 770 tests, 0 failures
- `angreal test functional` — 0 failures, debug output confirms JSON tables created
- No regressions

**Design decision:** JSON indexes use `(key_id, node_id)` rather than `(key_id, value, node_id)` like other types. JSON values can be arbitrarily large, making value-based indexing impractical. Key-based lookup is sufficient for the COALESCE chain.