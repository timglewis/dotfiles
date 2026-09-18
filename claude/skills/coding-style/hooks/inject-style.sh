#!/usr/bin/env bash
# PreToolUse/PostCompact hook for the coding-style skill. See hooks/README.md.

set -euo pipefail

rules_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../rules" && pwd)"
state_root="${HOME}/.claude/cache/coding-style"

# Extensions that carry prose or configuration rather than logic the rules speak to.
skip_extensions="md markdown mdx txt rst adoc json jsonc json5 yaml yml toml ini cfg conf properties csv tsv lock log env xml csproj sln props targets resx svg png jpg jpeg gif pdf"

action="${1:-inject}"
input="$(cat)"

session_id="$(jq -r '.session_id // "unknown"' <<<"$input")"
state_dir="${state_root}/${session_id}"

if [[ "$action" == "reset" ]]; then
  rm -rf "$state_dir"
  exit 0
fi

file_path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")"
[[ -n "$file_path" ]] || exit 0

basename="${file_path##*/}"
[[ "$basename" == *.* ]] || exit 0

extension="${basename##*.}"
extension="${extension,,}"
[[ " $skip_extensions " != *" $extension "* ]] || exit 0

fragments=(core)
case "$extension" in
  cs|csx) fragments+=(csharp) ;;
  tf|tfvars) fragments+=(terraform) ;;
esac

if [[ ! -d "$state_dir" ]]; then
  mkdir -p "$state_dir"
  # Sessions never announce their end, so old markers are swept on the way past.
  find "$state_root" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
fi

context=""
for fragment in "${fragments[@]}"; do
  marker="${state_dir}/${fragment}"
  [[ -e "$marker" ]] && continue
  [[ -f "${rules_dir}/${fragment}.md" ]] || continue
  context+="$(cat "${rules_dir}/${fragment}.md")"$'\n\n'
  : >"$marker"
done

[[ -n "$context" ]] || exit 0

# The edit was composed before these rules arrived, so it has to be re-checked rather than trusted.
preamble="The following coding style rules were not in context when you composed the edit you are about to make. Check that edit against them before you continue, and revise it if it breaks one."

jq -n --arg context "${preamble}"$'\n\n'"${context}" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $context
  }
}'
