---
name: git-review
description: Review uncommitted changes for issues, missed items, and improvements. Use when reviewing before commit or when user asks to check their work.
argument-hint: [range]
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
