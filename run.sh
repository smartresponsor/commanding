#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
# Source-of-truth: root script. Embedded dot copies are projections.

[ -f /etc/profile ] && . /etc/profile
[ -f ~/.bashrc ] && . ~/.bashrc
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

COMMANDING_SH_DIR="$COMMANDING_DIR/sh"

pause() {
  ui_pause_any
}

fail() {
  local message="${1:-Error}"
  ui_error "$message"
  pause
  return 0
}

resolve_script() {
  local action="${1:-}"

  case "$action" in
    1) printf '%s' "$COMMANDING_SH_DIR/route.sh" ;;
    2) printf '%s' "$COMMANDING_SH_DIR/server.sh" ;;
    3) printf '%s' "$COMMANDING_SH_DIR/fixture.sh" ;;
    4) printf '%s' "$COMMANDING_SH_DIR/schema.sh" ;;
    5) printf '%s' "$COMMANDING_DIR/patch_zipper.sh" ;;
    6) printf '%s' "$COMMANDING_SH_DIR/test.sh" ;;
    7) printf '%s' "$COMMANDING_SH_DIR/docker.sh" ;;
    8) printf '%s' "$COMMANDING_SH_DIR/migration.sh" ;;
    9) printf '%s' "$COMMANDING_SH_DIR/composer.sh" ;;
    i|I) printf '%s' "$COMMANDING_SH_DIR/inspection.sh" ;;
    g|G) printf '%s' "$COMMANDING_DIR/git/commanding.sh" ;;
    l|L) printf '%s' "$COMMANDING_SH_DIR/log.sh" ;;
    c|C) printf '%s' "$COMMANDING_SH_DIR/cache.sh" ;;
    d|D) printf '%s' "$COMMANDING_SH_DIR/dot.sh" ;;
    *) return 1 ;;
  esac
}

ensure_target() {
  local target="${1:-}"
  [ -n "$target" ] || return 1
  [ -f "$target" ] || return 1
  return 0
}

is_long_running() {
  case "${1:-}" in
    2) return 0 ;;
    *) return 1 ;;
  esac
}

self_check() {
  local as_json=0
  [ "${1:-}" = "--json" ] && as_json=1

  local key target missing=()
  for key in 1 2 3 4 5 6 7 8 9 i g l c d; do
    target="$(resolve_script "$key" || true)"
    if ! ensure_target "$target"; then
      missing+=("$key")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    if [ $as_json -eq 1 ]; then
      emit_json_result ok run.sh "dispatch map ok"
    else
      ui_note "run.sh self-check passed."
    fi
    return 0
  fi

  local detail="unresolved dispatch targets: ${missing[*]}"
  if [ $as_json -eq 1 ]; then
    emit_json_result fail run.sh "$detail"
  else
    ui_error "$detail"
  fi
  return 1
}

run_short() {
  local target="$1"
  shift || true

  set +e
  bash "$target" "$@"
  local status=$?
  set -e

  if [ $status -ne 0 ]; then
    ui_error "Command failed (exit=$status)"
  fi

  pause
  return 0
}

run_long() {
  local target="$1"
  shift || true
  bash "$target" "$@" || true
  return 0
}

single() {
  local action="${1:-}"
  shift || true
  local target

  if ! target="$(resolve_script "$action")"; then
    fail "Unknown input: $action"
    return 0
  fi

  if ! ensure_target "$target"; then
    fail "Script not found: $target"
    return 0
  fi

  log_action "run single: $action -> $target"

  if is_long_running "$action"; then
    run_long "$target" "$@"
  else
    run_short "$target" "$@"
  fi

  return 0
}

chain() {
  local digits="${1:-}"
  [ -n "$digits" ] || fail 'Empty chain'

  local i ch target status
  local len="${#digits}"

  log_action "run chain: $digits"

  for (( i=0; i<len; i++ )); do
    ch="${digits:i:1}"

    if [[ "$ch" == '0' ]]; then
      return 0
    fi

    if [[ ! "$ch" =~ ^[0-9]$ ]]; then
      fail "Invalid chain action: $ch"
      return 0
    fi

    if ! target="$(resolve_script "$ch")"; then
      fail "Unknown chain step: $ch"
      return 0
    fi

    if ! ensure_target "$target"; then
      fail "Script not found: $target"
      return 0
    fi

    set +e
    bash "$target"
    status=$?
    set -e

    if [ $status -ne 0 ]; then
      ui_error "Chain step failed (step=$ch, exit=$status)"
      pause
      return 0
    fi
  done

  pause
  return 0
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    --self-check)
      self_check "$@"
      return $?
      ;;
    '')
      fail 'No command provided to run.sh'
      return 0
      ;;
    chain) chain "${1:-}" ;;
    *)     single "$cmd" "$@" ;;
  esac
}

main "$@"
