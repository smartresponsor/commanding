#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -uo pipefail

print_menu() {
  printf '%s\n' 'Dependencies'
  printf '\n'
  printf '%s\n' ' 0) Back'
  printf '%s\n' ' r) Repeat'
  printf '%s\n' ' ------------------'
  printf '%s\n' ' Empty/space = back'
}

dispatch() {
  local line="${1:-}"

  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    exit 0
  fi

  case "$line" in
    0) exit 0 ;;
    r|R) return 0 ;;
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
