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

Identify the type from the request, then read the matching file under `templates/` (relative to this file) and follow it for that type's controls, preview, pre-populate guidance, and example topics. Everything else in this SKILL is cross-cutting and applies to every type. The reader's committed configuration always comes back to you through the file (see State).

- **Design** (components, layout, spacing, color, typography, animation) → `templates/design.md`
- **Data / query** (SQL, API, regex, pipeline, cron, GraphQL) → `templates/data.md`
- **Concept map / learning** (concepts, knowledge gaps, scope, task decomposition) → `templates/concept-map.md`
- **Code map** (architecture, data flow, layers, per-node feedback) → `templates/code-map.md`
- **Document critique** (approve / reject / comment on prose suggestions) → `templates/document-critique.md`
- **Diff review** (line-level comments on a git diff) → `templates/diff-review.md`

If the topic doesn't fit a type cleanly, use the closest and adapt.

## Core requirements (every playground)

- **Single `.jsx` morph page** (per the morph skill), default export. Two-panel layout: controls on one side, live preview on the other, and a commit action ("Use this" / "Send to Claude") beneath the preview that writes the current controls into the round-tripping config and confirms it visibly (a brief "Sent ✓ - Claude will pick this up"), since the write lands in the file where the reader can't see it. Beside the commit action, render a live one-or-two-sentence plain-language summary of the current draft (only non-default choices, in qualitative words: "a pronounced shadow", not `shadow: 24`); it updates as the controls move, so the reader checks what they're about to send before committing. Responsive: stack the panels on a narrow screen. (The canvas types, concept map and code map, put the interactive visual center-stage with a supplementary sidebar instead, see their templates.)
- **Live preview.** Updates instantly on every control change. No "Apply" button.
- **Sensible defaults + presets.** Looks good on first load. For exploratory playgrounds (design, data/query, concept map, code map), include 3-5 named presets that snap all controls to a cohesive combination; this doesn't apply to the single-subject review templates (document critique, diff review), which review one specific document or diff rather than explore a space, so presets aren't meaningful there.
- **Theme follows the reader's device** (per the morph skill: do **not** hardcode a dark theme; these open on phones over the LAN). System font for UI, monospace for code and values. Minimal chrome.

## State: live controls vs. what round-trips

This is the morph-specific design decision. Split state deliberately, following the morph State channel rules:

- **Ephemeral control state** lives in plain `useState`: slider positions, hover, which group is expanded. It drives the live preview, but it does not need to round-trip, so keep it out of `useMorph` (churning the file on every slider tick reformats it constantly).
- **The configuration you want to read back** lives in **one top-level `useMorph`** with a JSON-literal initializer: the committed config the reader has landed on. Give an explicit **"Use this" / "Send to Claude"** action that writes the current controls into it. When the reader clicks it, morph rewrites the initializer and logs `mutate Playground.config`; you read the `.jsx` for the exact values. The live summary (per Core requirements) renders from the same draft this action writes, so what the reader checked is exactly what commits.
  - For review-style playgrounds (document critique, diff review, code map comments), the per-item verdicts and comments **are** the round-tripping payload: model them as one top-level `useMorph({})` keyed by item id, written on each explicit decision (not per keystroke).

```jsx
const DEFAULTS = { radius: 8, padding: 16, shadow: "medium" };

function Playground() {
  const [draft, setDraft] = useState(DEFAULTS); // ephemeral live controls
  const [config, setConfig] = useMorph(null); // literal initializer, null until committed
  const commit = () => setConfig(draft); // "Use this" writes draft into the file
  // preview renders from `draft`; on commit, config's initializer in the file
  // becomes the committed values, which is what you read back
}
```

**The `useMorph` initializer must be a JSON literal** (`null` here), never a variable: `useMorph(DEFAULTS)` is non-literal, so the reader's commit is refused (the CLI logs a `skip` line, `non-literal initializer`, and the page rolls the commit back with a `change rejected` badge). Start from `null` or inline the literal, don't alias it.

## Serving and the read-back loop

- Serve with `morph` as a background process; report the URL (both the `localhost:<port>` and `<hostname>:<port>` forms, per the morph skill); never `open`.
- Because the config round-trips, watch morph's output for the commit and pick it up without being asked. Grep for `mutate` scoped to whatever you actually named the round-tripping hook, not a hard-coded name: `Playground.config` for a single committed config, or the per-item hook's own name (for example `Playground.verdicts` or `Playground.comments`) for the review-style playgrounds in State above. Also grep for `skip` and `error` so refusals and failures surface too, not just successful commits:

  ```bash
  tail -n0 -F <morph-background-output> | grep --line-buffered -E "mutate +Playground\.<your-hook-name>|skip +|error +"
  ```

  (A `skip` line means the CLI refused the commit, most often a non-literal `useMorph` initializer; per the morph skill this rolls the reader's edit back with a `change rejected` badge. An `error` line means an edit broke the preview; fix the file until `ok     preview recovered` follows, per the morph skill.)

  On that event, read the `.jsx`, take the reader's exact configuration, and do the work they set up, no copy-paste required. Tell the reader to click "Use this" when they've landed on a configuration and you'll pick it up here. The watch lives only for this session; stop it when they're done.

- **Act on the delta, not the dump.** When you pick up the committed config, act on what the reader changed from the defaults, not every field; turn raw numbers into qualitative direction ("a pronounced shadow", not just `shadow: 24`); and rely only on context the config itself carries, so what you produce stands on its own. Each type's `templates/` file says what "acting on it" means for that type (a direction to a developer, a spec to build, a learning request).

## Common mistakes to avoid

- Opening on a blank or fake canvas → pre-populate from the reader's real material (see the type's `templates/` file).
- Too many controls at once → group by concern, and lay advanced ones out below the primary ones (still visible, don't gate behind a collapse unless the list is genuinely long).
- Preview doesn't update instantly → every control change must re-render immediately.
- No defaults or presets → starts empty or broken on load.
- Hardcoding a dark theme → follow the device (per the morph skill).
- Writing to `useMorph` on every keystroke or slider tick → commit on an explicit action, so the file isn't rewritten and reformatted constantly.
- The round-tripping config must stay a **JSON literal** → a computed initializer won't round-trip; the commit is rejected and rolled back in front of the reader (per the morph State channel).
