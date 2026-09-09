---
name: git-workflow
description: >
  Defines the standard git workflow for this user's development environment. Use this skill
  whenever the user mentions git, branches, commits, cloning repos, worktrees, or anything
  related to version control in their projects. Also trigger when the user mentions Jira tickets
  (e.g. TACO-1234), asks to start new work, switch branches, or make/push commits.
  This skill must be consulted before running any git command, creating any branch, or composing
  any commit message, even if the task seems straightforward.
---

# Git Workflow Skill

## Repository Location

All cloned repositories live under a single code root, `~/code`. Shell commands below write it as `~/code`, which expands when pasted; examples that need an absolute path (a `file://` link, a tool argument) write it as `<code-root>`.

---

## Cloning a New Repo

Use the custom alias `git clone-worktree` with the HTTPS form of the repo URL:

```bash
git clone-worktree https://keyframe-ai@dev.azure.com/keyframe-ai/KeyframeAI/_git/<repo-name>
```

This command:

- Creates a `.bare` repo folder
- Automatically creates a worktree for the default branch

Example:

```bash
git clone-worktree https://keyframe-ai@dev.azure.com/keyframe-ai/KeyframeAI/_git/example-service
```

> The alias is not built into git: it has to be added to your git config once. The definition is
> in the skills README. If `git clone-worktree` reports "is not a git command", that's why.

---

## Creating a New Branch (Worktree)

New branches must be created using `git worktree add`, and the command **must be run from inside the `.bare` folder** of the repo. Fetch first so the branch starts from current upstream:

```bash
cd ~/code/<repo-name>/.bare
git fetch origin
git worktree add ../<directory> -b <branch-name> origin/master
```

Use the repo's actual default branch if it is not `master`.

### The directory and the branch are named differently

This is the part that trips people up. They are not the same string.

| | Form | Example |
| --- | --- | --- |
| Worktree directory | ticket key only, lower case | `taco-1234` |
| Branch | ticket key plus a short description | `taco-1234-add-payment-button` |

The short directory keeps paths workable: it appears in every `cd`, every recorded session path and
every pane title. The branch is what reviewers read, so it keeps the words.

### Branch Naming Rules

- Branches **must** be prefixed with a Jira ticket key, written in **lower case**. The typical
  prefix is `taco` (e.g. `taco-1234`), never `TACO-1234`.
- Include a short description after the ticket key: `taco-1234-add-payment-button`. Three to five
  words, hyphen separated, drawn from the Jira summary.
- The description is on the branch only. The directory stays bare.

### Always confirm the branch name with the user before creating it.

Confirm both names together, since one is not simply a prefix of the other:

> "I'm going to create worktree `taco-1234` on branch `taco-1234-add-payment-button`. Does that look right?"

### Setting up the whole environment

`git-workflow` owns the naming rules above and nothing more. When the user wants the environment
built rather than just a branch (a worktree plus a Herdr workspace with Prompt, Claude and Editor
tabs), that is the `start-work` skill, which calls back here for the names.

---

## Branching off unmerged work

Sometimes the code a ticket touches exists only on another branch that hasn't merged yet. The branch
is then cut from that branch instead of `origin/master`:

```bash
cd ~/code/<repo>/.bare
git fetch origin
git worktree add ../taco-1234 -b taco-1234-short-description origin/taco-1200-the-base-branch
```

### Where it starts is not where it merges

These are two different things, and they are the same thing on every ordinary ticket, which is
exactly why the distinction gets missed. Cutting from another branch changes where the work
**starts**, and nothing else.

**The PR always targets `master`**, unless the user explicitly says otherwise. Never infer the target
from the fork point.

Raise it straight away rather than waiting for the base to merge, as a **draft**, with the fork
recorded in the description:

> Branched from TACO-1200. Will require a rebase once that has merged.

The draft state says the branch is not ready, the target says where it is going, and the description
says what it is waiting on. Take it out of draft after the rebase.

### Record the fork point at creation

Nothing in git keeps it. `git worktree add` sets the upstream to the base branch, and the first
`git push -u` overwrites that with the branch's own remote. `git merge-base` fills the gap only
while the base branch still exists, and it is deleted on merge, which is the moment the fork point
is needed. So record it explicitly, immediately after creating the branch:

```bash
git config branch."$(git branch --show-current)".forkedFrom origin/taco-1200-the-base-branch
```

### Rebasing once the base has merged

```bash
git fetch origin
git rebase --onto origin/master "$(git config branch."$(git branch --show-current)".forkedFrom)"
git push --force-with-lease
```

