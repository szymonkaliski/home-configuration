#!/usr/bin/env node

// agy (Antigravity CLI) notifier, wired from ~/.gemini/config/hooks.json. It
// runs as `notify.js <event>` with the hook payload as JSON on stdin and prints
// that event's result JSON on stdout.
//
//   stop      the execution loop ended, so agy is waiting for input
//   pretool   arms a watcher for one tool call
//   posttool  the tool call finished, so disarm its watcher
//   watch     the detached watcher itself, spawned by pretool
//
// agy exposes no permission-request hook, so a blocking prompt is inferred: a
// tool call that has produced neither a PostToolUse hook nor a transcript entry
// after PERMISSION_WAIT_MS is taken to be sitting on one. A tool that legitimately
// runs longer than that alerts too.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const CONFIG_DIR = `${os.homedir()}/.gemini/config`;
const { truncate, createLogger, isFocusedPane, deliver } = require(
  `${CONFIG_DIR}/notify-lib.cjs`,
);

const LOG_PATH = `${os.homedir()}/.gemini/notify.log`;
const PENDING_DIR = `${os.homedir()}/.gemini/notify-pending`;
const PENDING_FRESH_MS = 10 * 60 * 1000;

const PERMISSION_WAIT_MS = 12000;
const WATCH_POLL_MS = 500;
const TRANSCRIPT_WAIT_MS = 5000;
const TRANSCRIPT_POLL_MS = 200;
const BODY_MAX = 200;
const DETAIL_MAX = 120;

const IDLE_BODY = "Antigravity is waiting for your input";

let log = createLogger(LOG_PATH);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Hooks run with their working directory set to the directory holding
// hooks.json, so the session's project comes from the payload, never from cwd.
function titleFor(input) {
  const workspace =
    Array.isArray(input.workspacePaths) && input.workspacePaths[0];
  const where = workspace ? path.basename(workspace) : "no workspace";
  return `Antigravity (${os.hostname()} - ${where})`;
}

function formatToolCall(toolCall) {
  const name = (toolCall && toolCall.name) || "tool";
  const args = (toolCall && toolCall.args) || {};

  const detail =
    args.CommandLine ||
    args.AbsolutePath ||
    args.DirectoryPath ||
    args.toolSummary ||
    args.toolAction ||
    Object.values(args).find((v) => typeof v === "string");

  return detail ? `${name}: ${truncate(String(detail), DETAIL_MAX)}` : name;
}

// One marker per in-flight tool call. stepIdx is stable across a call's
// PreToolUse and PostToolUse hooks, so it keys the pair.
function markerPath(conversationId, stepIdx) {
  const id = String(conversationId).replace(/[^\w.-]/g, "_");
  return `${PENDING_DIR}/${id}__${stepIdx}.json`;
}

function clearMarker(conversationId, stepIdx) {
  try {
    fs.unlinkSync(markerPath(conversationId, stepIdx));
  } catch {}
}

function clearConversationMarkers(conversationId) {
  const prefix = `${String(conversationId).replace(/[^\w.-]/g, "_")}__`;
  try {
    for (const name of fs.readdirSync(PENDING_DIR)) {
      if (name.startsWith(prefix)) fs.unlinkSync(`${PENDING_DIR}/${name}`);
    }
  } catch {}
}

// a tool call denied at the prompt never reaches PostToolUse, so its marker
// outlives the call and only this sweep removes it
function sweepStaleMarkers() {
  const now = Date.now();
  try {
    for (const name of fs.readdirSync(PENDING_DIR)) {
      const p = `${PENDING_DIR}/${name}`;
      try {
        if (now - fs.statSync(p).mtimeMs > PENDING_FRESH_MS) fs.unlinkSync(p);
      } catch {}
    }
  } catch {}
}

function readTail(filePath, maxBytes = 65536) {
  const fd = fs.openSync(filePath, "r");
  try {
    const stat = fs.fstatSync(fd);
    const readSize = Math.min(stat.size, maxBytes);
    const buf = Buffer.alloc(readSize);
    fs.readSync(fd, buf, 0, readSize, stat.size - readSize);
    const chunk = buf.toString("utf8");
    // a window smaller than the file starts mid-entry, so drop that first line
    const body =
      readSize < stat.size ? chunk.slice(chunk.indexOf("\n") + 1) : chunk;
    return body.split("\n").filter(Boolean);
  } finally {
    fs.closeSync(fd);
  }
}

// agy appends a transcript entry per step, and a turn's reply is a
// PLANNER_RESPONSE carrying content (the same entry type holds tool calls, which
// omit the field). Scan back to the newest one: a contentless entry, or a user
// prompt, means the reply has yet to reach disk and the caller should keep
// polling rather than deliver the previous turn's text.
//   { kind: "text" }               the reply
//   { kind: "awaiting_response" }  nothing final written yet
//   { kind: "no_response" }        the window holds no reply at all
function lastResponseState(transcriptPath) {
  for (const line of readTail(transcriptPath).reverse()) {
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    if (entry.type === "USER_INPUT") return { kind: "awaiting_response" };
    if (entry.type !== "PLANNER_RESPONSE") continue;
    if (typeof entry.content === "string" && entry.content.trim()) {
      return { kind: "text", text: truncate(entry.content.trim(), BODY_MAX) };
    }
    return { kind: "awaiting_response" };
  }
  return { kind: "no_response" };
}

