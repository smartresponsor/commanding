#!/usr/bin/env bash
# Copyright (c) 2025 Oleksandr Tishchenko / Marketing America Corp
set -euo pipefail

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

die_soft() {
  printf '%s\n' "${1:-}"
  exit 0
}

root="$(repo_root)"
[ -n "${root:-}" ] || die_soft "Git repo not detected. Nothing to zip."

cd "$root"

# collect changed files (staged + unstaged)
mapfile -t unstaged < <(git diff --name-only --diff-filter=ACMRT 2>/dev/null || true)
mapfile -t staged   < <(git diff --cached --name-only --diff-filter=ACMRT 2>/dev/null || true)

declare -A seen=()
files=()

add_file() {
  local f="$1"
  [ -n "$f" ] || return 0
  [ -f "$f" ] || return 0
  if [ -z "${seen[$f]+x}" ]; then
    seen["$f"]=1
    files+=("$f")
  fi
}

for f in "${staged[@]}"; do add_file "$f"; done
for f in "${unstaged[@]}"; do add_file "$f"; done

if [ "${#files[@]}" -eq 0 ]; then
  die_soft "No changed files detected (staged/unstaged)."
fi

ts="$(date +%Y-%m-%d-%H-%M-%S)"
zip_name="patch-${ts}.zip"

# create zip in repo root
if command -v zip >/dev/null 2>&1; then
  zip -q -r "$zip_name" -- "${files[@]}" || die_soft "zip failed."
  printf '%s\n' "Created: $zip_name"
  printf '%s\n' "Files: ${#files[@]}"
  exit 0
fi

die_soft "zip command not available."
