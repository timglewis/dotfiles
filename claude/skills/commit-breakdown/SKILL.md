---
name: commit-breakdown
description: >
  Plan the commit sequence for a Jira ticket by reading the investigation notes and breaking
  the work into small, logical, committable chunks. Use this skill whenever the user says
  "commit breakdown for TACO-XXXX", "break down the commits", "plan the commits for
  this ticket", "work out the commit order", "commit plan for TACO-XXXX", "how should
  I break up the work", "chunk up the work", or any similar phrase asking for a commit-by-commit
  plan. This skill is the natural next step after investigate-ticket: it reads investigation.md
  and produces commit-breakdown.md in the same thread folder. Each commit entry describes the
  files touched, what needs to happen, how it fits into the sequence, and a ready-to-use commit
  message in the project's standard format.
---

# Commit Breakdown Skill

Reads the ticket's investigation document and produces a sequenced commit plan as
`commit-breakdown.md` in the thread folder. The goal is commits that are small, purposeful,
and independently coherent — each one leaving the codebase in a working state, telling a clear
story when read in sequence.

## Locating the thread

Thread folders live under `/mnt/c/Users/timle/Obsidian/keyframe/Threads/`, named `YYYY-MM-DD - (KEY) <title>` for keyed threads. Find one by globbing `Threads/*(TACO-XXXX)*/`; its index note is always `index.md` and its session log is always `sessions.md`.

## Inputs

- Ticket key: `TACO-XXXX` (supplied by the user or inferred from context)
- `investigation.md` in the ticket's vault folder — the primary source of truth
- The vault at `/mnt/c/Users/timle/Obsidian/keyframe/`

## Workflow

### 1. Read the investigation

Read `/mnt/c/Users/timle/Obsidian/keyframe/Threads/<thread-folder>/investigation.md` in full.
Also read the `index.md` index note for context.

If `investigation.md` does not exist or is clearly incomplete (placeholder sections, unresolved
open questions that affect scope), tell the user and suggest running the `investigate-ticket` skill
first. Don't proceed on a half-baked investigation — the breakdown will be wrong.

### 2. Think about the right sequencing

Before writing anything, think through the order. Good sequencing criteria:

- **Foundation before feature**: data model changes, schema migrations, and interface changes before
  the logic that uses them
- **Infrastructure before consumers**: if a new service/client/helper is needed, add it before the
  code that calls it
- **Tests can accompany or follow logic**: unit tests for a class can go in the same commit as the
  class, or immediately after — don't leave tests to a single final commit at the end
- **Refactors before new behaviour**: if existing code needs reshaping to accommodate the change, do
  that in a separate commit first so the diff of the actual feature is clean
- **Each commit should compile and pass tests**: no commit should leave the branch in a broken state
- **Prefer smaller over larger**: if a commit is doing two separable things, split it

The number of commits is whatever the work actually needs — don't artificially inflate or compress.
Three well-chosen commits is better than eight micro-commits or one giant one.

### 3. Write the breakdown document

Path: `/mnt/c/Users/timle/Obsidian/keyframe/Threads/<thread-folder>/commit-breakdown.md`

Write it in one pass once you've thought the sequencing through. Use the template below.

---

## Document structure

```markdown
# Commit Breakdown: TACO-XXXX — <title>

> Investigation: [[investigation]]

## Sequencing rationale

One short paragraph explaining the overall approach and why commits are ordered this way.
Don't list the commits again here — just explain the logic (e.g. "model changes first so the
feature logic has a stable contract to depend on; tests travel with each commit to keep the
branch green throughout").

---

## Commit 1 — <short name for this commit>

**Message:** `<type>: [TACO-XXXX] - <description>`

**Files:**

- [`/full/path/to/File.cs`](file:///full/path/to/File.cs) — what changes in this file
- [`/full/path/to/AnotherFile.cs`](file:///full/path/to/AnotherFile.cs) — what changes here

**What needs to happen:**
Concrete description of the work in this commit. Specific enough that the developer could sit down
and do it without re-reading the investigation. Reference method names, class names, config keys,
field names as appropriate.

**How it fits:**
Why this commit comes here in the sequence. What it sets up for the commits that follow, or what
earlier commits it depends on.

---

## Commit 2 — <short name>

**Message:** `<type>: [TACO-XXXX] - <description>`

**Files:**
...

**What needs to happen:**
...

**How it fits:**
...
```

Repeat the commit block for each commit. Number them sequentially. Keep the short name in the
heading descriptive enough to scan — "add PaymentStatus enum", "wire StatusMapper into handler",
"add unit tests for StatusMapper" — not just "changes" or "update".

---

## Commit message format

Every commit message must follow the format from the git-workflow skill:

```
<type>: [TACO-XXXX] - <description>
```

Valid types:

| Type       | Use for                                             |
| ---------- | --------------------------------------------------- |
| `feat`     | new behaviour visible to callers / users            |
| `fix`      | correcting a bug                                    |
| `refactor` | restructuring without behaviour change              |
| `chore`    | config, dependencies, tooling, non-code maintenance |
| `docs`     | documentation only                                  |
| `test`     | adding or updating tests with no production changes |

The description should be imperative and specific: "Add PaymentStatus enum to domain model", not
"Payment status changes". Keep it under 72 characters.

Never include a Co-Authored-By trailer or any AI attribution in commit messages.

---

## File path conventions

Match the conventions from the investigation document:

- Always use **full absolute paths**
- Wrap in `file://` links so they're clickable in Obsidian:
  `[File.cs](file:///home/tim/code/<repo>/master/path/to/File.cs)`
- If a file needs to be **created** (doesn't exist yet), note that clearly:
  `[NewService.cs](file:///home/tim/code/<repo>/master/src/Services/NewService.cs) *(new file)*`

---

## What not to do

- Don't start writing before thinking through the full sequence — getting the order wrong means
  rewriting the whole document
- Don't invent commits to pad the list; don't collapse distinct concerns into one commit to shorten it
- Don't leave tests to a single final commit — keep the branch green
- Don't write vague "what needs to happen" sections — if it's not specific enough to act on, it's
  not done
- Don't use relative paths or short filenames in the Files list
- Don't add emojis
- Don't include a Co-Authored-By trailer or AI attribution in any commit message
