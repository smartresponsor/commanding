#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"}"
SCRIPT_DIR="$COMMANDING_DIR/sh"
MENU="$COMMANDING_DIR/menu.sh"

back_to_menu() {
  read -r -p "Press Enter to continue..." _ || true
  exec bash "$MENU"
}

fail_to_menu() {
  printf '%s\n' "${1:-Error}"
  back_to_menu
}

resolve_script() {
  local token="${1:-}"

  case "$token" in
    1) printf '%s' "$SCRIPT_DIR/route.sh" ;;
    2) printf '%s' "$SCRIPT_DIR/server.sh" ;;
    3) printf '%s' "$SCRIPT_DIR/fixture.sh" ;;
    4) printf '%s' "$SCRIPT_DIR/schema.sh" ;;
    5) printf '%s' "$SCRIPT_DIR/patch_zipper.sh" ;;
    6) printf '%s' "$SCRIPT_DIR/test.sh" ;;
    7) printf '%s' "$SCRIPT_DIR/docker.sh" ;;
    8) printf '%s' "$SCRIPT_DIR/migration.sh" ;;
    9) printf '%s' "$SCRIPT_DIR/composer.sh" ;;
    g|G) printf '%s' "$SCRIPT_DIR/git.sh" ;;
    l|L) printf '%s' "$SCRIPT_DIR/log.sh" ;;
    w|W) printf '%s' "$SCRIPT_DIR/worker.sh" ;;
    c|C) printf '%s' "$SCRIPT_DIR/cache.sh" ;;
    r|R) printf '%s' "$SCRIPT_DIR/repeat.sh" ;;
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
    2|w|W) return 0 ;; # server/worker
    *)     return 1 ;;
  esac
}

run_short() {
  local target="$1"; shift || true

  set +e
  bash "$target" "$@"
  local status=$?
  set -e

  if [ $status -ne 0 ]; then
    printf '\n%s\n' "Command failed (exit=$status)"
  fi

  back_to_menu
}

run_long() {
  local target="$1"; shift || true
  exec bash "$target" "$@"
}

single() {
  local token="${1:-}"; shift || true
  local target

  if ! target="$(resolve_script "$token")"; then
    fail_to_menu "Unknown input: $token"
  fi

  if ! ensure_target "$target"; then
    fail_to_menu "Script not found: $target"
  fi

  if is_long_running "$token"; then
    run_long "$target" "$@"
  else
    run_short "$target" "$@"
  fi
}

chain() {
  local digits="${1:-}"
  [ -n "$digits" ] || fail_to_menu "Empty chain"

  local i ch target status
  local len="${#digits}"

  for (( i=0; i<len; i++ )); do
    ch="${digits:i:1}"

    if [[ "$ch" == "0" ]]; then
      exec bash "$MENU"
    fi

    if [[ ! "$ch" =~ ^[0-9]$ ]]; then
      fail_to_menu "Invalid chain token: $ch"
    fi

    if ! target="$(resolve_script "$ch")"; then
      fail_to_menu "Unknown chain step: $ch"
    fi

    if ! ensure_target "$target"; then
      fail_to_menu "Script not found: $target"
    fi

    set +e
    bash "$target"
    status=$?
    set -e

    if [ $status -ne 0 ]; then
      printf '\n%s\n' "Chain step failed (step=$ch, exit=$status)"
      back_to_menu
    fi
  done

  back_to_menu
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    chain) chain "${1:-}" ;;
    *)     single "$cmd" "$@" ;;
  esac
}

main "$@"
