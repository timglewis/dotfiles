---
name: semgrep-review
description: >
  Run a static security scan over the current branch with semgrep, triage the raw findings
  against the surrounding code, and report only the ones that survive. Use this skill whenever
  the user says "security review", "security scan", "run semgrep", "scan this for
  vulnerabilities", "check this branch for security issues", "semgrep review", "is this
  secure", or any similar phrase asking for the work to be checked for security problems
  rather than correctness bugs. It is offered alongside `/code-review` at the end of a
  ticket, since both want the same moment: the branch complete, nothing raised yet. Installs
  semgrep into a dedicated venv on first use if it is not already on PATH. Scopes itself to
  the branch's own diff, so pre-existing findings on the base branch stay out of the way.
---

# Semgrep Review Skill

Runs semgrep over what this branch changed, then reads every hit against the code around it
and reports only what stands up.

The raw tool output is not the deliverable. Semgrep is a pattern matcher with no idea what
the code is for, and a list of unfiltered hits is how a scanner gets switched off after a
fortnight. The value this skill adds is the triage pass in step 4.

## Where this sits

Three review passes exist, and they do not overlap:

| Pass | Finds | Driven by |
| --- | --- | --- |
| `/code-review` | Correctness bugs, reuse, simplification | The model reading the diff |
| `semgrep-review` (this) | Known-shape vulnerabilities and leaked credentials | Rule packs, then triaged |
| `/security-review` | Logic-level security flaws no rule encodes | The model reasoning about the change |

Run this one alongside `/code-review`, not instead of it. Semgrep is cheap, deterministic and
catches the classes it knows. It will not notice a missing authorisation check.

## The scripts

Three scripts do the mechanical work, and they live in this skill's own `scripts/` folder.
Where that folder is depends on which agent's skills directory the skill was installed into
(`~/.claude/skills/semgrep-review/` for Claude Code, `~/.copilot/skills/semgrep-review/` for
Copilot CLI), so resolve it once and reuse it as `$SKILL_DIR` in every command below:

```bash
SKILL_DIR=$(ls -d ~/.claude/skills/semgrep-review ~/.copilot/skills/semgrep-review 2>/dev/null | head -1)
```

## Preflight: is semgrep installed

```bash
command -v semgrep && semgrep --version
```

If it is missing, say so and offer the install once:

> "semgrep isn't installed. Want me to set it up? It goes in its own venv under
> `~/.local/share/semgrep-venv`, symlinked into `~/.local/bin`, no sudo and nothing
> system-wide."

On yes:

```bash
"$SKILL_DIR"/scripts/install-semgrep.sh
```

Ubuntu marks the system Python as externally managed, so `pip install --user semgrep` is
refused outright. The venv sidesteps that without sudo. Pass `--upgrade` to move an existing
install forward. To remove it entirely, delete the venv directory and the symlink.

On no, stop there. Don't offer a container fallback: Docker Desktop's WSL integration is off
on this machine, so there isn't one.

## Workflow

### 1. Scan

```bash
"$SKILL_DIR"/scripts/scan.sh
```

The script works out the base ref itself, preferring `branch.<name>.forkedFrom` (set by
`git-workflow` when a branch is cut from something other than the default branch) over
`origin/master`, and passes it to semgrep as `--baseline-commit` so only what this branch
introduced is reported. It picks rule packs from the extensions actually touched, always
including `p/secrets`, and writes JSON to the scratchpad.

Useful arguments:

- `--base <ref>` when the inferred fork point is wrong.
- `--all` to scan the whole tree rather than the branch, for a first pass on a repo that has
  never been scanned. Expect a long, mostly pre-existing list.

A typical branch takes ten to fifteen seconds. The first run on a machine fetches the rule
packs from the registry and caches them under `~/.semgrep`, so it needs network once. The scan
runs with `--metrics=off`: findings, file paths and rule hit counts stay local, which matters
because this is private code.

### 2. Check the scan actually ran

The script exits non-zero and says so loudly when semgrep failed, because a scan that fell
over reports zero findings exactly like a clean branch does, and "0 findings" is the answer
everyone is happiest to believe. Never report a failed scan as a clean one.

Watch for two things in particular:

- **A fatal config error.** Usually a rule pack that does not exist in the registry, which
  404s and aborts the whole run. Fix the pack list in `scan.sh` rather than working around it.
- **Partial parsing.** Semgrep's C# parser trips on newer language syntax, and when it does,
  the rules are skipped on that file. The script lists any such file. Those files are not
  covered, so read them yourself and say in the report that you did.

### 3. Condense

```bash
python3 "$SKILL_DIR"/scripts/report.py <json-path>
```

Prints one block per finding, ordered by severity then confidence. Pass
`--severity WARNING` to drop the informational tail on a noisy run.

### 4. Triage

This is the step that matters. Take each finding and open the file at the reported line. The
OSS engine reports `"lines": "requires login"` instead of the matched source, so reading the
file is not optional, and the surrounding code is what decides the question anyway.

For each one, work out whether it is reachable and whether it matters here. Discard:

- Test fixtures, sample data and `.tpl` templates, where a hardcoded credential is the point.
- Input that is already validated or constrained upstream, where the sink is unreachable with
  attacker-controlled data.
- Findings on lines this branch did not touch, which `--baseline-commit` should have filtered
  but sometimes survive a rebase.
- Audit-category rules restating a deliberate architectural choice, when that choice is
  visible in the code.

Keep anything where user-controlled data reaches a dangerous sink, any credential that looks
real, and anything you cannot talk yourself out of. Uncertain and plausible beats silent: say
it is uncertain.

### 5. Report

Report in chat. Lead with the count that survived triage, not the count semgrep produced.

```
Semgrep: 7 findings, 2 survived triage.

1. SQL injection in IngressesController.cs:48
   User-supplied `filter` is concatenated into the command text. Use SqlParameter.
   csharp.lang.security.sqli.csharp-sqli (CWE-89)

2. ...

Discarded: 5 (3 in test fixtures, 1 unreachable, 1 pre-existing).
Not covered: AutodeskImportHarness.cs failed to parse; read it by hand, nothing found.
```

Then offer to fix what was found. Fixes are committed and pushed like any other change, per
`git-workflow`.

## Suppressions

An accepted finding gets a `// nosemgrep: <rule-id>` on the line above, with the reason on the
same comment. The bare `// nosemgrep` with no rule id suppresses everything on that line,
including a future finding nobody has seen yet, so always name the rule.

Never add a suppression unprompted. Propose it, say what it silences, and let the user decide.
If the reasoning runs longer than a comment, it belongs in the thread's investigation note.

## Known limits

Be straight about these in the report rather than implying coverage the scan does not have:

- **C# coverage is thin.** The community rules catch SQL injection and the obvious sinks, but
  miss plenty: weak hashing via `MD5.Create()` goes unflagged, for example. Most of the yield
  on this codebase lands in `Keyframe.UI` and the Terraform.
- **No pack exists for shell, HTML, SQL, YAML or JSON.** Those files are still swept by
  `p/secrets` for credentials, but nothing else.
- **Rules are patterns, not analysis.** Cross-file dataflow, authorisation logic and
  business-rule flaws are out of scope. That is what `/security-review` is for.
- **Zero findings means zero pattern matches**, which is not the same as secure. Say the
  former.
