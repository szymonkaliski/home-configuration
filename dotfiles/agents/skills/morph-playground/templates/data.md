# Data / query playground

For data queries, APIs, pipelines, or structured configuration: SQL builders, API designers, regex builders, pipeline visuals, cron schedules, GraphQL. Follow `../SKILL.md` for the cross-cutting parts; mechanics (syntax highlighting, diagrams) live in `../../morph/SKILL.md`.

## Controls

| Decision                                           | Control                                                                           |
| -------------------------------------------------- | --------------------------------------------------------------------------------- |
| Select from available items                        | Clickable chips or cards (tables, columns, HTTP methods)                          |
| Add a filter or condition                          | An "Add" button that appends a row of dropdowns plus an input (column, op, value) |
| Join type or aggregation                           | Dropdown per row (INNER/LEFT/RIGHT, COUNT/SUM/AVG)                                |
| Ordering                                           | Dropdown plus an ASC/DESC toggle                                                  |
| Limit or count                                     | Slider                                                                            |
| On/off feature (include header, show descriptions) | Toggle                                                                            |

## Preview

Syntax-highlighted output built from the draft state (use `prism-react-renderer`, per the morph skill). For a pipeline-style playground, render a horizontal or vertical flow diagram with the morph diagram toolkit instead.

## Pre-populate

Defaults that already produce a valid query or config, plus 3-5 presets that snap to a cohesive combination. Seed with the reader's real schema (table and column names and types) when you have it.

## Reading it back

Act on the committed config as a specification of what to build, carrying the schema context (table and column types), not the raw query string. That keeps the request actionable without the playground.

**Example.** From a config joining `orders` to `users` on `user_id`, filtered to `created_at > '2024-01-01'` and `total > 50`, grouped by user, ordered by order count descending, limit 10, you'd write: "Write a SQL query against `orders(user_id, total, created_at)` and `users(id, name)` returning the top 10 users by order count for orders since 2024-01-01 over $50."

## Example topics

SQL query builder (tables, joins, filters, group by, order by, limit), API endpoint designer (routes, methods, request/response fields), data transformation pipeline (source → filter → map → aggregate → output), regex builder (sample strings, match groups, live highlight), cron schedule builder (visual timeline, interval, day toggles), GraphQL query builder (type selection, field picker, nested resolvers).
