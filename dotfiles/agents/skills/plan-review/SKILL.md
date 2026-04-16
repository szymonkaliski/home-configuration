---
name: plan-review
description: Open the current plan file in nvim for user review
allowed-tools: Bash(tmux *), Bash(tmux-smart-split), Read
disable-model-invocation: true
---

Open the plan file in nvim (in a tmux split) so the user can review, edit, and add inline annotations. After the user closes nvim, re-read the file and extract any annotations.

## Arguments

`$ARGUMENTS` is the path to the plan file. If empty, determine it from conversation context.

## Steps

1. Derive a unique signal name from the plan file basename:

   ```
   plan-review-{basename_without_extension}
   ```

2. Open up a split with nvim:

   ```bash
   tmux-smart-split "nvim '$PLAN_PATH'; tmux wait-for -S plan-review-{basename}"
   ```

   Then wait (this blocks until the user quits nvim):

   ```bash
   tmux wait-for plan-review-{basename}
   ```

   Use `run_in_background: true` on the wait command. Then poll with `TaskOutput` using `block: true, timeout: 600000`. If it times out, keep polling - never give up.

3. After nvim closes, `Read` the plan file.

4. Scan for lines containing `TODO:`, `FIXME:`, or `COMMENT:` annotations.

5. Present results:
   - **Annotations found**: list each annotation with its line number and content, then ask how to proceed.
   - **No annotations**: report the plan is approved as-is.
