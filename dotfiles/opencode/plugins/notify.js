import os from "os";
import path from "path";
import { createRequire } from "module";

// loaded by absolute path: this plugin is a symlink into the dotfiles repo on a
// host and a plain copy inside a microVM, so a relative specifier would resolve
// to two different places
const { truncate, createLogger, isFocusedPane, deliver } = createRequire(
  import.meta.url,
)(`${os.homedir()}/.config/opencode/notify-lib.cjs`);

const LOG_PATH = `${os.homedir()}/.config/opencode/notify.log`;

export const NotifyPlugin = async ({ client, directory }) => {
  const title = `OpenCode (${os.hostname()} - ${path.basename(directory || process.cwd())})`;

  // opencode delivers all events through a single `event` hook keyed by
  // event.type (named hooks like "session.idle" are never dispatched)
  async function notifyIdle(sessionID) {
    const log = createLogger(LOG_PATH, {
      event: "session.idle",
      session: sessionID,
    });
    log({ phase: "fire" });

    if (isFocusedPane()) {
      log({ phase: "suppressed", reason: "focused-pane" });
      return;
    }

    let body = "OpenCode is waiting for your input";
    try {
      const sessionResult = await client.session.get({
        path: { id: sessionID },
      });
      if (sessionResult?.data?.parentID) {
        log({ phase: "suppressed", reason: "subagent-session" });
        return;
      }

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
      log({
        phase: "fetch-context-failed",
        error: String((err && err.message) || err),
      });
    }

    await deliver({ title, body, log });
  }

  async function notifyPermission(perm) {
    const log = createLogger(LOG_PATH, {
      event: "permission.asked",
      session: perm?.sessionID,
    });
    log({ phase: "fire", perm });

    if (isFocusedPane()) {
      log({ phase: "suppressed", reason: "focused-pane" });
      return;
    }

    const tool = perm?.permission || perm?.action || "tool";
    const meta = perm?.metadata || {};
    const detail =
      meta.command ||
      meta.description ||
      meta.filePath ||
      meta.path ||
      perm?.patterns?.[0] ||
      perm?.resources?.[0] ||
      "";
    const body = detail
      ? `${tool}: ${truncate(String(detail), 140)}`
      : `${tool} permission request`;

    await deliver({ title, body, log });
  }

  async function notifyQuestion(props) {
    const log = createLogger(LOG_PATH, {
      event: "question.asked",
      session: props?.sessionID,
    });
    log({ phase: "fire" });

    if (isFocusedPane()) {
      log({ phase: "suppressed", reason: "focused-pane" });
      return;
    }

    const q = props?.questions?.[0]?.question;
    const body = q ? `Question: ${truncate(String(q), 140)}` : "Question";

    await deliver({ title, body, log });
  }

  return {
    event: async ({ event }) => {
      if (event?.type === "session.idle") {
        await notifyIdle(event.properties?.sessionID);
      } else if (
        event?.type === "permission.asked" ||
        event?.type === "permission.v2.asked"
      ) {
        await notifyPermission(event.properties);
      } else if (
        event?.type === "question.asked" ||
        event?.type === "question.v2.asked"
      ) {
        await notifyQuestion(event.properties);
      }
    },
  };
};
