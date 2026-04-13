#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/ale4ko69/agent-orchestrator-installer}"
REF="${REF:-main}"
PROJECT_PATH="${1:-}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
TASK_PREFIX="${TASK_PREFIX:-TASK}"

is_project_folder() {
  local p="$1"
  [[ -d "$p" ]] || return 1
  [[ -e "$p/.git" ]] && return 0
  [[ -f "$p/package.json" ]] && return 0
  [[ -f "$p/pyproject.toml" ]] && return 0
  [[ -f "$p/requirements.txt" ]] && return 0
  [[ -f "$p/go.mod" ]] && return 0
  [[ -f "$p/Cargo.toml" ]] && return 0
  [[ -f "$p/pom.xml" ]] && return 0
  return 1
}

resolve_project_path() {
  if [[ -n "$PROJECT_PATH" ]]; then
    [[ -d "$PROJECT_PATH" ]] || { echo "Provided PROJECT_PATH does not exist: $PROJECT_PATH" >&2; exit 1; }
    cd "$PROJECT_PATH" && pwd
    return
  fi

  local cwd
  cwd="$(pwd)"
  if is_project_folder "$cwd"; then
    read -r -p "Current folder looks like a project: $cwd. Use it? [Y/n]: " ans
    ans="${ans:-Y}"
    if [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
      echo "$cwd"
      return
    fi
  else
    echo "Current folder does not look like a project root."
  fi

  while true; do
    read -r -p "Enter project folder path: " manual
    if [[ -n "$manual" && -d "$manual" ]]; then
      cd "$manual" && pwd
      return
    fi
    echo "Path not found: $manual"
  done
}

normalize_repo_url() {
  local u="$1"
  u="${u%.git}"
  u="${u%/}"
  if [[ ! "$u" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
    echo "Repo URL must be: https://github.com/<owner>/<repo>" >&2
    exit 1
  fi
  echo "$u"
}

PROJECT_ROOT="$(resolve_project_path)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
REPO_BASE="$(normalize_repo_url "$REPO_URL")"
PROJECT_ROOT_POSIX="$(echo "$PROJECT_ROOT" | sed 's#\\#/#g')"

TMP_ROOT="$PROJECT_ROOT/.tmp/agent-installer"
SRC_ROOT="$TMP_ROOT/src"
ZIP_PATH="$TMP_ROOT/installer.zip"

mkdir -p "$TMP_ROOT"
rm -rf "$SRC_ROOT"
mkdir -p "$SRC_ROOT"

ZIP_URL="$REPO_BASE/archive/refs/heads/$REF.zip"
echo "Downloading installer archive: $ZIP_URL"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"
elif command -v wget >/dev/null 2>&1; then
  wget -q "$ZIP_URL" -O "$ZIP_PATH"
else
  echo "curl or wget is required." >&2
  exit 1
fi

if command -v unzip >/dev/null 2>&1; then
  unzip -q "$ZIP_PATH" -d "$SRC_ROOT"
else
  echo "unzip is required." >&2
  exit 1
fi

EXTRACTED_ROOT="$(find "$SRC_ROOT" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[[ -n "$EXTRACTED_ROOT" ]] || { echo "Failed to extract installer archive." >&2; exit 1; }

INSTALL_SCRIPT="$EXTRACTED_ROOT/scripts/install.sh"
[[ -f "$INSTALL_SCRIPT" ]] || { echo "install.sh not found in extracted archive: $INSTALL_SCRIPT" >&2; exit 1; }

CONFIG_PATH="$TMP_ROOT/project.config.bootstrap.json"
cat > "$CONFIG_PATH" <<EOF
{
  "projectName": "$PROJECT_NAME",
  "projectRoot": "$PROJECT_ROOT_POSIX",
  "codexHome": "$PROJECT_ROOT_POSIX/.ai",
  "mainBranch": "$MAIN_BRANCH",
  "taskPrefix": "$TASK_PREFIX"
}
EOF

echo "Bootstrap config created: $CONFIG_PATH"
echo "Project: $PROJECT_NAME"
echo "Project root: $PROJECT_ROOT"

bash "$INSTALL_SCRIPT" "$CONFIG_PATH"

