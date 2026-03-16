#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -uo pipefail

MENU_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

print_menu() {
  printf '%s\n' 'Docker'
  printf '\n'
  printf '%s\n' ' 1) Menu'
  printf '%s\n' ' 2) DB up'
  printf '%s\n' ' 3) DB reset'
  printf '%s\n' ' 4) All up'
  printf '%s\n' ' 5) All down'
  printf '\n'
  printf '%s\n' ' 0) Back'
  printf '%s\n' ' r) Repeat'
  printf '%s\n' ' ------------------'
  printf '%s\n' ' Empty/space = back'
}

run() {
  bash "$MENU_DIR/$1" ${2:-}
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
    1) run 'docker.sh' ;;
    2) run 'tool/up.sh' 'db' ;;
    3) run 'tool/reset-db.sh' ;;
    4) run 'tool/up.sh' 'all' ;;
    5) run 'tool/down.sh' 'all' ;;
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
