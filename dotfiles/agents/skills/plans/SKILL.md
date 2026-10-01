---
name: plans
description: Work plans kept in the repository's `plans/` directory, readable from every branch. Use when the user asks to capture a plan for later, to list or resume plans, or to close or park a plan.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/plans *)
---

# Plans

A plan is a markdown file in `plans/` at the repository root. `plans/README.md` holds the format, the statuses, and the rules. Read it before you write or change a plan. When the working tree has no `plans/README.md`, read `${CLAUDE_SKILL_DIR}/template/README.md`.

The script `${CLAUDE_SKILL_DIR}/plans` does the mechanical work. `${CLAUDE_SKILL_DIR}/plans --help` lists its commands.

## Capture

The user asks to capture, save, or write down the plan for later.

1. Run `${CLAUDE_SKILL_DIR}/plans init`. Then make sure that the agent instruction file of the repository (`AGENTS.md` or `CLAUDE.md`) tells a reader about `plans/` and points to `plans/README.md`. When the file lacks this, add one line where it fits.
2. Split the session into topics: the main work, the follow-ups, and the ideas to return to. Each topic gets one plan. Run `${CLAUDE_SKILL_DIR}/plans list --all` to find the plans that already exist. A topic with a plan in the working tree updates that plan. A new topic gets `${CLAUDE_SKILL_DIR}/plans new <slug>`.
3. Replace each placeholder of the format. Write for a _cold start_: a reader with no memory of this session continues the work from the plan alone. `Start here` names the first action. Each todo has a `verify:` line. Each measurement keeps the command that produced it.
4. Check each plan. The step is complete when no placeholder is left, each path that the plan cites is tracked by git or sits in `plans/`, and `${CLAUDE_SKILL_DIR}/plans list --all` shows the plan.
5. Tell the user the path of each plan. The user decides when to commit.

## Resume

The user asks which plans exist, or names a plan to continue.

1. Run `git fetch --all --quiet`, then `${CLAUDE_SKILL_DIR}/plans list`. When the user did not name a plan, show the list and let the user choose.
2. Run `${CLAUDE_SKILL_DIR}/plans show <name>`. It prints the newest copy of the plan and names its ref.
3. When that ref is another branch, the code of the work is on that branch too. Ask the user before you switch to it.
4. A plan is a snapshot, and the code can be newer. Before you act, confirm in the code each fact that `Start here` and the first open todo depend on.
5. Do the action in `Start here`. Keep the plan current as the README says.

## Close

The work of a plan is finished, or it is on hold.

- Finished: follow "To finish a plan" in the README. Open todos go to a new plan through the capture steps. `${CLAUDE_SKILL_DIR}/plans status <name> done` sets the status and the close date.
- On hold: run `${CLAUDE_SKILL_DIR}/plans status <name> parked`, and add a dated `Log` entry that says why.
