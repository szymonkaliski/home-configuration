#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const { execFileSync, execSync } = require("child_process");

const input = JSON.parse(fs.readFileSync(0, "utf8"));
const event = input.hook_event_name;
const transcriptPath = input.transcript_path;

// skip if terminal window is focused on this pane
if (process.env.TMUX) {
  try {
    const info = execSync(
      "tmux display-message -p '#{client_flags} #{pane_active} #{window_active}'",
      { encoding: "utf8" },
    ).trim();

    const [flags, pane, window] = info.split(" ");

    if (flags.includes("focused") && pane === "1" && window === "1") {
      process.exit(0);
    }
  } catch {}
}

// Extended thinking streams as two jsonl entries sharing one msg_id: a thinking-only
// entry first, then a paired text entry up to ~15s later. The Stop hook fires on the
// first entry, so callers must poll until kind === "text" to avoid spurious "Waiting".
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
      if (entry.type === "progress" || entry.type === "system") continue;

      if (entry.type !== "assistant") return { kind: "not_assistant" };
      const contents = entry.message?.content;
      if (!Array.isArray(contents)) return { kind: "not_assistant" };

      for (let j = contents.length - 1; j >= 0; j--) {
        if (contents[j].type === "text" && contents[j].text?.trim()) {
          return { kind: "text", text: contents[j].text.trim().slice(0, 200) };
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
// echoes the notification as assistant text, producing nonsense pushovers.
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
      if (Array.isArray(content) && content.some((c) => c.type === "tool_result")) continue;
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
    const cmd = (inp.command || "").slice(0, 120);
    return `Bash: ${cmd}`;
  }
  if (name === "Edit") return `Edit: ${inp.file_path || "?"}`;
  if (name === "Write") return `Write: ${inp.file_path || "?"}`;
  if (name === "Read") return `Read: ${inp.file_path || "?"}`;

  if (name === "AskUserQuestion") {
    const q = inp.questions?.[0]?.question;
    if (q) return `Question: ${q.slice(0, 120)}`;
    return "Question";
  }

  // generic: tool name + first string-valued input field
  const firstVal = Object.values(inp).find((v) => typeof v === "string");
  if (firstVal) return `${name}: ${firstVal.slice(0, 100)}`;
  return name;
}

let body;

if (event === "Stop") {
  if (!transcriptPath || !fs.existsSync(transcriptPath)) process.exit(0);
  if (lastUserOriginIsTaskNotification(transcriptPath)) process.exit(0);

  const sab = new SharedArrayBuffer(4);
  const view = new Int32Array(sab);
  const deadline = Date.now() + 30000;
  let state = readLastAssistantState(transcriptPath);
  while (state.kind !== "text" && Date.now() < deadline) {
    Atomics.wait(view, 0, 0, 200);
    state = readLastAssistantState(transcriptPath);
  }

  if (state.kind !== "text") process.exit(0);
  body = state.text;
} else {
  body = input.message || "Notification";

  if (
    input.notification_type === "permission_prompt" &&
    transcriptPath &&
    fs.existsSync(transcriptPath)
  ) {
    try {
      const toolUse = readLastToolUse(transcriptPath);
      if (toolUse) body = formatToolUse(toolUse);
    } catch {}
  }
}

const title = `Claude Code (${os.hostname()})`;

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
  process.exit(0);
} catch {}

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
      () => process.exit(0),
      () => process.exit(0),
    );
  }
}
