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

### Tidying as we go

The Boy Scout Rule, applied to style: leave a file tidier than you found it, but ask first.

- While editing a file, watch the whole file for non-functional changes that would bring it into line with these preferences: member ordering, a comment that earns nothing, nesting a guard clause would flatten, a single-use indirection worth inlining
- ALWAYS ask before making one. List the tidy-ups together, once per file, and wait for an answer. Never apply one silently, and never fold one into the edit that found it
- A declined tidy-up stays declined for the rest of the session. Don't raise it again on the next edit to that file
- Scope is the file being edited. A file only read, or one a search turned up, is out of scope: raise it as a follow-up at the end of the task if it matters, rather than interrupting the work
- An approved tidy-up is its own commit, separate from the behaviour change, so the functional diff stays reviewable on its own
- Leaving pre-existing bad code untouched is still normal scope discipline, not a compromise. A tidy-up is offered, never insisted on

## Structure and indirection

- A variable that doesn't vary isn't configuration. If a value is identical across every environment or caller, inline it where it's used once, or make it a local/constant if it's used often. Don't keep a config knob for something that never changes
- Prefer inlining single-use indirection over naming it. A name earns its place by being reused, or by explaining something the literal doesn't

## File organisation

- Judge by size, not by category: a concern gets its own file once it is substantial enough to stand alone
