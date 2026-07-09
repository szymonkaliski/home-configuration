---
name: morph
description: Foundation for authoring and serving a morph page, a single-file React page previewed locally with hot reload and reader-writable state (the useMorph hook). Read this whenever you build or serve a morph page, or invoke it directly to make one. morph-explain, morph-diff, and morph-playground build on it.
---

# Morph

Morph is a preview server for a single React file: it transpiles one `.jsx` file, serves it on a local port, hot-reloads the page on every save, and rewrites the file's own source when the reader interacts (the `useMorph` hook). You build a live, reader-writable page and iterate on it by editing the file in place. `morph-explain`, `morph-diff`, and `morph-playground` specialize this skill; everything below is common to any morph page.

## The file

- A single `.jsx` file whose **default export** is the page component. Basic responsive styling so it reads well on a phone.
- All React APIs (`useState`, `useRef`, `useEffect`, `useMemo`, `useLayoutEffect`, `use`, `Suspense`, `React` itself, ...) are already in scope in the preview; don't import them. `useState` holds ephemeral state; the ambient `useMorph` hook (also no import) persists reader-authored state into the document and is the channel you read and write through the file (see State channel).
- Bare npm imports resolve through esm.sh in the browser at view time (needs internet). Write them as a normal top-level `import { X } from 'pkg'` with a bare specifier: the sandbox resolves and version-pins them, and dedupes React so a component library's internal hooks share the preview's one React instance, for example, code highlighting:

  ```jsx
  import { Highlight, themes } from "prism-react-renderer";

  function CodeBlock({ code, language = "tsx" }) {
    const dark = matchMedia("(prefers-color-scheme: dark)").matches;
    return (
      <Highlight code={code.trim()} language={language} theme={dark ? themes.vsDark : themes.vsLight}>
        {({ tokens, getLineProps, getTokenProps }) => (
          <pre className="code">
            {tokens.map((line, i) => (
              <div key={i} {...getLineProps({ line })}>
                {line.map((t, k) => (
                  <span key={k} {...getTokenProps({ token: t })} />
                ))}
              </div>
            ))}
          </pre>
        )}
      </Highlight>
    );
  }
  ```

  Any code block must keep its source in a **template literal**: ``<pre>{`...`}</pre>``. JSX collapses whitespace in literal text, so code written as plain JSX text loses its newlines. Escape backticks and `${` inside the sample. Before saving, scan every code block and confirm it uses this form.

  Render a Graphviz dot graph to SVG with `@viz-js/viz`. `instance()` loads the WASM engine once and is async, so unwrap that promise with `use()` inside a `Suspense` boundary; the `dot → svg` render itself is synchronous, so memoize it and inject via `dangerouslySetInnerHTML`. Keeping the boundary inside `Graph` leaves every call site a plain `<Graph dot={...} />`:

  ```jsx
  import { instance } from "@viz-js/viz";

  const vizEngine = instance(); // WASM engine, loaded once

  function GraphSVG({ dot }) {
    const viz = use(vizEngine);
    const svg = useMemo(() => viz.renderString(dot, { format: "svg" }), [viz, dot]);
    return <div dangerouslySetInnerHTML={{ __html: svg }} />;
  }

  function Graph({ dot }) {
    return (
      <Suspense fallback={null}>
        <GraphSVG dot={dot} />
      </Suspense>
    );
  }
  ```

  Reach for a package where hand-rolling is worse; these two earn their place often.

