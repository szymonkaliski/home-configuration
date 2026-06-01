#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const { execFileSync, execSync } = require("child_process");

const input = JSON.parse(fs.readFileSync(0, "utf8"));
const event = input.hook_event_name;
const transcriptPath = input.transcript_path;

function truncate(str, max) {
  if (str.length <= max) return str;
  let cut = str.slice(0, max);
  // if the cutoff lands mid-word, drop the trailing partial word
  if (/\S/.test(str[max])) {
    const atBoundary = cut.replace(/\S+$/, "").trimEnd();
    if (atBoundary) cut = atBoundary;
  }
  return cut.trimEnd() + "…";
}

const LOG_PATH = `${os.homedir()}/.claude/notify.log`;
const LOG_RETAIN_MS = 90 * 24 * 60 * 60 * 1000;
const LOG_PRUNE_SLACK_MS = 7 * 24 * 60 * 60 * 1000;

function logLine(data) {
  const now = Date.now();
  try {
    fs.appendFileSync(
      LOG_PATH,
      JSON.stringify({ ts: new Date(now).toISOString(), ...data }) + "\n",
    );
    pruneLog(now);
  } catch {}
}

// Keep ~3 months of entries. The first field of every line is "ts", so peek at
// the head of the file to find the oldest entry cheaply; only rewrite the whole
// file once entries spill a slack window past the retention edge, so the full
// rewrite happens roughly weekly rather than on every notification.
function pruneLog(now) {
  const fd = fs.openSync(LOG_PATH, "r");
  let oldestTs;
  try {
    const head = Buffer.alloc(128);
    const n = fs.readSync(fd, head, 0, 128, 0);
    const m = head.toString("utf8", 0, n).match(/"ts":"([^"]+)"/);
    oldestTs = m ? Date.parse(m[1]) : NaN;
  } finally {
    fs.closeSync(fd);
  }
  if (!Number.isFinite(oldestTs)) return;
  if (oldestTs >= now - LOG_RETAIN_MS - LOG_PRUNE_SLACK_MS) return;

  const cutoff = now - LOG_RETAIN_MS;
  const kept = fs
    .readFileSync(LOG_PATH, "utf8")
    .split("\n")
    .filter((line) => {
      const m = line.match(/"ts":"([^"]+)"/);
      return m ? Date.parse(m[1]) >= cutoff : false;
    });
  fs.writeFileSync(LOG_PATH, kept.length ? kept.join("\n") + "\n" : "");
}

logLine({
  phase: "fire",
  event,
  notification_type: input.notification_type,
  tool_name: input.tool_name,
});

// skip the notification when the user is actively looking at this pane
if (process.env.TMUX && process.env.TMUX_PANE) {
  try {
    const myPane = process.env.TMUX_PANE;
    const clients = execSync(
      "tmux list-clients -F '#{client_flags}\t#{session_name}'",
      {
        encoding: "utf8",
      },
    )
      .trim()
      .split("\n");

    for (const row of clients) {
      const [flags, session] = row.split("\t");
      if (!flags || !flags.split(",").includes("focused")) continue;
      const activePane = execSync(
        `tmux display-message -p -t ${JSON.stringify(session)} '#{pane_id}'`,
        { encoding: "utf8" },
      ).trim();
      if (activePane === myPane) {
        logLine({ phase: "suppressed", reason: "focused-pane", event });
        process.exit(0);
      }
    }
  } catch {}
}

// Scan backward for the most recent assistant entry, skipping every non-assistant
// entry. Claude Code appends non-conversational entries (ai-title, last-prompt,
// permission-mode, mode, queue-operation, attachment) that are frequently the last
// line when the Stop hook fires, so bailing on the first non-assistant entry would
// drop the notification. Separately, extended thinking streams as two jsonl entries
// sharing one msg_id (thinking-only first, paired text up to ~15s later) and Stop
// fires on the first, so callers poll until kind === "text".
function readLastAssistantState(filePath) {
  const fd = fs.openSync(filePath, "r");
  try {
    const stat = fs.fstatSync(fd);
    const readSize = Math.min(stat.size, 65536);
    const buf = Buffer.alloc(readSize);
    fs.readSync(fd, buf, 0, readSize, stat.size - readSize);
    const chunk = buf.toString("utf8");

    const firstNewline = chunk.indexOf("\n");
    const lines = chunk
      .slice(firstNewline + 1)
      .split("\n")
      .filter(Boolean);

    for (let i = lines.length - 1; i >= 0; i--) {
      let entry;
      try {
        entry = JSON.parse(lines[i]);
      } catch {
        continue;
      }
      if (entry.type !== "assistant") continue;
      const contents = entry.message?.content;
      if (!Array.isArray(contents)) return { kind: "assistant_without_text" };

      for (let j = contents.length - 1; j >= 0; j--) {
        if (contents[j].type === "text" && contents[j].text?.trim()) {
          return { kind: "text", text: truncate(contents[j].text.trim(), 200) };
        }
      }
      return { kind: "assistant_without_text" };
    }
    return { kind: "not_assistant" };
  } finally {
    fs.closeSync(fd);
  }
}

