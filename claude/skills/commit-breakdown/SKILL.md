---
name: commit-breakdown
description: >
  Plan the commit sequence for one ticket from its investigation.md, writing commit-breakdown.md
  in the same thread folder with the files, the work and the commit message for each commit. Use
  whenever the user says "commit breakdown for TACO-XXXX", "break down the commits", "plan the
  commits for this ticket", "work out the commit order", "commit plan for TACO-XXXX", "how should
  I break up the work", "chunk up the work", or anything similar asking for a commit-by-commit
  plan. Follows investigate, or work-breakdown when the work spans several tickets.
---

# Commit Breakdown Skill

Reads the ticket's investigation document and produces a sequenced commit plan as
`commit-breakdown.md` in the thread folder. The goal is commits that are small, purposeful,
and independently coherent, each one leaving the codebase in a working state, telling a clear
story when read in sequence.

Scope is **one ticket, one branch**. If the investigation covers work that needs more than one
ticket, that split belongs to the `work-breakdown` skill. Run that first, then come back here for
whichever ticket is being picked up.

## Locating the thread

**Invoke `obsidian` first.** It owns where thread folders live, how to find one, and how notes
are written. Don't reconstruct any of it from memory.

## Inputs

- Ticket key: `TACO-XXXX` (supplied by the user or inferred from context)
- `investigation.md` in the ticket's thread folder, the primary source of truth
- The thread folder in the vault, located per `obsidian`

## Workflow

### 1. Read the investigation

Read `<thread-folder>/investigation.md` in full.
Also read the `index.md` index note for context.

If `investigation.md` does not exist or is clearly incomplete (placeholder sections, unresolved
open questions that affect scope), tell the user and suggest running the `investigate` skill
first. Don't proceed on a half-baked investigation, because the breakdown will be wrong.

### 2. Think about the right sequencing

Before writing anything, think through the order. Good sequencing criteria:

- **Foundation before feature**: data model changes, schema migrations, and interface changes before
  the logic that uses them
- **Infrastructure before consumers**: if a new service/client/helper is needed, add it before the
  code that calls it
- **Tests can accompany or follow logic**: unit tests for a class can go in the same commit as the
  class, or immediately after. Don't leave tests to a single final commit at the end
- **Refactors before new behaviour**: if existing code needs reshaping to accommodate the change, do
  that in a separate commit first so the diff of the actual feature is clean
- **Each commit should compile and pass tests**: no commit should leave the branch in a broken state
- **Prefer smaller over larger**: if a commit is doing two separable things, split it

The number of commits is whatever the work actually needs. Don't artificially inflate or compress.
Three well-chosen commits is better than eight micro-commits or one giant one.

### 3. Load the commit message and code style rules

**Invoke the `git-workflow` skill** (`Skill(skill="git-workflow")`) and read its "Commit Messages"
section. It is the single source of truth for how a commit message is written, so don't
reconstruct the format from memory or from the repo's history, which predates the current rules.
The one thing this skill adds: each message is specific to *this* commit's slice of the work, "Add
PaymentStatus enum to domain model" rather than "Payment status changes" or the ticket's summary
repeated across every commit.

**Invoke the `coding-style` skill** (`Skill(skill="coding-style")`) as well. The breakdown describes
code that is about to be written, so the "what needs to happen" sections should describe it in the
shape the user actually wants: guard clauses over nesting, comments only where the _why_ isn't derivable,
no catch-log-rethrow. That skill owns those preferences and this one does not restate them.

Do this before writing any message or any "what needs to happen" text, not after. The rules are not
in context until the skills are invoked, and a plan written first and corrected afterwards is a plan
the user has already read.

### 4. Write the breakdown document

Path: `<thread-folder>/commit-breakdown.md`

Write it in one pass once you've thought the sequencing through. Use the template below.

---

## Document structure

```markdown
# Commit Breakdown: TACO-XXXX - <title>

> Investigation: [[investigation]]
>
> Push each commit to origin as soon as it is made, per `git-workflow`.

## Sequencing rationale

One short paragraph explaining the overall approach and why commits are ordered this way.
Don't list the commits again here, just explain the logic (e.g. "model changes first so the
feature logic has a stable contract to depend on; tests travel with each commit to keep the
branch green throughout").

---

## Commit 1 - <short name for this commit>

**Message:** `<the commit message, per the git-workflow format>`

**Files:**

- [`/full/path/to/File.cs`](file:///full/path/to/File.cs): what changes in this file
- [`/full/path/to/AnotherFile.cs`](file:///full/path/to/AnotherFile.cs): what changes here

**What needs to happen:**
Concrete description of the work in this commit. Specific enough that the developer could sit down
and do it without re-reading the investigation. Reference method names, class names, config keys,
field names as appropriate.

**How it fits:**
Why this commit comes here in the sequence. What it sets up for the commits that follow, or what
earlier commits it depends on.

---

## Commit 2 - <short name>

**Message:** `<the commit message, per the git-workflow format>`

**Files:**
...

**What needs to happen:**
...

**How it fits:**
...
```

Repeat the commit block for each commit. Number them sequentially. Keep the short name in the
heading descriptive enough to scan: "add PaymentStatus enum", "wire StatusMapper into handler",
"add unit tests for StatusMapper", not just "changes" or "update".

Close the document with the review step, so the plan ends where the work does:

```markdown
---

## After the last commit

Run `/code-review` over the branch, then a `semgrep-review` security scan, then deal with the
findings before the PR is raised. The `pr-summary` skill offers both too, so if they have already
run there is nothing to repeat.
```

Write that section verbatim: it is a fixed footer, not something to reword per ticket. It is a
pointer, not a commit, so don't number it or give it a commit message.

---

## Finishing the write

Stamp `updated:` in the index note, per `obsidian`, and change nothing else in it.

Then suggest `/clear` (not a compaction) before the first commit, and a re-run of `track-session`
afterwards. Coding starts from the plan on disk, and compacting would reduce the `git-workflow` and
`coding-style` rules loaded in step 3 to a summary of themselves.
