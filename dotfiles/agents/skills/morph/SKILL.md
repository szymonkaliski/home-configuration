---
name: morph
description: Build, serve, and monitor a morph page, a single .jsx file previewed locally with hot reload whose state lives in the file itself (useMorph) and which can run approved shell commands (useShell). Serving always includes arming a persistent Monitor on the output, since the reader's clicks and comments come back through the file and must reach you as notifications without them asking. Use whenever you author, serve, or respond to a morph document.
---

# Morph

morph serves one `.jsx` file (or a directory of them), hot-reloads on every save, and rewrites the file's own source when the reader interacts. The file is the state: there is no store and no HTTP state endpoint. The morph repo's `README.md` is the authority on mechanics; read it when you need more than this.

## Build an instrument, not a report

The strong default is that **the thing under discussion is rendered live at full size, in the form it will really take, and everything else on the page is a control that changes it.** Not a list of options described in cards for the reader to read top to bottom and imagine.

If you are choosing between fifteen versions of a paragraph, the page shows *one* paragraph (the current one, typeset the way it will actually ship) and the fifteen candidates are a control that swaps it. If you are tuning a layout, the layout is on screen and the knobs are beside it. The reader should be able to answer "how does this feel?" by looking, never by reconstructing it in their head from a description.

This follows from the medium. A morph page can re-render on click; prose cannot. **If the page would work just as well pasted into a chat message, it is a document and you have wasted the medium.** Use that as the test before you serve.

What this implies in practice:

- Put the artifact at the top, big, and give it room. Controls go underneath or beside it, visually quieter than the thing they control.
- Attach your commentary to the control and reveal it on selection, rather than stacking explanatory paragraphs the reader must wade through. Say the cost of the option they are actually looking at.
- Push rationale, references, and diagnosis into collapsed drawers. They are support, and they should not outweigh the artifact by ten to one.
- Offer a way to see the current/original state for comparison, since "is this actually better?" is the question the reader is really asking.
- Prefer one control per decision over one card per combination. Decisions compose; cards multiply.

Reach for a document shape only when there is genuinely nothing to manipulate: a summary of findings with no open choices. Even then, ask what the reader will want to change, and whether the answer is really nothing.

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

Then arm the watch, in the same turn, before you go back to editing. **Use `Monitor`, not a backgrounded `Bash` command.** Monitor turns every stdout line into a notification delivered to you as it happens; a backgrounded `tail -F | grep` writes to an output file that nothing delivers, so the reader's comments pile up unread until you happen to look. The reader should never have to nudge you in chat to say they commented.

```
Monitor({
  command: 'tail -n0 -F <morph-background-output> | grep --line-buffered -E "^[0-9:]{8} (mutate|error|skip|ask|ok|shell|grant|deny|stop|warn)"',
  description: 'morph reader edits + errors on <slug>',
  persistent: true,
  timeout_ms: 3600000,
})
```

`persistent: true` is required: this watch must live as long as the session, and the default 5-minute timeout would silently disarm it mid-conversation. `--line-buffered` is required too, or matches sit in grep's buffer instead of reaching you.

The filter drops the tags that are not the reader: `ready`, `open`, `new`, and `gone` are server and route lifecycle, and `update` fires on **your own** saves, so including it would notify you about yourself on every edit. Everything else is the reader acting or the page breaking. One event per line as `HH:MM:SS <tag> <message>`:

| tag                       | what happened                                                    | what you do                                                       |
| ------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------- |
| `mutate`                  | the reader changed a `useMorph` value                            | read the `.jsx` for the full value, then edit the file to respond |
| `ask`                     | a `useShell` hook is waiting on approval                         | tell the reader it is waiting; they may be on another device      |
| `grant` / `deny` / `stop` | the reader answered that approval, or cancelled a running command | on `deny` and `stop`, stop expecting a result                     |
| `shell`                   | a command started, then finished (`N line(s)`, or red `exit N`)  | on a failure, read the result in the `.jsx` and respond           |
| `skip`                    | a change was refused, usually a non-literal                      | fix the initializer; the reader watched it roll back              |
| `warn`                    | a file read or write failed, so a reader change may not have landed | re-read the `.jsx` to see what is actually there                |
| `error`                   | an edit broke the preview                                        | fix until `ok` follows                                            |
| `ok`                      | the preview recovered after an `error`                           | nothing, the fix landed                                           |

