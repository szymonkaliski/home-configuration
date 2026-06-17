#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const { execFileSync, execSync } = require("child_process");

const input = JSON.parse(fs.readFileSync(0, "utf8"));
const event = input.hook_event_name;
const transcriptPath = input.transcript_path;
const sessionId = input.session_id;

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

// PermissionRequest fires the instant a real permission dialog appears (carrying
// the tool input) and we notify from it directly. A redundant generic
// `permission_prompt` Notification then fires ~6s later; to drop that duplicate
// we drop a per-session "already notified" marker here when we deliver a
// blocking-prompt notification, and the later Notification dedups against it.
// (Verified: PermissionRequest +51ms with command; Notification +6s generic.)
const PENDING_DIR = `${os.homedir()}/.claude/notify-pending`;
const PENDING_FRESH_MS = 10 * 60 * 1000;

function pendingFile(sid) {
  return `${PENDING_DIR}/${String(sid).replace(/[^\w.-]/g, "_")}.json`;
}
function markNotified(sid) {
  if (!sid) return;
  try {
    fs.mkdirSync(PENDING_DIR, { recursive: true });
    fs.writeFileSync(pendingFile(sid), JSON.stringify({ ts: Date.now() }));
  } catch {}
}
function wasNotified(sid) {
  if (!sid) return false;
  try {
    const rec = JSON.parse(fs.readFileSync(pendingFile(sid), "utf8"));
    return Date.now() - rec.ts <= PENDING_FRESH_MS;
  } catch {
    return false;
  }
}
function clearPending(sid) {
  if (!sid) return;
  try {
    fs.unlinkSync(pendingFile(sid));
  } catch {}
  // sweep records orphaned by killed/crashed sessions so the dir can't grow
  try {
    const now = Date.now();
    for (const f of fs.readdirSync(PENDING_DIR)) {
      const p = `${PENDING_DIR}/${f}`;
      try {
        if (now - fs.statSync(p).mtimeMs > PENDING_FRESH_MS) fs.unlinkSync(p);
      } catch {}
    }
  } catch {}
}

