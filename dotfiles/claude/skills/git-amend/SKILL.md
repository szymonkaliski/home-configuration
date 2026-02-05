---
name: git-amend
description: Format, lint, test, and amend the current commit. Detects repo tooling automatically.
argument-hint: [message]
---

Amend the current commit with all changes, after formatting, linting, and testing.

## 1. Gather Context

Check what tooling exists:

!`ls -la package.json Makefile Cargo.toml pyproject.toml go.mod 2>/dev/null || true`

!`cat package.json 2>/dev/null | head -50 || true`

!`git log --oneline -5`

## 2. Current Changes

!`git status`

!`git diff`

!`git diff --cached`

## 3. Execute

Based on what you found:

1. **Format**: Run formatter if available (prettier, black, gofmt, cargo fmt, nixfmt, etc.)
2. **Lint**: Run linter if available (eslint, tsc --noEmit, clippy, etc.)
3. **Test**: Run tests related to changed files if test runner exists
4. **Stage**: `git add -A`
5. **Amend**: `git commit --amend` - if `$ARGUMENTS` provided, use as new message; otherwise keep existing message with `--no-edit`

Fix any formatting/lint issues automatically. If tests fail, report and stop.

IMPORTANT: This amends the last commit. Do NOT use on commits already pushed to shared branches.
