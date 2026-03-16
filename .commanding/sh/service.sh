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

ensure_service_runtime() {
  require_command php || return 1
  require_file "bin/console" || return 1
}

run_service_list() {
  ensure_service_runtime || return 1
  run_logged "service list" php bin/console debug:container
}

run_service_show() {
  ensure_service_runtime || return 1
  local service_id=""
  read -r -p "Enter service id or class fragment: " service_id || true
  if [ -z "$service_id" ]; then
    ui_warn "Service id is required."
    return 1
  fi
  run_logged "service show $service_id" php bin/console debug:container "$service_id" --show-arguments
}

run_service_by_tag() {
  ensure_service_runtime || return 1
  local tag_name=""
  read -r -p "Enter service tag: " tag_name || true
  if [ -z "$tag_name" ]; then
    ui_warn "Service tag is required."
    return 1
  fi
  run_logged "service tag $tag_name" php bin/console debug:container --tag="$tag_name"
}

while true; do
  ui_clear
  ui_banner "Service"
  printf '%s\n' "1) List service container"
  printf '%s\n' "2) Show service details"
  printf '%s\n' "3) Show services by tag"
  printf '%s\n' "4) Open action log"
  printf '%s\n' ""
  printf '%s\n' "Space) Exit"
  printf '%s' "Choice: "

  key="$(ui_pick_key)"
  printf '\n'

  case "${key:-}" in
    1)
      run_service_list || ui_warn "Service list failed."
      ui_pause_any
      ;;
    2)
      run_service_show || ui_warn "Service details failed."
      ui_pause_any
      ;;
    3)
      run_service_by_tag || ui_warn "Service tag lookup failed."
      ui_pause_any
      ;;
    4)
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
