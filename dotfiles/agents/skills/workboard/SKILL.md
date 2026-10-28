---
name: workboard
description: Interactive morph dashboard for planning, project tracking, design discussions, and diff review.
argument-hint: [<morph-file-or-slug> | <topic, plan, or git-range>]
disable-model-invocation: true
---

# Workboard

A workboard is a single-file `morph` page (`./tmp/YYYY-MM-DD-<slug>.morph.jsx`) for planning complex work, tracking tasks, discussing decisions, and reviewing diffs. Invoke the `morph` skill first for serving (`morph ./tmp`), arming the persistent `Monitor`, and `useMorph` edit rules.

## 1. Initialize the board

The workboard template lives in `${CLAUDE_SKILL_DIR}/scaffold.jsx`. Its data and `useMorph` hooks sit at the top of the file, above the `UI TOOLKIT` banner.

1. **Create or open the board file.** For a new board, `mkdir -p ./tmp` and copy `${CLAUDE_SKILL_DIR}/scaffold.jsx` to `./tmp/YYYY-MM-DD-<slug>.morph.jsx`. For an existing board, edit `./tmp/<board>.morph.jsx` in place so reader mutations stay intact.
2. **Populate top-level data and state.** Edit only the section above the `UI TOOLKIT` banner:
   - `DEMOS`: optional live React components keyed by `demoKey`.
   - `DIFFS`: unified git diffs (`git diff --no-ext-diff`) keyed by `diffKey`, stored as JSON string literals.
   - `entries`: section map in `useMorph` (Section 4), always including `"step-overview"`.
   - `threads`: comment thread map `{}` in `useMorph` on a new board.
3. **Serve and monitor.** Start `morph ./tmp` in the background if not already running, and arm the persistent `Monitor` on the server output as specified in the `morph` skill.

Initialization is complete when `entries` covers every scoped section, the persistent `Monitor` is running, and you have given the user the direct document URL (`http://localhost:<port>/YYYY-MM-DD-<slug>.morph.jsx`) and the LAN URL (`http://<hostname>:<port>/YYYY-MM-DD-<slug>.morph.jsx`).

## 2. Run the live loop: acknowledge, then synchronize

On every `mutate` notification from the `Monitor`, and before any edit or report to the user, re-read the board file up to the `UI TOOLKIT` banner so your edit preserves every `status`, `selected`, task `status`, `threads`, and `view` value the user changed.

### Step 2a: Acknowledge before legwork

Run this step first whenever a user comment, task toggle, or decision click needs a command, test, subagent, or code edit:

1. Set the target section's `status` to `"working"` in `entries`.
2. Append an `"agent"` reply to `threads[anchorId]` stating what you are checking or changing, and save the board file.

Acknowledgment is complete when the target section shows `"working"` and your initial reply is saved in `threads` before legwork begins.

### Step 2b: Synchronize the board on every change

Every finding, code edit, task update, or user decision updates the section above the `UI TOOLKIT` banner:

1. Update `DIFFS` with fresh `git diff --no-ext-diff` output when code changed.
2. Update the section's `blocks`, `tldr`, and `summary` in `entries` to match current state, and update `"step-overview"` when the section list or top-level summary changes.
3. Set every modified section's `status` to `"to-review"` (including a `"reviewed"` section whose code or content changed) and append the full findings reply to `threads[anchorId]`. Leave untouched `"reviewed"` sections at `"reviewed"`.

Synchronization is complete when `DIFFS` and `entries` match `HEAD`, every user choice is preserved, every user comment in `threads` ends with an `"agent"` reply, and modified sections are `"to-review"`.

### Step 2c: Backport UI changes to `scaffold.jsx`

When the user asks to change the workboard UI itself (components or styles below the `UI TOOLKIT` banner), apply the same edit to `${CLAUDE_SKILL_DIR}/scaffold.jsx` so future boards inherit it.

## 3. Section lifecycle and workflows

Each section moves through four values in `entry.status`:

| `status`      | Badge       | Meaning                                                                                   |
| ------------- | ----------- | ----------------------------------------------------------------------------------------- |
| `"planned"`   | `Planned`   | Proposed step, unstarted workstream, or queued task.                                      |
| `"working"`   | `Working`   | You are actively coding, investigating, or running verification on this section.          |
| `"to-review"` | `To Review` | Ready for the user to inspect, test, or decide.                                           |
| `"reviewed"`  | `Reviewed`  | Set only by the user after reviewing. Your final status for any section is `"to-review"`. |

Choose section blocks to match the workflow:

- **Project dashboard & tracking:** Group sections by milestone or workstream. Use `tasks` blocks for interactive checklists with status pills and `verify` commands, `decision` blocks for open choices, and `prose` for context.
- **Design & architecture discussion:** Put interactive prototypes in `demo` blocks (`DEMOS[demoKey]`) or `ui-states`, before/after shapes in `comparison`, tradeoffs in `decision` cards, and rationale in `prose`.
- **Plan-first execution:** Start sections at `"planned"` with `prose`, `tasks`, and open `decision` items (`selected: null`). Wait for user choices on blocking decisions, move active sections through `"working"` to `"to-review"`, and attach `diff` and validation results as steps complete.
- **Branch or diff review (including `/git-review`):** Create one `"to-review"` section per logical change (with `prose` for why and what changed, `comparison` for pre/post walkthrough, `diff` for the unified diff, and `prose` or `tasks` for validation), plus a section for review findings and `decision` cards.

