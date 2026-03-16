#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

PROJECT_ROOT="$(detect_project_root)"
cd "$PROJECT_ROOT"

run_schema_validate() {
  require_command php || return 1
  require_file "bin/console" || return 1
  run_logged "schema validate" php bin/console doctrine:schema:validate
}

run_schema_update() {
  require_command php || return 1
  require_file "bin/console" || return 1

  if ! ui_confirm "Run doctrine:schema:update --complete --force? [y/N]: "; then
    ui_note "Schema update cancelled."
    return 0
  fi

  run_logged "schema update" php bin/console doctrine:schema:update --complete --force
  run_logged "schema validate after update" php bin/console doctrine:schema:validate
}

while true; do
  ui_clear
  ui_banner "Schema"
  printf '%s\n' "1) Validate schema"
  printf '%s\n' "2) Update schema (force)"
  printf '%s\n' "3) Open action log"
  printf '%s\n' ""
  printf '%s\n' "Space) Exit"
  printf '%s' "Choice: "

  key="$(ui_pick_key)"
  printf '\n'

  case "${key:-}" in
    1)
      run_schema_validate || ui_warn "Schema validation failed."
      ui_pause_any
      ;;
    2)
      run_schema_update || ui_warn "Schema update failed."
      ui_pause_any
      ;;
    3)
      show_file "$(runtime_log_file)"
      ;;
    ""|0|q|Q)
      exit 0
      ;;
    *)
      ui_warn "Unknown action."
      ui_pause_any
      ;;
  esac
done
