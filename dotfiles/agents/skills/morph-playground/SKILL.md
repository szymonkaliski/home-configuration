---
name: morph-playground
description: Creates an interactive playground as a morph page, a single-file React explorer with live controls and a live preview, served locally with hot reload. The reader's choices round-trip back to you through the file (useMorph). Use when the user asks to make a playground, explorer, or interactive tool for a topic.
---

# Morph Playground

A playground lets the user configure something visually: controls on one side, a live preview on the other. The user adjusts controls, explores, lands on a configuration, and that configuration round-trips back to you through the file, so you read their exact choices and act on them. This skill builds that as a morph page. First read `../morph/SKILL.md` (relative to this file) and follow it for authoring the file, serving, theme, and the `useMorph` state channel; everything below is what's specific to playgrounds.

**The morph difference.** Because this is a morph page, the reader's configuration **persists into the file** via `useMorph`. There is no prompt to copy and paste back: you read their exact choices straight from the `.jsx` and act on them. The whole loop is: reader configures, reader commits, you read the config from the file, you do the thing.

## When to use

When the user asks for an interactive playground, explorer, or visual tool for a topic, especially when the input space is large, visual, or structural and hard to express as plain text.

## Playground types

Identify the type from the request and shape the controls and preview accordingly. The reader's committed configuration always comes back to you through the file (see State), so each type below is about how you read that config and act on it:

- **Design** (components, layout, spacing, color, typography, animation): sliders / toggles / dropdowns / clickable layout cards → a live preview element styled from the state's inline styles, rendered on both a light and a dark surface (a context toggle) so contrast and shadows read on each. Act on the committed config as a direction to a developer, not a spec sheet.
- **Data / query** (SQL, API, regex, pipeline, cron, GraphQL): selectable chips for tables/fields, add-a-filter rows, per-row dropdowns → syntax-highlighted output (use `prism-react-renderer`, per the morph skill). Act on the committed config as a specification of what to build, carrying the schema context (table and column types), not the raw query.
- **Concept map / learning** (concepts, knowledge gaps, scope, task decomposition): draggable nodes and reader-drawn edges on an SVG canvas, per-node knowledge level (know → fuzzy → unknown). The committed config names what they know, are fuzzy on, and don't know, plus the relationships they drew; act on it as a targeted learning request.
- **Document critique / diff review** (review content with approve / reject / comment): render the document or diff, attach to each suggestion or hunk a per-item verdict (approve / reject) with a comment affordance and a category tag (clarity, completeness, performance, accessibility, ux), plus filter-by-status with counts. Generate the suggestions yourself by analyzing the real document or diff up front (see Pre-populate). The verdicts and comments are the payload.
- **Code map** (architecture, data flow, layers): a node/edge system diagram (use the morph diagram toolkit: Graphviz or measured SVG overlay), layer/connection-type filters, per-node comments. The committed config is the reader's per-component feedback against the system context; act on it directly.

If the topic doesn't fit a type cleanly, use the closest and adapt.

## Controls

Pick the control that fits the decision:

| Decision                    | Control                                                                           |
| --------------------------- | --------------------------------------------------------------------------------- |
| Size, spacing, radius       | Slider                                                                            |
| On/off feature              | Toggle                                                                            |
| One choice from a set       | Dropdown, or clickable cards for structural choices (layout, easing curve)        |
| Color                       | Hue / saturation / lightness sliders                                              |
| Responsive behavior         | Viewport-width slider that reflows the preview                                    |
| Select from available items | Clickable chips or cards (tables, columns, methods)                               |
| Add a filter or condition   | An "Add" button that appends a row of dropdowns plus an input (column, op, value) |
| Join type or aggregation    | Dropdown per row                                                                  |
| Ordering                    | Dropdown plus an ASC/DESC toggle                                                  |
| Limit or count              | Slider                                                                            |

## Pre-populate with real data

A playground that opens on the reader's actual material beats a blank one, and the read-back loop only pays off when there is something real to configure. Before serving, seed the initial state from the real thing:

