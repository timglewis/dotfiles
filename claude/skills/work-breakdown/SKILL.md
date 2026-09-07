---
name: work-breakdown
description: >
  Break a completed investigation into separately deployable items and raise a Jira ticket for
  each. Use this skill whenever the user says "work breakdown for TACO-XXXX", "break this
  investigation into tickets", "raise the tickets for this work", "what tickets do we need",
  "split this into deployable items", "create the Jira items for this", or any similar phrase
  asking for the work to be carved up into ticketed units. This skill is the natural next step
  after investigate-ticket: it reads investigation.md, proposes a set of items typed as User
  Story, Technical Story or Bug, gets explicit sign-off, creates them in Jira via the Atlassian
  MCP, and writes work-breakdown.md into the same thread folder with the resulting keys. It
  sits one level above commit-breakdown — this skill decides what the tickets are, commit-
  breakdown plans the commits inside one of them. Ticket conventions themselves — the item types,
  description style and the fields set on creation — come from the jira-ticket skill.
---

# Work Breakdown Skill

Turns a finished investigation into a set of **deployable items** — each one a single Jira ticket,
a single branch, a single PR. Produces `work-breakdown.md` in the thread folder and the tickets
themselves in Jira.

## Where this sits

```
start-thread → investigate-ticket → work-breakdown → ┐
                                    (jira-ticket)    │  per ticket:
                                                     └→ start-thread → commit-breakdown → pr-summary
```

`jira-ticket` is the reference this skill leans on: **it owns what a ticket looks like — the three
item types, how the description is written, and the epic/sprint/assignee fields. This skill owns
only the decision of what the tickets should be.** Don't restate its rules here; follow them.

Two different cuts of the same work, and they are easy to confuse:

| Skill | Unit | Output |
| --- | --- | --- |
| `work-breakdown` (this one) | a deployable item — one ticket, one branch, one PR | tickets in Jira + `work-breakdown.md` |
| `commit-breakdown` | a commit inside one ticket's branch | `commit-breakdown.md` |

If the user asks for "the breakdown" and it is ambiguous which they mean, ask. The tell: are they
about to write code (commit-breakdown) or about to fill the backlog (work-breakdown)?

## Locating the thread

Thread folders live under `/mnt/c/Users/timle/Obsidian/keyframe/Threads/`, named
`YYYY-MM-DD - (KEY) <title>` for keyed threads and `YYYY-MM-DD - <title>` for unkeyed ones. With a
key, glob `Threads/*(TACO-XXXX)*/`; without one, match on distinctive title words and confirm the
match if more than one folder is plausible. The index note is always `index.md`.

## Inputs

- The thread folder, keyed or unkeyed — an investigation spike with no ticket of its own is the
  common case here, and is fine
- `investigation.md` in that folder — the primary source of truth
- The vault at `/mnt/c/Users/timle/Obsidian/keyframe/`

## Workflow

### 1. Read the investigation

Read `investigation.md` in full, plus `index.md` for context. The **Required Changes**, **Risks &
Concerns** and **Open Questions** sections carry most of what you need.

If `investigation.md` does not exist, or is visibly incomplete — placeholder sections, or open
questions that would change the shape of the work — stop and say so, and suggest running
`investigate-ticket` first. Tickets raised off a half-finished investigation have to be rewritten
or closed, which is worse than not raising them yet.

If `work-breakdown.md` already exists with ticket keys in it, **do not raise a second set**. Read
it, tell the user what is already raised, and offer to add only the genuinely new items.

### 2. Slice into deployable items

An item earns its own ticket when it can be **merged and released on its own** without waiting for
its siblings. Good slicing criteria:

- **Independently deployable**: shipping it alone leaves the product in a working, releasable state
- **One reviewable PR**: if the diff would be too big to review in one sitting, split it
- **A single coherent intent**: "add the endpoint" and "add the caching in front of it" are two
  items; "add the endpoint" and "add its unit tests" are one
- **Ordered by dependency, not by convenience**: if B cannot start until A is merged, say so
  explicitly on B rather than silently relying on the numbering
- **Foundation first**: schema, contracts and shared infrastructure before the features that use them

