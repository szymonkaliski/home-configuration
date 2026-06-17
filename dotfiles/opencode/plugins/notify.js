import fs from "fs";
import os from "os";
import { execFileSync, execSync } from "child_process";

const LOG_PATH = `${os.homedir()}/.config/opencode/notify.log`;
const LOG_RETAIN_MS = 90 * 24 * 60 * 60 * 1000;
const LOG_PRUNE_SLACK_MS = 7 * 24 * 60 * 60 * 1000;

function truncate(str, max) {
  if (!str) return "";
  if (str.length <= max) return str;
  let cut = str.slice(0, max);
  if (/\S/.test(str[max])) {
    const atBoundary = cut.replace(/\S+$/, "").trimEnd();
    if (atBoundary) cut = atBoundary;
  }
  return cut.trimEnd() + "…";
}

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

function pruneLog(now) {
  let fd;
  let oldestTs;
  try {
    fd = fs.openSync(LOG_PATH, "r");
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
      .readFileSync(LOG_PATH, "utf8")
      .split("\n")
      .filter((line) => {
        const m = line.match(/"ts":"([^"]+)"/);
        return m ? Date.parse(m[1]) >= cutoff : false;
      });
    fs.writeFileSync(LOG_PATH, kept.length ? kept.join("\n") + "\n" : "");
  } catch {}
}

function shouldSuppressNotification() {
  if (process.env.TMUX && process.env.TMUX_PANE) {
    try {
      const myPane = process.env.TMUX_PANE;
      const clients = execSync(
        "tmux list-clients -F '#{client_flags}\t#{session_name}'",
        { encoding: "utf8" },
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
          return true;
        }
      }
    } catch {}
  }
  return false;
}

function sendNotification(title, body, event) {
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
        },
        (err) => {
          logLine({
            phase: "channel-failed",
            channel: "pushover",
            error: String((err && err.message) || err),
          });
        },
      );
    } else {
      logLine({ phase: "skipped", reason: "pushover-no-tokens" });
    }
  } else {
    logLine({ phase: "skipped", reason: "no-pushoverrc" });
  }
}

export const NotifyPlugin = async ({ client }) => {
  // opencode delivers all events through a single `event` hook keyed by
  // event.type (named hooks like "session.idle" are never dispatched)
  async function notifyIdle(sessionID) {
    const event = "session.idle";
    logLine({ phase: "fire", event });

    if (shouldSuppressNotification()) {
      logLine({ phase: "suppressed", reason: "focused-pane", event });
      return;
    }

    let body = "OpenCode is waiting for your input";
    try {
      const messagesResult = await client.session.messages({
        path: { id: sessionID },
      });
      if (messagesResult?.data) {
        const messages = messagesResult.data;
        for (let i = messages.length - 1; i >= 0; i--) {
          const msg = messages[i];
          if (msg.info.role === "assistant") {
            const textParts = msg.parts.filter(
              (p) => p.type === "text" && p.text?.trim(),
            );
            if (textParts.length > 0) {
              body = truncate(textParts[textParts.length - 1].text.trim(), 200);
            }
            break;
          }
        }
      }
    } catch (err) {
      logLine({
        phase: "fetch-context-failed",
        error: String((err && err.message) || err),
      });
    }

    sendNotification(`OpenCode (${os.hostname()})`, body, event);
  }

  function notifyPermission(perm) {
    const event = "permission.asked";
    logLine({ phase: "fire", event, perm });

    if (shouldSuppressNotification()) {
      logLine({ phase: "suppressed", reason: "focused-pane", event });
      return;
    }

    const tool = perm?.permission || "tool";
    const meta = perm?.metadata || {};
    const detail =
      meta.command ||
      meta.description ||
      meta.filePath ||
      meta.path ||
      perm?.patterns?.[0] ||
      "";
    const body = detail
      ? `${tool}: ${truncate(String(detail), 140)}`
      : `${tool} permission request`;

    sendNotification(`OpenCode (${os.hostname()})`, body, event);
  }

  return {
    event: async ({ event }) => {
      if (event?.type === "session.idle") {
        await notifyIdle(event.properties?.sessionID);
      } else if (event?.type === "permission.asked") {
        notifyPermission(event.properties);
      }
    },
  };
};
