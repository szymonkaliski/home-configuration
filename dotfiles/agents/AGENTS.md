## Code

- DO NOT commit, push, or deploy anything unless explicitly asked
- code comments MUST assert current state
  - DO NOT add narrative comments describing previous state, changes, contrasting with past approach that's no longer in the codebase
- prefer discriminated unions over optional fields; make illegal states unrepresentable

## Investigation

- never speculate - "probably" or "likely" is not evidence, show the log line or code path
  - don't guess root causes; read the code, check logs, or add instrumentation to confirm before proposing a fix
  - if you haven't opened a file, you cannot make claims about what it contains
  - "I don't know" is a valid answer, say it, then investigate

- reproduce a bug and observe the failure yourself before attempting a fix - don't fix from a description alone
  - confirm the fix by observing the same reproduction now pass
  - if it can't be reproduced, say so explicitly instead of fixing speculatively

- NEVER dismiss errors, warnings, or failing tests as "pre-existing" or "not caused by my changes" - you are the sole developer - all issues are your responsibility
  - when you encounter errors during builds, linting, typechecks, or tests that you didn't introduce, flag them and offer to fix them rather than skipping over them

- when designing an approach before writing code, use web search to check documentation and issues on GitHub, assume you don't have the latest knowledge

- if a request is ambiguous or spans multiple reasonable approaches, ask clarifying questions before implementing

## Subagents

- the main thread orchestrates: scope the work, delegate, judge the results, synthesize; delegated work runs on one of two tiers
  - heavy tier (strongest worker model): implementation, investigation, review, anything that needs judgment
  - light tier (fast model): mechanical, fully specified work - search, renames, formatting
  - pick the tier per delegation; when the harness takes a model per call, always pass one (heavy tier by default), never let a subagent inherit the session model by omission
- delegate: independent read-only fan-out (codebase search, multi-file research, doc/web lookups) launched in one message; an unrelated edit that came up mid-session; research whose result isn't blocking the current step (run it in the background)
- keep inline: anything that fits in a handful of tool calls; steps that depend on each other; work that needs the current conversation's context; edits to files the main thread or another agent touches (lockfiles, configs, anything a formatter rewrites); destructive or outward-facing actions (push, delete, deploy)
- one subagent per task, no re-delegation; prefer fewer, larger subagents over many narrow ones
- the delegation prompt is the subagent's entire briefing, it sees none of the conversation; include:
  - one objective and what "done" looks like
  - the context it lacks: file paths, error text, decisions already made, constraints the user gave
  - scope boundaries: what to touch, what not to, what belongs to another agent
  - the return format: a short report (findings, changed files, evidence such as command output), not a transcript; large outputs go to a file, return the path
- wait for the completion notification instead of polling; review every result before trusting it - subagents report success plausibly, so ask for evidence and re-verify anything that lands in the main thread's work

## Shell & Environment

- for running ad-hoc shell commands from nixpkgs, use `nix run nixpkgs#<pkg> -- <args>` (for example: `nix run nixpkgs#poppler-utils -- pdfinfo [...]`); prefer it over writing ad-hoc code

- use `./tmp/` in the project root for any temporary/scratch files (reproduction scripts, test fixtures, debug output, etc.) - it's globally gitignored
  - create it if it doesn't exist
  - when struggling to understand a library behavior, git clone it into `./tmp/` and review the code there

- if you have to write ad-hoc code, use `node` instead of `python`

- use `trash` instead of `rm` (if available)

## Prose & Communication

- never use em-dashes or semicolons
- write in ASD-STE100 Simplified Technical English style: active voice, simple tenses, one idea per sentence, sentences under 20 words, plain common words, one word per meaning (do not rotate synonyms)
  - say what a thing is before what it is not; drop the contrast when it adds nothing
- do not restate the question, preview the answer, or add a closing summary
- avoid AI-cliche wording: delve, robust, seamless, crucial, testament to, load-bearing, "that lands", "worth noting", "clean/cleanly", "it is not X, it is Y"
- keep outputs focused, brief, and direct
  - keep disclaimers and caveats short, spending most of the response on the main answer
- lead directly with the outcome: your first sentence should answer "what happened" or "what did you find," followed by supporting details
- match written documents and files to substance, cover what is needed without padding with filler sections, redundant summaries, or boilerplate

