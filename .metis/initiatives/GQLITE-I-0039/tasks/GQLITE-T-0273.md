---
id: s19-full-tck-regression-baseline
level: task
title: "S19: Full TCK regression baseline diff — verify byte-identical pass set"
short_code: "GQLITE-T-0273"
created_at: 2026-05-19T14:46:18.108953+00:00
updated_at: 2026-05-19T14:46:18.108953+00:00
parent: GQLITE-I-0039
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/todo"


exit_criteria_met: false
initiative_id: GQLITE-I-0039
---

# S19: Full TCK regression baseline diff — verify byte-identical pass set

## Parent Initiative

[[GQLITE-I-0039]]

## Objective

Capture `build/tck-results.json` immediately before S1 lands; compare against the post-S18 result. Pass scenario set must be byte-identical (or strictly larger if S7 unblocked the var-length / OPTIONAL MATCH classes). Closing this task closes the initiative.

## Acceptance Criteria

- [ ] Pre-initiative baseline saved.
- [ ] Post-initiative diff produces zero scenario regressions (and the gains from S7 are accounted for in the comparison).

## Status Updates

### 2026-05-20 — Defer until I-0043 lands

Final verification step for the original I-0039 scope. Should run
after GQLITE-I-0043 lands its Phase 5 (deletion of legacy
transform_expression and trio). The baseline reference point is the
TCK pass count at I-0039 start (3346) — current state is 3352-3357
band (within ±6 noise), so we have slight positive movement but
nothing dramatic from the migration itself.

When picked up: capture pre-/post- TCK results via
`tests/tck/baseline.json` and `tools/tck/report.py` (if exists) or
the equivalent JSON diff. Document the final delta in this task's
status, transition to completed, then close I-0039.
