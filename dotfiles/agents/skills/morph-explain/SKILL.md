---
name: morph-explain
description: Use when the user asks for a rich explanation of a topic, system, project architecture, or comparison of concepts. Produces a single-file React explainer page served locally with hot reload (morph). For a code change, diff, branch, or PR, use morph-diff instead.
---

# Morph Explain

Make a rich, interactive explanation of the specified subject as a morph page. First read `../morph/SKILL.md` (relative to this file) and follow it for authoring the file, serving, the `useMorph` state channel, the diagram/chart toolkit, and the reader comment rail; everything below is only what's specific to explanations.

## Arguments

`$ARGUMENTS` names the subject: a system or project (or part of one, like "this project's architecture"), a mechanism, a concept, or a comparison ("X vs Y"). It doesn't have to relate to the current directory.

## Grounding

- Claims about code must trace to files you have actually read; explore the codebase before writing about it.
- For external subjects, check documentation or search the web where you aren't certain; don't present recollection as fact.

## Sections

- **Background**: the context needed to follow the rest. We don't know how much the reader already knows, so include a deep background for beginners (noting it can be skipped if the reader is already familiar), and then a narrower background directly relevant to the subject.
- **Intuition**: the core essence, not the full details. Use concrete examples with toy data. Use figures and diagrams liberally (the rendering toolkit is in the morph skill).
- **The substance**: one or more sections shaped by the subject: an architecture explained layer by layer, a comparison walked dimension by dimension with both sides on screen, a mechanism traced end to end. Group and order by concept, in the order that builds understanding.

The page is one long page with section headers and a table of contents. Don't use tabs for the top-level structure.

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
- **Margin comments**: every explainer carries the comment rail down the right margin (the `Block` wrapper and watch loop are in the morph skill; here they are **required**, not optional). Each block has an affordance to leave a comment or question; it gates nothing, so it stays within "everything visible at once". This is how the reader talks back and how the doc gets refined, so build it into every page, not just ones that seem to invite discussion.

Implementation: one top-level `hovered` state (React context) naming the active concept; prose terms, code lines, diagram nodes, and grid cells tag themselves with a concept id and derive their emphasis/dimming classes from it. The resting render, before any interaction, must already show the complete explanation; interaction only adds emphasis.

## Writing style

- Write with the clarity and flow of Martin Kleppmann, engaging and in classic style. Transitions between sections should be smooth.
- Use HTML lists for lists of things, real markup over walls of prose.
- Syntax-color code blocks with `prism-react-renderer` (the source string still lives in a template literal, per the morph skill's code-block rule).
- Use callouts for key concepts or definitions, important edge cases, etc.
