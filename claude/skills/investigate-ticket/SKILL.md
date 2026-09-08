---
name: investigate-ticket
description: >
  Investigate a Jira ticket by digging into the codebase and writing a thorough investigation.md
  in the ticket's Obsidian vault folder. Use this skill whenever the user says "investigate
  TACO-XXXX", "investigate this ticket", "dig into this ticket", "run investigation on
  TACO-XXXX", "do an investigation for TACO-XXXX", "look into this ticket",
  "analyse this ticket", or any similar phrase asking for a deep dive into what's needed for a Jira
  ticket. This skill is the natural next step after start-thread: it reads the ticket, existing vault
  notes, and the current repo's codebase to produce a living investigation document covering the
  current state of the code, exactly what changes are needed, high-risk areas, and well-linked file
  paths. It pauses to ask clarifying questions as ambiguities surface, never ploughing ahead on
  assumptions, and rewrites the document in-place to stay current as decisions are made. Always
  produces a file named investigation.md inside the thread folder. Works equally on an unkeyed
  thread (a spike, an alert investigation, research) where there is no Jira ticket to fetch;
  trigger phrases there are "investigate this spike", "look into why X", "research X".
---

# Investigate Ticket Skill

Produces a living `investigation.md` in the ticket's vault folder. The document is not a one-shot
summary: it grows and self-corrects as you dig deeper and clarify with the user. You're aiming for
the document a thoughtful senior engineer would hand off before starting implementation: accurate,
navigable, and honest about what's uncertain.

## Locating the thread

Thread folders live under `/mnt/c/Users/timle/Obsidian/keyframe/Threads/`, named `YYYY-MM-DD - (KEY) <title>` for keyed threads and `YYYY-MM-DD - <title>` for unkeyed ones. With a key, find the folder by globbing `Threads/*(TACO-XXXX)*/`. Without one, match on the title, so glob `Threads/*<distinctive words>*/` and confirm the match with the user if more than one folder is plausible. Its index note is always `index.md` and its session log is always `sessions.md`.

If no thread folder exists yet, say so and offer to run `start-thread` first rather than writing `investigation.md` into a folder you invented.

## Inputs

- **Either** a Jira ticket key (`TACO-XXXX`, supplied by the user or inferred from the vault folder
  or branch name) **or** an unkeyed thread: a spike, an alert investigation, research. Both are
  first-class: a keyed ticket is investigated to work out the approach to delivering it, an unkeyed
  thread to work out whether there is anything to deliver at all.
- The current working directory. **This is the repo to investigate, and the only one**
- The vault at `/mnt/c/Users/timle/Obsidian/keyframe/`

## Scope

The repo to investigate is whichever one the current working directory sits in. Investigate that repo
and no other.

If the ticket clearly spans more than one repo (it names a service you aren't in, or the change is
obviously split across a caller and a callee), **say so and ask** which repos are in scope rather than
wandering off into a second checkout unasked. A multi-repo investigation the user didn't want is worse
than a single-repo one they can extend.

## Workflow

### 1. Gather context (parallel where possible)

Run these together at the start:

- **Fetch the Jira ticket** via `mcp__claude_ai_Atlassian_Rovo__getJiraIssue`. **Keyed threads only;
  skip this bullet entirely when there is no key**. Extract: summary, description,
  acceptance criteria, labels, linked issues, subtasks, comments. If `cloudId`
  is unknown, call `mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources` first (once per session).
  Comments are **not** in the default field set, so pass `fields` explicitly including `"comment"`
  (they arrive at `fields.comment.comments`), and `responseContentFormat="markdown"` to avoid raw ADF.
- **Read the vault index note**: `/mnt/c/Users/timle/Obsidian/keyframe/Threads/<thread-folder>/index.md`
- **Read any existing files** already in the thread folder, since the user may have left scratch notes,
  previous research, or design docs that should inform the investigation.

> **Not using Jira?** Delete the fetch bullet. Work from the ticket description the user gives you and
> from the vault index note; everything after step 1 is unchanged.

### 2. Understand the codebase

Explore the current repo with intent:

- Get a structural overview (directory layout, key entry points)
- Identify the files and code paths most directly involved in what the ticket describes
- Understand the current behaviour: how does the feature/flow work today?
- Look for tests: they often reveal expected contracts and edge cases
- Note patterns and conventions (naming, error handling, data shapes) so the investigation can flag
  deviations or guide implementation choices

Be thorough but purposeful. You're not cataloguing the whole repo, you're mapping the territory that
the ticket's work will touch.

### 3. Ask as you go, don't assume

When you hit an ambiguity, a design fork, or something that only the user can resolve, **stop and ask**
before continuing that thread of investigation. Don't batch questions to the end (by then you'll have
made assumptions that contaminate later findings). Phrase questions specifically: what you found, why
it's ambiguous, and what the alternatives are. One or two focused questions at a time is better than
a wall of them.

Good reasons to pause and ask:

