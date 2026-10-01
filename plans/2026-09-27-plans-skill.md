---
status: done
closed: 2026-10-01
---

# Plans skill: capture, list, and resume work plans in any repository

Each repository that the user works in gets a `plans/` directory with one markdown file per plan. An agent writes a plan at the end of a session. A later session, on any machine and any branch, lists the plans and continues one. Today the user types the capture prompt by hand, the plans have no common shape or status, and a plan on one branch is invisible from another branch.

## Outcome

The skill exists and is installed on minix. Commit `adc659c` added `dotfiles/agents/skills/plans/` (the skill text, the script, and the README template at version 5), `bin/plans`, the pointer line in `AGENTS.md`, and the two files in `plans/`. Commit `daac833` made `bin/microvm` copy the skills into a staged VM at each start. A second repository with 25 old plans adopted the convention, and its listing on `main` shows a plan that lives on another branch. Commit `7cb1435` on `dev/vaillant-rf` holds the first plan of this repository, and that branch stays local. No plan follows. The laptop gets the skill with a pull and `home-manager switch`.

## Start here

Each todo is complete. The work in this repository is not committed. Ask the user for the commit, then finish this plan with the steps in `plans/README.md`.

State on 2026-09-28: the skill is installed on minix (`dotfiles/agents/skills/plans/`, staged with `git add`, not committed). `bin/plans`, the `bin/microvm` change, the `AGENTS.md` pointer line, and the files in `plans/` are not committed. Commit `7cb1435` on `dev/vaillant-rf` is not pushed, and the branch stays local by user decision. The script has no test file.

## Todos

- [x] Review `plans/README.md` and this plan with the user.
  - verify: the user confirms the format, the statuses, and the rules
- [x] Get a user decision on each item in `Decisions` that is marked "proposed".
  - verify: no item in `Decisions` is marked "proposed"
- [x] Move the README text to `dotfiles/agents/skills/plans/template/README.md`. That file is the single source. `plans/README.md` in each repository is a copy.
  - verify: `diff plans/README.md dotfiles/agents/skills/plans/template/README.md` prints nothing
- [x] Write the script `dotfiles/agents/skills/plans/plans` with the commands in `Context`, section "Script".
  - verify: a test in `tmp/` with one bare remote and three clones. Two clones write different plans on different branches and push. The third clone is on `main` and `plans list` shows both plans
  - verify: a plan that is `done` on one branch and `open` on an older branch shows as `done`
  - verify: `plans init` replaces a README with a lower version and keeps a README with a higher version
- [x] Write `dotfiles/agents/skills/plans/SKILL.md` with three branches: capture, resume, close. Load the `writing-for-agents` skill first.
  - verify: a new session in a scratch repository gets the prompt "capture the plan". The result is a file in `plans/` that `plans list` shows
- [x] Link `bin/plans` to the script.
  - verify: `plans list` runs from a new shell in this repository
- [x] Run `git add` on the new skill, then `home-manager switch` (commands in `CLAUDE.md`).
  - verify: `~/.claude/skills/plans/SKILL.md` and `~/.gemini/config/skills/plans/SKILL.md` exist
- [x] Make the skill reach microVMs that are already staged.
  - verify: `ls ~/.claude/skills/plans` in a VM that was staged before the skill existed
- [x] Try the skill in agy inside a microVM. The VM wrapper starts agy with its skip-permissions flag (`nix/hosts/minix/microvms/setup.sh`).
  - verify: agy gets the prompt "capture the plan" in a scratch repository, and `plans list` shows the plan it writes
- [x] Convert `nix/hosts/berry/vaillant-rf.md` on the branch `dev/vaillant-rf` (commit `de941c3`) to `plans/2026-09-27-vaillant-rf.md`. This is the first real plan.
  - verify: `plans list` on `main` shows the plan with the ref `dev/vaillant-rf`
- [x] Try the skill in a second repository that has plans in the old form.
  - verify: the user resumes one plan there from a different branch

## Context

### The problem

The user types a prompt like this many times each week: "capture the plan in md file with all the context, actionable todos (`- [ ] ...`), so we can pick it up later". One session often gives several plans: follow-up ideas, things to return to, places to start again. The user returns to some of them after days.

The user starts up to 4 microVMs on one repository. Each VM has its own `dev/...` branch, writes plans, and pushes. Later the user is on a laptop on `main` and fetches all branches. No command shows all plans, so the user cannot choose one and continue.

