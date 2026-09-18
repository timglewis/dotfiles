#!/usr/bin/env python3
"""Condense a semgrep JSON run into a compact triage list.

The raw JSON carries licence text, reference URLs and rule metadata on every hit, which
is mostly noise to read through and expensive to hold in context. This prints one block
per finding with the fields triage actually turns on, ordered so the ones most likely to
be real come first.

Note the OSS engine reports `"lines": "requires login"` rather than the matched source,
so triage has to open the file at the reported line. That is the right thing to do
anyway: the surrounding code is what decides whether a finding is real.

Usage: report.py <semgrep.json> [--severity ERROR|WARNING|INFO]
"""

import json
import sys
from collections import Counter

SEVERITY_ORDER = {"ERROR": 0, "WARNING": 1, "INFO": 2}
CONFIDENCE_ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__, file=sys.stderr)
        return 2

    path = args[0]
    floor = None
    if "--severity" in args:
        floor = args[args.index("--severity") + 1].upper()

    with open(path) as fh:
        data = json.load(fh)

    results = data.get("results", [])
    if floor:
        cutoff = SEVERITY_ORDER.get(floor, 2)
        results = [
            r for r in results
            if SEVERITY_ORDER.get(r["extra"].get("severity", "INFO"), 2) <= cutoff
        ]

    def sort_key(r):
        meta = r["extra"].get("metadata", {})
        return (
            SEVERITY_ORDER.get(r["extra"].get("severity", "INFO"), 3),
            CONFIDENCE_ORDER.get(meta.get("confidence", "LOW"), 3),
            r["path"],
            r["start"]["line"],
        )

    results.sort(key=sort_key)

    if not results:
        print("No findings.")
        return 0

    by_severity = Counter(r["extra"].get("severity", "INFO") for r in results)
    print(f"{len(results)} findings: " + ", ".join(
        f"{n} {sev.lower()}" for sev, n in sorted(
            by_severity.items(), key=lambda kv: SEVERITY_ORDER.get(kv[0], 3)
        )
    ))
    print()

    for i, r in enumerate(results, 1):
        extra = r["extra"]
        meta = extra.get("metadata", {})
        line = r["start"]["line"]
        end = r["end"]["line"]
        span = f"{line}" if line == end else f"{line}-{end}"

        print(f"[{i}] {extra.get('severity', 'INFO')} "
              f"confidence={meta.get('confidence', '?')} "
              f"impact={meta.get('impact', '?')} "
              f"likelihood={meta.get('likelihood', '?')}")
        print(f"    rule:  {r['check_id']}")
        print(f"    where: {r['path']}:{span}")
        for cwe in meta.get("cwe", [])[:2]:
            print(f"    cwe:   {cwe}")
        message = " ".join(extra.get("message", "").split())
        print(f"    what:  {message}")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
