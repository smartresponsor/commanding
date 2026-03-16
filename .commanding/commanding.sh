#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

print_menu() {
  ui_clear
  ui_banner "Commanding"
  printf '%s\n' ' 1) Route        6) Test          d) Dot'
  printf '%s\n' ' 2) Server       7) Docker        g) Git'
  printf '%s\n' ' 3) Fixture      8) Migration     c) Cache'
  printf '%s\n' ' 4) Schema       9) Composer      l) Log'
  printf '%s\n' ' 5) Patch (zip)  i) Inspection'
  printf '\n'
  printf '%s\n' ' 0) Exit'
  printf '%s\n' ' r) Refresh'
  printf '%s\n' ' -------------------------------'
  printf '%s\n' ' Empty/space = exit'
}

read_choice() {
  local first='' k='' buf=''
  IFS= read -rsn1 first 2>/dev/null || return 1

  if [[ "$first" == $'\n' || "$first" == $'\r' || "$first" == ' ' ]]; then
    printf ''
    return 0
  fi

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

  printf '%s' "$first"
}

dispatch() {
  local line="${1:-}"

  if [[ "$line" =~ ^[[:space:]]*$ ]]; then
    return 1
  fi

  case "$line" in
    0) return 1 ;;
    r|R) return 0 ;;
  esac

  if [[ "$line" =~ ^[0-9]+$ ]]; then
    bash "$COMMANDING_DIR/run.sh" chain "$line" || true
    return 0
  fi

  bash "$COMMANDING_DIR/run.sh" "$line" || true
  return 0
}

menu_loop() {
  while true; do
    print_menu
    printf '%s' ' Select: '

    local line=''
    line="$(read_choice || true)"
    printf '\n\n'

    dispatch "$line" || break
  done
}

main() {
  if [ $# -ge 1 ]; then
    dispatch "$1" || true
    return 0
  fi

  menu_loop
}

main "$@"
