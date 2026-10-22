import { execFile } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import { Plugin } from "@opencode/plugin/tui";
import {
  createEffect,
  createMemo,
  createSignal,
  onCleanup,
  Show,
} from "solid-js";

const HOST = os.hostname().split(".")[0];
const VM_PREFIX = HOST.startsWith("vm-") ? `${HOST} ` : "";
const BRAILLE_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const BASE16_SYMLINK = path.join(os.homedir(), ".base16_theme");
const HEAVY_BORDER_CHARS = {
  topLeft: "",
  bottomLeft: "",
  vertical: "▌",
  topRight: "",
  bottomRight: "",
  horizontal: " ",
  bottomT: "",
  topT: "",
  cross: "",
  leftT: "",
  rightT: "",
};
globalThis.THIN_BORDER_CHARS = HEAVY_BORDER_CHARS;

function readBase16Target() {
  try {
    return fs.realpathSync(BASE16_SYMLINK);
  } catch {
    return "";
  }
}

function themeBlue(theme) {
  return theme.syntax?.function ?? theme.markdown?.listItem ?? theme.text.base;
}

function themeMagenta(theme) {
  return (
    theme.syntax?.keyword ??
    theme.text.action?.primary?.selected ??
    theme.text.base
  );
}

function themeCyan(theme) {
  return theme.syntax?.operator ?? theme.text.feedback.info.base;
}

function themeYellow(theme) {
  return theme.text.feedback.warning.base;
}

function themeGreen(theme) {
  return theme.diff?.text?.added ?? theme.text.feedback.success.base;
}

function themeRed(theme) {
  return theme.diff?.text?.removed ?? theme.text.feedback.error.base;
}

function hostColor(theme) {
  switch (HOST) {
    case "orchid":
      return themeBlue(theme);
    case "minix":
      return themeYellow(theme);
    case "berry":
      return themeCyan(theme);
    default:
      return themeMagenta(theme);
  }
}

function agentThemeColor(agentName, theme) {
  const lower = (agentName || "build").toLowerCase();
  if (lower === "plan") {
    return themeMagenta(theme);
  }
  if (lower === "shell") {
    return themeRed(theme);
  }
  return themeBlue(theme);
}

function parseBase16File(filePath) {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const vars = {};
    for (const line of raw.split("\n")) {
      const m = line.match(
        /^(color\w+)=["']?(\$color\w+|[0-9a-fA-F/]{6,8})["']?/,
      );
      if (!m) continue;
      const [, key, val] = m;
      if (val.startsWith("$")) {
        vars[key] = vars[val.slice(1)];
      } else {
        vars[key] = `#${val.replace(/\//g, "").toLowerCase()}`;
      }
    }
    if (!vars.color00 || !vars.color07) return null;
    return {
      base00: vars.color00,
      base01: vars.color18 || vars.color00,
      base02: vars.color19 || vars.color08,
      base03: vars.color08,
      base04: vars.color20 || vars.color07,
      base05: vars.color07,
      base06: vars.color21 || vars.color15,
      base07: vars.color15,
      base08: vars.color01,
      base09: vars.color16 || vars.color03,
      base0A: vars.color03,
      base0B: vars.color02,
      base0C: vars.color06,
      base0D: vars.color04,
      base0E: vars.color05,
      base0F: vars.color17 || vars.color01,
    };
  } catch {
    return null;
  }
}

function paletteToBase16(p) {
  const pal = p?.palette;
  if (!Array.isArray(pal) || !pal[0] || !pal[7]) return null;
  const norm = (c) => (typeof c === "string" ? c.toLowerCase() : null);
  const c00 = norm(p.defaultBackground) || norm(pal[0]);
  const c05 = norm(p.defaultForeground) || norm(pal[7]);
  if (!c00 || !c05) return null;
  return {
    base00: c00,
    base01: norm(pal[18]) || c00,
    base02: norm(pal[19]) || norm(pal[8]) || c00,
    base03: norm(pal[8]) || c05,
    base04: norm(pal[20]) || c05,
    base05: c05,
    base06: norm(pal[21]) || norm(pal[15]) || c05,
    base07: norm(pal[15]) || c05,
    base08: norm(pal[1]) || c05,
    base09: norm(pal[16]) || norm(pal[3]) || c05,
    base0A: norm(pal[3]) || c05,
    base0B: norm(pal[2]) || c05,
    base0C: norm(pal[6]) || c05,
    base0D: norm(pal[4]) || c05,
    base0E: norm(pal[5]) || c05,
    base0F: norm(pal[17]) || norm(pal[1]) || c05,
  };
}

function overwriteRgbaHex(target, hex) {
  if (!target?.buffer || !hex) return;
  const Ctor = target.constructor;
  if (typeof Ctor?.fromHex !== "function") return;
  try {
    const src = Ctor.fromHex(hex);
    if (src?.buffer) {
      target.buffer[0] = src.buffer[0];
      target.buffer[1] = src.buffer[1];
      target.buffer[2] = src.buffer[2];
    }
  } catch {}
}

