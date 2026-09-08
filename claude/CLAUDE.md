# Writing conventions

These apply to everything written: Jira tickets, PR titles and descriptions, commit
messages, code comments, documentation, vault notes, and replies in the terminal.

## Spelling

Australian English throughout.

| Use | Not |
| --- | --- |
| organise, prioritise, serialise | organize, prioritize, serialize |
| colour, behaviour, favour | color, behavior, favor |
| centre, metre, fibre | center, meter, fiber |
| cancelled, modelling, labelled | canceled, modeling, labeled |
| analyse, catalogue, defence | analyze, catalog, defense |

Licence and practice are the nouns, license and practise the verbs.

**Code is the exception.** Never change an identifier, an API name, a config key or a CLI
flag to match the prose rule: `Color`, `serializer`, `Initialize`, `--optimize` and CSS
`color` all stay exactly as the code has them, including inside prose that surrounds them.
Quoted text, product names and third-party terminology also stay as written.

## Punctuation

**No em-dashes.** Recast the sentence instead:

* a comma, when the aside is light
* parentheses, when it is a genuine aside
* a colon, when what follows explains what came before
* a full stop, when the clause can stand on its own

An en dash is still correct in a numeric range (2020-2024, pages 12-18), and a hyphen in a
compound modifier (read-only, well-formed).

## No emojis

Not in tickets, commits, PR descriptions, documentation, code, or terminal replies.
