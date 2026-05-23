---
id: cypher-language-surface-expansion
level: initiative
title: "Cypher Language Surface Expansion — LOAD CSV, PROFILE, EXISTS subquery, map projection, indexes"
short_code: "GQLITE-I-0045"
created_at: 2026-05-23T05:10:47.272684+00:00
updated_at: 2026-05-23T05:10:47.272684+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: false

tags:
  - "#initiative"
  - "#phase/discovery"


exit_criteria_met: false
estimated_complexity: XL
initiative_id: cypher-language-surface-expansion
---

# Cypher Language Surface Expansion

## Context

Where **GQLITE-I-0044** (TCK Conformance Push II) makes existing
Cypher constructs more correct, this initiative **adds language
constructs we don't support at all**. Each is its own feature
unlock with distinct semantics, AST, transform, and (often) executor
implications.

These tickets have been sitting in the backlog because each is a
multi-week effort and none was the highest-leverage TCK target.
Grouping them lets us plan a coherent feature-expansion cycle —
each ticket becomes a child task with its own design phase,
implementation, and TCK validation.

## Tickets in scope

| Ticket | Feature | Effort | Spec / use case |
|---|---|---|---|
| **T-0134** | `LOAD CSV` clause | L | Bulk import from CSV files into the graph. Parser already exists; transform + executor need to land. |
| **T-0135** | `PROFILE` query modifier | M | Returns execution plan + counters alongside results. Observability. |
| **T-0139** | Existential subquery `EXISTS { MATCH … WHERE … }` | L | Inline subquery predicate, distinct from `EXISTS(...)` function form. Modern Cypher. |
| **T-0136** | Map projection variable selector | M | Forms like `{.*, .foo, bar: expr}` for property forwarding. |
| **T-0008** | `CREATE INDEX` / `CREATE CONSTRAINT` | L | DDL for index hints and uniqueness constraints. Real engine surface. |
| **T-0125** | Label disjunction `n:Label1\|Label2` (currently blocked) | M | Pattern-level label-OR. Blocked on prerequisite cypher_ast/grammar choice. |

## Goals

- **G1**: Each feature ships as a coherent unit — parser, AST, transform,
  executor, and TCK tests land together. No half-implementations.
- **G2**: Per-feature acceptance: relevant TCK feature file(s) move
  from skip/error to pass; new functional tests assert the
  behaviour end-to-end.
- **G3**: Each feature gets a design pass BEFORE implementation
  starts. Cypher spec semantics are non-trivial — we need to know
  what we're committing to.
- **G4**: Features ship as separate releases (or paired with
  other work, but each is independently revertable).

## Non-Goals

- **NOT** chasing the entire Cypher language spec. Items not on
  this list (e.g. full `MERGE` ON CREATE/MATCH idempotency edges,
  full subquery support, `CALL { ... }` subqueries with WITH
  scope) stay out until product priorities call for them.
- **NOT** TCK conformance fixes for already-implemented features
  — those are I-0044's scope.
- **NOT** transform/executor architectural refactors — those
  are I-0033 (arch hardening) and I-0043 (transform_expression
  rewrite).

## Suggested sequencing

Some features have heavier blast radius than others; sequence by
risk/value.

### First — observability + low-blast-radius

- **T-0135 PROFILE**: doesn't change semantics of any existing
  query, just adds an introspection wrapper. Good first feature
  — proves the design-pass-then-implement cycle works.
- **T-0136 Map projection variable selector**: localized to the
  RETURN/WITH projection layer. Doesn't touch graph traversal.

### Second — query expressivity

- **T-0139 EXISTS subquery**: lets WHERE clauses contain inline
  pattern-match predicates. Touches transform_expr_predicate +
  needs careful scope rules. Significant.
- **T-0125 Label disjunction**: needs grammar updates (current
  blocker) + label-set evaluation. Smaller than T-0139.

### Third — data ingest + DDL

- **T-0134 LOAD CSV**: bulk import path. Already has partial
  scaffolding in transform_load_csv.c. Substantial executor
  work to handle file IO, type coercion, error rows.
- **T-0008 CREATE INDEX / CONSTRAINT**: DDL surface. Indexes
  become advisory (SQLite has its own indexer) but the syntax
  + the constraint side (NOT NULL, UNIQUE) need engine support.

## Decomposition approach

Each feature in this initiative gets:

1. A **design phase** task — output is an ADR or design doc
   under `.metis/specs/` or `docs/design/` describing the AST
   shape, transform strategy, executor changes, error model,
   TCK coverage plan, and migration impact.
2. One or more **implementation phase** tasks — parser, AST,
   transform, executor, tests. Often a single task per feature
   suffices; LOAD CSV and EXISTS subquery probably need 2-3.
3. A **landing phase** task — TCK validation + functional tests +
   documentation update.

For features already in the backlog with task tickets
(T-0008/0125/0134/0135/0136/0139), the existing ticket becomes
the design-phase task; implementation phases get filed under
it as needed.

## Acceptance Criteria

- [ ] Each in-scope feature ships at least to its acceptance
  criteria as defined in its ticket OR is explicitly deferred
  with a reason recorded.
- [ ] No regressions: TCK pass rate at the start of this
  initiative remains a floor.
- [ ] Each landed feature has end-to-end functional test
  coverage in `tests/functional/` and updates the
  semantic-coverage-matrix doc.

## Operational notes

- **Order is not strict.** A user can land T-0135 PROFILE
  before T-0136 map projection regardless of the suggested
  sequence above; the sequence is a recommendation based on
  blast radius, not a dependency chain.
- **Decomposition is human-driven.** Per Metis policy,
  initiatives don't auto-decompose. When ready to start
  feature X, file the design task + ping for review.
- **Parallel with I-0044.** This initiative runs alongside the
  TCK conformance push. They touch different code paths
  (TCK push fixes existing emission; this adds new emission)
  so PRs don't conflict.

## Status Updates

### 2026-05-23 — Created

Filed at v0.5.0 baseline. Discovery phase — gathering the
existing backlog tickets under one roof. Awaiting human review
before promoting individual features into design phase.
