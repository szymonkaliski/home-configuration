#!/usr/bin/env node

// Claude Code hook and CLI that clears a macOS privacy (TCC) deny stuck on
// ~/Documents, ~/Desktop or ~/Downloads.
//
// Failure mode: sandboxd asks tccd whether a process may read a protected
// folder, tccd answers with an error instead of a verdict ("Failed to create
// Attribution Chain from message", kTCCErrorDomain code 5), and sandboxd caches
// that error as a deny for the terminal app's whole process tree. From then on
// every shell under that terminal (and under a tmux server it started) gets
// EPERM on the folder, while other folders and other terminals keep working.
// Resetting the folder entry for the terminal app publishes a TCC change event
// that drops the cached deny; an app with Full Disk Access keeps it.
//
// This file is copied into the nix store, not linked into the dotfiles repo,
// so it stays readable while ~/Documents is blocked. It must not require any
// file under ~/Documents. common.nix installs it on macOS hosts only.
//
// Usage:
//   tcc-heal.js --fix          check from this shell, repair, report
//   tcc-heal.js --check        check only, exit 1 when a folder is blocked
//   tcc-heal.js --ids          print the terminal bundle ids a reset would target
//   <stdin JSON>               Claude Code hook (SessionStart, PostToolUse,
//                              PostToolUseFailure)

const fs = require("fs");
const os = require("os");
const { execFileSync } = require("child_process");

// A blocked cwd must not stop the script.
try {
  process.chdir("/");
} catch {}

const HOME = os.homedir();
const LOG = `${HOME}/.claude/tcc-heal.log`;
const LOCK = `${HOME}/.claude/tcc-heal.lock`;
const LOCK_STALE_MS = 30 * 1000;
const CANARY_TIMEOUT_MS = 3000;

const SERVICE_BY_FOLDER = {
  Documents: "SystemPolicyDocumentsFolder",
  Desktop: "SystemPolicyDesktopFolder",
  Downloads: "SystemPolicyDownloadsFolder",
};

const BUNDLE_ID_BY_TERM_PROGRAM = {
  ghostty: "com.mitchellh.ghostty",
  Apple_Terminal: "com.apple.Terminal",
};

function log(line) {
  try {
    fs.appendFileSync(LOG, `${new Date().toISOString()} ${line}\n`);
  } catch {}
}

// Canary: list each protected folder with /bin/ls in a child process, under a
// timeout, because a pending permission prompt blocks the read until someone
// answers it. "Operation not permitted" is the privacy deny; "Permission
// denied" would be ordinary file modes and is ignored.
// Returns { blocked: [...folders], pending: [...folders that timed out] }.
function probeFolders() {
  const blocked = [];
  const pending = [];
  for (const folder of Object.keys(SERVICE_BY_FOLDER)) {
    try {
      execFileSync("/bin/ls", [`${HOME}/${folder}`], {
        stdio: ["ignore", "ignore", "pipe"],
        timeout: CANARY_TIMEOUT_MS,
      });
    } catch (err) {
      if (err.code === "ETIMEDOUT" || err.signal) pending.push(folder);
      else if (/operation not permitted/i.test(String(err.stderr)))
        blocked.push(folder);
    }
  }
  return { blocked, pending };
}

// The responsible app is what tccd judges. The kernel records it per process
// (inherited through fork, so the tmux server and its panes carry the terminal
// that started the server). Asked through the same private API tccd uses, via
// JXA, which needs no root. Environment variables are the fallback.
function responsibleBundleId() {
  const script =
    "ObjC.import('AppKit');" +
    "ObjC.bindFunction('responsibility_get_pid_responsible_for_pid',['int',['int']]);" +
    "function run(a){const r=$.responsibility_get_pid_responsible_for_pid(+a[0]);" +
    "const app=$.NSRunningApplication.runningApplicationWithProcessIdentifier(r);" +
    "return (app&&!app.isNil())?ObjC.unwrap(app.bundleIdentifier):'';}";
  try {
    const out = execFileSync(
      "osascript",
      ["-l", "JavaScript", "-e", script, String(process.pid)],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
        timeout: 5000,
      },
    ).trim();
    return out || null;
  } catch {
    return null;
  }
}

function terminalBundleIds() {
  const ids = new Set();
  const exact = responsibleBundleId();
  if (exact) ids.add(exact);
  if (process.env.__CFBundleIdentifier)
    ids.add(process.env.__CFBundleIdentifier);
  const fromTerm = BUNDLE_ID_BY_TERM_PROGRAM[process.env.TERM_PROGRAM];
  if (fromTerm) ids.add(fromTerm);
  if (process.env.TMUX) {
    try {
      const env = execFileSync("tmux", ["show-environment", "-g"], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
        timeout: 3000,
      });
      const match = env.match(/^__CFBundleIdentifier=(.+)$/m);
      if (match) ids.add(match[1].trim());
      const term = env.match(/^TERM_PROGRAM=(.+)$/m);
      if (term && BUNDLE_ID_BY_TERM_PROGRAM[term[1].trim()]) {
        ids.add(BUNDLE_ID_BY_TERM_PROGRAM[term[1].trim()]);
      }
    } catch {}
  }
  return [...ids];
}

// Parallel tool calls run this hook concurrently; one reset is enough.
function acquireLock() {
  try {
    const stat = fs.statSync(LOCK);
    if (Date.now() - stat.mtimeMs > LOCK_STALE_MS) fs.rmdirSync(LOCK);
  } catch {}
  try {
    fs.mkdirSync(LOCK);
    return true;
  } catch {
    return false;
  }
}

function releaseLock() {
  try {
    fs.rmdirSync(LOCK);
  } catch {}
}

