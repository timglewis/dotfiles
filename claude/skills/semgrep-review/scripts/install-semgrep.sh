#!/usr/bin/env bash
# Install semgrep into a dedicated venv and expose it on PATH.
#
# Ubuntu 24.04 marks the system Python as externally managed (PEP 668), so a plain
# `pip install --user semgrep` is refused. A dedicated venv sidesteps that without
# sudo and without touching system packages: to uninstall, delete the venv and the
# symlink.
#
# Idempotent: safe to re-run, and `--upgrade` moves an existing install forward.

set -euo pipefail

VENV="${SEMGREP_VENV:-$HOME/.local/share/semgrep-venv}"
BIN_DIR="${SEMGREP_BIN_DIR:-$HOME/.local/bin}"
LINK="$BIN_DIR/semgrep"

upgrade=false
[[ "${1:-}" == "--upgrade" ]] && upgrade=true

if [[ -x "$LINK" ]] && ! $upgrade; then
    echo "semgrep already installed: $("$LINK" --version 2>/dev/null || echo unknown)"
    exit 0
fi

if ! python3 -c 'import venv' 2>/dev/null; then
    echo "error: python3 venv module missing. Install it with: sudo apt install python3-venv" >&2
    exit 1
fi

if [[ ! -d "$VENV" ]]; then
    echo "Creating venv at $VENV"
    python3 -m venv "$VENV"
fi

echo "Installing semgrep (this pulls a large wheel, give it a minute)"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet --upgrade semgrep

mkdir -p "$BIN_DIR"
ln -sf "$VENV/bin/semgrep" "$LINK"

if ! command -v semgrep >/dev/null 2>&1; then
    echo "warning: $BIN_DIR is not on PATH. Add it to your shell profile." >&2
fi

echo "Installed: $("$LINK" --version)"
