---
name: explain-diff
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces a single-file React explainer page served locally with hot reload.
---

# Explain Diff

This skill specializes the `explain` skill for code changes. First read `SKILL.md` from the sibling `explain` skill directory (`../explain/SKILL.md` relative to this file) and follow everything in it; below is only what's specific to explaining a diff.

## Arguments

`$ARGUMENTS` names the change to explain: a commit range, branch, PR number, or file paths. If empty, explain the current working change, which is the **union of unstaged, staged, and untracked-new files** (not just what `git diff` prints); if that's empty too, explain the latest commit.

## Grounding

- Gather the whole change before writing anything, and never trust a bare `git diff`: it shows unstaged edits only. A freshly `git add`ed new file appears **only** in `git diff --cached`; an untracked file appears in **neither**. So plan from the union: `git status --short` for the full picture, then `git diff` and `git diff --cached` for tracked hunks, and read the untracked new files (the `??` entries) directly. Missing a staged-new or untracked file is the most common way this skill silently under-covers a change.
- Derive the walkthrough order from the changes themselves: background (docs, specs, config) first, then new files, then modified/integration files, then tests. Group by concept, never alphabetically.
- Weight by significance, not by whether a change has runtime behavior. A large new documentation, prompt, or config file (a new `SKILL.md`, a schema, a big README) is often the most important part of a diff even though it has no algorithm to trace. Do not demote it to a one-line footnote just because an algorithmic change nearby is easier to render as a ladder of abstraction. If a new file is among the largest additions, it earns its own section.
- Skip generated files (lockfiles, generated API reports, snapshots, changelogs, vendored code). At most a one-line mention that they changed.
- Every claim in the explanation must trace to an actual hunk or to surrounding code you have read. If the diff contradicts the commit message, the PR description, or your recollection, the diff wins.

## Sections, specialized to a diff

- **Background** covers the existing system relevant to this change; broadly explore the surrounding code for it.
- **Intuition** explains the core idea of the change with toy data.
- **The substance** is a **Code** section: a literate diff. Walk through the changes at a high level, grouped and ordered per the Grounding rules above, not file by file.
- **Quiz** tests understanding of this change specifically: around five interactive multiple-choice questions at medium difficulty, hard enough that you actually need to have followed the change to answer them but not gotchas, so the reader can confirm they've grasped what it does and why. When the reader clicks an answer, tell them whether they were correct and give feedback. This is the one exception to explain's no-hidden-interactivity rule: the answer stays hidden until the reader commits to a choice, since reveal-on-click is the point. Hold the reader's choices in one top-level `useMorph({})` keyed by question id (`answers.q3`); each pick persists into the document and logs a `mutate` line, so you can read the file to see how the reader did.
- In the ladder of abstraction, the compared variants are the old and new code paths: run them as parallel film strips and parallel grid rows over the same toy data, and point out the cases whose outcome the change flips.
