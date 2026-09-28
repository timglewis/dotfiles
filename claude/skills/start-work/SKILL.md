---
name: start-work
description: >
  Set up somewhere to do the work: a git worktree plus a Herdr workspace with Prompt, Claude and
  Editor tabs. Use whenever the user says "set up the environment for TACO-XXXX", "create a
  worktree for TACO-XXXX", "make me a workspace for TACO-XXXX", "set me up for this ticket", "get
  me an environment for TACO-XXXX", or otherwise asks for somewhere to do the work rather than
  somewhere to keep notes. Usually follows start-thread. Requires HERDR_ENV=1.
---

# Start Work Skill

Creates the place the work actually happens: a git worktree for the branch, and a Herdr workspace
holding three tabs pointed at it.

`start-thread` gives a piece of work somewhere to keep notes. This skill gives it somewhere to type.
The two are independent: a thread is useful without a worktree, and a worktree is useful on a ticket
whose notes already exist.

## Where this sits

```
"start TACO-3372"
      |
      v
  start-thread ....... vault notes, index.md          (owns the thread folder)
      |  step 7
      v
  start-work ......... worktree + config + workspace  (this skill)
      |
      +--> git-workflow ..... branch naming rules     (owns the branch name)
      +--> herdr ............ CLI syntax              (owns the commands)
```

Never restate branch-naming or commit-message rules here. `git-workflow` is the single source of
truth for both; this skill proposes a name under those rules and asks it to be confirmed.

## Preconditions

Check both before doing anything. Without them only the worktree half can be built.

```bash
test "${HERDR_ENV:-}" = 1 && command -v herdr
```

If `HERDR_ENV` is not `1`, say the workspace cannot be built because this session is not running
inside Herdr, and offer to create the worktree alone. If `herdr` is not on `PATH`, check
`~/.local/bin`.

The installed binary is the authority for command syntax. The bundled `herdr` skill documents
v0.9.0 and the installed client may be older, so if a command below is rejected, print the command
group (`herdr tab`, `herdr workspace`) and adapt rather than guessing.

## Inputs

| Input | Source |
| --- | --- |
| Ticket key | The user, the thread being worked, or the current branch |
| Repo | The repo containing the current working directory, confirmed with the user |
| Branch description | The Jira summary, or the user |

An unkeyed piece of work is fine. Everything below still applies with the key parts dropped: the
directory and workspace label become a short slug of the title instead.

## Naming

Four names come out of one ticket. The worktree directory and the branch follow `git-workflow`;
the two Herdr names reuse the directory.

| Name | Example |
| --- | --- |
| Worktree directory | `taco-3372` |
| Branch | `taco-3372-autodesk-model-derivative-importer` |
| Workspace label | `taco-3372` |
| Herdr agent name | `taco-3372` |

The agent name must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents, which
`taco-xxxx` satisfies. If an agent of that name is already live, the environment probably already
exists: see the error table.

**Confirm the branch name with the user before creating anything.** That rule belongs to
`git-workflow` and applies here unchanged. Propose both names together, since the directory is not
simply a prefix of the branch:

> "I'll create worktree `taco-3372` on branch `taco-3372-autodesk-model-derivative-importer`, and a
> Herdr workspace `taco-3372`. Does that look right?"

## Workflow

### 1. Resolve the repo and check for collisions

```bash
git -C "$PWD" rev-parse --path-format=absolute --git-common-dir
```

The repo root is the parent of the `.bare` directory that comes back. Confirm it with the user if
the work might belong to a different repo.

Then check both halves of the environment before building either, so a half-existing setup is
reported rather than duplicated:

```bash
ls -d ~/code/<repo>/<dir> 2>/dev/null
herdr workspace list
```

### 2. Create the worktree

Run from inside the `.bare` directory, per `git-workflow`. Fetch first so the branch starts from
current upstream rather than whatever the bare repo last saw:

```bash
cd ~/code/<repo>/.bare
git fetch origin
git worktree add ../<dir> -b <branch> origin/master
```

Use the repo's actual default branch if it is not `master`.

`git worktree add` fails rather than clobbering if the directory or branch already exists. Treat
that as the collision case, not as something to force.

Don't use `herdr worktree create` instead. It makes a workspace linked to the worktree, which brings
group-close semantics the existing `taco-*` workspaces do not have, so git and Herdr stay separate
steps.

### 3. Link the shared local config

Generated config such as a filled-in `.env.local` is kept once per repo, outside every worktree, in
`~/code/<repo>/.env-shared/`. That folder mirrors worktree-relative paths, so the file a worktree
needs at `Keyframe.UI/apps/keyframe-ui-next/.env.local` lives at
`~/code/<repo>/.env-shared/Keyframe.UI/apps/keyframe-ui-next/.env.local`. Symlink every file found
there into the new worktree at the same path:

```bash
SHARED=~/code/<repo>/.env-shared
WT=~/code/<repo>/<dir>

test -d "$SHARED" && (cd "$SHARED" && find . -type f) | while read -r file; do
  target="$WT/${file#./}"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "skipped $file (already present)"
  else
    mkdir -p "$(dirname "$target")"
    ln -s "$SHARED/${file#./}" "$target"
    echo "linked $file"
  fi
done
```

