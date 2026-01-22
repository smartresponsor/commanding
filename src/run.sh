#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp

# Load Git Bash environment (colors/prompt) BEFORE strict mode
[ -f /etc/profile ] && . /etc/profile
[ -f ~/.bashrc ] && . ~/.bashrc
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"}"
export COMMANDING_DIR

COMMANDING_SH_DIR="$COMMANDING_DIR/sh"
COMMANDING="$COMMANDING_DIR/commanding.sh"

pause() {
  read -r -p "Press Enter to continue..." _ || true
  return 0
}

fail() {
  printf '%s\n' "${1:-Error}"
  pause
  return 0
}

resolve_script() {
  local action="${1:-}"

  case "$action" in
    1) printf "%s" "$COMMANDING_SH_DIR/route.sh" ;;
    2) printf "%s" "$COMMANDING_SH_DIR/server.sh" ;;
    3) printf "%s" "$COMMANDING_SH_DIR/fixture.sh" ;;
    4) printf "%s" "$COMMANDING_SH_DIR/schema.sh" ;;
    5) printf "%s" "$COMMANDING_DIR/patch_zipper.sh" ;;
    6) printf "%s" "$COMMANDING_SH_DIR/test.sh" ;;
    7) printf "%s" "$COMMANDING_SH_DIR/docker.sh" ;;
    8) printf "%s" "$COMMANDING_SH_DIR/migration.sh" ;;
    9) printf "%s" "$COMMANDING_SH_DIR/composer.sh" ;;
    g|G) printf "%s" "$COMMANDING_DIR/git/commanding.sh" ;;
    l|L) printf "%s" "$COMMANDING_SH_DIR/log.sh" ;;
    c|C) printf "%s" "$COMMANDING_SH_DIR/cache.sh" ;;
    d|D) printf "%s" "$COMMANDING_SH_DIR/dot.sh" ;;
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

  pause
  return 0
}

run_long() {
  local target="$1"; shift || true
  bash "$target" "$@" || true
  return 0
}

single() {
  local action="${1:-}"; shift || true
  local target

  if ! target="$(resolve_script "$action")"; then
    fail "Unknown input: $action"
    return 0
  fi

  if ! ensure_target "$target"; then
    fail "Script not found: $target"
    return 0
  fi

  if is_long_running "$action"; then
    run_long "$target" "$@"
  else
    run_short "$target" "$@"
  fi

  return 0
}

chain() {
  local digits="${1:-}"
  [ -n "$digits" ] || fail "Empty chain"

  local i ch target status
  local len="${#digits}"

  for (( i=0; i<len; i++ )); do
    ch="${digits:i:1}"

    if [[ "$ch" == "0" ]]; then
      # stop chain and return to menu
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
      printf '\n%s\n' "Chain step failed (step=$ch, exit=$status)"
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
    chain) chain "${1:-}" ;;
    *)     single "$cmd" "$@" ;;
  esac
}

main "$@"
