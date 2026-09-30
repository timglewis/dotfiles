---
name: implement
description: >
  Build a ticket from its commit-breakdown.md, one planned commit at a time: make the change,
  build and test it, confirm the message, commit and push, record the commit in the plan, then
  stop until the user says to carry on. Use whenever the user says "implement TACO-XXXX", "start
  the commits", "build this ticket", "do commit 1", "next commit", "carry on with the plan",
  "pick up where we left off on TACO-XXXX", or anything similar asking for planned work to be
  written. Follows commit-breakdown, and hands over to pr-summary after the last commit.
---

# Implement Skill

Turns the plan in `commit-breakdown.md` into commits on the ticket's branch, **one commit per run
of the loop, stopping after each one**. The plan was settled upstream by `investigate` and
`commit-breakdown`, so this skill builds it rather than redesigning it: when the code disagrees with
the plan, it stops and asks instead of quietly doing something else.

```
investigate → commit-breakdown → implement → pr-summary
```

## Locating the thread

**Invoke `obsidian` first.** It owns where thread folders live, how to find one, and how notes
are written. Don't reconstruct any of it from memory.

**Invoke `git-workflow` as well.** It owns commit messages, pushing and the branch rules, and this
skill commits and pushes on every loop. Code shape needs no explicit load: the `coding-style` hook
injects the rules that apply on every edit.

## Inputs

- Ticket key: `TACO-XXXX`, from the user or inferred from the branch name
- `<thread-folder>/commit-breakdown.md`, the plan and the progress record
- `<thread-folder>/investigation.md`, for the detail a commit block points back to
- The current worktree, which must be the ticket's branch

## Workflow

### 1. Check the ground before touching anything

- **The branch.** The current branch must be the ticket's (`taco-1234-...`). On `master`, or on
  another ticket's branch, stop and say so: `start-work` or `git-workflow` makes the right one.
- **The working tree.** Uncommitted changes that aren't the start of the next planned commit
  (say, from an earlier session that stopped mid-commit) need the user's call before building on
  top of them. If they are that commit's work, say so and carry on from there.
- **The plan.** If `commit-breakdown.md` is missing, suggest `commit-breakdown` and stop. If
  `investigation.md` still has open questions marked as affecting scope, point them out before
  starting.
- **The status.** If the index note's `status:` is `planned`, set it to `coding` per the lifecycle
  in `obsidian`.

### 2. Find the next commit

Each finished commit carries a `**Done:**` line in its block (step 7). The next commit is the first
block without one.

Cross-check against the branch rather than trusting the plan alone, since a commit may have been
made by hand:

```bash
BASE=$(git config branch."$(git branch --show-current)".forkedFrom 2>/dev/null || echo origin/master)
git log --reverse --pretty='%h %s' "$BASE"..HEAD
```

A commit on the branch whose subject matches a planned message but whose block has no `**Done:**`
line gets one backfilled. A commit on the branch that matches nothing in the plan is worth a line
to the user, not a guess about which block it covers.

Say which commit is next, by number and short name, before starting it.

### 3. Build the commit

Work from the commit's block: its files, its "What needs to happen" and its "How it fits". Read
the files it names before editing them, and go back to `investigation.md` where the block refers
to something it explains.

Stay inside the commit. Work that belongs to a later commit waits for it, even when it would be
easy to do now, because the plan's order is what keeps each commit building and passing on its
own. Something unrelated that looks wrong gets a line in the report at step 6, not a fix.

### 4. When the code disagrees with the plan, stop

The investigation was written before any code changed, so it will sometimes be wrong: a file isn't
where it said, a method has callers it didn't list, a commit turns out to need splitting, or two
commits can't be separated. Don't absorb the difference silently. Stop and ask, saying what the
plan expected, what the code actually shows and what you'd do instead.

Once the user agrees, **rewrite the affected commit blocks in `commit-breakdown.md`** before
carrying on, so the plan stays true for the rest of this run and for any later session. A new
commit gets its own block with a message per `git-workflow`; later blocks are renumbered.

A small detail the plan didn't spell out (a parameter name, which overload to call) is not a
disagreement. Decide it the way `coding-style` and the surrounding code suggest.

### 5. Check it builds and its tests pass

Work out the repo's commands once per session, from its own docs (`CLAUDE.md`, `README`) first and
the project files second (`*.sln` or `*.csproj`, `package.json` scripts, `*.tf`). Typical shapes:

| Repo | Build or typecheck | Targeted tests |
| --- | --- | --- |
| .NET | `dotnet build` | `dotnet test --filter "FullyQualifiedName~<Class>"` |
| Front end | the `typecheck` or `build` script | the test script, passed the file under change |
| Terraform | `terraform fmt -check` and `terraform validate` | none, usually |

- **Build often**, after each meaningful edit rather than once at the end, so a failure points at
  the edit that caused it.
- **Run the tests for the area** the commit touches, including any it adds. Each commit must build
  and pass on its own, which is what `commit-breakdown` promised.
- **Run the full suite once, before the last commit** in the plan. Earlier commits don't need it.
- **Skipped is not passed.** Worktrees hold only what git tracks, so a test that reads a
  gitignored file (`appsettings.Development.json`, user secrets, a local database) can skip itself
  and still report green. If tests in the area under change were skipped, say which and why rather
  than calling the run clean.

A failure caused by the commit gets fixed inside the commit. A failure that was already there on the
base branch gets reported, not fixed: check that with a quick run on a clean checkout of the base
only if it isn't obvious from the failure.

### 6. Report, then confirm the message

This is the review point, while the change can still be reshaped cheaply. Report in a few lines:

- what changed, by file, in a line each
- the build and test results, with the counts, and any skipped tests in the area
- anything that differed from the plan (already agreed at step 4) or that looked wrong nearby

Then ask for the message from the plan, per `git-workflow`:

> "Commit 2 is ready: `Add PaymentStatus enum to domain model`. Commit and push with that message?"

The user may want to look at the working tree first, reword the message or change the code. Do
whatever they ask and come back to the same question.

### 7. Commit, push and record

On approval, commit and push per `git-workflow`: the approval covers the push, and the first push
of the branch sets its upstream.

Then record the commit in its block in `commit-breakdown.md`, straight under the `**Message:**`
line:

```markdown
**Done:** `3fa11d0`
```

If the message was reworded at step 6, update the block's `**Message:**` line to the one actually
used. Stamp `updated:` in the index note, per `obsidian`.

### 8. Stop

**End the turn here after every commit.** Say what was committed and which commit comes next:

> "Commit 2 is pushed (`3fa11d0`). Next is commit 3, wire StatusMapper into the handler. Say when
> to carry on."

Don't start the next commit until the user says to, even when it looks trivial. Carrying on is
their call, made after looking at what just landed. When they say to, go back to step 2.

## After the last commit

When every block has a `**Done:**` line, the build is finished. Say so, and point at `pr-summary`
as the next step: it offers `spec-review`, `/code-review` and `semgrep-review` over the branch
before writing the summary, which is where `commit-breakdown`'s closing footer sends the work.

Give a verdict on clearing first, per "Clearing at a handoff" in `obsidian`. The reviews work from
the diff and the thread's notes, so a clear usually wins after a build of more than a commit or
two.

## Picking up in a fresh session

Everything this skill needs is on disk: the plan, the `**Done:**` lines and the branch. A new
session starts at step 1 and finds its place at step 2. That is also why the plan has to be kept
true at step 4: a session that clears after commit 3 builds commit 4 from what the plan says.
