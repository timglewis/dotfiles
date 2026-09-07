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
  breakdown plans the commits inside one of them.
---

# Work Breakdown Skill

Turns a finished investigation into a set of **deployable items** — each one a single Jira ticket,
a single branch, a single PR. Produces `work-breakdown.md` in the thread folder and the tickets
themselves in Jira.

## Where this sits

```
start-thread → investigate-ticket → work-breakdown → ┐
                                                     │  per ticket:
                                                     └→ start-thread → commit-breakdown → pr-summary
```

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

Exactly three types are in use. Do not reach for any other type the project happens to expose —
no Task, Epic, Sub-task, Spike or Design Task.

| Type | Use for |
| --- | --- |
| `User Story` | A feature the end user will see and/or experience |
| `Technical Story` | Functionality that adds capability the end user does not directly experience |
| `Bug` | A defect or problem that requires fixing |

The distinction that matters is **who experiences the outcome**, not how technical the work is. A
UI change driven by a refactor is still a User Story if the user sees it; a hard-won performance
fix nobody notices is a Technical Story. When the source ticket is a Bug and the fix splits into
several items, each item that corrects the defect stays a Bug; supporting work that merely enables
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

Three fields get set on every item: **parent epic**, **sprint** and **assignee**. Ask once and apply
the answer to the whole set — items from one investigation almost always share all three.

Resolve the defaults first (cheap, mostly cache reads), then confirm them in a **single line**
rather than three separate questions:

> "Epic TACO-3143 (Autodesk Platform Services Integration), 2026 Sprint 97 (active), assigned to
> you. Change any of these, or go ahead?"

#### Parent epic

Every item should have a parent epic. Start from the saved default, which costs no server call —
`~/.jira/default_epic.ps1` is written by `taco_ticket.ps1` each time an epic is picked:

```powershell
$DEFAULT_EPIC_KEY = "TACO-3143"
$DEFAULT_EPIC_SUMMARY = "Autodesk Platform Services Integration"
```

Read it directly with `grep`/`sed` — do not execute it.

**Only if the user wants a different epic**, get the list of open epics. Check the cache first:

- Cache file: `~/.jira/epics_cache.json`, holding `{"fetched": "<ISO-8601 UTC>", "epics": [{"key", "summary", "status"}]}`
- Use it when it exists and is **less than 24 hours old**; say which list you're showing and how old it is
- Otherwise query and rewrite the cache:

```
mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql(
  cloudId="698e3af2-3533-45b9-bbdc-d0407275d5c7",
  jql="project = TACO AND issuetype = Epic AND resolution is EMPTY ORDER BY created DESC",
  fields=["summary", "status"],
  maxResults=100,
)
```

That is the same JQL `taco_ticket.ps1` uses. `maxResults` caps at 100; if there are more open
epics, follow `nextPageToken` rather than truncating the list.

Re-fetch regardless of cache age if the user says the epic they want isn't listed, or asks to
refresh — an epic created today will not be in yesterday's cache.

Present epics in the same order the script does, by status: **Implementing, In Design, On Hold,
Backlog**, then everything else.

Once an epic is chosen, write it back to `~/.jira/default_epic.ps1` in exactly the two-line format
above, so the next `taco_ticket.ps1` run pre-selects the same epic. Only write it when the user
actively picked an epic — never on "no parent".

If the user declines a parent, note that explicitly in `work-breakdown.md` rather than leaving it
looking like an oversight.

#### Sprint

Default to the **active** sprint, which is what `taco_ticket.ps1` pre-selects. Backlog (no sprint)
and any future sprint are the alternatives.

The MCP has no Agile board endpoint — `fetch` takes ARIs only, so the board/sprint REST API the
script uses is out of reach. Harvest sprints from the issues that are already in them instead:

```
mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql(
  cloudId="698e3af2-3533-45b9-bbdc-d0407275d5c7",
  jql="project = TACO AND (sprint in openSprints() OR sprint in futureSprints()) ORDER BY created DESC",
  fields=["customfield_10020"],
  maxResults=50,
)
```

