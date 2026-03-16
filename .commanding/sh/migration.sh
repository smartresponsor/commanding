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

ensure_migration_runtime() {
  require_command php || return 1
  require_file "bin/console" || return 1
}

run_migration_diff() {
  ensure_migration_runtime || return 1
  run_logged "migration diff" php bin/console doctrine:migrations:diff
}

run_migration_migrate() {
  ensure_migration_runtime || return 1
  if ! ui_confirm "Run doctrine:migrations:migrate? [y/N]: "; then
    ui_note "Migration cancelled."
    return 0
  fi
  run_logged "migration migrate" php bin/console doctrine:migrations:migrate --no-interaction
}

run_migration_rollback() {
  ensure_migration_runtime || return 1
  if ! ui_confirm "Rollback to previous migration? [y/N]: "; then
    ui_note "Rollback cancelled."
    return 0
  fi
  run_logged "migration rollback prev" php bin/console doctrine:migrations:migrate prev --no-interaction
}

run_migration_status() {
  ensure_migration_runtime || return 1
  run_logged "migration status" php bin/console doctrine:migrations:status
}

run_migration_execute() {
  ensure_migration_runtime || return 1
  local version=""
  read -r -p "Enter migration version: " version || true
  if [ -z "$version" ]; then
    ui_warn "Migration version is required."
    return 1
  fi
  if ! ui_confirm "Execute migration ${version}? [y/N]: "; then
    ui_note "Execution cancelled."
    return 0
  fi
  run_logged "migration execute $version" php bin/console doctrine:migrations:execute "$version" --up --no-interaction
}

while true; do
  ui_clear
  ui_banner "Migration"
  printf '%s\n' "1) Create migration (diff)"
  printf '%s\n' "2) Apply migration"
  printf '%s\n' "3) Rollback to previous"
  printf '%s\n' "4) Show migration status"
  printf '%s\n' "5) Execute specific migration"
  printf '%s\n' "6) Open action log"
  printf '%s\n' ""
  printf '%s\n' "Space) Exit"
  printf '%s' "Choice: "

  key="$(ui_pick_key)"
  printf '\n'

  case "${key:-}" in
    1)
      run_migration_diff || ui_warn "Migration diff failed."
      ui_pause_any
      ;;
    2)
      run_migration_migrate || ui_warn "Migration apply failed."
      ui_pause_any
      ;;
    3)
      run_migration_rollback || ui_warn "Migration rollback failed."
      ui_pause_any
      ;;
    4)
      run_migration_status || ui_warn "Migration status failed."
      ui_pause_any
      ;;
    5)
      run_migration_execute || ui_warn "Migration execute failed."
      ui_pause_any
      ;;
    6)
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
