# claude

`settings.json` sets `DISABLE_AUTOUPDATER=1`. The npm auto-updater replaces `claude.exe` on disk underneath running sessions. On macOS, long-lived sessions then lose `~/Documents` access: every read by the session and its children (Stop hook `notify.js`, `statusline-command.sh`) fails with EPERM, logged by the kernel as `System Policy: <proc> deny(1) file-read-data <path>`. Consistent with TCC no longer matching the running process against the binary at its registered path; upstream also correlates incidents with memory pressure, so disabling auto-updates removes the one trigger observed here, not necessarily all of them.

Upstream:

- https://github.com/anthropics/claude-code/issues/58952
- https://github.com/ghostty-org/ghostty/discussions/12947
- https://github.com/ghostty-org/ghostty/discussions/12928
