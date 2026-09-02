# Project Instructions

## GitHub Issue Language

All GitHub issue content must be written in English. This requirement applies to issue drafts, titles, descriptions, comments, implementation reports, and evidence summaries.

## Upstream Contributions

Do not open issues or pull requests against the upstream repository
`colliery-io/graphqlite`. All work stays in the `Mineru98/graphqlite` fork
(`origin`); `upstream` is a read-only remote used only for `git fetch`.

On 2026-09-02 the maintainer closed issues #100 and #102 as `NOT_PLANNED`
along with PRs #101 and #103, stating that Python and Rust are the only
bindings that can be maintained in-tree and that a TypeScript binding should
be hosted in a separate repository, following the PHP bindings pattern.

Always pass `--repo Mineru98/graphqlite` to `gh issue` and `gh pr` commands,
since `gh` routes fork repositories to upstream by default.
