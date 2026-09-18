---
name: coding-style
description: The user's personal coding style preferences: philosophy, control flow, comments, error handling and structure, plus sections for C# and Terraform. The rules live in rules/ and a PreToolUse hook injects the ones that apply whenever a file is edited, so ordinary coding does not need this skill. Load it when the user asks what their coding style is, when reviewing code without editing it (the hook only fires on edits), and when the user corrects a style choice or says they prefer X over Y, to capture the preference before saving it.
---

# Coding Style

## Philosophy

Code should explain itself through naming and structure. The reader should be able to follow the logic without narration. Comments exist for the rare case where the _why_ isn't derivable from the code: a non-obvious constraint, a surprising decision, or context that would take effort to reconstruct.

## Where the rules live

| File | Applies to |
| --- | --- |
| `rules/core.md` | any language |
| `rules/csharp.md` | `.cs`, `.csx` |
| `rules/terraform.md` | `.tf`, `.tfvars` |

`hooks/inject-style.sh` puts the fragments that apply into context on `PreToolUse` for
`Edit`, `Write` and `NotebookEdit`, once per fragment per session. `hooks/README.md` has the
wiring and the routing rules.

That covers editing. It does not cover reading: a review pass that only reads files never
triggers the hook, so `/code-review`, `semgrep-review` and any other read-only check should read
`rules/core.md` and the language fragment directly.

## Capturing new preferences

When the user corrects a style choice or expresses a preference during a session, say:

> "I'd capture this as: [exact wording]. Want me to add it to your coding style skill?"

Wait for confirmation before editing anything. Always show the exact wording before asking, and
name the file it is going into: `rules/core.md` unless the preference is genuinely specific to one
language, in which case it belongs in that language's fragment.
