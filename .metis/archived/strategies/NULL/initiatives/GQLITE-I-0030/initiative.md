---
id: native-json-map-list-properties
level: initiative
title: "Native JSON/Map/List Properties + Nested Access"
short_code: "GQLITE-I-0030"
created_at: 2026-02-07T16:44:57.884397+00:00
updated_at: 2026-02-07T19:40:19.028043+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: true

tags:
  - "#initiative"
  - "#phase/completed"


exit_criteria_met: false
estimated_complexity: XL
strategy_id: NULL
initiative_id: native-json-map-list-properties
---

# Native JSON/Map/List Properties + Nested Access Initiative

**GitHub Issue**: [#14](https://github.com/colliery-io/graphqlite/issues/14)
**Promoted from**: GQLITE-T-0097

## Context

GraphQLite currently stores properties as scalar values in typed EAV tables (`node_props_text`, `node_props_int`, `node_props_real`, `node_props_bool`). Users cannot store structured data (maps, lists) as property values — they must manually serialize to JSON strings and handle extraction themselves. This is a major gap vs Memgraph/Neo4j where map and list literals are first-class property values.

Recent work on dialect parity (GQLITE-T-0096) added nested dot access and bracket chaining for *reading* JSON-valued text properties. This initiative extends that to full write support and a dedicated JSON storage layer.

## Goals & Non-Goals

**Goals:**
- Store map and list literals as native JSON properties via `SET` and `CREATE`
- Read nested values with dot access (`n.metadata.name`) and bracket access (`n.metadata['key']`)
- Add dedicated `node_props_json` / `edge_props_json` tables with `json_valid()` constraints
- Provide `json_get()` and related helper functions as explicit fallbacks
- Ensure comparison and `IN` operators work on nested JSON scalar values

**Non-Goals:**
- SET/REMOVE of nested JSON paths (`SET n.metadata.name = 'foo'`) — requires JSON path updates, much more complex
- JSON Schema validation beyond `json_valid()`
- Full JSONPath query support
- Performance optimization (expression indexes on JSON columns) — future work

## Detailed Design

### Architecture Overview

Add a fifth property table pair (`node_props_json` / `edge_props_json`) that stores values as JSON TEXT with a `json_valid()` CHECK constraint. Leverages SQLite JSON1 (built into vendored 3.47.2). Property access COALESCE chains gain a new JSON arm. Nested access uses `json_extract()`.

### Key Design Decisions

1. **Dedicated JSON tables** rather than overloading `_text` — avoids ambiguity in COALESCE chains and enables future JSON-specific indexing
2. **Read-only nested access** — writing nested paths is out of scope (too complex for initial implementation)
3. **Leverage existing dialect parity work** — nested dot access grammar and `json_extract` transform from commit `210a895` provide the read path foundation

### Layer-by-Layer Changes

| Layer | What Changes |
|-------|-------------|
| **Schema** | New `node_props_json`/`edge_props_json` tables, `PROP_TYPE_JSON` enum value |
| **Parser** | Verify existing nested dot/bracket grammar handles all cases (may already be done) |
| **Transform** | Add JSON table to property COALESCE chains, nested access via `json_extract()` |
| **Executor SET/CREATE** | Detect map/list AST nodes, serialize to JSON, store as `PROP_TYPE_JSON` |
| **Functions** | Register `json_get()`, `json_keys()`, `json_type()` as Cypher functions |
| **Operators** | Verify `IN` and comparison operators work on `json_extract()` output |

## Alternatives Considered

1. **Store JSON in `_text` tables** — Rejected: ambiguity between JSON strings and regular text strings in COALESCE lookups; no clean way to distinguish
2. **Single JSONB column on nodes/edges table** — Rejected: breaks EAV pattern, would require migrating all property access
3. **Client-side JSON handling only** — Rejected: poor UX, forces manual serialization, no nested access

## Implementation Plan

Six phases, each independently testable:

1. **GQLITE-T-0102** — Schema layer: `PROP_TYPE_JSON`, DDL for `node_props_json`/`edge_props_json`, property set/get functions
2. **GQLITE-T-0103** — Transform layer: JSON arm in COALESCE chains, `json_extract()` for nested access
3. **GQLITE-T-0104** — Executor layer: Route map/list literals to JSON storage in SET and CREATE paths
4. **GQLITE-T-0105** — JSON helper functions: `json_get()`, `json_keys()`, `json_type()` function dispatch
5. **GQLITE-T-0106** — End-to-end functional tests for JSON property storage and nested access

**Note:** Parser verification (originally phase 2) was dropped — codebase exploration confirmed that nested dot/bracket grammar is already fully implemented from the dialect parity work (commit `210a895`).

### Dependency chain

```
T-0102 (schema) ──┬──> T-0103 (transform COALESCE) ──> T-0105 (json functions)
                   └──> T-0104 (SET/CREATE routing)
                                                    all ──> T-0106 (e2e tests)
```