#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
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

// idle-state marker: records the body delivered for this idle period (by Stop or
// a previous idle_prompt). The ~60s idle_prompt Notification is suppressed only
// when it would repeat that same body, so it still backstops turns that fire no
// Stop: a finished `context: fork` slash-command resolves to its command output,
// which differs from the last Stop's text and passes the body check. Keying on
// the body (not just freshness) matters because background Task agents finish
// after the turn's Stop, and a time-only marker either dedups the fork case away
// or lets the same text re-deliver.
function markIdle(sid, body) {
  if (!sid) return;
  try {
    fs.mkdirSync(PENDING_DIR, { recursive: true });
    fs.writeFileSync(
      pendingFile(`${sid}__idle`),
      JSON.stringify({ ts: Date.now(), body }),
    );
  } catch {}
}
function wasIdleNotified(sid, body) {
  if (!sid) return false;
  try {
    const rec = JSON.parse(
      fs.readFileSync(pendingFile(`${sid}__idle`), "utf8"),
    );
    return Date.now() - rec.ts <= PENDING_FRESH_MS && rec.body === body;
  } catch {
    return false;
  }
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

// Only Stop, PermissionRequest, and Notification are hooked, but sessions
// started before a settings change keep their old hook registrations and can
// invoke us for since-removed events (PreToolUse, SubagentStop); ignore those
// instead of letting them fall through to the generic-Notification branch.
if (!["Stop", "PermissionRequest", "Notification"].includes(event)) {
  logLine({ phase: "skipped", reason: "unhooked-event", event });
  process.exit(0);
}

// skip the notification when the user is actively looking at this pane
if (process.env.TMUX && process.env.TMUX_PANE) {
  try {
    const myPane = process.env.TMUX_PANE;
    const clients = execSync(
      "tmux list-clients -F '#{client_flags}\t#{pane_id}'",
      {
        encoding: "utf8",
      },
    )
      .trim()
      .split("\n");

    for (const row of clients) {
      const [flags, activePane] = row.split("\t");
      if (
        flags &&
        flags.split(",").includes("focused") &&
        activePane === myPane
      ) {
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
          return {
            kind: "text",
            text: truncate(contents[j].text.trim(), 200),
            ts: entry.timestamp,
          };
        }
      }
      return { kind: "assistant_without_text" };
    }
    return { kind: "not_assistant" };
  } finally {
    fs.closeSync(fd);
  }
}

// Stop/PermissionRequest carry transcript_path, but Notification
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
  // a Stop re-fired by a blocking stop hook's continuation, not a turn end
  if (input.stop_hook_active) {
    logLine({ phase: "skipped", reason: "stop-hook-active", event });
    process.exit(0);
  }
  if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    logLine({ phase: "skipped", reason: "no-transcript", event });
    process.exit(0);
  }
  if (lastUserOriginIsTaskNotification(transcriptPath)) {
    logLine({ phase: "skipped", reason: "task-notification", event });
    process.exit(0);
  }

  // Reopening an old session appends metadata lines (ai-title, mode, last-prompt)
  // after the final assistant text and can fire Stop, which would re-deliver
  // hours-old text as if the turn just ended. Legit final text lands seconds
  // before Stop (or up to ~15s after, for the thinking case), so a transcript
  // whose newest assistant text is older than the staleness window means a
  // reopen, not a turn end.
  const STALE_MS = 5 * 60 * 1000;
  const hookStart = Date.now();
  const isStaleText = (state) => {
    if (state.kind !== "text" || !state.ts) return false;
    const t = Date.parse(state.ts);
    return Number.isFinite(t) && hookStart - t > STALE_MS;
  };

  const payloadText =
    typeof input.last_assistant_message === "string" &&
    input.last_assistant_message.trim();
  if (payloadText) {
    // Since v2.1.47 the Stop payload carries the final text directly, ahead of
    // the transcript flush (anthropics/claude-code#74340), so no polling; the
    // transcript is read once, only for the reopen staleness guard.
    if (isStaleText(readLastAssistantState(transcriptPath))) {
      logLine({ phase: "skipped", reason: "stale-assistant-text", event });
      process.exit(0);
    }
    body = truncate(payloadText, 200);
  } else {
    // Older versions: poll-read the transcript tail until the final text lands.
    // A stale read keeps polling too - mid-turn the last text can be the
    // previous turn's while the current one streams, and the fresh line may
    // still land before the deadline.
    const sab = new SharedArrayBuffer(4);
    const view = new Int32Array(sab);
    const deadline = Date.now() + 30000;
    let state = readLastAssistantState(transcriptPath);
    while (
      (state.kind !== "text" || isStaleText(state)) &&
      Date.now() < deadline
    ) {
      Atomics.wait(view, 0, 0, 200);
      state = readLastAssistantState(transcriptPath);
    }

    if (state.kind !== "text" || isStaleText(state)) {
      logLine({
        phase: "skipped",
        reason:
          state.kind === "text" ? "stale-assistant-text" : "no-assistant-text",
        kind: state.kind,
      });
      process.exit(0);
    }
    body = state.text;
  }
} else if (event === "PermissionRequest") {
  // Fires the instant a real permission dialog appears (never for auto-approved
  // calls) and carries the tool input - so we name exactly what's awaited,
  // immediately. This is the primary blocking-prompt notification, and it covers
  // AskUserQuestion too: the chooser goes through the permission dialog path.
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

  // The generic idle_prompt body ("Claude is waiting for your input") names no
  // context. Replace it with the last thing Claude actually said - assistant text
  // for a normal turn, or a finished forked command's output (command_result) -
  // so the alert identifies the session + topic, matching a Stop notification.
  // Falls back to the generic message when the turn ended on a tool call (no
  // assistant text), the command produced no output, or the transcript can't be
  // resolved. Then dedup on that resolved body: if this idle period already
  // delivered the same text (via Stop or an earlier idle_prompt), drop it.
  if (input.notification_type === "idle_prompt") {
    const tp = resolveTranscriptPath(input);
    if (tp && lastUserOriginIsTaskNotification(tp)) {
      logLine({ phase: "skipped", reason: "task-notification", event });
      process.exit(0);
    }
    if (tp) {
      const state = readLastAssistantState(tp);
      if (state.kind === "text" || state.kind === "command_result")
        body = state.text;
    }
    if (wasIdleNotified(sessionId, body)) {
      logLine({ phase: "suppressed", reason: "idle-already-notified", event });
      process.exit(0);
    }
  }
}

// remember we delivered a blocking-prompt notification (we are past the
// focused-pane suppression here), so the redundant ~6s permission_prompt - or a
// re-fire - dedups against it; cleared on Stop.
if (
  event === "PermissionRequest" ||
  (event === "Notification" && input.notification_type === "permission_prompt")
) {
  markNotified(sessionId);
}

// record what this idle period delivered so the ~60s idle_prompt backstop dedups
// against the instant Stop notification (or against itself if it re-fires).
if (
  event === "Stop" ||
  (event === "Notification" && input.notification_type === "idle_prompt")
) {
  markIdle(sessionId, body);
}

const title = `Claude Code (${os.hostname()} - ${path.basename(process.cwd())})`;

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
        if (res.ok) {
          logLine({
            phase: "sent",
            channel: "pushover",
            status: res.status,
            body,
          });
        } else {
          logLine({
            phase: "channel-failed",
            channel: "pushover",
            status: res.status,
            error: "HTTP error " + res.status,
          });
        }
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