function applyBase16Surface(theme, b16) {
  if (!theme || !b16) return;
  const RawCtor =
    theme.text?.base?.constructor?._rawCtor ?? theme.text?.base?.constructor;
  const fromHex =
    typeof RawCtor?.fromHex === "function"
      ? RawCtor.fromHex.bind(RawCtor)
      : null;
  const clone =
    typeof RawCtor?.clone === "function" ? RawCtor.clone.bind(RawCtor) : null;

  overwriteRgbaHex(theme.background?.base, b16.base00);
  overwriteRgbaHex(theme.background?.raised?.base, b16.base01);
  overwriteRgbaHex(theme.background?.raised?.high, b16.base01);
  overwriteRgbaHex(theme.background?.raised?.max, b16.base02);
  if (theme.hue?.gray) {
    overwriteRgbaHex(theme.hue.gray[900], b16.base00);
    overwriteRgbaHex(theme.hue.gray[800], b16.base00);
    overwriteRgbaHex(theme.hue.gray[700], b16.base01);
    overwriteRgbaHex(theme.hue.gray[600], b16.base01);
    overwriteRgbaHex(theme.hue.gray[500], b16.base02);
    overwriteRgbaHex(theme.hue.gray[400], b16.base04);
    overwriteRgbaHex(theme.hue.gray[300], b16.base04);
    overwriteRgbaHex(theme.hue.gray[200], b16.base05);
    overwriteRgbaHex(theme.hue.gray[100], b16.base07);
  }
  const hueMap = {
    red: b16.base08,
    orange: b16.base09,
    yellow: b16.base0A,
    green: b16.base0B,
    cyan: b16.base0C,
    blue: b16.base0D,
    purple: b16.base0E,
    accent: b16.base0D,
    interactive: b16.base0D,
  };
  if (theme.hue) {
    for (const [hueName, hex] of Object.entries(hueMap)) {
      const scale = theme.hue[hueName];
      if (!scale || typeof scale !== "object") continue;
      for (const step of [100, 200, 300, 400, 500, 600, 700, 800, 900]) {
        overwriteRgbaHex(scale[step], hex);
      }
    }
  }
  overwriteRgbaHex(theme.text?.base, b16.base05);
  overwriteRgbaHex(theme.text?.muted, b16.base04);
  overwriteRgbaHex(theme.border?.base, b16.base03);
  overwriteRgbaHex(theme.scrollbar?.base, b16.base03);
  overwriteRgbaHex(theme.text?.feedback?.error?.base, b16.base08);
  overwriteRgbaHex(theme.text?.feedback?.warning?.base, b16.base0A);
  overwriteRgbaHex(theme.text?.feedback?.success?.base, b16.base0B);
  overwriteRgbaHex(theme.text?.feedback?.info?.base, b16.base0C);
  overwriteRgbaHex(theme.syntax?.keyword, b16.base0E);
  overwriteRgbaHex(theme.syntax?.function, b16.base0D);
  overwriteRgbaHex(theme.syntax?.string, b16.base0B);
  overwriteRgbaHex(theme.syntax?.operator, b16.base0C);
  overwriteRgbaHex(theme.diff?.text?.added, b16.base0B);
  overwriteRgbaHex(theme.diff?.text?.removed, b16.base08);
  overwriteRgbaHex(theme.diff?.background?.added, b16.base01);
  overwriteRgbaHex(theme.diff?.background?.removed, b16.base01);
  overwriteRgbaHex(theme.diff?.background?.context, b16.base01);
  overwriteRgbaHex(theme.diff?.lineNumber?.background?.added, b16.base01);
  overwriteRgbaHex(theme.diff?.lineNumber?.background?.removed, b16.base01);
  overwriteRgbaHex(theme.diff?.highlight?.added, b16.base0B);
  overwriteRgbaHex(theme.diff?.highlight?.removed, b16.base08);
  if (fromHex) {
    if (theme.syntax) {
      theme.syntax.comment = fromHex(b16.base03);
      theme.syntax.variable = fromHex(b16.base08);
      theme.syntax.number = fromHex(b16.base09);
      theme.syntax.type = fromHex(b16.base0A);
      theme.syntax.punctuation = fromHex(b16.base05);
    }
    if (theme.diff?.text) {
      theme.diff.text.context = fromHex(b16.base04);
      theme.diff.text.hunkHeader = fromHex(b16.base0D);
    }
    if (theme.diff?.lineNumber) {
      theme.diff.lineNumber.text = fromHex(b16.base03);
    }
    if (theme.markdown) {
      theme.markdown.text = fromHex(b16.base05);
      theme.markdown.heading = fromHex(b16.base0D);
      theme.markdown.link = fromHex(b16.base0D);
      theme.markdown.linkText = fromHex(b16.base0C);
      theme.markdown.code = fromHex(b16.base0D);
      theme.markdown.blockQuote = fromHex(b16.base0A);
      theme.markdown.emphasis = fromHex(b16.base0E);
      theme.markdown.strong = fromHex(b16.base0A);
      theme.markdown.horizontalRule = fromHex(b16.base03);
      theme.markdown.listItem = fromHex(b16.base0D);
      theme.markdown.listEnumeration = fromHex(b16.base0C);
      theme.markdown.image = fromHex(b16.base0D);
      theme.markdown.imageText = fromHex(b16.base0C);
      theme.markdown.codeBlock = fromHex(b16.base05);
    }
    if (clone) {
      const safeCtor = { _rawCtor: RawCtor, fromHex, clone };
      for (const col of [
        theme.syntax?.function,
        theme.syntax?.keyword,
        theme.syntax?.operator,
        theme.diff?.text?.removed,
        theme.text?.feedback?.error?.base,
      ]) {
        if (col && col.constructor !== safeCtor) {
          try {
            Object.defineProperty(col, "constructor", {
              value: safeCtor,
              configurable: true,
            });
          } catch {}
        }
      }
    }
  }
}

function applyBase16ToTheme(theme, b16) {
  if (!theme || !b16) return;
  applyBase16Surface(theme, b16);
  const dialogSurface = theme.surface?.("dialog");
  if (dialogSurface && dialogSurface !== theme) {
    applyBase16Surface(dialogSurface, b16);
  }
}

function formatShortPwd(dir) {
  const home = os.homedir();
  const tilde = dir.startsWith(home) ? `~${dir.slice(home.length)}` : dir;
  const parts = tilde.split("/").filter(Boolean);
  let display;
  if (parts.length <= 3) {
    display = tilde.startsWith("/") ? `/${parts.join("/")}` : parts.join("/");
  } else {
    display = parts.slice(-3).join("/");
  }
  if (display.length > 50) {
    display = `...${display.slice(-47)}`;
  }
  return display || tilde;
}

function truncateLeft(str, maxLen) {
  if (maxLen <= 0) return "";
  if (str.length <= maxLen) return str;
  if (maxLen <= 3) return str.slice(0, maxLen);
  return `...${str.slice(-(maxLen - 3))}`;
}

function isBoxNode(node) {
  const proto = node?.constructor?.prototype;
  return Boolean(proto && Object.hasOwn(proto, "initializeBorder"));
}

function readTextRenderable(node) {
  if (!node) return "";
  if (typeof node === "string") return node;
  const raw = node.rootTextNode?._children ?? node._children;
  if (Array.isArray(raw)) {
    return raw.map((c) => readTextRenderable(c)).join("");
  }
  const chunks = node.content?.chunks;
  if (Array.isArray(chunks)) {
    return chunks.map((c) => c.text ?? "").join("");
  }
  return "";
}