**Show referenced plan sections inline:** Whenever `"step-overview"` or any section mentions a plan file (`plans/*.md`) or its todos, quote or render the relevant plan sections (the plan's goal, the exact todo items with their `verify:` lines, and any referenced `Context` or `Decisions`) directly in the workboard blocks so the reader can inspect them on the board without opening the file.

## 4. Data contract

All persistent state lives in three top-level `useMorph` calls inside `export default function Workboard()`:

- `Workboard.entries`: `{ [entryId]: Entry }` sorted by `entry.order`. Always include `"step-overview"` (`order: 0`, `code: null`) with a `directory` item.
- `Workboard.threads`: `{ [anchorId]: ThreadMessage[] }`
- `Workboard.view`: `{ selectedId: string, stages: { [itemId]: string }, diffOpen: { [fileKey]: boolean } }`

### `entries` shape

Every block in `entry.blocks` has the shape `{ id: string, heading?: string, items: Item[] }`. Give every block, item, option, and task a stable string `id` so comment threads and selections stay anchored across edits.

```json
{
  "step-overview": {
    "id": "step-overview",
    "code": null,
    "order": 0,
    "title": "Overview & Summary",
    "status": "to-review",
    "summary": "One-line board overview.",
    "tldr": "Executive summary shown under the title (comment anchor: `step-overview-tldr`).",
    "blocks": [
      {
        "id": "ov-directory",
        "heading": "Sections",
        "items": [{ "id": "ov-dir-item", "kind": "directory" }]
      },
      {
        "id": "ov-highlights",
        "heading": "Key Goals & Behavior Changes",
        "items": [
          {
            "id": "ov-vis-1",
            "kind": "prose",
            "body": "1. **First highlight:** what changes and why it matters."
          }
        ]
      }
    ]
  },
  "step-1": {
    "id": "step-1",
    "code": "1.0",
    "order": 1,
    "title": "Short Section Title",
    "status": "to-review",
    "summary": "One-line summary rendered in the overview directory.",
    "tldr": "2-3 sentence summary of the problem, approach, and outcome.",
    "blocks": [
      {
        "id": "s1-tasks",
        "heading": "Tasks",
        "items": [
          {
            "id": "s1-task-list",
            "kind": "tasks",
            "items": [
              {
                "id": "t-1",
                "text": "Implement parser and unit tests",
                "status": "done",
                "owner": "agent",
                "verify": "npm test"
              }
            ]
          }
        ]
      }
    ]
  }
}
```

### Item kinds (`item.kind`)

Each item in `block.items` is a discriminated union on `kind`:

- **`"prose"`**: `{ id, kind: "prose", body }`. Markdown text with GFM tables and fenced code blocks. Put each numbered point into its own item in `block.items` so each point gets its own comment thread.
- **`"tasks"`**: `{ id, kind: "tasks", title?, items: [{ id, text, status: "todo" | "working" | "done" | "blocked", owner?, verify?, note? }] }`. Interactive checklist with status pills, verification commands, and per-task comment threads (`<item.id>::task::<task.id>`).
- **`"decision"`**: `{ id, kind: "decision", title, context?, options: [{ id, label, description? }], selected: string | null }`. Interactive radio cards for design choices or review tradeoffs. Clicking an option writes `selected` in `entries`.
- **`"comparison"`**: `{ id, kind: "comparison", preTitle, preBody, postTitle, postBody }`. Side-by-side red and green Pre vs Post comparison for payloads, state shapes, or code traces.
- **`"demo"`**: `{ id, kind: "demo", demoKey, title?, caption? }`. Renders `DEMOS[demoKey]` from the top of the board file for a live interactive React instrument.
- **`"ui-states"`**: `{ id, kind: "ui-states", defaultStageId?, stages: [{ id, label, note?, badges?: [{ label, tone }], banner?: { tone, spinning?, text, actionLabel? }, body?, code?, diff?, imageSrc? }] }`. Interactive stage switcher (`tone` is `"amber" | "emerald" | "rose" | "blue" | "zinc"`). Active stage persists in `view.stages[item.id]`. Put any images in `./tmp/` and reference them by relative path in `imageSrc`.
- **`"diff"`**: `{ id, kind: "diff", file, diffKey?, diff?, files?: [{ file, open?: boolean, description?: string }] }`. Per-file collapsible unified git diff reading `DIFFS[item.diffKey || item.id] || item.diff`. Order `files` from most important to least important, set `open: true` on primary files and `open: false` on secondary files, and include a concise `description`. Supports commenting on any file (`<id>::file::<path>`) or diff line (`<id>::line::<path>::L<n>`).
- **`"directory"`**: `{ id, kind: "directory" }`. Interactive table of all sections with live status pickers, task progress, open decisions, and thread counts.

### `threads` shape

`threads` maps an `anchorId` to an ordered array of messages. Reader comments append `{ from: "user" }`, and your replies append `{ from: "agent" }` to the same array:

```json
{
  "s1-what-1": [
    {
      "id": "c-1730000000000-ab12",
      "from": "user",
      "entryId": "step-1",
      "blockHeading": "What we changed (#1)",
      "text": "Can we handle the empty array case here too?",
      "createdAt": "2026-10-27T08:30:00.000Z"
    },
    {
      "id": "r-1730000010000",
      "from": "agent",
      "entryId": "step-1",
      "blockHeading": "What we changed (#1)",
      "text": "Added the empty-array guard and a test in `parser.test.ts:42`.",
      "createdAt": "2026-10-27T08:30:10.000Z"
    }
  ]
}
```
