# Document critique playground

For reviewing and critiquing prose documents with an approve / reject / comment workflow: SKILL.md files, READMEs, specs, proposals. You generate the suggestions up front by analyzing the real document; the reader's verdicts and comments are the payload. Follow `../SKILL.md` for the cross-cutting parts.

## Controls

| Decision               | Control                                                                    |
| ---------------------- | -------------------------------------------------------------------------- |
| Verdict per suggestion | Approve / Reject buttons on the suggestion card (Reset if already decided) |
| Comment                | Textarea on the card                                                       |
| Filter                 | Tabs: All / Pending / Approved / Rejected, with counts                     |

## Preview

The document with line numbers on one side; a filterable suggestions panel on the other. Highlight lines that carry a suggestion with a colored left border, keyed to status: pending amber, approved green, rejected red and de-emphasized (drop its opacity so decided-against items recede). Give each a light and a dark value, per the morph theme rule. Clicking a card scrolls to its line.

## Pre-populate

Read the actual document and generate the suggestions yourself, each with a real line reference, actionable text, and a category tag (clarity, completeness, performance, accessibility, ux). Embed them as the initial state.

## Reading it back

Model the verdicts and comments as one top-level `useMorph({})` keyed by suggestion id (per `../SKILL.md`'s State section), written on each explicit decision, not per keystroke. Act only on the approved suggestions and any the reader commented on; treat rejected ones as context.

**Example.** Suggestion #3 ("shorten the description") approved with the note "keep the trigger list" becomes: "Tighten the `description` per suggestion #3, but preserve the trigger enumeration the reader called out." A rejected suggestion you leave in place, mentioning it only if it explains why you didn't make a related change.

## Example topics

SKILL.md review (definition quality, completeness, clarity), README critique (missing sections, unclear explanations), spec review (requirements clarity, missing edge cases, ambiguity), proposal feedback (structure, argumentation, missing context), code-comment review (docstring quality, inline-comment usefulness).