- Style with Tailwind utility classes; the Play CDN is injected into the preview, so utilities and `dark:` variants work out of the box. Use them for layout, spacing, typography, and color. Keep a `<style>` element inside the component (CSS in a template literal) only for what utilities can't express: the page background (see Theme), `@keyframes`, and data-driven colors that need both a light and a dark value (define them as CSS custom properties with a `@media (prefers-color-scheme: dark)` override and reference `var(--…)` from inline styles). Its rules are global inside the preview iframe, so `html, body` selectors reach the whole document, not just the component subtree.
- **Theme**: follow the reader's device light/dark setting; never hardcode one. These pages are served on every interface, so they're opened over the LAN or Tailscale on whatever device the reader has (often a phone, dark at night), and should match it. With the Play CDN this is just `dark:` variants: it defaults to the `media` strategy, so `dark:` tracks the device's `prefers-color-scheme` automatically, with no config or toggle. The page background is the one thing utilities can't set, since `html, body` live outside the React tree: set it on `html, body` in the `<style>` block (not just a content card, or the preview's white outer shell leaks at the page edges and on overscroll in dark mode) with a `@media (prefers-color-scheme: dark)` override that mirrors your `dark:` classes. Both modes must stay legible, which is the real work: give a light and a dark value to every color that carries meaning, including any per-concept highlight palette, diagram node fills, and the `prism-react-renderer` theme (pick `themes.vsDark`/`themes.vsLight` off `matchMedia('(prefers-color-scheme: dark)')`). No manual toggle: it tracks the system.
- Write the file to `./tmp/` in the project root (create it if it doesn't exist; it's globally gitignored). Prefix the filename with today's date so files stay time-sorted, and always end it in `.morph.jsx` so it's clear at a glance that it's a morph page: `./tmp/YYYY-MM-DD-<slug>.morph.jsx`.

## Diagrams and charts

Pick a small number of diagram families and reuse them throughout the page to cover the various cases. Useful kinds: a very simplified version of the UI the user sees, to show UI behavior; a system diagram showing data flow or communication between components (always include example data). Never ASCII diagrams.

- **Box-and-arrow architecture diagrams**: for plain graphs (dependencies, call flow, pipelines), write Graphviz dot and render it with `@viz-js/viz` (the `Graph` component above, injected via `dangerouslySetInnerHTML`); a real layout engine solves node placement, which is exactly what generated diagrams get wrong by hand. When nodes need rich HTML content, annotations, or linked highlighting, build the boxes as plain HTML (flexbox/grid) instead and draw connectors in one absolutely positioned SVG overlay whose endpoints you measure from refs with `getBoundingClientRect()` in a `useLayoutEffect` (re-measure on window resize). Never hand-guess SVG coordinates for arrows; gaps, arrows missing their boxes, and overlapping labels are how generated diagrams break. Define the arrowhead once in `<defs><marker>` and reference it with `marker-end`, and prefer straight or orthogonal connectors over beziers.
- **Sequence / data-flow diagrams**: CSS grid swimlanes, one column per actor, one row per time step, lifelines as borders spanning the rows. Cross-lane arrows use the same measured SVG overlay.
- **Charts**: CSS-only bar charts (div sizes from percentages, real HTML text for labels) when a bar chart suffices; hand-rolled inline SVG with `<rect>`/`<polyline>`/`<line>` when you need axes or a line chart. Use a round-number `viewBox` decoupled from `width="100%"`, keep coordinates on a coarse grid. Reach for a chart library via esm.sh only when the data genuinely needs one (many series, brushing, log scales); no canvas.
- **Text in SVG**: avoid it, SVG doesn't wrap text. Keep labels as HTML overlaid on or next to the SVG, reserving SVG for geometry.
- **Animation**: CSS transitions/keyframes driven by class toggles from JS: emphasize a hovered concept, move a request token through a pipeline, draw a connector on with `stroke-dashoffset`. Animate to show state change or causality, never as decoration, and keep the diagram fully legible when nothing is animating.

## Serving

Serve the file with `morph`, as a background process since it runs indefinitely. Never call `open`; tell the user the URL and let them open it themselves:

```bash
morph "./tmp/YYYY-MM-DD-<slug>.morph.jsx"
```

- One server previews exactly one file. Without `--port` it takes the first free port from 3000 upward; read the printed `ready  previewing <file> at http://localhost:<port>` line for the actual URL. (An explicit `--port` fails fast if the port is busy.)
- Every save hot-reloads the page with Fast Refresh, and the reader's state survives every edit for as long as the server runs: `useState` is preserved across the reload, and `useMorph` values live in the document itself. So iterate by editing the file in place and keep the same server running for the whole session. Editing a `useState` initializer resets that one hook; editing a `useMorph` initializer is how you push a new value to the reader (the page reloads and adopts it, see State channel).
- morph reformats the whole file with Prettier on every change (yours or the reader's), so keep the document Prettier-clean; your own edits get normalized too.
- **Do not verify that the page renders. Make the edit and move on.** This is the single biggest time-sink to avoid. Do **not** run `esbuild`/`tsc`/`prettier`, do **not** re-open or refresh a client "to check for errors", do **not** screenshot the page to confirm it looks right, and do **not** poll morph's output to confirm a render succeeded (an `update` line with no `error` after it is *not* a signal worth waiting for). The reader is looking at the live page, and morph shows any transpile or runtime error as an overlay *in that page*, so a genuinely broken edit is surfaced to the reader, who will tell you; it is not something you discover by inspecting. morph also reformats with Prettier on every save, so never run Prettier yourself either. Trust your edit and spend the effort on the content, not on confirming pixels. (morph's output is still worth watching for exactly one thing, reader edits, see the watch loop below, never for render confirmation.)
- Tell the user the URL. The `ready` line prints `http://localhost:<port>`, but the server binds every interface, so it's equally reachable at `http://<hostname>:<port>` (`hostname -s`) over the LAN or Tailscale; offer that form too when the reader might open it on another device like a phone.

## State channel

morph has no HTTP state endpoint. The document's own source is the state: an ambient `useMorph(initial)` hook (a `useState` you don't import) whose **initializer literal is rewritten in the file** when the reader interacts. That is the whole channel, both directions:

