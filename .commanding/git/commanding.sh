#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

MENU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

print_menu() {
  ui_clear
  ui_banner 'Git'
  printf '%s\n' ' 1) Diff'
  printf '%s\n' ' 2) Status'
  printf '%s\n' ' 3) Sync'
  printf '\n'
  printf '%s\n' ' 0) Back'
  printf '%s\n' ' r) Refresh'
  printf '%s\n' ' ------------------'
  printf '%s\n' ' Empty/space = back'
}

run_file() {
  local file_name="$1"
  local target="$MENU_DIR/$file_name"

  if [ ! -f "$target" ]; then
    ui_error "Missing: $file_name"
    ui_pause_any
    return 0
  fi

  log_action "git menu: $file_name"

  set +e
  bash "$target"
  local rc=$?
  set -e

  if [ $rc -ne 0 ]; then
    ui_error "Exit code: $rc"
    ui_pause_any
  fi

  return 0
}

dispatch() {
  local line="${1:-}"

  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    return 1
  fi

  case "$line" in
    0) return 1 ;;
    r|R) return 0 ;;
    1) run_file 'git_diff.sh' ;;
    2) run_file 'git_status.sh' ;;
    3) run_file 'git_sync.sh' ;;
    *) ui_warn 'Invalid choice'; sleep 1 ;;
  esac
}

main() {
  if [ $# -ge 1 ]; then
    dispatch "$1" || true
    return 0
  fi

  while true; do
    print_menu
    printf '%s' ' Select: '
    local line=''
    read -r line || true
    printf '\n'
    dispatch "$line" || break
  done
}

main "$@"
