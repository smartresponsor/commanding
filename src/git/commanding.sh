#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -uo pipefail

MENU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

print_menu() {
  printf '%s\n' 'Git'
  printf '\n'
  printf '%s\n' ' 1) Diff'
  printf '%s\n' ' 2) Status'
  printf '%s\n' ' 3) Sync'
  printf '\n'
  printf '%s\n' ' 0) Back'
  printf '%s\n' ' r) Repeat'
  printf '%s\n' ' ------------------'
  printf '%s\n' ' Empty/space = back'
}

run_file() {
  local f="$1"
  if [ ! -f "$MENU_DIR/$f" ]; then
    printf '%s\n' "Missing: $f"
    read -r -p 'Press Enter... ' _ || true
    return 0
  fi

  bash "$MENU_DIR/$f"
  local rc=$?
  if [ $rc -ne 0 ]; then
    printf '\n%s\n' "Exit code: $rc"
    read -r -p 'Press Enter... ' _ || true
  fi

  return 0
}

dispatch() {
  local line="${1:-}"

  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    exit 0
  fi

  case "$line" in
    0) exit 0 ;;
    r|R) return 0 ;;
    1) run_file 'git_diff.sh' ;;
    2) run_file 'git_status.sh' ;;
    3) run_file 'git_sync.sh' ;;
    *) printf '%s\n' 'Invalid choice'; sleep 1 ;;
  esac
}

main() {
  if [ $# -ge 1 ]; then
    dispatch "$1"
    exit 0
  fi

  while true; do
    clear
    print_menu
    printf '%s' 'Select: '
    read -r line || true
    printf '\n'
    dispatch "${line:-}"
  done
}

main "$@"