- **screen → you.** When the reader changes a `useMorph` value (types a question, picks an option), morph rewrites that initializer in the `.jsx` file and logs a `mutate  Component.variable` line followed by a colored word-level diff of exactly what changed (capped at 30 lines). The server runs in the background, so watch its output to see reader activity as it happens; read the `.jsx` file when you need the full current value.
- **you → screen.** To respond to a comment, seed a value, or reset a hook, edit its `useMorph` initializer in the file. morph pushes the new source to the page, which hot-reloads and adopts the new literal (your edit rebases cleanly onto a concurrent reader edit of the same value).

Design for it:

- **Persist only what should round-trip.** Use `useMorph` for reader-authored content you want to read back (comments, questions, choices); use plain `useState` for ephemeral emphasis (`hovered`, open/closed UI) so hovering doesn't churn the file. Only a **top-level** `useMorph` with a **JSON-literal** initializer persists: a `useMorph(makeDefault())`, or one inside a `.map()` (one initializer, many mounts), stays in-memory only and silently won't round-trip.
- **One top-level hook per collection, keyed by id.** Model per-section state as a single top-level `useMorph({})` object keyed by id (`values[id]`), not a `useMorph` per rendered item. Each mutation logs under the identity `Component.variable` (enclosing component name + destructured variable), so name them deliberately (`Page.comments`, not `C.v`) to keep the log legible.
- **Batch large edits.** Hold in-progress text in a local `useState` and push to the persisted hook only on an explicit action (a Send, a commit), never per keystroke, so a long entry doesn't rewrite and reformat the file as it is typed.
- **The reverse direction works too.** Edit the file to clear a value (`values[id] = ""`), seed or correct a value, or reset a hook to its default; the page reloads and adopts it.

## Reader comments and the watch loop

A margin comment rail is the reusable way the reader talks back and the document gets refined, built directly on the `useMorph` round-trip. It is additive and gates nothing, so it does not break an "everything visible at once" page. The reader questions a block, you answer in the rail and, when the answer belongs in the document, revise the content and leave a short note saying what changed.

**The `Block` wrapper.** One top-level `const [comments, setComments] = useMorph({})`, keyed by block id, each value an array of `{ by, text }` (`by: "you"` for the reader, `by: "claude"` for your replies; nested arrays still round-trip as long as the whole initializer stays a JSON literal). Wrap every block (paragraph, callout, diagram, table) with a stable id; lay content left and the rail right with a CSS grid (`minmax(0,1fr)` plus a fixed rail, stacking under the content on narrow screens, so there is no fragile position measuring).

```jsx
const [comments, setComments] = useMorph({});
const addComment = (id, text) =>
  setComments({ ...comments, [id]: [...(comments[id] || []), { by: "you", text }] });

function Block({ id, children }) {           // comments/addComment via context or closure
  const thread = comments[id] || [];
  const [draft, setDraft] = useState("");
  const [open, setOpen] = useState(false);
  const send = () => { const t = draft.trim(); if (t) addComment(id, t); setDraft(""); setOpen(false); };
  return (
    <div className="cmt-row">
      <div className="cmt-body">{children}</div>
      <aside className="cmt-rail">
        {thread.map((c, i) => <div key={i} className={c.by === "claude" ? "cmt-card claude" : "cmt-card"}>{c.text}</div>)}
        {open
          ? <><textarea value={draft} onChange={(e) => setDraft(e.target.value)} /><button onClick={send}>Send</button></>
          : <button onClick={() => setOpen(true)}>{thread.length ? "+ reply" : "+ comment"}</button>}
      </aside>
    </div>
  );
}
```

**Arm the watch loop after serving.** morph logs `mutate  Page.comments` to its background output whenever the reader posts (your own file edits log `update`, not `mutate`, so they never echo back as false events). Start a persistent monitor on that output so each new comment notifies you without the user having to ask:

```bash
tail -n0 -F <morph-background-output> | grep --line-buffered "mutate  Page.comments"
```

On each event, read the `.jsx` for the full thread, then edit the file: append a `{ by: "claude", text }` reply into that block's array, and/or revise the content and leave a short reply saying what you changed (the page hot-reloads and the reader sees it). If a claim is challenged, verify it (web search or the code) before answering, and correct the document rather than defend it. The watch lives only as long as this session, so tell the reader that, and stop it when they are done.