Each issue's `customfield_10020` is an array of sprint objects — `{id, name, state, boardId,
startDate, endDate}` — and includes closed sprints the issue passed through. Take the **distinct**
sprints whose `state` is `active` or `future`, and discard the rest. One page is plenty; don't
follow `nextPageToken` for this.

The limitation of harvesting this way: a sprint that exists on the board but has **no issues in it
yet** cannot be seen. If the user expects a future sprint that isn't listed, that's why — ask them
for its name and id rather than insisting it doesn't exist.

Cache the result in `~/.jira/sprints_cache.json` as
`{"fetched": "<ISO-8601 UTC>", "sprints": [{"id", "name", "state", "endDate"}]}` and reuse it when
**both** hold:

- it is less than 12 hours old, **and**
- the cached active sprint's `endDate` is still in the future

The second check matters: sprints roll over on a fixed cadence, and a cache that survives the
rollover will confidently name a sprint that closed overnight. Re-fetch if either check fails, or
if the user asks to refresh.

#### Assignee

Default to the user — `taco_ticket.ps1` self-assigns unconditionally (`:417-430`), with no prompt.
Offer "leave unassigned" as the alternative; don't offer to assign to anyone else unless asked.

The account id is stable, so cache it in `~/.jira/account_cache.json` as
`{"email": "...", "accountId": "..."}` and reuse it indefinitely. To resolve it the first time,
read **only** the `$JIRA_EMAIL` line out of `~/.jira/profile.ps1` — that file also holds
`$JIRA_API_TOKEN`, which you never need, never read and never echo — then:

```
mcp__claude_ai_Atlassian_Rovo__lookupJiraAccountId(
  cloudId="698e3af2-3533-45b9-bbdc-d0407275d5c7",
  searchString="<the JIRA_EMAIL value>",
)
```

### 6. Create the tickets

Site: `https://keyframeai.atlassian.net`, project `TACO`, cloudId
`698e3af2-3533-45b9-bbdc-d0407275d5c7` — pass the cloudId straight through rather than spending a
`getAccessibleAtlassianResources` round-trip.

```
mcp__claude_ai_Atlassian_Rovo__createJiraIssue(
  cloudId="698e3af2-3533-45b9-bbdc-d0407275d5c7",
  projectKey="TACO",
  issueTypeName="Technical Story",      # or "User Story" / "Bug" — exact strings
  summary="<imperative, specific, under ~80 chars>",
  description=<markdown, see below>,
  contentFormat="markdown",
  assignee_account_id="<cached accountId>",     # omit to leave unassigned
  additional_fields={
    "customfield_10014": "TACO-3143",           # Epic Link — the parent epic key
    "customfield_10020": 1011,                  # Sprint — the bare sprint id, not an object
  },
)
```

Create them one at a time, in dependency order, and capture each returned key as you go. If one
fails, stop and report — do not carry on and leave a half-raised set without saying so.

**Description body** for each ticket, in Markdown:

```markdown
<One paragraph: what this item delivers and why.>

## Acceptance criteria

- <specific, checkable outcome>
- <specific, checkable outcome>

## Notes

- Depends on TACO-XXXX
- Investigation: <vault path or Obsidian link>
```

Write the description so it stands alone for whoever picks it up — they will not have the vault
open. Pull the substance out of the investigation rather than linking to it and stopping there.

Both custom fields are the ones `taco_ticket.ps1` sets on this classic company-managed project:
`customfield_10014` is the Epic Link (`:433-435`) and `customfield_10020` is Sprint (`:438-441`),
which takes a **bare numeric sprint id** — not an object, not a name. Omit either key entirely when
the user chose no parent or Backlog. Do not use the MCP `parent` parameter for the epic; that one
is for sub-tasks.

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

- Don't create anything in Jira before the user has explicitly approved the list
- Don't raise a duplicate set when `work-breakdown.md` already carries keys
- Don't use any item type outside User Story, Technical Story and Bug
- Don't slice into items that can't ship independently — that's a commit plan, not a work breakdown
- Don't pad the breakdown to make it look substantial, or collapse distinct deployables to shorten it
- Don't write a description that only makes sense with the investigation open alongside it
- Don't guess an epic — ask, defaulting to the saved one; don't silently raise items with no parent
- Don't execute `~/.jira/default_epic.ps1` to read it, and don't rewrite it when no epic was chosen
- Don't trust a stale epic cache when the user says the epic they want is missing — re-fetch
- Don't trust a sprint cache that survived a sprint rollover — check the active sprint's endDate
- Don't read or echo `$JIRA_API_TOKEN` when pulling `$JIRA_EMAIL` out of `~/.jira/profile.ps1`
- Don't pass the sprint as a name or an object — `customfield_10020` takes the numeric id
- Don't guess a priority, or assign to anyone other than the user, unless told
- Don't add emojis
