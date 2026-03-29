---
id: grammar-rules-for-call-clause-with
level: task
title: "Grammar rules for CALL { } clause with UNION support"
short_code: "GQLITE-T-0173"
created_at: 2026-03-29T01:05:11.432575+00:00
updated_at: 2026-03-29T01:05:11.432575+00:00
parent: GQLITE-I-0034
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0034
---

# Grammar rules for CALL { } clause with UNION support

## Parent Initiative

[[GQLITE-I-0034]]

## Objective

Add Bison grammar rules to `cypher_gram.y` so that `CALL { ... }` is recognized as a clause, including support for UNION branches inside the braces.

## Affected Files

- `src/backend/parser/cypher_gram.y`
- `src/generated/cypher_gram.tab.c` (regenerated)
- `src/generated/cypher_gram.tab.h` (regenerated)

## Implementation Notes

- Add production: `call_clause: CALL '{' query_list '}'`
- Add `query_list: query | query_list UNION query` to support UNION inside CALL
- Add `call_clause` as an alternative in the `clause:` rule
- After adding rules, check for new shift/reduce or reduce/reduce conflicts and update `%expect` / `%expect-rr` counts accordingly
- Regenerate the parser output files via the build system

## Acceptance Criteria

- [ ] `CALL { WITH c MATCH (d) RETURN d }` parses without error
- [ ] `CALL { query1 UNION query2 }` parses without error
- [ ] `%expect` counts updated if new conflicts arise
- [ ] Generated parser files rebuild cleanly

## Effort Estimate

1-2 days

## Status Updates

*To be added during implementation*