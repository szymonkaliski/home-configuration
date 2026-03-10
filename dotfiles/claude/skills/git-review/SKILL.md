---
name: git-review
description: Review uncommitted changes for issues, missed items, and improvements. Use when reviewing before commit or when user asks to check their work.
argument-hint: [range]
allowed-tools: Bash(git *), Read, Glob, Grep
context: fork
disable-model-invocation: true
---

Review the git diff and identify:

1. **Missed items**: Incomplete implementations, forgotten edge cases, TODOs
2. **Issues**: Bugs, security concerns, inconsistencies with existing patterns
3. **Improvements**: Clarity, performance, maintainability
4. **Cleanup**: Debug code, commented-out code, unnecessary changes

## Changes

!`git diff $ARGUMENTS`

!`git diff --cached`

Provide a concise, actionable summary. If everything looks good, say so briefly.

## Instructions

Before flagging an issue, **read the relevant surrounding code** to verify it's actually a problem. Specifically:

- If a change removes dedup/caching logic, check whether the receiver already handles duplicates before calling it out.
- If a change uses a variable or prop not shown in the diff, read the file to understand its type, source, and nullability before
  speculating.
- If a change modifies a condition or filter, check the call sites and data flow to confirm whether the new behavior is correct.
- If something looks like it could break, check for guards, fallbacks, or reconciliation logic elsewhere before reporting.

**Do not flag something as an issue if the existing codebase already handles it.** Only report confirmed or highly likely problems.