function parseGitPorcelain(stdout, dir) {
  let head = "";
  let oid = "";
  let staged = 0;
  let modified = 0;
  let untracked = 0;
  let conflicts = 0;
  const untrackedFiles = [];

  for (const line of stdout.split("\n")) {
    if (!line) continue;
    if (line.startsWith("# branch.head ")) {
      head = line.slice(14).trim();
    } else if (line.startsWith("# branch.oid ")) {
      oid = line.slice(13).trim();
    } else if (line.startsWith("1 ") || line.startsWith("2 ")) {
      const xy = line.slice(2, 4);
      if (xy[0] && xy[0] !== ".") staged++;
      if (xy[1] && xy[1] !== ".") modified++;
    } else if (line.startsWith("u ")) {
      conflicts++;
    } else if (line.startsWith("? ")) {
      untracked++;
      untrackedFiles.push(line.slice(2).trim());
    }
  }

  let branch =
    head && head !== "(detached)"
      ? head
      : oid && oid !== "(initial)"
        ? oid.slice(0, 7)
        : head || "";

  if (branch.length > 20) {
    branch = `...${branch.slice(-17)}`;
  }

  let untrackedLines = 0;
  for (const rel of untrackedFiles.slice(0, 15)) {
    try {
      const full = path.join(dir, rel);
      const st = fs.lstatSync(full);
      if (st.isFile() && st.size > 0 && st.size <= 131072) {
        const buf = fs.readFileSync(full);
        if (!buf.includes(0)) {
          let lines = 0;
          for (let i = 0; i < buf.length; i++) {
            if (buf[i] === 10) lines++;
          }
          if (buf[buf.length - 1] !== 10) lines++;
          untrackedLines += lines;
        }
      }
    } catch {}
  }

  const dirty = staged > 0 || modified > 0 || untracked > 0 || conflicts > 0;

  return {
    branch,
    dirty,
    untrackedLines,
  };
}

function parseNumstat(stdout) {
  let additions = 0;
  let deletions = 0;
  for (const line of stdout.split("\n")) {
    if (!line) continue;
    const parts = line.split("\t");
    if (parts.length < 2) continue;
    const add = Number.parseInt(parts[0], 10);
    const del = Number.parseInt(parts[1], 10);
    if (Number.isFinite(add)) additions += add;
    if (Number.isFinite(del)) deletions += del;
  }
  return { additions, deletions };
}

function findLastAssistantWithTokens(messages, revertMessageID) {
  if (!Array.isArray(messages) || messages.length === 0) return undefined;
  const revertIdx = revertMessageID
    ? messages.findIndex((m) => m.id === revertMessageID)
    : -1;
  if (revertMessageID && revertIdx === -1) return undefined;
  const end = revertIdx === -1 ? messages.length : revertIdx;
  const compactionIdx = messages.findLastIndex(
    (m, idx) =>
      m.type === "compaction" && m.status === "completed" && idx < end,
  );
  return messages.findLast(
    (m, idx) =>
      m.type === "assistant" &&
      m.tokens !== undefined &&
      idx > compactionIdx &&
      idx < end,
  );
}

function getContextUsage(messages, models, revertMessageID) {
  const last = findLastAssistantWithTokens(messages, revertMessageID);
  if (!last?.tokens) return undefined;
  const total =
    (last.tokens.input || 0) +
    (last.tokens.output || 0) +
    (last.tokens.reasoning || 0) +
    (last.tokens.cache?.read || 0) +
    (last.tokens.cache?.write || 0);
  if (total <= 0) return undefined;
  const model = models?.find(
    (m) => m.providerID === last.model?.providerID && m.id === last.model?.id,
  );
  const percent = model?.limit?.context
    ? Math.round((total / model.limit.context) * 100)
    : undefined;
  return { tokens: total, percent };
}

