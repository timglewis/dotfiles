---
name: sweep-thread-status
description: >
  Sweep every ticketed thread in the Obsidian vault and bring its `status:` into line with where the
  ticket really is: `planned` (no branch), `coding` (a branch exists), `review` (an active PR) or
  `done` (the PR has merged). The same pass tags any thread of any kind that still has `tags: []`,
  drawing on the parent epic and on `Threads/tags.md`, and proposes a new tag where a group of
  threads has no row that fits. Use this skill whenever the user says "sweep the threads", "update
  the thread statuses", "sync thread status", "which of my threads are done", "tidy up the thread
  statuses", "refresh the status of my tickets", "tag the untagged threads", or any similar phrase
  asking for the vault's view of ticket progress to be brought up to date. Evidence comes from the
  branches in every worktree repo under the code root and the project's pull requests on Azure
  DevOps. Forward moves are written straight away; a move backwards, a move away from a status the
  user set by hand, and every tag are asked about first.
---

# Sweep Thread Status Skill

Brings the `status:` of every ticketed thread up to date in one pass, and tags the threads that
were never tagged.

Other skills move a thread forward as they go (see the lifecycle table in `obsidian`), but two
transitions happen where no skill is watching: a PR merging on Azure DevOps, and branches or PRs
made by hand. This sweep catches both, and repairs any thread that has fallen behind for any other
reason.

Tags drift the same way. `start-thread` infers them when a thread is scaffolded, but a thread
started before a tag existed, or one whose shape only became clear later, keeps `tags: []` forever
because nothing downstream revisits it. The sweep is the moment to look at them together, which is
also the only moment a theme running across several threads is visible.

## Conventions

**Invoke `obsidian` first.** It owns the status lifecycle this skill applies (which values exist,
what evidence each needs, and which threads are in scope), along with where threads live and how
the index note is written. Don't restate or reinterpret the rules here: `scripts/sweep.py`
implements them, and if the two ever disagree, `obsidian` wins and the script needs fixing.

**`Threads/tags.md` owns the tags**: the canonical list, what each one covers, and the conventions
for nesting and for reading an epic as a clue. Read it before proposing anything, and apply it as
written rather than restating it here. `start-thread` infers tags from the same list, so a tag this
sweep assigns should be one that skill would have assigned had the thread been scaffolded today.

## Scope

The status pass covers only ticketed code threads (`kind: code` with a `ticket:`), nested ones
included. Every other thread has no branch or PR to go on and is left alone, per `obsidian`.

The tag pass is wider: every thread of every kind whose `tags:` is empty, since an investigation or
a piece of work correlates with a workstream exactly as a ticket does. It only ever fills an empty
`tags:`. A thread already carrying tags is the user's, and the sweep does not add to it, reorder it
or second-guess it.

## The script

`scripts/sweep.py` does the gathering. It lives in this skill's own folder, which is wherever the
skill was installed (`~/.claude/skills/sweep-thread-status/` for Claude Code,
`~/.copilot/skills/sweep-thread-status/` for Copilot CLI), so resolve it once and reuse it as
`$SKILL_DIR`:

```bash
SKILL_DIR=$(ls -d ~/.claude/skills/sweep-thread-status ~/.copilot/skills/sweep-thread-status 2>/dev/null | head -1)
```

It reads the vault root, the code root and the Azure DevOps org and project from the environment,
falling back to the defaults the rest of the skills assume. Override them there, not by editing the
script:

| Variable | Default |
| --- | --- |
| `KEYFRAME_VAULT` | `~/Obsidian/keyframe` |
| `KEYFRAME_CODE_ROOT` | `~/code` |
| `KEYFRAME_AZDO_ORG` | `https://dev.azure.com/keyframe-ai` |
| `KEYFRAME_AZDO_PROJECT` | `KeyframeAI` |

## Workflow

### 1. Gather the evidence and derive each status

```bash
python3 "$SKILL_DIR"/scripts/sweep.py
```

It is read-only. It reads every thread's frontmatter, lists local and origin branches for every
`<code-root>/<repo>/.bare`, fetches the project's last 1000 PRs across all repos with
`az repos pr list` (a few seconds), and prints JSON:

| Field | Meaning |
| --- | --- |
| `rows[]` | One per ticketed code thread, for the status pass |
| `rows[].current` / `derived` | The status in the note, and the one the evidence gives |
| `rows[].move` | `none`, `forward`, `backward`, `migrate` (a value from the non-ticket set, such as `active`) or `held` (`paused` or `dropped`) |
| `rows[].evidence` | The PRs and branches the derivation used |
| `untagged[]` | One per thread of any kind with an empty `tags:`, with its `kind`, `ticket` (null when unkeyed), `title` and `folder` |
| `untagged[].ref` | What names that thread on the command line: its key, or its folder when it has none |
| `tags_in_use` | Every tag on a thread today and how many threads carry it, commonest first |
| `branch_errors` | Repos whose origin could not be listed |
| `pr_history_may_be_truncated` | A thread predates the oldest PR fetched |

**If the script fails**, stop and report why rather than deriving statuses by hand. The usual causes
are `az` not being logged in (`az login`, which the user runs as `! az login`) or the
`azure-devops` extension being missing. A sweep without PR data would mark every merged ticket as
`coding`.

**If `branch_errors` is not empty**, a thread whose only evidence would be a branch in that repo
can come out as `planned` when it is really `coding`. Treat any `backward` move to `planned` as
unreliable, and say which repo could not be read.

**If `pr_history_may_be_truncated` is true**, raise `PR_LIMIT` in the script for this run rather
than trusting the old rows.

### 2. Write the moves that need no decision

`forward` and `migrate` moves are what the evidence says, and the lifecycle only ever runs that
way, so apply them without asking:

```bash
python3 "$SKILL_DIR"/scripts/sweep.py --apply TACO-3342=done TACO-3380=coding
```

`--apply` sets `status:` and stamps `updated:` on each named thread, per `obsidian`, and touches
nothing else in the note. Only write threads whose status actually changes: stamping `updated:` on
an unchanged thread would push it up the Recent threads view for no reason.

### 3. Work out tags for the untagged threads

`untagged` is the list to work through. Nothing here is written yet: tagging is a judgement call,
so the whole proposal goes to the user in step 4.

**Read `Threads/tags.md` first**, and read `tags_in_use` alongside it. The two disagreeing is worth
a line in the report: a documented tag nothing carries may be the wrong shape, and a tag on threads
with no row is one somebody added by hand and never wrote down.

**Get the parent epic for every untagged thread that has a ticket.** An epic is the same shape as a
tag, a workstream spanning many tickets, and the ticket's own summary usually describes one slice
and names nothing recognisable. It costs one call per key, through whichever interface
`~/.claude/skills/jira-ticket/references/interface.md` selects:

```bash
for key in TACO-3362 TACO-3384; do
  acli jira workitem view "$key" --fields "summary,labels,parent" --json > "<scratchpad>/$key.json"
done
```

Only `view` takes `parent`: `acli jira workitem search` rejects it with `field 'parent' is not
allowed`, so there is no batched form and no point attempting one. Each `view` returns one large
pretty-printed object, so write them to separate files and read `fields.parent.key` and
`fields.parent.fields.summary` out of each rather than trying to stream them together. If Jira
cannot be reached at all, carry on from the note alone and say in the report that the epics were
unavailable, since a tag inferred without the epic is the weaker guess.

For an unkeyed thread there is no epic, so the index note's title and body are the evidence.

**Then group by theme.** A tag exists to correlate threads, so it earns its place by covering a
workstream that already has, or will have, more than one thread. Two threads sharing an epic and a
subject are a tag; one thread nothing else touches is not. `tags: []` stays a legitimate answer for
genuinely one-off work, and is better than a tag with a single member that no Bases filter will ever
use. Nested tags mean tagging the parent alongside the child, per `tags.md`.

**Propose a new tag when the list has no row that fits** and a group of threads, or an epic that
keeps turning up, needs one. Write the row as the existing ones are written: what the tag covers,
and where it stops when a neighbouring tag could be confused with it. The row goes into `tags.md`
only once the user has agreed, and the script refuses any tag with no row, so the list cannot drift
out of date behind the sweep.

### 4. Ask once, about the moves and the tags together

Three kinds of row need the user. Put them in one message so the sweep costs a single round trip.

Statuses, because the note may know something the evidence doesn't:

- **`backward`**: for example `done` to `coding`. Usually a PR was abandoned, or the thread was
  marked by hand before the PR existed, but it can also be a follow-up branch on finished work.
- **`held`**: the user set `paused` or `dropped`, and the evidence now says something else (a
  merged PR on a dropped ticket, say).

Tags, all of them, including the ones drawn straight from the existing list:

```
| Thread | Kind | Epic | Tags | Why |
| --- | --- | --- | --- | --- |
| TACO-3362 | code | Workspace Settings | (none) | One-off bug, nothing else touches it |
| TACO-3394 | code | Autodesk Platform Services Integration | autodesk | Key vault secrets for the connector |
| Spatial indexing with PostGIS | investigation | - | spatial-index | The initiative the tag names |
```

And any new `tags.md` row being proposed, quoted in full so the user is agreeing to the wording and
not just the name.

### 5. Apply the answers

Confirmed status moves go through `--apply` as in step 2. For tags, **add the agreed rows to
`tags.md` first**, then write them:

```bash
python3 "$SKILL_DIR"/scripts/sweep.py --tag TACO-3394=autodesk "2026-09-10 - Spatial indexing with PostGIS=spatial-index"
```

`--tag` takes `REF=TAGS`, where `REF` is the `ref` from the `untagged` row and `TAGS` is a
comma-separated list. It writes `tags:` as a block list, stamps `updated:`, and touches nothing
else. It refuses the whole call if any tag has no row in `tags.md`, and skips any thread that turns
out to be tagged already. A thread the user left untagged on purpose is simply left out of the call.

### 6. Report

A short table of what changed, grouped by the new status, then any rows left alone and why. Keep it
to the threads that moved or need attention; a thread whose status was already right needs no row.

```
| Ticket | Was | Now | Evidence |
| --- | --- | --- | --- |
| TACO-3342 | active | done | PR 2498 completed |
| TACO-3372 | active | review | PR 2521 active |
| TACO-3380 | active | coding | branch taco-3380-autodesk-processor-app |
```

Then the tags, in a second table: the thread, the tags written, and any new row added to `tags.md`
called out underneath. Finish with the untagged threads deliberately left as they are, in one line
rather than a row each, so it is clear they were considered and not missed.

```
| Thread | Tags | Source |
| --- | --- | --- |
| TACO-3394 | autodesk | Epic: Autodesk Platform Services Integration |
| Spatial indexing with PostGIS | spatial-index | Title and body |

Added to tags.md: `connectors`, covering the shared connector framework.
Left untagged: TACO-3362, TACO-3384, both one-off fixes with nothing to correlate against.
```

If any thread has PRs the sweep found but `prs:` doesn't list them, mention it in a line. Don't fill
`prs:` in: that is the user's, per `pr-summary`.

## Defaults and error handling

| Situation | What to do |
| --- | --- |
| No ticketed threads | Say so, and carry on with the tag pass, which does not need tickets. |
| No untagged threads | Say so in a line and skip steps 3 and 5's tag half. |
| `az` not logged in or missing | Stop before writing anything. Point at `! az login`. |
| A repo's origin cannot be listed | Carry on with local branches, flag the repo, distrust moves back to `planned`. |
| A thread has several PRs | The script already decides: any active PR means `review`, otherwise any completed one means `done`. |
| Frontmatter the script cannot parse | It is skipped, since it has no `kind`. Name the folder so the user can fix it (a title with an unquoted colon, usually). |
| Jira unreachable for the epics | Tag from the note alone, and say in the report which threads were tagged without their epic. |
| `--tag` refuses a tag | The tag has no row in `tags.md`. Add the row the user agreed to, then run it again. Never work around it by editing the note by hand. |
| A thread with no `tags:` line at all | The script leaves it and says so. Name it in the report; repairing frontmatter is the user's call, not the sweep's. |

## What NOT to do

- Don't touch threads outside the scope above, or any frontmatter beyond `status:`, `tags:` and
  `updated:`.
- Don't derive statuses by hand when the script fails. Fix the cause or stop.
- Don't apply a `backward` or `held` move without the user confirming it.
- Don't write any tag without the user confirming it, and don't add a row to `tags.md` before they
  have agreed to the wording.
- Don't touch a thread that already has tags, even to add one that obviously applies. Say it in the
  report and let the user decide.
- Don't coin a tag for a single thread, and don't coin one out of an epic name without checking the
  list for a row that already covers it.
- Don't stamp `updated:` on a thread whose status or tags didn't change.
- Don't run `git fetch` in the user's repos for this. `ls-remote` reads origin without changing
  anything local.
- Don't restate the lifecycle here; it lives in `obsidian`. Same for the tag conventions, which
  live in `Threads/tags.md`.
- Don't add emojis.
