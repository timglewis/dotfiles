---
name: sweep-threads
description: >
  Bring every thread in the Obsidian vault up to date in one pass: sync each ticketed thread's
  `status:` with its branches and Azure DevOps PRs, fill in empty `tags:`, and archive threads
  that finished and have sat untouched for 30 days. Use whenever the user says "sweep the
  threads", "update the thread statuses", "sync thread status", "which of my threads are done",
  "tidy up the thread statuses", "refresh the status of my tickets", "tag the untagged threads",
  "archive the finished threads", "tidy up the vault", or anything similar asking for the vault's
  record of its threads to be brought up to date.
---

# Sweep Threads Skill

Brings the `status:` of every ticketed thread up to date in one pass, tags the threads that were
never tagged, and archives the ones that finished long enough ago to be out of the way.

Other skills move a thread forward as they go (see the lifecycle table in `obsidian`), but two
transitions happen where no skill is watching: a PR merging on Azure DevOps, and branches or PRs
made by hand. This sweep catches both, and repairs any thread that has fallen behind for any other
reason.

Tags drift the same way. `start-thread` infers them when a thread is scaffolded, but a thread
started before a tag existed, or one whose shape only became clear later, keeps `tags: []` forever
because nothing downstream revisits it. The sweep is the moment to look at them together, which is
also the only moment a theme running across several threads is visible.

Archiving needs the same moment for a different reason. A merged ticket stays in `Threads/` and in
every Bases view forever, and no single thread is ever obviously the one to move, so the folder
just grows. The sweep already knows which threads are finished and when each last saw activity, so
it is the one pass that can answer the question for all of them at once.

## Conventions

**Invoke `obsidian` first.** It owns the status lifecycle this skill applies (which values exist,
what evidence each needs, and which threads are in scope), along with where threads live, how the
index note is written, and what archiving a thread means. Don't restate or reinterpret the rules
here: `scripts/sweep.py` implements them, and if the two ever disagree, `obsidian` wins and the
script needs fixing.

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

The archive pass is wider again, and cuts a different way: every top-level thread folder whose
status is terminal and which has gone quiet, whatever its kind and whether or not it has a ticket.
`obsidian` defines terminal and quiet; the script implements them. Only a top-level folder moves,
because nesting is folder nesting and archiving a child on its own would break it.

## The script

`scripts/sweep.py` does the gathering. It lives in this skill's own folder, which is wherever the
skill was installed (`~/.claude/skills/sweep-threads/` for Claude Code,
`~/.copilot/skills/sweep-threads/` for Copilot CLI), so resolve it once and reuse it as
`$SKILL_DIR`:

```bash
SKILL_DIR=$(ls -d ~/.claude/skills/sweep-threads ~/.copilot/skills/sweep-threads 2>/dev/null | head -1)
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
| `KEYFRAME_ARCHIVE_DAYS` | `30` |

## Workflow

### 1. Gather the evidence and derive each status

```bash
python3 "$SKILL_DIR"/scripts/sweep.py
```

It is read-only, and it reads only `Threads/`: an archived thread is out of the sweep altogether,
which is the point of archiving it. It reads every thread's frontmatter, lists local and origin
branches for every `<code-root>/<repo>/.bare`, fetches the project's last 1000 PRs across all repos with
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
| `archivable[]` | One per thread ready to move into `Archive/`, with its `status`, `folder`, `last_touched`, `days` quiet and any `nested` threads travelling with it |
| `archive_blocked[]` | A finished, quiet thread held back by a live nested child, with `blocked_by` naming it |
| `archive_after_days` | The dormancy threshold the rows were derived against |
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

### 4. Work out what is ready to archive

`archivable` is the list, and the script has already applied the rule from `obsidian`: a thread
reaches it only when its status is terminal and nothing in its folder has been touched for
`archive_after_days`. Read the rows rather than re-deriving them. `last_touched` is the day the
thread went quiet, `days` how long it has been quiet, and `nested` any child threads that would
travel with it.

Nothing is written yet, because a move is a move and the vault is not under version control. The
whole list goes to the user in step 5.

**A thread whose status you moved in step 2 will not appear**, since `--apply` stamped `updated:`
today and restarted its clock. That is the right answer rather than a gap to work around: the note
did just change, and the next sweep a month from now will pick it up.

**`archive_blocked` is the other half**: a finished, quiet thread still holding a nested child that
is not finished. Archiving the parent would drag the live child out of `Threads/` with it, so those
stay put. They get a line in the report, not a row in the proposal.

**Sanity-check the list against the status pass before proposing it.** A thread sitting at `done`
that the evidence in step 1 disagreed with is not one to archive this run: settle the status first,
and let it archive once it has been quiet for a month at the status it should have had.

### 5. Ask once, about the moves, the tags and the archive together

Four kinds of row need the user. Put them in one message so the sweep costs a single round trip.

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

Then the archive, as its own table, because it moves folders rather than editing frontmatter:

```
| Thread | Kind | Status | Quiet since | Days |
| --- | --- | --- | --- | --- |
| TACO-3342 | code | done | 2026-08-14 | 37 |
| 2026-08-02 - Staging 500s from the reap-stalled bake endpoint | investigation | dropped | 2026-08-11 | 40 |
```

Offer the list as a whole and let the user strike rows off it. Say plainly what the move does, in a
line rather than a paragraph: the folder goes to `Archive/` unchanged, it leaves every Bases view
because `threads.base` filters on `Threads/`, wikilinks to it keep resolving, and moving it back is
a `mv`.

### 6. Apply the answers

Confirmed status moves go through `--apply` as in step 2. For tags, **add the agreed rows to
`tags.md` first**, then write them:

```bash
python3 "$SKILL_DIR"/scripts/sweep.py --tag TACO-3394=autodesk "2026-09-10 - Spatial indexing with PostGIS=spatial-index"
```

`--tag` takes `REF=TAGS`, where `REF` is the `ref` from the `untagged` row and `TAGS` is a
comma-separated list. It writes `tags:` as a block list, stamps `updated:`, and touches nothing
else. It refuses the whole call if any tag has no row in `tags.md`, and skips any thread that turns
out to be tagged already. A thread the user left untagged on purpose is simply left out of the call.

Archive moves go last, once the statuses and tags are written, so a thread is never moved before
the pass that would have corrected it:

```bash
python3 "$SKILL_DIR"/scripts/sweep.py --archive TACO-3342 "2026-08-02 - Staging 500s from the reap-stalled bake endpoint"
```

`--archive` takes the `ref` or the `folder` from an `archivable` row. It re-derives the list before
moving anything, so a thread that no longer qualifies is refused rather than moved, and it changes
no file: no status move, no `updated:` stamp, nothing inside the folder touched. Name only the
threads the user agreed to.

### 7. Report

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

Then the archive, in a third table: the thread and how long it had been quiet. Underneath, in one
line each, the finished threads held back by a live child, and any row the user struck off.

```
| Thread | Status | Quiet since |
| --- | --- | --- |
| TACO-3342 | done | 2026-08-14 |

Held back: TACO-3309, whose nested TACO-3428 is still at coding.
```

If any thread has PRs the sweep found but `prs:` doesn't list them, mention it in a line. Don't fill
`prs:` in: that is the user's, per `pr-summary`.

## Defaults and error handling

| Situation | What to do |
| --- | --- |
| No ticketed threads | Say so, and carry on with the tag pass, which does not need tickets. |
| No untagged threads | Say so in a line and skip step 3 and the tag half of steps 5 and 6. |
| Nothing ready to archive | Say so in a line. On a young vault this is the normal answer and needs no comment beyond it. |
| `--archive` refuses a thread | It no longer qualifies, or `Archive/` already holds that folder. Re-run the sweep and work from the fresh rows; never move the folder by hand to get around it. |
| The vault was restored or copied about | A copy that didn't preserve mtimes makes every thread look touched today, so nothing archives. That errs the safe way. Say it rather than falling back to `updated:` alone. |
| The user wants a different dormancy window | Set `KEYFRAME_ARCHIVE_DAYS` for the run. Don't edit the script, and don't archive a thread the rows didn't offer. |
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
- Don't archive anything the user hasn't agreed to, one row at a time. It moves folders, and the
  vault isn't in git.
- Don't edit a thread while archiving it: no status move, no `updated:` stamp. It finished a month
  ago and nothing about it has changed.
- Don't archive a nested child on its own, or a parent still holding a live one.
- Don't move a folder into `Archive/` by hand, or rename one on the way in. `--archive` re-checks
  the thread still qualifies, which a `mv` doesn't.
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