A notification carries only the tag line, not the value. On any `mutate`, read the `.jsx` to see what the reader actually wrote, then respond in the same turn: treat it as an interruption worth handling now, not something to batch. `error` is urgent.

Silence means nothing happened, with one exception: if the morph server itself dies, `tail -F` sits on a frozen file and stays quiet forever. That case is covered by the server's own background task, which notifies you when it exits. Treat that notification as the page being down.

Do not sit and wait for the reader either. Events arrive on their own schedule and can land at any point, including while you are waiting on an unrelated answer; an incoming `mutate` is not a reply to whatever you last asked. Keep working, and let the notification interrupt you.

The monitor lives only as long as this session. Tell the reader that, and `TaskStop` it when they are done.

## Every save is published

Keep one server for the whole session. Every save hot-reloads with Fast Refresh and the reader's state survives: `useState` is preserved, `useMorph` values live in the file. Editing a `useMorph` initializer is how you push a new value to the reader.

Which means there is no staging area. The reader is looking at the page while you work, so each intermediate save is a frame in something they are watching. **Order your edits so the file is valid after every single one.**

The failure modes are not equally visible. A transpile or load failure keeps the last good render, so the reader sees a stale but intact page. A throw *during render* blanks it to white. Referencing something that does not exist yet is the blanking kind, and it is the one you will cause.

So, always: **define first, then wire up.** "Define" covers every binding the new markup reads, not just the obvious ones:

- Adding a component, constant, or helper: add the definition in one edit, reference it in the next. Never introduce `<Card>` into the render before `Card` exists in the file.
- **Adding a hook or local variable counts.** A section that reads `freeTime` needs its `useMorph`/`useState` line to land *first*. This is the easy one to miss, because you are thinking about the component you just carefully defined and the local slips through in the same edit as the JSX that uses it.
- Renaming: add the new name, move the call sites, then delete the old one. Three valid states.
- Deleting: remove the references first, the definition last.
- Restructuring a list into a shared component: write the component alongside the existing inline copy, switch the call sites, then remove the inline copy.

Before saving JSX you just wrote, reread it for every identifier it references and confirm each one already exists in the file on disk. That check is faster than the reader watching the page blank.

When a change cannot be made in one valid step, pick the smallest sequence of valid intermediates rather than the shortest sequence of edits. An extra tool call costs you nothing; a white screen costs the reader their place, their scroll position, and their confidence that the page works.

Ordering correctly is not the same as verifying. **Do not poll to confirm your own edit rendered. Make the edit and move on.** This is the biggest time-sink to avoid. Do not run esbuild, tsc, or Prettier (morph reformats the file itself), do not open a browser or screenshot the page, and do not re-read the output hunting for a clean render. Never wait to confirm an error's absence: the monitor will tell you if there is one.

Two things silently fail to survive a hot-swap, and both have the same fix: stash on `window`.

- **Element types created at module scope.** Fast Refresh preserves identity for *functions* only. A module-scope `React.createContext()` (likewise `memo`/`forwardRef` wrappers and HOC results) is a fresh object on every re-eval, so React sees a different Provider element type and **remounts everything beneath it**, resetting every `useState` on the page on every save, with no error and no event. Create it once: `const Ctx = (window.__CTX__ ??= React.createContext(null))`.
- **In-progress text drafts.** A `useState` draft dies whenever its component remounts, which your edits can cause at any moment. Mirror keystrokes into a `window` stash and seed the field from it on mount, so a save landing mid-sentence costs the reader nothing.

