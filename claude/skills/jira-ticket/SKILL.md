---
name: jira-ticket
description: >
  The rules for writing and raising a Jira ticket in the TACO project — the three item types in
  use (User Story, Technical Story, Bug), how to write a summary and description, and which
  fields to set on creation (parent epic, sprint, assignee). Use this skill whenever a ticket is
  about to be created or reworded: "raise a ticket for this", "create a Jira ticket", "log a bug
  for this", "write up this story", "add a ticket to the backlog", or any similar phrase. Also
  consult it whenever another skill needs to create tickets — `work-breakdown` raises a set of
  them from an investigation — so that ticket conventions live in one place rather than being
  restated. Covers the cached defaults in ~/.jira that make the epic, sprint and assignee
  prompts cost no server call.
---

# Jira Ticket Skill

Everything about **how a TACO ticket is written and raised**. Other skills decide *what* tickets
are needed; this one decides what goes in them.

Site `https://keyframeai.atlassian.net`, project `TACO`, cloudId
`698e3af2-3533-45b9-bbdc-d0407275d5c7` — pass the cloudId straight through rather than spending a
`getAccessibleAtlassianResources` round-trip.

## Item types

Exactly three types are in use. Do not reach for any other type the project happens to expose —
no Task, Epic, Sub-task, Design Task or Feature Flag, and there is no Spike type at all.

| Type | Use for |
| --- | --- |
| `User Story` | A feature the end user will see and/or experience |
| `Technical Story` | Functionality that adds capability the end user does not directly experience |
| `Bug` | A defect or problem that requires fixing |

Pass the name as an exact string — `issueTypeName="Technical Story"`.

The distinction that matters is **who experiences the outcome**, not how technical the work is. A
UI change driven by a refactor is still a User Story if the user sees it; a hard-won performance
fix nobody notices is a Technical Story. Supporting work that merely enables a fix is a Technical
Story even when the fix itself is a Bug.

## Writing the ticket

### Summary

Imperative, specific, under about 80 characters. It should read as the change, not the area:
"Show payment status on the order screen", not "Payment status changes".

### Description — what and why, not how

Keep it brief. Two short paragraphs is usually plenty, and often one will do.

- **What** the ticket delivers or fixes — the outcome, stated plainly
- **Why** it is needed — the reason it earns a place in the backlog

Include **how** it should be done only where it genuinely sharpens the requirement: a constraint
that rules approaches out, an interface or contract that must be matched, a specific file or
component where the work has to land. If the "how" is a solution the implementer could reasonably
arrive at themselves, leave it out — the ticket describes the requirement, not the implementation.

Write it so it stands alone for whoever picks it up. They will not have the investigation notes,
the vault, or this conversation. Link to supporting material, but never let the link carry the
substance.

Use `contentFormat="markdown"` and pass Markdown; do not hand-build ADF.

### Per type

**User Story** — what the user will be able to do, and why that matters to them.

```markdown
Users can see the current payment status directly on the order screen.

Support currently field several calls a week asking "has my payment gone through?", which today
means checking a second system. Surfacing the status where the order already is removes that step.

## Acceptance criteria

- Status appears on the order screen for every order with a payment
- Reflects the latest known status without a page refresh
- Orders with no payment show nothing rather than an empty state
```

**Technical Story** — what capability is added, and what it unblocks or protects. The "why" is
usually a downstream consumer, a risk being retired, or a cost being removed; name it, or the
ticket reads as work for its own sake.

```markdown
Add a PaymentStatus value to the order domain model, populated from the payments service.

Nothing reads it yet — it is the contract the order screen work (TACO-1235) depends on, and
landing it first keeps that change to presentation only.

## Acceptance criteria

- PaymentStatus is populated on every order returned by the orders API
- Absent or unreachable payment data leaves the value unset rather than failing the request
```

**Bug** — what happens, what should happen, and why it matters. Steps to reproduce are not "how to
fix it"; they are part of the requirement, so include them whenever the defect is not obvious from
the description alone.

```markdown
Cancelled orders show the payment status of the order created immediately before them.

**Expected:** a cancelled order shows its own status, or none.
**Actual:** it shows the previous order's status, so customers are told a refunded payment
succeeded.

## Steps to reproduce

1. Create two orders in the same session
2. Cancel the second
3. Open the second order — it shows the first order's status

Reported twice by support this sprint; both were escalated as suspected double charges.
```

