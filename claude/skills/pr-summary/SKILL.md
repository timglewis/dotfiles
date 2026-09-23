---
name: pr-summary
description: >
  Write a pull-request title and description for a Jira ticket and append it as a new section
  to the thread's index note in the Obsidian vault. Use this skill whenever the user says
  "write a PR summary", "PR summary for TACO-XXXX", "draft the PR description",
  "write up this PR", "summarise this PR", "PR description for this branch", "generate a PR title
  and summary", or any similar phrasing asking for a pull-request write-up, even if they don't
  name the ticket. The skill derives the changes from the branch's commits and diff against the
  default branch, produces a title in the project's `[TACO-XXXX] <short title>` format, and a
  concise high-level description built from four sections: `## Context`, `## Risk`,
  `## Jira Reference` and a `## Summary` of bullet points. It writes the result into the ticket
  note, echoes it in chat, and then offers to create the pull request on Azure DevOps with those
  fields already populated, set to auto-complete where the change is low risk and has nothing
  blocking its merge. Pushes
  any commits not yet on origin first, since the PR cannot be raised without them. Offers a
  `/code-review` pass and a `semgrep-review` security scan over the branch first, since being asked
  for a PR write-up is the signal that the ticket's work is finished.
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

### 1. Offer a review before writing anything

Being asked for a PR summary is the signal that the ticket's work is finished, and that makes this
the last cheap moment for a review: the branch is complete, nothing is in the PR yet, and the diff
can still change without a second round of reviewer comments. Review fixes are committed and
pushed like any other commit.

Two passes are on offer, and they look for different things: `/code-review` for correctness bugs,
`semgrep-review` for known-shape vulnerabilities and leaked credentials. Ask for both in one
question rather than two, so the user answers once:

> "The branch looks complete. Want me to run `/code-review` and a `semgrep-review` security scan
> over it before I write the summary? Either, both or neither."

- **Code review**: run it (`Skill(skill="code-review")`, it is a harness skill rather than one of
  these). Don't pass an effort level unless the user names one, because it reuses the level they
  last typed. `ultra` is user-triggered and billed, so if they want that, they type it themselves.
- **Security scan**: run it (`Skill(skill="semgrep-review")`). It takes well under a minute on a
  normal branch, and it offers its own install if semgrep is not yet on the machine.
- **Both**: run the code review first. It is the one more likely to change the diff, and the scan
  should see the code that is actually going into the PR.

Once the findings are dealt with (fixed, or consciously left), pick up from step 2. The summary
must describe the final diff, not the one that existed before the review.

Skip the question entirely when both have already run on this branch in the session, or when the
user declined in the same breath as asking for the summary. Ask once, don't push. If only one has
run, offer just the other.

### 2. Push the branch to origin

Each commit should already have been pushed as it was made, so this step is usually a check that
confirms nothing is outstanding: typically the review fixes from step 1, or a commit made outside
the usual flow. Everything after this step is PR work, and `az repos pr create` fails outright on a
source branch the remote doesn't have.

`git-workflow` owns the push rules; follow them rather than restating them here. In short: an
ordinary push needs no confirmation, since the commits were approved when they were made;
`git push -u origin HEAD` on the first push; and a confirmed `--force-with-lease` (never a bare
`--force`) for a branch whose commits have been rewritten.

Check the state before pushing:

```bash
git status -sb                                    # ahead/behind, or "no upstream"
git rev-list --count @{u}..HEAD 2>/dev/null       # commits not on origin
```

- **Nothing to push** (up to date with its upstream): say so in a line and carry on to step 3.
- **Unpushed commits, or no upstream yet**: push them, say so in a line, and carry on to step 3.
- **Branch has diverged from origin** (commits rewritten by a rebase or amend): that needs a
  force-push, so show the `--force-with-lease` command and ask once. If declined, carry on to step
  3 and don't ask again. The summary is still worth writing; just don't offer to create the PR at
  step 9, since the branch on origin would not match it.
- **Uncommitted changes in the working tree**: point them out rather than pushing over the top of
  them. They are either part of the ticket (they need a commit first, per `git-workflow`) or they
  are not (they stay out of the PR).

### 3. Identify the ticket and locate its note

Derive `TACO-XXXX` from the user's message or the branch name, then find
`<thread-folder>/index.md`.

Read its frontmatter: you need the `jira:` URL for the `## Jira Reference` section. If the note has no
`jira:` field, fall back to `https://keyframeai.atlassian.net/browse/TACO-XXXX`. If no note folder
exists, tell the user and ask whether to proceed (writing only to chat) or stop.

