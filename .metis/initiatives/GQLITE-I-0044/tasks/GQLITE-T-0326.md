---
id: a2-accept-reserved-keywords
level: task
title: "A2: Accept reserved keywords (CONTAINS/STARTS/ENDS) as relationship type names"
short_code: "GQLITE-T-0326"
created_at: 2026-05-23T10:53:41.448143+00:00
updated_at: 2026-05-23T10:53:41.448143+00:00
parent: GQLITE-I-0044
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0044
---

# A2: CONTAINS/STARTS/ENDS as rel type names

## Parent Initiative

[[GQLITE-I-0044]] — Phase A quick win #2.

## Objective

`MATCH (a)-[:CONTAINS]->(b)` and similar with STARTS/ENDS rejected
at parse time because the grammar only accepts IDENTIFIER and
BQIDENT for rel types. Labels already accept `non_reserved_kw`;
extend the same to rel types.

## Repro

```cypher
CREATE (a)-[:CONTAINS]->(b);
```

**Expected:** parses and creates edge with type 'CONTAINS'.
**Actual:** `syntax error, unexpected CONTAINS, expecting IDENTIFIER or BQIDENT`.

## Affected scenarios

- Match4 [2] Simple variable length pattern (uses :CONTAINS).
- Match4 [4] Matching longer variable length paths.
- Likely a few more sibling scenarios in Match4/5/6/7 that have
  CONTAINS/STARTS/ENDS in test data.

Estimated **+4 TCK** with possible long-tail unlocks once the
setup-CREATE silently-fails-and-leaves-empty-graph cascade is
broken.

## Implementation plan

1. Locate the rel-pattern productions in `cypher_gram.y`:
   - 6 productions: directed (`-[…]->`), incoming (`<-[…]-`),
     undirected (`-[…]-`), each with non-varlen and varlen variants.
2. Each currently accepts `IDENTIFIER` and `BQIDENT` for the type
   slot. Add a `non_reserved_kw` alternative.
3. Consider introducing a `rel_type_name` nonterminal to keep
   productions tidy (similar to how labels are factored).
4. Verify Bison conflict counts after change. Currently `%expect 14`
   S/R and `%expect-rr 3` R/R. Update both if needed.
5. `angreal dev clean` before rebuild (header struct change risk).

## Acceptance Criteria

- [ ] Match4 [2]/[4] pass.
- [ ] `:CONTAINS`, `:STARTS`, `:ENDS` parse as rel types in MATCH
  + CREATE.
- [ ] Bison conflict counts updated and documented in
  `%expect` directives.
- [ ] No regression on existing `CONTAINS`/`STARTS`/`ENDS`
  predicate usage (`x CONTAINS 'foo'` etc.).
- [ ] `angreal test unit && angreal test functional` clean.

## Affected files

- `src/backend/parser/cypher_gram.y` (primary).

## Effort

S — grammar productions are mechanical; conflict-resolution might
add a small amount.

## Risk

Bison conflicts. If introducing `non_reserved_kw` in rel-type
position creates new R/R conflicts with predicate uses
(`x CONTAINS y`), may need precedence tweaks or position-specific
alternates.

## Status Updates

*To be added during implementation.*
