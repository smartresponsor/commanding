#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

INSPECTION_DIR="$COMMANDING_DIR/logs/inspection"
TXT_DIR="$INSPECTION_DIR/txt"
JSON_DIR="$INSPECTION_DIR/json"
NDJSON_DIR="$INSPECTION_DIR/ndjson"

smoke_check() {
  mkdir -p "$INSPECTION_DIR" "$TXT_DIR" "$JSON_DIR" "$NDJSON_DIR"
  local action_log error_log
  action_log="$(runtime_log_file)"
  error_log="$(runtime_error_file)"
  touch "$action_log" "$error_log"

  local detail="log paths ready"
  if [ "${1:-}" = "--json" ]; then
    emit_json_result ok log.sh "$detail"
  else
    ui_note "$detail"
  fi
  return 0
}

pick_existing_file() {
  local path="${1:-}"
  [ -n "$path" ] || return 1
  [ -f "$path" ] || return 1
  printf '%s
' "$path"
}

resolve_inspection_file() {
  local primary="${1:-}"
  shift || true

  local candidate=""
  candidate="$(pick_existing_file "$primary" || true)"
  if [ -n "$candidate" ]; then
    printf '%s
' "$candidate"
    return 0
  fi

  for candidate in "$@"; do
    candidate="$(pick_existing_file "$candidate" || true)"
    if [ -n "$candidate" ]; then
      printf '%s
' "$candidate"
      return 0
    fi
  done

  return 1
}

show_inspection_file() {
  local label="${1:-inspection file}"
  shift || true

  local resolved=""
  resolved="$(resolve_inspection_file "$@" || true)"
  if [ -z "$resolved" ]; then
    ui_warn "$label is not available yet."
    ui_pause_any
    return 0
  fi

  show_file "$resolved"
  if [ ! -t 1 ]; then
    ui_pause_any
  fi
}

show_action_log() {
  local path=""
  path="$(runtime_log_file)"
  show_file "$path" || ui_pause_any
}

show_error_log() {
  local path=""
  path="$(runtime_error_file)"
  show_file "$path" || ui_pause_any
}

main() {
  case "${1:-}" in
    --smoke)
      shift || true
      smoke_check "$@"
      exit $?
      ;;
  esac

  ui_clear
  ui_banner "Log"

  printf '%s
' "Logs Menu"
  printf '%s
' "---------"
  printf '%s
' "1) Symfony server logs"
  printf '%s
' "2) Docker logs"
  printf '%s
' "3) Inspection run log"
  printf '%s
' "4) Inspection summary txt"
  printf '%s
' "5) Inspection summary json"
  printf '%s
' "6) Inspection chat report txt"
  printf '%s
' "7) Inspection compare report txt"
  printf '%s
' "8) Inspection compare json"
  printf '%s
' "9) Inspection findings ndjson"
  printf '%s
' "a) Inspection stream ndjson"
  printf '%s
' "b) Action log"
  printf '%s
' "c) Error log"
  printf '%s
' "Space) Exit"

  choice="$(ui_pick_key)"
  printf '
'

  case "${choice:-}" in
    1)
      require_command symfony || { ui_pause_any; exit 0; }
      exec symfony server:log
      ;;
    2)
      require_command docker || { ui_pause_any; exit 0; }
      exec docker compose logs -f
      ;;
    3)
      show_inspection_file         "inspection run log"         "$INSPECTION_DIR/latest.log"
      ;;
    4)
      show_inspection_file         "inspection summary txt"         "$TXT_DIR/latest.summary.txt"         "$INSPECTION_DIR/latest.summary.txt"
      ;;
    5)
      show_inspection_file         "inspection summary json"         "$JSON_DIR/latest.summary.json"         "$INSPECTION_DIR/latest.summary.json"
      ;;
    6)
      show_inspection_file         "inspection chat report txt"         "$TXT_DIR/latest.chat.txt"         "$INSPECTION_DIR/latest.chat.txt"
      ;;
    7)
      show_inspection_file         "inspection compare report txt"         "$TXT_DIR/latest.compare.txt"         "$INSPECTION_DIR/latest.compare.txt"
      ;;
    8)
      show_inspection_file         "inspection compare json"         "$JSON_DIR/latest.compare.json"         "$INSPECTION_DIR/latest.compare.json"
      ;;
    9)
      show_inspection_file         "inspection findings ndjson"         "$NDJSON_DIR/latest.findings.ndjson"         "$INSPECTION_DIR/latest.findings.ndjson"
      ;;
    a|A)
      show_inspection_file         "inspection stream ndjson"         "$NDJSON_DIR/latest.ndjson"         "$INSPECTION_DIR/latest.ndjson"
      ;;
    b|B)
      show_action_log
      ;;
    c|C)
      show_error_log
      ;;
    *)
      exit 0
      ;;
  esac
}

main "$@"
