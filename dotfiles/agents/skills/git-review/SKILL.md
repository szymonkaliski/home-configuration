---
name: git-review
description: Review uncommitted changes, a branch, or a pull request. Use after a substantial change, before committing, or when asked to review the work.
allowed-tools: Bash(git *), Bash(gh pr *), Bash(mkdir *), Read, Edit, Write, Glob, Grep, Agent, Task
---

Review changes through two opposing lenses: **Saboteur** (bugs, blast radius, missed items) and **Minimalist** (simplification, conventions, cleanup).

## 1. Scope the target

Pick the target in this order:

1. **Named target** (branch, ref, commit range, or PR from the user): `git diff --no-ext-diff <base>...<head>` (or `<range>`) or `gh pr diff <pr>`.
2. **Uncommitted changes** (`git status --short` has output): `git diff --no-ext-diff HEAD` plus untracked files (`git ls-files --others --exclude-standard`).
3. **Feature branch** (clean working tree ahead of the default branch): `git diff --no-ext-diff <default-branch>...HEAD`.

When the diff is empty and no untracked files exist, tell the user and stop.

A **small diff** is ≤ 20 changed lines in 1 file with 0 untracked files. For a **larger diff**, write the diff to `./tmp/git-review.diff` (`mkdir -p ./tmp`). The step is complete when every changed and untracked path is listed and `./tmp/git-review.diff` exists for a larger diff.

## 2. Run the review

- **Small diff**: review inline across both lenses below, applying `Verification`. Judge the diff as written.
- **Larger diff**: spawn 2 read-only subagents in parallel in one message, one per lens. For a _cold start_, pass each subagent only `./tmp/git-review.diff`, the list of changed and untracked paths, its lens brief below, and `Verification` pasted in full. Each subagent reviews directly with `Read`, `Grep`, and `Glob`.

## 3. Judge and handoff

When subagents ran, read the cited `file:line` for each finding and check it against the code and the decisions from this session. Keep only findings that hold up.

Split surviving findings into **fixes** and **decisions**:

- A **fix** is `CONFIRMED`, mechanical, and unambiguous (leftover debug code, a confirmed bug with an obvious correction, a missed rename, dead code, swapping in an existing export, collapsing a concept expressed twice).
- A **decision** involves intent, a tradeoff, or uncertainty (`PLAUSIBLE` findings, or anything that shifts behavior, error paths, design, or scope).

When the target is checked out, apply all fixes immediately without waiting for confirmation, report what you changed, and ask the user the decisions. When the target is not checked out, report both fixes and decisions without editing the working tree. When no findings survive, say that everything looks good and nothing needs to happen.

## Lenses

### Saboteur (bugs, blast radius, missed items)

Assume the change is broken or incomplete. Hunt for:

1. **Missed items**: Incomplete implementations, forgotten edge cases, TODOs, and call sites, sibling modules, types, schemas, tests, or docs that needed a matching update.
2. **Defects**: Logic bugs, broken assumptions, null or empty inputs, ordering or race conditions, partial failure states, swallowed errors, performance traps, and security or trust-boundary gaps.

### Minimalist (simplification, conventions, cleanup)

Assume the change fights the codebase or adds weight it does not need. Hunt for:

1. **Simplification**: Logic an existing export already covers, a simpler equivalent with identical behavior, a concept expressed in two places, dead code, or speculative abstractions. Search for a helper before claiming one exists.
2. **Conventions and cleanup**: Code that diverges from neighboring files, `AGENTS.md`, `CLAUDE.md`, or a lint/style config, names that contradict what a value holds, leftover debug code, commented-out code, and unnecessary edits.

Ground every simplification or convention finding in the codebase by citing the existing export, the neighboring file, or the rule in `AGENTS.md`, `CLAUDE.md`, or a lint/style config. Also report any confirmed bug you spot while reading a file.

## Verification

Read the surrounding code before flagging an issue:

- Removed dedup or caching logic: check whether the receiver already handles duplicates.
- Variable or prop outside the diff: read the file for its type, source, and nullability.
- Modified condition or filter: trace the call sites and data flow to confirm the new behavior fails.
- Apparent failure path: check for guards, fallbacks, or reconciliation logic elsewhere.
- Untracked files (`??`): read them in full and review them like any other change. A whole new file escaping review is the most likely gap.

Report only issues that the existing codebase does not already handle. Each finding cites `file:line` and the proving code (caller, guard, helper, or data flow), labeled **CONFIRMED** when traced end to end or **PLAUSIBLE** when the code points to it without an end-to-end trace.

The review pass is complete when every changed and untracked path has been read and judged.
