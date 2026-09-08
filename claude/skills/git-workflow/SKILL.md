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

All cloned repositories live in `/home/tim/code`.

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

New branches must be created using `git worktree add`, and the command **must be run from inside the `.bare` folder** of the repo.

```bash
cd /home/tim/code/<repo-name>/.bare
git worktree add ../<branch-name>
```

### Branch Naming Rules

- Branches **must** be prefixed with a Jira ticket key, written in **lower case**. The typical
  prefix is `taco` (e.g. `taco-1234`), never `TACO-1234`.
- Optionally (and preferably) include a short description after the ticket key: `taco-1234-fix-xyz`
- The description suffix is not required but is encouraged for clarity.

### Always confirm the branch name with the user before creating it.

Example flow:

> "I'm going to create branch `taco-1234-add-payment-button`. Does that look right?"

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
| Add a new branch | `cd /home/tim/code/<repo>/.bare && git worktree add ../<branch-name>`        |
| Commit           | Confirm the message with the user first, then `git commit -m "<message>"`   |

---

## Key Reminders

1. **Never create a branch without confirming the name first.**
2. **Branch name ticket prefixes must be lower case**: `taco-1234-fix-xyz`, never `TACO-1234-fix-xyz`.
3. **Never commit without confirming the message first.**
4. `git worktree add` must always be run from inside the `<repo>/.bare` directory.
5. **Never include a "Co-Authored-By" trailer (or any variation) referencing Claude/AI in commit messages.**
6. **Never put a `[TACO-1234]` ticket reference in a commit message**: the branch and PR title carry it.

---

## Not using worktrees?

The worktree layout above is a preference, not a requirement: it keeps every branch of a repo
checked out side by side under `/home/tim/code/<repo>/`. If you'd rather use ordinary clones and
`git checkout -b`, delete the "Cloning a New Repo" and "Creating a New Branch (Worktree)" sections
and keep everything else. The branch-naming, commit-message and confirmation rules are the part that
matters.
