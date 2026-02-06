---
name: lgtm-plan
description: Open the current plan file in lgtm for user review
allowed-tools: Bash(lgtm *), Bash(tmux *), Read
---

Open the plan file in lgtm so the user can review and add feedback. After the user quits the TUI, read their feedback and return it to the conversation.

## When to use
After generating a plan file, invoke this skill to open it for user review.

## Steps

1. Determine the export path based on the plan file basename:
   ```
   /tmp/lgtm-plan-{basename}.md
   ```

2. Run lgtm in the background (the user may take a long time to review):
   ```bash
   lgtm $ARGUMENTS --export-on-quit /tmp/lgtm-plan-{basename}.md
   ```
   Use `run_in_background: true` on the Bash tool call.

3. Wait for the user to finish reviewing by polling with `TaskOutput` (use `block: true` with `timeout: 600000`). If it times out, keep polling — never give up.

4. After the TUI exits, read the exported feedback file:
   ```bash
   Read /tmp/lgtm-plan-{basename}.md
   ```

5. Present the user's feedback and incorporate it into your response.

Note: If the user has `LGTM_TMUX=1` set, this will open in a tmux split. Otherwise it opens in the current terminal.
