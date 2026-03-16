#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

COMMANDING_DIR="${COMMANDING_DIR:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}"
export COMMANDING_DIR

# shellcheck source=/dev/null
source "$COMMANDING_DIR/lib/ui.sh"

policy_file="$COMMANDING_DIR/policy/dot-accept.yaml"

parse_accept_list() {
  [ -f "$policy_file" ] || return 0
  # read lines under "accept:" that start with "  - .something"
  sed -n 's/^[[:space:]]*-[[:space:]]*\(\.[A-Za-z0-9._-]*\).*/\1/p' "$policy_file" | tr -d '\r'
}

detect_entry() {
  local d="$1"
  local f=""
  for f in run.ps1 run.sh gate.ps1 gate.sh; do
    if [ -f "$d/$f" ]; then
      printf '%s' "$f"
      return 0
    fi
  done
  printf ''
  return 0
}

run_entry() {
  local root="$1"
  local name="$2"
  local d="$root/$name"
  local entry
  entry="$(detect_entry "$d")"
  if [ -z "$entry" ]; then
    printf '%s\n' "NONRUN: $name (no run.ps1/run.sh/gate.*)"
    return 0
  fi

  printf '%s\n' ""
  printf '%s\n' "RUN: $name ($entry)"
  printf '%s\n' "--------------------------------"

  case "$entry" in
    *.ps1)
      if command -v pwsh >/dev/null 2>&1; then
        (cd "$d" && pwsh -NoProfile -ExecutionPolicy Bypass -File "./$entry") || true
      elif command -v powershell >/dev/null 2>&1; then
        (cd "$d" && powershell -NoProfile -ExecutionPolicy Bypass -File "./$entry") || true
      else
        printf '%s\n' "PowerShell not found."
      fi
      ;;
    *.sh)
      (cd "$d" && bash "./$entry") || true
      ;;
    *)
      printf '%s\n' "Unsupported entry: $entry"
      ;;
  esac

  return 0
}

main() {
  local root
  root="$(repo_root)"
  [ -n "${root:-}" ] || { ui_clear; ui_banner "Dot"; printf '%s\n' "Repo not detected."; exit 0; }

  mapfile -t accept < <(parse_accept_list || true)
  if [ "${#accept[@]}" -eq 0 ]; then
    ui_clear
    ui_banner "Dot"
    printf '%s\n' "No accepted dot-folders in policy."
    exit 0
  fi

  # collect existing
  items=()
  entries=()
  for name in "${accept[@]}"; do
    if [ -d "$root/$name" ]; then
      items+=("$name")
      entries+=("$(detect_entry "$root/$name")")
    fi
  done

  while true; do
    ui_clear
    ui_banner "Dot"

    printf '%s\n' "Accepted list (existing only):"
    printf '%s\n' ""

    if [ "${#items[@]}" -eq 0 ]; then
      printf '%s\n' "None found in repo root."
      printf '%s\n' ""
      printf '%s\n' "q) Back"
      key="$(ui_pick_key)"
      [ -z "${key:-}" ] && exit 0
      [[ "${key}" =~ [qQ] ]] && exit 0
      continue
    fi

    local i=0
    for ((i=0; i<${#items[@]}; i++)); do
      idx=$((i+1))
      name="${items[$i]}"
      ent="${entries[$i]}"
      if [ -n "$ent" ]; then
        printf '%s\n' " ${idx}) ${name}  [RUN]"
      else
        printf '%s\n' " ${idx}) ${name}  [NONRUN]"
      fi
    done

    printf '%s\n' ""
    printf '%s\n' "a) Run all RUN items"
    printf '%s\n' "r) Refresh"
    printf '%s\n' "q) Back"
    printf '%s'   "Choice: "

    key="$(ui_pick_key)"
    printf '\n'

    [ -z "${key:-}" ] && exit 0

    case "$key" in
      a|A)
        for ((i=0; i<${#items[@]}; i++)); do
          name="${items[$i]}"
          ent="${entries[$i]}"
          [ -n "$ent" ] || continue
          ui_clear
          ui_banner "Dot"
          run_entry "$root" "$name"
          ui_pause_any
        done
        ;;
      r|R)
        # recompute entries
        entries=()
        for name in "${items[@]}"; do
          entries+=("$(detect_entry "$root/$name")")
        done
        ;;
      q|Q)
        exit 0
        ;;
      [1-9])
        sel=$((key-1))
        if [ $sel -ge 0 ] && [ $sel -lt ${#items[@]} ]; then
          name="${items[$sel]}"
          ui_clear
          ui_banner "Dot"
          run_entry "$root" "$name"
          ui_pause_any
        fi
        ;;
      *)
        # ignore
        ;;
    esac
  done
}

main "$@"
