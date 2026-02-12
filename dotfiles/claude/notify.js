#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const { execFileSync, execSync } = require("child_process");

const input = JSON.parse(fs.readFileSync("/dev/stdin", "utf8"));
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

function readLastAssistantText(filePath) {
  const fd = fs.openSync(filePath, "r");
  try {
    const stat = fs.fstatSync(fd);
    const readSize = Math.min(stat.size, 65536);
    const buf = Buffer.alloc(readSize);
    fs.readSync(fd, buf, 0, readSize, stat.size - readSize);
    const chunk = buf.toString("utf8");

    // find complete JSONL lines (skip possible partial first line)
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

      if (entry.type === "assistant") {
        const contents = entry.message?.content;
        if (!Array.isArray(contents)) return null;
        for (let j = contents.length - 1; j >= 0; j--) {
          if (contents[j].type === "text" && contents[j].text?.trim()) {
            return contents[j].text.trim().slice(0, 200);
          }
        }
      }
      // last meaningful entry is not assistant text — race condition
      return null;
    }
  } finally {
    fs.closeSync(fd);
  }
  return null;
}

let body;

if (event === "Stop") {
  body = "Waiting";
  if (transcriptPath && fs.existsSync(transcriptPath)) {
    let text = readLastAssistantText(transcriptPath);

    if (!text) {
      // race condition: poll until assistant text appears
      const sab = new SharedArrayBuffer(4);
      const view = new Int32Array(sab);
      const deadline = Date.now() + 2000;
      while (Date.now() < deadline) {
        Atomics.wait(view, 0, 0, 50);
        text = readLastAssistantText(transcriptPath);
        if (text) break;
      }
    }

    if (text) body = text;
  }
} else {
  body = input.message || "Notification";
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
