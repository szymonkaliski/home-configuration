## Code

- don't add comments to code you didn't write
- prefer discriminated unions over optional fields; make illegal states unrepresentable

## Investigation

- never speculate - "probably" or "likely" is not evidence, show the log line or code path
  - don't guess root causes; read the code, check logs, or add instrumentation to confirm before proposing a fix
  - if you haven't opened a file, you cannot make claims about what it contains
  - "I don't know" is a valid answer, say it, then investigate

- when designing an approach before writing code, use web search to check documentation and recent GitHub issues

- never dismiss errors, warnings, or failing tests as "pre-existing" or "not caused by my changes" - you are the sole developer - all issues are your responsibility
  - when you encounter errors during builds, linting, typechecks, or tests that you didn't introduce, flag them and offer to fix them rather than skipping over them

- if a request is ambiguous or spans multiple reasonable approaches, ask one or two clarifying questions before implementing

## Subagents

- fan out independent read-only work (codebase search, multi-file research, doc/web lookups) to parallel subagents, launched in one message
  - only when tasks are independent with no shared writes - subagents can't share context or nest
- an unrelated edit that comes up mid-session - hand it to a background subagent editing the live tree, keep working the main thread
  - only when its files don't overlap the main thread's or another agent's - watch shared files (lockfiles, configs, anything a formatter rewrites); if overlap is unavoidable, keep it inline instead
  - give it a complete spec up front - no supervision once it's running - and review the result before trusting it
- prefer background subagents for research/analysis whose results aren't blocking the current step
- don't parallelize a single edit or dependent steps

## Shell / environment

- for running ad-hoc shell commands from nixpkgs, use `nix run nixpkgs#<pkg> -- <args>` (for example: `nix run nixpkgs#poppler_utils -- pdfinfo [...]`); prefer it over trying to write ad-hoc code
- use `trash` instead of `rm` (only if already available)

- use `./tmp/` in the project root for any temporary/scratch files (repro scripts, test fixtures, debug output, etc.) - it's globally gitignored
  - create it if it doesn't exist
  - if you have to write ad-hoc code, use `node` instead of `python`
  - when struggling to understand a library, git clone it into `./tmp/` and review the code there

## tmux

- when running in tmux, the other panes' contents are written to `/tmp/tmux-panes-$TMUX_PANE.txt` on demand by a `PreToolUse` hook that fires just before a Read of that path - so access it with the **Read tool**, not `cat`/Bash (Bash bypasses the hook and the file reads empty)
  - always run `echo $TMUX_PANE` first to get the actual pane ID, never guess it
  - use the Read tool on the file when you need to see adjacent panes; use `capture-pane` for more or live context
  - send commands to these panes with `tmux send-keys -t <pane_id> 'command' Enter`
  - when sending commands to other panes, do NOT pipe through `tail` or truncate output, let the full output show so you can read it back with `capture-pane`

- create new tmux splits with `tmux-smart-split` (auto-picks direction from pane dimensions), not `tmux split-window`

## Prose

- do not use em-dashes

## Skills

- when using the playground skill, write HTML files to `./tmp/` and serve with `serve` (zsh function) from `./tmp/` instead of using `open`
