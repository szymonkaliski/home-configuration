import os from "os";
import path from "path";
import { createRequire } from "module";

// loaded by absolute path: this plugin is a symlink into the dotfiles repo on a
// host and a plain copy inside a microVM, so a relative specifier would resolve
// to two different places
const { truncate, createLogger, isFocusedPane, deliver } = createRequire(
  import.meta.url,
)(`${os.homedir()}/.config/opencode/notify-lib.cjs`);

const logLine = createLogger(`${os.homedir()}/.config/opencode/notify.log`);

export const NotifyPlugin = async ({ client }) => {
  // opencode delivers all events through a single `event` hook keyed by
  // event.type (named hooks like "session.idle" are never dispatched)
  async function notifyIdle(sessionID) {
    const event = "session.idle";
    logLine({ phase: "fire", event });

    if (isFocusedPane()) {
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

    await deliver({
      title: `OpenCode (${os.hostname()} - ${path.basename(process.cwd())})`,
      body,
      log: (data) => logLine({ event, ...data }),
    });
  }

  async function notifyPermission(perm) {
    const event = "permission.asked";
    logLine({ phase: "fire", event, perm });

    if (isFocusedPane()) {
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

    await deliver({
      title: `OpenCode (${os.hostname()} - ${path.basename(process.cwd())})`,
      body,
      log: (data) => logLine({ event, ...data }),
    });
  }

  return {
    event: async ({ event }) => {
      if (event?.type === "session.idle") {
        await notifyIdle(event.properties?.sessionID);
      } else if (event?.type === "permission.asked") {
        await notifyPermission(event.properties);
      }
    },
  };
};
