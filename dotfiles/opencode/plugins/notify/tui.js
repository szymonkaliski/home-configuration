import fs from "fs";
import os from "os";
import path from "path";
import { createRequire } from "module";
import { Plugin } from "@opencode/plugin/tui";

// loaded by absolute path: this plugin is a symlink into the dotfiles repo on a
// host and a plain copy inside a microVM, so a relative specifier would resolve
// to two different places; evaluated directly because OpenTUI's Bun.plugin
// registers an async onLoad for *.[cm]js that breaks CJS require() and exports
function loadCjs(filePath) {
  const mod = { exports: {} };
  const fn = new Function(
    "exports",
    "require",
    "module",
    "__filename",
    "__dirname",
    fs.readFileSync(filePath, "utf8"),
  );
  fn(
    mod.exports,
    createRequire(filePath),
    mod,
    filePath,
    path.dirname(filePath),
  );
  return mod.exports;
}

const { truncate, createLogger, isFocusedPane, deliver } = loadCjs(
  `${os.homedir()}/.config/opencode/notify-lib.cjs`,
);

const LOG_PATH = `${os.homedir()}/.config/opencode/notify.log`;

// A background subagent's report reaches its parent as a synthetic input, and
// that input starts a new parent execution as soon as the subagent's execution
// ends (opencode's SubagentCompletion.deliver). A parent still idle this long
// after its last subagent ended was not resumed.
const RESUME_GRACE_MS = 5000;

