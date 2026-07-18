# Concept map / learning playground

For learning, exploration, and mapping relationships: concept maps, knowledge-gap identification, scope mapping, task decomposition with dependencies. The interactive canvas IS the control (the reader drags nodes and draws edges); a sidebar supplements with toggles and lists. Follow `../SKILL.md` for the cross-cutting parts; the canvas/SVG toolkit lives in `../../morph/SKILL.md`.

## Controls

| Decision                 | Control                                                                          |
| ------------------------ | -------------------------------------------------------------------------------- |
| Knowledge level per node | Click-to-cycle in the sidebar list (know → fuzzy → unknown)                      |
| Connection type          | Selector chosen before drawing an edge (calls, depends on, contains, reads from) |
| Node arrangement         | Drag on the canvas (spatial layout reflects the reader's mental model)           |
| Which nodes to include   | Toggle per node                                                                  |
| Actions                  | Buttons: force-directed auto-layout, clear edges, reset                          |

## Preview

Draggable nodes and reader-drawn edges on an SVG canvas, with a tooltip (description) on hover. Drawing an edge is two clicks: click node A, then node B, and the edge appears with the currently selected connection type. Draw edges under nodes. Force-directed auto-layout is a simple spring simulation: repulsion between all pairs, attraction along edges, iterate 100-200 times with damping.

## Pre-populate

15-20 real nodes with real file paths and short descriptions, plus 20-30 real edges from the actual architecture. Default every node's knowledge level to fuzzy so the reader adjusts from there. Presets: "Zoom out" (hide internal nodes, show only top-level), "Focus on [layer]" (highlight one area).

## Reading it back

Two things round-trip via `useMorph`, each keyed by id and written the moment the reader acts (a cycle-click, an edge finished) rather than gated behind a separate commit step: every node's knowledge level (know / fuzzy / unknown) and the edges the reader drew, each with its connection type. Dragged node positions stay in plain `useState`: they're the reader's own spatial arrangement, not content you need back, so they never enter the file. Act on the persisted state as a targeted learning request: explain the fuzzy and unknown concepts along the edges they care about, building on what they already know, with concrete code references. Only mention the edges they drew and the concepts they didn't already mark as known.

**Example.** With `useState` marked known, `useReducer` fuzzy, `Context` unknown, and an edge `Context --provides--> useReducer`, you'd explain: "You know `useState`; `useReducer` is the same idea for state with many transitions. `Context` (which you flagged unknown) is how a reducer's `dispatch` reaches deep children without prop-drilling, wired up in `store.tsx`." You'd skip `useState` entirely since they already know it.

## Example topics

Codebase architecture map (modules, data flow, state management), framework learning (how React hooks connect, Next.js data-fetching layers), system design (services, databases, queues, caches and how they relate), task decomposition (goals → sub-tasks with dependency arrows and knowledge tags), API surface map (endpoints grouped by resource, shared middleware, auth layers).
