---
id: cypher-spec-coverage-audit
level: specification
title: "Cypher Spec Coverage Audit Procedure"
short_code: "GQLITE-S-0001"
created_at: 2026-03-17T13:43:43.791929+00:00
updated_at: 2026-03-17T13:43:43.791929+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: false

tags:
  - "#specification"
  - "#phase/discovery"


exit_criteria_met: false
initiative_id: NULL
---

# Cypher Spec Coverage Audit Procedure

## Overview

Repeatable procedure for auditing GraphQLite's Cypher language coverage against the openCypher specification. Produces a coverage matrix showing what's implemented, what's partial, and what's missing — then generates Metis backlog tasks for the gaps.

Run this audit after major feature work, before releases, or when the upstream spec changes.

## Procedure

### Step 1: Pick a Cypher feature from the openCypher spec

**Sources:**
- openCypher spec: https://opencypher.org/ and https://github.com/opencypher/openCypher
- Neo4j Cypher manual: https://neo4j.com/docs/cypher-manual/current/
- Neo4j cheat sheet: https://neo4j.com/docs/cypher-cheat-sheet/

Pick a specific clause, function, operator, or syntax construct from the spec.

### Step 2: Check if GraphQLite supports it

Test the feature directly:

1. **Parser**: Does `cypher('...')` parse without error?
2. **Transform**: Does it generate correct SQL and return results?
3. **Edge cases**: Does it handle nulls, empty inputs, type mismatches?

Use `angreal test functional` or ad-hoc `sqlite3 :memory:` queries against the built extension.

### Step 3: If there's a gap, create a Metis task

Create a single backlog task (`backlog_category: feature`) that:

- Names the specific spec feature(s) missing
- Describes expected behavior per the openCypher spec
- Includes example Cypher that should work but doesn't
- Groups tightly related features (e.g., all temporal construction functions = 1 task, not 15)

**Priority guide:**
- **P1**: Features users encounter in every tutorial (`RETURN *`, basic functions)
- **P2**: Standard spec compliance (temporal, spatial, statistical aggregates)
- **P3**: Niche/advanced (hyperbolic trig, normalize, PROFILE)

### Step 4: Implement and verify

Ralph the task. After implementation, re-test the feature from Step 2 to confirm the gap is closed.

## Scope Decisions

### In Scope (openCypher core)
- All reading/writing clauses
- All operators and expressions
- All standard functions (scalar, aggregate, string, math, list, path)
- Temporal types and functions
- Spatial types and functions
- CALL subqueries
- LOAD CSV

### Out of Scope (Neo4j-specific / admin)
- Database/user/role management (CREATE DATABASE, CREATE USER, GRANT, etc.)
- Transaction management (SHOW TRANSACTIONS, TERMINATE)
- Index/constraint DDL (handled by SQLite internally)
- Stored procedures (CALL db.procedure YIELD)
- Vector functions (Neo4j 2025+ only)
- Graph type management (Cypher 25)

### Deferred (Cypher 25 bleeding-edge)
- FINISH, USE, LET, NEXT clauses
- IS NORMALIZED / IS NOT NORMALIZED
- `||` concatenation operator (vs `+`)
- Quantified path patterns (`{m,n}`, `+`, `*`)
- SHORTEST k / ANY path modes
- IS :: type predicates
- `$($expression)` dynamic parameters
- Extended CASE with IS TYPED

## When to Run

- **Before each minor release** (0.x.0) — full audit
- **After implementing a coverage task** — update the matrix checkboxes
- **When openCypher publishes a new spec version** — refresh the checklist
- **On downstream consumer feedback** — cross-reference complaints against the matrix

## Changelog

| Date | Change | Rationale |
|------|--------|-----------|
| 2026-03-17 | Initial audit completed | First systematic coverage analysis, 71% core coverage |