export default Plugin.define({
  id: "theme",
  setup(context) {
    const [gitByDir, setGitByDir] = createSignal({});
    const [liveAgentName, setLiveAgentName] = createSignal("");
    const [spinnerIdx, setSpinnerIdx] = createSignal(0);
    const [themeVer, setThemeVer] = createSignal(0);
    const [termWidth, setTermWidth] = createSignal(
      context.renderer?.width || context.renderer?.root?.width || 80,
    );
    const inFlight = new Set();
    const trackedDirs = new Set();
    const patchedProps = [];
    const patchedNodes = new WeakMap();
    const lifecycleNodes = new Set();
    let lastBase16Target = readBase16Target();
    let cachedBase16 = parseBase16File(BASE16_SYMLINK);
    if (!cachedBase16) {
      context.renderer
        ?.getPalette?.({ size: 22 })
        ?.then((p) => {
          const parsed = paletteToBase16(p);
          if (parsed) {
            cachedBase16 = parsed;
            setThemeVer((v) => v + 1);
            scheduleApplyLayout();
          }
        })
        ?.catch?.(() => {});
    }
    let leftBoxRef;
    let rightBoxRef;

    function syncWidth(footerBox = leftBoxRef) {
      const footerRow = footerBox?.parent;
      const promptRoot = footerRow?.parent;
      const rootW =
        context.renderer?.width ||
        context.renderer?.root?.width ||
        context.renderer?.root?.getNativeSceneLayout?.()?.width ||
        80;
      const promptW =
        promptRoot?.getNativeSceneLayout?.()?.width ||
        footerRow?.getNativeSceneLayout?.()?.width ||
        0;
      const isHome = context.ui.router?.current?.()?.type === "home";
      const maxW = isHome ? Math.min(75, rootW) : rootW;
      const w = promptW > 0 ? Math.min(promptW, maxW) : maxW;
      if (w > 0 && w !== termWidth()) {
        setTermWidth(w);
      }
    }

    const onRendererResize = (w) => {
      const nextW =
        typeof w === "number"
          ? w
          : typeof w?.width === "number"
            ? w.width
            : context.renderer?.width;
      if (typeof nextW === "number" && nextW > 0) {
        const isHome = context.ui.router?.current?.()?.type === "home";
        setTermWidth(isHome ? Math.min(75, nextW) : nextW);
        applyLayout(leftBoxRef, true);
      } else {
        applyLayout(leftBoxRef);
      }
      context.renderer?.requestRender?.();
    };

    context.renderer?.on?.("resize", onRendererResize);
    context.renderer?.root?.on?.("resized", onRendererResize);

    const spinTimer = setInterval(() => {
      setSpinnerIdx((i) => (i + 1) % BRAILLE_FRAMES.length);
      applyLayout(leftBoxRef);
    }, 80);
    if (typeof spinTimer.unref === "function") spinTimer.unref();

    function lockStyle(node, props, value = 0) {
      if (!node || node.isDestroyed) return;
      let record = patchedNodes.get(node);
      if (!record) {
        record = new Map();
        patchedNodes.set(node, record);
      }
      for (const prop of props) {
        const prev = record.get(prop);
        const same =
          prev && value && typeof prev.equals === "function"
            ? prev.equals(value)
            : prev === value;
        if (same) continue;
        try {
          delete node[prop];
          node[prop] = value;
          Object.defineProperty(node, prop, {
            get: () => value,
            set: () => {},
            configurable: true,
          });
          const saved =
            value && typeof value.constructor?.clone === "function"
              ? value.constructor.clone(value)
              : value;
          record.set(prop, saved);
          patchedProps.push({ node, prop });
        } catch {}
      }
    }

    function applyLayout(footerBox = leftBoxRef, skipSyncWidth = false) {
      const root = context.renderer?.root;
      if (!root || root.isDestroyed) return;

      if (!skipSyncWidth) {
        syncWidth(footerBox);
      }

      if (cachedBase16) {
        applyBase16ToTheme(context.theme, cachedBase16);
      }

      const buildColor = agentThemeColor("build", context.theme);
      const planColor = agentThemeColor("plan", context.theme);
      const mutedColor = context.theme.text.muted;
      const borderBase = context.theme.border?.base ?? mutedColor;
      const bgBase = context.theme.background?.base;
      const raisedBase = context.theme.background?.raised?.base;
      const raisedHigh = context.theme.background?.raised?.high ?? raisedBase;
      const buildBorderColor = buildColor;
      const planBorderColor = planColor;

      const sessionPane = root.findDescendantById?.("session-pane");
      let composerWrap;
      if (sessionPane) {
        const qBox = sessionPane.getChildren?.()[0];
        const ueBox = qBox?.getChildren?.()[0];
        if (qBox) {
          lockStyle(qBox, ["minWidth"], 0);
          lockStyle(qBox, ["width"], "100%");
        }
        if (ueBox) {
          lockStyle(ueBox, ["minWidth"], 0);
          lockStyle(ueBox, ["width"], "100%");
          lockStyle(
            ueBox,
            ["paddingLeft", "paddingRight", "paddingTop", "paddingBottom"],
            0,
          );
          const ueChildren = (ueBox.getChildren?.() ?? []).filter(isBoxNode);
          const scrollWrap = ueChildren[0];
          composerWrap = ueChildren[ueChildren.length - 1];
          if (scrollWrap) {
            lockStyle(scrollWrap, ["minWidth"], 0);
            lockStyle(scrollWrap, ["width"], "100%");
          }
          if (composerWrap) {
            lockStyle(composerWrap, ["minWidth"], 0);
            lockStyle(composerWrap, ["width"], "100%");
          }
          const scrollbox = scrollWrap?.getChildren?.()[0];
          const rows = scrollbox?.content?.getChildren?.() ?? [];
          const firstRow = rows[0];
          if (firstRow && !firstRow.isDestroyed) {
            lockStyle(firstRow, ["marginTop"], 0);
          }

          const route = context.ui.router?.current?.();
          const activeSessionID =
            route?.type === "session" ? route.sessionID : undefined;
          const sessionMessages = activeSessionID
            ? (context.data.session.message.list(activeSessionID) ?? [])
            : [];
          const fallbackAgent =
            (liveAgentName() && liveAgentName().toLowerCase() !== "shell"
              ? liveAgentName()
              : undefined) ||
            (activeSessionID
              ? context.data.session.get(activeSessionID)?.agent
              : undefined) ||
            "build";

          const agentByMessageId = new Map();
          let currentTrackAgent = "";
          for (let i = 0; i < sessionMessages.length; i++) {
            const m = sessionMessages[i];
            if (!m) continue;
            if (
              (m.type === "agent-switched" || m.type === "assistant") &&
              m.agent
            ) {
              currentTrackAgent = m.agent;
            }
            if (m.type === "user" && m.id) {
              let turnAgent = "";
              for (let j = i + 1; j < sessionMessages.length; j++) {
                const next = sessionMessages[j];
                if (!next) continue;
                if (next.type === "user") break;
                if (next.type === "assistant" && next.agent) {
                  turnAgent = next.agent;
                  break;
                }
              }
              agentByMessageId.set(
                m.id,
                turnAgent || currentTrackAgent || fallbackAgent,
              );
            }
          }

          function styleTranscriptNode(n, rowAgent) {
            if (!n || n.isDestroyed) return;
            if ((n._backgroundColor?.a ?? 0) > 0 && raisedBase) {
              lockStyle(n, ["backgroundColor"], raisedBase);
            }
            if ("addedBg" in n && raisedBase) {
              lockStyle(
                n,
                [
                  "addedBg",
                  "removedBg",
                  "contextBg",
                  "lineNumberBg",
                  "addedLineNumberBg",
                  "removedLineNumberBg",
                ],
                raisedBase,
              );
              lockStyle(n, ["lineNumberFg"], borderBase);
            }
            if (
              Array.isArray(n.border) &&
              n.border.includes("left") &&
              n.borderColor
            ) {
              const fillAlpha = n.backgroundColor?.a ?? 0;
              if (fillAlpha === 0) {
                lockStyle(n, ["borderColor"], borderBase);
                lockStyle(n, ["customBorderChars"], HEAVY_BORDER_CHARS);
              } else if (bgBase && !n.borderColor.equals?.(bgBase)) {
                const msgColor =
                  (rowAgent || fallbackAgent).toLowerCase() === "plan"
                    ? planBorderColor
                    : buildBorderColor;
                lockStyle(n, ["borderColor", "focusedBorderColor"], msgColor);
                lockStyle(n, ["customBorderChars"], HEAVY_BORDER_CHARS);
              }
            }
            if ("textNode" in n) {
              if (
                cachedBase16 &&
                n.constructor?.prototype?._defaultOptions &&
                n.constructor.prototype._defaultOptions.fg !==
                  cachedBase16.base05
              ) {
                n.constructor.prototype._defaultOptions.fg =
                  cachedBase16.base05;
              }
              const fgInts = n._defaultFg?.toInts?.();
              if (
                fgInts &&
                ((fgInts[0] === 167 &&
                  fgInts[1] === 167 &&
                  fgInts[2] === 167) ||
                  (fgInts[0] === 88 && fgInts[1] === 88 && fgInts[2] === 88))
              ) {
                lockStyle(n, ["fg"], mutedColor);
              } else if (
                fgInts &&
                fgInts[0] === 255 &&
                fgInts[1] === 255 &&
                fgInts[2] === 255
              ) {
                lockStyle(n, ["fg"], context.theme.text.base);
              }
              const fullText = readTextRenderable(n).trim();
              if (
                fullText.startsWith("Thought") ||
                fullText.startsWith("Thinking")
              ) {
                lockStyle(n, ["fg"], mutedColor);
                const parentChildren = n.parent?.getChildren?.() ?? [];
                const iconNode = parentChildren[0];
                if (iconNode && iconNode !== n && "textNode" in iconNode) {
                  lockStyle(iconNode, ["fg"], mutedColor);
                }
              }
              const firstSpan = n.rootTextNode?._children?.[0];
              const label = readTextRenderable(firstSpan).trim().toLowerCase();
              if (label === "build" || label === "plan") {
                const col = label === "plan" ? planColor : buildColor;
                firstSpan.fg = col;
                n.requestRender?.();
              }
            }
            const syn = n.syntaxStyle ?? n._syntaxStyle;
            if (syn && typeof syn.registerStyle === "function") {
              let synRecord = patchedNodes.get(syn);
              if (
                !synRecord ||
                !synRecord.get("blue")?.equals?.(buildColor) ||
                !synRecord.get("muted")?.equals?.(mutedColor)
              ) {
                const savedBlue =
                  typeof buildColor?.constructor?.clone === "function"
                    ? buildColor.constructor.clone(buildColor)
                    : buildColor;
                const savedMuted =
                  typeof mutedColor?.constructor?.clone === "function"
                    ? mutedColor.constructor.clone(mutedColor)
                    : mutedColor;
                synRecord = new Map([
                  ["blue", savedBlue],
                  ["muted", savedMuted],
                ]);
                patchedNodes.set(syn, synRecord);
                queueMicrotask(() => {
                  try {
                    const synComment =
                      context.theme.syntax?.comment ?? borderBase;
                    const synNumber =
                      context.theme.syntax?.number ??
                      themeYellow(context.theme);
                    const synType =
                      context.theme.syntax?.type ?? themeYellow(context.theme);
                    const synVar =
                      context.theme.syntax?.variable ?? themeRed(context.theme);
                    syn.registerStyle("comment", {
                      fg: synComment,
                      italic: true,
                    });
                    syn.registerStyle("comment.documentation", {
                      fg: synComment,
                      italic: true,
                    });
                    syn.registerStyle("number", { fg: synNumber });
                    syn.registerStyle("boolean", { fg: synNumber });
                    syn.registerStyle("constant", { fg: synNumber });
                    syn.registerStyle("float", { fg: synNumber });
                    syn.registerStyle("type", { fg: synType });
                    syn.registerStyle("variable", { fg: synVar });
                    syn.registerStyle("markup.raw", { fg: buildColor });
                    syn.registerStyle("markup.raw.block", { fg: buildColor });
                    syn.registerStyle("markup.raw.inline", {
                      fg: buildColor,
                      bg: bgBase,
                    });
                    syn.registerStyle("diff.plus", {
                      fg: themeGreen(context.theme),
                      bg: raisedBase,
                    });
                    syn.registerStyle("diff.minus", {
                      fg: themeRed(context.theme),
                      bg: raisedBase,
                    });
                    syn.registerStyle("diff.delta", {
                      fg: mutedColor,
                      bg: raisedBase,
                    });
                  } catch {}
                });
              }
              let nodeRecord = patchedNodes.get(n);
              if (
                !nodeRecord ||
                !nodeRecord.get("blue")?.equals?.(buildColor) ||
                !nodeRecord.get("muted")?.equals?.(mutedColor)
              ) {
                const savedBlue =
                  typeof buildColor?.constructor?.clone === "function"
                    ? buildColor.constructor.clone(buildColor)
                    : buildColor;
                const savedMuted =
                  typeof mutedColor?.constructor?.clone === "function"
                    ? mutedColor.constructor.clone(mutedColor)
                    : mutedColor;
                nodeRecord = new Map([
                  ["blue", savedBlue],
                  ["muted", savedMuted],
                ]);
                patchedNodes.set(n, nodeRecord);
                queueMicrotask(() => {
                  try {
                    if (!n.isDestroyed) {
                      n.clearCache?.();
                      n.refreshStyles?.();
                    }
                  } catch {}
                });
              }
            }
            for (const ch of n.getChildren?.() ?? []) {
              styleTranscriptNode(ch, rowAgent);
            }
          }

          for (const row of rows) {
            const rowAgent =
              (row?.id && agentByMessageId.get(row.id)) || fallbackAgent;
            styleTranscriptNode(row, rowAgent);
          }
        }
      }

      const promptRoot =
        footerBox?.parent?.parent ??
        (composerWrap?.getChildren?.() ?? []).find(
          (c) => isBoxNode(c) && c.visible !== false,
        );
      if (promptRoot && !promptRoot.isDestroyed) {
        const promptChildren = (promptRoot.getChildren?.() ?? []).filter(
          isBoxNode,
        );
        const borderBox = promptChildren[0];
        const bottomEdgeBox = promptChildren[1];

        if (borderBox && !borderBox.isDestroyed) {
          lockStyle(borderBox, ["customBorderChars"], HEAVY_BORDER_CHARS);
          const innerPrompt = borderBox.getChildren?.()[0];
          if (innerPrompt && !innerPrompt.isDestroyed) {
            const boxBg = raisedHigh ?? innerPrompt._backgroundColor;
            if (boxBg) {
              lockStyle(innerPrompt, ["backgroundColor"], boxBg);
              lockStyle(borderBox, ["backgroundColor"], boxBg);
            }
            lockStyle(innerPrompt, ["paddingTop", "paddingBottom"], 1);
            const innerBoxes = (innerPrompt.getChildren?.() ?? []).filter(
              isBoxNode,
            );
            const modelRow = innerBoxes[innerBoxes.length - 1];
            if (modelRow && !modelRow.isDestroyed) {
              const ksBox = (modelRow.getChildren?.() ?? []).find(isBoxNode);
              const firstText = (ksBox?.getChildren?.() ?? []).find(
                (c) => "textNode" in c,
              );
              const detectedAgent = readTextRenderable(firstText).trim();
              if (detectedAgent && detectedAgent !== liveAgentName()) {
                setLiveAgentName(detectedAgent);
              }
              const targetColor = agentThemeColor(
                detectedAgent || liveAgentName() || "Build",
                context.theme,
              );
              if (targetColor) {
                lockStyle(
                  borderBox,
                  ["borderColor", "focusedBorderColor"],
                  targetColor,
                );
              }
              if (modelRow.visible !== false) {
                modelRow.visible = false;
              }
            }
          }
        }

        if (
          bottomEdgeBox &&
          bottomEdgeBox !== footerBox?.parent &&
          bottomEdgeBox.visible !== false
        ) {
          bottomEdgeBox.visible = false;
        }
      }

      const appBox = root.getChildren?.()[0];
      const mainRow = appBox?.getChildren?.()[0];
      const mainCol = mainRow
        ?.getChildren?.()
        .find((c) => (c.getChildrenCount?.() ?? 0) > 0);
      const routeContainer = mainCol?.getChildren?.()[0];
      for (const child of routeContainer?.getChildren?.() ?? []) {
        if (child.findDescendantById?.("session-pane")) continue;
        lockStyle(
          child,
          ["paddingLeft", "paddingRight", "paddingTop", "paddingBottom"],
          0,
        );
        for (const grandChild of child.getChildren?.() ?? []) {
          lockStyle(
            grandChild,
            ["paddingLeft", "paddingRight", "paddingTop", "paddingBottom"],
            0,
          );
        }
      }

      const footerRow = footerBox?.parent;
      if (footerRow) {
        for (
          let anc = footerRow;
          anc && anc !== root && !anc.isDestroyed;
          anc = anc.parent
        ) {
          lockStyle(anc, ["minWidth"], 0);
        }
        lockStyle(footerRow, ["width", "maxWidth"], "100%");
        lockStyle(footerRow, ["gap"], 1);
        lockStyle(footerRow, ["marginTop"], 1);
        for (const sib of footerRow.getChildren?.() ?? []) {
          if (
            sib === footerBox ||
            sib === leftBoxRef ||
            sib === rightBoxRef ||
            sib.id === "theme.footer.left" ||
            sib.id === "theme.footer.right"
          ) {
            continue;
          }
          if (sib.visible !== false) {
            sib.visible = false;
          }
        }
        const builtinLoc = root.findDescendantById?.("prompt.footer.location");
        if (builtinLoc && builtinLoc.visible !== false) {
          builtinLoc.visible = false;
        }
      }
    }

    function refreshGit(dir) {
      if (!dir || inFlight.has(dir)) return;
      inFlight.add(dir);
      execFile(
        "git",
        ["--no-optional-locks", "status", "--porcelain=v2", "--branch"],
        { cwd: dir, timeout: 3000 },
        (err, statusOut) => {
          if (err) {
            inFlight.delete(dir);
            setGitByDir((prev) =>
              prev[dir] === null ? prev : { ...prev, [dir]: null },
            );
            return;
          }
          const base = parseGitPorcelain(statusOut, dir);
          if (!base.dirty) {
            inFlight.delete(dir);
            const next = {
              branch: base.branch,
              dirty: false,
              additions: 0,
              deletions: 0,
            };
            setGitByDir((prev) =>
              JSON.stringify(prev[dir]) === JSON.stringify(next)
                ? prev
                : { ...prev, [dir]: next },
            );
            return;
          }
          execFile(
            "git",
            ["--no-optional-locks", "diff", "HEAD", "--numstat"],
            { cwd: dir, timeout: 3000 },
            (_diffErr, diffOut) => {
              inFlight.delete(dir);
              const stats = diffOut
                ? parseNumstat(diffOut)
                : { additions: 0, deletions: 0 };
              const next = {
                branch: base.branch,
                dirty: true,
                additions: stats.additions + base.untrackedLines,
                deletions: stats.deletions,
              };
              setGitByDir((prev) =>
                JSON.stringify(prev[dir]) === JSON.stringify(next)
                  ? prev
                  : { ...prev, [dir]: next },
              );
            },
          );
        },
      );
    }

    function refreshAllDirs() {
      const nextTarget = readBase16Target();
      if (nextTarget && nextTarget !== lastBase16Target) {
        lastBase16Target = nextTarget;
        cachedBase16 = parseBase16File(BASE16_SYMLINK);
        setThemeVer((v) => v + 1);
        try {
          process.emit("SIGUSR2");
        } catch {}
      }
      const def =
        context.location?.directory ??
        context.data.location.default()?.directory;
      if (def) trackedDirs.add(def);
      for (const dir of trackedDirs) {
        refreshGit(dir);
      }
    }

    const timer = setInterval(refreshAllDirs, 2000);
    if (typeof timer.unref === "function") timer.unref();

    const stopEvents = context.data.listen(({ details }) => {
      const t = details?.type;
      if (
        t === "vcs.branch.updated" ||
        t === "session.execution.succeeded" ||
        t === "session.execution.interrupted" ||
        t === "session.usage.updated" ||
        t === "shell.exited" ||
        t === "worktree.ready"
      ) {
        refreshAllDirs();
      }
    });

    let layoutQueued = false;
    function scheduleApplyLayout(node = leftBoxRef) {
      if (layoutQueued) return;
      layoutQueued = true;
      queueMicrotask(() => {
        layoutQueued = false;
        applyLayout(node);
      });
    }

    function registerLifecycleNode(node) {
      if (!node || node.isDestroyed) return;
      node.onLifecyclePass = () => scheduleApplyLayout(node);
      context.renderer?.registerLifecyclePass?.(node);
      lifecycleNodes.add(node);
      scheduleApplyLayout(node);
    }

    function computeRightMetrics(sessionID, mode = "normal") {
      const w = termWidth();
      const isShell =
        mode === "shell" || liveAgentName().toLowerCase() === "shell";

      const running = sessionID
        ? context.data.session.status(sessionID) === "running"
        : false;

      let actStr = "";
      if (sessionID && w >= 96) {
        const subCount = context.data.session
          .family(sessionID)
          .filter(
            (id) =>
              id !== sessionID && context.data.session.status(id) === "running",
          ).length;
        const shCount = context.data.shell
          .list(context.location)
          .filter((s) => s.metadata?.sessionID === sessionID).length;
        const parts = [];
        if (subCount)
          parts.push(`${subCount} subagent${subCount === 1 ? "" : "s"}`);
        if (shCount) parts.push(`${shCount} shell${shCount === 1 ? "" : "s"}`);
        actStr = parts.join(" / ");
      }

      const rawAgent = isShell
        ? "Shell"
        : liveAgentName() ||
          (sessionID
            ? context.data.session.get(sessionID)?.agent
            : undefined) ||
          "Build";
      const agentStr = rawAgent.replace(/\b\w/g, (c) => c.toUpperCase());

      let pctStr = "";
      if (sessionID) {
        const session = context.data.session.get(sessionID);
        if (session) {
          const messages = context.data.session.message.list(sessionID);
          const models = context.data.location.model.list(session.location);
          const u = getContextUsage(
            messages,
            models,
            session.revert?.messageID,
          );
          if (u?.percent !== undefined) {
            pctStr = `${u.percent}%`;
          }
        }
      }

      const showAgent = true;
      const spinCols = running ? 2 : 0;

      let modelStr = "";
      const sel = context.ui.model.current();
      if (sel && w >= 58) {
        const s = sessionID ? context.data.session.get(sessionID) : undefined;
        const loc =
          s?.location ?? context.location ?? context.data.location.default();
        const models = context.data.location.model.list(loc) ?? [];
        const found = models.find(
          (m) => m.providerID === sel.providerID && m.id === sel.modelID,
        );
        const candidate = found?.name ?? sel.modelID ?? "";
        const rightWithModel =
          (actStr ? actStr.length + 3 : 0) +
          spinCols +
          agentStr.length +
          (candidate ? 1 + candidate.length : 0) +
          (pctStr ? 3 + pctStr.length : 0);
        if (w - rightWithModel - 3 >= 20) {
          modelStr = candidate;
        }
      }

      const agentModelCols =
        spinCols + agentStr.length + (modelStr ? 1 + modelStr.length : 0);

      const segments = [];
      if (actStr) segments.push(actStr.length);
      if (agentModelCols > 0) segments.push(agentModelCols);
      if (pctStr) segments.push(pctStr.length);

      const totalRightCols =
        segments.reduce((a, b) => a + b, 0) +
        Math.max(0, segments.length - 1) * 3;

      return {
        w,
        running,
        actStr,
        agentStr,
        modelStr,
        showAgent,
        pctStr,
        totalRightCols,
      };
    }

    function LeftStatus(props) {
      const [dirHovered, setDirHovered] = createSignal(false);
      const [gitHovered, setGitHovered] = createSignal(false);

      const directory = createMemo(() => {
        if (props.sessionID) {
          const s = context.data.session.get(props.sessionID);
          if (s?.location?.directory) return s.location.directory;
        }
        return (
          context.location?.directory ??
          context.data.location.default()?.directory ??
          process.cwd()
        );
      });

      createEffect(() => {
        const dir = directory();
        if (dir) {
          trackedDirs.add(dir);
          refreshGit(dir);
        }
      });

      const fullPwd = createMemo(
        () => `${VM_PREFIX}${formatShortPwd(directory())}`,
      );

      const git = createMemo(() => gitByDir()[directory()] ?? null);

      const rawBranch = createMemo(() => {
        const g = git();
        if (g?.branch) return g.branch;
        const dir = directory();
        return dir
          ? (context.data.location.vcs.info({ directory: dir })?.branch
              ?.current ?? "")
          : "";
      });

      const layout = createMemo(() => {
        const metrics = computeRightMetrics(props.sessionID, props.mode);
        const minGap = 3;
        const budget = Math.max(6, metrics.w - metrics.totalRightCols - minGap);
        const pwd = fullPwd();
        const b = rawBranch();
        const g = git();
        const addStr =
          g?.dirty && (g?.additions ?? 0) > 0 ? `+${g.additions}` : "";
        const delStr =
          g?.dirty && (g?.deletions ?? 0) > 0 ? `-${g.deletions}` : "";
        const statCols =
          (addStr ? 1 + addStr.length : 0) + (delStr ? 1 + delStr.length : 0);

        if (!b) {
          return {
            pwd: truncateLeft(pwd, budget),
            branch: "",
            addStr: "",
            delStr: "",
          };
        }

        const branchWithStatsCols = 1 + b.length + statCols;
        if (statCols > 0 && budget - branchWithStatsCols >= 8) {
          return {
            pwd: truncateLeft(pwd, budget - branchWithStatsCols),
            branch: b,
            addStr,
            delStr,
          };
        }

        const branchOnlyCols = 1 + b.length;
        if (budget - branchOnlyCols >= 6) {
          return {
            pwd: truncateLeft(pwd, budget - branchOnlyCols),
            branch: b,
            addStr: "",
            delStr: "",
          };
        }

        return {
          pwd: truncateLeft(pwd, budget),
          branch: "",
          addStr: "",
          delStr: "",
        };
      });

      const branchColor = createMemo(() => {
        themeVer();
        if (gitHovered()) return context.theme.text.base;
        const g = git();
        if (g && g.dirty) {
          return themeRed(context.theme);
        }
        return themeGreen(context.theme);
      });

      let ownEl;
      onCleanup(() => {
        if (ownEl) {
          lifecycleNodes.delete(ownEl);
          context.renderer?.unregisterLifecyclePass?.(ownEl);
          if (leftBoxRef === ownEl) {
            leftBoxRef = undefined;
          }
        }
      });

      return (
        <box
          id="theme.footer.left"
          ref={(el) => {
            ownEl = el;
            leftBoxRef = el;
            registerLifecycleNode(el);
          }}
          flexDirection="row"
          flexGrow={1}
          flexShrink={1}
          minWidth={0}
          overflow="hidden"
          gap={1}
        >
          <Show when={layout().pwd}>
            <text
              wrapMode="none"
              flexShrink={0}
              fg={
                (themeVer(),
                dirHovered()
                  ? context.theme.text.base
                  : hostColor(context.theme))
              }
              onMouseOver={() => setDirHovered(true)}
              onMouseOut={() => setDirHovered(false)}
              onMouseUp={() => context.keymap.dispatch("session.move")}
            >
              {layout().pwd}
            </text>
          </Show>
          <Show when={layout().branch}>
            <box
              flexDirection="row"
              flexShrink={0}
              gap={1}
              onMouseOver={() => setGitHovered(true)}
              onMouseOut={() => setGitHovered(false)}
              onMouseUp={() => context.keymap.dispatch("diff.open")}
            >
              <text wrapMode="none" flexShrink={0} fg={branchColor()}>
                {layout().branch}
              </text>
              <Show when={layout().addStr}>
                <text
                  wrapMode="none"
                  flexShrink={0}
                  fg={
                    (themeVer(),
                    gitHovered()
                      ? context.theme.text.base
                      : themeGreen(context.theme))
                  }
                >
                  {layout().addStr}
                </text>
              </Show>
              <Show when={layout().delStr}>
                <text
                  wrapMode="none"
                  flexShrink={0}
                  fg={
                    (themeVer(),
                    gitHovered()
                      ? context.theme.text.base
                      : themeRed(context.theme))
                  }
                >
                  {layout().delStr}
                </text>
              </Show>
            </box>
          </Show>
        </box>
      );
    }

    function RightStatus(props) {
      const [subHovered, setSubHovered] = createSignal(false);
      const [modelHovered, setModelHovered] = createSignal(false);

      const metrics = createMemo(() =>
        computeRightMetrics(props.sessionID, props.mode),
      );

      const agentColor = createMemo(() => {
        themeVer();
        return agentThemeColor(metrics().agentStr, context.theme);
      });

      const mutedFg = createMemo(() => {
        themeVer();
        return context.theme.text.muted;
      });

      const baseFg = createMemo(() => {
        themeVer();
        return context.theme.text.base;
      });

      const usage = createMemo(() => {
        if (!props.sessionID) return undefined;
        const session = context.data.session.get(props.sessionID);
        if (!session) return undefined;
        const messages = context.data.session.message.list(props.sessionID);
        const models = context.data.location.model.list(session.location);
        return getContextUsage(messages, models, session.revert?.messageID);
      });

      const usageColor = createMemo(() => {
        themeVer();
        const p = usage()?.percent;
        if (p === undefined) return context.theme.text.muted;
        if (p >= 80) return themeRed(context.theme);
        if (p >= 50) return themeYellow(context.theme);
        return themeGreen(context.theme);
      });

      const hasNormalItems = createMemo(() =>
        Boolean(
          metrics().running ||
          metrics().actStr ||
          metrics().showAgent ||
          metrics().pctStr,
        ),
      );

      let ownEl;
      onCleanup(() => {
        if (ownEl && rightBoxRef === ownEl) {
          rightBoxRef = undefined;
        }
      });

      return (
        <Show when={hasNormalItems()}>
          <box
            id="theme.footer.right"
            ref={(el) => {
              ownEl = el;
              rightBoxRef = el;
            }}
            flexDirection="row"
            flexShrink={0}
            gap={1}
          >
            <Show when={metrics().actStr}>
              <text
                wrapMode="none"
                flexShrink={0}
                fg={subHovered() ? baseFg() : mutedFg()}
                onMouseOver={() => setSubHovered(true)}
                onMouseOut={() => setSubHovered(false)}
                onMouseUp={() => context.keymap.dispatch("session.child.first")}
              >
                {metrics().actStr}
              </text>
            </Show>

            <Show
              when={
                metrics().actStr &&
                (metrics().showAgent || metrics().running || metrics().pctStr)
              }
            >
              <text wrapMode="none" flexShrink={0} fg={mutedFg()}>
                {"/"}
              </text>
            </Show>

            <Show when={metrics().showAgent || metrics().running}>
              <box
                flexDirection="row"
                flexShrink={0}
                gap={1}
                onMouseOver={() => setModelHovered(true)}
                onMouseOut={() => setModelHovered(false)}
                onMouseUp={() => context.keymap.dispatch("model.list")}
              >
                <text wrapMode="none" flexShrink={0} fg={agentColor()}>
                  {metrics().running
                    ? `${BRAILLE_FRAMES[spinnerIdx()]} ${metrics().agentStr}`
                    : metrics().agentStr}
                </text>
                <Show when={metrics().showAgent && metrics().modelStr}>
                  <text
                    wrapMode="none"
                    flexShrink={0}
                    fg={modelHovered() ? baseFg() : mutedFg()}
                  >
                    {metrics().modelStr}
                  </text>
                </Show>
              </box>
            </Show>

            <Show
              when={
                (metrics().showAgent || metrics().running) && metrics().pctStr
              }
            >
              <text wrapMode="none" flexShrink={0} fg={mutedFg()}>
                {"/"}
              </text>
            </Show>

            <Show when={metrics().pctStr}>
              <text wrapMode="none" flexShrink={0} fg={usageColor()}>
                {metrics().pctStr}
              </text>
            </Show>
          </box>
        </Show>
      );
    }

    const disposeSlots = [
      context.ui.slot({
        prepend: "prompt.footer.status",
        render: (input) => (
          <LeftStatus sessionID={input.sessionID} mode={input.mode} />
        ),
      }),
      context.ui.slot({
        append: "prompt.footer",
        render: (input) => (
          <RightStatus sessionID={input.sessionID} mode={input.mode} />
        ),
      }),
    ];

    applyLayout();

    return () => {
      clearInterval(timer);
      clearInterval(spinTimer);
      stopEvents();
      context.renderer?.off?.("resize", onRendererResize);
      context.renderer?.root?.off?.("resized", onRendererResize);
      disposeSlots.reverse().forEach((cleanup) => cleanup());
      for (const node of lifecycleNodes) {
        node.onLifecyclePass = null;
        context.renderer?.unregisterLifecyclePass?.(node);
      }
      lifecycleNodes.clear();
      for (const { node, prop } of patchedProps) {
        try {
          delete node[prop];
        } catch {}
      }
    };
  },
});
