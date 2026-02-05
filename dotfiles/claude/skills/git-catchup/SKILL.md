---
name: git-catchup
description: Understand current work context from recent changes. Use at session start or when resuming work.
argument-hint: [range]
disable-model-invocation: true
---

Review recent git activity to understand what we're working on.

## Recent Commits

!`git log --oneline -10`

## Current Changes

!`git diff $ARGUMENTS`

!`git diff --cached`

Summarize what we're working on based on recent commits and current changes.
