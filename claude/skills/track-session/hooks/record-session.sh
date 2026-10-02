#!/usr/bin/env bash
# SessionStart hook for the track-session skill. See hooks/README.md.

set -euo pipefail

threads_root="${HOME}/Obsidian/keyframe/Threads"

input="$(cat)"
session_id="$(jq -r '.session_id // ""' <<<"$input")"
cwd="$(jq -r '.cwd // ""' <<<"$input")"
source="$(jq -r '.source // ""' <<<"$input")"

# Compaction keeps the session ID, so there is nothing new to record.
[[ "$source" != "compact" ]] || exit 0
[[ -n "$session_id" && -d "$cwd" && -d "$threads_root" ]] || exit 0

emit() {
  jq -n --arg context "$1" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $context
    }
  }'
  exit 0
}

# A session working inside the vault takes its thread from the working directory: the nearest
# folder holding an index.md. Both sides are resolved because ~/Obsidian may be a symlink.
thread=""
real_threads="$(realpath "$threads_root")"
dir="$(realpath "$cwd")"
while [[ "$dir" == "$real_threads"/* ]]; do
  if [[ -f "$dir/index.md" ]]; then
    thread="$threads_root/${dir#"$real_threads"/}"
    break
  fi
  dir="$(dirname "$dir")"
done

# Anywhere else, the branch leads with the ticket key.
key=""
if [[ -z "$thread" ]]; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"
  [[ "$branch" =~ ^([A-Za-z]+-[0-9]+) ]] || exit 0
  key="${BASH_REMATCH[1]^^}"

  mapfile -t matches < <(find "$threads_root" -type d -name "*(${key})*" 2>/dev/null)
  case "${#matches[@]}" in
    0) emit "The branch names ${key}, but no thread folder exists for it in the vault, so this session was not recorded. Mention this once if the user starts working on the ticket, and point at start-thread." ;;
    1) thread="${matches[0]}" ;;
    # Several folders for one key break the vault's own rule, so none is picked.
    *) emit "The branch names ${key}, but more than one thread folder carries that key, so this session was not recorded. Mention this once, since the vault should hold one folder per key." ;;
  esac
fi

index="$thread/index.md"
sessions="$thread/sessions.md"
[[ -f "$index" ]] || exit 0

folder="$(basename "$thread")"
title="$(awk '
  NR == 1 && $0 == "---" { in_frontmatter = 1; next }
  in_frontmatter && $0 == "---" { exit }
  in_frontmatter && /^title:/ { sub(/^title:[ \t]*/, ""); print; exit }
' "$index")"
title="${title#[\"\']}"
title="${title%[\"\']}"
[[ -n "$title" ]] || title="${folder#* - }"
[[ "$folder" =~ \(([^\)]+)\) ]] && key="${BASH_REMATCH[1]}"

context_tail="Run track-session to sharpen the label or add hand-off notes once there is something a resumer would need."

if [[ -f "$sessions" ]] && grep -qF "$session_id" "$sessions"; then
  emit "This session (ID ${session_id}) is already recorded in ${sessions}. ${context_tail}"
fi

today="$(date +%F)"
path_line="$(basename "$(dirname "$cwd")")/$(basename "$cwd")"
entry="## ${today} - ${title}

\`${path_line}\`

\`\`\`bash
cd ${cwd}
claude --resume ${session_id}
\`\`\`"

# Rewritten rather than appended so the entry is always separated by exactly one blank line,
# whatever trailing whitespace the file was left with.
if [[ -f "$sessions" ]]; then
  existing="$(cat "$sessions")"
else
  existing="# ${key:-$title} - Sessions"
fi
printf '%s\n\n%s\n' "$existing" "$entry" >"$sessions.tmp"
mv "$sessions.tmp" "$sessions"

# The link sits after the prose summary, before the first ## heading outside the frontmatter and
# outside code fences, or at the end when there is no such heading. updated: is stamped in the
# same pass because any write into the thread counts.
link="See [[sessions]] for the session log."
has_link=0
grep -qF '[[sessions]]' "$index" && has_link=1
awk -v today="$today" -v link="$link" -v has_link="$has_link" '
  NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
  in_frontmatter && $0 == "---" { in_frontmatter = 0; print; next }
  in_frontmatter && /^updated:/ { print "updated: " today; next }
  in_frontmatter { print; next }
  /^(```|~~~)/ { in_fence = !in_fence }
  !in_fence && !has_link && /^## / { print link; print ""; has_link = 1 }
  { print }
  END { if (!has_link) { print ""; print link } }
' "$index" >"$index.tmp"
mv "$index.tmp" "$index"

emit "This session (ID ${session_id}) was recorded in ${sessions} with the label \"${title}\". ${context_tail}"