### Acceptance criteria

Specific and checkable. Each line should be something a reviewer can confirm is true or not.
Cover the unhappy paths, not just the happy one. Leave the section out entirely rather than
padding it with restatements of the summary.

## Fields set on creation

Three fields get set on every ticket: **parent epic**, **sprint** and **assignee**. Resolve the
defaults first — mostly cache reads, costing no server call — then confirm them in a **single
line** rather than three separate questions:

> "Epic TACO-3143 (Autodesk Platform Services Integration), 2026 Sprint 97 (active), assigned to
> you. Change any of these, or go ahead?"

When raising several tickets at once, ask once and apply the answer to the whole set.

### Parent epic

Every ticket should have a parent epic. Start from the saved default —
`~/.jira/default_epic.ps1`, written by `taco_ticket.ps1` each time an epic is picked:

```powershell
$DEFAULT_EPIC_KEY = "TACO-3143"
$DEFAULT_EPIC_SUMMARY = "Autodesk Platform Services Integration"
```

Read it with `grep`/`sed` — do not execute it.

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

### Sprint

Default to the **active** sprint, which is what `taco_ticket.ps1` pre-selects. Backlog (no sprint)
and any future sprint are the alternatives.

The MCP has no Agile board endpoint — `fetch` takes ARIs only, so the board/sprint REST API the
script uses is out of reach. Harvest sprints from the issues already in them instead:

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

### Assignee

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

## Confirm before creating — always

Show what you are about to raise — type, summary, and the three fields — and get an explicit
go-ahead. Creating a ticket is outward-facing and visible to the whole team; a wrong one is
tedious to unpick. "Yes", "go ahead", "raise it" is the signal. Silence or a question is not.

## Creating it

```
mcp__claude_ai_Atlassian_Rovo__createJiraIssue(
  cloudId="698e3af2-3533-45b9-bbdc-d0407275d5c7",
  projectKey="TACO",
  issueTypeName="Technical Story",              # or "User Story" / "Bug" — exact strings
  summary="<imperative, specific, under ~80 chars>",
  description=<markdown, see above>,
  contentFormat="markdown",
  assignee_account_id="<cached accountId>",     # omit to leave unassigned
  additional_fields={
    "customfield_10014": "TACO-3143",           # Epic Link — the parent epic key
    "customfield_10020": 1011,                  # Sprint — the bare sprint id, not an object
  },
)
```

Both custom fields are the ones `taco_ticket.ps1` sets on this classic company-managed project:
`customfield_10014` is the Epic Link (`:433-435`) and `customfield_10020` is Sprint (`:438-441`),
which takes a **bare numeric sprint id** — not an object, not a name. Omit either key entirely
when the user chose no parent or Backlog. Do not use the MCP `parent` parameter for the epic; that
one is for sub-tasks.

When raising several, create them one at a time in dependency order and capture each returned key
as you go. If one fails, stop and report — do not carry on and leave a half-raised set without
saying so.

Report back with the key and the browse URL: `https://keyframeai.atlassian.net/browse/TACO-XXXX`.

## What not to do

- Don't create anything in Jira before the user has explicitly approved it
- Don't use any item type outside User Story, Technical Story and Bug
- Don't write a description that explains how to implement something the requirement doesn't constrain
- Don't pad the description or the acceptance criteria to make the ticket look substantial
- Don't write a description that only makes sense with the investigation notes open alongside it
- Don't guess an epic — ask, defaulting to the saved one; don't silently raise a ticket with no parent
- Don't execute `~/.jira/default_epic.ps1` to read it, and don't rewrite it when no epic was chosen
- Don't trust a stale epic cache when the user says the epic they want is missing — re-fetch
- Don't trust a sprint cache that survived a sprint rollover — check the active sprint's endDate
- Don't read or echo `$JIRA_API_TOKEN` when pulling `$JIRA_EMAIL` out of `~/.jira/profile.ps1`
- Don't pass the sprint as a name or an object — `customfield_10020` takes the numeric id
- Don't guess a priority, or assign to anyone other than the user, unless told
- Don't add emojis
