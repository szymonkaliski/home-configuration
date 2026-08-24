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
// line back to the session that produced it.
function createLogger(logPath, base = {}) {
  return function log(data) {
    const now = Date.now();
    try {
      fs.appendFileSync(
        logPath,
        JSON.stringify({
          ts: new Date(now).toISOString(),
          ...base,
          ...data,
        }) + "\n",
      );
      pruneLog(logPath, now);
    } catch {}
  };
}

// an alert is noise when the user is already watching the pane it came from
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
      if (
        flags &&
        flags.split(",").includes("focused") &&
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

// tnotify reaches the terminal the session runs in, which is where the user
// would act on the alert, so it goes first. Pushover is the fallback for when
// that terminal isn't reachable (a microVM has no tnotify at all) and one event
// stays one alert.
async function deliver({ title, body, log }) {
  log({ phase: "deliver", body });

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

module.exports = { truncate, createLogger, isFocusedPane, deliver };
