---
id: call-subquery-support-opencypher
level: initiative
title: "CALL {} Subquery Support (openCypher)"
short_code: "GQLITE-I-0034"
created_at: 2026-03-29T00:59:41.386138+00:00
updated_at: 2026-03-29T01:05:03.564912+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: false

tags:
  - "#initiative"
  - "#phase/decompose"


exit_criteria_met: false
estimated_complexity: L
initiative_id: call-subquery-support-opencypher
---

# CALL {} Subquery Support (openCypher) Initiative

**GitHub Issue**: #40
**openCypher Spec**: Sections 3 (Subqueries) and 6.5 (CALL subquery)

## Context

`CALL { ... }` subqueries are a core openCypher feature that allows executing inner queries with access to outer scope variables via `WITH`. This is the primary mechanism for:
- Batch ingestion with multiple relationship types per record
- Conditional relationship creation (UNION branches)
- Correlated subqueries that return aggregates

The `CALL` keyword already exists as a reserved keyword in the grammar but has no production rules. No AST node, transform, or executor support exists.

## Goals

- Parse `CALL { <subquery> }` syntax including `WITH` variable import
- Parse `CALL { <subquery> UNION <subquery> }` with UNION branches
- Transform subqueries to SQL (likely as CTEs or correlated subqueries)
- Execute subqueries with outer variable binding

## Non-Goals

- `CALL <procedure>` (stored procedures) — different feature
- `COUNT { }` and `COLLECT { }` subquery expressions — separate, simpler follow-on
- `EXISTS { }` — already tracked as GQLITE-T-0139

## Architecture

### Layers Affected

1. **Grammar** (`cypher_gram.y`): Add `CALL '{' query_list '}'` production rule in the `clause` rule
2. **AST** (`cypher_ast.h/c`): Add `AST_NODE_CALL_SUBQUERY` with `clauses` list and optional `UNION` branches
3. **Transform** (`cypher_transform.c`): Handle `AST_NODE_CALL_SUBQUERY` — likely generate a CTE per branch, with outer variables passed via column references
4. **Executor** (`query_dispatch.c`): Add `CLAUSE_CALL` handling in the pattern matcher; dispatch subquery branches

### SQL Generation Strategy

```cypher
MATCH (c:Company {id: 'acme'})
CALL {
    WITH c
    MATCH (d:Department {id: 'eng'})
    MERGE (c)-[:HAS_DEPT]->(d)
}
```

Could translate to:
```sql
-- CTE for outer MATCH
WITH _outer AS (SELECT c.id AS c_id FROM nodes c ...)
-- Execute subquery for each outer row
-- This requires either:
-- (a) A loop in the executor (row-by-row subquery execution)
-- (b) A correlated CTE pattern
-- (c) A LATERAL join (not supported in SQLite)
```

The most practical approach is **(a) executor-level iteration**: the transform layer generates SQL for the inner query with placeholders for outer variables, and the executor iterates over outer rows, binding variables and executing the inner query per row.

## Tasks (to be created during decompose)

| # | Task | Layer | Effort |
|---|------|-------|--------|
| 1 | Grammar rules for CALL { } with UNION | Parser | 1-2 days |
| 2 | AST node for CALL subquery | Parser | 0.5 days |
| 3 | Transform: generate inner SQL from subquery | Transform | 2-3 days |
| 4 | Executor: iterate outer rows, execute inner query per row | Executor | 2-3 days |
| 5 | WITH variable import in subquery scope | Transform+Executor | 1-2 days |
| 6 | UNION branch support inside CALL | All layers | 1-2 days |
| 7 | Integration tests + openCypher compliance tests | Testing | 1 day |

## Dependencies

- Grammar conflict resolution: adding CALL to the clause list may introduce new S/R conflicts with the GLR parser. Current `%expect 9` may need updating.
- The MERGE+WITH pipeline handler (from #36 fix) provides a pattern for executor-level clause chaining that this feature can build on.