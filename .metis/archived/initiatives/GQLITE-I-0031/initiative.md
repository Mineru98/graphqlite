---
id: critical-security-and-correctness
level: initiative
title: "Critical Security and Correctness Fixes (Arch Review Wave 1)"
short_code: "GQLITE-I-0031"
created_at: 2026-03-28T13:57:23.314651+00:00
updated_at: 2026-03-28T22:52:21.693468+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: true

tags:
  - "#initiative"
  - "#phase/completed"


exit_criteria_met: false
estimated_complexity: M
initiative_id: critical-security-and-correctness
---

# Critical Security and Correctness Fixes (Arch Review Wave 1) Initiative

**Source:** Architecture Review (`.claude/worktrees/arch-review/review/`)
**Priority:** Must fix before any production release
**Effort:** ~1 week combined (all tasks are independent and parallelizable)

## Context

An architecture review of the GraphQLite codebase identified 14 Critical-severity findings across security, correctness, and operability. This initiative addresses the 6 highest-priority recommendations (REC-01 through REC-06) that represent exploitable vulnerabilities or silent data corruption.

## Goals

- Eliminate all SQL injection vectors in the transform layer
- Fix integer overflow and unchecked realloc in result serialization
- Make extension initialization failures visible instead of silent
- Prevent infinite loops in CSR graph loading
- Fix LIKE wildcard injection in string predicates
- Make `CREATE ... RETURN` silent discard an explicit error

## Non-Goals

- Performance optimizations (Wave 2)
- Structural refactoring (Wave 3)
- New feature development

## Tasks (REC-01 through REC-06)

| REC | Task | Effort | Findings Addressed |
|-----|------|--------|--------------------|
| REC-01 | SQL injection escape audit pass | 1-2 days | SEC-001, SEC-002, SEC-003, SEC-004, COR-006 |
| REC-02 | Integer overflow + unchecked realloc in result serialization | 2 days | COR-001, COR-002, SEC-005, SEC-006 |
| REC-03 | Check function registration return values | 2-4 hours | OPS-001, COR-009 |
| REC-04 | Hash table termination guard in CSR graph load | 2-4 hours | COR-007, SEC-013 |
| REC-05 | LIKE wildcard injection fix | 2-4 hours | COR-003, SEC-008 |
| REC-06 | CREATE...RETURN explicit error | 2-4 hours | COR-005, API-002 |

## Testing Strategy

Each task must add a regression test *before* fixing the bug, following the review's recommendation. SQL injection tests use single-quote payloads in labels, relationship types, and graph names. All fixes verified against existing 921 unit + 43 functional test suite.

## Dependencies

None — all 6 tasks are independent. This wave unblocks Wave 2 (REC-02 scaffolding needed for PERF-002).