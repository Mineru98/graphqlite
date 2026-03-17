---
id: support-return-wildcard
level: task
title: "Support RETURN * wildcard"
short_code: "GQLITE-T-0123"
created_at: 2026-03-17T13:37:47.299840+00:00
updated_at: 2026-03-17T13:37:47.299840+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/backlog"
  - "#feature"


exit_criteria_met: false
initiative_id: NULL
---

# Support RETURN * wildcard

## Objective

Support `RETURN *` and `WITH *` to return all bound variables without listing them explicitly.

## Backlog Item Details

### Type
- [x] Feature - New functionality or enhancement

### Priority
- [x] P1 - High (important for user experience)

### Business Justification
- **User Value**: `RETURN *` is one of the most commonly used Cypher shortcuts. Every tutorial uses it. Its absence surprises users immediately.
- **Effort Estimate**: M — requires tracking bound variables through parse/transform

## Acceptance Criteria

- [ ] `MATCH (n) RETURN *` returns all matched nodes
- [ ] `MATCH (n)-[r]->(m) RETURN *` returns n, r, m
- [ ] `WITH *` passes all variables to next clause
- [ ] Works with OPTIONAL MATCH
- [ ] Functional tests added

## Coverage Matrix Reference
- `docs/cypher-coverage-matrix.md` Section 3: `RETURN *`, `WITH *`

## Status Updates

*To be added during implementation*