#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel 2>/dev/null
    return 0
  fi

  if [ -n "${COMMANDING_DIR:-}" ] && git -C "$COMMANDING_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$COMMANDING_DIR" rev-parse --show-toplevel 2>/dev/null
    return 0
  fi

  return 1
}

detect_project_root() {
  local root=""
  root="$(repo_root || true)"
  if [ -n "$root" ]; then
    printf '%s
' "$root"
    return 0
  fi

  if [ -n "${COMMANDING_DIR:-}" ]; then
    printf '%s
' "$COMMANDING_DIR"
    return 0
  fi

  pwd
}

ensure_runtime_dirs() {
  local root
  root="$(detect_project_root)"
  mkdir -p "$root/logs"
}

runtime_log_file() {
  local root
  root="$(detect_project_root)"
  printf '%s
' "$root/logs/actions.log"
}

runtime_error_file() {
  local root
  root="$(detect_project_root)"
  printf '%s
' "$root/logs/error.log"
}

action_log_file() {
  runtime_log_file
}

json_escape() {
  local value="${1:-}"
  value=${value//\/\\}
  value=${value//"/\"}
  value=${value//$'
'/\n}
  value=${value//$''/\r}
  value=${value//$'	'/\t}
  printf '%s' "$value"
}

json_bool() {
  if [ "${1:-0}" = "1" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

emit_json_result() {
  local status="${1:-ok}"
  local component="${2:-commanding}"
  local detail="${3:-}"
  local project_root=""
  project_root="$(detect_project_root)"
  printf '{"status":"%s","component":"%s","detail":"%s","project_root":"%s"}
'     "$(json_escape "$status")"     "$(json_escape "$component")"     "$(json_escape "$detail")"     "$(json_escape "$project_root")"
}

log_action() {
  ensure_runtime_dirs
  local log_file
  log_file="$(runtime_log_file)"
  printf '[%s] %s
' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$log_file"
}

log_error() {
  ensure_runtime_dirs
  local error_file
  error_file="$(runtime_error_file)"
  printf '[%s] %s
' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$error_file"
}

run_logged() {
  if [ "$#" -lt 2 ]; then
    ui_error "run_logged requires a label and a command."
    return 2
  fi

  local label="$1"
  shift

  ensure_runtime_dirs
  local error_file
  error_file="$(runtime_error_file)"

  log_action "$label"

  if "$@" 2>>"$error_file"; then
    log_action "$label [ok]"
    return 0
  fi

  local exit_code=$?
  log_action "$label [exit:$exit_code]"
  return "$exit_code"
}

show_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    ui_warn "File not found: $path"
    return 1
  fi

  if command -v less >/dev/null 2>&1; then
    less "$path"
    return 0
  fi

  cat "$path"
}

ui_banner() {
  local title="${1:-Commanding}"
  local root=""
  local branch=""

  root="$(repo_root || true)"
  if [ -n "$root" ] && git -C "$root" rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi

  printf '
'
  printf ' %s
' "$title"
  printf ' %s
' "$(printf '%.0s-' $(seq 1 ${#title}))"
  printf ' Repo: %s
' "${root:-not resolved}"
  if [ -n "$branch" ]; then
    printf ' Branch: %s
' "$branch"
  fi
  printf '
'
}

ui_pause_any() {
  local msg="${1:-Press any key to continue...}"
  IFS= read -rsn1 -p "$msg" _ 2>/dev/null || true
  printf '
'
  return 0
}

ui_clear() {
  clear || true
}

ui_pick_key() {
  local k=""
  IFS= read -rsn1 k 2>/dev/null || true
  if [[ "$k" == $'
' || "$k" == $'' || "$k" == ' ' ]]; then
    printf ''
    return 0
  fi
  printf '%s' "$k"
}

ui_note() {
  printf '%s
' "$*"
}

ui_warn() {
  printf 'Warning: %s
' "$*" >&2
}

ui_error() {
  printf 'Error: %s
' "$*" >&2
}

ui_confirm() {
  local prompt="${1:-Are you sure? [y/N]: }"
  local answer=""
  read -r -p "$prompt" answer || true
  case "$answer" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  ui_error "Required command is not available: $command_name"
  return 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_file() {
  local file_path="$1"
  if [ -f "$file_path" ]; then
    return 0
  fi

  ui_error "Required file is not available: $file_path"
  return 1
}
