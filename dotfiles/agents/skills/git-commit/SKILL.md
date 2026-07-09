---
name: git-commit
description: Format, lint, test, and commit changes. Detects repo tooling automatically.
argument-hint: [message]
allowed-tools: Bash(git *), Read, Glob, Grep
disable-model-invocation: true
---

Commit all changes in the repo with proper formatting, linting, and testing.

## 1. Gather Context

Check what tooling exists:

!`ls -la package.json Makefile Cargo.toml pyproject.toml go.mod 2>/dev/null || true`

!`cat package.json 2>/dev/null | head -50 || true`

Study the repo's commit message style:

!`git log --oneline -20 2>/dev/null || true`

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
4. **Sync lockfiles**: If a dependency manifest is among the changes (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`), reconcile its lockfile so it is not left behind - `npm install --package-lock-only` (or `pnpm install --lockfile-only` / `yarn install --mode update-lockfile`), `cargo generate-lockfile`, `go mod tidy`, etc. Stage the refreshed lockfile in the same commit as the manifest change. This is what stops a later `install` from dirtying the tree.
5. **Plan commits**: Look at the git log style. If the repo favors small, focused commits (one logical change each), split the staged/unstaged changes into multiple commits - group related files together by logical change. If the repo uses larger commits, a single commit is fine.
6. **Stage & commit**: For each logical group, `git add` the relevant files by path (never `git add -A` - avoid staging `.env`, credentials, or large binaries) and commit with a message matching the repo's style. Go from most independent change to most dependent.

If `$ARGUMENTS` is provided, use it as the commit message for a single commit of all changes. Otherwise, generate messages matching the repo's commit style, splitting into multiple commits when it matches the repo's pattern.

Fix any formatting/lint issues automatically. If tests fail, report and stop. After the final commit, run `git status` - the tree must be clean; if a sync or build step left changes behind, fold them into the relevant commit before finishing.