// task-notification user turns (e.g. Monitor events) spam Stop. Opus sometimes
// echoes the notification as assistant text, producing nonsense notifications.
function lastUserOriginIsTaskNotification(filePath) {
  const fd = fs.openSync(filePath, "r");
  try {
    const stat = fs.fstatSync(fd);
    const readSize = Math.min(stat.size, 65536);
    const buf = Buffer.alloc(readSize);
    fs.readSync(fd, buf, 0, readSize, stat.size - readSize);
    const chunk = buf.toString("utf8");

    const firstNewline = chunk.indexOf("\n");
    const lines = chunk
      .slice(firstNewline + 1)
      .split("\n")
      .filter(Boolean);

    for (let i = lines.length - 1; i >= 0; i--) {
      let entry;
      try {
        entry = JSON.parse(lines[i]);
      } catch {
        continue;
      }
      if (entry.type !== "user") continue;
      const content = entry.message?.content;
      if (
        Array.isArray(content) &&
        content.some((c) => c.type === "tool_result")
      )
        continue;
      return entry.origin?.kind === "task-notification";
    }
  } finally {
    fs.closeSync(fd);
  }
  return false;
}

function readLastToolUse(filePath) {
  const fd = fs.openSync(filePath, "r");
  try {
    const stat = fs.fstatSync(fd);
    const readSize = Math.min(stat.size, 65536);
    const buf = Buffer.alloc(readSize);
    fs.readSync(fd, buf, 0, readSize, stat.size - readSize);
    const chunk = buf.toString("utf8");

    const firstNewline = chunk.indexOf("\n");
    const lines = chunk
      .slice(firstNewline + 1)
      .split("\n")
      .filter(Boolean);

    for (let i = lines.length - 1; i >= 0; i--) {
      let entry;
      try {
        entry = JSON.parse(lines[i]);
      } catch {
        continue;
      }
      if (entry.type !== "assistant") continue;

      const contents = entry.message?.content;
      if (!Array.isArray(contents)) return null;

      for (let j = contents.length - 1; j >= 0; j--) {
        if (contents[j].type !== "tool_use") continue;
        return contents[j];
      }
      return null;
    }
  } finally {
    fs.closeSync(fd);
  }
  return null;
}

function formatToolUse(toolUse) {
  const name = toolUse.name;
  const inp = toolUse.input || {};

  if (name === "Bash") {
    return `Bash: ${truncate(inp.command || "", 120)}`;
  }
  if (name === "Edit") return `Edit: ${inp.file_path || "?"}`;
  if (name === "Write") return `Write: ${inp.file_path || "?"}`;
  if (name === "Read") return `Read: ${inp.file_path || "?"}`;

  if (name === "AskUserQuestion") {
    const q = inp.questions?.[0]?.question;
    if (q) return `Question: ${truncate(q, 120)}`;
    return "Question";
  }

  // generic: tool name + first string-valued input field
  const firstVal = Object.values(inp).find((v) => typeof v === "string");
  if (firstVal) return `${name}: ${truncate(firstVal, 100)}`;
  return name;
}

// Permission prompts for read-only inspection commands (git log/status/diff,
// ls, cat, …) are pure noise: the answer is always "approve", so a phone buzz
// per prompt is worthless. A misclassification here only costs a heads-up ping
// — the command still needs explicit in-terminal approval and never auto-runs,
// so suppressing a write-by-mistake can't let anything through. Bias the lists
// toward commands that are read-only in essentially every common form.
const READONLY_GIT_SUBCMDS = new Set([
  "log", "status", "diff", "show", "rev-parse", "rev-list", "describe",
  "blame", "shortlog", "reflog", "ls-files", "ls-tree", "cat-file",
  "whatchanged", "name-rev", "grep",
]);
const READONLY_CMDS = new Set([
  "ls", "cat", "head", "tail", "wc", "pwd", "stat", "file", "tree", "du",
  "df", "env", "printenv", "whoami", "id", "hostname", "date", "realpath",
  "readlink", "basename", "dirname", "nl", "tac", "jq", "less", "more", "bat",
]);

