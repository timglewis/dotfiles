# Raising TACO tickets with `acli`

The mechanics of driving Atlassian's CLI. `SKILL.md` owns what goes in a ticket; this file owns
how it gets there. Read it only once you are actually about to touch Jira.

Site `https://keyframeai.atlassian.net`, project `TACO`. Verified against `acli 1.3.36-stable`,
installed at `~/.local/bin/acli` and authenticated by OAuth.

## Preflight, once per session

```bash
command -v acli >/dev/null && acli jira auth status
```

- **Not installed** (`command -v` fails): say so plainly and fall back to the MCP calls in
  `SKILL.md`. Do not offer to install it; that is the user's call.
- **Installed but not authenticated**: `acli jira auth status` reports `unauthorized`. Ask the
  user to type `! acli jira auth login --web` themselves. Never run a login for them and never
  pass a token on a command line.
- **Both fine**: use `acli` for everything below.

Cache the outcome for the session. Do not re-check before every command.

## What `acli` cannot do

Worth knowing before you plan a sequence of calls:

- **No `--sprint`, and no custom-field flag on `create`.** Custom fields go through
  `--from-json` and its `additionalAttributes` key.
- **`edit` cannot set custom fields at all.** Its `--generate-json` shape has no
  `additionalAttributes`. So the sprint and epic must be set **when the ticket is created**, or
  through the MCP afterwards.
- **No sprint listing.** `acli jira sprint` only has `list-workitems`. Sprints are harvested from
  issues, as on the MCP path, but it takes a loop (see below).
- **`search --fields` only takes standard fields.** `customfield_10020`, `sprint` and `*all` are
  all rejected with `field '...' is not allowed`. `view --fields` takes anything.
- **Descriptions are plain text or ADF, never Markdown.** Markdown passed to `--description`
  arrives as literal `##` and `**` characters in the ticket. See below.

## Reading the JSON

`search --json` returns a list of issues shaped like the REST API: `[{"key": ..., "fields":
{...}}]`. `view --json` returns one such object. Status is `fields.status.name`.

One quirk: `--fields key` on its own returns `[null]`. Always ask for at least one real field
alongside it (`summary` is the cheap choice); `key` comes back at the top level regardless.

## Descriptions: ADF, not Markdown

This is the one place the CLI path genuinely costs something. The MCP takes
`contentFormat="markdown"`; `acli` does not, so the description has to be built as ADF.

Build it mechanically from the Markdown in `SKILL.md`. The constructs those templates use:

| Markdown | ADF node |
| --- | --- |
| a paragraph | `{"type":"paragraph","content":[{"type":"text","text":"..."}]}` |
| `## Heading` | `{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"..."}]}` |
| `- item` | a `bulletList` of `listItem`, each wrapping a `paragraph` |
| `1. item` | an `orderedList` of `listItem`, same wrapping as `bulletList` |
| `**bold**` | a `text` node with `"marks":[{"type":"strong"}]` |

A Bug description, as ADF:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Cancelled orders show the payment status of the order created immediately before them." }
      ]
    },
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Expected:", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": " a cancelled order shows its own status, or none." }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Steps to reproduce" }]
    },
    {
      "type": "orderedList",
      "content": [
        {
          "type": "listItem",
          "content": [
            { "type": "paragraph", "content": [{ "type": "text", "text": "Create two orders in the same session" }] }
          ]
        }
      ]
    }
  ]
}
```

Newlines inside a `text` node are not honoured, so a line break means a new `paragraph` node.

## Creating a ticket

**Every TACO ticket needs an epic and a sprint**, both custom fields, so every create goes through
`--from-json`. Write the JSON to the scratchpad and pass the path; never inline it in a shell
argument, where the quoting is miserable and a stray backtick will run something.

```bash
acli jira workitem create --from-json /path/to/scratchpad/ticket.json --json
```

The shape, from `acli jira workitem create --generate-json`:

```json
{
  "projectKey": "TACO",
  "type": "Technical Story",
  "summary": "Add PaymentStatus to the order domain model",
  "description": { "type": "doc", "version": 1, "content": [] },
  "assignee": "tim.lewis@keyframe.build",
  "additionalAttributes": {
    "customfield_10014": "TACO-3143",
    "customfield_10020": 1011
  }
}
```

- **`projectKey`**, not `project`.
- **`type`** is case sensitive: `User Story`, `Technical Story` or `Bug`, exactly.
- **`description`** must be an ADF document object, not a string.
- **`assignee`** takes an email or account id; take the email from `~/.jira/account_cache.json`.
  The `@me` shorthand is documented for the `--assignee` flag only, so do not rely on it here.
  Omit the key to leave the ticket unassigned.
- **`customfield_10014`** is Epic Link, the parent epic key. TACO mirrors it into `parent`, so
  setting it is enough. Do **not** use the template's `parentIssueId`: it is for sub-tasks only.
- **`customfield_10020`** is Sprint and takes a **bare numeric id**, not a name and not an
  object. Omit the key entirely for Backlog, and omit `customfield_10014` for no parent.

If `acli` rejects the shape, re-run `--generate-json` and follow what it prints: the template
may have moved on since this was written.

Read the key out of the `--json` output and report it with the browse URL.

### If a create fails

Report the failure and stop; do not silently retry on the MCP path. A create that failed on a
custom field may still have created the ticket without it, so search for the summary with
`acli jira workitem search --jql 'project = TACO AND summary ~ "..." AND created >= -1h'` before
raising anything a second time. A duplicate is worse than a missing field.

## Listing open epics

Same JQL the MCP path and `taco_ticket.ps1` use:

```bash
acli jira workitem search \
  --jql "project = TACO AND issuetype = Epic AND resolution is EMPTY ORDER BY created DESC" \
  --fields "key,summary,status" --json --paginate
```

`--paginate` fetches every page, so the MCP path's `nextPageToken` handling is not needed. Cache
and present the results exactly as `SKILL.md` describes; the cache file and its rules do not
change with the interface.

## Harvesting sprints

`search` cannot return the Sprint field, so find the issues with `search` and read their sprints
with `view`, one call per issue:

```bash
acli jira workitem search \
  --jql "project = TACO AND (sprint in openSprints() OR sprint in futureSprints()) ORDER BY created DESC" \
  --fields summary --limit 20 --json \
  | python3 -c "import json,sys;[print(i['key']) for i in json.load(sys.stdin)]" \
  | while read -r k; do acli jira workitem view "$k" --fields customfield_10020 --json; done \
  | python3 -c "
import json,sys
dec=json.JSONDecoder(); s=sys.stdin.read(); i=0; seen={}
while i < len(s):
    if s[i].isspace(): i+=1; continue
    d,i=dec.raw_decode(s,i)
    for sp in (d.get('fields',{}).get('customfield_10020') or []):
        if sp.get('state') in ('active','future'):
            seen[sp['id']]={k:sp.get(k) for k in ('id','name','state','endDate')}
print(json.dumps(sorted(seen.values(),key=lambda x:x['id'])))"
```

That is twenty `view` calls, so it takes a few seconds; it is still one Bash invocation. The
output is already in the `sprints` shape `~/.jira/sprints_cache.json` wants. The caching rules,
and the caveat that a future sprint with no issues in it cannot be seen, are in `SKILL.md` and
apply unchanged.

## Editing an existing ticket

```bash
acli jira workitem edit --key TACO-1234 --summary "..." --description-file desc.adf.json --yes
```

Summary, description, type, assignee and labels only. For **anything custom-field shaped, the
sprint and the epic included, `edit` will not do it**: use
`mcp__claude_ai_Atlassian_Rovo__editJiraIssue` and say that you have.
