---
name: explain
description: Use when the user asks for a rich explanation of a topic, system, project architecture, or comparison of concepts. Produces a single-file React explainer page served locally with hot reload. For a code change, diff, branch, or PR, use explain-diff instead.
---

# Explain

Make a rich, interactive explanation of the specified subject.

## Arguments

`$ARGUMENTS` names the subject: a system or project (or part of one, like "this project's architecture"), a mechanism, a concept, or a comparison ("X vs Y"). It doesn't have to relate to the current directory.

## Grounding

- Claims about code must trace to files you have actually read; explore the codebase before writing about it.
- For external subjects, check documentation or search the web where you aren't certain; don't present recollection as fact.

## Sections

- **Background**: the context needed to follow the rest. We don't know how much the reader already knows, so include a deep background for beginners (noting it can be skipped if the reader is already familiar), and then a narrower background directly relevant to the subject.
- **Intuition**: the core essence, not the full details. Use concrete examples with toy data. Use figures and diagrams liberally.
- **The substance**: one or more sections shaped by the subject: an architecture explained layer by layer, a comparison walked dimension by dimension with both sides on screen, a mechanism traced end to end. Group and order by concept, in the order that builds understanding.

## Interactive explainers

Everything must be visible at once. Never hide content behind steppers, tabs, toggles, sliders, or collapsed sections; interactivity adds understandability on top of fully visible content, it never gates it.

When explaining behavior (an algorithm, a protocol, a pipeline, a policy), structure the explainer as a ladder of abstraction (Bret Victor), with every rung on the page at once. Time and parameters become space on the page, never a control the reader has to operate:

1. **Ground level, one concrete run**: specific toy data flowing through the system. Show the inside, not just the interface: variables, queue contents, intermediate values at each point. If the reader can't see the internal state, they're watching the system through a keyhole.
2. **Abstract over time**: the whole run as one picture. Lay out every state as its own small annotated diagram, a film strip down the page; when comparing two designs or behaviors, run them as parallel strips over the same data.
3. **Abstract over inputs**: a grid of outcomes across representative inputs or parameter values, each cell summarizing an entire run, compared variants as parallel rows. This is where high-level patterns show: the threshold where behavior flips, the class of cases where the variants diverge.

The insight lives in the transitions between rungs, so keep them adjacent and connected: annotate the interesting cells of the outcome grid (the boundary case, the surprising divergence) and show their full concrete runs nearby. Never present an abstract summary without at least one fully worked concrete example next to it; stepping down the ladder matters as much as stepping up. A small subject may only need the ground rung; add rungs only while they keep earning their place.

Interactive devices on top of this, all additive:

- **Side by side instead of toggles**: compared variants both on screen, always. If a tunable value matters (timeout, threshold, buffer size), show a row of examples at representative values instead of a slider.
- **Linked highlighting**: the primary interactive device. Hovering a term in the prose highlights the matching diagram node, code line, film-strip frame, or grid cell, and vice versa; hovering a grid cell emphasizes the concrete run it summarizes. Dim unrelated parts while hovering, but never remove them. Budget one highlight color per concept.
- **Hover emphasis on diagrams**: hovering a component strengthens its connections and fades the rest; the resting state must already show everything.
- **Margin comments**: every explainer carries a comment rail down the right margin (see State channel). Each block has an affordance to leave a comment or question; it gates nothing, so it stays within "everything visible at once". This is how the reader talks back and how the doc gets refined, so build it into every page, not just ones that seem to invite discussion.

Implementation: one top-level `hovered` state (React context) naming the active concept; prose terms, code lines, diagram nodes, and grid cells tag themselves with a concept id and derive their emphasis/dimming classes from it. The resting render, before any interaction, must already show the complete explanation; interaction only adds emphasis.

## Diagrams and charts

Pick a small number of diagram families and reuse them throughout the explanation to cover the various cases. Useful kinds: a very simplified version of the UI the user sees, to explain UI behavior; a system diagram showing data flow or communication between components (always include example data). Never ASCII diagrams.

