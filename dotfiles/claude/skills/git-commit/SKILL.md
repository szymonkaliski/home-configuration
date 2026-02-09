---
name: git-commit
description: Format, lint, test, and commit changes. Detects repo tooling automatically.
argument-hint: [message]
---

Commit all changes in the repo with proper formatting, linting, and testing.

## 1. Gather Context

Check what tooling exists:

!`ls -la package.json Makefile Cargo.toml pyproject.toml go.mod 2>/dev/null || true`

!`cat package.json 2>/dev/null | head -50 || true`

Study the repo's commit message style:

!`git log --oneline -20`

Note the pattern: conventional commits? imperative mood? lowercase? prefix? scope? Look at casing, punctuation, length, and structure. Your commit message MUST follow this pattern.

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
5. **Commit**: Create commit message matching repo's existing style (from git log)

If `$ARGUMENTS` is provided, use it as the commit message. Otherwise, generate one matching the repo's commit style.

Fix any formatting/lint issues automatically. If tests fail, report and stop.
