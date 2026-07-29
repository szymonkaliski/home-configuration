---
name: morph
description: Build, serve, and watch a morph page, a single .jsx file previewed locally with hot reload whose state lives in the file itself (useMorph) and which can run approved shell commands (useShell). Serving always includes watching the output, since the reader's clicks and comments come back through the file for you to act on. Use whenever you author, serve, or respond to a morph document.
---

# Morph

morph serves one `.jsx` file (or a directory of them), hot-reloads on every save, and rewrites the file's own source when the reader interacts. The file is the state: there is no store and no HTTP state endpoint. The morph repo's `README.md` is the authority on mechanics; read it when you need more than this.

## The file

- One `.jsx` file, default export is the page component. Keep it responsive; these get opened on phones.
- `useMorph` and `useShell` are ambient, no import. So are the React APIs (`useState`, `useMemo`, `useEffect`, `use`, `Suspense`, `React`).
- Bare npm imports resolve through esm.sh in the browser at view time, unpinned. Pin in the specifier (`'pkg@1.2.3'`) when stability matters.
- Tailwind is loaded into the preview from a pinned CDN, so utilities and `dark:` work with no setup. Follow the reader's device theme, never hardcode dark. The page background is the exception: `html, body` live outside the React tree, so set it in a `<style>` block with a `prefers-color-scheme` override, or the white shell leaks at the edges.
- Keep code samples in a template literal, `<pre>{`...`}</pre>`. JSX collapses whitespace in literal text, so code written as plain JSX text loses its newlines.
- Write to `./tmp/YYYY-MM-DD-<slug>.morph.jsx` in the project root.

## Serving and watching

Serving is two steps and **the second is not optional**. Start the server in the background, then arm a watch on its output and keep it running for the rest of the session. A morph page exists so the reader can click, comment, and answer inside it; every one of those actions lands in the file and is yours to act on. Serving without watching means the reader talks and nobody listens.

```bash
morph ./tmp/2026-07-29-notes.morph.jsx   # one document, at /
morph ./docs                             # every top-level .jsx, each at its own route, index at /
```

Never call `open`. Read the `ready` line for the real URL and tell the reader. Port 3000 by default or the next free one; an explicit `--port` fails fast if busy. The server binds every interface, so also offer `http://<hostname>:<port>` (`hostname -s`) for a phone on the LAN or Tailscale.

Then arm the watch, in the same turn, before you go back to editing:

```bash
tail -n0 -F <morph-background-output> | grep --line-buffered -E "^[0-9:]{8} (mutate|error|skip|ask|ok)"
```

Piped output carries no colour, one event per line as `HH:MM:SS <tag> <message>`:

| tag      | what happened                               | what you do                                                       |
| -------- | ------------------------------------------- | ----------------------------------------------------------------- |
| `mutate` | the reader changed a `useMorph` value       | read the `.jsx` for the full value, then edit the file to respond |
| `ask`    | a `useShell` hook is waiting on approval    | tell the reader it is waiting; they may be on another device      |
| `skip`   | a change was refused, usually a non-literal | fix the initializer; the reader watched it roll back              |
| `error`  | an edit broke the preview                   | fix until `ok` follows                                            |
| `ok`     | the preview recovered after an `error`      | nothing, the fix landed                                           |

**The watch does not interrupt you. It is a log, and nothing delivers it.** A backgrounded `tail -F | grep` never exits, and a harness that re-invokes you when a background command *exits* will therefore never re-invoke you for this one. Events pile up in the output file and stay there, unread, until you go and look. Arming the watch is necessary and is not sufficient.

So read it, deliberately, at these three moments:

```bash
cat <watch-background-output>          # every event so far, one line each
```

- **Before every reply to the reader.** They may have commented while you were working, and answering without having read is how you tell someone you are listening while ignoring them.
- **After finishing any unit of work**, before starting the next one.
- **Before saying you are done** or asking what to do next.

Then read the `.jsx` for the values behind the events. Never tell the reader their comments "reach you" or that you are "watching" unless you have just read the log. You are polling it, and saying so is both honest and accurate.

Treat a `mutate` you find as an interruption worth handling now, not something to batch until the reader asks. `error` is urgent: a transpile or load failure keeps the last good render, but a throw during render blanks the page. Your own file edits log `update`, not `mutate`, so they never echo back as false events.

The watch lives only as long as this session. Tell the reader that, and stop it when they are done.

Keep one server for the whole session. Every save hot-reloads with Fast Refresh and the reader's state survives: `useState` is preserved, `useMorph` values live in the file. Editing a `useState` initializer remounts that component and resets its hooks; editing a `useMorph` initializer is how you push a new value to the reader.

**Do not poll to confirm your own edit rendered. Make the edit and move on.** This is the biggest time-sink to avoid. Do not run esbuild, tsc, or Prettier (morph reformats the file itself), do not open a browser or screenshot the page, and do not re-read the output hunting for a clean render. Never wait to confirm an error's absence.

That is about your own output, and it does not license skipping the reader's. Reading the watch log at the three moments above is the opposite habit and it is required: you are checking for something that has already happened, not waiting for something that might.

## State channel: useMorph

`useMorph(initial)` is a `useState` whose **initializer literal is rewritten in the file** when the reader interacts. That is the whole channel, both ways: the reader's change lands in the `.jsx` and logs a `mutate Component.variable` line with a diff; to reply or reset, you edit the initializer and the page adopts it on reload.

- Persist only what should round-trip. `useMorph` for reader-authored content (comments, answers, choices); plain `useState` for hover and open/closed, so interaction doesn't churn the file.
- Initializers must be **JSON literals** and hooks must be **top-level**. `useMorph(makeDefault())` is refused with a `skip` line and the page rolls the edit back visibly. One inside a `.map()` shares a single literal across every mount, so all of them get the last write.
- One top-level hook per collection, keyed by id (`Page.comments`), not a hook per item. The identity `Component.varName` is the round-trip key, so renaming the component or the variable orphans a reader's in-flight edit.
- Prefer the recipe setter, `setX(draft => { ... })`. It produces granular immer patches that rebase onto a concurrent edit; `setX({ ...x })` is one root-replace that can lose a change.
- Batch large edits behind an explicit action (a Send button), never per keystroke.
- Concurrency is one way: a reader mutation rebases onto the file, but your save is a plain write. After any `mutate`, re-read the file before editing.

## Running commands: useShell

`useShell(command, result)` is the same trick pointed outward: the host runs the command and writes the result into the second argument.

- The command must be a **static string literal**, and it is split into argv and spawned with no shell, so `&&` and `$(...)` are inert.
- The reader approves each command in a host-page dialog; the terminal logs `ask` at the same moment, because the page may be open on another device. Grants are stored outside the document, so a yes never travels with the file.
- The result is a discriminated union (`idle`, `asking`, `running`, `denied`, `cancelled`, `ok`, `failed`, `stale`, `unavailable`); handle every case. Only `ok` and `failed` persist.
- It runs once, then stops. A hook that already has a result never re-runs on its own; refreshing is an explicit act.
