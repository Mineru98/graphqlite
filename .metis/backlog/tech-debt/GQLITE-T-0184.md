---
id: sanitize-sql-aliases-built-from
level: task
title: "Sanitize SQL aliases built from Cypher variable names"
short_code: "GQLITE-T-0184"
created_at: 2026-03-30T16:12:44.291956+00:00
updated_at: 2026-03-30T16:12:44.291956+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/backlog"
  - "#tech-debt"


exit_criteria_met: false
initiative_id: NULL
---

# Sanitize SQL aliases built from Cypher variable names

## Objective

Audit and fix all SQL alias generation to sanitize or quote Cypher variable names, preventing invalid SQL from backtick-quoted identifiers with spaces or special characters.

## Backlog Item Details

### Type
- [x] Tech Debt - Code improvement or refactoring

### Priority
- [x] P2 - Medium (nice to have)

### Technical Debt Impact
- **Current Problems**: SQL aliases are built via `snprintf("%s_0", variable)` from raw Cypher variable names. Backtick-quoted identifiers (`` `my var` ``, `` `foo;bar` ``) can produce invalid or ambiguous SQL aliases.
- **Benefits of Fixing**: Robust handling of all valid Cypher identifiers; defense-in-depth against SQL injection patterns.
- **Risk Assessment**: Low exploit risk (SQLite single-statement execution prevents multi-statement injection), but malformed aliases can cause query failures or incorrect results.
- **GitHub Issue**: #55

## Acceptance Criteria

- [ ] All `snprintf(..., "%s_0", variable)` patterns replaced with safe alias generation
- [ ] Backtick-quoted Cypher variables with spaces/special chars produce valid SQL
- [ ] `CREATE (`my var`:Label {id: "test"})` + `MATCH (`my var`:Label) RETURN `my var`.id` works correctly
- [ ] Adversarial identifiers (`` `x;DROP TABLE nodes--` ``) produce valid SQL without errors
- [ ] Existing tests continue to pass

## Implementation Notes

### Technical Approach
Use `get_next_default_alias(ctx)` (already generates safe `_gql_default_alias_N` aliases) everywhere, and map back to variable names through `var_ctx`. Alternatively, quote all generated aliases with double-quotes in the SQL output.

### Affected Files
- `src/backend/executor/query_dispatch.c` (merge_with_execute_return, CALL handler)
- `src/backend/transform/transform_match.c` (alias generation for MATCH patterns)
- Any file with `snprintf(..., "%s_0", ...)` pattern

## Status Updates

*To be added during implementation*