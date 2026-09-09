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

Scaffolds a new thread in the vault. This skill owns the scaffolding decisions: which kind, which tags, what the index note says. The conventions it scaffolds *to* belong to `obsidian`.

**Invoke `obsidian` first.** It owns the thread model, the folder naming format, the frontmatter schema and how notes are written. Don't reconstruct any of it from memory or from a neighbouring thread folder.

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
mcp__claude_ai_Atlassian_Rovo__getJiraIssue(
  cloudId=<id>,
  issueIdOrKey="TACO-XXXX",
  fields=["summary", "description", "labels", "parent"],
)
```

Take `summary` as the title, and scan `description` and `labels` for tag hints.

**Ask for `parent` explicitly.** The default field set leaves it out, and it is what step 4 works from: it comes back with the epic's key and summary inline, so the epic costs no second call. Note that the Jira issue **type** is deliberately not recorded: that field is not part of the schema.

If the thread has no key and the user decides it needs a ticket, use the `jira-ticket` skill, which owns the item types, the description style and the fields set on creation.

> **Not using Jira?** Delete this step. Take the title from what the user tells you and carry straight on to step 3. Nothing downstream depends on the fetch succeeding.

### 3. Build the folder name

Per the naming format in `obsidian`, with today as the date.

Check for a collision before creating anything. If a folder for this key already exists (glob `Threads/*(KEY)*/`), do not create a second one and do not overwrite. Say so and stop.

### 4. Infer `tags:`

Read `Threads/tags.md`, the canonical list, and pick from it. Tags are the correlation axis for product initiatives and workstreams that aren't a single ticket.

**Start from the parent epic** on a keyed thread. An epic is the same shape as a tag: a workstream spanning many tickets, which is exactly what a tag correlates. Its summary is usually the better clue, because the ticket's own wording describes one slice of the work and often names nothing recognisable. `fields.parent.fields.summary` from step 2 carries it. TACO-3313, "Forma to Keyframe model import service", gives nothing away on its own; its epic, "Autodesk Platform Services Integration", lands squarely on `autodesk`.

Treat the epic as a clue, not an instruction. Match it to a row in `tags.md` rather than coining a tag out of the epic name, and remember one epic can span several tags and a ticket can sit outside its epic's usual territory. If the same epic keeps turning up with no row that fits, that is the signal to add one.

Then fall back to the ticket's own summary, description and labels, and to how the user framed the work. An unkeyed thread has no epic, so those are all there is.

Nested tags mean tagging the parent tag too: `payments/fx` implies `payments`.

Only propose a tag outside that list if nothing fits, and if you do, add a row to `tags.md` in the same breath. Otherwise `tags: []`.

### 5. Create the folder and index note

Index note path is always `<folder>/index.md`. Write the frontmatter for the kind exactly as `obsidian` specifies it, filling in:

- `title:` the full untruncated summary
- `aliases:` the key when keyed, the title when unkeyed
- `tags:` from step 4
- `created:` and `updated:` both today
- `ticket:` and `jira:` on a keyed `code` thread, omitted entirely when unkeyed

`status:` is `active`: the user is starting this.

Body:

```markdown
# <KEY> - <title>        (or just <title> when unkeyed)

<2-3 sentences on what this is about and why it matters, from the Jira description or the
user's framing. Plain prose. If there's nothing to go on, write a placeholder and flag it.>
```

One sentence per paragraph line, unwrapped, per `obsidian`.

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

- Don't restate the vault conventions here or diverge from them: the folder format, the frontmatter schema and note style are owned by `obsidian`.
- Don't nest a new thread under another unless the user asks. Nesting is the exception.
- Don't run git commands directly. Delegate branch and worktree work to `start-work`, which defers to `git-workflow` for naming.
- Don't add emojis.
