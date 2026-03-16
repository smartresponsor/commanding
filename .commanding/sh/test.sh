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

require_test_runtime() {
  if ! command_exists php; then
    ui_error "PHP is not available in PATH"
    return 1
  fi

  if [ ! -f "$PROJECT_ROOT/vendor/bin/phpunit" ]; then
    ui_error "vendor/bin/phpunit not found. Run composer install first."
    return 1
  fi

  return 0
}

run_test_action() {
  local label="$1"
  shift || true
  run_logged "$label" "$@" || EXIT_CODE=$?
}

unit_test() {
  ui_note "Running unit test suite..."
  run_test_action "PHPUnit unit suite" vendor/bin/phpunit --testsuite=unit
}

integration_test() {
  ui_note "Running integration test suite..."
  run_test_action "PHPUnit integration suite" vendor/bin/phpunit --testsuite=integration
}

e2e_test() {
  ui_note "Running e2e test suite..."
  run_test_action "PHPUnit e2e suite" vendor/bin/phpunit --testsuite=e2e
}

full_test() {
  ui_note "Running full PHPUnit suite..."
  run_test_action "PHPUnit full suite" vendor/bin/phpunit
}

open_test_log() {
  show_file "$(action_log_file)"
}

print_menu() {
  ui_clear
  ui_banner "Test"
  printf '%s
' "Tests Menu"
  printf '%s
' "----------"
  printf '%s
' "1) Unit tests"
  printf '%s
' "2) Integration tests"
  printf '%s
' "3) E2E tests"
  printf '%s
' "4) Full suite"
  printf '%s
' "5) Open action log"
  printf '%s
' "Space) Exit"
}

main() {
  if ! require_test_runtime; then
    ui_pause_any
    exit 0
  fi

  print_menu
  read -r -n 1 -s -p "Choice: " action
  printf '
'

  case "${action:-}" in
    1) unit_test ;;
    2) integration_test ;;
    3) e2e_test ;;
    4) full_test ;;
    5) open_test_log; exit 0 ;;
    *) exit 0 ;;
  esac

  printf '%s
' "Exit code: ${EXIT_CODE}"
  ui_pause_any
  exit 0
}

main "$@"
