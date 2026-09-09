---
name: obsidian
description: >
  The conventions for reading and writing notes in the user's Obsidian vault: where thread folders
  live and how to find one, the reserved filenames, the frontmatter schema for each thread kind,
  and how prose, wikilinks and file paths are written inside a note. Consult this skill before
  reading or writing anything under the vault, whether the user asked directly ("add this to my
  notes", "what does the note say about TACO-1234", "find the thread for this branch") or another
  skill needs to locate a thread folder or write a working file into one. It is the single source
  of truth for those conventions: `start-thread`, `track-session`, `investigate`,
  `work-breakdown`, `commit-breakdown` and `pr-summary` all defer to it rather than restating
  them. It owns conventions only, and creates nothing: scaffolding a new thread is `start-thread`.
---

# Obsidian Vault Skill

Everything needed to navigate the vault and write into it consistently. This skill is a reference: read it, apply it, don't expect it to perform a task.

The vault also carries its own `AGENTS.md` (with a `CLAUDE.md` shim importing it, since Claude Code reads only the latter), but that loads only when the working directory is inside the vault. These conventions are needed from code repos, which is why they live here.

## Vault root

```
~/Obsidian/keyframe/
```

`~/Obsidian` may be a symlink to an Obsidian directory elsewhere, on this setup the Windows side under WSL, and it can hold several vaults alongside the work one. **`keyframe` is the work vault and the only one these skills touch**; any sibling vault is out of scope unless the user names it.

Expand `~` to the absolute `/home/<user>/...` form before passing the path to a tool that requires an absolute path, and prefer that form over the resolved `/mnt/c/...` path when the vault is a symlink.

| Path | What's in it |
| --- | --- |
| `Threads/` | One folder per thread. The only place thread-scoped files go. |
| `Threads/tags.md` | The canonical tag list. |
| `Threads/threads.base` | The Bases views over all threads. |
| `Templates/` | Templater templates, one per thread kind. |

## The thread model

A **thread** is a folder holding an `index.md` plus whatever working files get produced. A Jira ticket is just a thread carrying a `ticket:` key: there is no separate Tickets folder and no `ticket` kind. "Is this a ticket" is answered by `ticket:` having a value, not by `kind`.

The four kinds split by what a thread produces. `code` changes a system, `investigation` produces understanding, `work` produces a proposal, plan or decision that isn't code, and `incident` is an incident response. `investigation` and `work` share a schema and differ only in intent: digging versus proposing.

Threads nest by **folder**, and only for epic-shaped work: one coordinated piece sliced into parts. Nesting is the exception and most threads are flat, and it is never how "everything to do with X" is expressed. That is `tags:`.

## Folder naming

| Case | Format | Example |
| --- | --- | --- |
| Keyed | `YYYY-MM-DD - (KEY) Title` | `2026-01-15 - (TACO-1234) Send confirmation email on order completion` |
| Unkeyed | `YYYY-MM-DD - Title` | `2026-01-15 - Log monitoring daemon` |

The date is the creation date and never changes. A single ` - ` separator follows the date; the key sits in brackets with no extra hyphen after it. Cap the title portion at **60 characters**, trimming at a word boundary and dropping any trailing stop-word or unbalanced bracket. The full untruncated title lives in frontmatter `title:`. Strip characters illegal on macOS (`/`, `:`).

## Reserved filenames

Only two: **`index.md`** (the thread note) and **`sessions.md`** (the session log). Everything else in a thread folder is a free-form dumping ground, named whatever makes sense. Three names are conventional because skills both write and read them: `investigation.md`, `work-breakdown.md` and `commit-breakdown.md`.

## Locating a thread

**Keyed.** The key sits in brackets in the folder name, so glob `Threads/*(TACO-XXXX)*/`. Take the key from the user's message, or from the current branch, which always leads with it:

```bash
git branch --show-current
```

**Unkeyed.** There is no key to glob and often no git repo at all. Match on distinctive words from the title (`Threads/*<distinctive words>*/`), or search `Threads/*/index.md` frontmatter for a matching `title:` or `aliases:`. A session working inside a thread folder can take the thread from the working directory. **If more than one folder plausibly fits, ask rather than guess.**

If no thread folder exists, say so and point at `start-thread`. Never invent a folder to write into, and never create a second folder for a key that already has one.

## Frontmatter schema

Core, on every thread:

```yaml
---
kind: code            # code | investigation | work | incident
title: Send confirmation email on order completion
status: active        # planned | active | paused | done | dropped
aliases:
  - TACO-1234         # the key when keyed, the title when not
tags: []
created: 2026-01-15
updated: 2026-01-15
---
```

`kind: code` also carries, in this order after `updated:`:

```yaml
ticket: TACO-XXXX                                            # omit entirely when unkeyed
jira: https://keyframeai.atlassian.net/browse/TACO-XXXX      # omit when unkeyed
prs: []
```

`kind: incident` adds `incident:`, `severity:`, `detected:`, `resolved:`. `kind: investigation` and `kind: work` add nothing.

Rules that matter:

- **`aliases:` is load-bearing.** It is the only thing keeping `[[TACO-1234]]` and `[[Some Thread Title]]` resolving to a note named `index.md`. Never drop it.
- **Quote any title containing a colon.** An unquoted colon breaks the line, Obsidian then shows no properties at all, and Bases silently drops the note from every view.
- **`status:` is `active` on a new thread.** The user is starting it. `planned` is for work deliberately queued rather than begun.
- **`prs:` is always present on `code`**, as `prs: []` when empty. Never omitted.
- Empty lists render inline as `[]`, not as an empty block.
- **No `type:` field, and no `parent:` or `root:`.** They are deliberately not part of the schema; hierarchy is folder nesting only, because `file.inFolder()` already matches subfolders.
- Only `index.md` carries frontmatter. `threads.base` filters on `file.hasProperty("kind")`, so a `kind` property on a working file would list it as a thread in its own right.

## Stamping `updated:`

**Stamp `updated:` in the thread's `index.md` whenever you write anywhere in the thread**, not just when you edit the index note itself. Writing `investigation.md`, appending to `sessions.md` or adding a `commit-breakdown.md` all count. The Recent threads view sorts on it, so a stale stamp hides live work.

This is the only edit to make to an index note you weren't asked to change. Leave its body and the rest of its frontmatter alone.

## Writing prose in a note

**Never hard-wrap prose.** Write each paragraph as a single unwrapped line, with no wrapping at 80 or 100 characters. Hard wraps render as line breaks mid-sentence when reading and editing in Obsidian. Tables, list items, code blocks and frontmatter keep their normal line structure.

Keep summaries 2-4 sentences and don't pad. Prefer editing an existing note over creating a new one. No emojis.

## Links and file paths

**Wikilinks between notes in the same thread go unqualified**: `[[sessions]]`, `[[investigation]]`. Obsidian resolves them to the file in the same folder, so every thread's link points at its own. Link to another thread by its alias, `[[TACO-1234]]`.

**Always use full absolute paths**, never relative paths or bare filenames.

**Wrap local paths in `file://` links** so they're clickable in Obsidian:

```markdown
[PaymentService.cs](file://<code-root>/<repo>/master/src/Services/PaymentService.cs)
```

Mark a file that doesn't exist yet: `[NewService.cs](file:///...) *(new file)*`.

**Inline code references in prose go in backticks**, with a line number where it helps: `` `<code-root>/<repo>/master/src/Services/PaymentService.cs:142` ``.

**Azure DevOps links** target `https://dev.azure.com/keyframe-ai/KeyframeAI/_git/<repo>` unless the thread's index note says otherwise.

## What not to do

- Don't put thread-scoped files anywhere but inside the thread folder.
- Don't create or overwrite a thread folder. That is `start-thread`, and it never overwrites either.
- Don't add frontmatter to anything but `index.md`.
- Don't hard-wrap prose, and don't leave `updated:` stale after writing.
- Don't add emojis.