// The Stop payload carries a finalModelOutput field that agy 1.1.13 leaves
// empty, so the reply comes from the transcript, and Stop can fire before that
// entry is flushed.
async function resolveIdleBody(transcriptPath) {
  if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    log({ phase: "fallback-body", reason: "no-transcript" });
    return IDLE_BODY;
  }

  const deadline = Date.now() + TRANSCRIPT_WAIT_MS;
  for (;;) {
    let state;
    try {
      state = lastResponseState(transcriptPath);
    } catch (err) {
      log({
        phase: "fallback-body",
        reason: "transcript-unreadable",
        error: String((err && err.message) || err),
      });
      return IDLE_BODY;
    }
    if (state.kind === "text") return state.text;
    if (Date.now() >= deadline) {
      log({ phase: "fallback-body", reason: state.kind });
      return IDLE_BODY;
    }
    await sleep(TRANSCRIPT_POLL_MS);
  }
}

// agy records a step once its tool call is done, so an entry under this step
// index means the call went through. It is the only disarm signal for
// call_mcp_tool, which fires PreToolUse but no PostToolUse.
function stepCompleted(pending) {
  if (!pending.transcriptPath) return false;
  try {
    for (const line of readTail(pending.transcriptPath)) {
      let entry;
      try {
        entry = JSON.parse(line);
      } catch {
        continue;
      }
      if (entry.step_index === pending.stepIdx) return true;
    }
  } catch {}
  return false;
}

async function stop(input) {
  fs.writeSync(1, "{}");
  clearConversationMarkers(input.conversationId);

  log({ phase: "fire", event: "stop", reason: input.terminationReason });

  if (isFocusedPane()) {
    log({ phase: "suppressed", reason: "focused-pane", event: "stop" });
    return;
  }

  await deliver({
    title: titleFor(input),
    body: await resolveIdleBody(input.transcriptPath),
    log: (data) => log({ event: "stop", ...data }),
  });
}

function pretool(input) {
  // Empty stdout leaves the tool call alone. Any JSON object here is read as a
  // decision, and one without a `decision` field denies the call outright.
  if (input.stepIdx === undefined || !input.conversationId) {
    log({ phase: "skipped", reason: "no-step-key", event: "pretool" });
    return;
  }

  const marker = markerPath(input.conversationId, input.stepIdx);
  try {
    fs.mkdirSync(PENDING_DIR, { recursive: true });
    fs.writeFileSync(
      marker,
      JSON.stringify({
        conversationId: input.conversationId,
        stepIdx: input.stepIdx,
        title: titleFor(input),
        detail: formatToolCall(input.toolCall),
        transcriptPath: input.transcriptPath || null,
      }),
    );
  } catch (err) {
    log({
      phase: "skipped",
      reason: "marker-write-failed",
      event: "pretool",
      error: String((err && err.message) || err),
    });
    return;
  }
  sweepStaleMarkers();

  // detached because hooks block agy's loop and this one has to outlive the
  // tool call it watches
  spawn(process.execPath, [__filename, "watch", marker], {
    detached: true,
    stdio: "ignore",
  }).unref();

  log({
    phase: "armed",
    event: "pretool",
    stepIdx: input.stepIdx,
    tool: input.toolCall && input.toolCall.name,
  });
}

function posttool(input) {
  fs.writeSync(1, "{}");
  clearMarker(input.conversationId, input.stepIdx);
}

async function watch(marker) {
  let pending;
  try {
    pending = JSON.parse(fs.readFileSync(marker, "utf8"));
  } catch {
    return;
  }
  log = createLogger(LOG_PATH, { conversation: pending.conversationId });

  const deadline = Date.now() + PERMISSION_WAIT_MS;
  while (Date.now() < deadline) {
    await sleep(WATCH_POLL_MS);
    if (!fs.existsSync(marker)) return;
    if (stepCompleted(pending)) {
      try {
        fs.unlinkSync(marker);
      } catch {}
      return;
    }
  }
  // Stop clears every marker of its conversation, so a turn that ended while
  // this watcher slept takes the alert with it
  if (!fs.existsSync(marker)) return;
  try {
    fs.unlinkSync(marker);
  } catch {}

  log({ phase: "fire", event: "permission", stepIdx: pending.stepIdx });

  if (isFocusedPane()) {
    log({ phase: "suppressed", reason: "focused-pane", event: "permission" });
    return;
  }

  await deliver({
    title: pending.title,
    body: `permission needed: ${pending.detail}`,
    log: (data) => log({ event: "permission", ...data }),
  });
}

async function main() {
  const event = process.argv[2];
  if (event === "watch") return watch(process.argv[3]);

  const input = JSON.parse(fs.readFileSync(0, "utf8"));
  log = createLogger(LOG_PATH, { conversation: input.conversationId });

  switch (event) {
    case "stop":
      return stop(input);
    case "pretool":
      return pretool(input);
    case "posttool":
      return posttool(input);
    default:
      log({ phase: "skipped", reason: "unknown-event", event });
  }
}

main().finally(() => process.exit(0));
