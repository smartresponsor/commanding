#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

PROJECT_ROOT="$(detect_project_root)"

require_command git || exit 1

current_branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
remote_name="origin"

push_branch() {
  local branch_name="$1"
  [ -n "$branch_name" ] || {
    ui_warn "Current branch is not resolved."
    return 1
  }

  (
    cd "$PROJECT_ROOT"
    run_logged "Git push $remote_name $branch_name" git push "$remote_name" "$branch_name"
  )
}

push_branch_with_tags() {
  local branch_name="$1"
  [ -n "$branch_name" ] || {
    ui_warn "Current branch is not resolved."
    return 1
  }

  if ! ui_confirm "Push branch '$branch_name' with tags to $remote_name? [y/N]: "; then
    ui_note "Cancelled."
    return 0
  fi

  (
    cd "$PROJECT_ROOT"
    run_logged "Git push --tags $remote_name $branch_name" git push --tags "$remote_name" "$branch_name"
  )
}

while true; do
  ui_clear
  ui_banner "Deploy"

  printf '%s\n' "Deploy Menu"
  printf '%s\n' "-----------"
  printf '%s\n' "Current branch: ${current_branch:-unknown}"
  printf '%s\n' "Remote: $remote_name"
  printf '%s\n' ""
  printf '%s\n' "1) Push current branch"
  printf '%s\n' "2) Push origin/master"
  printf '%s\n' "3) Push current branch with tags"
  printf '%s\n' "4) Open action log"
  printf '%s\n' ""
  printf '%s\n' "Space) Exit"
  printf '%s'   "Choice: "

  key="$(ui_pick_key)"
  printf '\n'

  exit_code=0

  case "${key:-}" in
    1)
      push_branch "$current_branch" || exit_code=$?
      ;;
    2)
      if ! ui_confirm "Push branch 'master' to $remote_name? [y/N]: "; then
        ui_note "Cancelled."
      else
        push_branch "master" || exit_code=$?
      fi
      ;;
    3)
      push_branch_with_tags "$current_branch" || exit_code=$?
      ;;
    4)
      show_file "$(runtime_log_file)" || exit_code=$?
      ;;
    ""|0|q|Q)
      exit 0
      ;;
    *)
      ui_warn "Unknown action."
      ;;
  esac

  ui_note "Exit code: $exit_code"
  ui_pause_any
 done
