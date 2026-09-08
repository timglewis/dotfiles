---
name: coding-style
description: Tim's personal coding style preferences for C#, TypeScript and Terraform. Consult this whenever writing, reviewing, or refactoring C#, TypeScript or Terraform (.tf/.tfvars) code to ensure it matches his style. Also trigger when Tim corrects a style choice or says he prefers X over Y, propose capturing the preference before saving it.
---

# Coding Style

## Philosophy

Code should explain itself through naming and structure. The reader should be able to follow the logic without narration. Comments exist for the rare case where the _why_ isn't derivable from the code: a non-obvious constraint, a surprising decision, or context that would take effort to reconstruct.

## Preferences

**Control flow**

- Prefer early returns and guard clauses over wrapping logic in conditionals
- When a condition guards most of a method body, invert it and return/throw early
- Minimise nesting depth: flat is easier to follow than deeply indented

**Comments**

- No comments explaining _what_: well-named code already does that
- Comments are for _why_: a constraint, a workaround, a business reason not obvious from the name
- If a comment could be deleted without confusing a future reader, leave it out
- When a comment seems necessary, first try to remove the need for it by renaming or restructuring the code. Only if that fails does the comment earn its place. Prefer deleting a weak comment over shortening it
- Keep comments to one or two sentences. Longer is allowed only when the _why_ genuinely cannot be conveyed in less, never as a default. What never belongs is the debate that produced the decision, or a record of alternatives considered
- Prefer XML doc comments (`///`) over `//` line comments when documenting properties or fields, because they surface in IntelliSense. Reserve `//` for inline notes on non-obvious logic

**Error handling**

- Never catch, log, and rethrow. If you can't handle an exception, let it propagate. The log line duplicates what the stack trace already carries
- A catch block must change behaviour: return a value, translate the exception, or recover. If it does none of those, delete it
- Prefer `catch (SpecificException e) when (<filter>)` over a broad catch, so unrelated failures are never intercepted

**Surrounding code**

- Never lower code quality, or drop one of these preferences, to match nearby code. Bad existing code is not a precedent
- If tempted to match a local pattern that conflicts with these preferences, ASK first: name the conflict and which preference it breaks. Don't resolve it silently in either direction
- Leaving pre-existing bad code untouched is normal scope discipline, not a compromise, but offer it as a follow-up rather than assuming it should stay

**Structure and indirection**

- A variable that doesn't vary isn't configuration. If a value is identical across every environment or caller, inline it where it's used once, or make it a local/constant if it's used often. Don't keep a config knob for something that never changes
- Prefer inlining single-use indirection over naming it. A name earns its place by being reused, or by explaining something the literal doesn't

**File organisation**

- Split _resources_ into separate files by type: one file per logical resource group, so a reader can find a thing by its kind
- Group the supporting wiring (providers, backend, locals, data sources) into a single file when each part is small. Don't carve out a file to hold one local or a seven-line backend block
- Judge by size, not by category: a concern gets its own file once it is substantial enough to stand alone

**Terraform**

- No single-use modules. A module is a unit of reuse; if it has exactly one consumer, inline it into the root and delete the `modules/` tree. Don't copy the pattern from a reference repo just because it's there
- Group the root wiring in `main.tf` in this order: backend, providers, locals, data sources
- Never declare a `provider` block inside a module: it's deprecated, and it's a sign the module shouldn't exist
- When a refactor renames resource addresses, use `moved {}` blocks rather than `terraform state mv`: they're declarative, visible in the plan, reviewable in the PR, and applied by CI automatically. Delete them once every environment has applied
- Give every variable a `type`. Add a `description` only where the name doesn't already carry the meaning
- Verify a refactor with a plan showing `0 to add, 0 to destroy` before committing it

## Capturing new preferences

When Tim corrects a style choice or expresses a preference during a session, say:

> "I'd capture this as: [exact wording]. Want me to add it to your coding style skill?"

Wait for confirmation before editing this file. Always show the exact wording before asking.
 
