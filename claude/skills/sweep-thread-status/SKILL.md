---
name: sweep-thread-status
description: >
  Sweep every ticketed thread in the Obsidian vault and bring its `status:` into line with where the
  ticket really is: `planned` (no branch), `coding` (a branch exists), `review` (an active PR) or
  `done` (the PR has merged). Use this skill whenever the user says "sweep the threads", "update the
  thread statuses", "sync thread status", "which of my threads are done", "tidy up the thread
  statuses", "refresh the status of my tickets", or any similar phrase asking for the vault's view of
  ticket progress to be brought up to date. Evidence comes from the branches in every worktree repo
  under the code root and the project's pull requests on Azure DevOps. Forward moves are written
  straight away; a move backwards, or away from a status the user set by hand, is asked about first.
---

# Sweep Thread Status Skill

Brings the `status:` of every ticketed thread up to date in one pass.

Other skills move a thread forward as they go (see the lifecycle table in `obsidian`), but two
transitions happen where no skill is watching: a PR merging on Azure DevOps, and branches or PRs
made by hand. This sweep catches both, and repairs any thread that has fallen behind for any other
reason.

## Conventions

**Invoke `obsidian` first.** It owns the status lifecycle this skill applies (which values exist,
what evidence each needs, and which threads are in scope), along with where threads live and how
the index note is written. Don't restate or reinterpret the rules here: `scripts/sweep.py`
implements them, and if the two ever disagree, `obsidian` wins and the script needs fixing.

## Scope

Only ticketed code threads (`kind: code` with a `ticket:`), nested ones included. Every other
thread has no branch or PR to go on and is left alone, per `obsidian`.

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
| `rows[].current` / `derived` | The status in the note, and the one the evidence gives |
| `rows[].move` | `none`, `forward`, `backward`, `migrate` (a value from the non-ticket set, such as `active`) or `held` (`paused` or `dropped`) |
| `rows[].evidence` | The PRs and branches the derivation used |
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

### 3. Ask about the rest

Two kinds of row need the user, because the note may know something the evidence doesn't:

- **`backward`**: for example `done` to `coding`. Usually a PR was abandoned, or the thread was
  marked by hand before the PR existed, but it can also be a follow-up branch on finished work.
- **`held`**: the user set `paused` or `dropped`, and the evidence now says something else (a
  merged PR on a dropped ticket, say).

List them in one table with the evidence, and ask once which to apply. Apply the ones confirmed
with `--apply`, and leave the rest.

### 4. Report

A short table of what changed, grouped by the new status, then any rows left alone and why. Keep it
to the threads that moved or need attention; a thread whose status was already right needs no row.

```
| Ticket | Was | Now | Evidence |
| --- | --- | --- | --- |
| TACO-3342 | active | done | PR 2498 completed |
| TACO-3372 | active | review | PR 2521 active |
| TACO-3380 | active | coding | branch taco-3380-autodesk-processor-app |
```

If any thread has PRs the sweep found but `prs:` doesn't list them, mention it in a line. Don't fill
`prs:` in: that is the user's, per `pr-summary`.

## Defaults and error handling

| Situation | What to do |
| --- | --- |
| No ticketed threads | Say so and stop. |
| `az` not logged in or missing | Stop before writing anything. Point at `! az login`. |
| A repo's origin cannot be listed | Carry on with local branches, flag the repo, distrust moves back to `planned`. |
| A thread has several PRs | The script already decides: any active PR means `review`, otherwise any completed one means `done`. |
| Frontmatter the script cannot parse | It is skipped, since it has no `kind`. Name the folder so the user can fix it (a title with an unquoted colon, usually). |

## What NOT to do

- Don't touch threads outside the scope above, or any frontmatter beyond `status:` and `updated:`.
- Don't derive statuses by hand when the script fails. Fix the cause or stop.
- Don't apply a `backward` or `held` move without the user confirming it.
- Don't stamp `updated:` on a thread whose status didn't change.
- Don't run `git fetch` in the user's repos for this. `ls-remote` reads origin without changing
  anything local.
- Don't restate the lifecycle here; it lives in `obsidian`.
- Don't add emojis.
