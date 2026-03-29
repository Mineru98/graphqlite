---
id: rec-13-rust-extension-extraction
level: task
title: "REC-13: Rust extension extraction safety (atomic write, hash verify, noexec fallback)"
short_code: "GQLITE-T-0167"
created_at: 2026-03-28T13:59:30.936753+00:00
updated_at: 2026-03-29T00:33:22.152515+00:00
parent: GQLITE-I-0032
blocked_by: []
archived: false

tags:
  - "#task"
  - "#phase/active"


exit_criteria_met: false
initiative_id: GQLITE-I-0032
---

# REC-13: Rust extension extraction safety (atomic write, hash verify, noexec fallback)

## Objective

Harden the Rust embedded extension extraction with atomic writes, integrity verification, noexec fallback, and old version cleanup. Addresses findings OPS-004, SEC-007 (Major).

## Affected Files

- `rust/src/platform.rs` -- extension extraction logic

## What To Do

1. **Atomic write**: write extracted extension to a temp file, then rename into place (prevents partial files on crash)
2. **Content integrity**: compute SHA-256 of extracted bytes and compare against a hash embedded at build time
3. **Noexec fallback**: if extraction to temp dir fails (e.g., noexec mount), retry from `~/.cache/graphqlite/`
4. **Old version cleanup**: on successful extraction, delete any older versioned extension files in the same directory

## Acceptance Criteria

## Acceptance Criteria

- [ ] Extension extraction uses write-then-rename pattern
- [ ] SHA-256 verification runs on every extraction; mismatch returns error
- [ ] Noexec tmpdir triggers fallback to `~/.cache/graphqlite/`
- [ ] Old extension versions are cleaned up after successful extraction
- [ ] All Rust tests pass

## Effort Estimate

1-2 days

## Status Updates

*To be added during implementation*