- **Box-and-arrow architecture diagrams**: for plain graphs (dependencies, call flow, pipelines), write Graphviz dot and render it with `@viz-js/viz` (the `Graph` component under Output, injected via `dangerouslySetInnerHTML`); a real layout engine solves node placement, which is exactly what generated diagrams get wrong by hand. When nodes need rich HTML content, annotations, or linked highlighting, build the boxes as plain HTML (flexbox/grid) instead and draw connectors in one absolutely positioned SVG overlay whose endpoints you measure from refs with `getBoundingClientRect()` in a `useLayoutEffect` (re-measure on window resize). Never hand-guess SVG coordinates for arrows; gaps, arrows missing their boxes, and overlapping labels are how generated diagrams break. Define the arrowhead once in `<defs><marker>` and reference it with `marker-end`, and prefer straight or orthogonal connectors over beziers.
- **Sequence / data-flow diagrams**: CSS grid swimlanes, one column per actor, one row per time step, lifelines as borders spanning the rows. Cross-lane arrows use the same measured SVG overlay.
- **Charts**: CSS-only bar charts (div sizes from percentages, real HTML text for labels) when a bar chart suffices; hand-rolled inline SVG with `<rect>`/`<polyline>`/`<line>` when you need axes or a line chart. Use a round-number `viewBox` decoupled from `width="100%"`, keep coordinates on a coarse grid. Reach for a chart library via esm.sh only when the data genuinely needs one (many series, brushing, log scales); no canvas.
- **Text in SVG**: avoid it, SVG doesn't wrap text. Keep labels as HTML overlaid on or next to the SVG, reserving SVG for geometry.
- **Animation**: CSS transitions/keyframes driven by class toggles from JS: emphasize the hovered concept, move a request token through a pipeline, draw a connector on with `stroke-dashoffset`. Animate to show state change or causality, never as decoration, and keep the diagram fully legible when nothing is animating.

## Output

- A single `.jsx` file whose **default export** is the page component. One long page with section headers and a table of contents. Don't use tabs for the top-level structure. Basic responsive styling so it reads well on a phone.
- All React APIs (`useState`, `useRef`, `useEffect`, `useMemo`, `useLayoutEffect`, `use`, `Suspense`, `React` itself, ...) are already in scope in the preview; don't import them. `useState` holds ephemeral state; the ambient `useMorph` hook (also no import) persists reader-authored state into the document and is the channel you read and write through the file (see below).
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
- **Theme**: follow the reader's device light/dark setting; never hardcode one. These pages are served on every interface, so they're opened over the LAN or Tailscale on whatever device the reader has (often a phone, dark at night), and should match it. With the Play CDN this is just `dark:` variants: it defaults to the `media` strategy, so `dark:` tracks the device's `prefers-color-scheme` automatically, with no config or toggle. The page background is the one thing utilities can't set, since `html, body` live outside the React tree: set it on `html, body` in the `<style>` block (not just a content card, or the preview's white outer shell leaks at the page edges and on overscroll in dark mode) with a `@media (prefers-color-scheme: dark)` override that mirrors your `dark:` classes. Both modes must stay legible, which is the real work: give a light and a dark value to every color that carries meaning, including the per-concept highlight palette, diagram node fills, and the `prism-react-renderer` theme (pick `themes.vsDark`/`themes.vsLight` off `matchMedia('(prefers-color-scheme: dark)')`). No manual toggle: it tracks the system, in keeping with the no-hidden-interactivity rule.
- Write the file to `./tmp/` in the project root (create it if it doesn't exist; it's globally gitignored). Prefix the filename with today's date so files stay time-sorted: `./tmp/YYYY-MM-DD-explanation-<slug>.jsx`.

## Serving

Serve the file with `morph`, as a background process since it runs indefinitely. Never call `open`; tell the user the URL and let them open it themselves:

```bash
morph "./tmp/YYYY-MM-DD-explanation-<slug>.jsx"
```

- One server previews exactly one file. Without `--port` it takes the first free port from 3000 upward; read the printed `ready  previewing <file> at http://localhost:<port>` line for the actual URL. (An explicit `--port` fails fast if the port is busy.)
- Every save hot-reloads the page with Fast Refresh, and the reader's state survives every edit for as long as the server runs: `useState` is preserved across the reload, and `useMorph` values live in the document itself. So iterate by editing the file in place and keep the same server running for the whole session. Editing a `useState` initializer resets that one hook; editing a `useMorph` initializer is how you push a new value to the reader (the page reloads and adopts it, see State channel).
- morph reformats the whole file with Prettier on every change (yours or the reader's), so keep the document Prettier-clean; your own edits get normalized too.
- **Do not verify that the page renders. Make the edit and move on.** This is the single biggest time-sink to avoid. Do **not** run `esbuild`/`tsc`/`prettier`, do **not** re-open or refresh a client "to check for errors", do **not** screenshot the page to confirm it looks right, and do **not** poll morph's output to confirm a render succeeded (an `update` line with no `error` after it is *not* a signal worth waiting for). The reader is looking at the live page, and morph shows any transpile or runtime error as an overlay *in that page*, so a genuinely broken edit is surfaced to the reader, who will tell you; it is not something you discover by inspecting. morph also reformats with Prettier on every save, so never run Prettier yourself either. Trust your edit and spend the effort on the explanation, not on confirming pixels. (morph's output is still worth watching for exactly one thing, reader comments, see the watch loop below, never for render confirmation.)
- Tell the user the URL. The `ready` line prints `http://localhost:<port>`, but the server binds every interface, so it's equally reachable at `http://<hostname>:<port>` (`hostname -s`) over the LAN or Tailscale; offer that form too when the reader might open it on another device like a phone.

## State channel

morph has no HTTP state endpoint. The document's own source is the state: an ambient `useMorph(initial)` hook (a `useState` you don't import) whose **initializer literal is rewritten in the file** when the reader interacts. That is the whole channel, both directions:

