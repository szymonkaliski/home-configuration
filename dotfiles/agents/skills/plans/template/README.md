---
version: 1
---

# Plans

A plan is a dated working note for one piece of work. It holds the goal, the todos, and the context that a reader with no memory of the session needs to continue the work. A plan is committed on the branch that does the work.

The `plans` skill manages this file. An update of the skill replaces the text.

## Files

- One plan per file: `plans/YYYY-MM-DD-<slug>.md`. The date is the day the plan was written.
- A new topic gets a new file.
- Material that a plan needs and that git does not hold goes in `plans/YYYY-MM-DD-<slug>/`, beside the plan. Examples: a patch, a capture, a table of measurements.

## Format

```markdown
---
status: open
---

# <title>

<goal: what is true when the work is done, and why it matters>

## Start here

<the first action for a reader with no context>

## Todos

- [ ] <action>
  - verify: <command or observation that proves the action is complete>

## Context

<the facts that the reader needs>

## Decisions

<each decision that is made, with its reason>

## Rejected

<each approach that was tried or considered and then dropped, with its reason>

## Log

<dated entries, newest last>
```

- Cite a tracked file as `path:line`, a commit by its hash, and a source by its URL. Cite material that travels with the repository.
- Omit a section that has no content.

## Status

| Status   | Meaning                                       |
| -------- | --------------------------------------------- |
| `open`   | the work is not started                       |
| `active` | the work is in progress                       |
| `parked` | the work is on hold, and the plan says why    |
| `done`   | the work is finished, and the plan is history |

## Rules

- Work on a plan only when the user asks. The todos of an `open` or `active` plan are current.
- While you work on a plan, keep it current: tick the todos, add dated entries to `Log`, and update `Start here`.
- To finish a plan:
  1. Move each open todo to a new plan.
  2. Add an `Outcome` section below the goal: what was done, which commits did it, and which plans follow.
  3. Set `status: done` and add `closed: YYYY-MM-DD` to the frontmatter.
- A `done` plan is history. Read it to learn why a thing was done. Its text stays as it was on the close date.
- When a plan and the code differ, the code is correct.

## List the plans on all branches

Plans live on the branch that wrote them. These commands list the plans that are not done, on every branch, without a checkout:

```sh
git fetch --all --quiet
git grep -l -E '^status: (open|active|parked)' \
  $(git for-each-ref --format='%(refname)' refs/heads refs/remotes) \
  -- ':(glob)plans/*.md'
```

Each output line is `<ref>:plans/<file>`. Read a plan with `git show <ref>:plans/<file>`.

A plan can have different copies on different refs. The copy with the newest commit counts, so a plan that one ref shows as `open` can be `done` on another ref. Get the commit time of a copy with `git log -1 --format=%ci <ref> -- plans/<file>`.
