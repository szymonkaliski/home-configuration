---
name: tmux
description: Read and control tmux panes from inside a tmux session - see what other panes show, send commands to them, create splits, run long-lived processes. ALWAYS use when asked about another pane, before running any tmux command, or when a command needs a real TTY or would outlive the shell tool timeout.
---

# tmux

You are usually inside the user's own tmux session, on purpose: it is a shared surface where you and the user exchange information - they can watch what you run, you can read what they have open. Work in it directly, and treat sibling panes as shared space, not scratch space.

## Orient first

- if `$TMUX` is empty you are not inside tmux and none of this applies
- `echo $TMUX_PANE` gives your own pane id - never guess pane ids
- map what exists: `tmux list-panes -F '#{pane_id} #{pane_index} #{pane_current_command} #{?pane_active,active,}'`
- prefer pane ids (`%3`) over `session:window.pane` targets - ids are unambiguous

## Reading panes

- visible contents: `tmux capture-pane -p -t '%3'`
- scrollback: `tmux capture-pane -p -J -S -200 -t '%3'` (`-J` joins wrapped lines, `-S -` for full history)
- full-screen programs (vim, less, htop) draw on the alternate screen - capture while the program is running; contents vanish when it exits; add `-e` when colors/attributes carry meaning (TUI state)

## Sending input

- send text literally, then Enter as a separate send - multiline or special-char text in one send triggers bracketed paste, which is not the same as typing:

  ```sh
  tmux send-keys -t '%3' -l -- 'make test 2>&1'
  tmux send-keys -t '%3' Enter
  ```

- control keys go by tmux name: `C-c`, `C-d`, `Escape`, `Up`, `Tab`
- `send-keys` exiting 0 does not mean the input landed - capture right after sending and check the command actually submitted; if it sits at the prompt unsubmitted, send another Enter
- never pipe through `tail`/`head` or otherwise truncate what you send - let the full output print so you can capture it back
- wait for output by polling `capture-pane` in a loop (0.5s interval, bounded attempts) - never a single blind sleep; `tmux wait-for` does not watch pane output
- for completion detection append a sentinel: send `long-command; echo "done: $?"` and grep captures for `done:` - the capture also contains your echoed command line, so match the output, not the invocation

## New panes and long-running work

- create splits with `tmux-smart-split` (wraps `split-window`, picks horizontal/vertical from pane proportions, `-d <dir>` sets the working directory) - never call `tmux split-window` directly
- grab the new pane's id at creation: `tmux-smart-split -P -F '#{pane_id}' 'command'`
- use a split for anything interactive (REPLs, TUIs), anything long-lived (servers, watchers), or commands that would outlive the shell tool timeout; keep the pane alive after exit with `command; echo "exited: $?"; sleep infinity` when you still need to read its output
- for chatty processes whose output would scroll past the history limit, stream it to a file instead: `tmux pipe-pane -t '%3' "cat >> $PWD/tmp/pane.log"` (rerun with no command to stop) - the command runs from the tmux server's cwd, so the path must be absolute

## Safety

- never kill panes, windows, or sessions you did not create; never `kill-server`
- before sending anything to a pane, capture it first and look - a pane running vim or a REPL will not run your shell command
- clean up panes you created once done (`tmux kill-pane -t '%9'`), after capturing any output that matters
