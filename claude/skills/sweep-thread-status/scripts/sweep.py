#!/usr/bin/env python3
"""Derive the lifecycle status of every ticketed code thread in the vault, and find untagged threads.

Reads each thread's frontmatter, the branches of every worktree repo under the code root, and the
project's pull requests on Azure DevOps, then prints one row per ticketed thread as JSON, alongside
every thread of any kind whose tags: is empty. With --apply it writes the derived status for the
keys named; with --tag it writes tags on threads that have none. Both stamp updated:, and neither
touches anything else.

The lifecycle and the frontmatter schema are defined in the obsidian skill; this script implements
them. The tag list itself lives in Threads/tags.md, which --tag validates against.
"""

import argparse
import datetime
import json
import os
import pathlib
import re
import subprocess
import sys

# Defaults match the layout the skills assume. Override any of them in the environment
# rather than editing here, so an update to this file doesn't clobber the setting.
VAULT = pathlib.Path(os.environ.get("KEYFRAME_VAULT", pathlib.Path.home() / "Obsidian" / "keyframe")) / "Threads"
CODE_ROOT = pathlib.Path(os.environ.get("KEYFRAME_CODE_ROOT", pathlib.Path.home() / "code"))
ORG = os.environ.get("KEYFRAME_AZDO_ORG", "https://dev.azure.com/keyframe-ai")
PROJECT = os.environ.get("KEYFRAME_AZDO_PROJECT", "KeyframeAI")
TAGS_INDEX = VAULT / "tags.md"
PR_LIMIT = 1000

ORDER = ["planned", "coding", "review", "done"]
HELD = {"paused", "dropped"}


def frontmatter(path):
    """Scalars as strings, block lists as lists. Enough of YAML for the thread schema."""
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        return {}

    fields = {}
    key = None
    for line in match.group(1).splitlines():
        item = re.match(r"^\s+-\s*(.*?)\s*$", line)
        if item and key:
            if not isinstance(fields.get(key), list):
                fields[key] = []
            fields[key].append(item.group(1))
            continue

        field = re.match(r"^([a-z]+):\s*(.*?)\s*$", line)
        key = field.group(1) if field else None
        if field:
            fields[key] = field.group(2)

    return fields


def listing(value):
    """A frontmatter list, whether it arrived as a block list or inline [a, b]."""
    if isinstance(value, list):
        return [item for item in value if item]

    value = (value or "").strip()
    if value.startswith("["):
        value = value[1:-1]
    return [item.strip().strip("\"'") for item in value.split(",") if item.strip()]


def all_threads():
    for index in sorted(VAULT.rglob("index.md")):
        fields = frontmatter(index)
        if fields.get("kind"):
            yield index, fields


def threads():
    for index, fields in all_threads():
        if fields.get("kind") == "code" and isinstance(fields.get("ticket"), str) and fields["ticket"]:
            yield index, fields


def ref(index, fields):
    """How a thread is named on the command line: its key, or its folder when it has none."""
    ticket = fields.get("ticket")
    return ticket if isinstance(ticket, str) and ticket else index.parent.name


def documented_tags():
    """The tags with a row in Threads/tags.md, which is the canonical list."""
    if not TAGS_INDEX.exists():
        return None

    text = TAGS_INDEX.read_text(encoding="utf-8")
    return {match.group(1) for match in re.finditer(r"^\|\s*`([^`]+)`\s*\|", text, re.M)}


def run(args, cwd=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=180)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(args[:3])} failed: {result.stderr.strip()}")

    return result.stdout


def branches():
    """Branch names from every worktree repo, local and on origin, lower-cased."""
    names = set()
    errors = []
    for bare in sorted(CODE_ROOT.glob("*/.bare")):
        local = run(["git", "for-each-ref", "--format=%(refname:short)", "refs/heads"], cwd=bare)
        names.update(name.lower() for name in local.split())
        try:
            remote = run(["git", "ls-remote", "--heads", "origin"], cwd=bare)
            names.update(line.split("refs/heads/", 1)[1].lower() for line in remote.splitlines())
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            errors.append(f"{bare.parent.name}: {error}")

    return names, errors