function isReadOnlyBash(command) {
  if (!command) return false;
  // redirections / command substitution can hide a write — don't classify
  if (/[<>]|\$\(|`/.test(command)) return false;
  // every chained/piped segment must itself be read-only
  return command.split(/&&|\|\||;|\|/).every((seg) => {
    const tokens = seg.trim().split(/\s+/).filter(Boolean);
    while (tokens.length && /^\w+=/.test(tokens[0])) tokens.shift(); // env prefix
    if (!tokens.length) return false;
    if (tokens[0] === "git") {
      const sub = tokens.slice(1).find((t) => !t.startsWith("-"));
      return sub ? READONLY_GIT_SUBCMDS.has(sub) : false;
    }
    return READONLY_CMDS.has(tokens[0]);
  });
}

let body;

if (event === "Stop") {
  if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    logLine({ phase: "skipped", reason: "no-transcript", event });
    process.exit(0);
  }
  if (lastUserOriginIsTaskNotification(transcriptPath)) {
    logLine({ phase: "skipped", reason: "task-notification", event });
    process.exit(0);
  }

  const sab = new SharedArrayBuffer(4);
  const view = new Int32Array(sab);
  const deadline = Date.now() + 30000;
  let state = readLastAssistantState(transcriptPath);
  while (state.kind !== "text" && Date.now() < deadline) {
    Atomics.wait(view, 0, 0, 200);
    state = readLastAssistantState(transcriptPath);
  }

  if (state.kind !== "text") {
    logLine({
      phase: "skipped",
      reason: "no-assistant-text",
      kind: state.kind,
    });
    process.exit(0);
  }
  body = state.text;
} else if (event === "PreToolUse") {
  // AskUserQuestion blocks mid-turn waiting on the user but fires no Notification
  // event (it bypasses the permission system) and Stop never fires for it either,
  // so a PreToolUse hook is the only signal that the chooser is now waiting.
  body = formatToolUse({
    name: input.tool_name,
    input: input.tool_input || {},
  });
} else {
  body = input.message || "Notification";

  if (
    input.notification_type === "permission_prompt" &&
    transcriptPath &&
    fs.existsSync(transcriptPath)
  ) {
    try {
      const toolUse = readLastToolUse(transcriptPath);
      if (toolUse) {
        if (toolUse.name === "Bash" && isReadOnlyBash(toolUse.input?.command)) {
          logLine({
            phase: "suppressed",
            reason: "readonly-permission-prompt",
            event,
            command: truncate(toolUse.input?.command || "", 120),
          });
          process.exit(0);
        }
        body = formatToolUse(toolUse);
      }
    } catch {}
  }
}

const title = `Claude Code (${os.hostname()})`;

logLine({ phase: "deliver", event, body });

// tnotify (desktop notifications)
try {
  const args = ["-t", title, body];
  if (process.env.TMUX) {
    const tty = execSync("tmux display-message -p '#{pane_tty}'", {
      encoding: "utf8",
    }).trim();
    const fd = fs.openSync(tty, "w");
    try {
      execFileSync("tnotify", args, { stdio: ["ignore", fd, "ignore"] });
    } finally {
      fs.closeSync(fd);
    }
  } else {
    execFileSync("tnotify", [...args, "--native"], { stdio: "ignore" });
  }
  logLine({ phase: "sent", channel: "tnotify", body });
  process.exit(0);
} catch (err) {
  logLine({
    phase: "channel-failed",
    channel: "tnotify",
    error: String((err && err.message) || err),
  });
}

// pushover (mobile notifications)
const pushoverrcPath = `${os.homedir()}/.pushoverrc`;
if (fs.existsSync(pushoverrcPath)) {
  const rc = fs.readFileSync(pushoverrcPath, "utf8");
  const vars = {};
  for (const line of rc.split("\n")) {
    const m = line.match(/^(\w+)=(.+)$/);
    if (m) vars[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }

  if (vars.PUSHOVER_TOKEN && vars.PUSHOVER_USER) {
    const params = new URLSearchParams({
      token: vars.PUSHOVER_TOKEN,
      user: vars.PUSHOVER_USER,
      title,
      message: body,
    });

    fetch("https://api.pushover.net/1/messages.json", {
      method: "POST",
      body: params,
    }).then(
      (res) => {
        logLine({
          phase: "sent",
          channel: "pushover",
          status: res.status,
          body,
        });
        process.exit(0);
      },
      (err) => {
        logLine({
          phase: "channel-failed",
          channel: "pushover",
          error: String((err && err.message) || err),
        });
        process.exit(0);
      },
    );
  } else {
    logLine({ phase: "skipped", reason: "pushover-no-tokens" });
  }
} else {
  logLine({ phase: "skipped", reason: "no-pushoverrc" });
}
