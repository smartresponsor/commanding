#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

ui_clear
ui_banner "Deploy"

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

printf '%s\n' "1) Push current branch (${current_branch:-unknown})"
printf '%s\n' "2) Push origin/master"
printf '%s\n' "3) Push with tags (current branch)"
printf '%s\n' ""
printf '%s\n' "Space) Exit"
printf '%s'   "Choice: "

key="$(ui_pick_key)"
printf '\n'

case "${key:-}" in
  1)
    [ -n "${current_branch:-}" ] || exit 0
    exec git push origin "${current_branch}"
    ;;
  2)
    exec git push origin master
    ;;
  3)
    [ -n "${current_branch:-}" ] || exit 0
    exec git push --tags origin "${current_branch}"
    ;;
  ""|0|q|Q)
    exit 0
    ;;
  *)
    printf '%s\n' "Unknown."
    exit 0
    ;;
esac
