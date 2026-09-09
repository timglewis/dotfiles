---
name: track-session
description: >
  Record the current Claude Code session against a thread in the Obsidian vault so it can
  be resumed later. Works for any thread kind: code (ticketed or not), investigation,
  work or incident. Use when the user says "track this session", "log this session",
  "add this session to my notes"; when re-running in a session already recorded, to
  set or sharpen its label and hand-off notes; and when a session begins in a worktree
  whose branch names a ticket that already has a thread. Appends to
  `Threads/<thread-folder>/sessions.md`, a sibling of the thread's index note.
---

# Track Session Skill

Records this session against a thread in the vault so a future session can be resumed with the right working directory. Entries live in their own `sessions.md` file inside the thread folder, so the index note stays a summary and the session log can grow without burying it.

**Invoke `obsidian` first.** It owns where thread folders live, how to find one, and how notes are written. Don't reconstruct any of that from memory.

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

Follow the routes in `obsidian`. **Keyed threads** (`code` with a `ticket:`, or `incident`) take their key from the current branch. **Unkeyed threads** (`work`, `investigation`, untracked `code`) resolve from what the session has actually been about, which is the one extra clue this skill has: the transcript itself.

If no thread exists, tell the user to run `start-thread`. Do not scaffold one here.

### 4. Write the entry

Entries go in `sessions.md` in the thread folder, never in `index.md`. Create the file if absent, with an H1 and nothing else:

```markdown
# TACO-XXXX - Sessions
```

Give it no frontmatter, per `obsidian`. The H1 uses the key for keyed threads and the thread title otherwise.

Search the file for this session's UUID first:

- **Already there**: update that entry in place. Never append a second entry for one session.
- **Not there**: append below the existing entries, so they read oldest to newest.

Leave the index note's own content untouched. Its `updated:` stamp is the one exception, covered in step 6.

### 5. Link it from the index note

`index.md` should carry one wikilink to the log so it's reachable from the thread:

```markdown
See [[sessions]] for the session log.
```

It goes after the prose summary, before the first `##` section, or at the end of the note if it has none. Skip this step if the link is already there. The wikilink is deliberately unqualified, for the reason `obsidian` gives.

### 6. Stamp the index note

Writing to `sessions.md` is a write into the thread, so set `updated:` in `index.md` to today per `obsidian`. Change nothing else in that note.

## Entry format

````markdown
# TACO-1234 - Sessions

## 2026-01-15 - Return destination refactor

`example-service/TACO-1234-quickpayment-back-to-redirect`

```bash
cd ~/code/example-service/TACO-1234-quickpayment-back-to-redirect
claude --resume 1b7d3725-9bcc-4b49-8c16-a607c437150e
```

Split the return hook into record + navigate. Option A applied, not committed past `3797cd99`.
````

- **Heading**: `##`, the date, then the **label**.
- **Path line**: the last two segments of the working directory, so entries are scannable without reading the code block.
- **Code block**: the full `cd` and resume command, copy-pasteable as a pair.
- **Notes**: optional prose, omitted entirely when there is nothing to say.

### Label vs notes

Each answers a different question, so keep them apart:

| | answers | written | changes |
| --- | --- | --- | --- |
| Label | which session is this | at the start | rarely |
| Notes | where it left off, what a resumer needs | on a re-run | every re-run |

A label is a few words naming the piece of work, drawn from the thread title when the session is new: `Return destination refactor`, `PR review fixes`, `E2E flakiness`. Sharpen it on a re-run once the session has turned out to be about something narrower.

Notes are for the state a resumer would otherwise have to rediscover: uncommitted work, a decision taken, the thing that was about to happen next. Write them only when there is something concrete. An entry with no notes is normal and better than an entry padded with a restatement of the label.

## Defaults & error handling

- **Session ID unverifiable**: stop and say so. Never write a guessed UUID.
- **No thread folder**: point at `start-thread`; don't create the folder. `sessions.md` itself is fine to create, but the folder must already exist.
- **Several worktrees on one thread**: expected. Each session records its own `cwd`, so entries for different repos sit side by side under the same thread.
- **Session already recorded**: update in place, and say which entry changed.
- **Entries still in `index.md`**: an older note may carry a `## Sessions` section. Move it to `sessions.md`, demoting each `###` entry to `##`, and leave the link behind.

## What not to do

- Don't write session entries into `index.md`, or edit anything in it but `updated:` and the `[[sessions]]` link.
- Don't write a guessed session UUID.
- Don't restate the vault conventions here or diverge from them: folder naming, frontmatter and link style are owned by `obsidian`.
- Don't add emojis.
