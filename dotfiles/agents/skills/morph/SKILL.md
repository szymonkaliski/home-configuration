---
name: morph
description: Foundation for authoring and serving a morph page, a single-file React page previewed locally with hot reload and reader-writable state (the useMorph hook). Read this whenever you build or serve a morph page, or invoke it directly to make one. morph-explain, morph-diff, and morph-playground build on it.
---

# Morph

Morph is a preview server for a single React file: it transpiles one `.jsx` file, serves it on a local port, hot-reloads the page on every save, and rewrites the file's own source when the reader interacts (the `useMorph` hook). You build a live, reader-writable page and iterate on it by editing the file in place. `morph-explain`, `morph-diff`, and `morph-playground` specialize this skill; everything below is common to any morph page.

## The file

- A single `.jsx` file whose **default export** is the page component. Basic responsive styling so it reads well on a phone.
- All React APIs (`useState`, `useRef`, `useEffect`, `useMemo`, `useLayoutEffect`, `use`, `Suspense`, `React` itself, ...) are already in scope in the preview; don't import them. `useState` holds ephemeral state; the ambient `useMorph` hook (also no import) persists reader-authored state into the document and is the channel you read and write through the file (see State channel).
- Bare npm imports resolve through esm.sh in the browser at view time (needs internet). Write them as a normal top-level `import { X } from 'pkg'` with a bare specifier: the sandbox resolves them through esm.sh unpinned (the import floats to the package's latest version; pin in the specifier, `'pkg@1.2.3'`, when stability matters) and dedupes React so a component library's internal hooks share the preview's one React instance, for example, code highlighting:

  ```jsx
  import { Highlight, themes } from "prism-react-renderer";

  function CodeBlock({ code, language = "tsx" }) {
    const dark = matchMedia("(prefers-color-scheme: dark)").matches;
    return (
      <Highlight
        code={code.trim()}
        language={language}
        theme={dark ? themes.vsDark : themes.vsLight}
      >
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
    const svg = useMemo(
      () => viz.renderString(dot, { format: "svg" }),
      [viz, dot],
    );
    return <div className="graph" dangerouslySetInnerHTML={{ __html: svg }} />;
  }

  function Graph({ dot }) {
    return (
      <Suspense fallback={null}>
        <GraphSVG dot={dot} />
      </Suspense>
    );
  }
  ```

  SVG text does not inherit page CSS, so make it legible and page-matching in the `dot` itself, and watch two traps that make graph text tiny or off-brand:

  - **Font.** The graphviz default is `Times,serif`, which clashes with a sans page. Set a sans `fontname` and a generous `fontsize` on `node` and `edge` up front: `node [fontname="Helvetica" fontsize=14 …]; edge [fontname="Helvetica" fontsize=12 …]`. (A CSS-generic like `ui-sans-serif` is emitted verbatim as `font-family` and does render, but graphviz has no metrics for it and lays the boxes out with fallback metrics, so prefer a real family it knows.)
  - **The scaling trap** (the usual cause of "the graph text is tiny"). viz-js emits an SVG whose intrinsic width is whatever the layout needs; `.graph svg { max-width:100% }` then shrinks any graph wider than its column, and the text shrinks with it. Measured: a five-node `rankdir=LR` chain with sentence-length labels renders ~1090px wide, so in a ~900px column its 11px labels drop to ~9px, and to ~4px on a phone. The fix is to keep the graph no wider than its column, not to bump `fontsize` (bigger labels make wider nodes make a wider graph that shrinks right back). So: prefer `rankdir=TB` (the same graph is ~250px wide as TB and renders at full size, growing downward, which the page scrolls anyway), keep node labels to a few words and push detail into the surrounding prose, and give a wide diagram the full content width rather than a column that shares space with a comment rail. Only when a graph is genuinely wide and cannot be narrowed, wrap it in `.graph { overflow-x:auto }` and let it scroll at natural size rather than scale its text below ~11px.

  Reach for a package where hand-rolling is worse; these two earn their place often.

- Style with Tailwind utility classes; the Tailwind Play engine is loaded into the preview from its CDN at view time (needs internet, same as esm.sh imports), so utilities and `dark:` variants work out of the box with no setup or imports. Use them for layout, spacing, typography, and color. Keep a `<style>` element inside the component (CSS in a template literal) only for what utilities can't express: the page background (see Theme), `@keyframes`, and data-driven colors that need both a light and a dark value (define them as CSS custom properties with a `@media (prefers-color-scheme: dark)` override and reference `var(--…)` from inline styles). Its rules are global inside the preview iframe, so `html, body` selectors reach the whole document, not just the component subtree.
- **Theme**: follow the reader's device light/dark setting; never hardcode one. These pages are served on every interface, so they're opened over the LAN or Tailscale on whatever device the reader has (often a phone, dark at night), and should match it. With the Play engine this is just `dark:` variants: it defaults to the `media` strategy, so `dark:` tracks the device's `prefers-color-scheme` automatically, with no config or toggle. The page background is the one thing utilities can't set, since `html, body` live outside the React tree: set it on `html, body` in the `<style>` block (not just a content card, or the preview's white outer shell leaks at the page edges and on overscroll in dark mode) with a `@media (prefers-color-scheme: dark)` override that mirrors your `dark:` classes. Both modes must stay legible, which is the real work: give a light and a dark value to every color that carries meaning, including any per-concept highlight palette, diagram node fills, and the `prism-react-renderer` theme (pick `themes.vsDark`/`themes.vsLight` off `matchMedia('(prefers-color-scheme: dark)')`). No manual toggle: it tracks the system.
- Write the file to `./tmp/` in the project root (create it if it doesn't exist; it's globally gitignored). Prefix the filename with today's date so files stay time-sorted, and always end it in `.morph.jsx` so it's clear at a glance that it's a morph page: `./tmp/YYYY-MM-DD-<slug>.morph.jsx`.

## Diagrams and charts

Pick a small number of diagram families and reuse them throughout the page to cover the various cases. Useful kinds: a very simplified version of the UI the user sees, to show UI behavior; a system diagram showing data flow or communication between components (always include example data). Never ASCII diagrams.

- **Box-and-arrow architecture diagrams**: choose by layout complexity. For a **simple linear flow** (a pipeline, a chain of a few steps, one path with a branch or two), lay the boxes out in HTML (a flex row that wraps to a column on narrow screens, arrows as chevrons or a thin connector between the cards) so the labels are real page type: crisp, correctly sized, matching the document, theme-aware, and highlightable, with none of the SVG scaling and font caveats below. Reserve **Graphviz** for a **genuinely complex or non-linear graph** (many nodes, cross-edges, placement that is not obvious by hand) where the layout engine earns its keep; render it with `@viz-js/viz` (the `Graph` component above, injected via `dangerouslySetInnerHTML`) and follow the font and scaling rules above so its text stays legible. When HTML boxes need rich content, annotations, linked highlighting, or arbitrary (non-linear) connectors, draw the connectors in one absolutely positioned SVG overlay whose endpoints you measure from refs with `getBoundingClientRect()` in a `useLayoutEffect` (re-measure on window resize). Never hand-guess SVG coordinates for arrows; gaps, arrows missing their boxes, and overlapping labels are how generated diagrams break. Define the arrowhead once in `<defs><marker>` and reference it with `marker-end`, and prefer straight or orthogonal connectors over beziers.
- **Sequence / data-flow diagrams**: CSS grid swimlanes, one column per actor, one row per time step, lifelines as borders spanning the rows. Cross-lane arrows use the same measured SVG overlay.
- **Charts**: CSS-only bar charts (div sizes from percentages, real HTML text for labels) when a bar chart suffices; hand-rolled inline SVG with `<rect>`/`<polyline>`/`<line>` when you need axes or a line chart. Use a round-number `viewBox` decoupled from `width="100%"`, keep coordinates on a coarse grid. Reach for a chart library via esm.sh only when the data genuinely needs one (many series, brushing, log scales); no canvas.
- **Text in SVG**: avoid it, SVG doesn't wrap text. Keep labels as HTML overlaid on or next to the SVG, reserving SVG for geometry.
- **Animation**: CSS transitions/keyframes driven by class toggles from JS: emphasize a hovered concept, move a request token through a pipeline, draw a connector on with `stroke-dashoffset`. Animate to show state change or causality, never as decoration, and keep the diagram fully legible when nothing is animating.

## Serving

Serve the file with `morph`, as a background process since it runs indefinitely. Never call `open`; tell the user the URL and let them open it themselves:

```bash
morph "./tmp/YYYY-MM-DD-<slug>.morph.jsx"
```

- One server previews exactly one file. It serves on port 3000 by default, or the next free port if 3000 is taken; read the printed `ready  previewing <file> at http://localhost:<port>` line for the actual URL. (An explicit `--port` fails fast if the port is busy.)
- Every save hot-reloads the page with Fast Refresh, and the reader's state survives every edit for as long as the server runs: `useState` is preserved across the reload, and `useMorph` values live in the document itself. So iterate by editing the file in place and keep the same server running for the whole session. Editing a `useState` initializer remounts that whole component and resets all its hooks, since the initializer's source is part of the Fast Refresh signature (`useMorph` values survive, they re-read the file's literal); editing a `useMorph` initializer is how you push a new value to the reader (the page reloads and adopts it, see State channel).
- morph Prettier-normalizes the file once at startup and reformats it on every change (yours or the reader's), so the document stays Prettier-clean on its own; your edits get normalized too.
- Restarting the server mid-session is safe: the page shows a `disconnected` badge, reconnects within a second, and replays edits the reader made while it was down only if the file did not change in the meantime; otherwise it drops them and re-adopts the file, visibly rolling back anything the file never received (`useState` values are untouched).
- **Do not verify that the page renders. Make the edit and move on.** This is the single biggest time-sink to avoid. Do **not** run `esbuild`/`tsc`/`prettier`, do **not** open a browser or spawn chrome-devtools to inspect the page, do **not** screenshot it, and do **not** poll morph's output to confirm a render succeeded (an `update` line with no `error` after it is _not_ a signal worth waiting for). A broken edit announces itself in morph's background output: a red `error` line (`invalid jsx: ...` for a transpile failure, `runtime error: ...` for a throw at load or render), followed by `ok     preview recovered` once a good render lands. The reader never sees an error message - a transpile or load failure keeps showing the last good render, but a throw _during_ render blanks the page (the error boundary renders nothing) - so that `error` line is the only signal there is, and can mean the reader is staring at a blank page; react to one if it shows up in the output you are already watching (see the watch loop below), never wait to confirm its absence. morph also reformats with Prettier on every save, so never run Prettier yourself either. Trust your edit and spend the effort on the content, not on confirming pixels.
- Tell the user the URL. The `ready` line prints `http://localhost:<port>`, but the server binds every interface, so it's equally reachable at `http://<hostname>:<port>` (`hostname -s`) over the LAN or Tailscale; offer that form too when the reader might open it on another device like a phone.

## State channel

morph has no HTTP state endpoint. The document's own source is the state: an ambient `useMorph(initial)` hook (a `useState` you don't import) whose **initializer literal is rewritten in the file** when the reader interacts. That is the whole channel, both directions:

- **screen → you.** When the reader changes a `useMorph` value (types a question, picks an option), morph rewrites that initializer in the `.jsx` file and logs a `mutate Component.variable` line followed by a diff of exactly what changed (capped at 30 lines): an inline word-level diff when stdout is an interactive TTY with color, or paired `- old` / `+ new` lines when the output is piped or tailed from a file, which is how the watch loop below runs it. The server runs in the background, so watch its output to see reader activity as it happens; read the `.jsx` file when you need the full current value.
- **you → screen.** To respond to a comment, seed a value, or reset a hook, edit its `useMorph` initializer in the file. morph pushes the new source to the page, which hot-reloads and adopts the new literal. Concurrency runs one way: a reader mutation rebases onto the current file, but your save is a plain write, so after any `mutate` re-read the file and edit fresh rather than writing from a stale copy, which clobbers their edit.

Design for it:

- **Persist only what should round-trip.** Use `useMorph` for reader-authored content you want to read back (comments, questions, choices); use plain `useState` for ephemeral emphasis (`hovered`, open/closed UI) so hovering doesn't churn the file. Keep every `useMorph` **top-level** with a **JSON-literal** initializer; each violation fails differently. A non-literal initializer (`useMorph(makeDefault())`) cannot round-trip and is refused loudly: the CLI logs a `skip`, and the page rolls the reader's edit back and flashes a `change rejected` badge, so it isn't usable as ephemeral state either (that's what `useState` is for). One inside a `.map()` (one initializer, many mounts) does round-trip, but wrongly: every mount's write rewrites the same shared literal, and the reload then pushes the last write into all of them.
- **One top-level hook per collection, keyed by id.** Model per-section state as a single top-level `useMorph({})` object keyed by id (`values[id]`), not a `useMorph` per rendered item. Each mutation logs under the identity `Component.variable` (enclosing component name + destructured variable), so name them deliberately (`Page.comments`, not `C.v`) to keep the log legible. That identity is also the round-trip key: renaming the component or the destructured variable orphans a reader's in-flight edit (it arrives under the old name, is refused, and snaps back with a `change rejected` badge), so don't rename a live page's `useMorph` variables mid-session. Keep identities unique, too: two hooks that derive the same `Component.variable` (say, two same-named components) are refused the same way.
- **Batch large edits.** Hold in-progress text in a local `useState` and push to the persisted hook only on an explicit action (a Send, a commit), never per keystroke, so a long entry doesn't rewrite and reformat the file as it is typed.
- **The reverse direction works too.** Edit the file to clear a value (`values[id] = ""`), seed or correct a value, or reset a hook to its default; the page reloads and adopts it.

## Reader comments and the watch loop

A margin comment rail is the reusable way the reader talks back and the document gets refined, built directly on the `useMorph` round-trip. It is additive and gates nothing, so it does not break an "everything visible at once" page. The reader questions a block, you answer in the rail and, when the answer belongs in the document, revise the content and leave a short note saying what changed.

**The `Block` wrapper.** One top-level `const [comments, setComments] = useMorph({})` inside the page component (never at module scope: a hook declared outside a component both breaks the page on load and has no enclosing name to derive an identity from), keyed by block id, each value an array of `{ by, text }` (`by: "you"` for the reader, `by: "claude"` for your replies; nested arrays still round-trip as long as the whole initializer stays a JSON literal). Prefer the recipe form of the setter, `setComments(draft => { ... })`, over spreading a new object: mutating `draft` produces granular immer patches the CLI can rebase onto a concurrent edit, while `setComments({ ...comments, ... })` is a single root-replace patch that can silently lose one.

```jsx
const CommentsContext = React.createContext(null);

function Page() {
  const [comments, setComments] = useMorph({});
  const addComment = (id, text) =>
    setComments((draft) => {
      (draft[id] ||= []).push({ by: "you", text });
    });

  return (
    <CommentsContext.Provider value={{ comments, addComment }}>
      {/* ...blocks go here, e.g. <Block id="intro">...</Block> */}
    </CommentsContext.Provider>
  );
}

function Block({ id, children }) {
  const { comments, addComment } = React.useContext(CommentsContext);
  const thread = comments[id] || [];
  const [draft, setDraft] = useState("");
  const [open, setOpen] = useState(false);
  const send = () => {
    const t = draft.trim();
    if (t) addComment(id, t);
    setDraft("");
    setOpen(false);
  };
  return (
    <div className="cmt-row">
      <div className="cmt-body">{children}</div>
      <aside className="cmt-rail">
        {thread.map((c, i) => (
          <div
            key={i}
            className={c.by === "claude" ? "cmt-card claude" : "cmt-card"}
          >
            {c.text}
          </div>
        ))}
        {open ? (
          <>
            <textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
            />
            <button onClick={send}>Send</button>
          </>
        ) : (
          <button onClick={() => setOpen(true)}>
            {thread.length ? "+ reply" : "+ comment"}
          </button>
        )}
      </aside>
    </div>
  );
}
```

**Arm the watch loop after serving.** morph logs `mutate Page.comments` to its background output whenever the reader posts (your own file edits log `update`, not `mutate`, so they never echo back as false events). The same stream carries render health, so watch for `error` too:

```bash
tail -n0 -F <morph-background-output> | grep --line-buffered -E "mutate +Page\.comments|error +"
```

On an `error` event, fix the file until `ok     preview recovered` follows. On a `mutate` event, read the `.jsx` for the full thread, then edit the file: append a `{ by: "claude", text }` reply into that block's array, and/or revise the content and leave a short reply saying what you changed (the page hot-reloads and the reader sees it). If a claim is challenged, verify it (web search or the code) before answering, and correct the document rather than defend it. The watch lives only as long as this session, so tell the reader that, and stop it when they are done.
