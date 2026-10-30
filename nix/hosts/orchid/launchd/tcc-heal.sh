#!/usr/bin/env bash

# Clears a macOS privacy (TCC) deny stuck on ~/Documents, ~/Desktop, or
# ~/Downloads for terminal and tmux process trees.
#
# Failure mode: sandboxd asks tccd whether a process may read a protected
# folder, tccd answers with an error instead of a verdict ("Failed to create
# Attribution Chain from message", kTCCErrorDomain code 5), and sandboxd caches
# that error as a deny for the responsible app's process tree. Resetting the
# folder entry for the responsible app publishes a TCC change event that drops
# the cached deny while keeping Full Disk Access intact.
#
# Logs: ~/Library/Logs/com.szymonkaliski.tcc-heal.log
#
# Upstream:
#   https://github.com/anthropics/claude-code/issues/90227
#   https://github.com/anthropics/claude-code/issues/96996
#   https://github.com/anthropics/claude-code/issues/58952
#   https://github.com/ghostty-org/ghostty/discussions/12947
#   https://github.com/ghostty-org/ghostty/discussions/2998

exec /Users/szymon/.nix-profile/bin/node - << 'EOF'
const fs = require("fs");
const os = require("os");
const readline = require("readline");
const { execFileSync, spawn } = require("child_process");

const HOME = os.homedir();
const RESET_COOLDOWN_MS = 2000;
const PID_CACHE_TTL_MS = 10 * 1000;
const SKIP_LOG_TTL_MS = 60 * 1000;

const SERVICE_BY_FOLDER = {
  Documents: "SystemPolicyDocumentsFolder",
  Desktop: "SystemPolicyDesktopFolder",
  Downloads: "SystemPolicyDownloadsFolder",
};

// Only terminal and tmux bundles with Full Disk Access are eligible for reset.
const ALLOWED_BUNDLE_IDS = new Set([
  "com.szymonkaliski.tmux",
  "com.mitchellh.ghostty",
  "com.apple.Terminal",
]);

// Only inspect denies from known shell, terminal, and agent CLI processes.
const KNOWN_CLI_PROCS = new Set([
  "bash",
  "cat",
  "claude",
  "claude.exe",
  "coreutils",
  "direnv",
  "fd",
  "git",
  "gitstatusd-darwin-arm64",
  "ls",
  "node",
  "nvim",
  "opencode",
  "opencode.exe",
  "rg",
  "sh",
  "tmux",
  "zsh",
]);

function log(line) {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  const ts = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
  process.stdout.write(`[${ts}] ${line}\n`);
}

function isPidAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// Returns { kind: "bundle", id, respPid } | { kind: "non-bundle", detail } | { kind: "gone" }.
function resolveResponsible(pid) {
  const script =
    "ObjC.import('AppKit');" +
    "ObjC.bindFunction('responsibility_get_pid_responsible_for_pid',['int',['int']]);" +
    "function run(a){const r=$.responsibility_get_pid_responsible_for_pid(+a[0]);" +
    "if(r<=0)return '';" +
    "const app=$.NSRunningApplication.runningApplicationWithProcessIdentifier(r);" +
    "const id=(app&&!app.isNil()&&ObjC.unwrap(app.bundleIdentifier))||'';" +
    "return r+'\\t'+id;}";
  try {
    const out = execFileSync(
      "/usr/bin/osascript",
      ["-l", "JavaScript", "-e", script, String(pid)],
      {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
        timeout: 5000,
      },
    ).trim();
    if (!out) {
      return isPidAlive(pid)
        ? { kind: "non-bundle", detail: "no-responsible-pid" }
        : { kind: "gone" };
    }
    const [respPid, directId] = out.split("\t");
    if (directId) return { kind: "bundle", id: directId, respPid };
    const comm = execFileSync("/bin/ps", ["-o", "comm=", "-p", respPid], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 3000,
    }).trim();
    if (!comm) return { kind: "gone" };
    const m = comm.match(/^(.+\.app)\/Contents\/MacOS\//);
    if (!m) return { kind: "non-bundle", detail: `${respPid}:${comm}` };
    const plist = fs.readFileSync(`${m[1]}/Contents/Info.plist`, "utf8");
    const id = plist.match(
      /<key>CFBundleIdentifier<\/key>\s*<string>([^<]+)<\/string>/,
    );
    return id
      ? { kind: "bundle", id: id[1].trim(), respPid }
      : { kind: "non-bundle", detail: `${respPid}:${comm}` };
  } catch {
    return isPidAlive(pid)
      ? { kind: "non-bundle", detail: "lookup-error" }
      : { kind: "gone" };
  }
}

const lastResetByService = new Map();
const pidCache = new Map();
const skipLogAt = new Map();

