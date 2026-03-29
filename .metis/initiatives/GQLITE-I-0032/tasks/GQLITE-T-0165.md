---
id: rec-11-structured-error-codes-and
level: task
title: "REC-11: Structured error codes and fix prefix-based error detection"
short_code: "GQLITE-T-0165"
created_at: 2026-03-28T13:59:28.174160+00:00
updated_at: 2026-03-29T00:48:45.973769+00:00
parent: GQLITE-I-0032
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/active"


exit_criteria_met: false
initiative_id: GQLITE-I-0032
---

# REC-11: Structured error codes and fix prefix-based error detection

## Objective

Replace unstructured `"Error: ..."` string responses with JSON-structured error objects containing error message and error code. Update Python and Rust SDK error detection accordingly. Addresses findings API-004, CF-6 (Major).

## Affected Files

- C error paths throughout `src/` that return `"Error: ..."` strings
- `python/graphqlite/connection.py` -- line 162 (prefix detection)
- `rust/src/connection.rs` -- line 126 (prefix detection)

## What To Do

1. Define error codes: `PARSE_ERROR`, `EXECUTION_ERROR`, `NOT_IMPLEMENTED`
2. Change C-level error returns from `"Error: ..."` to `{"error": "...", "code": "PARSE_ERROR|EXECUTION_ERROR|NOT_IMPLEMENTED"}`
3. Update Python `connection.py:162` to detect errors via JSON parse instead of string prefix
4. Update Rust `connection.rs:126` similarly
5. Add backward compatibility note if needed

## Acceptance Criteria

## Acceptance Criteria

- [ ] All error responses are valid JSON with `error` and `code` fields
- [ ] Python SDK correctly detects and raises errors from JSON responses
- [ ] Rust SDK correctly detects and raises errors from JSON responses
- [ ] All existing tests updated and passing

## Effort Estimate

2-3 days

## Status Updates

*To be added during implementation*