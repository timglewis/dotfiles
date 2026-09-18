# coding-style hooks

`inject-style.sh` puts the rule fragments in `../rules/` into context at the moment code is
about to be edited, rather than leaving it to the model to decide the skill is relevant.

## Wiring

The hook is registered in `~/.claude/settings.json`, which is a real file rather than a symlink
into this repo (`claude/README.md` explains why). `claude/settings.json` holds a reference copy,
so the two have to be kept in step by hand.

Two events are registered. `PreToolUse` on `Edit|Write|NotebookEdit` runs the script, and
`PostCompact` runs it with the `reset` argument. The script itself is reached through the
`~/.claude/skills/coding-style` symlink that `claude/link.sh` creates, so it is
version-controlled and needs no copying.

## What it does

Routing is on the file extension taken from `tool_input.file_path`, so all three editing tools
share one testable decision. `.cs` and `.csx` add `csharp.md`, `.tf` and `.tfvars` add
`terraform.md`, and everything else that isn't prose or configuration gets `core.md` alone.
The skip list is a denylist rather than an allowlist so that a language nobody thought about
still gets the any-language rules.

A fragment is injected once per session. Markers live in
`~/.claude/cache/coding-style/<session_id>/`, and directories older than seven days are swept
whenever a new session creates its own. The `reset` action clears the current session's markers,
which is why `PostCompact` calls it: compaction can drop the injected text, and it then needs to
come back.

## Known gap

`PreToolUse` fires after the edit has been composed, so the first injection of a session arrives
too late to shape the code it is attached to. The preamble asks for that edit to be re-checked.
If code still lands in the wrong style, the stricter fix is to return
`permissionDecision: "deny"` on the first edit for a language, which blocks the tool call and
forces a re-plan with the rules already in hand, at the cost of one wasted tool call per language
per session.