### 4. Derive the changes from git

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

### 5. Compose the PR title

Format:

```
[TACO-XXXX] <concise title>
```

- **The key is upper case and in square brackets**, `[TACO-3379]`, never `taco-3379` and never bare.
  The branch name is lower case; the PR title is not.
- **No `<type>:` prefix.** Commit messages take an optional `feat:`/`fix:` prefix, PR titles do not.
- Nothing between the closing bracket and the title but a single space. A ` - ` separator appears in
  some older PRs; it is not the convention to follow.
- Keep the title short and specific ("Send confirmation email on order completion", not "Changes for
  orders"). Aim for under ~72 characters total.

The title is **separate** from the summary: it is not repeated inside the description body.

### 6. Assess the context line and the risk level

Two sections sit above the summary bullets, and both are there for the reviewer rather than for the
record: a context reminder that says what area of the product this PR belongs to before they read a
single bullet, and a risk level that tells them how much care the review deserves. Each is a heading
with a single line under it, never a paragraph.

Both are derived from the diff resolved in step 4, not from the ticket's intent. A ticket described
as a tidy-up that turns out to touch a shared write path is assessed on what the diff does.

**Context**, the body of the `## Context` section. A few words naming the area the change belongs
to, not a restatement of the title. Think of it as the label a reviewer would file the PR under:
`Order confirmation emails`, `Spatial pipeline ingestion`, `Build and CI`,
`Internal developer tooling`. Three to six words, no verb, no trailing full stop.

**Risk**, the body of the `## Risk` section. One of four levels, followed by a short clause
justifying it.

| Level | What it means |
| --- | --- |
| `Zero` | No customer-visible surface at all: internal tooling, developer scripts, documentation, CI config, test-only changes, dead code removal. If it breaks, only the team notices. |
| `Low` | Customer-facing but narrowly scoped and trivially reversible: one endpoint, screen or job, additive behaviour, no shared code path and no change to stored data. A failure is contained and obvious. |
| `Medium` | Changes behaviour on a path customers actually use, or touches shared code with several callers. Covers additive schema changes, config changes to running services, and dependency upgrades with real API surface. A failure degrades a feature, not the platform. |
| `High` | Large blast radius: authentication, payments, data migrations that aren't trivially reversible, shared infrastructure, hot paths, or anything that could corrupt data or take a service down across many customers. A failure significantly impairs the platform or the customer experience, and rollback is slow or coordinated. |

Weigh the diff on five dimensions, then **take the highest level any single dimension reaches rather
than averaging them**. One migration in an otherwise cosmetic PR is still Medium.

- **Blast radius**: how many customers, surfaces or callers see this if it's wrong. A shared helper
  with twenty call sites is wider than one endpoint.
- **Reversibility**: does a revert and a redeploy undo it, or does undoing it need a backfill, a data
  fix or a coordinated release?
- **Data**: does it write, migrate, delete or reshape anything at rest? Changing stored data is
  Medium at least, and a migration that can't be replayed backwards is High.
- **Detectability**: would a failure surface immediately in errors and alerts, or sit quietly
  producing wrong results until a customer reports it? Silent failure raises the level.
- **Confidence**: is the change small, covered by tests and in familiar code, or a large edit to code
  nobody has touched in a year?

Round up when it's a close call. The level is a signal about how hard to look, and overstating it
costs a reviewer a few minutes where understating it costs an incident. Don't discount a level
because the change has been tested or sits behind a flag: note that in the justification instead.

The level leads the line and the justification follows it after a hyphen: one short clause, roughly
8 to 15 words, naming the reason rather than restating the level.

- Good: `Zero - repo-local tooling, nothing in this change ships to a customer`
- Good: `Low - additive send on one handler, no schema or shared-path change`
- Good: `Medium - shared notification method now parameterised, so SMS shares the email path`
- Good: `High - backfills the orders table in place, and a bad run needs a restore`
- Bad: `Low - low risk change`, which restates the level and tells the reviewer nothing.

### 7. Compose the PR description

The description body is what gets pasted into Azure DevOps. ALWAYS use this exact structure:

```
## Context
<a few words>

## Risk
**<Zero|Low|Medium|High>** - <short justification>

## Jira Reference
<jira-url>

## Summary
- <high-level change>
- <high-level change>
- <high-level change>
```

- **Four `##` sections, always in this order**: `## Context`, `## Risk`, `## Jira Reference`,
  `## Summary`. A blank line between each section and the next. Context comes first because it is
  what orients a reviewer who opens the PR cold.
- `## Context` and `## Risk` carry the values worked out in step 6, **one line of body each**. They
  are a signal at a glance, and a paragraph under either heading defeats the point.
- `## Jira Reference` holds the bare URL on its own line, nothing else: no label, no link text.
- `## Summary` is the only section with bullets. They cover the changes made, high-level. Aim for
  roughly 3–6, and lead with the most significant change.
- Do **not** add sections beyond these four: no testing notes, "how to test", screenshots,
  rollout/flag notes, or file-by-file detail. If a change is only a supporting detail of a larger
  one, fold it into that bullet rather than giving it its own.

**Default detail level.** Each bullet names what changed _plus a short clause of mechanism or why_:
roughly 15–25 words. The aim is enough for a reviewer to understand the change without opening the
diff, but no more. Avoid bare one-liners that just name a method or file, and equally avoid
sprawling bullets that drift into implementation play-by-play.

- Good: `Adds SendOrderConfirmationAsync to the Notifications client, which posts the order summary to the notification service's email endpoint`
- Too thin: `Adds a new client method`, which names the change but gives the reviewer nothing to go on.
- Too much: a bullet that walks through the method body, parameters, and HTTP headers line by line.

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

- Good: `Adds an order-confirmation method to the Notifications client`
- Good: `Updates order status to Completed when payment settles, alongside the existing receipt write`
- Good: `Parameterises the shared notification method by channel (email and SMS)`
- Bad: `Added ...` / `Called it from ...` / `Wired up ...`: past-tense narration reads like a personal
  changelog of what _you_ did, and "it" referring back to a previous bullet is informal and unclear.
- Bad: `I added ...` / `We updated ...`: never first person.

Each bullet should stand on its own without depending on a previous bullet for a pronoun like "it".

### 8. Write to the ticket note and echo in chat

Append a new `## Pull Request` section to the **end** of `index.md`. Put the title and the
description in fenced code blocks so they copy cleanly and the description's own `##` headings don't
fragment the note's heading outline:

````markdown
## Pull Request

**Title**

```
[TACO-1234] Send confirmation email on order completion
```

**Description**

```markdown
## Context
Order confirmation emails

## Risk
**Low** - additive send on one handler, no schema change and no shared write path

## Jira Reference
https://keyframeai.atlassian.net/browse/TACO-1234

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

Stamp `updated:` to today, per `obsidian`. Leave the rest of the frontmatter alone, `prs:` and
`status:` included: the PR doesn't exist yet, the URL is the user's to add, and the status moves
only once the PR is raised (step 9).

### 9. Offer to create the PR on Azure DevOps

Having written the summary, offer to raise the PR with those fields already filled in. Work out the
auto-complete decision below **before** asking, so the question names what will actually happen and
one answer covers the whole thing:

> "Want me to create the PR on Azure DevOps with this title and description, set to auto-complete?"

> "Want me to create the PR on Azure DevOps with this title and description? Leaving auto-complete
> off, since <the impediment>."

If they decline, stop: the summary in the note and in chat is the deliverable.

Creating a PR is outward-facing and visible to the team, so **always show the resolved command and
wait for approval before running it**. Never create one unasked.

#### Auto-complete

Azure DevOps can hold the PR and merge it the moment its branch policies pass. **Default to turning
it on when the change can merge on its own and the risk line from step 6 is `Zero` or `Low`.** A
small, reversible change that has nothing standing in its way shouldn't wait on someone noticing it
in a queue.

Auto-complete doesn't bypass anything: branch policies, required reviewers and build gates all still
have to pass, and the PR simply sits there until they do. That is what makes it a safe default on
the low end of the risk scale rather than a shortcut.

Leave it **off** when any of these hold, and say which one in the same line that offers the PR:

- **The risk is `Medium` or `High`.** These want a human deciding the moment of merge.
- **The PR is a draft**, which includes every branch cut from an unmerged base. Azure DevOps won't
  auto-complete a draft, so the two flags don't go together.
- **The branch doesn't merge cleanly into master.** Check rather than assume:
  ```bash
  git fetch origin master --quiet
  git merge-tree --write-tree origin/master HEAD >/dev/null 2>&1 \
    && echo "merges cleanly" || echo "conflicts with master"
  ```
- **Review findings from step 1 were consciously left unfixed**, or the diff is waiting on anything
  else: a coordinated deploy, a config change landing first, a decision the ticket's notes record as
  still open.
- **The user has said they want eyes on it** before it merges. Their call beats the default, and it
  holds for the rest of the session without being asked again.

When it is off for a reason that will clear (a conflict to rebase away, a base branch still to
merge), say so in a line rather than silently dropping it. Turning auto-complete on afterwards is a
click in the PR, and the user can decide when.

#### The command

`az` with the `azure-devops` extension does the work. Derive the org, project and repository from the
`origin` remote rather than hardcoding them, and the source branch from the current branch:

```bash
az repos pr create \
  --org https://dev.azure.com/keyframe-ai \
  --project KeyframeAI \
  --repository <repo> \
  --source-branch "$(git branch --show-current)" \
  --target-branch master \
  --title "[TACO-XXXX] <title>" \
  --description "<the description body>" \
  --auto-complete true \
  --open
```

Points that matter:

- **`--target-branch master` always**, unless the user has explicitly said otherwise. It is never the
  branch the work was cut from. See `git-workflow`.
- **The branch must already be on origin** (step 2). `az` fails on a source branch the remote
  doesn't have.
- **`--auto-complete true`** per the decision above. Drop the flag entirely when it is off rather
  than passing `false`.
- **`--draft`** replaces `--auto-complete true` whenever the work is not ready to merge, which
  includes every branch still waiting on an unmerged base. The two are mutually exclusive. Add the
  fork note to the description in that case:
  `Branched from TACO-1200. Will require a rebase once that has merged.`
- **Don't add `--squash` or `--delete-source-branch`** unless the user asks. The repository's policy
  owns the merge strategy, and auto-complete follows it.
- **`--open`** opens the created PR in the browser, which is usually what the user wants next.
- Report the PR id and URL back, say whether auto-complete is set, and leave `prs:` in the note for
  the user to fill in.

Once `az` reports the PR created, move the thread to `review` per the lifecycle in `obsidian`: set
`status:` to `review` if it is `planned` or `coding`, and leave `paused`, `dropped` or a status
already at `review` or `done` alone. If the user declines or the PR is raised by hand, leave the
status too; `sweep-threads` picks it up.

If `az` is missing, not logged in, or the extension is absent, say so plainly and fall back to the
copy-paste flow rather than trying to work around it.

## Finishing up

Raising the PR ends the ticket's work, so this is the natural place to suggest a `/clear` before the
next one starts. Nothing needs carrying forward: everything this skill produced is in the note, and
everything the next ticket needs is in its own thread folder. Re-running `track-session` after the
clear keeps the session log pointing at the live conversation.

The same holds on the way in. This skill derives the summary from the branch diff and the thread's
notes, not from the conversation, so it runs perfectly well in a context that knows nothing about
how the code got written. Don't ask the user to clear mid-skill though: the review at step 1 belongs
to this run, and clearing partway through loses the skill's own place in the workflow.

## What not to do

- Don't pad the summary with testing notes, rollout steps, or file-by-file detail. It's a
  high-level overview of changes only.
- Don't drop the `## Context` or `## Risk` section, reorder the four sections, or grow either of
  those two into a paragraph. One line of body each, above the summary.
- Don't soften the risk level because the author (or you) wrote the change. It is assessed from what
  the diff can break, not from how confident anyone feels about it.
- Don't repeat the title inside the description, and don't let the context line become a second
  copy of it.
- Don't assume the diff base is `master`. Resolve it, honouring `forkedFrom` on a stacked branch.
- Don't invent changes that aren't in the diff, or omit a significant one because it wasn't in a
  commit message. The diff is the source of truth.
- Don't write the summary from a diff a review is about to change: offer the review first (step 1),
  and regenerate the summary if the review changes anything.
- Don't touch the frontmatter beyond `updated:` and, once the PR is raised, `status:`. Don't add
  the PR URL to `prs:`: that is the user's to add once the PR exists.
- Don't force-push without asking, and don't offer to create the PR on a branch that isn't on
  origin: it will fail.
- Don't create the PR without asking, and never without showing the resolved command first.
- Don't set auto-complete on a `Medium` or `High` risk change, on a draft, or on a branch that hasn't
  been checked for a clean merge. Equally, don't leave it off on a `Zero` or `Low` change with
  nothing in its way: that is the default, not an upgrade to ask for.
- Don't hard-wrap prose in the note.
- Don't restate the vault conventions here or diverge from them: they are owned by `obsidian`.
