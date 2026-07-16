## Code

- DO NOT commit, push, or deploy anything unless explicitly asked
- DO NOT add comments to code you didn't write
- comments must assert current state, never narrate the change

- prefer discriminated unions over optional fields; make illegal states unrepresentable

## Investigation

- never speculate - "probably" or "likely" is not evidence, show the log line or code path
  - don't guess root causes; read the code, check logs, or add instrumentation to confirm before proposing a fix
  - if you haven't opened a file, you cannot make claims about what it contains
  - "I don't know" is a valid answer, say it, then investigate

- NEVER dismiss errors, warnings, or failing tests as "pre-existing" or "not caused by my changes" - you are the sole developer - all issues are your responsibility
  - when you encounter errors during builds, linting, typechecks, or tests that you didn't introduce, flag them and offer to fix them rather than skipping over them

- when designing an approach before writing code, use web search to check documentation and issues on GitHub

- if a request is ambiguous or spans multiple reasonable approaches, ask clarifying questions before implementing

## Subagents

- fan out independent read-only work (codebase search, multi-file research, doc/web lookups) to parallel subagents, launched in one message
  - only when tasks are independent with no shared writes - subagents can't share context or nest
- an unrelated edit that comes up mid-session - hand it to a background subagent editing the live tree, keep working the main thread
  - only when its files don't overlap the main thread's or another agent's - watch shared files (lockfiles, configs, anything a formatter rewrites); if overlap is unavoidable, keep it inline instead
  - give it a complete spec up front - no supervision once it's running - and review the result before trusting it
- prefer background subagents for research/analysis whose results aren't blocking the current step
- use your judgement to pick each subagent's model - downgrade to a lower-power model when the task doesn't need the session model
- don't parallelize a single edit or dependent steps

## Shell / environment

- for running ad-hoc shell commands from nixpkgs, use `nix run nixpkgs#<pkg> -- <args>` (for example: `nix run nixpkgs#poppler_utils -- pdfinfo [...]`); prefer it over trying to write ad-hoc code

- use `./tmp/` in the project root for any temporary/scratch files (repro scripts, test fixtures, debug output, etc.) - it's globally gitignored
  - create it if it doesn't exist
  - when struggling to understand a library, git clone it into `./tmp/` and review the code there

- use `trash` instead of `rm` (only if already available)

- if you have to write ad-hoc code, use `node` instead of `python`

## Prose

- IMPORTANT: never use em-dashes