- **screen → you.** When the reader changes a `useMorph` value (types a question, picks a quiz answer), morph rewrites that initializer in the `.jsx` file and logs a `mutate  Component.variable` line followed by a colored word-level diff of exactly what changed (capped at 30 lines). The server runs in the background, so watch its output to see reader activity as it happens; read the `.jsx` file when you need the full current value.
- **you → screen.** To respond to a comment, seed a value, or reset a hook, edit its `useMorph` initializer in the file. morph pushes the new source to the page, which hot-reloads and adopts the new literal (your edit rebases cleanly onto a concurrent reader edit of the same value).

Design for it:

- **Persist only what should round-trip.** Use `useMorph` for reader-authored content you want to read back (comments, questions, quiz choices); use plain `useState` for ephemeral emphasis (`hovered`, open/closed UI) so hovering doesn't churn the file. Only a **top-level** `useMorph` with a **JSON-literal** initializer persists: a `useMorph(makeDefault())`, or one inside a `.map()` (one initializer, many mounts), stays in-memory only and silently won't round-trip.
- **One top-level hook per collection, keyed by id.** Model per-section comments as a single top-level `useMorph({})` object keyed by section id (`comments[id]`), not a `useMorph` per rendered item. Each mutation logs under the identity `Component.variable` (enclosing component name + destructured variable), so name them deliberately (`Explainer.comments`, not `C.v`) to keep the log legible.
- **This is how the reader talks back.** Every block carries a margin comment rail (see Reader comments and the watch loop below). Hold the in-progress text in a local `useState` and push to `comments[id]` only on an explicit Send, never per keystroke, so a long comment doesn't rewrite and reformat the file as it is typed.
- **The reverse direction works too.** Edit the file to clear a reader's comment (`comments[id] = ""`), seed or correct a value, or reset a hook to its default; the page reloads and adopts it.

## Reader comments and the watch loop

Every explainer ships with a margin comment rail, and you watch for comments and respond as they arrive, for as long as the session runs. This is the loop by which feedback flows into the docs: the reader questions a paragraph, you answer in the rail and, when the answer belongs in the doc, revise the explanation and leave a short note saying what changed. It is additive and gates nothing, so it does not break "everything visible at once".

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

**Arm the watch loop after serving.** morph logs `mutate  Explainer.comments` to its background output whenever the reader posts (your own file edits log `update`, not `mutate`, so they never echo back as false events). Start a persistent monitor on that output so each new comment notifies you without the user having to ask:

```bash
tail -n0 -F <morph-background-output> | grep --line-buffered "mutate  Explainer.comments"
```

On each event, read the `.jsx` for the full thread, then edit the file: append a `{ by: "claude", text }` reply into that block's array, and/or revise the explanation and leave a short reply saying what you changed (the page hot-reloads and the reader sees it). If a claim is challenged, verify it (web search or the code) before answering, and correct the doc rather than defend it. The watch lives only as long as this session, so tell the reader that, and stop it when they are done.

## Writing style

- Write with the clarity and flow of Martin Kleppmann, engaging and in classic style. Transitions between sections should be smooth.
- Use HTML lists for lists of things, real markup over walls of prose.
- Code blocks must keep their source in a template literal: ``<pre>{`...`}</pre>``. JSX collapses whitespace in literal text, so code written as plain JSX text loses its newlines. Escape backticks and `${` inside the sample. Before saving, scan every code block and confirm it uses this form. Syntax-color code blocks with `prism-react-renderer` (the source string still lives in a template literal).
- Use callouts for key concepts or definitions, important edge cases, etc.
