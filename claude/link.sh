#!/usr/bin/env bash
# Makes ~/.claude/skills match this repo: a symlink per skill in claude/skills/, plus the
# third-party skills listed in claude/third-party-skills.txt. See claude/README.md.

set -euo pipefail

claude_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
own_skills="${claude_dir}/skills"
third_party_list="${claude_dir}/third-party-skills.txt"
installed="${HOME}/.claude/skills"

if [[ -L "$installed" ]]; then
  echo "${installed} is a symlink to $(readlink "$installed")." >&2
  echo "It has to be a real directory so third-party skills can live alongside these ones." >&2
  echo "Move anything under it that this repo does not own, then delete it and re-run." >&2
  exit 1
fi

mkdir -p "$installed"

clashes=0
for skill in "$own_skills"/*/; do
  name="$(basename "$skill")"
  target="${installed}/${name}"

  # ln -sfn onto a real directory reports success without linking anything, so a third-party
  # skill of the same name would silently shadow this one.
  if [[ -d "$target" && ! -L "$target" ]]; then
    echo "${target} is a directory installed by something else, so ${name} cannot be linked." >&2
    echo "Remove it, or rename the skill in this repo." >&2
    clashes=1
    continue
  fi

  ln -sfn "${own_skills}/${name}" "$target"
done

# A skill renamed or deleted in the repo leaves a dangling link behind, and Claude Code reports
# it as a broken skill rather than ignoring it.
for link in "$installed"/*; do
  [[ -L "$link" && ! -e "$link" ]] || continue
  [[ "$(readlink "$link")" == "${own_skills}/"* ]] || continue
  rm "$link"
done

if [[ -f "$third_party_list" ]]; then
  while read -r source || [[ -n "$source" ]]; do
    [[ -n "$source" && "$source" != \#* ]] || continue
    # Unquoted on purpose: a line may carry its own flags, such as --skill to take one skill
    # out of a repo that holds several.
    # shellcheck disable=SC2086
    npx --yes skills add --global --agent claude-code --yes $source
  done <"$third_party_list"
fi

exit "$clashes"
