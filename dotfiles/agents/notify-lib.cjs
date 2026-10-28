// Notification plumbing shared by the agent harness notifiers (claude,
// opencode, agy): the delivery channels, the focused-pane check, and the
// rolling log they all write.
//
// Every harness links this file into its own config directory and loads it by
// absolute path. On a host each harness entry point is a symlink into this
// repo, while a microVM gets a plain copy of it, so a relative specifier
// resolves to a different place in the two environments.

const fs = require("fs");
const os = require("os");
const { execFileSync, execSync } = require("child_process");

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
    inp.CommandLine ||
    inp.description ||
    inp.pattern ||
    inp.file_path ||
    inp.filePath ||
    inp.path ||
    inp.AbsolutePath ||
    inp.DirectoryPath ||
    inp.url ||
    inp.query ||
    inp.toolSummary ||
    inp.toolAction ||
    Object.values(inp).find((v) => typeof v === "string" && v);
  if (detail) return `${tool}: ${truncate(String(detail), 100)}`;
  return tool;
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

// Keep ~3 months of entries. The first field of every line is "ts", so peek at
// the head of the file to find the oldest entry cheaply; only rewrite the whole
// file once entries spill a slack window past the retention edge, so the full
// rewrite happens roughly weekly rather than on every notification.
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

// Several sessions interleave in one log, and a pushover `sent` line lands a few
// hundred ms after its `fire` line, so `base` carries whatever identifier ties a
// line back to the session that produced it. Every line also carries where it
// came from (host, tmux pane, cwd), so a reader can join it to a tmux pane
// without knowing the harness's own session bookkeeping.
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

// an alert is noise when the user is already watching the pane it came from.
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

//   { kind: "ok" }         usable token pair
//   { kind: "missing-rc" } sops never rendered the file (or this is a VM
//                          started without the host's pushoverrc)
//   { kind: "no-tokens" }  the file is there but one of the keys is not
function readPushoverConfig() {
  const rcPath = `${os.homedir()}/.pushoverrc`;
  if (!fs.existsSync(rcPath)) return { kind: "missing-rc" };

  const vars = {};
  for (const line of fs.readFileSync(rcPath, "utf8").split("\n")) {
    const m = line.match(/^(\w+)=(.+)$/);
    if (m) vars[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  if (!vars.PUSHOVER_TOKEN || !vars.PUSHOVER_USER) return { kind: "no-tokens" };
  return { kind: "ok", token: vars.PUSHOVER_TOKEN, user: vars.PUSHOVER_USER };
}

function isOnPath(command) {
  return (process.env.PATH || "").split(":").some((dir) => {
    try {
      fs.accessSync(`${dir}/${command}`, fs.constants.X_OK);
      return true;
    } catch {
      return false;
    }
  });
}

// tnotify reaches the terminal the session runs in, which is where the user
// would act on the alert, so it goes first where it is installed (orchid).
// Pushover is the fallback for a host without tnotify (minix, a microVM) and
// for a terminal tnotify can't reach, and one event stays one alert.
async function deliver({ title, body, log }) {
  log({ phase: "deliver", body });

  if (isOnPath("tnotify")) {
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
      log({ phase: "sent", channel: "tnotify", body });
      return;
    } catch (err) {
      log({
        phase: "channel-failed",
        channel: "tnotify",
        error: String((err && err.message) || err),
      });
    }
  } else {
    log({ phase: "skipped", reason: "tnotify-not-on-path" });
  }

  const pushover = readPushoverConfig();
  if (pushover.kind !== "ok") {
    log({ phase: "skipped", reason: `pushover-${pushover.kind}` });
    return;
  }

  try {
    const res = await fetch("https://api.pushover.net/1/messages.json", {
      method: "POST",
      body: new URLSearchParams({
        token: pushover.token,
        user: pushover.user,
        title,
        message: body,
      }),
    });
    if (res.ok) {
      log({ phase: "sent", channel: "pushover", status: res.status, body });
    } else {
      log({
        phase: "channel-failed",
        channel: "pushover",
        status: res.status,
        error: "HTTP error " + res.status,
      });
    }
  } catch (err) {
    log({
      phase: "channel-failed",
      channel: "pushover",
      error: String((err && err.message) || err),
    });
  }
}

module.exports = {
  truncate,
  formatToolUse,
  readTail,
  createLogger,
  isFocusedPane,
  deliver,
};
