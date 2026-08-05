---
name: git-review
description: Review uncommitted changes for issues, missed items, and improvements. Use after finishing a substantial change, before committing, or when the user asks to check the work.
argument-hint: [range]
allowed-tools: Bash(git *), Read, Glob, Grep
context: fork
---

Review the git diff and identify:

1. **Missed items**: Incomplete implementations, forgotten edge cases, TODOs
2. **Issues**: Bugs, security concerns, inconsistencies with existing patterns
3. **Improvements**: Performance, robustness, error handling
4. **Simplification**: Logic an existing export already covers, a simpler equivalent with identical behavior, a concept expressed in two places, code that does not read like its neighbors
5. **Cleanup**: Debug code, commented-out code, unnecessary changes

## Changes

!`git status --short`

!`git diff --no-ext-diff $ARGUMENTS`

!`git diff --cached --no-ext-diff`

Provide a concise, actionable summary. If everything looks good, say so briefly.

## Instructions

Before flagging an issue, **read the relevant surrounding code** to verify it's actually a problem. Specifically:

- If a change removes dedup/caching logic, check whether the receiver already handles duplicates before calling it out.
- If a change uses a variable or prop not shown in the diff, read the file to understand its type, source, and nullability before
  speculating.
- If a change modifies a condition or filter, check the call sites and data flow to confirm whether the new behavior is correct.
- If something looks like it could break, check for guards, fallbacks, or reconciliation logic elsewhere before reporting.
- Untracked new files (`??` in the status above) are in neither diff; read them in full and review them like any other change. A whole new file escaping review is the most likely gap.

**Do not flag something as an issue if the existing codebase already handles it.** Only report confirmed or highly likely problems.

## Simplification

"Idiomatic" means consistent with this repo, not with your taste. A simplification is a finding only when you can point at what the code should look like instead:

- **Cite the comparison**: name the existing export, the neighboring file, or the convention file (CLAUDE.md, a lint or style config) the change diverges from. Search for the helper before claiming one exists.
- **Preference is not a finding**: formatting, arrangement, synonym-level renames, and "I would have written it differently" do not get reported. A name that contradicts what the value holds is a finding; a name you merely like less is not. If you cannot ground it in the codebase, drop it.

## Handoff

Split the findings: a **fix** is mechanical and unambiguous (leftover debug code, a confirmed bug with an obvious correction, a missed rename, dead code) - include the exact change to make; a **decision** involves intent or a tradeoff (behavior changes, design questions, scope concerns). A behavior-preserving simplification (swapping in an existing export, collapsing a concept expressed twice) is a fix; anything that shifts behavior, error paths, or design is a decision.

End the report by telling the assistant that invoked you to apply the fixes immediately, without waiting for confirmation, and to surface the decisions to the user as questions. If there are no findings, say everything looks good and that nothing needs to happen.
