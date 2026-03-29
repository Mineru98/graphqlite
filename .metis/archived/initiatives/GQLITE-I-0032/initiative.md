---
id: major-correctness-performance-and
level: initiative
title: "Major Correctness, Performance, and API Improvements (Arch Review Wave 2)"
short_code: "GQLITE-I-0032"
created_at: 2026-03-28T13:57:24.637513+00:00
updated_at: 2026-03-29T00:57:36.702368+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: true

tags:
  - "#initiative"
  - "#phase/completed"


exit_criteria_met: false
estimated_complexity: L
initiative_id: major-correctness-performance-and
---

# Major Correctness, Performance, and API Improvements (Arch Review Wave 2) Initiative

**Source:** Architecture Review (`.claude/worktrees/arch-review/review/`)
**Priority:** Fix in current development cycle
**Effort:** ~2-3 weeks combined

## Context

Wave 2 addresses Major-severity findings that degrade correctness, security, or reliability in realistic usage. These build on Wave 1's corrected baseline.

## Goals

- Fix double-pass result enumeration and O(n^2) JSON serialization (PERF-001, PERF-002)
- Add structured error codes replacing prefix-based detection (API-004)
- Add schema versioning via PRAGMA user_version (OPS-003)
- Fix Rust extension extraction safety (OPS-004, SEC-007)
- Add scale guards for O(N^2) algorithms (PERF-007, SEC-014)
- Migrate Graph API to parameterized queries (API-001)

## Tasks (REC-07 through REC-13)

| REC | Task | Effort | Findings |
|-----|------|--------|----------|
| REC-07 | Scale guards for node similarity + dynamic hash table sizing | 4-8 hours | PERF-007, SEC-014, PERF-005 |
| REC-08 | Graph API parameterized queries (Python + Rust) | 3-5 days | API-001 |
| REC-10 | Single-pass result enumeration + O(n) JSON serialization | 1-2 days | PERF-001, PERF-002 |
| REC-11 | Structured error codes + fix prefix detection | 2-3 days | API-004, CF-6 |
| REC-12 | Schema versioning via PRAGMA user_version | 1-2 days | OPS-003 |
| REC-13 | Rust extension extraction safety | 1-2 days | OPS-004, SEC-007 |

## Dependencies

- REC-10 depends on Wave 1 REC-02 (buffer_size type change)
- REC-12 and REC-11 inform each other (both touch error/result formatting)

## Context **[REQUIRED]**

{Describe the context and background for this initiative}

## Goals & Non-Goals **[REQUIRED]**

**Goals:**
- {Primary objective 1}
- {Primary objective 2}

**Non-Goals:**
- {What this initiative will not address}

## Requirements **[CONDITIONAL: Requirements-Heavy Initiative]**

{Delete if not a requirements-focused initiative}

### User Requirements
- **User Characteristics**: {Technical background, experience level, etc.}
- **System Functionality**: {What users expect the system to do}
- **User Interfaces**: {How users will interact with the system}

### System Requirements
- **Functional Requirements**: {What the system should do - use unique identifiers}
  - REQ-001: {Functional requirement 1}
  - REQ-002: {Functional requirement 2}
- **Non-Functional Requirements**: {How the system should behave}
  - NFR-001: {Performance requirement}
  - NFR-002: {Security requirement}

## Use Cases **[CONDITIONAL: User-Facing Initiative]**

{Delete if not user-facing}

### Use Case 1: {Use Case Name}
- **Actor**: {Who performs this action}
- **Scenario**: {Step-by-step interaction}
- **Expected Outcome**: {What should happen}

### Use Case 2: {Use Case Name}
- **Actor**: {Who performs this action}
- **Scenario**: {Step-by-step interaction}
- **Expected Outcome**: {What should happen}

## Architecture **[CONDITIONAL: Technically Complex Initiative]**

{Delete if not technically complex}

### Overview
{High-level architectural approach}

### Component Diagrams
{Describe or link to component diagrams}

### Class Diagrams
{Describe or link to class diagrams - for OOP systems}

### Sequence Diagrams
{Describe or link to sequence diagrams - for interaction flows}

### Deployment Diagrams
{Describe or link to deployment diagrams - for infrastructure}

## Detailed Design **[REQUIRED]**

{Technical approach and implementation details}

## UI/UX Design **[CONDITIONAL: Frontend Initiative]**

{Delete if no UI components}

### User Interface Mockups
{Describe or link to UI mockups}

### User Flows
{Describe key user interaction flows}

### Design System Integration
{How this fits with existing design patterns}

## Testing Strategy **[CONDITIONAL: Separate Testing Initiative]**

{Delete if covered by separate testing initiative}

### Unit Testing
- **Strategy**: {Approach to unit testing}
- **Coverage Target**: {Expected coverage percentage}
- **Tools**: {Testing frameworks and tools}

### Integration Testing
- **Strategy**: {Approach to integration testing}
- **Test Environment**: {Where integration tests run}
- **Data Management**: {Test data strategy}

### System Testing
- **Strategy**: {End-to-end testing approach}
- **User Acceptance**: {How UAT will be conducted}
- **Performance Testing**: {Load and stress testing}

### Test Selection
{Criteria for determining what to test}

### Bug Tracking
{How defects will be managed and prioritized}

## Alternatives Considered **[REQUIRED]**

{Alternative approaches and why they were rejected}

## Implementation Plan **[REQUIRED]**

{Phases and timeline for execution}