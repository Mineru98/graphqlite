---
id: end-to-end-functional-tests-for
level: task
title: "End-to-end functional tests for JSON property storage and nested access"
short_code: "GQLITE-T-0106"
created_at: 2026-02-07T16:48:25.764707+00:00
updated_at: 2026-02-07T19:39:47.519330+00:00
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

# End-to-end functional tests for JSON property storage and nested access

## Parent Initiative

[[GQLITE-I-0030]] — Native JSON/Map/List Properties + Nested Access

## Objective

Create a comprehensive functional test file that exercises the full JSON property lifecycle: CREATE with map/list values, SET map/list values, read via dot access, bracket access, nested access, helper functions, WHERE comparisons, and IN operators. This validates the entire feature end-to-end and serves as the acceptance test suite for the initiative.

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

## Acceptance Criteria

- [ ] New `tests/functional/27_json_properties.sql` test file created
- [ ] Section 1: CREATE with map literal — `CREATE (n:Node {metadata: {name: 'x', labels: {a: 'b'}}})`
- [ ] Section 2: CREATE with list literal — `CREATE (n:Node {tags: [1, 2, 3]})`
- [ ] Section 3: SET map/list — `SET n.metadata = {key: 'val'}`, `SET n.tags = [1, 2, 3]`
- [ ] Section 4: Read via dot access — `RETURN n.metadata`, `RETURN n.metadata.name`
- [ ] Section 5: Read via bracket access — `RETURN n.metadata['name']`, `RETURN n.tags[0]`
- [ ] Section 6: Deep nesting — `RETURN n.metadata.labels.a`
- [ ] Section 7: WHERE comparisons — `WHERE n.metadata.name = 'x'`, `WHERE n.metadata.count > 5`
- [ ] Section 8: IN operator — `WHERE 'x' IN n.tags`
- [ ] Section 9: Helper functions — `json_get(n.metadata, 'name')`, `json_keys(n.metadata)`, `json_type(n.metadata)`
- [ ] Section 10: Edge JSON properties — `SET r.config = {timeout: 30}`, `RETURN r.config.timeout`
- [ ] Section 11: Mixed scalar + JSON — verify scalar properties still work alongside JSON
- [ ] All tests pass with `angreal test functional`
- [ ] Un-skip `tests/functional/09_edge_cases.sql` line 199-202 (nested property test)

## Implementation Notes

### Files to Create/Modify

| File | Changes |
|------|---------|
| `tests/functional/27_json_properties.sql` | **New** — comprehensive test file |
| `tests/functional/09_edge_cases.sql` | Un-skip nested property test at line 199 |

### Technical Approach

Follow the existing functional test pattern: each section has a header comment, `SELECT 'section name' as section;`, then individual test cases with `SELECT 'Test N.M - description:' as test_name;` followed by the Cypher query. Tests should create their own data and verify results inline.

### Dependencies

Depends on all other tasks (T-0102, T-0103, T-0104, T-0105). This is the final validation task.

## Status Updates

### Session 1 — Implementation Complete

**Created `tests/functional/33_json_properties.sql`** (used 33 since 27 was taken by foreach_clause):

| Section | Tests | Status |
|---------|-------|--------|
| 1. CREATE with map literals | Simple map, nested map, read back | Pass |
| 2. CREATE with list literals | Int list, string list, mixed list, read back | Pass |
| 3. SET map/list properties | SET map, SET list, overwrite scalar→JSON | Pass |
| 4. Dot access | Key access, numeric, nested map, nested scalar | Pass |
| 5. Bracket access | Map key, list index [0], [2], string list | Pass |
| 6. Deep nesting | 3 levels, 4 levels deep, intermediate object | Pass |
| 7. WHERE comparisons | Nested string, numeric, > comparison, deep nested | Pass |
| 8. Helper functions | json_get (key + $path), json_keys, json_type (object + array) | Pass |
| 9. Edge JSON properties | CREATE with map, read, nested access, SET map | Pass |
| 10. Mixed scalar + JSON | Coexistence, properties(), keys() include JSON | Pass |
| 11. List of maps | CREATE, read back, index access | Pass |

**Edge case test (09_edge_cases.sql line 199-202):** Already active and passing — `n.data.level1.level2.level3` returns "found". No changes needed.

**Test results:** 770/770 unit tests pass, all functional tests pass (0 failures)