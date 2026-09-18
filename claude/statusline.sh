#!/usr/bin/env bash
# Claude Code status line: model, repo/branch, PR badge, context window utilisation.
# Wired up via the "statusLine" key in ~/.claude/settings.json; the session JSON
# arrives on stdin (see the schema that `/statusline` documents).

set -uo pipefail

input=$(cat)

# One field per line: tab-separated fields would collapse, since bash treats a
# run of tabs in IFS as a single delimiter and empty fields then shift the rest.
mapfile -t f < <(
  jq -r '
    (.model.display_name // "?"),
    (.workspace.current_dir // .cwd // "."),
    (.workspace.project_dir // .workspace.current_dir // .cwd // "."),
    (.workspace.repo.name // ""),
    (.workspace.git_worktree // ""),
    (.pr.number // ""),
    (.pr.kind // "pr"),
    (.pr.review_state // ""),
    (.context_window.used_percentage // "")
  ' <<<"$input"
)
model=${f[0]} dir=${f[1]} project_dir=${f[2]} repo_name=${f[3]}
worktree=${f[4]} pr_num=${f[5]} pr_kind=${f[6]} pr_state=${f[7]} ctx=${f[8]}

dim=$'\033[2m'
reset=$'\033[0m'
sep="${dim} · ${reset}"

parts=("$model")

# Repo and branch. The status line JSON carries no branch, so ask git directly.
branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null) \
  || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null) \
  || branch=""
# repo.name is only populated for hosts Claude Code recognises, so fall back to
# the origin remote (which works for Azure DevOps) and then to the directory.
if [ -z "$repo_name" ]; then
  remote=$(git -C "$dir" remote get-url origin 2>/dev/null)
  repo_name=$(basename "${remote%.git}" 2>/dev/null)
fi
[ -n "$repo_name" ] || repo_name=$(basename "$project_dir")
if [ -n "$branch" ]; then
  parts+=("${repo_name}:${branch}")
else
  parts+=("$repo_name")
fi

# Worktree name, only for --worktree sessions.
[ -n "$worktree" ] && parts+=("wt:${worktree}")

# PR badge. Populated only where Claude Code detects the PR itself (GitHub, GitLab).
if [ -n "$pr_num" ]; then
  [ "$pr_kind" = "mr" ] && badge="MR !${pr_num}" || badge="PR #${pr_num}"
  case "$pr_state" in
    approved)          badge="${badge} ok" ;;
    changes_requested) badge="${badge} changes" ;;
    draft)             badge="${badge} draft" ;;
    pending)           badge="${badge} review" ;;
  esac
  parts+=("$badge")
fi

# Context window utilisation, coloured once it starts to matter.
if [ -n "$ctx" ]; then
  pct=$(printf '%.0f' "$ctx")
  if   [ "$pct" -ge 85 ]; then colour=$'\033[31m'
  elif [ "$pct" -ge 60 ]; then colour=$'\033[33m'
  else                         colour=$'\033[32m'
  fi
  parts+=("${colour}ctx ${pct}%${reset}")
fi

printf '%s' "${parts[0]}"
for p in "${parts[@]:1}"; do printf '%s%s' "$sep" "$p"; done
printf '\n'
