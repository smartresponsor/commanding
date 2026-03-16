#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./_lib.sh
source "$DIR/tool/_lib.sh"

stack="${1:-db}"
repo_root="$(find_repo_root)"
export_defaults "$repo_root"

cmd="$(compose_cmd)"

do_down() {
  local s="$1"
  mapfile -t files < <(collect_files "$s" "$DIR" "$repo_root")
  local args=()
  for f in "${files[@]}"; do
    args+=( -f "$f" )
  done
  $cmd "${args[@]}" down --remove-orphans
}

if [ "$stack" = "all" ]; then
  do_down obs || true
  do_down object || true
  do_down mq || true
  do_down cache || true
  do_down db || true
  exit 0
fi

do_down "$stack"
