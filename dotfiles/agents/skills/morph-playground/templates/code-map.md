# Code map playground

For visualizing codebase architecture: component relationships, data flow, layer diagrams, with per-node commenting for feedback. Follow `../SKILL.md` for the cross-cutting parts; the diagram toolkit (Graphviz or a measured SVG overlay) lives in `../../morph/SKILL.md`.

## Controls

| Decision           | Control                                                              |
| ------------------ | -------------------------------------------------------------------- |
| System view        | Preset buttons (Full System, Frontend Only, Backend Only, Data Flow) |
| Visible layers     | Toggle per layer (Client, Server, SDK, Data, External)               |
| Connection types   | Toggle per type, each with its color indicator                       |
| Component feedback | Click a node to open a comment affordance                            |
| Zoom               | +/−/reset                                                            |

## Connection-type taxonomy

Define 3-5 connection types, each a distinct line style plus a theme-aware color, so the filters and the diagram stay legible. Give each color a light and a dark value (per the morph theme rule); a default set:

| Type       | Line style | Light stroke          | Dark stroke           | Use for                         |
| ---------- | ---------- | --------------------- | --------------------- | ------------------------------- |
| data-flow  | solid      | #3b82f6 (blue-500)    | #60a5fa (blue-400)    | request/response, data passing  |
| tool-call  | dashed     | #10b981 (emerald-500) | #34d399 (emerald-400) | function calls, API invocations |
| event      | short dash | #ef4444 (red-500)     | #f87171 (red-400)     | async events, pub/sub           |
| dependency | dotted     | #6b7280 (gray-500)    | #9ca3af (gray-400)    | import/require relationships    |

## Layer palette

Fill nodes by layer so the bands read at a glance. Give each layer a light and a dark value (per the morph theme rule) and keep the node title and border legible on both. A default set:

| Layer    | Light fill           | Dark fill                 |
| -------- | -------------------- | ------------------------- |
| Client   | #dbeafe (blue-100)   | rgba(59, 130, 246, 0.18)  |
| Server   | #fef3c7 (amber-100)  | rgba(245, 158, 11, 0.18)  |
| SDK      | #f3e8ff (purple-100) | rgba(168, 85, 247, 0.18)  |
| Data     | #fce7f3 (pink-100)   | rgba(236, 72, 153, 0.18)  |
| External | #e2e8f0 (slate-200)  | rgba(148, 163, 184, 0.18) |

## Preview

A node/edge system diagram: nodes are rounded rectangles with a title and a file-path subtitle, organized in horizontal bands by layer; connections styled by the taxonomy above. A commented node gets a visible indicator. Include a legend in a corner of the diagram itself, mapping line styles to connection types and fills to layers; the control panel's color chips only help while the panel is in view.

## Pre-populate

15-25 real components (real file paths) plus 20-40 real connections from actual imports and calls, laid out in horizontal bands by layer. Presets as above (Full System / Frontend Only / Backend Only / Data Flow).

## Reading it back

The per-node comments are the payload: model them as one top-level `useMorph({})` keyed by node id (per `../SKILL.md`'s State section), written on each explicit comment, not per keystroke. Act on the committed config as the reader's per-component feedback against the system context, together with which layers were visible. Only include the components they actually commented on.

**Example.** A comment "add retry with backoff" on the `api-client` node (`src/api/client.ts`) becomes: "In `src/api/client.ts`, wrap the request path in retry-with-exponential-backoff; the reader flagged this while viewing the Client→Server data flow."

## Example topics

Codebase architecture explorer (modules, imports, data flow), microservices map (services, queues, databases, API gateways), React component tree (components, hooks, context, state), API architecture (routes, middleware, controllers, models), agent system (prompts, tools, skills, subagents), data pipeline (sources, transforms, sinks, scheduling).