// Returns { kind: "no-terminal" } | { kind: "locked" } |
// { kind: "reset", ids, blocked, pending }, the last two from a probe after
// the reset.
function heal(folders) {
  const ids = terminalBundleIds();
  if (ids.length === 0) {
    log(`blocked=${folders.join(",")} no terminal bundle id found`);
    return { kind: "no-terminal" };
  }
  if (!acquireLock()) {
    log(`blocked=${folders.join(",")} another tcc-heal holds the lock`);
    return { kind: "locked" };
  }
  try {
    for (const id of ids) {
      for (const folder of folders) {
        const service = SERVICE_BY_FOLDER[folder];
        try {
          execFileSync("tccutil", ["reset", service, id], {
            stdio: "pipe",
            timeout: 10000,
          });
          log(`reset ${service} ${id}`);
        } catch (err) {
          log(
            `reset ${service} ${id} failed: ${String(err.message).split("\n")[0]}`,
          );
        }
      }
    }
  } finally {
    releaseLock();
  }
  const probe = probeFolders();
  log(
    `after reset blocked=${probe.blocked.join(",") || "none"} pending=${probe.pending.join(",") || "none"}`,
  );
  return { kind: "reset", ids, ...probe };
}

function healed(result) {
  return (
    result.kind === "reset" &&
    result.blocked.length === 0 &&
    result.pending.length === 0
  );
}

function describe(result, folders) {
  const list = folders.map((f) => `~/${f}`).join(", ");
  const ids =
    result.kind === "reset" ? result.ids.join(", ") : "no terminal id found";
  if (healed(result)) {
    return (
      `tcc-heal: macOS had a cached privacy deny on ${list} for this terminal's ` +
      `process tree (sandboxd kept a tccd attribution error as a deny). The ` +
      `folder entry for ${ids} was reset and reads work again from this tree. ` +
      `The command that failed can be retried.`
    );
  }
  if (result.kind === "locked") {
    return `tcc-heal: ${list} is blocked for this process tree; another tcc-heal run is resetting it. Retry in a moment.`;
  }
  if (result.kind === "reset" && result.pending.length) {
    return (
      `tcc-heal: the entry for ${ids} was reset; macOS is now showing a permission ` +
      `prompt for ${result.pending.map((f) => `~/${f}`).join(", ")} (the terminal has no Full Disk ` +
      `Access). A person has to click Allow before reads continue.`
    );
  }
  return (
    `tcc-heal: ${list} is blocked for this process tree and the reset (${ids}) did ` +
    `not clear it. The terminal app that started this tree (or the tmux server) ` +
    `has likely exited; \`tmux kill-server\` and reopening the sessions is the ` +
    `remaining fix. Log: ${LOG}`
  );
}

// Matches error lines such as
//   ls: cannot open directory '/Users/me/Documents': Operation not permitted
//   EPERM: operation not permitted, open '/Users/me/Documents/x.js'
// and not prose that quotes the phrase in backticks (README.md).
// The text is JSON, so a newline inside tool output arrives as the two
// characters "\n".
function mentionsProtectedEperm(text) {
  return text
    .split(/\\n|\n/)
    .some(
      (line) =>
        /operation not permitted/i.test(line) &&
        !/`operation not permitted`/i.test(line) &&
        /(\/Users\/[^/\s'"]+|~)\/(Documents|Desktop|Downloads)\b/.test(line),
    );
}

function emit(event, context) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: { hookEventName: event, additionalContext: context },
    }),
  );
}

function runCli(mode) {
  if (mode === "--ids") {
    console.log(terminalBundleIds().join("\n") || "(none)");
    return;
  }
  const probe = probeFolders();
  if (mode === "--check") {
    if (probe.pending.length)
      console.log(`pending prompt: ${probe.pending.join(", ")}`);
    console.log(
      probe.blocked.length ? `blocked: ${probe.blocked.join(", ")}` : "ok",
    );
    process.exit(probe.blocked.length || probe.pending.length ? 1 : 0);
  }
  if (probe.blocked.length === 0) {
    console.log(
      probe.pending.length
        ? `a permission prompt is pending for ${probe.pending.join(", ")}: answer it first`
        : "ok: protected folders readable from this process tree",
    );
    return;
  }
  const result = heal(probe.blocked);
  console.log(describe(result, probe.blocked));
  process.exit(healed(result) ? 0 : 1);
}

// Hook policy: act only when this process tree is blocked. A tool output that
// mentions EPERM while this tree reads fine says nothing certain about where
// the failing process ran, so the hook stays silent and only logs.
function runHook() {
  let input;
  try {
    input = JSON.parse(fs.readFileSync(0, "utf8"));
  } catch {
    return;
  }
  const event = input.hook_event_name;

  if (event === "SessionStart") {
    const probe = probeFolders();
    if (probe.blocked.length === 0) return;
    log(`SessionStart blocked=${probe.blocked.join(",")}`);
    emit(event, describe(heal(probe.blocked), probe.blocked));
    return;
  }

  if (event === "PostToolUse" || event === "PostToolUseFailure") {
    const text = JSON.stringify(input.tool_response ?? input.error ?? "");
    if (!mentionsProtectedEperm(text)) return;
    const probe = probeFolders();
    log(
      `${event} ${input.tool_name} eperm-in-output blocked=${probe.blocked.join(",") || "none"} pending=${probe.pending.join(",") || "none"}`,
    );
    if (probe.blocked.length === 0) return;
    emit(event, describe(heal(probe.blocked), probe.blocked));
  }
}

const arg = process.argv[2];
if (arg === "--fix" || arg === "--check" || arg === "--ids") runCli(arg);
else runHook();