// idle-state marker: set when we deliver a turn-end (Stop) or idle notification,
// cleared when a forked skill / subagent finishes (SubagentStop). Lets the ~60s
// idle_prompt Notification act as a backstop for turns that fire no Stop (e.g.
// `context: fork` slash-commands, which fire SubagentStop only) without
// double-notifying normal turns that Stop already covered.
function markIdle(sid) {
  markNotified(`${sid}__idle`);
}
function wasIdle(sid) {
  return wasNotified(`${sid}__idle`);
}
function clearIdle(sid) {
  if (!sid) return;
  try {
    fs.unlinkSync(pendingFile(`${sid}__idle`));
  } catch {}
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

// A forked skill / subagent finished. It fires SubagentStop (never Stop), so the
// turn-end path won't run; clear the idle marker so the ~60s idle_prompt backstop
// fires if the session is now waiting on the user. (For a mid-turn Task subagent,
// the main turn's own Stop re-marks idle afterward, so idle_prompt stays deduped.)
if (event === "SubagentStop") {
  clearIdle(sessionId);
  logLine({ phase: "cleared-idle", event });
  process.exit(0);
}

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

// Scan backward for the most recent assistant entry, skipping non-conversational
// entries (ai-title, last-prompt, permission-mode, mode, queue-operation,
// attachment) and mid-turn tool_result user entries that are frequently the last
// line when the Stop hook fires, so bailing on the first of them would drop the
// notification. Two cases make callers poll (kind !== "text"): extended thinking
// streams as two jsonl entries sharing one msg_id (thinking-only first, paired text
// up to ~15s later) and Stop fires on the first; and the Stop hook can read before
// the current turn's assistant line lands on disk, leaving a real user prompt as the
// latest entry - return "awaiting_response" there instead of falling through to the
// previous turn's now-stale assistant text (the off-by-one). A finished forked /
// slash command is the exception: it fires no Stop and prints its result as a
// local-command-stdout user entry rather than assistant text, so return that output
// as "command_result" for the idle_prompt backstop to surface.
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

      // A real user prompt (not a mid-turn tool_result) below the most recent
      // assistant text means the current turn's reply hasn't been flushed yet.
      // Stop scanning here so the caller polls, rather than falling through to an
      // older assistant entry and delivering the previous turn's message.
      if (entry.type === "user") {
        const content = entry.message?.content;
        // A finished forked / slash command (e.g. /git-review) prints its result
        // as a string-content local-command-stdout user entry, not an assistant
        // entry, so the off-by-one guard below would otherwise treat it as a
        // pending prompt. Surface that output as "command_result" instead - the
        // idle_prompt backstop reads it to name what just finished.
        if (typeof content === "string") {
          const m = content.match(
            /<local-command-stdout>([\s\S]*?)<\/local-command-stdout>/,
          );
          const out = m && m[1].trim();
          if (out) return { kind: "command_result", text: truncate(out, 200) };
        }
        const isToolResult =
          Array.isArray(content) &&
          content.some((c) => c.type === "tool_result");
        if (!isToolResult) return { kind: "awaiting_response" };
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

// Stop/PreToolUse/PermissionRequest carry transcript_path, but Notification
// events are not documented to, so resolve it ourselves: the session_id is a
// globally-unique UUID, so ~/.claude/projects/*/<session_id>.jsonl matches at
// most one file. Prefer transcript_path when it is present and points at a real
// file; otherwise glob the projects tree by session_id.
function resolveTranscriptPath(input) {
  if (input.transcript_path && fs.existsSync(input.transcript_path)) {
    return input.transcript_path;
  }
  const sid = input.session_id;
  if (!sid) return null;
  const root = `${os.homedir()}/.claude/projects`;
  try {
    for (const dir of fs.readdirSync(root)) {
      const p = `${root}/${dir}/${sid}.jsonl`;
      if (fs.existsSync(p)) return p;
    }
  } catch {}
  return null;
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

let body;

if (event === "Stop") {
  clearPending(sessionId); // turn ended; any pending-tool record is now stale
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
  // Only AskUserQuestion reaches here (Read goes to pre-read-hook; nothing else
  // is hooked). It blocks mid-turn but fires no permission Notification, so this
  // is the only immediate signal that the chooser is waiting.
  if (input.tool_name !== "AskUserQuestion") process.exit(0);
  body = formatToolUse({
    name: input.tool_name,
    input: input.tool_input || {},
  });
} else if (event === "PermissionRequest") {
  // Fires the instant a real permission dialog appears (never for auto-approved
  // calls) and carries the tool input - so we name exactly what's awaited,
  // immediately. This is the primary permission notification.
  body = formatToolUse({
    name: input.tool_name,
    input: input.tool_input || {},
  });
} else {
  body = input.message || "Notification";

  // The generic permission_prompt Notification fires ~6s later as a backstop. If
  // PermissionRequest already notified this prompt (marker set on delivery), it's
  // a duplicate - drop it. It still fires when PermissionRequest was suppressed
  // because the pane was focused and the user has since looked away (a re-alert).
  if (
    input.notification_type === "permission_prompt" &&
    wasNotified(sessionId)
  ) {
    logLine({
      phase: "suppressed",
      reason: "permission-already-notified",
      event,
    });
    process.exit(0);
  }

  // idle_prompt ("Claude is waiting for your input") fires ~60s after the session
  // goes idle. If a Stop already notified this idle period it's a duplicate, drop
  // it. Otherwise it's the only signal (e.g. a `context: fork` command that fired
  // SubagentStop but no Stop), so deliver it.
  if (input.notification_type === "idle_prompt" && wasIdle(sessionId)) {
    logLine({ phase: "suppressed", reason: "idle-already-notified", event });
    process.exit(0);
  }

  // The generic idle_prompt body ("Claude is waiting for your input") names no
  // context. Replace it with the last thing Claude actually said - assistant text
  // for a normal turn, or a finished forked command's output (command_result) for
  // the SubagentStop-only case that is the only idle_prompt to survive dedup - so
  // the alert identifies the session + topic, matching a Stop notification. Falls
  // back to the generic message when the turn ended on a tool call (no assistant
  // text), the command produced no output, or the transcript can't be resolved.
  if (input.notification_type === "idle_prompt") {
    const tp = resolveTranscriptPath(input);
    if (tp) {
      const state = readLastAssistantState(tp);
      if (state.kind === "text" || state.kind === "command_result")
        body = state.text;
    }
  }
}

// remember we delivered a blocking-prompt notification (we are past the
// focused-pane suppression here), so the redundant ~6s permission_prompt - or a
// re-fire - dedups against it; cleared on Stop.
if (
  event === "PermissionRequest" ||
  (event === "PreToolUse" && input.tool_name === "AskUserQuestion") ||
  (event === "Notification" && input.notification_type === "permission_prompt")
) {
  markNotified(sessionId);
}

// mark this idle period as notified so the ~60s idle_prompt backstop dedups
// against the instant Stop notification (or against itself if it re-fires).
if (
  event === "Stop" ||
  (event === "Notification" && input.notification_type === "idle_prompt")
) {
  markIdle(sessionId);
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