def pull_requests():
    query = (
        "[].{id:pullRequestId,repo:repository.name,status:status,draft:isDraft,"
        "title:title,branch:sourceRefName,created:creationDate}"
    )
    output = run([
        "az", "repos", "pr", "list", "--org", ORG, "--project", PROJECT,
        "--status", "all", "--top", str(PR_LIMIT), "--query", query, "-o", "json",
    ])
    return json.loads(output)


def owns(key, name):
    """True when a branch name or PR title belongs to the ticket key."""
    return re.search(rf"(?<![a-z0-9]){re.escape(key.lower())}(?![0-9])", name.lower()) is not None


def derive(key, branch_names, prs):
    mine = [pr for pr in prs
            if owns(key, pr["title"]) or owns(key, pr["branch"].removeprefix("refs/heads/"))]
    active = [pr for pr in mine if pr["status"] == "active"]
    completed = [pr for pr in mine if pr["status"] == "completed"]
    branch = sorted(name for name in branch_names if re.match(rf"{re.escape(key.lower())}(-|$)", name))

    evidence = [f"PR {pr['id']} {pr['status']}{' (draft)' if pr['draft'] else ''} in {pr['repo']}"
                for pr in mine]
    evidence += [f"branch {name}" for name in branch]

    if active:
        return "review", evidence
    if completed:
        return "done", evidence
    if branch:
        return "coding", evidence
    return "planned", evidence


def move(current, derived):
    if current == derived:
        return "none"
    if current in HELD:
        return "held"
    if current not in ORDER:
        return "migrate"
    return "forward" if ORDER.index(derived) > ORDER.index(current) else "backward"


def sweep():
    branch_names, errors = branches()
    prs = pull_requests()

    oldest_pr = min((pr["created"][:10] for pr in prs), default=None)
    rows = []
    for index, fields in threads():
        derived, evidence = derive(fields["ticket"], branch_names, prs)
        rows.append({
            "ticket": fields["ticket"],
            "title": fields.get("title", "").strip("\"'"),
            "created": fields.get("created"),
            "current": fields.get("status"),
            "derived": derived,
            "move": move(fields.get("status"), derived),
            "evidence": evidence,
            "path": str(index),
        })

    untagged, in_use = tag_survey()

    # A thread older than the oldest PR fetched may have PRs the query did not reach.
    truncated = len(prs) >= PR_LIMIT and any(row["created"] and row["created"] < oldest_pr for row in rows)
    return {"rows": rows, "untagged": untagged, "tags_in_use": in_use, "branch_errors": errors,
            "prs_fetched": len(prs), "oldest_pr": oldest_pr,
            "pr_history_may_be_truncated": truncated}


def tag_survey():
    """Every thread with no tags, and how often each tag already in use appears."""
    untagged = []
    in_use = {}
    for index, fields in all_threads():
        tags = listing(fields.get("tags"))
        for tag in tags:
            in_use[tag] = in_use.get(tag, 0) + 1

        if not tags:
            ticket = fields.get("ticket")
            untagged.append({
                "ref": ref(index, fields),
                "kind": fields["kind"],
                "ticket": ticket if isinstance(ticket, str) and ticket else None,
                "title": str(fields.get("title", "")).strip("\"'"),
                "folder": index.parent.name,
                "path": str(index),
            })

    return untagged, dict(sorted(in_use.items(), key=lambda pair: (-pair[1], pair[0])))


