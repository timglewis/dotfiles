---
name: track-session
description: >
  Record the current Claude Code session against a thread in the Obsidian vault so it can
  be resumed later. Works for any thread kind — work (ticketed or not), investigation,
  initiative or incident. Use when the user says "track this session", "log this session",
  "add this session to my notes"; when re-running in a session already recorded, to
  set or sharpen its label and hand-off notes; and when a session begins in a worktree
  whose branch names a ticket that already has a thread. Appends to
  `Threads/<thread-folder>/sessions.md`, a sibling of the thread's index note.
---

# Track Session Skill

Records this session against a thread in `/mnt/c/Users/timle/Obsidian/keyframe/Threads/` so a future session can be resumed with the right working directory. Entries live in their own `sessions.md` file inside the thread folder, so the index note stays a summary and the session log can grow without burying it.

## Locating the thread

Thread folders live under `/mnt/c/Users/timle/Obsidian/keyframe/Threads/`, named `YYYY-MM-DD - (KEY) <title>` when the thread has a key and `YYYY-MM-DD - <title>` when it doesn't. The index note is always `index.md` and the session log is always `sessions.md`. Step 3 covers finding the right one for both cases.

## Why the working directory is recorded

`claude --resume <id>` finds a session from anywhere, but the resumed session runs in **whatever directory you launch it from**, not the one it was created in. Resume this session from the wrong place and it comes back with full memory of the work and then runs `git diff` against the wrong repo. So every entry carries a `cd` alongside the resume command.

## Workflow

### 1. Establish the session ID

A `SessionStart` hook may have already supplied it, in which case use that and skip ahead. Otherwise the scratchpad directory named in the environment ends in the session UUID:

```
/private/tmp/claude-<uid>/<project-slug>/<session-uuid>/scratchpad
```

Confirm it against the transcript before writing it down:

```bash
find ~/.claude/projects -name "<uuid>.jsonl"
```

Exactly one path must come back. If nothing matches, or no scratchpad path is available, say so and stop. A wrong ID is worse than no entry, because it looks resumable and isn't.

### 2. Establish the working directory

```bash
pwd
```

Record the absolute path. In a worktree this is the worktree, not the repo root.

### 3. Find the thread

Two routes, depending on whether the thread has a key. Try them in this order.

**Keyed threads (`work` with a `ticket:`, or `incident`).** Take the key from the current branch, which always leads with it:

```bash
git branch --show-current
```

Then glob `Threads/*(TACO-XXXX)*/` — the key sits in brackets in the folder name.

**Unkeyed threads (`initiative`, `investigation`, untracked `work`).** There is no branch key to go on, and often no git repo at all. Resolve it from what the session has actually been about: search `Threads/*/index.md` frontmatter for a matching `title:` or `aliases:` entry, and if more than one plausibly fits, ask rather than guess. A session working inside a thread folder can also take the thread from the working directory.

Either way the folder holds `index.md` and `sessions.md`. If no thread exists, tell the user to run `start-thread` — do not scaffold one here.

### 4. Write the entry

Entries go in `sessions.md` in the thread folder — never in `index.md`. Create the file if absent, with an H1 and nothing else:

```markdown
# TACO-XXXX — Sessions
```

Give it no frontmatter. `threads.base` filters on `file.hasProperty("kind")`, so a `kind` property here would list the session log as a thread in its own right. The H1 uses the key for keyed threads and the thread title otherwise.

Search the file for this session's UUID first:

- **Already there** — update that entry in place. Never append a second entry for one session.
- **Not there** — append below the existing entries, so they read oldest to newest.

Leave the index note's own content untouched, frontmatter included.

### 5. Link it from the index note

`index.md` should carry one wikilink to the log so it's reachable from the thread:

```markdown
See [[sessions]] for the session log.
```

It goes after the prose summary, before the first `##` section — or at the end of the note if it has none. Skip this step if the link is already there. `[[sessions]]` is deliberately unqualified: Obsidian resolves it to the `sessions.md` in the same folder, so every thread's link points at its own log.

## Entry format

````markdown
# TACO-1234 — Sessions

## 2026-01-15 — Return destination refactor

`example-service/TACO-1234-quickpayment-back-to-redirect`

```bash
cd /home/tim/code/example-service/TACO-1234-quickpayment-back-to-redirect
claude --resume 1b7d3725-9bcc-4b49-8c16-a607c437150e
```

Split the return hook into record + navigate. Option A applied, not committed past `3797cd99`.
````

- **Heading** — `##`, the date, then the **label**.
- **Path line** — the last two segments of the working directory, so entries are scannable without reading the code block.
- **Code block** — the full `cd` and resume command, copy-pasteable as a pair.
- **Notes** — optional prose, omitted entirely when there is nothing to say.

### Label vs notes

Each answers a different question, so keep them apart:

| | answers | written | changes |
| --- | --- | --- | --- |
| Label | which session is this | at the start | rarely |
| Notes | where it left off, what a resumer needs | on a re-run | every re-run |

A label is a few words naming the piece of work, drawn from the thread title when the session is new: `Return destination refactor`, `PR review fixes`, `E2E flakiness`. Sharpen it on a re-run once the session has turned out to be about something narrower.

Notes are for the state a resumer would otherwise have to rediscover: uncommitted work, a decision taken, the thing that was about to happen next. Write them only when there is something concrete. An entry with no notes is normal and better than an entry padded with a restatement of the label.

## Defaults & error handling

- **Session ID unverifiable** — stop and say so. Never write a guessed UUID.
- **No thread folder** — point at `start-thread`; don't create the folder. `sessions.md` itself is fine to create — it's the folder that must already exist.
- **Several worktrees on one thread** — expected. Each session records its own `cwd`, so entries for different repos sit side by side under the same thread.
- **Session already recorded** — update in place, and say which entry changed.
- **Entries still in `index.md`** — an older note may carry a `## Sessions` section. Move it to `sessions.md`, demoting each `###` entry to `##`, and leave the link behind.
