#!/usr/bin/env python3
"""Derive the lifecycle status of every ticketed code thread in the vault.

Reads each thread's frontmatter, the branches of every worktree repo under the code root, and the
project's pull requests on Azure DevOps, then prints one row per thread as JSON. With --apply it
writes the derived status (and stamps updated:) for the keys named, and nothing else.

The lifecycle itself is defined in the obsidian skill; this script implements it.
"""

import argparse
import datetime
import json
import pathlib
import re
import subprocess
import sys

VAULT = pathlib.Path.home() / "Obsidian" / "keyframe" / "Threads"
CODE_ROOT = pathlib.Path.home() / "code"
ORG = "https://dev.azure.com/keyframe-ai"
PROJECT = "KeyframeAI"
PR_LIMIT = 1000

ORDER = ["planned", "coding", "review", "done"]
HELD = {"paused", "dropped"}


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        return {}

    fields = {}
    for line in match.group(1).splitlines():
        field = re.match(r"^([a-z]+):\s*(.*?)\s*$", line)
        if field:
            fields[field.group(1)] = field.group(2)

    return fields


def threads():
    for index in sorted(VAULT.rglob("index.md")):
        fields = frontmatter(index)
        if fields.get("kind") == "code" and fields.get("ticket"):
            yield index, fields


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

    # A thread older than the oldest PR fetched may have PRs the query did not reach.
    truncated = len(prs) >= PR_LIMIT and any(row["created"] and row["created"] < oldest_pr for row in rows)
    return {"rows": rows, "branch_errors": errors, "prs_fetched": len(prs), "oldest_pr": oldest_pr,
            "pr_history_may_be_truncated": truncated}


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", nargs="+", metavar="KEY=STATUS",
                        help="write these statuses, e.g. TACO-1234=done TACO-1300=coding")
    args = parser.parse_args()

    if args.apply:
        pairs = [pair.split("=", 1) for pair in args.apply]
        bad = [pair for pair in pairs if len(pair) != 2 or pair[1] not in ORDER]
        if bad:
            parser.error(f"expected KEY=STATUS with STATUS one of {', '.join(ORDER)}")
        apply([key for key, _ in pairs], [status for _, status in pairs])
        return

    json.dump(sweep(), sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
