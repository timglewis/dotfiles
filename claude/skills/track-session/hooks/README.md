# track-session hooks

`record-session.sh` does the mechanical half of `track-session` when a session starts, so the
thread's session log stays current without the skill being run by hand. The skill keeps the
half that needs judgement: sharpening labels, writing hand-off notes, and threads the hook
cannot find.

## Wiring

The hook is registered in `~/.claude/settings.json`, which is a real file rather than a symlink
into this repo (`claude/README.md` explains why). `claude/settings.json` holds a reference copy,
so the two have to be kept in step by hand.

It runs on `SessionStart` with the matcher `startup|clear|resume`. Compaction keeps the session
ID, so `compact` is left out, and the script skips it too in case the matcher is widened. The
script is reached through the `~/.claude/skills/track-session` symlink that `claude/link.sh`
creates, so it is version-controlled and needs no copying.

## What it does

It finds the thread one of two ways:

* **Inside the vault**: the nearest folder above the working directory that holds an `index.md`.
* **Anywhere else**: the ticket key the branch leads with, globbed against folder names under
  `Threads/`, including nested ones. `Archive/` is not searched, since work resuming on an
  archived thread moves it back first.

When the session's UUID is not already in the thread's `sessions.md`, it appends an entry
labelled with the thread's `title:` and no notes, creating the file if needed. It then adds the
`[[sessions]]` link to `index.md` if missing and stamps `updated:` to today, per `obsidian`.

Whatever happens, it tells Claude through `additionalContext`: where the session was recorded,
that it already was, or why it could not be (a key with no thread, or with several).

## What it leaves alone

It writes nothing when the branch carries no key or when several folders share one, and it never
creates a thread folder. Unkeyed threads worked on from a code repo are invisible to it, because
matching them means reading what the session is about. `track-session` handles those, and the
thread-writing skills run it on their way past.
