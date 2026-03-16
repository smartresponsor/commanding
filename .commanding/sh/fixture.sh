#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

PROJECT_ROOT="$(detect_project_root)"
CONSOLE_BIN="$PROJECT_ROOT/bin/console"

require_command php || exit 1
require_file "$CONSOLE_BIN" || exit 1

run_console() {
  local label="$1"
  shift

  run_logged "$label" php "$CONSOLE_BIN" "$@"
}

load_fixture_replace() {
  ui_warn "This action truncates current fixture data before reloading."
  if ! ui_confirm "Continue with fixture replace load? [y/N]: "; then
    ui_note "Cancelled."
    return 0
  fi

  run_console "Fixture load --replace" doctrine:fixtures:load --purge-with-truncate --no-interaction
}

load_fixture_append() {
  run_console "Fixture load --append" doctrine:fixtures:load --append --no-interaction
}

run_avatar_download() {
  local count=""
  read -r -p "Avatar count: " count || true

  if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -le 0 ]; then
    ui_error "Avatar count must be a positive integer."
    return 1
  fi

  run_console "Avatar download --count=$count" app:avatar-download --count="$count"
}

while true; do
  ui_clear
  ui_banner "Fixture"

  printf '%s\n' "Fixture Menu"
  printf '%s\n' "------------"
  printf '%s\n' "1) Replace fixture data"
  printf '%s\n' "2) Append fixture data"
  printf '%s\n' "3) Download profile avatars"
  printf '%s\n' "4) Open action log"
  printf '%s\n' ""
  printf '%s\n' "Space) Exit"
  printf '%s'   "Choice: "

  action="$(ui_pick_key)"
  printf '\n'

  exit_code=0

  case "${action:-}" in
    1)
      load_fixture_replace || exit_code=$?
      ;;
    2)
      load_fixture_append || exit_code=$?
      ;;
    3)
      run_avatar_download || exit_code=$?
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