- **Concept map:** 15-20 real nodes with real file paths, plus 20-30 real edges from the actual architecture; default every node's knowledge level to fuzzy so the reader adjusts from there.
- **Code map:** 15-25 real components (real file paths) plus 20-40 real connections, laid out in horizontal bands by layer.
- **Document critique:** read the actual document, generate the suggestions yourself with real line references and category tags, and embed them as the initial state.
- **Diff review:** `git show <commit> -p` (or the branch or PR diff), parsed into the hunks the page renders.
- **Design / data:** defaults that already look good, and 3-5 presets that each snap all controls to a cohesive combination.

## Core requirements (every playground)

- **Single `.jsx` morph page** (per the morph skill), default export. Two-panel layout: controls on one side, live preview on the other, and a commit action ("Use this" / "Send to Claude") beneath the preview that writes the current controls into the round-tripping config. Responsive: stack the panels on a narrow screen.
- **Live preview.** Updates instantly on every control change. No "Apply" button.
- **Sensible defaults + presets.** Looks good on first load. Include 3-5 named presets that snap all controls to a cohesive combination.
- **Theme follows the reader's device** (per the morph skill: do **not** hardcode a dark theme; these open on phones over the LAN). System font for UI, monospace for code and values. Minimal chrome.

## State: live controls vs. what round-trips

This is the morph-specific design decision. Split state deliberately, following the morph State channel rules:

- **Ephemeral control state** lives in plain `useState`: slider positions, hover, which group is expanded. It drives the live preview, but it does not need to round-trip, so keep it out of `useMorph` (churning the file on every slider tick reformats it constantly).
- **The configuration you want to read back** lives in **one top-level `useMorph`** with a JSON-literal initializer: the committed config the reader has landed on. Give an explicit **"Use this" / "Send to Claude"** action that writes the current controls into it. When the reader clicks it, morph rewrites the initializer and logs `mutate  Playground.config`; you read the `.jsx` for the exact values.
  - For review-style playgrounds (document critique, diff review, code map comments), the per-item verdicts and comments **are** the round-tripping payload: model them as one top-level `useMorph({})` keyed by item id, written on each explicit decision (not per keystroke).

```jsx
const DEFAULTS = { radius: 8, padding: 16, shadow: "medium" };

function Playground() {
  const [draft, setDraft] = useState(DEFAULTS); // ephemeral live controls
  const [config, setConfig] = useMorph(DEFAULTS); // persists → you read it back
  const commit = () => setConfig(draft); // "Use this" button
  // preview renders from `draft`; `config` is what you pick up on commit
  // ...
}
```

## Serving and the read-back loop

- Serve with `morph` as a background process; report the URL (both the `localhost:<port>` and `<hostname>:<port>` forms, per the morph skill); never `open`.
- Because the config round-trips, watch morph's output for the commit and pick it up without being asked:

  ```bash
  tail -n0 -F <morph-background-output> | grep --line-buffered "mutate  Playground.config"
  ```

  On that event, read the `.jsx`, take the reader's exact configuration, and do the work they set up, no copy-paste required. Tell the reader to click "Use this" when they've landed on a configuration and you'll pick it up here. The watch lives only for this session; stop it when they're done.

## Common mistakes to avoid

- Opening on a blank or fake canvas → pre-populate from the reader's real material (see Pre-populate).
- Too many controls at once → group by concern, and lay advanced ones out below the primary ones (still visible, don't gate behind a collapse unless the list is genuinely long).
- Preview doesn't update instantly → every control change must re-render immediately.
- No defaults or presets → starts empty or broken on load.
- Hardcoding a dark theme → follow the device (per the morph skill).
- Writing to `useMorph` on every keystroke or slider tick → commit on an explicit action, so the file isn't rewritten and reformatted constantly.
- The round-tripping config must stay a **JSON literal** → a computed initializer silently won't round-trip (per the morph State channel).
