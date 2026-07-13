# Design playground

For visual design decisions: components, layout, spacing, color, typography, animation, responsive behavior. Follow `../SKILL.md` for the cross-cutting parts (state split, commit, serving, common mistakes); this file is the design-specific shape. Diagram and code-block mechanics live in `../../morph/SKILL.md`.

## Controls

| Decision                            | Control                                                                    |
| ----------------------------------- | -------------------------------------------------------------------------- |
| Size, spacing, radius               | Slider                                                                     |
| On/off feature (border, hover lift) | Toggle                                                                     |
| One choice from a set               | Dropdown, or clickable cards for structural choices (layout, easing curve) |
| Color                               | Hue / saturation / lightness sliders                                       |
| Responsive behavior                 | Viewport-width slider that reflows the preview                             |

## Preview

A live element styled from the draft state's inline styles, rendered on both a light and a dark surface (a context toggle) so contrast and shadows read on each. Updates on every control change, no "Apply".

## Pre-populate

Defaults that already look good on first load, plus 3-5 named presets that each snap all controls to a cohesive combination (for example "Soft", "Sharp", "Dense", "Airy").

## Reading it back

Act on the committed config as a direction to a developer, not a spec sheet. If the reader works in Tailwind, hand back Tailwind classes; if raw CSS, CSS properties.

**Example.** From `{ radius: 12, padding: 24, shadow: "medium", hoverLift: true }` you'd write: "Give the card a soft, elevated feel — 12px corner radius, 24px horizontal padding, a medium shadow (`0 4px 12px rgba(0,0,0,0.1)`), and on hover lift it with `translateY(-1px)` and deepen the shadow. In Tailwind: `rounded-xl px-6 shadow-md hover:-translate-y-px hover:shadow-lg`."

## Example topics

Button style explorer (radius, padding, weight, hover/active states), card component (shadow depth, radius, content layout, image), layout builder (sidebar width, content max-width, header height, grid), typography scale (base size, ratio, line heights across h1-body-caption), color palette generator (primary hue derives secondary/accent/surface), dashboard density (one airy-to-compact slider that scales everything proportionally), modal/dialog (width, overlay opacity, entry animation, corner radius).
