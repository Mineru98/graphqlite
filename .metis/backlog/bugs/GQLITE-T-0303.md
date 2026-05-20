---
id: percentilecont-disc-out-of-range
level: task
title: "percentileCont/Disc out-of-range param raises generic error instead of ArgumentError: NumberOutOfRange"
short_code: "GQLITE-T-0303"
created_at: 2026-05-20T16:16:13.402828+00:00
updated_at: 2026-05-20T16:16:13.402828+00:00
parent: 
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/backlog"
  - "#bug"


exit_criteria_met: false
initiative_id: NULL
---

# percentileCont/Disc out-of-range param raises generic error instead of ArgumentError: NumberOutOfRange

## Reproducer

```sql
.load build/graphqlite.dylib
SELECT cypher('CREATE ({price: 10.0})');
SELECT cypher('MATCH (n) RETURN percentileCont(n.price, 1.1) AS p');
-- Got:      [] (with generic error)
-- Expected: ArgumentError: NumberOutOfRange (TCK-classified error)
```

Same for `-1`, `1000`, etc. Per openCypher spec the percentile
parameter must be in `[0, 1]`.

## Context — surfaced 2026-05-20

Discovered while landing M15 (percentile aggregates, GQLITE-T-0300).
The out-of-range path correctly raises an error via
`sqlite3_result_error("percentileCont: percentile must be in [0,1]")`
in `runtime/udf_helpers.c` — but the error string doesn't carry the
TCK error-class prefix, so the harness classifies it as a generic
internal error rather than the expected
`ArgumentError: NumberOutOfRange`.

TCK targets: `Aggregation6 [3]` (percentileCont bad args, examples
1000/-1/1.1), `Aggregation6 [4]` (percentileDisc bad args, same).

## Fix sketch

Change `percentile_cont_final` and `percentile_disc_final` in
`src/backend/runtime/udf_helpers.c` to:

```c
sqlite3_result_error(ctx,
    "ArgumentError: NumberOutOfRange: percentile must be in [0,1]", -1);
```

Also validate at xStep (so zero-row aggregates still raise). Audit
other UDFs that raise errors without TCK-class prefixes — same
pattern across the codebase is worth a sister sweep (related to
I-0037 Phase B work).

## Impact

~6 TCK scenarios (Aggregation6 [3]/[4] across their example rows).

## Acceptance Criteria

- [ ] Out-of-range param produces `ArgumentError: NumberOutOfRange: ...` error
- [ ] Error fires at xStep, not deferred to xFinal
- [ ] Aggregation6 [3] and [4] scenarios pass
- [ ] No regression on in-range percentile calls

---

*Sections below are unused template scaffolding.*

## Parent Initiative **[CONDITIONAL: Assigned Task]**

[[Parent Initiative]]

## Objective **[REQUIRED]**

{Clear statement of what this task accomplishes}

## Backlog Item Details **[CONDITIONAL: Backlog Item]**

{Delete this section when task is assigned to an initiative}

### Type
- [ ] Bug - Production issue that needs fixing
- [ ] Feature - New functionality or enhancement  
- [ ] Tech Debt - Code improvement or refactoring
- [ ] Chore - Maintenance or setup work

### Priority
- [ ] P0 - Critical (blocks users/revenue)
- [ ] P1 - High (important for user experience)
- [ ] P2 - Medium (nice to have)
- [ ] P3 - Low (when time permits)

### Impact Assessment **[CONDITIONAL: Bug]**
- **Affected Users**: {Number/percentage of users affected}
- **Reproduction Steps**: 
  1. {Step 1}
  2. {Step 2}
  3. {Step 3}
- **Expected vs Actual**: {What should happen vs what happens}

### Business Justification **[CONDITIONAL: Feature]**
- **User Value**: {Why users need this}
- **Business Value**: {Impact on metrics/revenue}
- **Effort Estimate**: {Rough size - S/M/L/XL}

### Technical Debt Impact **[CONDITIONAL: Tech Debt]**
- **Current Problems**: {What's difficult/slow/buggy now}
- **Benefits of Fixing**: {What improves after refactoring}
- **Risk Assessment**: {Risks of not addressing this}

## Acceptance Criteria **[REQUIRED]**

- [ ] {Specific, testable requirement 1}
- [ ] {Specific, testable requirement 2}
- [ ] {Specific, testable requirement 3}

## Test Cases **[CONDITIONAL: Testing Task]**

{Delete unless this is a testing task}

### Test Case 1: {Test Case Name}
- **Test ID**: TC-001
- **Preconditions**: {What must be true before testing}
- **Steps**: 
  1. {Step 1}
  2. {Step 2}
  3. {Step 3}
- **Expected Results**: {What should happen}
- **Actual Results**: {To be filled during execution}
- **Status**: {Pass/Fail/Blocked}

### Test Case 2: {Test Case Name}
- **Test ID**: TC-002
- **Preconditions**: {What must be true before testing}
- **Steps**: 
  1. {Step 1}
  2. {Step 2}
- **Expected Results**: {What should happen}
- **Actual Results**: {To be filled during execution}
- **Status**: {Pass/Fail/Blocked}

## Documentation Sections **[CONDITIONAL: Documentation Task]**

{Delete unless this is a documentation task}

### User Guide Content
- **Feature Description**: {What this feature does and why it's useful}
- **Prerequisites**: {What users need before using this feature}
- **Step-by-Step Instructions**:
  1. {Step 1 with screenshots/examples}
  2. {Step 2 with screenshots/examples}
  3. {Step 3 with screenshots/examples}

### Troubleshooting Guide
- **Common Issue 1**: {Problem description and solution}
- **Common Issue 2**: {Problem description and solution}
- **Error Messages**: {List of error messages and what they mean}

### API Documentation **[CONDITIONAL: API Documentation]**
- **Endpoint**: {API endpoint description}
- **Parameters**: {Required and optional parameters}
- **Example Request**: {Code example}
- **Example Response**: {Expected response format}

## Implementation Notes **[CONDITIONAL: Technical Task]**

{Keep for technical tasks, delete for non-technical. Technical details, approach, or important considerations}

### Technical Approach
{How this will be implemented}

### Dependencies
{Other tasks or systems this depends on}

### Risk Considerations
{Technical risks and mitigation strategies}

## Status Updates **[REQUIRED]**

*To be added during implementation*