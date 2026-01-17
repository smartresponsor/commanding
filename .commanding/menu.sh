#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export COMMANDING_DIR

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

banner() {
  printf '%s\n' "Commanding"
  local root
  root="$(repo_root)"
  if [ -n "${root:-}" ]; then
    printf '%s\n' "Repo: $root"
  else
    printf '%s\n' "Repo: not resolved"
  fi
  printf '\n'
}

print_menu() {
  printf '%s\n' " 1 Route        |"
  printf '%s\n' " 2 Server       |"
  printf '%s\n' " 3 Fixture      |"
  printf '%s\n' " 4 Schema       |"
  printf '%s\n' " 5 Patch to zip |"
  printf '%s\n' " 6 Test         |"
  printf '%s\n' " 7 Docker       |"
  printf '%s\n' " 8 Migration    |  g) Git    "
  printf '%s\n' " 9 Composer     |  c) Cache  "
  printf '%s\n' " 0 Exit         |  r) Repeat "
  printf '%s\n' "                |  l) Log     "
  printf '%s\n' " ----------------------------"
  printf '%s\n' " Empty/space = exit"
}

dispatch() {
  local line="${1:-}"

  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    exit 0
  fi

  case "$line" in
    0) exit 0 ;;
  esac

  if [[ "$line" =~ ^[0-9]+$ ]]; then
    exec bash "$COMMANDING_DIR/run.sh" chain "$line"
  fi

  exec bash "$COMMANDING_DIR/run.sh" "$line"
}

main() {
  # allow: ./menu.sh 6  |  ./menu.sh 1332  |  ./menu.sh g
  if [ $# -ge 1 ]; then
    dispatch "$1"
  fi

  while true; do
    clear
    banner
    print_menu
    printf '%s' "Select: "
    read -r line || true
    printf '\n'
    dispatch "${line:-}"
  done
}

main "$@"