- The ticket description leaves scope unclear (e.g., "update the payment flow": which flow, which step?)
- You've found two plausible approaches with meaningfully different trade-offs
- A component or dependency you expected isn't present / has changed
- You need to confirm an assumption before reading further (e.g., "I'm assuming X is the entry point,
  is that right?")
- There's an existing pattern that could be reused, but it's not obvious if it's the right one
- The ticket appears to span repos beyond the one you're in

After the user answers, incorporate the answer into the document and continue.

### 4. Write the document incrementally

Path: `/mnt/c/Users/timle/Obsidian/keyframe/Threads/<thread-folder>/investigation.md`

Don't wait until everything is done to start writing. Write a first draft early, even if some sections
say "investigating…", and then update it in-place as you learn more. The document should always
reflect the current best understanding. When something changes (a clarification, a correction, a new
discovery), rewrite the relevant section rather than appending; keep it clean and readable, not a
change log.

Make the file **navigable**. Every code reference should include a full absolute path so the user can
`cmd+click` or copy-paste it straight into their editor. Where line numbers are meaningful (a specific
function, a config key), include them. Use Markdown file links for local paths, e.g.
`[example-service](file:///home/tim/code/example-service/master/)`.

### 5. Finalise

When investigation is complete and open questions are resolved (or consciously deferred):

- Reread the document with fresh eyes and tighten it: remove placeholders, sharpen vague sections,
  confirm the Relevant Files list is accurate and complete
- Make sure the Open Questions section clearly separates **resolved** items (moved to Decisions) from
  **genuinely unresolved** ones (still open)
- Tell the user the document is ready and flag anything that still needs their attention
- Point at the next step: `work-breakdown` if the work needs carving into separate tickets (always
  the case for an unkeyed spike, which has no ticket of its own yet), or `commit-breakdown` if this
  ticket is already the deployable unit and implementation starts now
- If the investigation turned up a single thing worth raising on its own (a defect found along the
  way, one follow-up), that's `jira-ticket`, which owns how a ticket is written and raised

---

## Document structure

Use this template. Add or remove sub-sections as the ticket warrants. Not every section will have
content for every ticket, and that's fine. Don't pad.

```markdown
# Investigation: TACO-XXXX - <title>

Drop the key from the heading when the thread is unkeyed: `# Investigation: <title>`.

## Summary

One paragraph. What is this being investigated, and why? Written for a developer who hasn't read
the Jira ticket. Plain terms, no padding.

## Requirements

A structured breakdown of what needs to be delivered. Use the Jira acceptance criteria if present;
synthesise from the description if not. Be specific. Numbered list or sub-sections work well here.

For an unkeyed thread there are no acceptance criteria to work from, so state the question the
investigation is answering instead, and retitle the section `## Question`.

## Current State

How the codebase currently works in the area this ticket touches. Focus on what's actually relevant:

- Entry points and key code paths
- Existing behaviour the ticket will modify or extend
- Relevant data models, contracts, or configurations
- Anything surprising or non-obvious that the ticket author might not have known

Include inline code references with full paths, e.g.:
`/home/tim/code/example-service/master/src/Handlers/PaymentHandler.cs`

## What Needs to Change

Concrete description of the changes required. Not a task list (that's for the PR), but a clear
articulation of what the code needs to do differently after this ticket. Reference specific files
and functions where you can.

## Relevant Files

A navigable index of files material to this ticket. Group by purpose if it helps.

| File                                                    | Purpose                       |
| ------------------------------------------------------- | ----------------------------- |
| [`/full/path/to/File.cs`](file:///full/path/to/File.cs) | Brief description of its role |

## Risks & Concerns

Areas that are higher risk, potential gotchas, edge cases to watch, or things that could go wrong.
Be honest: a risk flagged here is a regression avoided later.

## Open Questions

Questions that need resolution before or during implementation. Mark the source of each:

- [ ] **[Stakeholder/Product]** Question about scope or intent
- [ ] **[Design]** Design decision to make before starting
- [x] **[Resolved]** Question that was answered → moved to Decisions

## Decisions

Design decisions and clarifications confirmed during the investigation. Each entry should include
what was decided and why (briefly), so future-you can reconstruct the reasoning.

- **Decision**: What was decided. **Why**: Brief rationale.
```

---

## File path conventions

- Always use **full absolute paths**, never relative paths or just filenames
- For local files, use `file://` links so they're clickable in Obsidian:
  `[Filename](file:///home/tim/code/<repo>/master/path/to/File.cs)`
- For code references inline in prose, use backticks:
  `` `/home/tim/code/<repo>/master/src/Services/PaymentService.cs:142` ``
- For Azure DevOps links, target `https://dev.azure.com/keyframe-ai/KeyframeAI/_git/<repo>` unless the vault note says otherwise

---

## What not to do

- Don't write the document all at once at the end: write early, update often
- Don't make design decisions silently: surface trade-offs and ask
- Don't pad sections with "this section will be updated" filler: leave sections out if empty
- Don't use relative paths or shortened paths in the Relevant Files table
- Don't move on past an ambiguity that matters: ask first
- Don't include every file you read, only the ones genuinely relevant to the ticket
- Don't wander into a second repo without asking
- Don't add emojis
