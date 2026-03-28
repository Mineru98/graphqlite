---
id: rec-12-schema-versioning-via
level: task
title: "REC-12: Schema versioning via PRAGMA user_version"
short_code: "GQLITE-T-0166"
created_at: 2026-03-28T13:59:29.503077+00:00
updated_at: 2026-03-28T13:59:29.503077+00:00
parent: GQLITE-I-0032
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0032
---

# REC-12: Schema versioning via PRAGMA user_version

## Objective

Add schema versioning so GraphQLite can detect outdated schemas and run migrations on existing databases. Addresses finding OPS-003 (Major).

## Affected Files

- `include/cypher_schema.h` -- add `GRAPHQLITE_SCHEMA_VERSION` define
- `src/backend/schema/cypher_schema.c` -- `cypher_schema_initialize()`

## What To Do

1. Define `GRAPHQLITE_SCHEMA_VERSION 1` in `cypher_schema.h`
2. At end of `cypher_schema_initialize()`, set `PRAGMA user_version = 1`
3. At start of init, read `PRAGMA user_version`; if 0 (fresh DB), proceed normally; if < current version, run migration steps; if > current version, return error
4. Add a migration framework skeleton (version switch/case) for future use

## Acceptance Criteria

- [ ] `GRAPHQLITE_SCHEMA_VERSION` defined in header
- [ ] Fresh databases get `user_version` set to 1
- [ ] Existing databases with version 0 are migrated (currently no-op, just sets version)
- [ ] Databases with version > current return a clear error
- [ ] All tests pass

## Effort Estimate

1-2 days

## Status Updates

*To be added during implementation*