def apply(keys, statuses):
    today = datetime.date.today().isoformat()
    wanted = {key.upper(): status for key, status in zip(keys, statuses)}
    for index, fields in threads():
        status = wanted.pop(fields["ticket"].upper(), None)
        if status is None:
            continue

        text = index.read_text(encoding="utf-8")
        head, body = text.split("\n---\n", 1)
        head = re.sub(r"(?m)^status:.*$", f"status: {status}", head, count=1)
        head = re.sub(r"(?m)^updated:.*$", f"updated: {today}", head, count=1)
        index.write_text(f"{head}\n---\n{body}", encoding="utf-8")
        print(f"{fields['ticket']}: {fields.get('status')} -> {status}")

    for key in wanted:
        print(f"{key}: no ticketed code thread found", file=sys.stderr)


def write_tags(wanted):
    """Write tags on threads that have none. A thread already tagged is left for the user."""
    today = datetime.date.today().isoformat()
    documented = documented_tags()
    unknown = sorted({tag for tags in wanted.values() for tag in tags} - documented) if documented else []
    if unknown:
        print(f"not in {TAGS_INDEX}: {', '.join(unknown)}. Add a row for each before tagging.",
              file=sys.stderr)
        return 1

    for name, tags in wanted.items():
        missing = sorted({tag.rsplit("/", 1)[0] for tag in tags if "/" in tag} - set(tags))
        if missing:
            print(f"note: {name} carries a nested tag without its parent: {', '.join(missing)}",
                  file=sys.stderr)

    for index, fields in all_threads():
        tags = wanted.pop(ref(index, fields), None)
        if tags is None:
            continue

        if listing(fields.get("tags")):
            print(f"{ref(index, fields)}: already tagged, left alone", file=sys.stderr)
            continue

        text = index.read_text(encoding="utf-8")
        head, body = text.split("\n---\n", 1)
        if not re.search(r"(?m)^tags:", head):
            print(f"{ref(index, fields)}: no tags: line in the frontmatter, left alone", file=sys.stderr)
            continue

        head = set_tags(head, tags)
        head = re.sub(r"(?m)^updated:.*$", f"updated: {today}", head, count=1)
        index.write_text(f"{head}\n---\n{body}", encoding="utf-8")
        print(f"{ref(index, fields)}: tags {', '.join(tags)}")

    for name in wanted:
        print(f"{name}: no thread found", file=sys.stderr)

    return 0


def set_tags(head, tags):
    """Replace the tags: line, and any block list under it, with a block list of tags."""
    lines = head.splitlines()
    out = []
    index = 0
    while index < len(lines):
        if not re.match(r"^tags:", lines[index]):
            out.append(lines[index])
            index += 1
            continue

        index += 1
        while index < len(lines) and re.match(r"^\s+-\s", lines[index]):
            index += 1
        out.append("tags:" if tags else "tags: []")
        out.extend(f"  - {tag}" for tag in tags)

    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", nargs="+", metavar="KEY=STATUS",
                        help="write these statuses, e.g. TACO-1234=done TACO-1300=coding")
    parser.add_argument("--tag", nargs="+", metavar="REF=TAGS",
                        help="tag these threads, e.g. TACO-1234=autodesk,spatial-index. REF is the "
                             "ticket key, or the folder name for a thread without one, as the "
                             "untagged rows give it")
    args = parser.parse_args()

    if args.apply:
        pairs = [pair.split("=", 1) for pair in args.apply]
        bad = [pair for pair in pairs if len(pair) != 2 or pair[1] not in ORDER]
        if bad:
            parser.error(f"expected KEY=STATUS with STATUS one of {', '.join(ORDER)}")
        apply([key for key, _ in pairs], [status for _, status in pairs])

    if args.tag:
        pairs = [pair.split("=", 1) for pair in args.tag]
        bad = [pair for pair in pairs if len(pair) != 2 or not pair[1].strip()]
        if bad:
            parser.error("expected REF=TAGS with at least one comma-separated tag")
        wanted = {name: [tag.strip() for tag in tags.split(",") if tag.strip()]
                  for name, tags in pairs}
        failed = write_tags(wanted)
        if failed:
            sys.exit(failed)

    if args.apply or args.tag:
        return

    json.dump(sweep(), sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
