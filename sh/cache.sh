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

ensure_cache_runtime() {
  require_command php || return 1
  require_file "bin/console" || return 1
}

smoke_check() {
  local as_json=0
  [ "${1:-}" = "--json" ] && as_json=1
  local detail="cache runtime ready"
  if ! ensure_cache_runtime; then
    detail="cache runtime not available"
    if [ $as_json -eq 1 ]; then
      emit_json_result fail cache.sh "$detail"
    else
      ui_error "$detail"
    fi
    return 1
  fi

  if [ $as_json -eq 1 ]; then
    emit_json_result ok cache.sh "$detail"
  else
    ui_note "$detail"
  fi
}

run_cache_clear() {
  ensure_cache_runtime || return 1
  run_logged "cache clear" php bin/console cache:clear
}

run_cache_warmup() {
  ensure_cache_runtime || return 1
  run_logged "cache warmup" php bin/console cache:warmup
}

run_cache_clear_and_warmup() {
  ensure_cache_runtime || return 1
  run_logged "cache clear" php bin/console cache:clear
  run_logged "cache warmup" php bin/console cache:warmup
}

main() {
  case "${1:-}" in
    --smoke)
      shift || true
      smoke_check "$@"
      exit $?
      ;;
  esac

  while true; do
    ui_clear
    ui_banner "Cache"
    printf '%s
' "1) Clear cache"
    printf '%s
' "2) Warmup cache"
    printf '%s
' "3) Clear and warmup"
    printf '%s
' "4) Open action log"
    printf '%s
' ""
    printf '%s
' "Space) Exit"
    printf '%s' "Choice: "

    key="$(ui_pick_key)"
    printf '
'

    case "${key:-}" in
      1)
        run_cache_clear || ui_warn "Cache clear failed."
        ui_pause_any
        ;;
      2)
        run_cache_warmup || ui_warn "Cache warmup failed."
        ui_pause_any
        ;;
      3)
        run_cache_clear_and_warmup || ui_warn "Cache clear/warmup failed."
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
}

main "$@"