Link rather than copy, so re-filling the shared file after a secret rotates reaches every worktree
at once. Never overwrite something already at the target: a real file there is a deliberate
per-worktree override (pointing at a different backend, say). Never read or print the contents of
these files; they hold secrets.

No `.env-shared` folder, or no file in it that a template in the worktree needs, is not an error.
Say which templates have no shared copy (for the UI app, `.env.local.tpl` in
`Keyframe.UI/apps/keyframe-ui-next`) and give the one-off command to create it, run from that app
directory, without running it unasked:

```bash
mkdir -p ~/code/<repo>/.env-shared/<app-path>
pwsh <worktree>/secrets-replace.ps1 -InputFile .env.local.tpl \
  -OutputFile ~/code/<repo>/.env-shared/<app-path>/.env.local
```

This does not use a git `post-checkout` hook, because the repo sets `core.hooksPath` to the
committed `.husky` directory, so a hook would land in the team's hooks.

Do this whenever the worktree exists at the end of step 2, including when an existing directory was
reused, since the skip rule makes it safe to repeat.

### 4. Move the thread to `coding`

The branch now exists, which is what `coding` means in the lifecycle `obsidian` defines. If the key
has a thread (locate it per `obsidian`) and its `status:` is `planned`, set it to `coding` and stamp
`updated:`. Change nothing else in the note.

Leave any other status alone: `review` or `done` means the work is being reopened, and `paused` or
`dropped` is the user's call. No thread at all is fine too; this skill does not scaffold one.

Do this whenever the worktree exists at the end of step 2, including when an existing directory was
reused.

### 5. Create the workspace and its three tabs

Build the whole layout unfocused, so the user's current pane keeps focus while it is assembled.
Focus moves once, at the end.

The root tab is created labelled `1`, so it is renamed rather than created:

```bash
WT=~/code/<repo>/<dir>

herdr workspace create --cwd "$WT" --label <dir> --no-focus
# -> .result.workspace.workspace_id, .result.tab.tab_id, .result.root_pane.pane_id

herdr tab rename <root-tab-id> Prompt

herdr tab create --workspace <ws-id> --cwd "$WT" --label Claude --no-focus
# -> .result.tab.tab_id, .result.root_pane.pane_id

herdr tab create --workspace <ws-id> --cwd "$WT" --label Editor --no-focus
# -> .result.tab.tab_id, .result.root_pane.pane_id
```

Read every ID from the JSON response. Never predict them: workspace IDs are allocated by the server
and are not sequential in any way you can rely on.

Pass `--cwd` on every tab. A tab does not inherit the workspace's directory.

### 6. Fill the Claude and Editor tabs

The Claude tab gets a real agent rather than a shell running `claude`, so Herdr tracks its
lifecycle and it shows up in `herdr agent list`:

```bash
herdr agent start <dir> --kind claude --pane <claude-pane-id>
```

This returns only once Herdr has detected the agent and considers it ready, typically in a few
seconds against a 30-second default timeout.

The Editor tab is an ordinary command:

```bash
herdr pane run <editor-pane-id> "nvim ."
```

Leave the Prompt tab alone. It is a shell sitting at a prompt in the worktree, which is the whole
point of it.

### 7. Focus the Claude tab

Last, and only now:

```bash
herdr workspace focus <ws-id>
herdr tab focus <claude-tab-id>
```

### 8. Report and hand back

Give the user the worktree path, the branch, the workspace ID and label, which shared config files
step 3 linked or found missing, and the thread's status if step 4 moved it.

Then flag the session problem, because it is easy to miss: the Claude agent in the new tab is a
**different session** from the one that ran this skill. Whatever `track-session` recorded points at
the old working directory and will resume in the wrong place. Say so, and suggest running
`track-session` from the new Claude tab so the thread's session log points at the worktree.

Do not prompt the new agent with the ticket's work unless the user asks. It starts idle and ready,
and what to do first is theirs to decide.

## Defaults and error handling

| Situation | What to do |
| --- | --- |
| Worktree directory exists, no workspace | Reuse it. Skip step 2, say you are reusing it, build the workspace. |
| Workspace label exists, no worktree | Almost always a stale workspace. Report it and ask before creating a second. |
| Both exist | Nothing to build. Run steps 3 and 4 anyway, focus the existing workspace and say so. |
| Agent name already live | The workspace exists somewhere. Find it with `herdr agent list` before creating anything. |
| `git fetch` fails | Offer to branch from the local default branch instead, saying it may be behind. |
| `agent start` returns `agent_not_ready` | The pane kept the name. Wait for idle with `herdr agent wait <name>`, do not start a second agent. |
| `agent start` fails outright | Leave the workspace up. The Prompt and Editor tabs are still useful; say the Claude tab needs starting by hand. |
| `nvim` not installed | Leave the tab as a shell and say so. Do not substitute another editor. |
| Not running inside Herdr | Create the worktree, link the shared config, move the thread to `coding`, skip the workspace, say which half was done. |

Partial success is normal and worth reporting precisely. A worktree with two working tabs is a
better outcome than an unwound setup, so never tear down what already succeeded because a later
step failed. Never close a workspace this run did not create.
