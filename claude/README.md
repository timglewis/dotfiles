# Claude Code configuration

## What is symlinked

```
~/.claude/CLAUDE.md     -> claude/CLAUDE.md
~/.claude/statusline.sh -> claude/statusline.sh
```

Both are live: editing them here changes the running configuration. The skills are live too,
but they are linked one at a time rather than as a directory. Run `claude/link.sh` to set them
up, and again after adding or renaming one.

## Why the skills directory is not itself a symlink

`~/.claude/skills` is the only place Claude Code reads user skills from, and this repo is not
its only writer. Claude Code syncs Anthropic's own skills into `synced/` underneath it, and the
vercel-labs `skills` CLI installs third-party ones as siblings. Pointing the whole directory at
this repo made all of that land in version control, which is what the old
`claude/skills/synced/` ignore rule was papering over.

So `~/.claude/skills` is a real directory owned by nobody in particular, and `link.sh` puts one
symlink in it per skill in `claude/skills/`. Third-party skills sit alongside them and never
touch this repo:

```
~/.claude/skills/
├── coding-style -> ~/code/dotfiles/claude/skills/coding-style
├── ...
├── web-design-guidelines/    installed by the skills CLI
└── synced/                   written by Claude Code
```

`link.sh` removes a link whose target has gone, so a skill renamed or deleted here does not
leave a broken one behind. It only ever touches links into this repo, so anything installed by
another tool is left alone.

## Adapting the skills to another setup

The skills assume Jira, Azure DevOps and a bare-repo worktree layout. Two of those are easy to
strip out:

* **No Jira.** Delete step 2 of `start-thread` and the ticket-fetch bullet in step 1 of
  `investigate`. Both then work from the title and description the user gives, and nothing
  downstream depends on the fetch.
* **No worktrees.** In `git-workflow`, delete "Cloning a New Repo" and "Creating a New Branch
  (Worktree)" and use ordinary clones with `git checkout -b`. The branch-naming, commit-message
  and confirmation rules are the part that matters.

## Third-party skills

Install them with the vercel-labs CLI, which writes into `~/.claude/skills` directly:

```
npx skills add --global --agent claude-code <source>
```

Its own record of what is installed lives in `~/.agents/.skill-lock.json`, outside version
control, so add the source to `claude/third-party-skills.txt` as well. That file is what a new
machine is rebuilt from: `link.sh` reads it and installs everything listed.

## settings.json is a reference copy, not a symlink

`claude/settings.json` records the hooks, the git permission allowlist and the display
preferences so they can be rebuilt on a new machine. It is **not** linked to
`~/.claude/settings.json`, so changes here do nothing until they are copied across by hand.

It cannot be linked, because the real user settings file has to hold the `autoMode` block, and
that block names the organisation, its Azure DevOps remote, its container registry, the paths
holding secrets and the protected Terraform scopes. This repo is public. `autoMode` is valid
only at user or managed scope, so there is nowhere else on the user tier to put it.

When copying this file onto a new machine, add the `autoMode` block afterwards and leave it out
of any commit. Anything naming an employer, a host, a registry or a branch stays out of this
repo.

## ~/.claude/settings.local.json is not read

Claude Code 2.1.277 reads five settings sources, and the only `settings.local.json` among them
is the project-level `.claude/settings.local.json`. A `settings.local.json` in the home
directory is inert: a model set there does not override the one in `settings.json`. It is not a
place to hide anything, and the file that exists there is a leftover from an older version.
