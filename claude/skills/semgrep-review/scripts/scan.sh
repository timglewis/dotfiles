#!/usr/bin/env bash
# Run semgrep over the changes this branch introduces and write the findings as JSON.
#
# Scope matches /code-review: the branch's own diff, not the whole repo. Semgrep's
# --baseline-commit does the filtering, so a finding that already existed on the base
# branch is not reported here. Rule packs are chosen from the languages actually touched,
# because an unused pack costs download and scan time for nothing.
#
# Usage: scan.sh [--base <ref>] [--out <path>] [--all]
#   --base <ref>  Compare against this ref instead of the inferred fork point.
#   --out <path>  Write JSON here (default: a file under the scratchpad or /tmp).
#   --all         Scan the whole working tree, not just this branch's changes.

set -uo pipefail

BASE=""
OUT=""
SCAN_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base) BASE="$2"; shift 2 ;;
        --out)  OUT="$2";  shift 2 ;;
        --all)  SCAN_ALL=true; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

command -v semgrep >/dev/null 2>&1 || {
    echo "error: semgrep not on PATH. Run scripts/install-semgrep.sh first." >&2
    exit 127
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "error: not inside a git repository." >&2
    exit 2
}

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 2

# Where the branch was cut from. git-workflow records this in branch.<name>.forkedFrom
# for branches cut from something other than the default branch, so prefer it.
if [[ -z "$BASE" ]] && ! $SCAN_ALL; then
    BRANCH="$(git branch --show-current)"
    BASE="$(git config "branch.$BRANCH.forkedFrom" 2>/dev/null || true)"
    if [[ -z "$BASE" ]]; then
        BASE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
        [[ -z "$BASE" ]] && BASE="origin/master"
    fi
fi

if $SCAN_ALL; then
    BASELINE=""
    CHANGED="$(git ls-files)"
else
    BASELINE="$(git merge-base "$BASE" HEAD 2>/dev/null)"
    if [[ -z "$BASELINE" ]]; then
        echo "error: could not find a merge base with '$BASE'. Fetch it, or pass --base." >&2
        exit 2
    fi
    # Committed changes plus anything still in the working tree, so a review run before the
    # last commit sees the same code the user is looking at.
    CHANGED="$(
        { git diff --name-only --diff-filter=d "$BASELINE"...HEAD
          git diff --name-only --diff-filter=d HEAD
          git ls-files --others --exclude-standard
        } | sort -u
    )"
fi

if [[ -z "$CHANGED" ]]; then
    echo "No changes to scan against ${BASE:-the working tree}."
    exit 3
fi

# Rule packs, keyed off the extensions actually present. p/secrets always runs: a
# credential can land in any file type, including the config and template files that
# carry no language rules at all.
#
# Only packs that exist in the registry belong here. An unknown pack 404s, and semgrep
# treats that as a fatal config error that aborts the whole scan. There is no pack for
# shell, HTML, SQL, YAML or JSON: those files are still swept by p/secrets.
packs=("p/secrets")
add_pack() { for p in "${packs[@]}"; do [[ "$p" == "$1" ]] && return; done; packs+=("$1"); }

while IFS= read -r f; do
    case "$f" in
        *.cs)                         add_pack "p/csharp" ;;
        *.ts|*.tsx)                   add_pack "p/typescript" ;;
        *.js|*.jsx|*.mjs|*.cjs|*.vue) add_pack "p/javascript" ;;
        *.tf|*.tfvars)                add_pack "p/terraform" ;;
        *.py)                         add_pack "p/python" ;;
        *.go)                         add_pack "p/golang" ;;
        *.rb)                         add_pack "p/ruby" ;;
        *.java)                       add_pack "p/java" ;;
        *.kt|*.kts)                   add_pack "p/kotlin" ;;
        *.rs)                         add_pack "p/rust" ;;
        *.php)                        add_pack "p/php" ;;
        *Dockerfile|Dockerfile*|*.dockerfile) add_pack "p/dockerfile" ;;
    esac
done <<< "$CHANGED"

if [[ -z "$OUT" ]]; then
    OUT_DIR="${CLAUDE_SCRATCHPAD_DIR:-${TMPDIR:-/tmp}}"
    mkdir -p "$OUT_DIR"
    OUT="$OUT_DIR/semgrep-$(git rev-parse --abbrev-ref HEAD | tr '/' '-')-$(date +%s).json"
fi

config_args=()
for p in "${packs[@]}"; do config_args+=(--config "$p"); done

baseline_args=()
[[ -n "$BASELINE" ]] && baseline_args=(--baseline-commit "$BASELINE")

echo "Repo:       $REPO_ROOT"
echo "Base:       ${BASE:-(whole tree)}${BASELINE:+ ($BASELINE)}"
echo "Files:      $(wc -l <<< "$CHANGED") changed"
echo "Rule packs: ${packs[*]}"
echo

# --metrics=off keeps findings, file paths and rule hit counts off Semgrep's servers.
# This scans private code, so the default is not one worth inheriting.
semgrep scan \
    --metrics=off \
    --quiet \
    --timeout 60 \
    "${config_args[@]}" \
    "${baseline_args[@]}" \
    --json \
    --output "$OUT" \
    . 2>&1 | grep -viE '^(Scanning|Ruleset|  )' || true

status=${PIPESTATUS[0]}
if [[ ! -s "$OUT" ]]; then
    echo "error: semgrep produced no output (exit $status)." >&2
    exit 1
fi

# A scan that fell over reports zero findings exactly like a clean one does. Tell the two
# apart here, because "0 findings" is the answer a reviewer is most willing to believe.
summary=$(python3 - "$OUT" <<'PYSUM'
import json, sys

with open(sys.argv[1]) as fh:
    data = json.load(fh)

errors = data.get("errors", [])
fatal = [e for e in errors if e.get("level") == "error"]
warnings = [e for e in errors if e.get("level") != "error"]

print(len(data.get("results", [])))
print(len(data.get("paths", {}).get("scanned", [])))
print("|".join(str(e.get("message", ""))[:200] for e in fatal))

# Partial parsing means rules were skipped on that file: a coverage gap, not a clean file.
partial = set()
for w in warnings:
    kind = w.get("type")
    spans = kind[1] if isinstance(kind, list) and len(kind) > 1 else []
    if isinstance(spans, list):
        for span in spans:
            if isinstance(span, dict) and span.get("path"):
                partial.add(span["path"])
print("|".join(sorted(partial)))
PYSUM
)

count=$(sed -n 1p <<< "$summary")
scanned=$(sed -n 2p <<< "$summary")
fatal=$(sed -n 3p <<< "$summary")
partial=$(sed -n 4p <<< "$summary")

if [[ -n "$fatal" ]]; then
    echo "SCAN FAILED, do not report these results as clean:" >&2
    tr '|' '\n' <<< "$fatal" | sed 's/^/  /' >&2
    exit 1
fi

if [[ "$scanned" == "0" ]]; then
    echo "error: semgrep scanned 0 files. Treat this as a failed scan, not a clean one." >&2
    exit 1
fi

echo "Findings:   $count (over $scanned files scanned)"
if [[ -n "$partial" ]]; then
    echo
    echo "Partial parsing, rules were skipped on these files, so they are NOT covered:"
    tr '|' '\n' <<< "$partial" | sed 's/^/  /'
fi
echo
echo "JSON:       $OUT"
