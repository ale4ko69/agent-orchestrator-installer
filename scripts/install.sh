#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-./project.config.json}"
shift || true
EXTRA_ARGS=("$@")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install.py"

if [[ ! -f "$INSTALLER" ]]; then
  echo "install.py not found: $INSTALLER" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  python3 "$INSTALLER" "$CONFIG_PATH" "${EXTRA_ARGS[@]}"
elif command -v python >/dev/null 2>&1; then
  python "$INSTALLER" "$CONFIG_PATH" "${EXTRA_ARGS[@]}"
else
  echo "Python 3 is required. Please install python3 and retry." >&2
  exit 1
fi
