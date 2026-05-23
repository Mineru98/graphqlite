---
id: a5-bqident-sweep-accept-backtick
level: task
title: "A5: BQIDENT sweep — accept backtick-quoted identifiers in remaining grammar slots"
short_code: "GQLITE-T-0329"
created_at: 2026-05-23T10:55:30.411252+00:00
updated_at: 2026-05-23T10:55:30.411252+00:00
parent: GQLITE-I-0044
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0044
---

# A5: BQIDENT sweep in remaining grammar slots

## Parent Initiative

[[GQLITE-I-0044]] — Phase A quick win #5.

## Objective

v0.5.0 added BQIDENT (backtick-quoted identifier) support for
RETURN AS and UNWIND AS aliases. Sweep other grammar productions
that take IDENTIFIER and should also accept BQIDENT.

## Background

Cypher allows backtick-quoted identifiers anywhere a regular
identifier is valid: variable bindings, alias targets, property
keys, label names (handled via non_reserved_kw / BQIDENT split),
parameter names within `$`{`...`}.

The v0.5.0 sweep covered:
- `expr AS IDENTIFIER` → also `expr AS BQIDENT` (RETURN).
- `UNWIND expr AS IDENTIFIER` → also `BQIDENT`.

Remaining slots to verify (and possibly extend):
- `FOREACH ( IDENTIFIER IN ... )` — loop variable.
- `LOAD CSV ... AS IDENTIFIER` — bound row alias.
- Map projection `n {.IDENTIFIER, …}` — though this is largely
  property-access territory.
- Property keys inside map literals — `{IDENTIFIER: expr}` vs
  `{BQIDENT: expr}`.
- Subquery scopes if any.

## Implementation plan

1. Grep `cypher_gram.y` for every `IDENTIFIER` occurrence in a
   binding/alias context. Compare against where BQIDENT is also
   accepted.
2. For each slot where IDENTIFIER appears but BQIDENT does not,
   add a parallel production. The scanner strips the backticks
   so the action body is identical.
3. Verify Bison conflict counts — should not increase (BQIDENT
   is a distinct token from IDENTIFIER, no shift/reduce overlap).
4. Run TCK to see what scenarios newly pass.

## Expected wins

Modest — most TCK scenarios use plain identifiers. BQIDENT comes
up in tests checking that backtick-quoted variable names are
preserved (e.g. `RETURN n.\`some key\``). Estimated **+1-2 TCK**.

## Acceptance Criteria

- [ ] Every grammar slot that accepts IDENTIFIER in a binding
  context ALSO accepts BQIDENT (where Cypher spec allows).
- [ ] Documentation note in cypher_gram.y identifying the
  identifier/binding slots that intentionally REJECT BQIDENT
  (if any).
- [ ] No regression on existing identifier tests.
- [ ] `angreal test unit && angreal test functional` clean.

## Affected files

- `src/backend/parser/cypher_gram.y` — additions only.

## Effort

S — mechanical grammar additions. Likely 3-5 productions to add.

## Status Updates

*To be added during implementation.*
