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

require_docker_runtime() {
  if ! command_exists docker; then
    ui_error "Docker is not available in PATH"
    return 1
  fi

  if [ ! -f "$PROJECT_ROOT/docker/compose.yml" ] && [ ! -d "$PROJECT_ROOT/docker/compose" ]; then
    ui_error "Docker compose files were not found under: $PROJECT_ROOT/docker"
    return 1
  fi

  return 0
}

run_docker_action() {
  local label="$1"
  shift || true
  run_logged "$label" "$@" || EXIT_CODE=$?
}

docker_up() {
  ui_note "Starting local container stack..."
  run_docker_action "Docker up" docker compose up -d
}

docker_down() {
  ui_note "Stopping local container stack..."
  run_docker_action "Docker down" docker compose down
}

docker_logs() {
  ui_note "Streaming Docker logs..."
  local status=0
  set +e
  (
    cd "$PROJECT_ROOT"
    docker compose logs -f --tail 200
  )
  status=$?
  set -e
  EXIT_CODE=$status
}

print_menu() {
  ui_clear
  ui_banner "Docker"
  printf '%s
' "Docker Menu"
  printf '%s
' "-----------"
  printf '%s
' "1) Up"
  printf '%s
' "2) Down"
  printf '%s
' "3) Logs"
  printf '%s
' "4) Open Docker base README"
  printf '%s
' "5) Open Docker base manifest"
  printf '%s
' "Space) Exit"
}

main() {
  if ! require_docker_runtime; then
    ui_pause_any
    exit 0
  fi

  print_menu
  read -r -n 1 -s -p "Choice: " action
  printf '
'

  case "${action:-}" in
    1) docker_up ;;
    2) docker_down ;;
    3) docker_logs ;;
    4) show_file "$COMMANDING_DIR/docker/README.md" ;;
    5) show_file "$COMMANDING_DIR/docker/MANIFEST.md" ;;
    *) exit 0 ;;
  esac

  if [ "${action:-}" = "1" ] || [ "${action:-}" = "2" ] || [ "${action:-}" = "3" ]; then
    printf '%s
' "Exit code: ${EXIT_CODE}"
    ui_pause_any
  fi

  exit 0
}

main "$@"
