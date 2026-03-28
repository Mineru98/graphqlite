---
id: structural-consolidation-and
level: initiative
title: "Structural Consolidation and Architecture Hardening (Arch Review Wave 3)"
short_code: "GQLITE-I-0033"
created_at: 2026-03-28T13:57:26.022410+00:00
updated_at: 2026-03-28T13:59:02.918783+00:00
parent: GQLITE-V-0001
blocked_by: []
archived: false

tags:
  - "#initiative"
  - "#phase/decompose"


exit_criteria_met: false
estimated_complexity: XL
initiative_id: structural-consolidation-and
---

# Structural Consolidation and Architecture Hardening (Arch Review Wave 3) Initiative

**Source:** Architecture Review (`.claude/worktrees/arch-review/review/`)
**Priority:** Schedule as dedicated refactor cycle
**Effort:** ~4-6 weeks combined

## Context

Wave 3 addresses structural issues that reduce long-term maintenance cost. These are larger refactors that touch many files and should be done in a dedicated cycle, not interspersed with feature work.

## Goals

- Consolidate extension.c / bundled_init.c into shared implementation
- Migrate all static transform globals into per-query context (thread safety)
- Normalize dual result type to single representation
- Add runtime observability callback + structured version response
- Fix API consistency issues across Python and Rust bindings

## Tasks (REC-09, REC-14 through REC-17)

| REC | Task | Effort | Findings |
|-----|------|--------|----------|
| REC-09 | Consolidate extension.c and bundled_init.c | 3-5 days | LEG-005, EVO-06, CF-2 |
| REC-14 | Migrate static transform globals into context | 1-2 weeks | COR-004, EVO-01, SEC-009, LEG-003, LEG-004, LEG-008 |
| REC-15 | Normalize dual result type to single representation | 1 week | EVO-02, LEG-002 |
| REC-16 | Runtime observability callback + version function | 3-5 days | OPS-002, OPS-006, OPS-008, API-013 |
| REC-17 | API consistency fixes (Python + Rust) | 2-4 days | API-003, API-005, API-006, API-007, API-008, API-010 |

## Dependencies (strict ordering)

1. REC-09 first (consolidate entry points — halves defect surface for everything after)
2. REC-14 second (migrate statics — prerequisite for REC-15)
3. REC-15 third (normalize result type — requires REC-09 and REC-14)
4. REC-16 and REC-17 can be done in parallel after REC-09

## Architectural Policies (ongoing after Wave 3)

- AR-1: No static globals in transform files (enforce via CI lint)
- AR-2: All AST string values must pass through escape_sql_string() before SQL embedding
- AR-3: All functional tests must assert data values, not just non-error returns
- AR-4: graphqlite_version() replaces graphqlite_test() for load verification

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