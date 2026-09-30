---
name: spec-review
description: >
  Review the current branch along two separate axes: Standards (does the diff follow the user's
  coding-style rules, the repo's own documented conventions and a baseline of code smells?) and
  Spec (does it deliver what the Jira ticket and the thread's investigation asked for, no more and
  no less?). Runs each axis in its own subagent and reports them side by side. Use whenever the
  user says "spec review", "review against the ticket", "does this match the ticket", "check this
  against the spec", "did I miss anything from the ticket", "standards review", "check this follows
  my coding style", or anything similar. It does not hunt for correctness bugs: that is the
  built-in `/code-review`, which this complements rather than replaces.
---

# Spec Review Skill

A two-axis review of what this branch changed:

- **Standards**: does the code follow the user's coding style and the repo's documented conventions?
- **Spec**: does the code deliver what the ticket asked for?

Each axis runs in its own subagent so neither sees the other's reasoning, and the two reports are
never merged or ranked against each other.

## Where this sits

| Pass | Finds |
| --- | --- |
| `/code-review` | Correctness bugs, reuse, simplification |
| `spec-review` (this) | Style and convention breaches, code smells, missing or unrequested behaviour |
| `semgrep-review` | Known-shape vulnerabilities and leaked credentials |

Run it from a fresh session where possible. The session that wrote the code holds every
assumption that shaped it, which is exactly what an independent review should not have.

## Process

### 1. Pin the fixed point

The diff is everything this branch added on top of where it started. Take the fixed point from the
first of these that applies:

1. A ref the user named.
2. `branch.<name>.forkedFrom`, set by `git-workflow` on a branch cut from unmerged work:
   `git config branch."$(git branch --show-current)".forkedFrom`
3. `origin/master`, or the repo's default branch if it is not `master`.

Fetch first (`git fetch origin`) so the fixed point is current. Capture the diff command once as
`git diff <fixed-point>...HEAD` (three dots, so the comparison is against the merge-base) and the
commit list as `git log <fixed-point>..HEAD --oneline`.

Confirm the ref resolves (`git rev-parse <fixed-point>`) and the diff is non-empty before going
further. A bad ref or an empty diff should fail here, not inside two subagents.

### 2. Gather the spec

The ticket key is the prefix of the branch name (`taco-1234-...` is `TACO-1234`). Gather, in
parallel:

- **The Jira ticket**, through the interface `~/.claude/skills/jira-ticket/references/interface.md`
  selects: summary, description, acceptance criteria and comments.
- **The thread folder**, located per `obsidian`. Read `investigation.md` for the agreed approach
  and `commit-breakdown.md` for the planned scope, where they exist. The ticket says what was asked
  for; these say what was agreed since, and a decision recorded there overrides the ticket's
  original wording.
- **A path the user passed**, if any, which takes the place of all of the above.

If the branch has no key and the user gave no path, ask where the spec is. If there is none, skip
the Spec subagent and say "no spec available" in the report rather than inventing requirements.

### 3. Gather the standards

In order of precedence, highest first:

1. **The repo's own documentation**: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`,
   `CODING_STANDARDS.md` and anything similar at the root or under `docs/`.
2. **The user's coding style**: `~/.claude/skills/coding-style/rules/core.md`, plus the fragment
   for each language the diff touches, per the table in `coding-style`. The edit hook never fires
   on a read-only pass, so read them directly.
3. **The smell baseline** below, which applies even when nothing else is documented.

A higher source always wins over a lower one: where the repo or the coding style endorses
something the baseline would flag, suppress the smell. Skip anything tooling already enforces.

Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Each reads
*what it is* then *how to fix*:

- **Mysterious Name**: a function, variable or type whose name doesn't reveal what it does or holds. Rename it; if no honest name comes, the design is murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. Extract the shared shape and call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. Move the method onto the data it envies.
- **Data Clumps**: the same few fields or parameters keep travelling together. Bundle them into one type and pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. Give the concept its own small type.
- **Repeated Switches**: the same `switch` or `if` cascade on the same type recurs across the change. Replace it with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. Gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. Split it so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters or hooks added for needs the spec doesn't have. Delete it and inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. Hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. Cut it and call the real target directly.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. Drop the inheritance and use composition.

### 4. Spawn both subagents in parallel

Use two `general-purpose` agents in a single message. Each prompt must be self-contained, since
neither has access to this skill, and each must end with the guard below. Without it a subagent can
rediscover a review skill and fan out again, which upstream has seen reach 50 agents:

> Do not invoke `spec-review`, `/code-review` or any other skill, and do not spawn additional
> agents: perform this review directly.

**Standards subagent** gets:

- The diff command and commit list.
- The paths of the repo documentation and coding-style fragments from step 3, the precedence
  rule, and the smell baseline pasted in full.
- The brief: "Report, per file and hunk where relevant, (a) every place the diff breaches a
  documented standard, citing the file and the rule; and (b) any baseline smell you spot, naming
  it and quoting the hunk. Documented breaches can be hard violations; baseline smells are always
  judgement calls, and a documented standard overrides the baseline. Skip anything tooling
  enforces. Under 400 words."

**Spec subagent** gets:

- The diff command and commit list.
- The ticket's content and the paths of `investigation.md` and `commit-breakdown.md`, or the path
  the user gave.
- The brief: "Report (a) requirements that are missing or only partly delivered; (b) behaviour in
  the diff that nothing asked for (scope creep); (c) requirements that look delivered but where the
  implementation looks wrong. Quote the ticket or note line for each finding. Where the
  investigation or commit breakdown records a decision that changes the ticket's original ask,
  judge against the decision. Under 400 words."

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned.
Do not merge or rerank the findings.

End with one line: the number of findings on each axis and the worst issue *within* each. Don't
pick a single winner across the axes, because a change can pass one and fail the other: code that
follows every convention while delivering the wrong thing, or code that does exactly what the
ticket asked while breaking the conventions. A blended verdict lets the passing axis hide the
failing one.

Offer to fix what the user picks. A fix is committed and pushed like any other commit, per
`git-workflow`.

## Upstream

Forked from `skills/engineering/code-review` in
[mattpocock/skills](https://github.com/mattpocock/skills) at commit `5c89081d`. Renamed so it does
not shadow the built-in `/code-review`, and adapted to find the spec in Jira and the vault rather
than GitHub issues, to read `coding-style` as a standards source, to default the fixed point
instead of asking for one, and to guard the subagents against recursion. To pick up upstream
changes, diff that path against `5c89081d` and port what applies by hand.
