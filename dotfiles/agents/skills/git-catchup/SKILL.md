---
name: git-catchup
description: Understand current work context from recent changes. Use at session start or when resuming work.
argument-hint: [range]
allowed-tools: Bash(git *), Read, Glob, Grep
disable-model-invocation: true
---

Review recent git activity and build a picture of what's in progress.

## Branch & Tracking

!`git branch -vv --no-color 2>/dev/null | head -20`

## Recent Commits

!`git log --oneline --graph -15`

## Current Changes

!`git status --short`

!`git diff $ARGUMENTS`

!`git diff --cached`

## Stashed Work

!`git stash list 2>/dev/null | head -5`

## Instructions

Synthesize a concise briefing:

1. **Where we are**: current branch, how it relates to remote (ahead/behind), any active rebase/merge
2. **What changed recently**: group the recent commits by theme — what features, fixes, or refactors are in flight
3. **Work in progress**: uncommitted changes and what they appear to be doing
4. **Parked work**: anything in the stash worth noting

If the changes touch specific subsystems, read key files to understand the current state rather than guessing. Keep the summary short — the goal is orientation, not a full code review.
