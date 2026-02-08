---
id: match-set-return-ignores-return
level: task
title: "MATCH+SET+RETURN ignores RETURN clause"
short_code: "GQLITE-T-0110"
created_at: 2026-02-08T02:19:38.244430+00:00
updated_at: 2026-02-08T02:19:38.244430+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/backlog"
  - "#bug"


exit_criteria_met: false
strategy_id: NULL
initiative_id: NULL
---

# MATCH+SET+RETURN ignores RETURN clause

## Objective

When a Cypher query combines MATCH+SET+RETURN (e.g., `MATCH (n:Person) SET n.score = 100 RETURN n.score`), the RETURN clause is silently ignored. The SET executes correctly but no data is returned. In standard Cypher (Neo4j), this pattern is valid and returns the updated values.

## Backlog Item Details

### Type
- [x] Bug - Production issue that needs fixing

### Priority
- [x] P2 - Medium (nice to have)

### Impact Assessment
- **Affected Users**: Any user combining SET and RETURN in a single Cypher query
- **Reproduction Steps**: 
  1. `SELECT cypher('CREATE (n:Test {name: "Alice"})');`
  2. `SELECT cypher('MATCH (n:Test) SET n.score = 100 RETURN n.score');`
  3. Observe: result is NULL instead of `[{"n.score": 100}]`
- **Expected vs Actual**: Expected the updated `n.score` value to be returned. Actual: no data returned (NULL result). The SET itself succeeds — a subsequent `MATCH (n:Test) RETURN n.score` correctly returns 100.
- **Workaround**: Split into two queries — one for SET, one for RETURN.

## Root Cause

The `handle_match_set` dispatch handler in `query_dispatch.c:625` (priority 90, `forbidden = CLAUSE_NONE`) catches any query containing MATCH+SET, regardless of other clauses present. It calls `execute_match_set_query()` in `executor_set.c:31`, which:

1. Transforms the MATCH clause to SQL
2. Executes it to get matched node/edge IDs
3. Applies SET operations for each matched row
4. Returns — **never inspecting or processing the RETURN clause**

The same issue likely applies to MATCH+DELETE+RETURN and MATCH+REMOVE+RETURN, since those handlers follow the same pattern.

## Acceptance Criteria

- [ ] `MATCH (n:Label) SET n.prop = value RETURN n.prop` returns the updated property value
- [ ] `MATCH (n:Label) SET n += {map} RETURN n.prop` returns updated values after merge
- [ ] `MATCH (n:Label) SET n = {map} RETURN n.prop` returns updated values after replace
- [ ] Works with both parameterized and non-parameterized queries
- [ ] Existing SET tests continue to pass
- [ ] Add functional tests for SET+RETURN patterns

## Implementation Notes

### Technical Approach
After executing the SET operations in `execute_match_set_query`, check if the original query has a RETURN clause. If so, re-query the (now updated) matched nodes and build the result using the RETURN clause's expression list. Alternatively, refactor the dispatch to use the transform-based path (which handles RETURN naturally) for the full query, only using the SET executor for the mutation step.

### Risk Considerations
- Must ensure RETURN sees post-SET values, not pre-SET values
- Need to handle edge cases: RETURN with expressions, aliases, aggregations after SET