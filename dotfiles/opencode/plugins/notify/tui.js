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

export default Plugin.define({
  id: "notify",
  setup(context) {
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

    async function notifyIdle(sessionID, eventLocation) {
      const session = await resolveSession(sessionID);
      if (!isLocalSession(sessionID, session) || session?.parentID) return;

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
        void logKind(
          event.data.sessionID,
          "session.execution.started",
          "working",
        );
      }),
      // an aborted or failed turn ends like a finished one, without an alert
      context.data.on("session.execution.interrupted", (event) => {
        void logKind(
          event.data.sessionID,
          "session.execution.interrupted",
          "waiting",
        );
      }),
      context.data.on("session.execution.failed", (event) => {
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
        void notifyIdle(event.data.sessionID, event.location);
      }),
      context.data.on("permission.asked", (event) => {
        void notifyPermission(event);
      }),
      context.data.on("form.created", (event) => {
        void notifyForm(event);
      }),
    ];

    return () => dispose.reverse().forEach((cleanup) => cleanup());
  },
});
