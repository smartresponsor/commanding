#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

ui_banner() {
  local title="${1:-Commanding}"
  printf '%s\n' ""
  printf '%s\n' " ${title}"

  local root
  root="$(repo_root)"
  if [ -n "${root:-}" ]; then
    printf '%s\n' " Repo: ${root}"
  else
    printf '%s\n' " Repo: not resolved"
  fi
  printf '\n'
}

ui_pause_any() {
  local msg="${1:-Press any key to continue...}"
  IFS= read -rsn1 -p "${msg}" _ 2>/dev/null || true
  printf '\n'
  return 0
}

ui_clear() {
  clear || true
}

ui_pick_key() {
  # read one key (no Enter). returns key in stdout. empty on Enter/Space.
  local k=""
  IFS= read -rsn1 k 2>/dev/null || true
  if [[ "${k}" == $'\n' || "${k}" == $'\r' || "${k}" == ' ' ]]; then
    printf ''
    return 0
  fi
  printf '%s' "${k}"
}