function logSkip(folder, procName, pid, reason, deniedPath) {
  const now = Date.now();
  if (skipLogAt.size > 500) skipLogAt.clear();
  const key = `${folder}:${procName}:${reason}`;
  if (now - (skipLogAt.get(key) || 0) < SKIP_LOG_TTL_MS) return;
  skipLogAt.set(key, now);
  log(
    `skip ${folder}: ${procName}(${pid}) reason=${reason} path=${deniedPath}`,
  );
}

function resetTargets(folder, service, ids, procName, pid, responsible, deniedPath) {
  log(
    `heal ${folder}: ${procName}(${pid}) responsible=${responsible} path=${deniedPath}`,
  );
  for (const id of ids) {
    try {
      execFileSync("/usr/bin/tccutil", ["reset", service, id], {
        stdio: "pipe",
        timeout: 10000,
      });
      log(`reset ${service} ${id}`);
    } catch (err) {
      log(
        `reset ${service} ${id} failed: ${String(err.message).split("\n")[0]}`,
      );
    }
    lastResetByService.set(service, Date.now());
  }
}

const folderPredicates = Object.keys(SERVICE_BY_FOLDER)
  .map((f) => `eventMessage CONTAINS "${HOME}/${f}"`)
  .join(" OR ");
const predicate = `processID == 0 AND sender == "Sandbox" AND eventMessage BEGINSWITH "System Policy:" AND (${folderPredicates})`;

const child = spawn(
  "/usr/bin/log",
  ["stream", "--style", "compact", "--predicate", predicate],
  { stdio: ["ignore", "pipe", "inherit"] },
);

log(
  `watching Sandbox System Policy denies on ${Object.keys(SERVICE_BY_FOLDER)
    .map((f) => `~/${f}`)
    .join(", ")}`,
);

const stop = () => {
  child.kill("SIGTERM");
  process.exit(0);
};
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
child.on("exit", (code) => {
  log(`log stream exited with code ${code ?? 1}`);
  process.exit(code ?? 1);
});

const denyRe =
  /System Policy: (.+)\((\d+)\) deny\(\d+\) \S+ (\/Users\/[^/]+\/(Documents|Desktop|Downloads)(?:\/.*)?)/;
const rl = readline.createInterface({ input: child.stdout });

rl.on("line", (line) => {
  const m = denyRe.exec(line);
  if (!m) return;
  const [, procName, pidStr, deniedPath, folder] = m;
  const pid = Number(pidStr);
  const service = SERVICE_BY_FOLDER[folder];
  if (!service || !pid) return;

  if (!KNOWN_CLI_PROCS.has(procName)) {
    logSkip(folder, procName, pid, "unlisted-proc", deniedPath);
    return;
  }

  const now = Date.now();
  if (now - (lastResetByService.get(service) || 0) < RESET_COOLDOWN_MS) {
    return;
  }

  if (pidCache.size > 500) pidCache.clear();
  const cached = pidCache.get(pid);
  if (cached && now - cached.at < PID_CACHE_TTL_MS) {
    if (cached.kind === "allowed") {
      resetTargets(
        folder,
        service,
        [cached.id],
        procName,
        pid,
        `${cached.id}(${cached.respPid})`,
        deniedPath,
      );
    } else {
      logSkip(folder, procName, pid, cached.reason, deniedPath);
    }
    return;
  }

  if (!isPidAlive(pid)) {
    resetTargets(
      folder,
      service,
      ALLOWED_BUNDLE_IDS,
      procName,
      pid,
      "gone",
      deniedPath,
    );
    return;
  }

  const res = resolveResponsible(pid);
  if (res.kind === "bundle") {
    if (ALLOWED_BUNDLE_IDS.has(res.id)) {
      pidCache.set(pid, {
        kind: "allowed",
        id: res.id,
        respPid: res.respPid,
        at: Date.now(),
      });
      resetTargets(
        folder,
        service,
        [res.id],
        procName,
        pid,
        `${res.id}(${res.respPid})`,
        deniedPath,
      );
    } else {
      const reason = `unlisted-bundle(${res.id}:${res.respPid})`;
      pidCache.set(pid, { kind: "skipped", reason, at: Date.now() });
      logSkip(folder, procName, pid, reason, deniedPath);
    }
    return;
  }
  if (res.kind === "gone") {
    resetTargets(
      folder,
      service,
      ALLOWED_BUNDLE_IDS,
      procName,
      pid,
      "gone",
      deniedPath,
    );
    return;
  }
  const reason = `non-bundle(${res.detail})`;
  pidCache.set(pid, { kind: "skipped", reason, at: Date.now() });
  logSkip(folder, procName, pid, reason, deniedPath);
});
EOF
