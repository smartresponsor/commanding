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
  printf '%s\n' " Enter/space = exit"
}

read_choice() {
  local first="" k="" buf=""

  # single key (no Enter)
  IFS= read -rsn1 first 2>/dev/null || return 1

  # Enter / Space => exit
  if [[ "$first" == $'\n' || "$first" == $'\r' || "$first" == ' ' ]]; then
    printf ''
    return 0
  fi

  # digits: allow multi-digit input without Enter (short idle timeout)
  if [[ "$first" =~ [0-9] ]]; then
    buf="$first"
    while IFS= read -rsn1 -t 0.20 k 2>/dev/null; do
      if [[ "$k" =~ [0-9] ]]; then
        buf+="$k"
        continue
      fi
      if [[ "$k" == $'\n' || "$k" == $'\r' ]]; then
        break
      fi
      break
    done
    printf '%s' "$buf"
    return 0
  fi

  # letters like g/c/r/l
  printf '%s' "$first"
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
  # allow: ./commanding.sh 6  |  ./commanding.sh 1332  |  ./commanding.sh g
  if [ $# -ge 1 ]; then
    dispatch "$1"
  fi

  while true; do
    clear
    banner
    print_menu
    printf '%s\n' " Select: "

    local line=""
    line="$(read_choice || true)"

    printf '\n'
    dispatch "${line:-}"
  done
}

main "$@"
