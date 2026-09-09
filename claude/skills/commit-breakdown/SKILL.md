---
name: commit-breakdown
description: >
  Plan the commit sequence for a Jira ticket by reading the investigation notes and breaking
  the work into small, logical, committable chunks. Use this skill whenever the user says
  "commit breakdown for TACO-XXXX", "break down the commits", "plan the commits for
  this ticket", "work out the commit order", "commit plan for TACO-XXXX", "how should
  I break up the work", "chunk up the work", or any similar phrase asking for a commit-by-commit
  plan. This skill is the natural next step after investigate: it reads investigation.md
  and produces commit-breakdown.md in the same thread folder. Each commit entry describes the
  files touched, what needs to happen, how it fits into the sequence, and a ready-to-use commit
  message in the project's standard format.
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
section. It is the single source of truth for how a commit message is written, and this skill
deliberately does not restate the format.

**Invoke the `coding-style` skill** (`Skill(skill="coding-style")`) as well. The breakdown describes
code that is about to be written, so the "what needs to happen" sections should describe it in the
shape Tim actually wants: guard clauses over nesting, comments only where the _why_ isn't derivable,
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

Run `/code-review` over the branch, then deal with the findings before the PR is raised. The
`pr-summary` skill offers this too, so if the review has already run there is nothing to repeat.
```

Write that section verbatim: it is a fixed footer, not something to reword per ticket. It is a
pointer, not a commit, so don't number it or give it a commit message.

---

## Commit message format

The format comes from the `git-workflow` skill, invoked in step 3. It is not restated here, and that
duplication is how the two skills drifted apart last time, and a copy that looks authoritative is
worse than no copy at all.

If step 3 was skipped, go back and do it. Don't reconstruct the format from memory or from commits
already in the repo's history, which predate the current rules.

One thing this skill adds on top: the description should be imperative and specific to *this*
commit's slice of the work: "Add PaymentStatus enum to domain model", not "Payment status changes",
and not a description of the ticket as a whole repeated across every commit.

---

## Finishing the write

Writing `commit-breakdown.md` is a write into the thread, so stamp `updated:` in the thread's
`index.md` per `obsidian`. Change nothing else in that note.

Absolute paths, `file://` links and the `*(new file)*` marker all follow `obsidian`, which is also
what the investigation document was written against.

---

## What not to do

- Don't start writing before thinking through the full sequence, because getting the order wrong means
  rewriting the whole document
- Don't invent commits to pad the list; don't collapse distinct concerns into one commit to shorten it
- Don't leave tests to a single final commit: keep the branch green
- Don't write vague "what needs to happen" sections: if it's not specific enough to act on, it's
  not done
- Don't use relative paths or short filenames in the Files list
- Don't hard-wrap prose in the document, and don't leave the index note's `updated:` stale
- Don't restate the vault conventions here or diverge from them: they are owned by `obsidian`
- Don't turn the review step into a numbered commit, and don't leave the footer off: a plan that
  stops at the last commit reads as though the branch is ready to raise
- Don't add emojis
- Don't write commit messages without invoking `git-workflow` first (step 3), and don't reconstruct its format from memory or from the repo's existing commit history
- Don't describe the code a commit should produce without invoking `coding-style` first (step 3), and don't infer his style preferences from the surrounding code
