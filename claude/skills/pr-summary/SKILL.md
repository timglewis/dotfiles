---
name: pr-summary
description: >
  Write a pull-request title and description for a Jira ticket and append it as a new section
  to the thread's index note in the Obsidian vault. Use this skill whenever the user says
  "write a PR summary", "PR summary for TACO-XXXX", "draft the PR description",
  "write up this PR", "summarise this PR", "PR description for this branch", "generate a PR title
  and summary", or any similar phrasing asking for a pull-request write-up, even if they don't
  name the ticket. The skill derives the changes from the branch's commits and diff against the
  default branch, produces a title in the project's `<type>: [TACO-XXX] - <short title>`
  format, and a concise high-level summary that starts with a Jira Reference line followed by a
  `## Summary` section of bullet points. It writes the result into the ticket note and echoes it in
  chat for copy-paste into Azure DevOps. Offers a `/code-review` pass over the branch first,
  since being asked for a PR write-up is the signal that the ticket's work is finished.
---

# PR Summary Skill

Produces a ready-to-paste pull-request **title** and **description** for a ticket, writes them
into the thread's index note as a new `## Pull Request` section, and echoes them in chat.

The goal is something the user can paste straight into the Azure DevOps PR form: a clean title and a
short, high-level description of _what changed_, not a changelog, not testing notes, not
implementation play-by-play. Reviewers skim PR descriptions; the value is in a tight summary that
orients them fast.

## Locating the thread

**Invoke `obsidian` first.** It owns where thread folders live, how to find one, and how notes
are written. Don't reconstruct any of it from memory.

## Inputs

- A Jira ticket key (`TACO-XXXX`). If the user doesn't state it, infer it from the current branch
  name (e.g. `TACO-1234-order-confirmation-email` → `TACO-1234`).
- The current git branch (the work to summarise).

## Workflow

### 1. Offer a code review before writing anything

Being asked for a PR summary is the signal that the ticket's work is finished, and that makes this
the last cheap moment for a review: the branch is complete, nothing is in the PR yet, and the diff
can still change without a force-push or a second round of reviewer comments.

Ask once, concisely:

> "The branch looks complete. Want me to run `/code-review` over it before I write the summary?"

- **If yes**: run it (`Skill(skill="code-review")`, it is a harness skill rather than one of these).
  Don't pass an effort level unless the user names one, because it reuses the level they last typed.
  `ultra` is user-triggered and billed, so if they want that, they type it themselves. Once the
  findings are dealt with (fixed, or consciously left), pick up from step 2. The summary must
  describe the final diff, not the one that existed before the review.
- **If no**: carry straight on, and don't ask again.

Skip the question entirely when a review has already run on this branch in the session, or when the
user declined one in the same breath as asking for the summary. Ask once, don't push.

### 2. Identify the ticket and locate its note

Derive `TACO-XXXX` from the user's message or the branch name, then find
`<thread-folder>/index.md`.

Read its frontmatter: you need the `jira:` URL for the Jira Reference line. If the note has no
`jira:` field, fall back to `https://keyframeai.atlassian.net/browse/TACO-XXXX`. If no note folder
exists, tell the user and ask whether to proceed (writing only to chat) or stop.

### 3. Derive the changes from git

The branch diff against its **base** is the source of truth. Commit messages alone can miss things
or overstate them. Resolve the base rather than assuming it, then read both the log and the diff.

The base is the fork point, which is not always the default branch. Work cut from another unmerged
branch records its fork point in `branch.<name>.forkedFrom` (see `git-workflow`), and diffing such a
branch against master would present the whole base branch as this PR's changes.

```bash
BASE=$(git config branch."$(git branch --show-current)".forkedFrom 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || echo origin/master)

git log "$BASE"..HEAD --pretty='%s'        # commit subjects, for the shape of the work
git diff "$BASE"...HEAD --stat             # files touched, for scope
git diff "$BASE"...HEAD                    # the actual changes, when a bullet needs detail
```

Synthesise _what changed at a feature level_, not file-by-file. Group related commits into one
bullet where it reads better (e.g. three test commits → one "Added test coverage" bullet). You're
describing the change to a reviewer, not transcribing git history.

### 4. Compose the PR title

Format, matching the project's commit convention:

```
<type>: [TACO-XXX] - <concise imperative title>
```

- `<type>` is one of `feat | fix | refactor | chore | docs | test`. Pick the type that reflects the
  PR's primary purpose: if it adds new behaviour, it's `feat` even if it also includes refactors
  and tests. Use the dominant intent, not a literal count of commit types.
- Keep the title short, specific, and imperative ("Send confirmation email on order completion",
  not "Changes for orders"). Aim for under ~72 characters total.

The title is **separate** from the summary: it is not repeated inside the description body.

