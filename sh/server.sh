#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

PROJECT_ROOT="$(detect_project_root)"
EXIT_CODE=0

require_runtime() {
  local missing=0

  if ! command_exists symfony; then
    ui_error "Symfony CLI is not available in PATH"
    missing=1
  fi

  if ! command_exists php; then
    ui_error "PHP is not available in PATH"
    missing=1
  fi

  if [ ! -f "$PROJECT_ROOT/bin/console" ]; then
    ui_error "bin/console not found in project root: $PROJECT_ROOT"
    missing=1
  fi

  [ "$missing" -eq 0 ]
}

run_server_action() {
  local label="$1"
  shift || true
  run_logged "$label" "$@" || EXIT_CODE=$?
}

server_restart() {
  ui_note "Restarting Symfony local server..."
  run_server_action "Server stop" symfony server:stop
  run_server_action "Server start detached" symfony server:start -d
}

server_restart_with_cache() {
  ui_note "Restarting server and refreshing cache..."
  run_server_action "Server stop" symfony server:stop
  run_server_action "Cache clear" php bin/console cache:clear
  run_server_action "Cache warmup dev" php bin/console cache:warmup --env=dev
  run_server_action "Server start detached" symfony server:start -d
}

server_restart_with_schema() {
  ui_warn "This action updates the database schema with --force."
  if ! ui_confirm "Continue with schema update? [y/N]: "; then
    ui_note "Cancelled."
    return 0
  fi

  ui_note "Restarting server and applying schema update..."
  run_server_action "Server stop" symfony server:stop
  run_server_action "Schema update force" symfony console doctrine:schema:update --complete --force
  run_server_action "Schema validate" symfony console doctrine:schema:validate
  run_server_action "Server start detached" symfony server:start -d
}

print_menu() {
  ui_clear
  ui_banner "Server"
  printf '%s
' "Server Menu"
  printf '%s
' "-----------"
  printf '%s
' "1) Restart server"
  printf '%s
' "2) Restart + cache clear + warmup"
  printf '%s
' "3) Restart + schema update + validate"
  printf '%s
' "Space) Exit"
}

main() {
  if ! require_runtime; then
    ui_pause_any
    exit 0
  fi

  print_menu
  read -r -n 1 -s -p "Choice: " action
  printf '
'

  case "${action:-}" in
    1) server_restart ;;
    2) server_restart_with_cache ;;
    3) server_restart_with_schema ;;
    *) exit 0 ;;
  esac

  printf '%s
' "Exit code: ${EXIT_CODE}"
  ui_pause_any
  exit 0
}

main "$@"
