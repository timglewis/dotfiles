# Coding style: any language

These are the user's standing preferences. They apply to code in every language, and they
outrank the conventions of the surrounding file.

## Philosophy

Code should explain itself through naming and structure. The reader should be able to follow the logic without narration. Comments exist for the rare case where the _why_ isn't derivable from the code: a non-obvious constraint, a surprising decision, or context that would take effort to reconstruct.

## Control flow

- Prefer early returns and guard clauses over wrapping logic in conditionals
- When a condition guards most of a method body, invert it and return/throw early
- Minimise nesting depth: flat is easier to follow than deeply indented

## Comments

- No comments explaining _what_: well-named code already does that
- Comments are for _why_: a constraint, a workaround, a business reason not obvious from the name
- If a comment could be deleted without confusing a future reader, leave it out
- When a comment seems necessary, first try to remove the need for it by renaming or restructuring the code. Only if that fails does the comment earn its place. Prefer deleting a weak comment over shortening it
- Keep comments to one or two sentences. Longer is allowed only when the _why_ genuinely cannot be conveyed in less, never as a default. What never belongs is the debate that produced the decision, or a record of alternatives considered

## Error handling

- Never catch, log, and rethrow. If you can't handle an exception, let it propagate. The log line duplicates what the stack trace already carries
- A catch block must change behaviour: return a value, translate the exception, or recover. If it does none of those, delete it

## Surrounding code

- Never lower code quality, or drop one of these preferences, to match nearby code. Bad existing code is not a precedent
- If tempted to match a local pattern that conflicts with these preferences, ASK first: name the conflict and which preference it breaks. Don't resolve it silently in either direction
- Leaving pre-existing bad code untouched is normal scope discipline, not a compromise, but offer it as a follow-up rather than assuming it should stay

## Structure and indirection

- A variable that doesn't vary isn't configuration. If a value is identical across every environment or caller, inline it where it's used once, or make it a local/constant if it's used often. Don't keep a config knob for something that never changes
- Prefer inlining single-use indirection over naming it. A name earns its place by being reused, or by explaining something the literal doesn't

## File organisation

- Judge by size, not by category: a concern gets its own file once it is substantial enough to stand alone