(The precise remount rules: a component's `useState`/`useReducer` initializer text is part of its refresh signature, so editing an initializer remounts that component. `useMorph`/custom-hook arguments are not part of the signature, so pushing a new value by editing a `useMorph` initializer does not remount anything.)

## Everything is commentable

A morph page is a conversation, not a report. **Every distinct thing you present must have a way for the reader to respond to it, and the unit of commenting should be as small as the unit of thought.** If you show ten options, that is ten comment boxes, not one at the bottom. If you show a rewritten paragraph, the paragraph is commentable. A block with no affordance is you saying "no notes on this one," which is never what you meant.

The failure is easy to miss because it happens by omission, and it lands on the thing you spent the most effort on: you build the careful per-item controls for a list, then add a big new section later and forget it entirely. Audit before you serve: walk the page top to bottom and name the id for each block. Any block you cannot name has no box.

**Comments are threads, not single notes.** A one-string-per-block map forces the reader to overwrite their own earlier note and gives your replies nowhere to live, so the conversation leaks into chat and the page stops being the record. The map value is a list of messages, `{ "block-id": [{ who: "you", text: "..." }, { who: "claude", text: "..." }] }`, in a single top-level `useMorph` keyed by block id. The reader's Send appends a `{ who: "you" }` entry; you reply by editing the initializer and appending a `{ who: "claude" }` entry to the same list. The exchange then reads in order, chat-style, right next to the thing it discusses.

Practical shape: one `Annotatable`-style wrapper that takes an `id`, renders its children, and reveals the thread on tap. Then wrapping a new block is one line.

- Render the thread as a conversation: a `who` label on each message, reader and author visually distinct (alignment or color). An undifferentiated wall of text is not a thread.
- Keep the affordance visible-but-quiet (a faint marker at ~30% opacity that solidifies on hover) and always tappable. A pure `hover:` reveal does not exist on a phone, and these get read on phones.
- Show the message count in the marker when a thread exists, so the reader sees at a glance where conversation is already happening.
- Choose ids that describe the content (`intro-freetime`), not the position (`section-3`). Reordering the page must not silently reattach a comment to different content, and the id is what you will grep for when the `mutate` arrives.
- Offer both grains where both make sense: per-item boxes *and* a whole-section box, since "this option is wrong" and "the whole framing is wrong" are different notes.

## State channel: useMorph

`useMorph(initial)` is a `useState` whose **initializer literal is rewritten in the file** when the reader interacts. That is the whole channel, both ways: the reader's change lands in the `.jsx` and logs a `mutate Component.variable` line with a diff; to reply or reset, you edit the initializer and the page adopts it on reload.

- **`useMorph` is the default. Reach for `useState` only when you can name the reason this value must not persist.** Getting this backwards is the most common way to make a page feel broken.

  You are editing the file while the reader is using the page, and Fast Refresh preserves `useState` only while a component's hook list stays stable. Adding a hook, renaming the component, or restructuring it remounts and silently resets every `useState` inside. So the reader collapses a section, you save, and it springs back open, repeatedly, with no error and no event, because a reset `useState` is invisible to you. They just quietly redo the work until they complain.

  Anything the reader *deliberately sets* is a preference: collapsed/expanded, chosen tab, sort order, filters, selected variant. Persist all of it.

  `useState` is correct in three cases, all narrow: per-keystroke drafts batched behind a blur or Send button (keeping churn out of the file is the point), genuinely transient pointer state (hover, focus, drag), and anything inside a `.map()`, where one `useMorph` literal shared across every mount makes it wrong anyway.
- Initializers must be **JSON literals**: `useMorph(makeDefault())` is refused with a `skip` line and the page rolls the edit back visibly. Placement is not checked, though, because the key is one per *declaration*: a hook inside a `.map()` is accepted and shares a single literal across every mount, so all of them get the last write.
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
