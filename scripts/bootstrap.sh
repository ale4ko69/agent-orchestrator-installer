#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:-}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
TASK_PREFIX="${TASK_PREFIX:-TASK}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
CONFIG_PATH="$SCRIPT_DIR/project.config.bootstrap.json"

if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "install.sh not found near bootstrap.sh: $INSTALL_SCRIPT" >&2
  exit 1
fi

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
    if [[ ! -d "$PROJECT_PATH" ]]; then
      echo "Provided PROJECT_PATH does not exist: $PROJECT_PATH" >&2
      exit 1
    fi
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

PROJECT_ROOT="$(resolve_project_path)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
PROJECT_ROOT_POSIX="$(echo "$PROJECT_ROOT" | sed 's#\\#/#g')"

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

