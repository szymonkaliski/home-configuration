// Status logging plumbing shared by the agent harness hooks (claude, opencode):
// the focused-pane check and the rolling JSONL log read by orchestrator.
//
// Every harness links this file into its own config directory and loads it by
// absolute path. On a host each harness entry point is a symlink into this
// repo, while a microVM gets a plain copy of it, so a relative specifier
// resolves to a different place in the two environments.

const fs = require("fs");
const os = require("os");
const { execSync } = require("child_process");

const LOG_RETAIN_MS = 90 * 24 * 60 * 60 * 1000;
const LOG_PRUNE_SLACK_MS = 7 * 24 * 60 * 60 * 1000;

function truncate(str, max) {
  if (!str) return "";
  if (str.length <= max) return str;
  let cut = str.slice(0, max);
  // if the cutoff lands mid-word, drop the trailing partial word
  if (/\S/.test(str[max])) {
    const atBoundary = cut.replace(/\S+$/, "").trimEnd();
    if (atBoundary) cut = atBoundary;
  }
  return cut.trimEnd() + "…";
}

function formatToolUse(name, input) {
  const tool = name || "tool";
  const inp = input || {};

  if (tool === "Bash" || tool === "bash" || tool === "shell") {
    return `${tool}: ${truncate(inp.command || "", 120)}`;
  }
  if (
    tool === "Edit" ||
    tool === "edit" ||
    tool === "Write" ||
    tool === "write" ||
    tool === "Read" ||
    tool === "read"
  ) {
    return `${tool}: ${inp.file_path || inp.filePath || inp.path || "?"}`;
  }
  if (tool === "AskUserQuestion" || tool === "question") {
    const q = inp.questions?.[0]?.question;
    return q ? `Question: ${truncate(q, 120)}` : "Question";
  }

  const detail =
    inp.command ||
    inp.description ||
    inp.pattern ||
    inp.file_path ||
    inp.filePath ||
    inp.path ||
    inp.url ||
    inp.query ||
    Object.values(inp).find((v) => typeof v === "string" && v);
  if (detail) return `${tool}: ${truncate(String(detail), 100)}`;
  return tool;
}

// Keep ~3 months of entries. The first field of every line is "ts", so peek at
// the head of the file to find the oldest entry cheaply; only rewrite the whole
// file once entries spill a slack window past the retention edge, so the full
// rewrite happens roughly weekly rather than on every event.
function pruneLog(logPath, now) {
  let fd;
  let oldestTs;
  try {
    fd = fs.openSync(logPath, "r");
    const head = Buffer.alloc(128);
    const n = fs.readSync(fd, head, 0, 128, 0);
    const m = head.toString("utf8", 0, n).match(/"ts":"([^"]+)"/);
    oldestTs = m ? Date.parse(m[1]) : NaN;
  } catch {
    return;
  } finally {
    if (fd !== undefined) {
      try {
        fs.closeSync(fd);
      } catch {}
    }
  }
  if (!Number.isFinite(oldestTs)) return;
  if (oldestTs >= now - LOG_RETAIN_MS - LOG_PRUNE_SLACK_MS) return;

  const cutoff = now - LOG_RETAIN_MS;
  try {
    const kept = fs
      .readFileSync(logPath, "utf8")
      .split("\n")
      .filter((line) => {
        const m = line.match(/"ts":"([^"]+)"/);
        return m ? Date.parse(m[1]) >= cutoff : false;
      });
    fs.writeFileSync(logPath, kept.length ? kept.join("\n") + "\n" : "");
  } catch {}
}

// Several sessions interleave in one log, so `base` carries whatever identifier
// ties a line back to the session that produced it. Every line also carries
// where it came from (host, tmux pane, cwd), so orchestrator can join it to a
// tmux pane without knowing the harness's own session bookkeeping.
function createLogger(logPath, base = {}) {
  // the short name: macOS reports "orchid.local", the config keys are short
  const origin = { host: os.hostname().split(".")[0], cwd: process.cwd() };
  if (process.env.TMUX_PANE) origin.pane = process.env.TMUX_PANE;
  return function log(data) {
    const now = Date.now();
    try {
      fs.appendFileSync(
        logPath,
        JSON.stringify({
          ts: new Date(now).toISOString(),
          ...origin,
          ...base,
          ...data,
        }) + "\n",
      );
      pruneLog(logPath, now);
    } catch {}
  };
}

// A transition is already seen when the user is watching the pane it came from.
// A control-mode client (the orchestrator feed) is attached and focused on its
// session's active pane too, but nobody looks through it.
function isFocusedPane() {
  if (!process.env.TMUX || !process.env.TMUX_PANE) return false;
  try {
    const myPane = process.env.TMUX_PANE;
    const clients = execSync(
      "tmux list-clients -F '#{client_flags}\t#{pane_id}'",
      { encoding: "utf8" },
    )
      .trim()
      .split("\n");

    for (const row of clients) {
      const [flags, activePane] = row.split("\t");
      const set = flags ? flags.split(",") : [];
      if (
        set.includes("focused") &&
        !set.includes("control-mode") &&
        activePane === myPane
      ) {
        return true;
      }
    }
  } catch {}
  return false;
}

module.exports = {
  truncate,
  formatToolUse,
  createLogger,
  isFocusedPane,
};
