# claude

## `~/Documents` suddenly denied in every shell

Symptom: every shell under Ghostty (and under the tmux server Ghostty started) fails with `Operation not permitted` on `~/Documents` only. `~/Desktop`, `~/Downloads`, `~/Library` and shells under Terminal.app keep working. Hooks and the statusline die too, because this repo lives under `~/Documents` and `~/.claude/*` links into it.

What the `tccd` and `sandboxd` logs show (2026-10-06): sandboxd asked tccd whether a Claude Code process may read `~/Documents`. tccd replied with an error instead of a verdict (`Failed to create Attribution Chain from message`, `kTCCErrorDomain` code 5). sandboxd cached that error as a deny for the responsible process, Ghostty, so for its whole process tree.

The cause is not confirmed. Nothing here explains why tccd fails to build the attribution chain. Two things preceded the 2026-10-06 incident, and neither is a proven trigger:

- `npm-sync` (run from `update-all`) replaced `claude.exe` on disk twelve minutes after the failing session started.
- The failing session ran many parallel tools in a repo under `~/Documents` (sandboxd logged about 18 TCC checks per second).

The deny occurred again with `DISABLE_AUTOUPDATER=1` set, so `settings.json` does not set it.

Repair: `~/.claude/tcc-heal.js --fix`. It lists the protected folders from the current process (with a timeout, a pending prompt blocks the read), resolves the responsible app through the kernel's `responsibility_get_pid_responsible_for_pid` (JXA, no root; `__CFBundleIdentifier`, `TERM_PROGRAM` and the tmux server's environment as fallbacks) and runs `tccutil reset SystemPolicyDocumentsFolder <bundle id>`. The TCC change event drops the cached deny; Ghostty keeps its Full Disk Access, so nothing is prompted. No sudo, no tmux restart. If Ghostty itself has exited, only `tmux kill-server` helps, because the tmux server's responsible process is gone.

The same script runs as a Claude Code hook (`SessionStart`, `PostToolUse` for Bash, `PostToolUseFailure`): it repairs the state and tells the model to retry. `common.nix` copies it into the nix store instead of linking it into this repo, so it stays readable while `~/Documents` is blocked. It is macOS only: `common.nix` installs it on Darwin hosts, and the hook command does nothing on a host without the file. Log: `~/.claude/tcc-heal.log`.

Upstream:

- https://github.com/anthropics/claude-code/issues/90227
- https://github.com/anthropics/claude-code/issues/96996
- https://github.com/anthropics/claude-code/issues/58952
- https://github.com/ghostty-org/ghostty/discussions/12947
- https://github.com/ghostty-org/ghostty/discussions/2998
