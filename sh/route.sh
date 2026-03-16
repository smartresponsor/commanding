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
require_command grep || exit 1

run_route_command() {
  local label="$1"
  shift

  (
    cd "$PROJECT_ROOT"
    run_logged "$label" php "$CONSOLE_BIN" "$@"
  )
}

show_all_route() {
  (
    cd "$PROJECT_ROOT"
    php "$CONSOLE_BIN" debug:router
  )
}

show_route_detail() {
  local route_name="$1"
  (
    cd "$PROJECT_ROOT"
    php "$CONSOLE_BIN" debug:router --format=md --show-controllers "$route_name"
  )
}

filter_route_partial() {
  local pattern="$1"
  (
    cd "$PROJECT_ROOT"
    php "$CONSOLE_BIN" debug:router --format=md --show-controllers | grep -E "(${pattern})|(^ --------------)|(^ Name)"
  )
}

filter_route_exact() {
  local route_name="$1"
  (
    cd "$PROJECT_ROOT"
    php "$CONSOLE_BIN" debug:router --format=md --show-controllers | grep -E "(${route_name})|(^ --------------)|(^ Name)"
  )
}

while true; do
  ui_clear
  ui_banner "Route"

  printf '%s\n' "Route Menu"
  printf '%s\n' "----------"
  printf '%s\n' "1) List all route"
  printf '%s\n' "2) Show route detail by name"
  printf '%s\n' "3) Filter route by partial name"
  printf '%s\n' "4) Filter route by exact name"
  printf '%s\n' "5) Open action log"
  printf '%s\n' ""
  printf '%s\n' "Space) Exit"
  printf '%s'   "Choice: "

  action="$(ui_pick_key)"
  printf '\n'

  exit_code=0

  case "${action:-}" in
    1)
      show_all_route || exit_code=$?
      ;;
    2)
      route_name=""
      read -r -p "Route name: " route_name || true
      if [ -z "$route_name" ]; then
        ui_warn "Route name is required."
      else
        show_route_detail "$route_name" || exit_code=$?
      fi
      ;;
    3)
      partial_name=""
      read -r -p "Partial route name: " partial_name || true
      if [ -z "$partial_name" ]; then
        ui_warn "Partial route name is required."
      else
        filter_route_partial "$partial_name" || exit_code=$?
      fi
      ;;
    4)
      exact_name=""
      read -r -p "Exact route name: " exact_name || true
      if [ -z "$exact_name" ]; then
        ui_warn "Exact route name is required."
      else
        filter_route_exact "$exact_name" || exit_code=$?
      fi
      ;;
    5)
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