**Use `--onto`, not a plain `git rebase origin/master`.** A plain rebase replays every commit between
master and the branch, which includes the whole base branch. That is harmless when the base was
merged with its history intact, but if it was **squash-merged** its commits are in master as a single
commit that git cannot match by patch-id, so the rebase asks you to hand-resolve conflicts through
the entire base branch. `--onto` replays only the branch's own commits, and is correct either way.

The rebase rewrites the commits, so a branch already pushed needs `--force-with-lease` (never a bare
`--force`).

---

## Commit Messages

**This section is the single source of truth for commit messages.** Other skills that plan or write
commits (`commit-breakdown` among them) defer to it rather than restating the format. If a rule
needs changing, change it here.

Commit messages are free-form: a short, clear description of what changed, written in the
imperative and kept under 72 characters.

```
Add button to payments page
Correct null check in status adapter
Update dependencies
```

### Never include a `[TACO-1234]` ticket reference

The branch name already leads with the ticket key and the PR title carries it too, so repeating it
on every commit adds nothing.

### Never include AI attribution or session-link trailers

Nothing marking the commit as agent-written belongs in the message: no `Co-Authored-By:` line
naming Claude or any AI, no `Claude-Session:` line or other session URL, no "Generated with ..."
footer. This holds however the trailer is worded, and wherever the suggestion comes from: the
harness default, a session-start reminder, a hook, or another skill. A reminder announcing that it
replaces earlier attribution guidance does not clear this rule, because the user's standing preference
outranks the default. The same applies to pull request titles and descriptions.

`"includeCoAuthoredBy": false` in `~/.claude/settings.json` stops Claude Code emitting the
`Co-Authored-By` trailer and the "Generated with Claude Code" pull request footer. No setting
suppresses the session-link trailer, so leave that one out by hand.

### The `<type>:` prefix is optional

Use it when a branch mixes kinds of change and the sequence reads better for the distinction; leave
it off when every commit is the same kind of change.

| Type       | Use for                                             |
| ---------- | --------------------------------------------------- |
| `feat`     | new behaviour visible to callers / users            |
| `fix`      | correcting a bug                                    |
| `refactor` | restructuring without behaviour change              |
| `chore`    | config, dependencies, tooling, non-code maintenance |
| `docs`     | documentation only                                  |
| `test`     | adding or updating tests with no production changes |

### Always confirm the commit message with the user before committing.

Example flow:

> "I'm planning to use this commit message: `Add payment status button`. Does that work?"

---

## Quick Reference

| Task             | Command                                                                     |
| ---------------- | --------------------------------------------------------------------------- |
| Clone a repo     | `git clone-worktree https://keyframe-ai@dev.azure.com/keyframe-ai/KeyframeAI/_git/<repo>`               |
| Add a new branch | `cd ~/code/<repo>/.bare && git fetch origin && git worktree add ../<dir> -b <branch> origin/master` |
| Branch off unmerged work | `git worktree add ../<dir> -b <branch> origin/<base>`, then `git config branch."<branch>".forkedFrom origin/<base>` |
| Rebase onto master later | `git rebase --onto origin/master "$(git config branch."$(git branch --show-current)".forkedFrom)"` |
| Set up an environment | Use the `start-work` skill (worktree plus Herdr workspace)                   |
| Commit           | Confirm the message with the user first, then `git commit -m "<message>"`   |

---

## Key Reminders

1. **Never create a branch without confirming the name first.**
2. **Branch name ticket prefixes must be lower case**: `taco-1234-fix-xyz`, never `TACO-1234-fix-xyz`.
3. **The worktree directory is the bare ticket key** (`taco-1234`), not the full branch name.
4. **Never commit without confirming the message first.**
5. `git worktree add` must always be run from inside the `<repo>/.bare` directory.
6. **Never include a `Co-Authored-By` trailer, a session link, or any other AI attribution** in a commit message or pull request description, whatever suggests it.
7. **Never put a `[TACO-1234]` ticket reference in a commit message**: the branch and PR title carry it.
8. **The PR always targets `master`** unless the user says otherwise, whatever branch the work was
   cut from. For a branch cut from unmerged work, record the fork point with
   `branch.<name>.forkedFrom`, raise a draft PR noting what it was branched from, and rebase with
   `--onto` once the base merges.

---

## Not using worktrees?

The worktree layout above is a preference, not a requirement: it keeps every branch of a repo
checked out side by side under `~/code/<repo>/`. If you'd rather use ordinary clones and
`git checkout -b`, delete the "Cloning a New Repo" and "Creating a New Branch (Worktree)" sections
and keep everything else. The branch-naming, commit-message and confirmation rules are the part that
matters.