### Requirements

1. Plans are in git and travel with a push.
2. Several branches and machines write plans at the same time with no merge conflict.
3. One command lists the plans of all branches, with status, from any branch.
4. The design works in each repository with no setup by hand.
5. An agent that does not have the skill can follow the rules. Other people commit to some of the repositories.
6. Finished plans stay available. They show why a thing was done.
7. An old plan does not mislead an agent.

### Evidence in this repository

- The branch `dev/vaillant-rf` adds `nix/hosts/berry/vaillant-rf.md` in commit `de941c3`. The file is a plan with a goal, constraints, known facts, numbered steps, and a log. It has no status and no checkboxes. From `main` it is invisible.
- home-manager links each directory in `dotfiles/agents/skills/` to `~/.claude/skills` and `~/.gemini/config/skills` (`nix/modules/home/common.nix:14`). Flake evaluation sees tracked files only, so a new skill needs `git add`.
- A microVM gets `~/.claude` by `rsync -aL` at its first staging (`bin/microvm:62`). At each later start it gets only the auth tokens and the skill directories of both harnesses (`bin/microvm:48-56`). A script inside the skill directory travels with the skill.
- A microVM gets only the `git-minix-*` scripts from `bin/` (`bin/microvm:37`). A script in `bin/` alone does not reach the VMs.
- `node` is present on the hosts (`nix/modules/home/common.nix:50`) and in the VMs (`nix/hosts/minix/microvms/base.nix:53`).

### Evidence from a second repository

The user has a second repository with 25 plans from the hand-typed prompt. An analysis on 2026-09-27 gave these results:

- No plan has frontmatter. Status is prose in 10 different forms. 2 plans have no status.
- The status contradicts the content in 5 plans. One plan says "not started" above 27 ticked boxes.
- 17 plans cite files in `tmp/`, which git ignores. One patch exists only there.
- The median length is 178 lines and the longest plan has 950 lines. In one plan the open items start at line 349 of 390.
- An index that is kept by hand omits 2 plans.
- Strengths: measurements with commands and commit hashes, sections for decisions and for rejected approaches, todos with a verification line.

A scan of all 13 refs of that repository (1,871 tracked files) took 74 ms with `git ls-tree` and 37 ms with `git grep`.

### Script

The script does the mechanical work. It is a single `node` file with no dependencies.

| Command                        | Action                                                                                                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `plans init`                   | creates `plans/` and `plans/README.md`. Refuses when `plans/` exists                                                                                   |
| `plans new <slug>`             | creates `plans/YYYY-MM-DD-<slug>.md` with the frontmatter and the section headings. Brings the README up to the template                               |
| `plans list [--all]`           | scans `plans/*.md` in the working tree and on all refs. Shows each plan once, below a header row: status, open and all todos, date, pushed, name, refs |
| `plans show <name>`            | prints the newest copy of a plan and names its ref                                                                                                     |
| `plans status <name> <status>` | sets the status in the working tree copy. `done` also adds `closed:`                                                                                   |

Rules for `list`:

- A plan is identified by its file name.
- When refs hold different copies of a plan, the newest copy counts. The age of a copy is the time of the last commit that changed the file on that ref. A changed copy in the working tree is newer than each commit.
- `DATE` is the local date of the newest copy: the commit date, or the file date for a working-tree copy.
- `PUSHED` is `no` when the newest copy is on no remote ref.
- `list` reads the files that have a `status` in the frontmatter. The README has none.
- A merge commit counts as a change to each file that differs from its first parent. Without this rule, a plan that changed only in a merge gets the time of an older commit.
- A detached HEAD counts as a ref.

Rules for the README:

- The frontmatter of the README holds `version: N`.
- `new` writes the README when `plans/` has none, and replaces it when the template has a higher version.
- `new` keeps a README that has no version.

### Prior art

No published tool does this design. Parts of it exist:

| Tool                                                                                 | What it shares                                       | Why it is not used as is                                                                 |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [Backlog.md](https://github.com/MrLesk/Backlog.md)                                   | committed task files, status, reads other branches   | its lists for agents exclude other branches, IDs are sequential, it forbids direct edits |
| taskmd                                                                               | `tasks/NNN-slug.md` with a status in the frontmatter | no listing across branches, numeric IDs can collide                                      |
| OpenSpec                                                                             | fixed directory, finished work moves to an archive   | bound to its spec workflow                                                               |
| [willseltzer/claude-handoff](https://github.com/willseltzer/claude-handoff)          | capture and resume, `- [x]` and `- [ ]` sections     | one `HANDOFF.md`, no status, no branches                                                 |
| [mattpocock/skills](https://github.com/mattpocock/skills) `handoff`                  | short capture skill, "reference, do not duplicate"   | writes to the temporary directory of the OS, no todos                                    |
| [obra/superpowers](https://github.com/obra/superpowers) `writing-plans`              | dated plan files with checkboxes                     | depends on the other superpowers skills                                                  |
| [OpenAI ExecPlans](https://developers.openai.com/cookbook/articles/codex_exec_plans) | living plan with progress and a decision log         | a format only                                                                            |

The ExecPlans rule is the quality bar for a plan: "it should always be possible to restart from _only_ the ExecPlan".

Claude Code has no built-in feature for this. Plan mode, the task tools, and `--resume` keep their data in `~/.claude` on one machine, and a sweep deletes it after 30 days by default ([settings](https://code.claude.com/docs/en/settings-reference#plansdirectory), [sessions](https://code.claude.com/docs/en/sessions)). A skill with `context: fork` does not see the conversation, so the capture skill runs inline ([skills](https://code.claude.com/docs/en/skills)).

### Reports about old plans

- A stale plan was executed: "CC treats the stale plan as authoritative instructions and executes them with full confidence." ([claude-code#23509](https://github.com/anthropics/claude-code/issues/23509))
- An agent read another plan's progress as its own ([superpowers release notes](https://github.com/obra/superpowers/blob/main/RELEASE-NOTES.md)).
- An agent edited finished plans until the user added a rule against it ([memory file](https://github.com/chdalski/rlsp/blob/main/.ai/memory/feedback_no_edit_completed_plans.md)).
- Deny rules do not keep files from an agent. Claude Code deny rules "don't apply to a command that reads files without naming them, such as `grep -r pattern .`" ([permissions](https://code.claude.com/docs/en/permissions)).
- Architecture Decision Records are the known convention for a document with a status whose text does not change: "If a decision is reversed, we will keep the old one around, but mark it as superseded." ([Nygard](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions))

### Trials with `claude -p`

A new `claude -p` session runs the skill only in the default permission mode. In `--permission-mode acceptEdits`, the `Skill` tool is denied, and a loaded skill gets no `allowed-tools` grant. The working flags are `--allowedTools Edit Write`. `${CLAUDE_SKILL_DIR}` gets the unresolved path `~/.claude/skills/plans` in the text and in `allowed-tools`.

### Trial with agy in a microVM

agy finds the script through the path it read `SKILL.md` from, so it needs no `${CLAUDE_SKILL_DIR}`. In a VM, agy runs its shell commands in `/workspace`, the overlay of the project that the VM holds, and not in the directory it starts in. A trial in a scratch repository in the VM home therefore also writes to `/workspace`. On 2026-09-27 agy saw this and reverted its own changes there. Step 12 of that run shows the workspace clean before the trial, so no VM work was lost. Start the next agy trial with the scratch repository as the VM project (`microvm start --dir <repo>`).

## Decisions

Decisions by the user on 2026-09-27:

1. Plans live in `plans/` in the root of the repository. Reason: the directory is the marker, and a repository needs no setup.
2. The design is the same for all repositories. One repository is an example and does not set the design.
3. Finished plans stay in git as files. Reason: they show why a thing was done and what the context was.
4. A finished plan stays in its place and gets `status: done`. Reason: the path is stable.
5. The rules live in `plans/README.md` of each repository. The skill does not depend on the global `AGENTS.md`. Reason: an agent without the skill reads the README.
6. The skill creates `plans/` and the README, and it updates the README when the text in the skill changes.
7. A script does the mechanical work (section "Script"). Reason: the listing across refs and the README version check must give the same result each time.
8. The script lives in the skill directory, and `bin/plans` links to it. `SKILL.md` calls it as `${CLAUDE_SKILL_DIR}/plans`, and `allowed-tools` lists the same path, so the script runs with no permission prompt ([skills](https://code.claude.com/docs/en/skills)). Reason: the skill directory reaches the VMs and both harnesses.
9. The README has a version number, and `new` replaces a lower version only. Reason: a VM with an old copy of the skill must not put an old README back. The number is in the frontmatter (`version: N`), by user decision on 2026-09-27.
10. The write path is a plain file and a plain commit. Reason: a VM or a person with no script can write a plan.
11. The capture skill writes the files and leaves the commit to the user. Reason: the user's rule is no commit without a request.
12. The frontmatter holds `status` and `closed` only. Reason: git history gives the branch, the commit, and the dates.
13. The file name has the date and a slug, with no sequence number. Reason: sequence numbers collide when two branches write at the same time. Two branches can still pick the same date and slug. The user accepts this risk because it is rare, so `plans new` does not check other refs.
14. The skill is model-invoked, so the words "capture the plan" start it. Cost: its description is in the context of each session.
15. The agent owns the pointer to the rules. After `plans init`, the agent makes sure that the agent instruction file of the repository (`AGENTS.md` or `CLAUDE.md`) tells a reader about `plans/` and points to `plans/README.md`. When the file lacks this, the agent adds one line where it fits. The script has no check for it. Reason: an agent without the skill finds the rules, and the agent can judge where the line fits.
16. An agent works on a plan only when the user asks. Reason: an agent that finds an open plan must not start it by itself ([claude-code#23509](https://github.com/anthropics/claude-code/issues/23509)).
17. The README tells a reader without the script that the copy with the newest commit counts. Reason: a test on 2026-09-27 showed the `git grep` command list a plan as `open` from `main` while a newer branch had it `done`.
18. `bin/microvm` copies the skill directories of both harnesses into a staged VM at each start. Reason: a staged VM gets only the auth tokens (`stage_vm_home` in `bin/microvm`), so a new or changed skill does not reach it.
19. The user decides which plans exist. An agent creates a plan only when the user asks for it, and it can suggest one.
20. `plans init` refuses when `plans/` exists. Reason: on 2026-09-28 `init` replaced a hand-written `plans/README.md` with no question.
21. The capture check accepts a cited path that exists in the repository and that `git check-ignore` does not match. Reason: a new file is untracked until the user commits, and the skill leaves the commit to the user.
22. A staged VM keeps the files of a skill that the host removed. Reason: `microvm clean` deletes the home of the VM, and the next start copies the skills again.
23. A plan is `done` when the result that its title names exists. Follow-up work goes to a new plan. Reason: small plans are easier to manage, and a done plan with open todos reads as a contradiction in the list.
24. `open` means that work remains and nobody works on it now. `active` means that somebody works on it now. Reason: in the trial, no status fit a plan whose first part was complete while the rest waited.
25. `closed` is the day when the plan is set to `done`. Reason: in the trial, one plan had a close date that was earlier than work that the same plan records.
26. At the close of a plan, the agent reads the full text for open work. Reason: in the trial, a done plan with no open todo held 6 open items in a text section.
27. Open work that the user declines for a new plan goes into `Outcome` as not planned. Reason: in the trial, the user declined a new plan for 2 of 5 closed plans, and the README had no rule for it.
28. The listing across branches is enough for the last todo. Reason: in the second repository, `plans list` on `main` shows a plan that lives on a different branch.

## Rejected

| Approach                                     | Reason                                                                                                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Plans in `tmp/`                              | easy to delete by accident, and they do not travel to other machines                                         |
| One orphan `plans` branch                    | it separates a plan from its code, and each VM needs a tool to write. Beads had a sync branch and removed it |
| A separate repository for plans              | each VM needs a second clone and credentials                                                                 |
| `git notes`                                  | a note attaches to a commit, and a plan for later work has no commit                                         |
| Custom refs such as `refs/plans/*`           | a clone does not fetch them without a refspec                                                                |
| An issue tracker                             | the plans are not in git, and each VM needs a token                                                          |
| Plan mode, task tools, `--resume`            | the data is on one machine and expires                                                                       |
| Delete a finished plan                       | the user wants to read old plans. One project deleted all plans and restored them 4 weeks later              |
| A `plans/done/` directory                    | the user chose `status: done` in place                                                                       |
| A file name suffix (`*.plan.md`) at any path | the fixed directory is simpler                                                                               |
| Separate kinds for plans and records         | it came from one repository, and the user wants one design for all                                           |
| Steps for a migration in `SKILL.md`          | the user declined them                                                                                       |
| A `--closed <date>` argument for `status`    | the user declined it. An agent writes a historic close date by hand                                          |

## Log

- 2026-09-27: Research session. Four subagents covered published skills, built-in Claude Code features, storage practices, and the plans of a second repository. The design changed three times after user feedback: orphan branch, then plans on the work branch with a marker, then a fixed `plans/` directory. This plan and `plans/README.md` were written by hand in the target format, before the skill exists.
- 2026-09-27: Review session. The user confirmed decisions 7 to 15 and added 16 to 18. The README rule "act on a plan when its status is open" became "work on a plan only when the user asks". The README moved to `dotfiles/agents/skills/plans/template/README.md`.
- 2026-09-27: Build session. A subagent wrote the script and its test. The review added two `list` rules (merge commits, detached HEAD), each with a test that fails without it. `home-manager switch` installed the skill. A `claude -p` session in a scratch repository captured a plan with the skill, after three runs that failed on permission flags (section "Trials with `claude -p`"). The auto-mode classifier blocks `agy --dangerously-skip-permissions` on the host, so the agy trial moves to a VM.
- 2026-09-27: VM and agy session. vm-1, staged before the skill existed, got the skill at its next start. `git worktree` kept `main` untouched while commit `7cb1435` moved the vaillant plan on `dev/vaillant-rf`. The agy trial in vm-1 captured a plan (section "Trial with agy in a microVM"). By user decision, `init` no longer checks `AGENTS.md` or `CLAUDE.md` (decision 15), and `plans list` shows a header row, a date, and a `PUSHED` column.
- 2026-09-28: Rules session. Two user decisions changed the README (version 2) and `SKILL.md`: the user decides which plans exist (decision 19), and `plans/` holds markdown files only. At the close of a plan, the agent shows the open todos and the user decides.
- 2026-09-28: The user deleted the plan for the adoption in other repositories. An agent had written it with no request.
- 2026-09-28: The test file of the script is removed. The skill directory holds `SKILL.md`, the script, and the README template.
- 2026-09-28: Review session. A `git-review` gave six fixes and three decisions (20 to 22). One fix broke `list`, `show`, and `status` for about two minutes, because the script is live through a link and the fix was applied before a test. `init` now only creates, and `new` updates the README.
- 2026-09-28: Trial in a second repository, by a session in that repository. It moved 25 old plans to `plans/` with `git mv` after `plans init`: 1 active, 13 open, 5 parked, 6 done. 19 plans got the section layout, and the 6 done plans got frontmatter only. 22 files outside `plans/` got new citation paths. The result is not committed and the user has not reviewed it, so the last todo stays open. Findings for the skill: no status fits a plan whose first part is complete while the rest waits, `plans status <name> done` writes the date of today where a migration needs the date the work ended, and `SKILL.md` has no steps for a migration.
- 2026-09-28: User review of the trial in the second repository. 5 statuses changed: 11 done, 10 open, 4 parked, 0 active. 3 new plans took the open todos of closed plans, by user decision for each plan. Findings for the README: "the work is finished" kept plans open for small open todos, and a done plan with open todos shows as `done 9/37` in the list. The rule that the user accepted there: a plan is `done` when the result that its title names exists. The result is not committed, so the last todo stays open.
- 2026-09-28: README version 3, by user decision after the trial: new texts for `open`, `active`, and `done`, follow-up work goes to a new plan (decisions 23 and 24), and "To finish a plan" has four steps. The session in the second repository got the new rules and the permission of the user to refactor its plans again.
- 2026-09-28: README version 4, by user decision after a review of the trial: the meaning of `closed`, the check of the full text at the close of a plan, and the rule for open work that the user declines (decisions 25 to 27). The last todo is ticked (decision 28).
- 2026-09-28: Cleanup in the second repository under README version 4, not committed there. Each done plan has an `Outcome` and the close date 2026-09-28. Two new plans hold the follow-up work, and 6 items are not planned. The user removed one parked plan. It stays in `plans list` until each ref that holds the file has the removal, so a commit on a second branch removed it there too.
- 2026-10-01: README version 5, by user decision: a plan is one way to work, most work gets none, and the agent no longer suggests plans on its own. The one suggestion that stays is step 2 of "To finish a plan".
- 2026-10-01: Commits `adc659c` and `daac833` hold the work. The plan is done.