export default Plugin.define({
  id: "notify",
  setup(context) {
    // every session with an execution in flight (a root or a subagent) and its
    // session info lookup, kept in event order
    const running = new Map();
    // roots whose turn ended while subagents still ran: their idle path waits
    // for the last subagent, with the succeeded event's location
    const deferred = new Map();
    let settleTimer;

    const location = () => context.location ?? context.data.location.default();
    const titleFor = (dir) =>
      `OpenCode (${os.hostname()} - ${path.basename(dir || location()?.directory || process.cwd())})`;

    async function resolveSession(sessionID) {
      if (!sessionID) return undefined;
      return (
        context.data.session.get(sessionID) ??
        (await context.client.session.get({ sessionID }).catch(() => undefined))
      );
    }

    function isLocalSession(sessionID, session) {
      if (!sessionID) return false;
      const parentID = session?.parentID;
      const rootID = parentID
        ? context.data.session.root(parentID)
        : context.data.session.root(sessionID);
      const route = context.ui.router.current();
      const routeSessionID =
        route?.type === "session"
          ? route.sessionID
          : route?.type === "plugin"
            ? route.data?.sessionID
            : undefined;
      if (
        routeSessionID &&
        (routeSessionID === sessionID || routeSessionID === rootID)
      ) {
        return true;
      }
      if (context.ui.tabs.enabled()) {
        return context.ui.tabs
          .list()
          .some(
            (t) =>
              t.sessionID === sessionID ||
              (rootID ? t.sessionID === rootID : false),
          );
      }
      return false;
    }

    // one line, no delivery: the state transitions the log carries for readers.
    // A subagent shares its parent's pane, so its turn lifecycle says nothing
    // about the pane, while its prompt does block and unblock the pane.
    async function logKind(sessionID, event, kind) {
      const session = await resolveSession(sessionID);
      if (!isLocalSession(sessionID, session)) return;
      if (event.startsWith("session.") && session?.parentID) return;
      createLogger(LOG_PATH, {
        harness: "opencode",
        event,
        kind,
        session: sessionID,
      })({ phase: "fire" });
    }

    // the subagents of rootID with an execution in flight, at any depth
    async function runningChildren(rootID) {
      const entries = [...running].filter(([id]) => id !== rootID);
      const sessions = await Promise.all(entries.map(([, session]) => session));
      return sessions.filter(
        (session, i) =>
          running.has(entries[i][0]) &&
          session?.parentID &&
          context.data.session.root(session.parentID) === rootID,
      );
    }

    function settleLater() {
      clearTimeout(settleTimer);
      settleTimer = setTimeout(() => void settle(), RESUME_GRACE_MS);
    }

    // a deferred root that started a new execution logs its own lines; one
    // whose subagents all ended without resuming it goes idle
    async function settle() {
      for (const [rootID, entry] of [...deferred]) {
        if (running.has(rootID)) continue;
        if ((await runningChildren(rootID)).length > 0) continue;
        if (deferred.get(rootID) !== entry || running.has(rootID)) continue;
        deferred.delete(rootID);
        const session = await resolveSession(rootID);
        if (running.has(rootID) || !isLocalSession(rootID, session)) continue;
        await deliverIdle(rootID, session, entry.location);
      }
    }

    function executionStarted(sessionID) {
      running.set(
        sessionID,
        resolveSession(sessionID).catch(() => undefined),
      );
      deferred.delete(sessionID);
    }

    function executionEnded(sessionID) {
      running.delete(sessionID);
      deferred.delete(sessionID);
      if (deferred.size > 0) settleLater();
    }

    async function notifyIdle(sessionID, eventLocation) {
      const session = await resolveSession(sessionID);
      if (!isLocalSession(sessionID, session) || session?.parentID) return;

      // the session still works while its subagents run: the turn that takes
      // up their reports decides, so nothing is delivered
      const children = await runningChildren(sessionID);
      if (running.has(sessionID)) return;
      if (children.length > 0) {
        deferred.set(sessionID, { location: eventLocation });
        createLogger(LOG_PATH, {
          harness: "opencode",
          event: "session.execution.succeeded",
          kind: "working",
          session: sessionID,
        })({
          phase: "fire",
          background: children.map((child) => child.agent ?? "subagent"),
        });
        settleLater();
        return;
      }

      await deliverIdle(sessionID, session, eventLocation);
    }

    async function deliverIdle(sessionID, session, eventLocation) {
      const log = createLogger(LOG_PATH, {
        harness: "opencode",
        event: "session.execution.succeeded",
        kind: "waiting",
        session: sessionID,
      });
      log({ phase: "fire" });

      if (isFocusedPane()) {
        log({ phase: "suppressed", reason: "focused-pane" });
        return;
      }

      let body = "OpenCode is waiting for your input";
      const sessionDir =
        eventLocation?.directory ?? session?.location?.directory;
      try {
        const messages =
          (await context.client.session.context({ sessionID })) ??
          context.data.session.message.list(sessionID) ??
          [];
        for (let i = messages.length - 1; i >= 0; i--) {
          const msg = messages[i];
          if (msg.type === "assistant" && Array.isArray(msg.content)) {
            const textParts = msg.content.filter(
              (p) => p.type === "text" && p.text?.trim(),
            );
            if (textParts.length > 0) {
              body = truncate(textParts[textParts.length - 1].text.trim(), 200);
            }
            break;
          }
        }
      } catch (err) {
        log({
          phase: "fetch-context-failed",
          error: String((err && err.message) || err),
        });
      }

      await deliver({ title: titleFor(sessionDir), body, log });
    }

    async function notifyPermission(event) {
      const perm = event.data;
      const session = await resolveSession(perm?.sessionID);
      if (!isLocalSession(perm?.sessionID, session)) return;

      const log = createLogger(LOG_PATH, {
        harness: "opencode",
        event: "permission.asked",
        kind: "permission",
        session: perm?.sessionID,
      });
      log({ phase: "fire", perm });

      if (isFocusedPane()) {
        log({ phase: "suppressed", reason: "focused-pane" });
        return;
      }

      const tool = perm?.action || "tool";
      const meta = perm?.metadata || {};
      const detail =
        meta.command ||
        meta.description ||
        meta.filePath ||
        meta.path ||
        perm?.resources?.[0] ||
        perm?.message ||
        "";
      const body = detail
        ? `${tool}: ${truncate(String(detail), 140)}`
        : `${tool} permission request`;

      const sessionDir =
        event.location?.directory ?? session?.location?.directory;
      await deliver({ title: titleFor(sessionDir), body, log });
    }

    async function notifyForm(event) {
      const form = event.data?.form;
      const session = await resolveSession(form?.sessionID);
      if (!isLocalSession(form?.sessionID, session)) return;

      const log = createLogger(LOG_PATH, {
        harness: "opencode",
        event: "form.created",
        kind: "permission",
        session: form?.sessionID,
      });
      log({ phase: "fire" });

      if (isFocusedPane()) {
        log({ phase: "suppressed", reason: "focused-pane" });
        return;
      }

      const field = form?.fields?.[0];
      const q = field?.description || field?.title || form?.title;
      const body = q ? `Question: ${truncate(String(q), 140)}` : "Question";

      const sessionDir =
        event.location?.directory ?? session?.location?.directory;
      await deliver({ title: titleFor(sessionDir), body, log });
    }

    const dispose = [
      context.data.on("session.execution.started", (event) => {
        executionStarted(event.data.sessionID);
        void logKind(
          event.data.sessionID,
          "session.execution.started",
          "working",
        );
      }),
      // an aborted or failed turn ends like a finished one, without an alert
      context.data.on("session.execution.interrupted", (event) => {
        executionEnded(event.data.sessionID);
        void logKind(
          event.data.sessionID,
          "session.execution.interrupted",
          "waiting",
        );
      }),
      context.data.on("session.execution.failed", (event) => {
        executionEnded(event.data.sessionID);
        void logKind(
          event.data.sessionID,
          "session.execution.failed",
          "waiting",
        );
      }),
      // an answered prompt puts the agent back to work
      context.data.on("permission.replied", (event) => {
        void logKind(event.data.sessionID, "permission.replied", "working");
      }),
      context.data.on("form.replied", (event) => {
        void logKind(
          event.data.form?.sessionID ?? event.data.sessionID,
          "form.replied",
          "working",
        );
      }),
      context.data.on("form.cancelled", (event) => {
        void logKind(
          event.data.form?.sessionID ?? event.data.sessionID,
          "form.cancelled",
          "working",
        );
      }),
      context.data.on("session.execution.succeeded", (event) => {
        executionEnded(event.data.sessionID);
        void notifyIdle(event.data.sessionID, event.location);
      }),
      context.data.on("permission.asked", (event) => {
        void notifyPermission(event);
      }),
      context.data.on("form.created", (event) => {
        void notifyForm(event);
      }),
    ];

    return () => {
      clearTimeout(settleTimer);
      dispose.reverse().forEach((cleanup) => cleanup());
    };
  },
});