### 5. Compose the PR description

The description body is what gets pasted into Azure DevOps. ALWAYS use this exact structure:

```
Jira Reference: <jira-url>

## Summary
- <high-level change>
- <high-level change>
- <high-level change>
```

- First line is literally `Jira Reference: ` followed by the URL, then a blank line.
- Then a `## Summary` header, then bullet points.
- Bullets cover the changes made, high-level. Aim for roughly 3–6. Lead with the most significant
  change.
- Do **not** include testing notes, "how to test", screenshots, risk sections, rollout/flag notes,
  or file-by-file detail. If a change is only a supporting detail of a larger one, fold it in rather
  than giving it its own bullet.

**Default detail level.** Each bullet names what changed _plus a short clause of mechanism or why_:
roughly 15–25 words. The aim is enough for a reviewer to understand the change without opening the
diff, but no more. Avoid bare one-liners that just name a method or file, and equally avoid
sprawling bullets that drift into implementation play-by-play.

- ✅ `Adds SendOrderConfirmationAsync to the Notifications client, which posts the order summary to the notification service's email endpoint`
- ⚠️ Too thin: `Adds a new client method`, which names the change but gives the reviewer nothing to go on.
- ⚠️ Too much: a bullet that walks through the method body, parameters, and HTTP headers line by line.

**Detail nudge.** Treat the level above as the default, but adjust when the user signals one. If they
say things like "keep it tight", "more concise", "shorter", "TL;DR", drop to terse one-line bullets
that just name each change (~6–10 words, no mechanism clause). If they say "more detail", "expand
it", "more thorough", widen each bullet with the mechanism and the reason, and split a bundled
bullet into its parts where that adds genuine clarity. Don't change the voice or structure, only
the depth of each bullet.

**Bullet voice, important.** Write each bullet as a neutral description of _what the PR does to the
codebase_, using present-tense third-person verbs: **Adds, Updates, Introduces, Parameterises,
Moves, Removes, Renames, Replaces**. The reader is reviewing the change, so the bullets should
describe the change itself, not narrate the actions the author took.

- ✅ `Adds an order-confirmation method to the Notifications client`
- ✅ `Updates order status to Completed when payment settles, alongside the existing receipt write`
- ✅ `Parameterises the shared notification method by channel (email and SMS)`
- ❌ `Added ...` / `Called it from ...` / `Wired up ...`: past-tense narration reads like a personal
  changelog of what _you_ did, and "it" referring back to a previous bullet is informal and unclear.
- ❌ `I added ...` / `We updated ...`: never first person.

Each bullet should stand on its own without depending on a previous bullet for a pronoun like "it".

### 6. Write to the ticket note and echo in chat

Append a new `## Pull Request` section to the **end** of `index.md`. Put the title and the
description in fenced code blocks so they copy cleanly and the inner `## Summary` doesn't fragment
the note's own heading outline:

````markdown
## Pull Request

**Title**

```
feat: [TACO-1234] - Send confirmation email on order completion
```

**Description**

```markdown
Jira Reference: https://keyframeai.atlassian.net/browse/TACO-1234

## Summary

- Adds `SendOrderConfirmationAsync` to the Notifications client, which posts the order summary to the notification service's email endpoint
- Updates the order-completion handler to send a confirmation when an order settles, alongside the existing receipt write
- Parameterises the shared notification method by channel so email and SMS run through one implementation instead of duplicated methods
- Adds unit coverage for the new client method and handler behaviour, plus an integration test asserting the notification is sent end-to-end
```
````

If a `## Pull Request` section already exists in the note, replace it rather than adding a second
one, and the latest summary supersedes the old one.

Then echo the same title and description in the chat reply so the user can copy-paste immediately
without opening the note.

Stamp `updated:` to today, per `obsidian`. Leave the rest of the frontmatter alone, `prs:`
included: the PR URL doesn't exist yet, and that is the user's to add.

## What not to do

- Don't pad the summary with testing notes, rollout steps, or file-by-file detail. It's a
  high-level overview of changes only.
- Don't repeat the title inside the description.
- Don't assume the diff base is `master`. Resolve it, honouring `forkedFrom` on a stacked branch.
- Don't invent changes that aren't in the diff, or omit a significant one because it wasn't in a
  commit message. The diff is the source of truth.
- Don't write the summary from a diff a review is about to change: offer the review first (step 1),
  and regenerate the summary if the review changes anything.
- Don't touch the frontmatter beyond `updated:`, and don't add the PR URL to `prs:`: that is the
  user's to add once the PR exists.
- Don't create a PR; this skill only writes the summary.
- Don't hard-wrap prose in the note.
- Don't restate the vault conventions here or diverge from them: they are owned by `obsidian`.
