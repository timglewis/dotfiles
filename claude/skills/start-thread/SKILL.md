---
name: start-thread
description: >
  Start a new thread in the Obsidian vault, the generic unit of work for notes on a piece of
  work. Use whenever the user says "start ticket TACO-XXXX", "begin work on
  TACO-XXXX", "kick off TACO-XXXX", "set up TACO-XXXX",
  "start a thread on X", "start a topic for X", "make me a thread for this investigation", or
  otherwise asks for a place to keep notes on a new piece of work. Handles all four thread kinds:
  code (ticketed or not), investigation, work (non-code proposals, team process, goals) and
  incident. When given a Jira key it fetches ticket details via the Atlassian MCP. Creates the
  `Threads/YYYY-MM-DD - (KEY) <title>/` folder, scaffolds `index.md`, infers tags, records the
  session via track-session, and offers to hand off to start-work for the worktree and Herdr
  workspace.
---

# Start Thread Skill

Scaffolds a new thread under `/mnt/c/Users/timle/Obsidian/keyframe/Threads/`. Follows the conventions in that vault's `CLAUDE.md` (Threads section). Read it if anything here is ambiguous.

## The model, in one paragraph

A **thread** is a folder holding an `index.md` plus whatever working files get produced. A Jira ticket is just a thread carrying a `ticket:` key, and there is no separate Tickets folder and no `ticket` kind. "Is this a ticket" is answered by `ticket:` having a value.

## Inputs

Either a Jira key (`TACO-XXXX`) or a plain description of the work. Everything else is inferred or asked for.

## Workflow

### 1. Determine the kind

`kind` is one of four:

| kind | When |
| --- | --- |
| `code` | Something being built or changed, ticketed or not. The default. |
| `investigation` | Digging with no deliverable: a spike without a ticket, an alert investigation, research. |
| `work` | Non-code work that produces a proposal, plan or decision: team process, goals and OKRs, committee work. |
| `incident` | An incident with a post-incident-review lifecycle. |

Infer it: a request phrased as "look into" / "investigate" / "work out why" points at `investigation`. Something that produces a proposal or plan rather than code (team process, goals, committee work) is `work`. An incident is `incident`. Everything else is `code`. State the inference in one clause rather than asking, but ask if genuinely torn.

### 2. Fetch the Jira issue (keyed threads only)

Use the Atlassian MCP. If `cloudId` isn't known, call `mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources` once and cache it for the session.

```
mcp__claude_ai_Atlassian_Rovo__getJiraIssue(cloudId=<id>, issueIdOrKey="TACO-XXXX")
```

Take `summary` as the title, and scan `description` and `labels` for tag hints. Note that the Jira issue **type** is deliberately not recorded: that field is not part of the schema.

If the thread has no key and the user decides it needs a ticket, use the `jira-ticket` skill, which owns the item types, the description style and the fields set on creation.

> **Not using Jira?** Delete this step. Take the title from what the user tells you and carry straight on to step 3. Nothing downstream depends on the fetch succeeding.

### 3. Build the folder name

| Case | Format |
| --- | --- |
| Keyed | `YYYY-MM-DD - (KEY) Title` |
| Unkeyed | `YYYY-MM-DD - Title` |

The date is today. A single ` - ` separator follows the date; the key sits in brackets with no extra hyphen after it. **Cap the title portion at 60 characters**, trimming at a word boundary and dropping any trailing stop-word or unbalanced bracket. The full title goes in frontmatter `title:`. Strip characters illegal on macOS (`/`, `:`).

If a folder for this key already exists (glob `Threads/*(KEY)*/`), do not create a second one and do not overwrite. Say so and stop.

### 4. Infer `tags:`

Read `Threads/tags.md`, the canonical list, and pick from it. Tags are the correlation axis for product initiatives and workstreams that aren't a single ticket.

Nested tags mean tagging the parent too: `payments/fx` implies `payments`.

Only propose a tag outside that list if nothing fits, and if you do, add a row to `tags.md` in the same breath. Otherwise `tags: []`.

### 5. Create the folder and index note

Index note path is always `<folder>/index.md`.

**Core frontmatter, every kind:**

```yaml
---
kind: code
title: <full summary, quoted if it contains a colon>
status: active
aliases:
  - <KEY, or the title when unkeyed>
tags: []
created: <today>
updated: <today>
---
```

**`kind: code` also gets**, in this order after `updated:`:

```yaml
ticket: TACO-XXXX                            # omit entirely when unkeyed
jira: https://keyframeai.atlassian.net/browse/TACO-XXXX     # omit when unkeyed
prs: []
```

**`kind: incident` also gets** `incident:`, `severity:`, `detected:`, `resolved:`.

**`kind: investigation`** and **`kind: work`** add nothing.

Body:

```markdown
# <KEY> - <title>        (or just <title> when unkeyed)

<2-3 sentences on what this is about and why it matters, from the Jira description or the
user's framing. Plain prose. If there's nothing to go on, write a placeholder and flag it.>
```

Rules that matter:

- **`status:` defaults to `active`**: the user is starting this. The vocabulary is `planned | active | paused | done | dropped`.
- **`aliases:` is not optional.** It is the only thing keeping `[[TACO-1234]]` and `[[Some Thread Title]]` resolving to a note called `index.md`.
- **Quote any title containing a colon.** An unquoted colon breaks the line, and Obsidian then shows no properties at all and Bases silently drops the note from every view.
- **`prs:` is always present on `code`**, as `prs: []` when empty. Never omitted.
- Empty lists render inline as `[]`, not as an empty block.

### 6. Record this session

Hand off to `track-session`, which writes the working directory and resume command into a sibling `sessions.md` and links it from the index note. It owns that file and the session-ID lookup, so don't write either here.

The thread is new, so give it a label from the title and no notes. If the session ID can't be verified, `track-session` says so and stops; that is not a scaffold failure. Mention it and carry on.

### 7. Offer an environment (keyed `code` threads only)

Ask once, concisely (_"Want me to set up a worktree and Herdr workspace for this in `<repo>`?"_), and don't push if declined. If yes:

1. Confirm the repo with the user.
2. Hand off to `start-work`. It owns the worktree and the Herdr workspace, and delegates branch naming to `git-workflow`. Never run `git worktree` or `herdr` directly here.
3. A new worktree makes this session's recorded directory stale, and the Claude tab `start-work` opens is a different session again. `start-work` says so itself; don't repeat it.

If the user wants notes only, stop here. A thread without a worktree is a normal outcome, and `start-work` can be run later against the same ticket.

## Defaults and error handling

- **Jira fetch fails or the ticket doesn't exist**: say so, then offer to scaffold from a user-supplied title instead, or abort.
- **Atlassian auth errors**: the Rovo connector has no `authenticate` tool. Ask the user to reconnect Atlassian at https://claude.ai/settings/connectors and restart Claude Code, then retry.
- **Folder collision**: never delete or rename an existing thread folder.

## What NOT to do

- Don't put thread-scoped files anywhere but inside the thread folder.
- Don't add a `type:` field. It is deliberately not part of the schema.
- Don't add `parent:` or `root:` frontmatter. Hierarchy is expressed by folder nesting only, and only for epic-shaped work.
- Don't nest a new thread under another unless the user asks. Nesting is the exception.
- Don't run git commands directly. Delegate branch and worktree work to `start-work`, which defers to `git-workflow` for naming.
- Don't add emojis.
