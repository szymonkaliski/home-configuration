# Diff review playground

For reviewing code changes with line- or hunk-level commenting: git commits, branches, PRs. The reader's comments become the code-review feedback you act on. Follow `../SKILL.md` for the cross-cutting parts.

## Controls

| Decision                  | Control                                                                        |
| ------------------------- | ------------------------------------------------------------------------------ |
| Comment on a line or hunk | Click the line to open a textarea beneath it                                   |
| Comment indicator         | A badge on lines that carry a comment                                          |
| Edit or remove a comment  | Click a commented line to reopen its textarea; clearing it deletes the comment |
| Save / cancel             | Buttons in the comment box                                                     |

## Preview

The diff rendered with line numbers and +/− indicators, additions and deletions tinted (give each a light and a dark value, per the morph theme rule). Group by file, then hunk. Style the `@@` hunk header as its own line type (a distinct tint, conventionally blue) so hunk boundaries read apart from code. A hover hint on uncommented lines ("click to comment") makes the interaction discoverable.

## Pre-populate

Gather the real change with `git show <commit> -p`, or the branch or PR diff, and parse it into what the page renders: files, each file's hunks (keep the `@@` header line), each hunk's lines as `{ type: "context" | "addition" | "deletion", oldNum, newNum, content }`, walking both counters from the hunk header (`null` on the side a line doesn't exist on). Getting the dual numbering right is what makes the committed comments' `file:line` references correct. Include the commit metadata (hash, message, author) in the header. Skip generated files (lockfiles, snapshots).

## Reading it back

Model the comments as one top-level `useMorph({})` keyed by line or hunk id (per `../SKILL.md`'s State section), written on save, not per keystroke. Act on the committed config as structured review feedback: for each comment, the file, the line, the code, and what the reader said.

**Example.** A comment on `src/handler.py:45` ("this can throw if `tracker` is None") becomes an action: "At `src/handler.py:45`, guard the `tracker.register()` call: the reader flagged a possible None deref."

## Example topics

Git commit review (single commit, line comments), pull-request review (multiple commits, file- and line-level comments), before/after refactoring comparison, merge-conflict resolution (both versions annotated), security audit (findings per line).