Prefer fewer, meaningful items. Three tickets that each ship something beat eight that only make
sense as a set. If the work genuinely is one deployable unit, say so and raise one ticket — do not
manufacture a breakdown to justify the skill.

### 3. Type each item

Every item is a `User Story`, a `Technical Story` or a `Bug`. **The `jira-ticket` skill owns the
type definitions and the rule for choosing between them — follow it rather than deciding here.**

The one thing worth restating: when the source ticket is a Bug and the fix splits into several
items, each item that corrects the defect stays a Bug, while supporting work that merely enables
the fix is a Technical Story.

### 4. Propose before creating — always

Show the proposed items **as a table in chat** and get an explicit go-ahead before touching Jira.
Creating tickets is outward-facing and visible to the whole team; a wrong set is tedious to unpick.

| # | Type | Summary | Depends on |
| --- | --- | --- | --- |
| 1 | Technical Story | Add PaymentStatus to the domain model | — |
| 2 | User Story | Show payment status on the order screen | 1 |

Wait for the user to approve, amend or drop items. "Yes", "go ahead", "raise them" is the signal.
Silence or a question is not.

### 5. Fill in the ticket fields

Parent epic, sprint and assignee are set on every item. **The `jira-ticket` skill owns how those
are resolved** — the cached defaults in `~/.jira`, when to re-query, and the single-line
confirmation that covers all three.

Ask once and apply the answer to the whole set: items from one investigation almost always share
an epic, a sprint and an assignee.

If the user declines a parent epic, note that explicitly in `work-breakdown.md` rather than
leaving it looking like an oversight.

### 6. Create the tickets

**The `jira-ticket` skill owns ticket creation** — how to write the summary and description, which
fields to pass, and the exact `createJiraIssue` call. Follow it for each item; nothing about the
mechanics is repeated here.

What is specific to a breakdown:

- Create them **one at a time, in dependency order**, capturing each returned key as you go —
  later items reference earlier keys in their "Depends on" notes
- If one fails, stop and report. Don't carry on and leave a half-raised set without saying so
- Each description should name what it depends on and link back to the investigation:

```markdown
## Notes

- Depends on TACO-XXXX
- Investigation: <vault path or Obsidian link>
```

Descriptions still have to stand alone — the link is context, not the substance.

### 7. Write work-breakdown.md

Path: `/mnt/c/Users/timle/Obsidian/keyframe/Threads/<thread-folder>/work-breakdown.md`

```markdown
# Work Breakdown: <title>

> Investigation: [[investigation]]

## Approach

One short paragraph on how the work was sliced and why the order is what it is. Don't re-list
the items here — explain the logic.

---

**Parent epic:** TACO-XXXX — <summary>  (or: none, by decision)
**Sprint:** <name>  (or: Backlog)
**Assignee:** <name>  (or: unassigned)

---

## 1. TACO-XXXX — <short name>

**Type:** Technical Story
**Depends on:** — (or TACO-XXXX)
**Jira:** https://keyframeai.atlassian.net/browse/TACO-XXXX

**What it delivers:**
Concrete description of the item, specific enough to act on without re-reading the investigation.

**Relevant files:**

- [`/full/path/to/File.cs`](file:///full/path/to/File.cs) — what changes here

---

## 2. TACO-XXXX — <short name>

...
```

Repeat per item, numbered in dependency order. Then tell the user what was raised, with the keys,
and point out that `commit-breakdown` is the next step once they pick one up.

## File path conventions

- Always use **full absolute paths** — never relative paths or bare filenames
- Wrap local paths in `file://` links so they are clickable in Obsidian:
  `[File.cs](file:///home/tim/code/<repo>/master/path/to/File.cs)`
- Inline code references in prose go in backticks with a line number where it helps:
  `` `/home/tim/code/<repo>/master/src/Services/PaymentService.cs:142` ``

## What not to do

- Don't slice into items that can't ship independently — that's a commit plan, not a work breakdown
- Don't pad the breakdown to make it look substantial, or collapse distinct deployables to shorten it
- Don't raise a duplicate set when `work-breakdown.md` already carries keys
- Don't restate the `jira-ticket` rules here or diverge from them — types, descriptions and fields
  are owned by that skill
- Don't add emojis
