---
name: oracle
description: Consults the oracle, a fresh read-only session on a strong model, for a second opinion on a plan, a bug, or a change. Use only when the user asks to consult or ask the oracle.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/oracle *)
---

The oracle sees only the briefing you write and the files it opens. The script `${CLAUDE_SKILL_DIR}/oracle` sets the model, the effort, and the tools.

1. Write the briefing to `./tmp/oracle/<YYYYMMDD-HHMMSS>.md` in the project root. Give it these sections:
   - Question: what the user wants to know, asked as a question to the oracle.
   - Goal: the outcome the user wants.
   - Constraints: the rules from the user and the repository that bind the answer.
   - Evidence: what was tried and what was observed, with commands, output, and errors.
   - Files: the paths the oracle reads first.

   Write facts and observations only. The oracle forms its own hypotheses. The step is complete when every section has content and every path in it exists.

2. Run `${CLAUDE_SKILL_DIR}/oracle <briefing>` with the longest timeout the shell tool allows. A consult takes several minutes. The last line of the output is `oracle session: <id>`.
3. When the answer ends with `## Context request`, write the requested items to a new file and run `${CLAUDE_SKILL_DIR}/oracle --resume <id> <file>`. Do this once.
4. Show the user the oracle's answer word for word. Then say which points you accept, which you reject and on what evidence, and your next step. When the answer changes the approach the user agreed to, ask the user before you change course.
