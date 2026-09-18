# Claude Code configuration

## What is symlinked

```
~/.claude/CLAUDE.md     -> claude/CLAUDE.md
~/.claude/skills        -> claude/skills
~/.claude/statusline.sh -> claude/statusline.sh
```

Those three are live: editing them here changes the running configuration.

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
