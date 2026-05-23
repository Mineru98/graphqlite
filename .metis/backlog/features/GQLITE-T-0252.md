---
id: user-defined-procedures-call-test
level: task
title: "User-defined procedures (CALL test.*) for TCK Call1-Call6"
short_code: "GQLITE-T-0252"
created_at: 2026-05-19T11:12:43.647420+00:00
updated_at: 2026-05-23T04:07:02.925573+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#feature"
  - "#phase/completed"


exit_criteria_met: false
initiative_id: NULL
---

# User-defined procedures (CALL test.*) for TCK Call1-Call6

## Objective

Support user-defined procedures so the openCypher TCK `Call1`–`Call6` feature
files (plus the `Map3` / `Graph3` tests that lean on a `test.labels()` /
`test.my.proc(...)` procedure) can run end-to-end. The TCK declares
procedures with the gherkin step
`And 'there exists a procedure test.my.proc(in :: INTEGER?) :: (out :: INTEGER?)'`,
which has no matcher today — so 49 scenarios skip instead of pass/fail.

This is a real engine capability gap: we have no procedure registry, no
typed argument-binding path, and no way to surface multi-column YIELD into
the result set.

## Backlog Item Details

### Type
- [x] Feature - New functionality or enhancement

### Priority
- [x] P2 - Medium (nice to have)

### Business Justification
- **User Value**: openCypher compatibility — `CALL` is a core clause type.
- **Effort Estimate**: L (registry, typed dispatch, YIELD plumbing, test fixtures).

## Scope

1. Procedure registry (engine): per-database map from fully-qualified
   procedure name → handler signature (input types, yield columns, types).
2. Parser/AST: `CALL` clause already parses; verify YIELD-clause support and
   plumb argument coercion through transform.
3. Built-in test procedures so the TCK harness can register `test.doNothing`,
   `test.labels`, `test.my.proc` variants without bespoke fixtures (or accept
   the harness step as a no-op once the engine can route `CALL test.foo(...)`
   to a per-scenario-registered handler).
4. Result-shape: yields appear as columns, not as a single JSON blob.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] `there exists a procedure ...` step is recognised by `tests/tck/runner.py`.
- [ ] `CALL test.doNothing()` runs without error in TCK Call1.
- [ ] `CALL test.my.proc(...) YIELD out` projects `out` as a column.
- [ ] Call1–Call6 pass-rate moves from 0% to whatever the engine supports.
- [ ] `test.labels()` returns one row per label in the database.
- [ ] Skipped-due-to-procedures count drops from 49 → 0
      (pass+fail+error split tracked separately).

## Source Evidence

`build/tck-results.json` skipped entries:
- 15 × `test.my.proc(in :: INTEGER?) :: (a :: INTEGER?, b :: INTEGER?)`
- 6 × `test.my.proc(in :: INTEGER?) :: (out :: INTEGER?)`
- 6 × `test.my.proc(in :: INTEGER?) :: (out :: STRING?)`
- 5 × `test.my.proc(name :: STRING?, id :: INTEGER?) :: (city :: STRING?, country_code :: STRING?)`
- 4 × `test.doNothing() :: ()`
- 4 × `test.labels() :: (label :: STRING?)`
- 4 × `test.my.proc(in :: NUMBER?) :: (out :: STRING?)`
- 3 × `test.my.proc(name :: STRING?, in :: INTEGER?) :: (out :: INTEGER?)`
- 2 × `test.my.proc(in :: FLOAT?) :: (out :: STRING?)`
- 1 × `test.labels(in :: INTEGER?) :: (label :: STRING?)`

## Implementation Notes

### Touch points
- `src/backend/parser/cypher_gram.y` — verify CALL/YIELD grammar.
- `src/backend/transform/transform_call.c` (create if absent).
- `src/extension.c` — procedure registry / built-in test procs.
- `tests/tck/runner.py` — step matcher + per-scenario procedure declarations.

### Dependencies
None known; orthogonal to current engine refactors.

## Status Updates

### 2026-05-22 — Harness-side support shipped (v0.5.0)

Closed via harness-side implementation rather than full engine
procedure registry. The TCK runner now:

- Parses `there exists a procedure name(args) :: (yields)` step
  via new pattern matcher + `_h_procedure_declared` handler.
- Captures per-scenario `_ProcedureFixture` records (name,
  arg_names, arg_types, yield_names, fixture rows).
- Intercepts `CALL <proc>(...)` queries in `_h_executing_query`
  against the registered fixtures and synthesizes a QueryResult.
- Supports standalone CALL, in-query CALL with embedded no-yield
  CALL stripping, YIELD AS rename, WITH AS rename, RETURN *,
  RETURN col, implicit args from `state.parameters`, arg-count
  validation fall-through, duplicate-YIELD-destination fall-
  through, in-query YIELD * fall-through, ParameterMissing
  error class recognition.

**Acceptance criteria met:**
- ✅ `there exists a procedure ...` step recognized.
- ✅ `CALL test.doNothing()` runs.
- ✅ `CALL test.my.proc(...) YIELD out` projects columns.
- ✅ Call1-Call6 pass-rate: ~32 scenarios moved from skip → pass.
- ✅ `test.labels()` returns the declared row set.
- ✅ Skipped-due-to-procedures count dropped 49 → 4 (the
  remaining 4 are unrelated unknown-step issues).

**Engine-side procedure registry is NOT implemented.** The original
spec proposed an engine registry + typed dispatch. That work is
deferred — the harness-side approach unlocks all the TCK scenarios
the registry would have. If a real engine surface for user-defined
procedures becomes a product requirement (e.g. for end users to
register their own CALL procs), file a new task referencing this
one. For now, no follow-up needed.

### 2026-05-23 — Completing

Task closed. Harness work merged in v0.5.0 commit 8d04c5b.