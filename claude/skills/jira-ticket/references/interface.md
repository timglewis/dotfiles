# Which Jira interface to use

The gate every skill passes through before it touches Jira, whether it is reading a ticket,
raising one or cancelling one. `jira-ticket/SKILL.md` owns what goes in a ticket;
`references/acli.md` owns the CLI mechanics; this file owns only the choice between the two
interfaces.

Site `https://keyframeai.atlassian.net`, project `TACO`, cloudId
`698e3af2-3533-45b9-bbdc-d0407275d5c7`. Pass the cloudId straight through on the MCP path rather
than spending a `getAccessibleAtlassianResources` round-trip.

## Preflight, once per session

**Prefer `acli`**, Atlassian's command line tool. Fall back to the Atlassian MCP only when it is
not installed or not authenticated.

```bash
command -v acli >/dev/null && acli jira auth status
```

- **Not installed** (`command -v` fails): say so plainly and use the MCP. Do not offer to install
  it; that is the user's call.
- **Installed but not authenticated**: `acli jira auth status` reports `unauthorized`. Ask the
  user to type `! acli jira auth login --web` themselves. Never run a login for them and never
  pass a token on a command line.
- **Both fine**: use `acli`.

Cache the outcome for the session. Do not re-check before every command. Whichever way it goes,
say which interface you are on the first time it matters, and say which of the two reasons sent
you to the MCP.

Run this check **before** reaching for an MCP tool, not after one fails. The MCP being present in
the session says nothing about `acli`: both are usually available, and `acli` still wins.

## Where the commands live

| Operation | CLI path | MCP fallback |
| --- | --- | --- |
| Read one ticket | `acli.md`, "Reading one ticket" | `getJiraIssue` |
| Create | `acli.md`, "Creating a ticket" | `createJiraIssue` |
| Edit | `acli.md`, "Editing an existing ticket" | `editJiraIssue` |
| Cancel | `acli.md`, "Cancelling a ticket" | `getTransitionsForJiraIssue`, `transitionJiraIssue`, `addCommentToJiraIssue` |
| List open epics | `acli.md`, "Listing open epics" | `searchJiraIssuesUsingJql` |
| Harvest sprints | `acli.md`, "Harvesting sprints" | `searchJiraIssuesUsingJql` |

MCP tools are the `mcp__claude_ai_Atlassian_Rovo__*` family. `jira-ticket/SKILL.md` gives the full
call for each write operation; the reading skills give their own field sets.

Two limits shape a sequence of calls on the CLI path: `acli` cannot set a custom field on an
existing ticket (so epic and sprint are set at creation or through the MCP afterwards), and it
never accepts Markdown in a description. Both are covered in `acli.md`.

## When Atlassian auth fails altogether

The Rovo connector has no `authenticate` tool. If the MCP path returns an auth error, ask the user
to reconnect Atlassian at https://claude.ai/settings/connectors and restart Claude Code, then
retry. If `acli` is the one failing, follow the preflight outcomes above instead: an unauthorised
CLI is fixed by `acli jira auth login --web`, not by reconnecting the connector.
